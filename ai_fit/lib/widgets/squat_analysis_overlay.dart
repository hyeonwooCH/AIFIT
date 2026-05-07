import 'package:flutter/material.dart';
import 'package:ai_fit/widgets/squat_feedback_bar.dart';
import 'package:ai_fit/widgets/squat_counter_display.dart';

class SquatAnalysisOverlay extends StatelessWidget {
  final int count;
  final String state;
  final String feedback;
  final bool isSpineOk;
  final bool isKneeOk;
  final bool isStarted;
  final VoidCallback onStart;

  const SquatAnalysisOverlay({
    super.key,
    required this.count,
    required this.state,
    required this.feedback,
    required this.isSpineOk,
    required this.isKneeOk,
    required this.isStarted,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 카운터 숫자 (왼쪽 위로 이동!)
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          child: SquatCounterDisplay(
            count: count,
            state: state,
          ),
        ),

        // 2. 피드백 메시지 바 (왼쪽 아래 예시 이미지의 바로 옆으로 이동!)
        Positioned(
          bottom: 50, // 예시 이미지와 높이를 얼추 맞춤
          left: 160,  // 가이드 이미지가 차지하는 가로 공간(120) + 여백(40)을 피해서 배치
          right: 20,
          child: SquatFeedbackBar(
            message: feedback,
            isSpineOk: isSpineOk,
            isKneeOk: isKneeOk,
          ),
        ),

        // 3. 시작 버튼 레이어
        if (!isStarted)
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  onPressed: onStart,
                  child: const Text(
                    "운동 시작", 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}