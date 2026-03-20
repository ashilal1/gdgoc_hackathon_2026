import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageUtils {
  static Future<ui.Image> loadImageFromUrl(String url) async {
    final ImageStream stream = NetworkImage(
      url,
    ).resolve(ImageConfiguration.empty);
    final Completer<ui.Image> completer = Completer();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
        }
        stream.removeListener(listener);
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(exception);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}
