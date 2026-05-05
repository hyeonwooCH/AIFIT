import 'dart:math' as math;

/// 3D 좌표를 다루기 위한 간단한 클래스
class Vector3 {
  final double x, y, z;
  Vector3(this.x, this.y, this.z);
}

class SquatEngine {
  // 파이썬 Config 클래스의 설정값을 상수로 정의
  static const double hipYDownThresh = 0.12;
  static const double hipYUpRatio = 0.7;

  /// 세 점 사이의 3D 각도를 계산 (파이썬의 calc_angle_3d 로직)[cite: 1]
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

/// 스쿼트 개수와 상태를 관리하는 카운터 클래스[cite: 1]
class SquatCounter {
  int count = 0;
  String state = 'UP';
  double? baseY;
  double? minYThisRep;

  Map<String, dynamic> update(double currentHipY) {
    bool counted = false;

    if (baseY == null) {
      baseY = currentHipY;
      return {'count': count, 'state': state, 'counted': false};
    }

    // 엉덩이가 기준점보다 일정 깊이 이상 내려갔을 때 DOWN 상태로 진입[cite: 1]
    double downThresh = baseY! + SquatEngine.hipYDownThresh;

    if (state == 'UP') {
      if (currentHipY > downThresh) {
        state = 'DOWN';
        minYThisRep = currentHipY;
      }
    } else if (state == 'DOWN') {
      if (currentHipY > (minYThisRep ?? 0)) {
        minYThisRep = currentHipY;
      }
      
      // 다시 올라오는 지점을 계산하여 UP 상태로 복귀 및 카운트[cite: 1]
      double upThresh = baseY! + (minYThisRep! - baseY!) * (1 - SquatEngine.hipYUpRatio);
      if (currentHipY < upThresh) {
        state = 'UP';
        count++;
        counted = true;
        // 기준점 미세 조정
        baseY = 0.9 * baseY! + 0.1 * currentHipY;
      }
    }

    return {'count': count, 'state': state, 'counted': counted};
  }

  void reset() {
    count = 0;
    state = 'UP';
    baseY = null;
    minYThisRep = null;
  }
}