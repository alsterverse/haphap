import 'haphap_platform_interface.dart';

class Haphap {
  Future<String?> getPlatformVersion() {
    return HaphapPlatform.instance.getPlatformVersion();
  }

  // Future<void> idle() {
  // }

  Future<void> stop() {
    return HaphapPlatform.instance.stop();
  }

  // Future<bool> getIsPrepared() {}

  Future<void> prepare() {
    return HaphapPlatform.instance.prepare();
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
