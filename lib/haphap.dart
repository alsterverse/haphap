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

  Future<void> runRampUp() {
    return HaphapPlatform.instance.runRampUp();
  }

  Future<void> runContinuous() {
    return HaphapPlatform.instance.runContinuous();
  }

  Future<void> runRelease(double power) {
    return HaphapPlatform.instance.runRelease(power);
  }

  Future<void> runPattern(String data) {
    //print('runPattern $data');
    return HaphapPlatform.instance.runPattern(data);
  }
}
