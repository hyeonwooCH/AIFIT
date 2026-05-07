import 'package:flutter/material.dart';

class SquatFeedbackBar extends StatelessWidget {
  final String message;
  final bool isSpineOk;
  final bool isKneeOk;

  const SquatFeedbackBar({
    super.key,
    required this.message,
    required this.isSpineOk,
    required this.isKneeOk,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: (isSpineOk && isKneeOk) 
            ? Colors.greenAccent.withOpacity(0.9) 
            : Colors.redAccent.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(blurRadius: 6, color: Colors.black45, offset: Offset(0, 3))
        ],
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center, // 텍스트가 짧아도 가운데 정렬
      ),
    );
  }
}