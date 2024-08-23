import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'haphap_platform_interface.dart';

/// An implementation of [HaphapPlatform] that uses method channels.
class MethodChannelHaphap extends HaphapPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('haphap');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> runPattern(String data) async {
    await methodChannel.invokeMethod<void>('runPattern', {
      'data': data,
    });
  }

  @override
  Future<void> stop() async {
    await methodChannel.invokeMethod<void>('stop');
  }

  @override
  Future<void> goToIdle() async {
    await methodChannel.invokeMethod<void>('goToIdle');
  }

  @override
  Future<void> prepare() async {
    await methodChannel.invokeMethod<void>('prepare');
  }

  @override
  Future<void> runRampUp() async {
    await methodChannel.invokeMethod<void>('runRampUp');
  }

  @override
  Future<void> runContinuous() async {
    await methodChannel.invokeMethod<void>('runContinuous');
  }

  @override
  Future<void> runRelease(
    double power,
  ) async {
    await methodChannel.invokeMethod<void>('runRelease', {
      'power': power,
    });
  }

  @override
  Future<void> updateSettings(
    double releaseDuration,
    double revolutions,
    bool useExponentialCurve,
  ) async {
    await methodChannel.invokeMethod<void>('updateSettings', {
      'releaseDuration': releaseDuration,
      'revolutions': revolutions,
      'useExponentialCurve': useExponentialCurve,
    });
  }
}
