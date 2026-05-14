import 'package:flutter/material.dart';
import 'camera_squirt.dart'; // 조금 뒤에 만들 카메라 화면

class GuideScreen extends StatelessWidget {
  final String exerciseName;

  const GuideScreen({super.key, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141E30), // 다크 테마 배경
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('$exerciseName 가이드'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.accessibility_new, size: 100, color: Colors.lightBlueAccent),
            const SizedBox(height: 30),
            const Text(
              '스마트폰을 가로로 눕혀주세요.',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text(
              '머리부터 발끝까지 전신이\n화면에 나오도록 거리를 조절해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 50),
            
            // 촬영 시작 버튼
            ElevatedButton(
              onPressed: () {
                // 촬영 화면으로 이동!
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                '촬영 시작하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}