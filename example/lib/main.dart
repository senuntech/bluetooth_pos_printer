import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:bluetooth_pos_printer/bluetooth_pos_printer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth POS Printer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const PrinterScreen(),
    );
  }
}

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  PrinterStatus _connectionStatus = PrinterStatus.disconnected;
  List<BluetoothPrinterDevice> _devices = [];
  BluetoothPrinterDevice? _connectedDevice;
  bool _isScanning = false;
  BluetoothScanMode _scanMode = BluetoothScanMode.active;
  late StreamSubscription<PrinterStatus> _statusSubscription;

  @override
  void initState() {
    super.initState();
    _statusSubscription = BluetoothPosPrinter.instance.statusStream.listen((
      status,
    ) {
      setState(() {
        _connectionStatus = status;
        if (status == PrinterStatus.disconnected) {
          _connectedDevice = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    final isBluetoothOn = await BluetoothPosPrinter.instance.isBluetoothEnabled();
    if (!isBluetoothOn) {
      _showSnackBar('Bluetooth está desativado. Por favor, ative o Bluetooth.');
      return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      final devices = await BluetoothPosPrinter.instance.scan(
        mode: _scanMode,
      );
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      _showSnackBar('Erro ao buscar impressoras: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connect(BluetoothPrinterDevice device) async {
    try {
      final success = await BluetoothPosPrinter.instance.connect(
        device.address,
      );
      if (success) {
        setState(() {
          _connectedDevice = device;
        });
      } else {
        _showSnackBar('Falha ao conectar à impressora.');
      }
    } catch (e) {
      _showSnackBar('Erro de conexão: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      await BluetoothPosPrinter.instance.disconnect();
    } catch (e) {
      _showSnackBar('Erro ao desconectar: $e');
    }
  }

  Future<void> _printTestCoupon() async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text(
        'TESTE DE IMPRESSAO',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.text('--------------------------------');

      final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
      bytes += generator.text(
        'Data: $dateStr',
        styles: const PosStyles(align: PosAlign.left),
      );

      bytes += generator.text('--------------------------------');
      bytes += generator.text(
        'Obrigado por usar o plugin!',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.feed(2);
      bytes += generator.cut();

      final success = await BluetoothPosPrinter.instance.printRawBytes(bytes);
      if (!success) {
        _showSnackBar('Falha ao enviar dados para a impressora.');
      } else {
        _showSnackBar('Cupom enviado com sucesso!');
      }
    } catch (e) {
      _showSnackBar('Erro na impressão: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getStatusText() {
    switch (_connectionStatus) {
      case PrinterStatus.disconnected:
        return 'Desconectado';
      case PrinterStatus.connecting:
        return 'Conectando...';
      case PrinterStatus.connected:
        return 'Conectado a: ${_connectedDevice?.name ?? 'Impressora'}';
    }
  }

  Color _getStatusColor() {
    switch (_connectionStatus) {
      case PrinterStatus.disconnected:
        return Colors.redAccent;
      case PrinterStatus.connecting:
        return Colors.orangeAccent;
      case PrinterStatus.connected:
        return Colors.green;
    }
  }

  Icon _getDeviceIcon(String type) {
    switch (type) {
      case 'printer':
        return const Icon(Icons.print, color: Colors.blueAccent);
      case 'phone':
        return const Icon(Icons.phone_android, color: Colors.green);
      case 'computer':
        return const Icon(Icons.computer, color: Colors.purple);
      case 'audio':
        return const Icon(Icons.headphones, color: Colors.orange);
      case 'peripheral':
        return const Icon(Icons.mouse, color: Colors.teal);
      default:
        return const Icon(Icons.bluetooth, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionStatus == PrinterStatus.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impressora Térmica Bluetooth'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: _getStatusColor(),
            child: Text(
              _getStatusText(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Modo de Busca
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Modo de Busca',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<BluetoothScanMode>(
                    segments: const <ButtonSegment<BluetoothScanMode>>[
                      ButtonSegment<BluetoothScanMode>(
                        value: BluetoothScanMode.active,
                        label: Text('Ativos'),
                        icon: Icon(Icons.radar),
                      ),
                      ButtonSegment<BluetoothScanMode>(
                        value: BluetoothScanMode.paired,
                        label: Text('Pareados'),
                        icon: Icon(Icons.link),
                      ),
                      ButtonSegment<BluetoothScanMode>(
                        value: BluetoothScanMode.all,
                        label: Text('Todos'),
                        icon: Icon(Icons.all_inclusive),
                      ),
                    ],
                    selected: <BluetoothScanMode>{_scanMode},
                    onSelectionChanged: _isScanning
                        ? null
                        : (Set<BluetoothScanMode> newSelection) {
                            setState(() {
                              _scanMode = newSelection.first;
                            });
                          },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _scanMode == BluetoothScanMode.active
                        ? 'Busca apenas novos aparelhos ativos próximos (padrão)'
                        : _scanMode == BluetoothScanMode.paired
                            ? 'Exibe apenas aparelhos já pareados no Android'
                            : 'Exibe pareados e faz busca ativa por novos aparelhos',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Scan Control
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('Buscar Impressoras'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),

          // Device List
          Expanded(
            child: _devices.isEmpty && !_isScanning
                ? const Center(child: Text('Nenhuma impressora encontrada.'))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isCurrentConnectedDevice =
                          _connectedDevice?.address == device.address;

                      return ListTile(
                        leading: _getDeviceIcon(device.type),
                        title: Text(device.name),
                        subtitle: Text(device.address),
                        trailing:
                            isCurrentConnectedDevice &&
                                _connectionStatus == PrinterStatus.connected
                            ? ElevatedButton(
                                onPressed: _disconnect,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Desconectar'),
                              )
                            : ElevatedButton(
                                onPressed:
                                    _connectionStatus ==
                                        PrinterStatus.connecting
                                    ? null
                                    : () => _connect(device),
                                child: const Text('Conectar'),
                              ),
                      );
                    },
                  ),
          ),

          // Print Panel
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: isConnected ? _printTestCoupon : null,
                icon: const Icon(Icons.receipt_long),
                label: const Text(
                  'Imprimir Cupom de Teste',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  backgroundColor: isConnected
                      ? Colors.blueAccent
                      : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
