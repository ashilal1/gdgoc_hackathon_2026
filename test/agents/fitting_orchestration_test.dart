import 'package:flutter_test/flutter_test.dart';
import 'package:gdgoc_hackathon_2026/agents/fitting_orchestration.dart';
import 'package:gdgoc_hackathon_2026/agents/inventory_agent.dart';

void main() {
  group('InventoryAgent', () {
    test('returns inStock=true when desired size exists', () async {
      final agent = InventoryAgent(
        inventoryData: {
          'item-1': {'M': 2, 'L': 0},
        },
      );

      final result = await agent.checkInventory('item-1', 'M');

      expect(result.inStock, isTrue);
      expect(result.requestedSize, 'M');
      expect(result.alternativeSize, isNull);
    });

    test(
      'returns alternative size when desired size is not available',
      () async {
        final agent = InventoryAgent(
          inventoryData: {
            'item-2': {'M': 0, 'L': 3},
          },
        );

        final result = await agent.checkInventory('item-2', 'M');

        expect(result.inStock, isFalse);
        expect(result.requestedSize, 'M');
        expect(result.alternativeSize, 'L');
      },
    );
  });

  group('FittingAgent', () {
    test(
      'returns fit suggestion when shoulder width is within tolerance',
      () async {
        final agent = FittingAgent(
          inventoryAgent: InventoryAgent(
            inventoryData: {
              'item-3': {'M': 1},
            },
          ),
        );

        final result = await agent.evaluateFitting(
          userShoulderWidth: 42,
          clothShoulderWidth: 43,
          currentSize: 'M',
          itemId: 'item-3',
        );

        expect(result.suggestionText, contains('Mサイズは肩周りにフィット'));
        expect(
          result.logs.any((log) => log.contains('[FittingAgent] 適合判定')),
          isTrue,
        );
      },
    );

    test('orchestrates inventory check when fitting is too tight', () async {
      final agent = FittingAgent(
        inventoryAgent: InventoryAgent(
          inventoryData: {
            'item-4': {'L': 2},
          },
        ),
      );

      final result = await agent.evaluateFitting(
        userShoulderWidth: 45,
        clothShoulderWidth: 40,
        currentSize: 'M',
        itemId: 'item-4',
      );

      expect(result.suggestionText, contains('Mサイズは肩周りがタイト'));
      expect(result.suggestionText, contains('Lサイズ'));
      expect(
        result.logs.any((log) => log.contains('[InventoryAgent] 応答')),
        isTrue,
      );
    });
  });
}
