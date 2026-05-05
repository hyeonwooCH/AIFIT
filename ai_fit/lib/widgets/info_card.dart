import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InfoCard extends StatelessWidget {
  final Widget child;
  const InfoCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(top: 15, bottom: 7), // 카드 사이 간격
      decoration: BoxDecoration(
        color: AppTheme.cardColor, // 반투명한 흰색
        borderRadius: BorderRadius.circular(20),
        // [디테일] 아주 얇은 흰색 테두리가 '유리' 느낌의 핵심입니다!
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
      ),
      child: child,
    );
  }
}