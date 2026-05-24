import 'dart:async';
import 'package:flutter/services.dart';

enum PrinterStatus {
  disconnected,
  connecting,
  connected,
}

enum BluetoothScanMode {
  all,
  paired,
  active,
}

class BluetoothPrinterDevice {
  final String name;
  final String address;
  final String type;

  BluetoothPrinterDevice({
    required this.name,
    required this.address,
    required this.type,
  });

  factory BluetoothPrinterDevice.fromMap(Map<Object?, Object?> map) {
    return BluetoothPrinterDevice(
      name: map['name'] as String? ?? 'Unknown',
      address: map['address'] as String? ?? '',
      type: map['type'] as String? ?? 'unknown',
    );
  }
}

class BluetoothPosPrinter {
  static final BluetoothPosPrinter instance = BluetoothPosPrinter._internal();

  factory BluetoothPosPrinter() {
    return instance;
  }

  BluetoothPosPrinter._internal();

  final MethodChannel _channel = const MethodChannel('samples.flutter.dev/bluetooth_pos_printer');
  final EventChannel _statusChannel = const EventChannel('samples.flutter.dev/bluetooth_pos_printer/status');

  /// Retorna `true` se o Bluetooth estiver ativado/ligado.
  Future<bool> isBluetoothEnabled() async {
    final bool? result = await _channel.invokeMethod<bool>('isBluetoothEnabled');
    return result ?? false;
  }

  /// Busca por impressoras Bluetooth.
  /// Android: Retorna dispositivos Classic Bluetooth SPP pareados e descobertos.
  /// iOS: Retorna dispositivos BLE que possam ser impressoras.
  ///
  /// Permissões Obrigatórias no Android (AndroidManifest.xml):
  /// - `<uses-permission android:name="android.permission.BLUETOOTH" />`
  /// - `<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />`
  /// - `<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />` (Android 12+)
  /// - `<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />` (Android 12+)
  /// - `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />` (Necessário para o scan)
  ///
  /// Permissões Obrigatórias no iOS (Info.plist):
  /// - `<key>NSBluetoothAlwaysUsageDescription</key>`
  ///   `<string>Precisamos de acesso ao Bluetooth para conectar à impressora.</string>`
  /// - `<key>NSBluetoothPeripheralUsageDescription</key>`
  ///   `<string>Precisamos de acesso ao Bluetooth para conectar à impressora.</string>`
  Future<List<BluetoothPrinterDevice>> scan({
    BluetoothScanMode mode = BluetoothScanMode.active,
  }) async {
    final List<dynamic>? results = await _channel.invokeListMethod('scan', {
      'mode': mode.name,
    });
    if (results == null) return [];
    
    return results.map((e) => BluetoothPrinterDevice.fromMap(e as Map<Object?, Object?>)).toList();
  }

  /// Conecta ao dispositivo usando o endereço MAC (Android) ou UUID (iOS) fornecido.
  Future<bool> connect(String address) async {
    final bool? result = await _channel.invokeMethod<bool>('connect', {'address': address});
    return result ?? false;
  }

  /// Desconecta do dispositivo atualmente conectado.
  Future<bool> disconnect() async {
    final bool? result = await _channel.invokeMethod<bool>('disconnect');
    return result ?? false;
  }

  /// Envia bytes brutos diretamente para a impressora.
  Future<bool> printRawBytes(List<int> bytes) async {
    final bool? result = await _channel.invokeMethod<bool>('printRawBytes', {'bytes': Uint8List.fromList(bytes)});
    return result ?? false;
  }

  /// Escuta o status da conexão em tempo real.
  Stream<PrinterStatus> get statusStream {
    return _statusChannel.receiveBroadcastStream().map((dynamic event) {
      final String statusStr = event.toString().toLowerCase();
      if (statusStr == 'connecting') return PrinterStatus.connecting;
      if (statusStr == 'connected') return PrinterStatus.connected;
      return PrinterStatus.disconnected;
    });
  }
}
