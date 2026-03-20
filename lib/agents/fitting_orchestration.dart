import 'dart:developer' as developer;
import 'gemini_advisor.dart';

const List<String> sizeOrder = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
const String _defaultInventoryItemId = 'default-item';

class InventoryCheckResult {
  final bool inStock;
  final String requestedSize;
  final String? alternativeSize;
  final String message;

  const InventoryCheckResult({
    required this.inStock,
    required this.requestedSize,
    required this.message,
    this.alternativeSize,
  });
}

class FittingOrchestrationResult {
  final String suggestionText;
  final List<String> logs;

  const FittingOrchestrationResult({
    required this.suggestionText,
    required this.logs,
  });
}

class InventoryAgent {
  final Map<String, Map<String, int>> _mockInventory;

  InventoryAgent({Map<String, Map<String, int>>? inventoryData})
    : _mockInventory =
          inventoryData ??
          {
            _defaultInventoryItemId: {'S': 0, 'M': 0, 'L': 4, 'XL': 2},
            'fallback-item': {'M': 1, 'L': 0},
          };

  Future<InventoryCheckResult> checkInventory(
    String itemId,
    String desiredSize,
  ) async {
    try {
      final itemInventory =
          _mockInventory[itemId] ??
          _mockInventory[_defaultInventoryItemId] ??
          {};
      final normalizedDesiredSize = desiredSize.toUpperCase();

      if ((itemInventory[normalizedDesiredSize] ?? 0) > 0) {
        return InventoryCheckResult(
          inStock: true,
          requestedSize: normalizedDesiredSize,
          message: '$normalizedDesiredSizeサイズは現在在庫があります。',
        );
      }

      final alternative = _findAlternativeSize(
        desiredSize: normalizedDesiredSize,
        itemInventory: itemInventory,
      );

      if (alternative != null) {
        return InventoryCheckResult(
          inStock: false,
          requestedSize: normalizedDesiredSize,
          alternativeSize: alternative,
          message: '$normalizedDesiredSizeサイズは在庫切れですが、$alternativeサイズをご用意できます。',
        );
      }

      return InventoryCheckResult(
        inStock: false,
        requestedSize: normalizedDesiredSize,
        message: '$normalizedDesiredSizeサイズおよび代替サイズの在庫が現在ありません。',
      );
    } catch (e) {
      developer.log(
        '[InventoryAgent] checkInventory error',
        name: 'InventoryAgent',
        error: e,
      );
      return InventoryCheckResult(
        inStock: false,
        requestedSize: desiredSize.toUpperCase(),
        message: '在庫確認で問題が発生しました。時間をおいて再度お試しください。',
      );
    }
  }

  String? _findAlternativeSize({
    required String desiredSize,
    required Map<String, int> itemInventory,
  }) {
    final desiredIndex = sizeOrder.indexOf(desiredSize);
    if (desiredIndex == -1) {
      for (final size in sizeOrder) {
        if ((itemInventory[size] ?? 0) > 0) return size;
      }
      return null;
    }

    for (int i = desiredIndex + 1; i < sizeOrder.length; i++) {
      final size = sizeOrder[i];
      if ((itemInventory[size] ?? 0) > 0) return size;
    }

    for (int i = desiredIndex - 1; i >= 0; i--) {
      final size = sizeOrder[i];
      if ((itemInventory[size] ?? 0) > 0) return size;
    }

    return null;
  }
}

class FittingAgent {
  final InventoryAgent _inventoryAgent;
  final GeminiAdvisor? _geminiAdvisor;
  final double shoulderTolerance;

  FittingAgent({
    InventoryAgent? inventoryAgent,
    GeminiAdvisor? geminiAdvisor,
    this.shoulderTolerance = 2.0,
  }) : _inventoryAgent = inventoryAgent ?? InventoryAgent(),
       _geminiAdvisor = geminiAdvisor;

