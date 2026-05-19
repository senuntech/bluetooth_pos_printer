import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bluetooth_pos_printer_platform_interface.dart';

/// An implementation of [BluetoothPosPrinterPlatform] that uses method channels.
class MethodChannelBluetoothPosPrinter extends BluetoothPosPrinterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('bluetooth_pos_printer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
