import 'squat_engine.dart';

class FeatureExtractor {
  /// 파이썬의 extract_features 로직을 Dart로 완벽 이식[cite: 1]
  static List<double> extract(Map<int, Vector3> landmarks) {
    List<double> f = [];

    // 편의를 위한 랜드마크 추출 (파이썬 번호 기준)[cite: 1]
    Vector3 nose = landmarks[0]!;
    Vector3 earL = landmarks[7]!;   Vector3 earR = landmarks[8]!;
    Vector3 shoL = landmarks[11]!;  Vector3 shoR = landmarks[12]!;
    Vector3 hipL = landmarks[23]!;  Vector3 hipR = landmarks[24]!;
    Vector3 kneeL = landmarks[25]!; Vector3 kneeR = landmarks[26]!;
    Vector3 ankL = landmarks[27]!;  Vector3 ankR = landmarks[28]!;
    Vector3 heelL = landmarks[29]!; Vector3 heelR = landmarks[30]!;
    Vector3 footL = landmarks[31]!; Vector3 footR = landmarks[32]!;

    // 중앙점 계산[cite: 1]
    Vector3 shoC3 = Vector3((shoL.x + shoR.x)/2, (shoL.y + shoR.y)/2, (shoL.z + shoR.z)/2);
    Vector3 hipC3 = Vector3((hipL.x + hipR.x)/2, (hipL.y + hipR.y)/2, (hipL.z + hipR.z)/2);
    Vector3 kneC3 = Vector3((kneeL.x + kneeR.x)/2, (kneeL.y + kneeR.y)/2, (kneeL.z + kneeR.z)/2);

    // AI 모델이 요구하는 13가지 피처 계산[cite: 1]
    f.add(SquatEngine.calculateAngle3D(shoC3, hipC3, kneC3) / 180.0); // 1. 상체 각도
    f.add(SquatEngine.calculateAngle3D(shoL, hipL, kneeL) / 180.0);   // 2. 왼쪽 고관절
    f.add(SquatEngine.calculateAngle3D(shoR, hipR, kneeR) / 180.0);   // 3. 오른쪽 고관절
    f.add(SquatEngine.calculateAngle3D(earL, shoL, hipL) / 180.0);    // 4. 왼쪽 목 각도
    f.add(SquatEngine.calculateAngle3D(earR, shoR, hipR) / 180.0);    // 5. 오른쪽 목 각도
    f.add(nose.x - (shoL.x + shoR.x) / 2);                           // 6. 코와 어깨 중앙 거리
    f.add(SquatEngine.calculateAngle3D(hipL, kneeL, ankL) / 180.0);   // 7. 왼쪽 무릎 각도
    f.add(SquatEngine.calculateAngle3D(hipR, kneeR, ankR) / 180.0);   // 8. 오른쪽 무릎 각도
    
    double kneeW = (kneeL.x - kneeR.x).abs() + 1e-6;
    double ankW = (ankL.x - ankR.x).abs() + 1e-6;
    f.add((kneeW / ankW).clamp(0.0, 3.0));                           // 9. 무릎/발목 너비 비율
    
    f.add(heelL.y - footL.y);                                        // 10. 왼쪽 뒤꿈치 높이
    f.add(heelR.y - footR.y);                                        // 11. 오른쪽 뒤꿈치 높이
    f.add(shoC3.z - hipC3.z);                                        // 12. 어깨-골반 깊이 차이
    
    double kz = ((kneeL.z - ankL.z) + (kneeR.z - ankR.z)) / 2;
    f.add(kz);                                                       // 13. 무릎-발목 깊이 차이[cite: 1]

    return f;
  }
}