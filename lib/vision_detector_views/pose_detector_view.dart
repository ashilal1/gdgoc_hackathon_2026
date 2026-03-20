// 画像を受け取って AI に渡し、その結果を描画用に整形する

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'detector_view.dart';
import 'painters/pose_painter.dart';
import 'painters/clothes_painter.dart';
import '../agents/fitting_orchestration.dart';
import '../agents/gemini_advisor.dart';
import '../models/clothes.dart';
import '../repositories/clothes_repository.dart';
import '../repositories/user_repository.dart';
import '../utils/image_utils.dart';
import 'widgets/status_overlay.dart';
import 'widgets/suggestion_overlay.dart';

class PoseDetectorView extends StatefulWidget {
  final bool isFirstLogin;
  // コンストラクタで受け取る
  const PoseDetectorView({super.key, required this.isFirstLogin});

  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  // MVPではFirestoreにサイズ列がないため、初期評価サイズを M として扱う。
  // 商品ごとのサイズ情報を持たせる実装にした場合は、ここを動的値に置き換える。
  static const String _initialFittingSize = "M";

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  ); // ML Kitの姿勢検出（自分たちは骨格検出って言っているよ）エンジン本体
  bool _canProcess = true;
  bool _isBusy = false; // 前の画像の解析が終わっていないのに次の解析を始めないようにするためのフラグ
  CustomPaint? _customPaint; // 骨格検出の結果を描画するための情報が入る
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
  final ClothesRepository _clothesRepository = ClothesRepository();
  final UserRepository _userRepository = UserRepository();
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
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _fittingAgent = FittingAgent(
      geminiAdvisor: geminiApiKey.isNotEmpty
          ? GeminiAdvisor(apiKey: geminiApiKey)
          : null,
    );
    _statusMessage = widget.isFirstLogin
        ? "骨格座標を取得中...."
        : "あなたに合う服を選んでいます....";

    // ⭐️ ターミナルへ出力
    print("📱現在のステータス: $_statusMessage");

    if (!widget.isFirstLogin) {
      _fetchClothesFromFirestore();
    }
  }

  //  Stackで画面上部にメッセージを重ねる
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          DetectorView(
            title: 'Pose Detector',
            customPaint: _customPaint,
            onImage: _processImage,
            initialCameraLensDirection: _cameraLensDirection,
            onCameraLensDirectionChanged: (value) =>
                _cameraLensDirection = value,
          ),

          StatusOverlay(message: _statusMessage),
          SuggestionOverlay(
            suggestionText: _agentSuggestionText,
            logs: _agentLogs,
          ),
        ],
      ),
    );
  }

  // カメラやギャラリーから画像が届くたびに実行される非同期メソッド
  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;

    // AI が画像内のポーズ（関節の位置など）を検出する
    final poses = await _poseDetector.processImage(inputImage);

    // 初回のサイズ計測と保存処理
    if (widget.isFirstLogin && !_hasSavedSize && poses.isNotEmpty) {
      final pose = poses.first; // 最初のひとり
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

      // 肩がしっかり検出できている場合
      if (leftShoulder != null && rightShoulder != null) {
        // 肩幅のピクセル距離を計算
        final dx = leftShoulder.x - rightShoulder.x;
        final dy = leftShoulder.y - rightShoulder.y;
        final baseShoulderWidthPx = sqrt(dx * dx + dy * dy);

        // 誤検出を防ぐため、ある程度の大きさになってから保存する
        if (baseShoulderWidthPx > 50) {
          _hasSavedSize = true; // これ以降は同じ処理が呼ばれないようにフラグを立てる

          //  awaitで_processImage自体を止めずに、非同期ブロックとして分離する
          () async {
            // 演出のため、意図的に5秒間ほど骨格を描画し続ける（待機する）
            await Future.delayed(const Duration(seconds: 5));

            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await _userRepository.saveUserShoulderWidth(
                user.uid,
                baseShoulderWidthPx,
              );

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
        try {
          final result = await _fittingAgent.evaluateFitting(
            userShoulderWidth: userShoulderWidth,
            clothShoulderWidth: _selectedClothes!.baseShoulderWidthPx
                .toDouble(),
            currentSize: _initialFittingSize,
            itemId: _selectedClothes!.id,
          );
          if (mounted) {
            setState(() {
              _agentSuggestionText = result.suggestionText;
              _agentLogs = result.logs;
            });
          }
        } catch (e) {
          print("FittingAgent評価エラー: $e");
          if (mounted) {
            setState(() {
              _agentSuggestionText = "サイズ提案の処理で問題が発生しました。しばらくしてから再度お試しください。";
              _agentLogs = ['[FittingAgent] 評価処理で例外を検知。フォールバックを表示: $e'];
            });
          }
        }
      }
    }

    // 描画の切り替え処理
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      // 服の処理が終わるまでは骨格を描画する
      if (widget.isFirstLogin && !_isClothesReady) {
        // サイズ計測中＆検索中：ずっと骨格を描画し続ける
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
      } else {
        //  服の準備完了：服を描画する
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
      }
    } else {
      _customPaint = null;
    }

    _isBusy = false;
    if (mounted) setState(() {});
  }

  // 服の取得処理 (Dartでは同名メソッドの複数定義ができないため、引数を [] でオプショナルにしてみた)
  Future<void> _fetchClothesFromFirestore([double? baseShoulderWidthPx]) async {
    try {
      // APIなどから服のデータを取得する想定の処理
      final List<Clothes> clothesList = await _clothesRepository.fetchClothes();

      print("Firestoreから服を ${clothesList.length} 件取得しました");

      String imageUrl = "";
      if (clothesList.isNotEmpty) {
        // 服を選ぶ
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
      final image = await ImageUtils.loadImageFromUrl(imageUrl);

      if (mounted) {
        setState(() {
          _clothesImage = image;
          _isClothesReady = true;
          _statusMessage = "服の準備が完了しました！";
          _resetAgentState();
        });
        // ターミナルへ出力
        print("現在のステータス: $_statusMessage");
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

  void _resetAgentState() {
    _hasRequestedSuggestion = false;
    _agentSuggestionText = "";
    _agentLogs = [];
  }
}
