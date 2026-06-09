import 'dart:io';

import 'package:flutter/services.dart';

class MediaProjectionFgs {
  MediaProjectionFgs._();

  static const _channel = MethodChannel('internview/media_projection_fgs');

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('start');
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('stop');
  }
}

