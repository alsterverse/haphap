import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'haphap_method_channel.dart';

abstract class HaphapPlatform extends PlatformInterface {
  /// Constructs a HaphapPlatform.
  HaphapPlatform() : super(token: _token);

  static final Object _token = Object();

  static HaphapPlatform _instance = MethodChannelHaphap();

  /// The default instance of [HaphapPlatform] to use.
  ///
  /// Defaults to [MethodChannelHaphap].
  static HaphapPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HaphapPlatform] when
  /// they register themselves.
  static set instance(HaphapPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> prepare() {
    throw UnimplementedError('prepare() has not been implemented.');
  }

  Future<void> runRampUp() {
    throw UnimplementedError('runRampUp() has not been implemented.');
  }

  Future<void> runContinuous() {
    throw UnimplementedError('runContinuous() has not been implemented.');
  }

  Future<void> runRelease(double power) {
    throw UnimplementedError('runRelease(power) has not been implemented.');
  }

  Future<void> runPattern(String data) {
    //print('runPattern $data');
    //return HaphapPlatform.instance.runPattern(data);
    throw UnimplementedError('runPattern() has not been implemented.');
  }
}
