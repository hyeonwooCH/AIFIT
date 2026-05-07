import 'dart:io';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/foundation.dart';

// 프로젝트 내부 로직 임포트
import 'package:ai_fit/ml/pose_painter.dart';
import 'package:ai_fit/logic/squat_engine.dart'; 
import 'package:ai_fit/logic/feature_extractor.dart';
import 'package:ai_fit/logic/posture_inferrer.dart';

// 분리된 UI 위젯 임포트
import 'package:ai_fit/widgets/squat_guideview.dart';
import 'package:ai_fit/widgets/squat_analysis_overlay.dart';

class CameraSquat extends StatefulWidget {
  const CameraSquat({super.key});

  @override
  State<CameraSquat> createState() => _CameraSquatState();
}

class _CameraSquatState extends State<CameraSquat> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  
  bool _isBusy = false;
  bool _isStarted = false;
  List<Pose> _poses = [];

  int _squatCount = 0;
  String _squatState = 'UP';
  String _feedbackMessage = "전신이 보이게 서주세요";
  bool _isSpineOk = true;
  bool _isKneeOk = true;

  final SquatCounter _counter = SquatCounter();
  final PostureInferrer _inferrer = PostureInferrer();

  @override
  void initState() {
    super.initState();
    _inferrer.loadModels(); 
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

    _controller?.startImageStream((image) {
      if (_isBusy || !_isStarted) return;
      _processImage(image);
    });

    if (mounted) setState(() => _isCameraInitialized = true);
  }

  Future<void> _processImage(CameraImage image) async {
    _isBusy = true;
    
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    final poses = await _poseDetector.processImage(inputImage);
    
    if (poses.isNotEmpty) {
      final pose = poses.first;
      
      // 1. 골반(0,0,0) 기준으로 모든 랜드마크 정규화
      final Map<int, Vector3> landmarkMap = _convertPoseToMap(pose);

      // 25번(왼쪽 무릎), 26번(오른쪽 무릎) 랜드마크 확인
      if (landmarkMap.containsKey(25) && landmarkMap.containsKey(26)) {
        
        // 2. 골반 대비 무릎의 상대적 Y좌표 (화면 위치에 영향받지 않는 절대 수치)
        final normalizedKneeY = (landmarkMap[25]!.y + landmarkMap[26]!.y) / 2;

        // 3. TFLite AI 모델로 자세 검증 (Spine, Knee)
        final features = FeatureExtractor.extract(landmarkMap);
        final aiResult = _inferrer.infer(features);
        
        final bool isSpineOk = aiResult['spine']['ok'];
        final bool isKneeOk = aiResult['knee']['ok'];
        final bool isPosturePerfect = isSpineOk && isKneeOk;

        // 4. 카운터에 "무릎 높이"와 "현재 자세의 완벽함"을 넘겨서 판정
        final countResult = _counter.update(normalizedKneeY, isPosturePerfect);

        if (mounted) {
          setState(() {
            _poses = poses;
            _squatCount = countResult['count'];
            _squatState = countResult['state'];
            _isSpineOk = isSpineOk;
            _isKneeOk = isKneeOk;

            // 5. 상태에 따른 멘트 출력 제어
            if (_squatState == 'UP') {
              _feedbackMessage = "스쿼트를 진행해주세요";
            } else { // DOWN 상태 (앉고 있는 중)
              _feedbackMessage = isPosturePerfect ? "완벽한 자세입니다!" : "자세를 교정해주세요";
            }
          });
        }
      }
    }
    _isBusy = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1층: 전체 화면 카메라 (여백 없음)
          _buildCameraPreview(),

          // 2층: AI 뼈대 렌더링 (카메라와 비율 동기화하여 치우침 방지)
          if (_poses.isNotEmpty) _buildSkeletonPainter(),

          // 3층: 분석 UI (카운터 좌측상단 / 피드백 우측하단 배치)
          SquatAnalysisOverlay(
            count: _squatCount,
            state: _squatState,
            feedback: _feedbackMessage,
            isSpineOk: _isSpineOk,
            isKneeOk: _isKneeOk,
            isStarted: _isStarted,
            onStart: () {
              setState(() => _isStarted = true);
              _counter.reset();
            },
          ),

          // 4층: 가이드 예시 이미지 (왼쪽 아래)
          Positioned(
            bottom: 40,
            left: 20,
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black45)],
              ),
              child: const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(13)),
                child: SquatGuideView(),
              ),
            ),
          ),

          // 5층: 닫기 버튼 (오른쪽 위)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height, // iOS 가로세로 반전 대응
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildSkeletonPainter() {
    final previewWidth = _controller!.value.previewSize!.height;
    final previewHeight = _controller!.value.previewSize!.width;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: CustomPaint(
            painter: PosePainter(
              _poses,
              Size(previewWidth, previewHeight), 
              Platform.isAndroid ? InputImageRotation.rotation0deg : InputImageRotation.rotation90deg,
            ),
          ),
        ),
      ),
    );
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

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes, 
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Map<int, Vector3> _convertPoseToMap(Pose pose) {
    final Map<int, Vector3> map = {};
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftHip == null || rightHip == null) return map;

    final double originX = (leftHip.x + rightHip.x) / 2;
    final double originY = (leftHip.y + rightHip.y) / 2;
    final double originZ = (leftHip.z + rightHip.z) / 2;

    final double hipWidth = sqrt(pow(leftHip.x - rightHip.x, 2) + pow(leftHip.y - rightHip.y, 2));
    final double scale = hipWidth > 0 ? hipWidth : 1.0;

    pose.landmarks.forEach((type, landmark) {
      map[type.index] = Vector3(
        (landmark.x - originX) / scale,
        (landmark.y - originY) / scale,
        (landmark.z - originZ) / scale
      );
    });

    return map;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }
}