import 'package:tflite_flutter/tflite_flutter.dart';

class PostureInferrer {
  Interpreter? _spineInterpreter;
  Interpreter? _kneeInterpreter;

  // 파이썬 Config의 threshold 값들 이식
  static const double spineThreshold = 0.03;
  static const double kneeThreshold = 0.9;

  // ✨ 민지님이 찾아오신 13개의 정규화 수치들
  final List<double> means = [
    0.6597344591390601, 0.6018336052508202, 0.6763585187971245, 0.752226953069831, 
    0.5984998368766419, -0.020185077170364905, 0.5242700177613039, 0.5324580074006389, 
    0.8441708889508317, -0.03743224389591189, -0.014262611663705387, -0.12322716463728114, 
    -0.26971472816021985
  ]; 

  final List<double> scales = [
    0.1638176419564905, 0.14596745564667837, 0.1583657060340464, 0.04766136501434452, 
    0.05566880738659572, 0.019960677841024222, 0.1646669414180347, 0.18346564252629252, 
    0.24546227240691074, 0.01762589170393938, 0.018128880144627053, 0.09214901301345392, 
    0.07000323411153277
  ];

  /// 모델 파일을 메모리에 올립니다.
  Future<void> loadModels() async {
    try {
      _spineInterpreter = await Interpreter.fromAsset('assets/models/model_label_spine.tflite');
      _kneeInterpreter = await Interpreter.fromAsset('assets/models/model_label_knee.tflite');
      print('AIFIT AI 모델 로드 완료');
    } catch (e) {
      print('모델 로드 실패: $e');
    }
  }

  /// FeatureExtractor가 뽑아준 데이터를 정규화한 뒤 판단을 내립니다.
  Map<String, dynamic> infer(List<double> features) {
    // 1. [핵심] 입력받은 13개 데이터를 파이썬 StandardScaler 공식으로 변환
    final List<double> scaledInput = List.generate(features.length, (i) {
      return (features[i] - means[i]) / scales[i];
    });

    // 2. 변환된 데이터를 모델에 넣음
    var input = [scaledInput]; 
    var spineOutput = List.filled(1, List.filled(1, 0.0)).reshape([1, 1]);
    var kneeOutput = List.filled(1, List.filled(1, 0.0)).reshape([1, 1]);

    _spineInterpreter?.run(input, spineOutput);
    _kneeInterpreter?.run(input, kneeOutput);

    double spineProb = spineOutput[0][0];
    double kneeProb = kneeOutput[0][0];

    return {
      'spine': {
        'prob': spineProb,
        'ok': spineProb >= spineThreshold, // 파이썬의 ok 판정 로직 적용
      },
      'knee': {
        'prob': kneeProb,
        'ok': kneeProb >= kneeThreshold,  // 파이썬의 ok 판정 로직 적용
      },
    };
  }

  void close() {
    _spineInterpreter?.close();
    _kneeInterpreter?.close();
  }
}