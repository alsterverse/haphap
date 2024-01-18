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
          title: const Text('Plugin example app'),
        ),
        body: ListView(
          children: [
            ListTile(
              title: Text('Running on: $_platformVersion\n'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.prepare();
              },
              child: const Text('Prepare'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.runRampUp();
              },
              child: const Text('Ramp'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.runRelease(0.25);
              },
              child: const Text('Release 0.25'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.runRelease(0.5);
              },
              child: const Text('Release 0.5'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.runRelease(0.75);
              },
              child: const Text('Release 0.75'),
            ),
            TextButton(
              onPressed: () async {
                _haphapPlugin.runRelease(1.0);
              },
              child: const Text('Release 1.0'),
            ),
          ],
        ),
      ),
    );
  }
}
