import 'package:flutter/services.dart';

class KeystorePlatformChannel {
  static const _channel = MethodChannel('com.example.sshku/keys');

  Future<String> encrypt(String data) async {
    final result = await _channel.invokeMethod<String>('encrypt', {'data': data});
    return result!;
  }

  Future<String> decrypt(String data) async {
    final result = await _channel.invokeMethod<String>('decrypt', {'data': data});
    return result!;
  }

  Future<Map<String, dynamic>> importKey(String keyContent, {String? passphrase}) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('importKey', {
      'keyContent': keyContent,
      'passphrase': passphrase,
    });
    return result!;
  }

  Future<Map<String, String>> generateKey({
    required String type,
    int? bits,
    required String comment,
  }) async {
    final result = await _channel.invokeMapMethod<String, String>('generateKey', {
      'type': type,
      if (bits != null) 'bits': bits,
      'comment': comment,
    });
    return result!;
  }

  Future<String> getPublicKey(String encryptedPrivateKey) async {
    final result = await _channel.invokeMethod<String>('getPublicKey', {
      'encryptedPrivateKey': encryptedPrivateKey,
    });
    return result!;
  }
}
