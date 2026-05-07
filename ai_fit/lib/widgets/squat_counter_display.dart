import 'package:flutter/material.dart';

class SquatCounterDisplay extends StatelessWidget {
  final int count;
  final String state;

  const SquatCounterDisplay({
    super.key,
    required this.count,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    // 💡 수정 포인트: 충돌을 일으키던 Positioned를 제거했습니다!
    // 이제 부모가 지시한 '화면 아래쪽 중앙'에 예쁘게 배치됩니다.
    return Column(
      mainAxisSize: MainAxisSize.min, // Column이 화면 전체 높이를 차지하지 않도록 최소화
      crossAxisAlignment: CrossAxisAlignment.center, // 가운데 정렬
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 100,
            fontWeight: FontWeight.w900,
            shadows: const [
              // 숫자가 카메라 화면 위에서도 잘 보이도록 약간의 그림자 추가
              Shadow(blurRadius: 10, color: Colors.black54, offset: Offset(2, 2))
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.yellowAccent,
            borderRadius: BorderRadius.circular(8), // 모서리를 살짝 둥글게
          ),
          child: Text(
            'STATE: $state',
            style: const TextStyle(
              color: Colors.black, 
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}