import 'package:flutter/material.dart';

class StatusOverlay extends StatelessWidget {
  final String message;

  const StatusOverlay({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100, // 上からの位置（カメラのUIと被らないように調整）
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7), // 半透明の黒背景
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
