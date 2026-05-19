import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'bluetooth_pos_printer_method_channel.dart';

abstract class BluetoothPosPrinterPlatform extends PlatformInterface {
  /// Constructs a BluetoothPosPrinterPlatform.
  BluetoothPosPrinterPlatform() : super(token: _token);

  static final Object _token = Object();

  static BluetoothPosPrinterPlatform _instance = MethodChannelBluetoothPosPrinter();

  /// The default instance of [BluetoothPosPrinterPlatform] to use.
  ///
  /// Defaults to [MethodChannelBluetoothPosPrinter].
  static BluetoothPosPrinterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BluetoothPosPrinterPlatform] when
  /// they register themselves.
  static set instance(BluetoothPosPrinterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
