import 'package:flutter/material.dart';

class SuggestionOverlay extends StatelessWidget {
  final String suggestionText;
  final List<String> logs;

  const SuggestionOverlay({
    super.key,
    required this.suggestionText,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestionText.isEmpty && logs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggestionText.isNotEmpty)
              Text(
                suggestionText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (logs.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...logs.map(
                (log) => Text(
                  log,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
