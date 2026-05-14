import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PostureInferrer {
  Interpreter? _spineInterpreter;
  Interpreter? _kneeInterpreter;

  List<double> means = [];
  List<double> scales = [];

  static const double spineThreshold = 0.03;
  static const double kneeThreshold = 0.80;

  Future<void> loadModels() async {
    await _loadScaler();

    _spineInterpreter = await Interpreter.fromAsset(
      'assets/models/model_label_spine.tflite',
    );
    _kneeInterpreter = await Interpreter.fromAsset(
      'assets/models/model_label_knee.tflite',
    );
  }

  Future<void> _loadScaler() async {
    final raw = await rootBundle.loadString('assets/models/scaler.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;

    means = (data['means'] as List).map((v) => (v as num).toDouble()).toList();
    scales = (data['scales'] as List)
        .map((v) => (v as num).toDouble())
        .toList();

    if (means.length != 13 || scales.length != 13) {
      throw StateError('scaler.json의 means/scales는 각각 13개여야 합니다.');
    }
  }

  Map<String, dynamic> infer(List<double> features) {
    final spineInterpreter = _spineInterpreter;
    final kneeInterpreter = _kneeInterpreter;

    if (spineInterpreter == null || kneeInterpreter == null) {
      throw StateError('AI 모델이 아직 로드되지 않았습니다.');
    }
    if (features.length != 13) {
      throw ArgumentError('스쿼트 모델 입력 피처는 13개여야 합니다.');
    }

    final scaledInput = List<double>.generate(features.length, (index) {
      return (features[index] - means[index]) / scales[index];
    });

    final input = [scaledInput];
    final spineOutput = [
      [0.0],
    ];
    final kneeOutput = [
      [0.0],
    ];

    spineInterpreter.run(input, spineOutput);
    kneeInterpreter.run(input, kneeOutput);

    final spineProb = spineOutput[0][0];
    final kneeProb = kneeOutput[0][0];

    return {
      'spine': {'prob': spineProb, 'ok': spineProb >= spineThreshold},
      'knee': {'prob': kneeProb, 'ok': kneeProb >= kneeThreshold},
    };
  }

  void close() {
    _spineInterpreter?.close();
    _kneeInterpreter?.close();
    _spineInterpreter = null;
    _kneeInterpreter = null;
  }
}
