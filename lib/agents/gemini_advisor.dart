import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:developer' as developer;

class GeminiAdvisor {
  final GenerativeModel _model;

  GeminiAdvisor({required String apiKey})
    : _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

  Future<String> generateSuggestion({
    required String currentSize,
    required bool isTooSmall,
    required bool inStock,
    required String requestedSize,
    String? alternativeSize,
  }) async {
    final fitReason = isTooSmall ? 'タイトで窮屈そう' : '全体的にゆとりがありそう';

    final prompt =
        '''
あなたは高級感のある、かつ親しみやすいアパレルブランドの優秀な店員です。
試着室にいるお客様に、以下の情報に基づいて自然で丁寧なサイズ提案をしてください。

【状況】
- 現在試着中のサイズ: $currentSize
- 現在のフィット感: 肩周りが$fitReasonです。
- 提案したい理想のサイズ: $requestedSize
- 理想のサイズの在庫: ${inStock ? 'あり' : 'なし'}
- 代替で提案できるサイズ: ${alternativeSize ?? 'なし'}

【出力のルール】
1. まず、現在のサイズ感について優しく共感・指摘してください。（例：「肩周りが少し窮屈そうですね」「少しゆとりがあるようですね」）
2. その後、在庫状況に応じて試着すべきサイズを提案してください。
3. お客様が気持ちよく次の試着に進めるように励ましてください。
4. 出力はプレーンテキストのみで、100文字〜150文字程度。
5. 【重要】変数の値（M, Lなど）は使ってもよいですが、システム内部の数値や小数は絶対に使わないでください。
6. 返答には余計な記号（* や -）や、システム的な不要な改行を含めないでください。
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ??
          _getFallbackText(isTooSmall, requestedSize);
    } catch (e) {
      developer.log(
        '[GeminiAdvisor] API Error',
        name: 'GeminiAdvisor',
        error: e,
      );
      return _getFallbackText(isTooSmall, requestedSize);
    }
  }

  String _getFallbackText(bool isTooSmall, String requestedSize) {
    final fitStatus = isTooSmall ? 'タイト' : 'ルーズ';
    return '現在のサイズは少し$fitStatusなようです。$requestedSizeサイズをお持ちしましょうか？';
  }

  Future<String> generatePerfectFitSuggestion({
    required String currentSize,
  }) async {
    final prompt =
        '''
あなたは高級感のある、かつ親しみやすいアパレルブランドの優秀な店員です。
試着室にいるお客様に、自然で丁寧な声かけをしてください。

【状況】
- お客様は${currentSize}サイズを試着中で、肩周りのサイズはぴったりです。

【出力のルール】
1. 現在の試着サイズ（${currentSize}）がお客様の体型にぴったり合っていることを褒めてください。（例：「お似合いですね」「ぴったりですね」）
2. このまま試着を楽しんでいただけるよう、温かい言葉をかけてください。
3. 出力はプレーンテキストのみで、50文字〜100文字程度。
4. 【重要】数値や小数は絶対に使わないでください。返答に余計な記号や改行を含めないでください。
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ??
          '${currentSize}サイズでお体にぴったりフィットしていますね。このままご試着をお楽しみください！';
    } catch (e) {
      developer.log(
        '[GeminiAdvisor] API Error (PerfectFit)',
        name: 'GeminiAdvisor',
        error: e,
      );
      return '${currentSize}サイズでお体にぴったりフィットしていますね。このままご試着をお楽しみください！';
    }
  }
}
