import 'dart:async';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';

typedef Future<dynamic> MessageHandler(String message);

class FlutterUmpush {
  factory FlutterUmpush() => _instance;

  @visibleForTesting
  FlutterUmpush.private(MethodChannel channel, Platform platform)
      : _channel = channel,
        _platform = platform;

  static final FlutterUmpush _instance = new FlutterUmpush.private(
      const MethodChannel('flutter_umpush'), const LocalPlatform());

  final MethodChannel _channel;
  final Platform _platform;

  /// Sets up [MessageHandler] for incoming messages.
  Future<void> configure() async {
    await _channel.invokeMethod('configure');
  }

  Future<String> getToken() async {
    return await _channel.invokeMethod('getToken');
  }

  Future<String> getPushData() async {
    return await _channel.invokeMethod('getPushData');
  }
}
