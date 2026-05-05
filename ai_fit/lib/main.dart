import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'app_layout.dart';

// 2. [수정] main 함수를 비동기(async)로 바꾸고 초기화 코드 2줄 추가
void main() async {
  // 앱이 시작되기 전에 Flutter 엔진이 준비되도록 보장하는 코드
  WidgetsFlutterBinding.ensureInitialized();
  
  // 한국어 날짜 형식 데이터 초기화 (이 코드가 바로 에러를 해결해 줍니다!)
  await initializeDateFormatting('ko_KR', null);
  
  runApp(const AIFitApp());
}

class AIFitApp extends StatelessWidget {
  const AIFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AIFIT',
      theme: ThemeData.dark(),
      home: const AppLayout(),
    );
  }
}