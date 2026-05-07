import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:ai_fit/ml/pose_painter.dart';
import 'package:ai_fit/logic/squat_engine.dart';
import 'package:ai_fit/logic/feature_extractor.dart';
import 'package:ai_fit/logic/posture_inferrer.dart';
import 'package:ai_fit/widgets/squat_feedback_bar.dart';
import 'package:ai_fit/widgets/squat_counter_display.dart';

class CameraSquirtScreen extends StatefulWidget {
  const CameraSquirtScreen({super.key});

  @override
  State<CameraSquirtScreen> createState() => _CameraSquirtScreenState();
}

class _CameraSquirtScreenState extends State<CameraSquirtScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  // ✨ AI 엔진 및 상태 설정
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isBusy = false; 
  bool _isStarted = false; // 가짜 카운트 방지를 위한 시작 플래그
  List<Pose> _poses = []; 

  final SquatCounter _counter = SquatCounter();
  int _squatCount = 0;
  String _squatState = 'UP';

  final PostureInferrer _inferrer = PostureInferrer();
  String _feedbackMessage = "전신이 보이게 서주세요";
  bool _isSpineOk = true;
  bool _isKneeOk = true;

  @override
  void initState() {
    super.initState();
    _inferrer.loadModels(); // AI 뇌 장착
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    _controller?.startImageStream((CameraImage image) {
      if (_isBusy) return;
      _processCameraImage(image);
    });

    if (mounted) setState(() => _isCameraInitialized = true);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    // 시작 버튼을 누르기 전에는 분석을 건너뛰어 가짜 카운트를 방지합니다
    if (_isBusy || !_isStarted) return; 
    _isBusy = true;
    print("분석 시작!");

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      print("inputImage 생성 실패");
      _isBusy = false;
      return;
    }

    final poses = await _poseDetector.processImage(inputImage);
    print("감지된 포즈 개수: ${poses.length}");

    print("📸 감지된 포즈 개수: ${poses.length}");

    int newCount = _squatCount;
    String newState = _squatState;
    String newFeedback = _feedbackMessage;
    bool newSpineOk = _isSpineOk;
    bool newKneeOk = _isKneeOk;

    if (poses.isNotEmpty) {
      final pose = poses.first;
      final coreLandmarks = [11, 12, 23, 24, 25, 26, 27, 28]; // 어깨, 골반, 무릎, 발목
      bool isVisible = coreLandmarks.every((index) => 
        (pose.landmarks[PoseLandmarkType.values[index]]?.likelihood ?? 0) > 0.3
      );

      if (!isVisible) {
        if (mounted) {
          setState(() {
            _feedbackMessage = "전신이 보이게 서주세요";
            _poses = []; 
          });
        }
        _isBusy = false;
        return; 
      }

      // ----------------------------------------------------
      // 여기서부터는 '전신이 확실히 보일 때만' 실행되는 진짜 분석 로직입니다
      final landmarkMap = _convertPoseToMap(pose);

      if (landmarkMap.containsKey(23) && landmarkMap.containsKey(24)) {
        final hipY = (landmarkMap[23]!.y + landmarkMap[24]!.y) / 2;

        // 1. 개수 카운팅 업데이트
        final result = _counter.update(hipY);
        newCount = result['count'];
        newState = result['state'];

        // 2. AI 모델용 피처 추출 및 추론 실행
        final features = FeatureExtractor.extract(landmarkMap);
        final aiResult = _inferrer.infer(features); // ✨ 진짜 AI 지능 연결 부분
      
        newSpineOk = aiResult['spine']['ok'];
        newKneeOk = aiResult['knee']['ok'];

        // 피드백 메시지 결정
        if (newSpineOk && newKneeOk) {
          newFeedback = "완벽한 자세입니다!";
        } else if (!newSpineOk) {
          newFeedback = "허리를 더 펴주세요!";
        } else {
          newFeedback = "무릎 방향에 주의하세요!";
        }
      }
      // ----------------------------------------------------
    } else {
      newFeedback = "사람을 찾을 수 없습니다";
    }

    if (mounted) {
      setState(() {
        _poses = poses;
        _squatCount = newCount;
        _squatState = newState;
        _feedbackMessage = newFeedback;
        _isSpineOk = newSpineOk;
        _isKneeOk = newKneeOk;
      });
    }
    _isBusy = false;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationValue = sensorOrientation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationValue = (sensorOrientation + 180) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationValue);
    }
    
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    /*final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );*/

    // 1. 모든 플레인(Y, U, V)의 바이트 데이터를 하나로 합칩니다.
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // 2. 합쳐진 데이터를 넘겨줍니다.
    return InputImage.fromBytes(
      bytes: bytes, 
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow, // 안드로이드는 첫 판의 가로 길이를 기준으로 잡습니다.
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 카메라 배경화면
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // 2. AI 관절 선 그리기
          if (_poses.isNotEmpty)
            SizedBox.expand(
              child: CustomPaint(
                painter: PosePainter(
                  _poses,
                  Size(_controller!.value.previewSize!.height, _controller!.value.previewSize!.width),
                  Platform.isAndroid
                      ? InputImageRotation.rotation0deg
                      : InputImageRotation.rotation90deg,
                ),
              ),
            ),

          // 3. 분리한 커스텀 위젯 적용
          SquatFeedbackBar(
            message: _feedbackMessage,
            isSpineOk: _isSpineOk,
            isKneeOk: _isKneeOk,
          ),

          SquatCounterDisplay(
            count: _squatCount,
            state: _squatState,
          ),

          // 4. 우측 상단 X 버튼
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // 5. 운동 시작 버튼 overlay (시작 전까지만 표시)
          if (!_isStarted)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                  onPressed: () {
                    setState(() => _isStarted = true);
                    _counter.reset(); // 영점 조절
                  },
                  child: const Text(
                    "운동 시작", 
                    style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<int, Vector3> _convertPoseToMap(Pose pose) {
    final Map<int, Vector3> map = {};
    pose.landmarks.forEach((type, landmark) {
      map[type.index] = Vector3(landmark.x, landmark.y, landmark.z);
    });
    return map;
  }
}