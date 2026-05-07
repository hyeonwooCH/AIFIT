import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses; // 감지된 포즈들
  final Size absoluteImageSize; // 원본 이미지 크기
  final InputImageRotation rotation; // 회전 정보 (InputVideoRotation이 아니라 InputImageRotation입니다!)

  PosePainter(this.poses, this.absoluteImageSize, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.greenAccent;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    for (final pose in poses) {
      // 모든 관절 포인트를 순회하며 그리기
      pose.landmarks.forEach((type, landmark) {
        // 좌표 변환: 분석 이미지 좌표를 현재 폰 화면 크기에 맞게 계산
        final x = landmark.x * size.width / absoluteImageSize.width;
        final y = landmark.y * size.height / absoluteImageSize.height;

        canvas.drawCircle(Offset(x, y), 4, dotPaint);
      });

      // ... 기존 dots 그리기 반복문 (pose.landmarks.forEach) 끝나는 지점 바로 아래

      // ✨ [추가] 관절 사이의 선 그리기 (webcam_test.py의 POSE_CONNECTIONS 로직)
      final paintLine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.greenAccent.withOpacity(0.8);

      // 연결할 관절 번호 쌍 정의
      final connections = [
        [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder], // 어깨
        [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],       // 왼쪽 상체
        [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],     // 오른쪽 상체
        [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],           // 골반
        [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],     // 왼팔
        [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
        [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],   // 오른팔
        [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
        [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],           // 왼다리
        [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
        [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],         // 오른다리
        [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      ];

      for (final connection in connections) {
        final startLandmark = pose.landmarks[connection[0]];
        final endLandmark = pose.landmarks[connection[1]];

        if (startLandmark != null && endLandmark != null) {
          final startX = startLandmark.x * size.width / absoluteImageSize.width;
          final startY = startLandmark.y * size.height / absoluteImageSize.height;
          final endX = endLandmark.x * size.width / absoluteImageSize.width;
          final endY = endLandmark.y * size.height / absoluteImageSize.height;

          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paintLine);
        }
      }

      // ... 하단의 'AI.FIT SQUAT ANALYZER' 텍스트 레이아웃 코드 시작

      // 점수판 UI (webcam_test.py의 디자인 참고)
      /*final textPainter = TextPainter(
        text: const TextSpan(
          text: 'AI.FIT SQUAT ANALYZER',
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, const Offset(20, 50));*/
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.poses != poses;
  }
}