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
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 80, // X 버튼 공간 확보
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: (isSpineOk && isKneeOk) 
              ? Colors.greenAccent.withOpacity(0.8) 
              : Colors.redAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}