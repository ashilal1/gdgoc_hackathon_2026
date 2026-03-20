import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class CameraImageConverter {
  Uint8List? _reusablePlaneBuffer;
  Uint8List? _reusableNv21Buffer;
  int _lastNv21Size = 0;

  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? convert(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // フロントカメラ
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // 後ろのカメラ
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }

    const androidSupportedFormats = [
      InputImageFormat.nv21,
      InputImageFormat.yv12,
      InputImageFormat.yuv_420_888,
    ];

    if ((Platform.isAndroid && !androidSupportedFormats.contains(format)) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    InputImageFormat resolvedFormat = format;
    final Uint8List bytes;

    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
    } else if (Platform.isAndroid &&
        (format == InputImageFormat.yuv_420_888 ||
            format == InputImageFormat.yv12) &&
        image.planes.length == 3) {
      bytes = _convertYUV420ToNV21(image);
      resolvedFormat = InputImageFormat.nv21;
    } else {
      bytes = _concatenatePlanes(image);
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: resolvedFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(CameraImage image) {
    final int totalBytes = image.planes.fold<int>(
      0,
      (int sum, Plane plane) => sum + plane.bytes.length,
    );

    var buffer = _reusablePlaneBuffer;
    if (buffer == null || buffer.length < totalBytes) {
      buffer = Uint8List(totalBytes);
      _reusablePlaneBuffer = buffer;
    }

    var offset = 0;
    for (final Plane plane in image.planes) {
      final bytes = plane.bytes;
      buffer.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
    }

    if (totalBytes == buffer.length) {
      return buffer;
    }
    return Uint8List.sublistView(buffer, 0, totalBytes);
  }

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;
    final int requiredSize = ySize + uvSize;

    if (_reusableNv21Buffer == null || _lastNv21Size != requiredSize) {
      _reusableNv21Buffer = Uint8List(requiredSize);
      _lastNv21Size = requiredSize;
    }

    final Uint8List nv21 = _reusableNv21Buffer!;

    final Plane yPlane = image.planes[0];
    int destIndex = 0;
    for (int row = 0; row < height; row++) {
      final int srcRowStart = row * yPlane.bytesPerRow;
      nv21.setRange(destIndex, destIndex + width, yPlane.bytes, srcRowStart);
      destIndex += width;
    }

    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    int uvIndex = ySize;
    for (int row = 0; row < height ~/ 2; row++) {
      final int uRowStart = row * uPlane.bytesPerRow;
      final int vRowStart = row * vPlane.bytesPerRow;

      for (int col = 0; col < width ~/ 2; col++) {
        final int uIndex = uRowStart + col * uvPixelStride;
        final int vIndex = vRowStart + col * vPixelStride;

        nv21[uvIndex++] = vPlane.bytes[vIndex];
        nv21[uvIndex++] = uPlane.bytes[uIndex];
      }
    }

    return nv21;
  }
}
