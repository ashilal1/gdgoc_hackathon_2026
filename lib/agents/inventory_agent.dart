import 'dart:developer' as developer;

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
