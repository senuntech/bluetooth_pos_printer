import Flutter
import UIKit
import CoreBluetooth

public class BluetoothPosPrinterPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate, CBPeripheralDelegate, FlutterStreamHandler {
    
    private var channel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    private var centralManager: CBCentralManager?
    private var discoveredPeripherals: [CBPeripheral] = []
    
    private var connectedPeripheral: CBPeripheral?
    private var writableCharacteristic: CBCharacteristic?
    
    private var isConnecting = false
    
    private class PendingAction {
        let action: () -> Void
        let onTimeout: () -> Void
        
        init(action: @escaping () -> Void, onTimeout: @escaping () -> Void) {
            self.action = action
            self.onTimeout = onTimeout
        }
    }
    private var pendingActions: [PendingAction] = []
    private var peripheralNames: [UUID: String] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "samples.flutter.dev/bluetooth_pos_printer", binaryMessenger: registrar.messenger())
        let instance = BluetoothPosPrinterPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "samples.flutter.dev/bluetooth_pos_printer/status", binaryMessenger: registrar.messenger())
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)
        
        instance.centralManager = CBCentralManager(delegate: instance, queue: nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isBluetoothEnabled":
            isBluetoothEnabled(result: result)
        case "scan":
            scanDevices(result: result)
        case "connect":
            if let args = call.arguments as? [String: Any], let address = args["address"] as? String {
                connectToDevice(address: address, result: result)
            } else {
                result(FlutterError(code: "INVALID_ADDRESS", message: "Address cannot be null", details: nil))
            }
        case "disconnect":
            disconnect(result: result)
        case "printRawBytes":
            if let args = call.arguments as? [String: Any], let flutterData = args["bytes"] as? FlutterStandardTypedData {
                printBytes(data: flutterData.data, result: result)
            } else {
                result(FlutterError(code: "INVALID_DATA", message: "Bytes cannot be null", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    private func updateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.eventSink?(status)
        }
    }
    
    private func scanDevices(result: @escaping FlutterResult) {
        if centralManager == nil || centralManager?.state == .unknown || centralManager?.state == .resetting {
            let pending = PendingAction(
                action: { [weak self] in
                    self?.scanDevices(result: result)
                },
                onTimeout: {
                    result(FlutterError(code: "BLUETOOTH_DISABLED", message: "Bluetooth is not powered on (Timeout)", details: nil))
                }
            )
            pendingActions.append(pending)
            
            // Timeout de 15.0 segundos para permitir tempo para o usuário aceitar a permissão de Bluetooth
            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
                guard let self = self else { return }
                if let index = self.pendingActions.firstIndex(where: { $0 === pending }) {
                    self.pendingActions.remove(at: index)
                    pending.onTimeout()
                }
            }
            return
        }
        
        if centralManager?.state != .poweredOn {
            result(FlutterError(code: "BLUETOOTH_DISABLED", message: "Bluetooth is not powered on", details: nil))
            return
        }
        
        discoveredPeripherals.removeAll()
        peripheralNames.removeAll()
        centralManager?.scanForPeripherals(withServices: nil, options: nil)
        
        // Return results after 3.0 seconds of scanning
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            self.centralManager?.stopScan()
            var list: [[String: String]] = []
            for p in self.discoveredPeripherals {
                var map: [String: String] = [:]
                map["name"] = self.peripheralNames[p.identifier] ?? p.name ?? "Unknown"
                map["address"] = p.identifier.uuidString
                list.append(map)
            }
            result(list)
        }
    }
    
    private func isBluetoothEnabled(result: @escaping FlutterResult) {
        if centralManager == nil || centralManager?.state == .unknown || centralManager?.state == .resetting {
            let pending = PendingAction(
                action: { [weak self] in
                    self?.isBluetoothEnabled(result: result)
                },
                onTimeout: {
                    result(false)
                }
            )
            pendingActions.append(pending)
            
            // Timeout de 15.0 segundos para aguardar resolução do estado
            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
                guard let self = self else { return }
                if let index = self.pendingActions.firstIndex(where: { $0 === pending }) {
                    self.pendingActions.remove(at: index)
                    pending.onTimeout()
                }
            }
            return
        }
        
        result(centralManager?.state == .poweredOn)
    }

    private func connectToDevice(address: String, result: @escaping FlutterResult) {
        if centralManager == nil || centralManager?.state == .unknown || centralManager?.state == .resetting {
            let pending = PendingAction(
                action: { [weak self] in
                    self?.connectToDevice(address: address, result: result)
                },
                onTimeout: {
                    result(FlutterError(code: "BLUETOOTH_DISABLED", message: "Bluetooth is not powered on (Timeout)", details: nil))
                }
            )
            pendingActions.append(pending)
            
            // Timeout de 15.0 segundos para aguardar resolução do estado
            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
                guard let self = self else { return }
                if let index = self.pendingActions.firstIndex(where: { $0 === pending }) {
                    self.pendingActions.remove(at: index)
                    pending.onTimeout()
                }
            }
            return
        }
        
        if centralManager?.state != .poweredOn {
            result(FlutterError(code: "BLUETOOTH_DISABLED", message: "Bluetooth is not powered on", details: nil))
            return
        }
        
        guard let uuid = UUID(uuidString: address) else {
            result(FlutterError(code: "INVALID_UUID", message: "Invalid UUID string", details: nil))
            return
        }
        
        let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = peripherals?.first else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device not found", details: nil))
            return
        }
        
        if isConnecting || connectedPeripheral != nil {
            disconnectInternal()
        }
        
        isConnecting = true
        updateStatus("connecting")
        
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        
        centralManager?.connect(peripheral, options: nil)
        result(true)
    }
    
    private func disconnectInternal() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        writableCharacteristic = nil
        updateStatus("disconnected")
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        disconnectInternal()
        result(true)
    }
    
    private func printBytes(data: Data, result: @escaping FlutterResult) {
        guard let peripheral = connectedPeripheral, let char = writableCharacteristic else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Printer is not connected or writable characteristic not found", details: nil))
            return
        }
        
        let writeType: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        
        let chunkSize = 256
        var offset = 0
        let totalSize = data.count
        
        DispatchQueue.global(qos: .userInitiated).async {
            while offset < totalSize {
                let end = min(offset + chunkSize, totalSize)
                let chunk = data.subdata(in: offset..<end)
                
                peripheral.writeValue(chunk, for: char, type: writeType)
                offset += chunkSize
                
                Thread.sleep(forTimeInterval: 0.01)
            }
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            disconnectInternal()
        }
        
        if central.state != .unknown && central.state != .resetting {
            if !pendingActions.isEmpty {
                let actions = pendingActions
                pendingActions.removeAll()
                for pending in actions {
                    pending.action()
                }
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
        
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            peripheralNames[peripheral.identifier] = localName
        } else if let name = peripheral.name {
            peripheralNames[peripheral.identifier] = name
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnecting = false
        peripheral.discoverServices(nil)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnecting = false
        disconnectInternal()
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        disconnectInternal()
    }
    
    // MARK: - CBPeripheralDelegate
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writableCharacteristic = characteristic
                updateStatus("connected")
                return
            }
        }
    }
}
