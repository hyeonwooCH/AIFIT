import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SquatAnalyzer {
  Interpreter? _spineModel;
  Interpreter? _kneeModel;

  // TODO: 파이썬 코드에서 출력된 Mean(평균)과 Var(분산) 숫자 13개를 여기에 복사해 넣으세요!
  final List<double> _mean = [0.6597344591390601, 0.6018336052508202, 0.6763585187971245, 0.752226953069831, 0.5984998368766419, -0.020185077170364905, 0.5242700177613039, 0.5324580074006389, 0.8441708889508317, -0.03743224389591189, -0.014262611663705387, -0.12322716463728114, -0.26971472816021985]; 
  final List<double> _var = [0.026836219816184916, 0.02130649810796502, 0.025079696847661998, 0.002271605715030584, 0.0030990161158458945, 0.0003984286598731554, 0.027115201595970476, 0.03365964198758536, 0.06025172717516446, 0.00031067205835899907, 0.00032865629529825295, 0.0084914405993537, 0.004900452786074066];

  // 모델 로드
  Future<void> loadModels() async {
    _spineModel = await Interpreter.fromAsset('assets/models/model_label_spine.tflite');
    _kneeModel = await Interpreter.fromAsset('assets/models/model_label_knee.tflite');
    print("✅ TFLite 모델 로드 완료!");
  }

  // 3D 각도 계산 공식 (파이썬의 calc_angle_3d와 동일)
  double _calculateAngle3D(List<double> a, List<double> b, List<double> c) {
    List<double> v1 = [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
    List<double> v2 = [c[0] - b[0], c[1] - b[1], c[2] - b[2]];

    double dotProduct = v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
    double norm1 = sqrt(pow(v1[0], 2) + pow(v1[1], 2) + pow(v1[2], 2));
    double norm2 = sqrt(pow(v2[0], 2) + pow(v2[1], 2) + pow(v2[2], 2));

    double cosVal = dotProduct / (norm1 * norm2 + 1e-6);
    cosVal = cosVal.clamp(-1.0, 1.0);
    return acos(cosVal) * 180 / pi;
  }

  // 데이터 스케일링 (파이썬의 StandardScaler.transform과 동일)
  List<double> _scaleFeatures(List<double> features) {
    List<double> scaled = [];
    for (int i = 0; i < features.length; i++) {
      double scaledValue = (features[i] - _mean[i]) / sqrt(_var[i] + 1e-6);
      scaled.add(scaledValue);
    }
    return scaled;
  }

  // 특징 추출 및 추론
  Map<String, double> analyzePose(Pose pose) {
    if (_spineModel == null || _kneeModel == null) return {};

    final lm = pose.landmarks;
    // 필요한 관절이 하나라도 없으면 분석 중단
    if (lm[PoseLandmarkType.leftShoulder] == null) return {};

    // x, y, z 좌표 리스트화 헬퍼 함수
    List<double> p3(PoseLandmarkType type) {
      return [lm[type]!.x, lm[type]!.y, lm[type]!.z];
    }

    var nose = p3(PoseLandmarkType.nose);
    var earL = p3(PoseLandmarkType.leftEar);
    var earR = p3(PoseLandmarkType.rightEar);
    var shoL = p3(PoseLandmarkType.leftShoulder);
    var shoR = p3(PoseLandmarkType.rightShoulder);
    var hipL = p3(PoseLandmarkType.leftHip);
    var hipR = p3(PoseLandmarkType.rightHip);
    var kneL = p3(PoseLandmarkType.leftKnee);
    var kneR = p3(PoseLandmarkType.rightKnee);
    var ankL = p3(PoseLandmarkType.leftAnkle);
    var ankR = p3(PoseLandmarkType.rightAnkle);
    var heelL = p3(PoseLandmarkType.leftHeel);
    var heelR = p3(PoseLandmarkType.rightHeel);
    var footL = p3(PoseLandmarkType.leftFootIndex);
    var footR = p3(PoseLandmarkType.rightFootIndex);

    var shoC = [(shoL[0] + shoR[0]) / 2, (shoL[1] + shoR[1]) / 2, (shoL[2] + shoR[2]) / 2];
    var hipC = [(hipL[0] + hipR[0]) / 2, (hipL[1] + hipR[1]) / 2, (hipL[2] + hipR[2]) / 2];
    var kneC = [(kneL[0] + kneR[0]) / 2, (kneL[1] + kneR[1]) / 2, (kneL[2] + kneR[2]) / 2];

    List<double> features = [];
    features.add(_calculateAngle3D(shoC, hipC, kneC) / 180.0);
    features.add(_calculateAngle3D(shoL, hipL, kneL) / 180.0);
    features.add(_calculateAngle3D(shoR, hipR, kneR) / 180.0);
    features.add(_calculateAngle3D(earL, shoL, hipL) / 180.0);
    features.add(_calculateAngle3D(earR, shoR, hipR) / 180.0);
    features.add((nose[0] - shoC[0]).toDouble());
    features.add(_calculateAngle3D(hipL, kneL, ankL) / 180.0);
    features.add(_calculateAngle3D(hipR, kneR, ankR) / 180.0);
    
    double kneeW = (kneL[0] - kneR[0]).abs() + 1e-6;
    double ankW = (ankL[0] - ankR[0]).abs() + 1e-6;
    features.add((kneeW / ankW).clamp(0.0, 3.0));
    
    features.add((heelL[1] - footL[1]).toDouble());
    features.add((heelR[1] - footR[1]).toDouble());
    features.add((shoC[2] - hipC[2]).toDouble());
    features.add(((kneL[2] - ankL[2]) + (kneR[2] - ankR[2])) / 2.0);

    // 1. 스케일링
    var scaledFeatures = _scaleFeatures(features);
    
    // 2. TFLite 입력용 2차원 배열로 변환 [1, 13]
    var input = [scaledFeatures];
    
    // 3. 추론 (출력용 배열 준비)
    var spineOutput = List.generate(1, (index) => List.filled(1, 0.0));
    var kneeOutput = List.generate(1, (index) => List.filled(1, 0.0));

    _spineModel!.run(input, spineOutput);
    _kneeModel!.run(input, kneeOutput);

    // 4. 확률 반환 (0.0 ~ 1.0)
    return {
      'spine': spineOutput[0][0],
      'knee': kneeOutput[0][0],
    };
  }
}