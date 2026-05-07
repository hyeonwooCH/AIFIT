import 'dart:math' as math;

/// 3D 좌표를 다루기 위한 간단한 클래스
class Vector3 {
  final double x, y, z;
  Vector3(this.x, this.y, this.z);
}

class SquatEngine {
  // 스쿼트로 인정할 만큼 무릎과 골반 간격이 좁아지는 변화량 (필요시 조절)
  static const double kneeYDownThresh = 0.25; 
  // 가장 깊게 앉았을 때를 기준으로 몇 % 일어서면 UP으로 볼 것인가 (0.7 = 70%)
  static const double kneeYUpRatio = 0.7;

  /// 세 점 사이의 3D 각도를 계산 (파이썬의 calc_angle_3d 로직)
  static double calculateAngle3D(Vector3 a, Vector3 b, Vector3 c) {
    double v1x = a.x - b.x; double v1y = a.y - b.y; double v1z = a.z - b.z;
    double v2x = c.x - b.x; double v2y = c.y - b.y; double v2z = c.z - b.z;

    double dotProduct = v1x * v2x + v1y * v2y + v1z * v2z;
    double v1Mag = math.sqrt(v1x * v1x + v1y * v1y + v1z * v1z);
    double v2Mag = math.sqrt(v2x * v2x + v2y * v2y + v2z * v2z);

    double cosVal = dotProduct / (v1Mag * v2Mag + 1e-6);
    return math.acos(cosVal.clamp(-1.0, 1.0)) * 180 / math.pi;
  }
}

/// 스쿼트 개수와 상태를 관리하는 카운터 클래스
class SquatCounter {
  int count = 0;
  String state = 'UP';
  double? baseY;
  double? minKneeYThisRep;
  
  // ✨ 새로 추가된 변수: 앉아있는 동안 '완벽한 자세'가 몇 번 나왔는지 세는 카운터
  int _perfectFrameCount = 0;

  // 🎛️ 난이도 조절 레버 (원하는 대로 숫자를 바꿔가며 내 몸에 맞추세요!)
  // 카메라가 보통 1초에 30프레임(30번 판정)을 찍어냅니다.
  // 5로 설정하면: 앉아있는 동안 최소 5번(약 0.15초) 이상 완벽한 자세가 유지되어야 1개 인정!
  // 숫자를 키울수록(예: 10, 15) 코치가 더 깐깐해집니다.
  final int requiredPerfectFrames = 5; 

  Map<String, dynamic> update(double currentKneeY, bool isPosturePerfect) {
    bool counted = false;

    if (baseY == null) {
      baseY = currentKneeY;
      return {'count': count, 'state': state, 'counted': false};
    }

    double downThresh = baseY! - SquatEngine.kneeYDownThresh;

    if (state == 'UP') {
      if (currentKneeY < downThresh) {
        state = 'DOWN';
        minKneeYThisRep = currentKneeY;
        
        // 🚨 앉기 시작할 때 누적 프레임 카운터를 0으로 초기화
        _perfectFrameCount = 0;
      }
    } else if (state == 'DOWN') {
      if (currentKneeY < (minKneeYThisRep ?? baseY!)) {
        minKneeYThisRep = currentKneeY;
      }

      // ✨ 평가: AI가 "자세 완벽함(true)"을 줄 때마다 카운트를 +1씩 쌓아줍니다.
      if (isPosturePerfect) {
        _perfectFrameCount++;
      }
      
      double upThresh = baseY! - (baseY! - minKneeYThisRep!) * (1 - SquatEngine.kneeYUpRatio);
      
      if (currentKneeY > upThresh) {
        state = 'UP';
        
        // ✨ 최종 심사: 일어날 때, 누적된 완벽 프레임 수가 '합격 기준'을 넘었는지 확인!
        if (_perfectFrameCount >= requiredPerfectFrames) {
          count++;
          counted = true;
        }
        
        baseY = 0.9 * baseY! + 0.1 * currentKneeY;
      }
    }

    return {'count': count, 'state': state, 'counted': counted};
  }

  void reset() {
    count = 0;
    state = 'UP';
    baseY = null;
    minKneeYThisRep = null;
    _perfectFrameCount = 0;
  }
}