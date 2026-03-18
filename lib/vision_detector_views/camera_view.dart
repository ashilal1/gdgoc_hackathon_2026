// スマートフォンのカメラを制御し、リアルタイムの映像をMlKitに渡すウィジェット

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class CameraView extends StatefulWidget {
  CameraView({
    super.key,
    required this.customPaint,
    required this.onImage,
    this.onCameraFeedReady,
    this.onDetectorViewModeChanged,
    this.onCameraLensDirectionChanged,
    this.initialCameraLensDirection = CameraLensDirection.back,
  });

  final CustomPaint? customPaint;
  final Function(InputImage inputImage) onImage;
  final VoidCallback? onCameraFeedReady;
  final VoidCallback? onDetectorViewModeChanged;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  // アプリ全体で一度取得すれば使い回せるからstaticでいい
  static List<CameraDescription> _cameras = []; // 利用可能なカメラリスト
  CameraController? _controller;
  int _cameraIndex = -1; // 現在使用中のカメラ番号
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  bool _changingCameraLens = false;

  @override
  void initState() {
    super.initState();
    _initialize(); // 開始時にカメラを準備
  }

  // 利用可能なカメラ（前面・背面）を確認し、指定されたカメラ（デフォルトは背面）を準備する
  void _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras(); // デバイスのカメラを探す
    }
    // 指定された向き（背面/前面）のカメラを選択する
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _liveFeedBody());
  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty) return Container();
    if (_controller == null) return Container();
    if (_controller?.value.isInitialized == false) return Container();
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: _changingCameraLens
                ? Center(child: const Text('Changing camera lens'))
                : CameraPreview(_controller!, child: widget.customPaint),
          ),
          _backButton(),
          _switchLiveCameraToggle(),
          _detectionViewModeToggle(),
          _zoomControl(),
          _exposureControl(),
        ],
      ),
    );
  }

  Widget _backButton() => Positioned(
    top: 40,
    left: 8,
    child: SizedBox(
      height: 50.0,
      width: 50.0,
      child: FloatingActionButton(
        heroTag: Object(),
        onPressed: () => Navigator.of(context).pop(),
        backgroundColor: Colors.black54,
        child: Icon(Icons.arrow_back_ios_outlined, size: 20),
      ),
    ),
  );

  Widget _detectionViewModeToggle() => Positioned(
    bottom: 8,
    left: 8,
    child: SizedBox(
      height: 50.0,
      width: 50.0,
      child: FloatingActionButton(
        heroTag: Object(),
        onPressed: widget.onDetectorViewModeChanged,
        backgroundColor: Colors.black54,
        child: Icon(Icons.photo_library_outlined, size: 25),
      ),
    ),
  );

  Widget _switchLiveCameraToggle() => Positioned(
    bottom: 8,
    right: 8,
    child: SizedBox(
      height: 50.0,
      width: 50.0,
      child: FloatingActionButton(
        heroTag: Object(),
        onPressed: _switchLiveCamera,
        backgroundColor: Colors.black54,
        child: Icon(
          Platform.isIOS
              ? Icons.flip_camera_ios_outlined
              : Icons.flip_camera_android_outlined,
          size: 25,
        ),
      ),
    ),
  );

  Widget _zoomControl() => Positioned(
    bottom: 16,
    left: 0,
    right: 0,
    child: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 250,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Slider(
                value: _currentZoomLevel,
                min: _minAvailableZoom,
                max: _maxAvailableZoom,
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
                onChanged: (value) async {
                  setState(() {
                    _currentZoomLevel = value;
                  });
                  final controller = _controller;
                  if (controller == null || !controller.value.isInitialized) {
                    return;
                  }
                  try {
                    await controller.setZoomLevel(value);
                  } on CameraException {
                    return;
                  }
                },
              ),
            ),
            Container(
              width: 50,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    '${_currentZoomLevel.toStringAsFixed(1)}x',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _exposureControl() => Positioned(
    top: 40,
    right: 8,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 250),
      child: Column(
        children: [
          Container(
            width: 55,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '${_currentExposureOffset.toStringAsFixed(1)}x',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                height: 30,
                child: Slider(
                  value: _currentExposureOffset,
                  min: _minAvailableExposureOffset,
                  max: _maxAvailableExposureOffset,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                  onChanged: (value) async {
                    setState(() {
                      _currentExposureOffset = value;
                    });
                    final controller = _controller;
                    if (controller == null || !controller.value.isInitialized) {
                      return;
                    }
                    try {
                      await controller.setExposureOffset(value);
                    } on CameraException {
                      return;
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // CameraController を作成し、解像度（ResolutionPreset.high）や画像フォーマットを設定してカメラを開始する
  // 画像フォーマット（AndroidはNV21、iOSはBGRA8888）
  Future _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high, // 高解像度でカメラを起動する（解析の精度が上がる）
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMinZoomLevel().then((value) {
        _currentZoomLevel = value;
        _minAvailableZoom = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        _maxAvailableZoom = value;
      });
      _currentExposureOffset = 0.0;
      _controller?.getMinExposureOffset().then((value) {
        _minAvailableExposureOffset = value;
      });
      _controller?.getMaxExposureOffset().then((value) {
        _maxAvailableExposureOffset = value;
      });
      // 映像ストリームを開始し、1フレームごとに _processCameraImageを呼ぶ
      _controller?.startImageStream(_processCameraImage).then((value) {
        if (widget.onCameraFeedReady != null) {
          widget.onCameraFeedReady!();
        }
        if (widget.onCameraLensDirectionChanged != null) {
          widget.onCameraLensDirectionChanged!(camera.lensDirection);
        }
      });
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;

    await _stopLiveFeed();
    await _startLiveFeed();
    setState(() => _changingCameraLens = false);
  }

  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage);
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /*
   1. デバイスの向きから回転角度を計算
   2. 画像フォーマットの整合性を確認
   3. バイトデータを InputImage 形式に変換
*/
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
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
      print('could not find format from raw value: ${image.format.raw}');
      return null;
    }

    const androidSupportedFormats = [
      InputImageFormat.nv21,
      InputImageFormat.yv12,
      InputImageFormat.yuv_420_888,
    ];

    if ((Platform.isAndroid && !androidSupportedFormats.contains(format)) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      print('image format is not supported: $format');
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

  Uint8List? _reusablePlaneBuffer;

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

  Uint8List? _reusableNv21Buffer;
  int _lastNv21Size = 0;
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
