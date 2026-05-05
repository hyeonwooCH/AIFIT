import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroundColor = Color(0xFF141E30); // 짙은 남색
  static const Color cardColor = Color(0x22FFFFFF); // [핵심] 아주 투명한 흰색 (유리 느낌)
  static const Color primaryBlue = Colors.lightBlueAccent;

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: 'Pretendard',
  );
}