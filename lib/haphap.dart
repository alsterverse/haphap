import 'haphap_platform_interface.dart';

class Haphap {
  Future<String?> getPlatformVersion() {
    return HaphapPlatform.instance.getPlatformVersion();
  }

  Future<void> idleHaptics() {
    return HaphapPlatform.instance.goToIdle();
  }

  Future<void> prepareHaptics() {
    return HaphapPlatform.instance.prepare();
  }

  Future<void> stop() {
    return HaphapPlatform.instance.stop();
  }

  Future<void> playEscalatingHapticPattern() {
    return HaphapPlatform.instance.runRampUp();
  }

  /// Power [0-1] determines the playback point of the haptic pattern.
  /// More power equals more and longer vibrations.
  /// Should be set to a division of the number of revolutions to get a strong vibration at the start
  Future<void> playWaveHapticPattern({
    double power = 1.0,
  }) {
    return HaphapPlatform.instance.runRelease(power);
  }

  Future<void> updateWaveHapticPatternSettings({
    Duration durationInSeconds = const Duration(seconds: 4),
    double waves = 4.0,
    bool useExponentialCurve = false,
  }) {
    return HaphapPlatform.instance.updateSettings(
      durationInSeconds.inMilliseconds,
      waves,
      useExponentialCurve,
    );
  }
}
