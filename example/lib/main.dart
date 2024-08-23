import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:haphap/haphap.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _haphapPlugin = Haphap();
  double _releaseValue = 1.0;

  double _releaseDuration = 4.0;
  double _revolutions = 4.0;
  bool _useExponentialCurve = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _haphapPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Haphap example'),
        ),
        body: ListView(
          children: [
            ListTile(
              title: Text('Running on: $_platformVersion\n'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.prepareHaptics();
              },
              child: const Text('Prepare haptics'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.idleHaptics();
              },
              child: const Text('Idle haptics'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.stop();
              },
              child: const Text('Stop'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.playEscalatingHapticPattern();
              },
              child: const Text('Ramp'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.playWaveHapticPattern(
                  power: _releaseValue,
                );
              },
              child: Text('Release at $_releaseValue'),
            ),
            const ListTile(
              title: Text('Release point'),
            ),
            Slider(
                value: _releaseValue,
                label: _releaseValue.toString(),
                divisions: 10,
                onChanged: (value) {
                  setState(
                    () {
                      _releaseValue = value;
                    },
                  );
                }),
            const ListTile(
              title: Text('Settings'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.updateWaveHapticPatternSettings(
                  durationInSeconds: _releaseDuration,
                  waves: _revolutions,
                  useExponentialCurve: _useExponentialCurve,
                );
              },
              child: const Text('Update settings'),
            ),
            const ListTile(
              title: Text('Release duration'),
            ),
            Slider(
                value: _releaseDuration,
                label: _releaseDuration.toString(),
                divisions: 10,
                max: 10.0,
                onChanged: (value) {
                  setState(
                    () {
                      _releaseDuration = value;
                    },
                  );
                }),
            const ListTile(
              title: Text('Revolutions'),
            ),
            Slider(
                value: _revolutions,
                label: _revolutions.toString(),
                divisions: 10,
                max: 10.0,
                onChanged: (value) {
                  setState(
                    () {
                      _revolutions = value;
                    },
                  );
                }),
            SwitchListTile(
              title: const Text('Use exponential curve'),
              value: _useExponentialCurve,
              onChanged: (value) {
                setState(
                  () {
                    _useExponentialCurve = value;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
