import 'package:flutter/material.dart';

class SquatGuideView extends StatelessWidget {
  const SquatGuideView({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 흰색 배경과 텍스트를 모두 제거했습니다.
    // 2. 이미지가 박스에 꽉 차도록 fit: BoxFit.cover를 사용합니다.
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // 이미지가 없을 때를 대비한 반투명 검은 배경
      ),
      child: Image.asset(
        'assets/images/squat_guide.gif', // 준비하신 이미지나 gif 파일 이름으로 맞춰주세요!
        fit: BoxFit.cover, // 이미지가 비율을 유지하며 박스에 꽉 차게 (여백 없음)
        errorBuilder: (context, error, stackTrace) {
          // 만약 경로에 이미지가 없다면 흰 박스 대신 비디오 아이콘을 띄워줍니다.
          return const Center(
            child: Icon(Icons.video_library, color: Colors.white54, size: 40),
          );
        },
      ),
    );
  }
}