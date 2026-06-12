import 'package:flutter/services.dart';

class ShellEventChannel {
  static const EventChannel _channel =
      EventChannel('com.example.sshku/shell_output');

  Stream<String> get outputStream =>
      _channel.receiveBroadcastStream().map((event) => event as String);
}
