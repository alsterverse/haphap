import 'package:flutter_test/flutter_test.dart';
import 'package:haphap/haphap.dart';
import 'package:haphap/haphap_platform_interface.dart';
import 'package:haphap/haphap_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHaphapPlatform
    with MockPlatformInterfaceMixin
    implements HaphapPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> prepare() {
    // TODO: implement prepare
    throw UnimplementedError();
  }

  @override
  Future<void> runContinuous() {
    // TODO: implement runContinuous
    throw UnimplementedError();
  }

  @override
  Future<void> runRampUp() {
    // TODO: implement runRampUp
    throw UnimplementedError();
  }

  @override
  Future<void> runRelease(
    double power,
  ) {
    // TODO: implement runRelease
    throw UnimplementedError();
  }

  @override
  Future<void> runPattern(String data) {
    // TODO: implement runPattern
    throw UnimplementedError();
  }

  @override
  Future<void> stop() {
    // TODO: implement stop
    throw UnimplementedError();
  }

  @override
  Future<void> goToIdle() {
    // TODO: implement goToIdle
    throw UnimplementedError();
  }

  @override
  Future<void> updateSettings(
    double releaseDuration,
    double revolutions,
    bool useExponentialCurve,
  ) {
    // TODO: implement updateSettings
    throw UnimplementedError();
  }
}

void main() {
  final HaphapPlatform initialPlatform = HaphapPlatform.instance;

  test('$MethodChannelHaphap is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHaphap>());
  });

  test('getPlatformVersion', () async {
    Haphap haphapPlugin = Haphap();
    MockHaphapPlatform fakePlatform = MockHaphapPlatform();
    HaphapPlatform.instance = fakePlatform;

    expect(await haphapPlugin.getPlatformVersion(), '42');
  });
}
