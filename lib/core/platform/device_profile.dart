import 'package:flutter/services.dart';

/// Características del dispositivo que cambian el layout
/// (teléfono vs. Google TV).
class DeviceProfile {
  const new({required this.isTv});

  /// Canal implementado en `MainActivity.kt`.
  static const channel = MethodChannel('ejerciciosapp/device');

  final bool isTv;

  static Future<DeviceProfile> load() async {
    try {
      final isTv = await channel.invokeMethod<bool>('isTv') ?? false;
      return DeviceProfile(isTv: isTv);
    } on PlatformException {
      return const DeviceProfile(isTv: false);
    } on MissingPluginException {
      return const DeviceProfile(isTv: false);
    }
  }
}