  Future<FittingOrchestrationResult> evaluateFitting({
    required double userShoulderWidth,
    required double clothShoulderWidth,
    required String currentSize,
    required String itemId,
  }) async {
    final logs = <String>[];

    try {
      logs.add(
        '[FittingAgent] 判定開始: user=$userShoulderWidth, cloth=$clothShoulderWidth, size=$currentSize, item=$itemId',
      );

      final diff = clothShoulderWidth - userShoulderWidth;
      if (diff.abs() <= shoulderTolerance) {
        logs.add('[FittingAgent] 適合判定: 現在のサイズで適合');

        String suggestion;
        if (_geminiAdvisor != null) {
          logs.add('[FittingAgent] Gemini APIを使ってパーフェクトフィットのテキストを生成します');
          suggestion = await _geminiAdvisor.generatePerfectFitSuggestion(
            currentSize: currentSize.toUpperCase(),
          );
        } else {
          suggestion =
              '\${currentSize.toUpperCase()}サイズは肩周りにぴったりフィットしています。このままご試着をお楽しみください！';
        }

        return FittingOrchestrationResult(
          suggestionText: suggestion,
          logs: logs,
        );
      }

      final isTooSmall = diff < 0;
      final desiredSize = _getNextSize(
        currentSize.toUpperCase(),
        isTooSmall: isTooSmall,
      );

      logs.add(
        '[FittingAgent] サイズ不適合を検知 (${isTooSmall ? "タイト" : "ルーズ"}) -> [InventoryAgent] へ$desiredSizeサイズの在庫照会',
      );

      final inventory = await _inventoryAgent.checkInventory(
        itemId,
        desiredSize,
      );
      logs.add('[InventoryAgent] 応答: ${inventory.message}');

      String suggestion;
      if (_geminiAdvisor != null) {
        logs.add('[FittingAgent] Gemini APIを使ってテキストを生成します');
        suggestion = await _geminiAdvisor.generateSuggestion(
          currentSize: currentSize.toUpperCase(),
          isTooSmall: isTooSmall,
          inStock: inventory.inStock,
          requestedSize: inventory.requestedSize,
          alternativeSize: inventory.alternativeSize,
        );
      } else {
        final fitReason = isTooSmall
            ? '\${currentSize.toUpperCase()}サイズは肩周りがタイトです。'
            : '\${currentSize.toUpperCase()}サイズは肩周りに余裕があります。';

        suggestion = _buildSuggestionText(fitReason, inventory);
      }

      return FittingOrchestrationResult(suggestionText: suggestion, logs: logs);
    } catch (e) {
      developer.log(
        '[FittingAgent] evaluateFitting error',
        name: 'FittingAgent',
        error: e,
      );
      logs.add('[FittingAgent] 予期しないエラーを検知。安全なフォールバックを返却');
      return FittingOrchestrationResult(
        suggestionText: 'サイズ提案の処理で問題が発生しました。しばらくしてから再度お試しください。',
        logs: logs,
      );
    }
  }

  String _getNextSize(String currentSize, {required bool isTooSmall}) {
    final index = sizeOrder.indexOf(currentSize);
    if (index == -1) return isTooSmall ? 'L' : 'S';

    if (isTooSmall) {
      final next = index + 1;
      return next < sizeOrder.length ? sizeOrder[next] : sizeOrder[index];
    }

    final prev = index - 1;
    return prev >= 0 ? sizeOrder[prev] : sizeOrder[index];
  }

  String _buildSuggestionText(
    String fitReason,
    InventoryCheckResult inventory,
  ) {
    if (inventory.inStock) {
      return '$fitReason ${inventory.requestedSize}サイズの在庫を確認したところ、現在すぐにご用意できます。${inventory.requestedSize}サイズを試着しますか？';
    }

    if (inventory.alternativeSize != null) {
      return '$fitReason ${inventory.requestedSize}サイズを確認したところ、${inventory.alternativeSize}サイズならご用意できます。${inventory.alternativeSize}サイズを試しますか？';
    }

    return '$fitReason 申し訳ありません。近いサイズの在庫が見つかりませんでした。';
  }
}
