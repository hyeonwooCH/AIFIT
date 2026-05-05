import 'package:flutter/material.dart';

class StatCircle extends StatelessWidget {
  final String label;
  final String value;
  final String subValue;
  final Color color;
  final double size;

  const StatCircle({
    super.key,
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    // 이제 밖을 감싸던 Column과 아래쪽 Text를 지웁니다.
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle, 
        border: Border.all(color: color, width: size * 0.06)
      ),
      // [핵심] 원의 중심에 두 줄의 텍스트를 세로로 배치합니다.
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 세로 중앙 정렬
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label, // "섭취칼로리", "소모칼로리", "운동시간"
              style: TextStyle(fontSize: size * 0.12, color: Colors.white70, height: 1.0),
            ),
          ],
          Text(
            value, // "1500", "550", "1시간 20분"
            style: TextStyle(fontSize: size * 0.18, fontWeight: FontWeight.bold, height: 1.7),
          ),
          Text(
            subValue,
            style: TextStyle(fontSize: size * 0.13, color: Colors.white70, height: 1.0),
          )
        ],
      ),
    );
  }
}