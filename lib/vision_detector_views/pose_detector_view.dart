// 画像を受け取って AI に渡し、その結果を描画用に整形する

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'dart:async';

import 'detector_view.dart';
import 'painters/pose_painter.dart';
import 'painters/clothes_painter.dart';
import '../agents/fitting_orchestration.dart';

class PoseDetectorView extends StatefulWidget {
  final bool isFirstLogin;
  // コンストラクタで受け取る
  const PoseDetectorView({super.key, required this.isFirstLogin});

  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  static const String _defaultCurrentSize = "M";

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  ); // ML Kitの姿勢検出（自分たちは骨格検出って言っているよ）エンジン本体
  bool _canProcess = true;
  bool _isBusy = false; // 前の画像の解析が終わっていないのに次の解析を始めないようにするためのフラグ
  CustomPaint? _customPaint; // 骨格検出の結果を描画するための情報が入る
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;

  // 一度サイズを保存したら何度もfirestoreに書き込まないためのフラグ
  bool _hasSavedSize = false;

  // ユーザーに表示するステータスメッセージ
  String _statusMessage = "準備中...";

  // 服の検索が完了したかどうかのフラグ
  bool _isClothesReady = false;

  // ARで表示する服の画像
  ui.Image? _clothesImage;
  // 選択された服のデータ
  Clothes? _selectedClothes;
  late final FittingAgent _fittingAgent;
  bool _hasRequestedSuggestion = false;
  String _agentSuggestionText = "";
  List<String> _agentLogs = [];

  @override
  void dispose() async {
    _canProcess = false; // ウィジェットが破棄された後に処理が走らないようにするためのフラグ
    _poseDetector.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fittingAgent = FittingAgent();
    _statusMessage = widget.isFirstLogin
        ? "骨格座標を取得中...."
        : "あなたに合う服を選んでいます....";

    // ⭐️ ターミナルへ出力
    print("📱現在のステータス: $_statusMessage");

    if (!widget.isFirstLogin) {
      _fetchClothesFromFirestore();
    }
  }

  // ⭐️ buildメソッドを修正し、Stackで画面上部にメッセージを重ねる
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          DetectorView(
            title: 'Pose Detector',
            customPaint: _customPaint,
            // (textは使わないので削除するか、ログ用として空にしておきます)
            onImage: _processImage,
            initialCameraLensDirection: _cameraLensDirection,
            onCameraLensDirectionChanged: (value) =>
                _cameraLensDirection = value,
          ),

          // --- ⬇︎追加：カメラの上にメッセージをオーバーレイ表示 ⬇︎---
          Positioned(
            top: 100, // 上からの位置（カメラのUIと被らないように調整）
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7), // 半透明の黒背景
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          if (_agentSuggestionText.isNotEmpty || _agentLogs.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_agentSuggestionText.isNotEmpty)
                      Text(
                        _agentSuggestionText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (_agentLogs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._agentLogs.map(
                        (log) => Text(
                          log,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // --- ⬆︎ここまで ⬆︎---
        ],
      ),
    );
  }

  // カメラやギャラリーから画像が届くたびに実行される非同期メソッド
  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() => _text = '');

    // AI が画像内のポーズ（関節の位置など）を検出する
    final poses = await _poseDetector.processImage(inputImage);

    // ======================================
    // 【初回のサイズ計測と保存処理】
    // ======================================
    if (widget.isFirstLogin && !_hasSavedSize && poses.isNotEmpty) {
      final pose = poses.first; // 最初のひとり
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

      // 肩がしっかり検出できている場合
      if (leftShoulder != null && rightShoulder != null) {
        // [1] 肩幅のピクセル距離を計算
        final dx = leftShoulder.x - rightShoulder.x;
        final dy = leftShoulder.y - rightShoulder.y;
        final baseShoulderWidthPx = sqrt(dx * dx + dy * dy);

        // 誤検出を防ぐため、ある程度の大きさになってから保存する
        if (baseShoulderWidthPx > 50) {
          _hasSavedSize = true; // これ以降は同じ処理が呼ばれないようにフラグを立てる

          //  修正: awaitで_processImage自体を止めず、非同期ブロックとして分離する
          () async {
            // 演出のため、意図的に5秒間ほど骨格を描画し続ける（待機する）
            await Future.delayed(const Duration(seconds: 5));

            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set({
                    'baseShoulderWidthPx': baseShoulderWidthPx,
                  }, SetOptions(merge: true));

              // 計測が完了したら切り替え
              if (mounted) {
                setState(() {
                  _statusMessage = "あなたに合う服を選んでいます....";
                });
                //  ターミナルへ出力
                print("保存完了: 肩幅 $baseShoulderWidthPx");
                print("現在のステータス: $_statusMessage");
              }
              await _fetchClothesFromFirestore(baseShoulderWidthPx);
            }
          }(); // 即時実行関数として呼び出す
        }
      }
    }

    if (_isClothesReady &&
        !_hasRequestedSuggestion &&
        poses.isNotEmpty &&
        _selectedClothes != null) {
      final pose = poses.first;
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      if (leftShoulder != null && rightShoulder != null) {
        _hasRequestedSuggestion = true;
        final dx = leftShoulder.x - rightShoulder.x;
        final dy = leftShoulder.y - rightShoulder.y;
        final userShoulderWidth = sqrt(dx * dx + dy * dy);
        final result = await _fittingAgent.evaluateFitting(
          userShoulderWidth: userShoulderWidth,
          clothShoulderWidth: _selectedClothes!.baseShoulderWidthPx.toDouble(),
          currentSize: _defaultCurrentSize,
          itemId: _selectedClothes!.id,
        );
        if (mounted) {
          setState(() {
            _agentSuggestionText = result.suggestionText;
            _agentLogs = result.logs;
            _statusMessage = result.suggestionText;
          });
        }
      }
    }

    // ======================================
    // 【描画の切り替え処理】
    // ======================================
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      // 【修正】服の処理が終わるまでは骨格を描画する
      if (widget.isFirstLogin && !_isClothesReady) {
        // [状態1＆2] サイズ計測中＆検索中：ずっと骨格を描画し続ける
        final painter = PosePainter(
          poses,
          inputImage.metadata!.size,
          inputImage.metadata!.rotation,
          _cameraLensDirection,
        );
        _customPaint = CustomPaint(painter: painter);
      } else if (!_isClothesReady) {
        // （2回目以降のログイン時）骨格を描かないための処理
        _customPaint = null;
        _text = _statusMessage;
      } else {
        // [状態3] 服の準備完了：服を描画する
        if (_clothesImage != null && _selectedClothes != null) {
          final painter = ClothesPainter(
            poses,
            inputImage.metadata!.size,
            inputImage.metadata!.rotation,
            _cameraLensDirection,
            _clothesImage!,
            _selectedClothes!.baseShoulderWidthPx,
          );
          _customPaint = CustomPaint(painter: painter);
        } else {
          _customPaint = null;
        }
        _text = "";
      }
    } else {
      _text = 'Poses found: ${poses.length}\n\n';
      _customPaint = null;
    }

    _isBusy = false;
    if (mounted) setState(() {});
  }

  // 服の取得処理 (Dartでは同名メソッドの複数定義ができないため、引数を [] でオプショナルにしました)
  Future<void> _fetchClothesFromFirestore([double? baseShoulderWidthPx]) async {
    try {
      // APIなどから服のデータを取得する想定の処理
      final clothes = await FirebaseFirestore.instance
          .collection('clothes')
          .get();

      // 例: 服のデータを処理
      final List<Clothes> clothesList = clothes.docs
          .map((doc) => Clothes.fromFirestore(doc))
          .toList();

      print("🔥 Firestoreから服を ${clothesList.length} 件取得しました");

      String imageUrl = "";
      if (clothesList.isNotEmpty) {
        // 服を選ぶ（今回は一番目の服、もしくはサイズが最も近い服など）
        // ここでは簡単に最初の服を選択
        _selectedClothes = clothesList.first;
        if (_selectedClothes!.imageUrl.isNotEmpty) {
          imageUrl = _selectedClothes!.imageUrl;
          print("👕 服の画像URL: $imageUrl");
        } else {
          throw Exception("服の画像URLが空です");
        }
      } else {
        throw Exception("Firestoreに服のデータが存在しません");
      }

      // 画像をダウンロードして ui.Image に変換
      final image = await _loadImageFromUrl(imageUrl);

      if (mounted) {
        setState(() {
          _clothesImage = image;
          _isClothesReady = true;
          _statusMessage = "服の準備が完了しました！";
          _hasRequestedSuggestion = false;
          _agentSuggestionText = "";
          _agentLogs = [];
        });
        // ⭐️ ターミナルへ出力
        print("📱現在のステータス: $_statusMessage");
      }
    } catch (e) {
      print("服の取得エラー: $e");
      if (mounted) {
        setState(() {
          _statusMessage = "服の取得に失敗しました。";
        });
      }
    }
  }

  Future<ui.Image> _loadImageFromUrl(String url) async {
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

// 簡易的な服のデータモデルクラス（エラー回避のためのダミー実装です。実際の実装に合わせて調整してください）
class Clothes {
  final String id;
  final String imageUrl;
  final String itemName;
  final String brandName;
  final num baseShoulderWidthPx;

  Clothes({
    required this.id,
    this.imageUrl = "",
    this.itemName = "",
    this.brandName = "",
    this.baseShoulderWidthPx = 0,
  });

  factory Clothes.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Clothes(
      id: doc.id,
      imageUrl: data?['imageUrl'] ?? "",
      itemName: data?['itemName'] ?? "",
      brandName: data?['brandName'] ?? "",
      baseShoulderWidthPx: data?['baseShoulderWidthPx'] ?? 0,
    );
  }
}
