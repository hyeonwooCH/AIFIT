import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ml/feature_extractor.dart';
import '../ml/posture_inferrer.dart';
import '../ml/squat_engine.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const MethodChannel _poseChannel = MethodChannel(
    'aifit/pose_landmarker',
  );
  static const int _poseFrameIntervalMs = 66;
  static const int _calibrationSeconds = 3;
  static const double _outOfPositionThreshold = 0.18;

  final PostureInferrer _postureInferrer = PostureInferrer();
  final SquatCounter _squatCounter = SquatCounter();

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isInitializingCamera = true;
  bool _areModelsReady = false;
  bool _isWorkoutStarted = false;
  bool _isDetectingPose = false;
  String? _cameraError;
  String? _modelError;

  int _count = 0;
  String _state = 'UP';
  String _guideText = '전신이 보이게 서주세요';
  String _poseDebugText = 'MediaPipe 대기 중';
  String _lastFeedbackText = '';
  List<_PoseLandmark> _imageLandmarks = [];
  Size? _poseImageSize;
  DateTime? _lastPoseProcessTime;
  DateTime? _calibrationStart;
  double? _calibratedHipX;
  bool _isCalibrated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeCamera();
    _initializeAiModels();
  }

  Future<void> _initializeAiModels() async {
    try {
      await _postureInferrer.loadModels();
      if (!mounted) return;
      setState(() {
        _areModelsReady = true;
        _poseDebugText = 'AI 모델 준비 완료';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _modelError = '$e';
        _poseDebugText = 'AI 모델 로드 실패';
      });
    }
  }

  Future<void> _initializeCamera({CameraDescription? preferredCamera}) async {
    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _cameraError = '사용 가능한 카메라가 없습니다.';
          _isInitializingCamera = false;
        });
        return;
      }

      final frontCameras = _cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      final selectedCamera =
          preferredCamera ??
          (frontCameras.isNotEmpty ? frontCameras.first : _cameras.first);

      final oldController = _controller;
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await oldController?.dispose();
      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _isInitializingCamera = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = '카메라를 열 수 없습니다. (${e.code})';
        _isCameraInitialized = false;
        _isInitializingCamera = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = '카메라 초기화 중 오류가 발생했습니다.';
        _isCameraInitialized = false;
        _isInitializingCamera = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _controller == null) return;

    await _stopWorkout(clearOverlay: true);

    final current = _controller!.description;
    final nextCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection != current.lensDirection,
      orElse: () => _cameras.first,
    );

    await _initializeCamera(preferredCamera: nextCamera);
  }

  Future<void> _toggleWorkout() async {
    if (_isWorkoutStarted) {
      await _stopWorkout(clearOverlay: true);
    } else {
      await _startWorkout();
    }
  }

  Future<void> _startWorkout() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _isWorkoutStarted = true;
      _count = 0;
      _state = 'UP';
      _lastFeedbackText = '';
      _isCalibrated = false;
      _calibrationStart = null;
      _calibratedHipX = null;
      _lastPoseProcessTime = null;
      _guideText = '전신이 보이게 서주세요';
      _poseDebugText = '실시간 분석 시작';
    });

    try {
      if (!controller.value.isStreamingImages) {
        await controller.startImageStream(_handleCameraImage);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isWorkoutStarted = false;
        _guideText = '실시간 분석 시작 실패';
        _poseDebugText = '$e';
      });
    }
  }

  Future<void> _stopWorkout({required bool clearOverlay}) async {
    final controller = _controller;

    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    _squatCounter.reset();

    if (!mounted) return;
    setState(() {
      _isWorkoutStarted = false;
      _isDetectingPose = false;
      _count = 0;
      _state = 'UP';
      _guideText = '전신이 보이게 서주세요';
      _poseDebugText = '분석 대기 중';
      _lastFeedbackText = '';
      _isCalibrated = false;
      _calibrationStart = null;
      _calibratedHipX = null;
      _lastPoseProcessTime = null;
      if (clearOverlay) {
        _imageLandmarks = [];
        _poseImageSize = null;
      }
    });
  }

  Future<void> _handleCameraImage(CameraImage image) async {
    if (!_isWorkoutStarted || _isDetectingPose) return;

    final now = DateTime.now();
    final previous = _lastPoseProcessTime;
    if (previous != null &&
        now.difference(previous).inMilliseconds < _poseFrameIntervalMs) {
      return;
    }
    _lastPoseProcessTime = now;
    _isDetectingPose = true;

    try {
      final result = await _poseChannel
          .invokeMethod<Map<dynamic, dynamic>>('detectYuvFrame', {
            'width': image.width,
            'height': image.height,
            'rotationDegrees': _controller?.description.sensorOrientation ?? 0,
            'planes': image.planes.map((plane) => plane.bytes).toList(),
            'bytesPerRow': image.planes
                .map((plane) => plane.bytesPerRow)
                .toList(),
            'bytesPerPixel': image.planes
                .map((plane) => plane.bytesPerPixel ?? 1)
                .toList(),
          });

      _handlePoseResult(result);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _guideText = '자세 분석 실패';
        _poseDebugText = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guideText = '자세 분석 실패';
        _poseDebugText = '$e';
      });
    } finally {
      _isDetectingPose = false;
    }
  }

  void _handlePoseResult(Map<dynamic, dynamic>? result) {
    final poseFound = result?['poseFound'] == true;
    final imageLandmarks = result?['imageLandmarks'] as List<dynamic>? ?? [];
    final worldLandmarks = result?['worldLandmarks'] as List<dynamic>? ?? [];
    final imageWidth = (result?['imageWidth'] as num?)?.toDouble() ?? 1;
    final imageHeight = (result?['imageHeight'] as num?)?.toDouble() ?? 1;

    final parsedImageLandmarks = _parsePoseLandmarks(imageLandmarks);
    final fullBodyVisible = _isFullBodyVisible(parsedImageLandmarks);
    final canTrack =
        poseFound &&
        fullBodyVisible &&
        worldLandmarks.length >= 33 &&
        _areModelsReady;

    var nextGuideText = '전신이 보이게 서주세요';
    var nextDebugText =
        'image: ${imageLandmarks.length}개 / world: ${worldLandmarks.length}개';

    if (poseFound && !fullBodyVisible) {
      nextGuideText = '발목까지 화면에 들어오게';
      nextDebugText = '상반신만 감지됨 - 전신 필요';
      if (!_isCalibrated) {
        _calibrationStart = null;
        _calibratedHipX = null;
      }
    } else if (poseFound && !_areModelsReady) {
      nextGuideText = 'AI 모델을 준비하고 있어요';
      nextDebugText = _modelError ?? '모델 로딩 중...';
    } else if (canTrack) {
      final worldMap = _toVectorMap(worldLandmarks);
      final hipY = _averageHipY(parsedImageLandmarks);
      final hipX = _averageHipX(parsedImageLandmarks);
      final bodyHeight = _bodyHeight(parsedImageLandmarks);

      if (!_isCalibrated) {
        final now = DateTime.now();
        _calibrationStart ??= now;
        final elapsed =
            now.difference(_calibrationStart!).inMilliseconds / 1000;

        if (elapsed >= _calibrationSeconds) {
          _isCalibrated = true;
          _calibratedHipX = hipX;
          _squatCounter.reset();
          nextGuideText = '시작하세요';
          nextDebugText = '영점 설정 완료';
        } else {
          final remaining = (_calibrationSeconds - elapsed).clamp(
            0,
            _calibrationSeconds,
          );
          nextGuideText = '영점 설정 중 ${remaining.toStringAsFixed(1)}';
          nextDebugText = '움직이지 마세요';
        }
      } else if (!_isInCalibratedPosition(hipX)) {
        nextGuideText = '처음 위치로 돌아오세요';
        nextDebugText = '위치 이탈 - 카운팅 중단';
      } else {
        final countResult = _squatCounter.update(
          hipY,
          worldMap,
          bodyHeight: bodyHeight,
        );

        _count = countResult['count'] as int;
        _state = countResult['state'] as String;
        final hipDelta = countResult['hipDelta'] as double;
        final downThreshold = countResult['downThreshold'] as double;
        nextGuideText = _lastFeedbackText.isEmpty ? '운동 중' : _lastFeedbackText;
        nextDebugText =
            'STATE: $_state / hip ${hipDelta.toStringAsFixed(3)} / 기준 ${downThreshold.toStringAsFixed(3)}';

        if (countResult['counted'] == true) {
          final bottomLandmarks =
              countResult['bottomLandmarks'] as Map<int, Vector3>?;

          if (bottomLandmarks != null) {
            final features = FeatureExtractor.extract(bottomLandmarks);
            final inference = _postureInferrer.infer(features);
            final spine = inference['spine'] as Map<String, dynamic>;
            final knee = inference['knee'] as Map<String, dynamic>;
            final spineProb = spine['prob'] as double;
            final kneeProb = knee['prob'] as double;
            final spineOk = spine['ok'] == true;
            final kneeOk = knee['ok'] == true;

            _lastFeedbackText = _buildFeedbackText(
              spineOk: spineOk,
              kneeOk: kneeOk,
            );
            nextGuideText = _lastFeedbackText;
            nextDebugText =
                '$_count회 / 척추 ${spineProb.toStringAsFixed(3)} '
                '${spineOk ? "OK" : "NG"} / '
                '무릎 ${(kneeProb * 100).toStringAsFixed(1)}% '
                '${kneeOk ? "OK" : "NG"}';
          }
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _guideText = nextGuideText;
      _poseDebugText = nextDebugText;
      _imageLandmarks = parsedImageLandmarks;
      _poseImageSize = Size(imageWidth, imageHeight);
    });
  }

  List<_PoseLandmark> _parsePoseLandmarks(List<dynamic> rawLandmarks) {
    return rawLandmarks.map((raw) {
      final item = raw as Map<dynamic, dynamic>;
      return _PoseLandmark(
        x: (item['x'] as num).toDouble(),
        y: (item['y'] as num).toDouble(),
        z: (item['z'] as num).toDouble(),
        visibility: (item['visibility'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Map<int, Vector3> _toVectorMap(List<dynamic> rawLandmarks) {
    final vectors = <int, Vector3>{};
    for (var index = 0; index < rawLandmarks.length; index++) {
      final item = rawLandmarks[index] as Map<dynamic, dynamic>;
      vectors[index] = Vector3(
        (item['x'] as num).toDouble(),
        (item['y'] as num).toDouble(),
        (item['z'] as num).toDouble(),
      );
    }
    return vectors;
  }

  bool _isFullBodyVisible(List<_PoseLandmark> landmarks) {
    const requiredIndexes = [11, 12, 23, 24, 25, 26, 27, 28];
    if (landmarks.length <= 28) return false;

    final hasRequiredLandmarks = requiredIndexes.every((index) {
      final landmark = landmarks[index];
      return landmark.visibility >= 0.45 &&
          landmark.x >= -0.05 &&
          landmark.x <= 1.05 &&
          landmark.y >= -0.05 &&
          landmark.y <= 1.05;
    });

    if (!hasRequiredLandmarks) return false;

    final requiredYValues = requiredIndexes.map((index) => landmarks[index].y);
    final minY = requiredYValues.reduce((a, b) => a < b ? a : b);
    final maxY = requiredYValues.reduce((a, b) => a > b ? a : b);
    final visibleBodyHeight = maxY - minY;

    return visibleBodyHeight >= 0.35;
  }

  double _averageHipY(List<_PoseLandmark> landmarks) {
    if (landmarks.length <= 24) return 0;
    return (landmarks[23].y + landmarks[24].y) / 2;
  }

  double _averageHipX(List<_PoseLandmark> landmarks) {
    if (landmarks.length <= 24) return 0;
    return (landmarks[23].x + landmarks[24].x) / 2;
  }

  double _bodyHeight(List<_PoseLandmark> landmarks) {
    if (landmarks.length <= 28) return 0.5;

    final shoulderY = (landmarks[11].y + landmarks[12].y) / 2;
    final ankleY = (landmarks[27].y + landmarks[28].y) / 2;
    return (ankleY - shoulderY).abs().clamp(0.35, 0.9);
  }

  bool _isInCalibratedPosition(double hipX) {
    final calibratedHipX = _calibratedHipX;
    if (calibratedHipX == null) return false;
    return (hipX - calibratedHipX).abs() < _outOfPositionThreshold;
  }

  String _buildFeedbackText({required bool spineOk, required bool kneeOk}) {
    if (spineOk && kneeOk) return '좋아요, 자세 유지';

    final messages = <String>[];
    if (!spineOk) messages.add('허리를 펴주세요');
    if (!kneeOk) messages.add('무릎을 발끝 방향으로 맞춰주세요');

    return messages.join('\n');
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _postureInferrer.close();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    final controller = _controller!;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 720,
          height: controller.value.previewSize?.width ?? 1280,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildTopGuide() {
    return Positioned(
      top: 0,
      left: 35,
      right: 78,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF55C58E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _guideText,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 5,
      right: 20,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 34),
        ),
      ),
    );
  }

  Widget _buildCounter() {
    return Positioned(
      top: 145,
      left: 38,
      child: Text(
        '$_count',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 92,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildStateBadge() {
    return Positioned(
      top: 300,
      left: 35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: const Color(0xFF9BA300),
        child: Text(
          'STATE: $_state',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, 95),
        child: SizedBox(
          width: 210,
          height: 84,
          child: ElevatedButton(
            onPressed: _toggleWorkout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF62F0A8),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(42),
              ),
            ),
            child: Text(
              _isWorkoutStarted ? '운동 종료' : '운동 시작',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoseDebugText() {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 92,
      child: Text(
        _poseDebugText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPoseSkeleton() {
    final poseImageSize = _poseImageSize;
    if (_imageLandmarks.isEmpty || poseImageSize == null) {
      return const SizedBox.shrink();
    }

    final mirror =
        _controller?.description.lensDirection == CameraLensDirection.front;

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _PoseSkeletonPainter(
            landmarks: _imageLandmarks,
            imageSize: poseImageSize,
            mirror: mirror,
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 5,
      left: 18,
      child: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildCameraSwitchButton() {
    if (_cameras.length < 2) return const SizedBox.shrink();

    return Positioned(
      bottom: 28,
      right: 24,
      child: InkWell(
        onTap: _switchCamera,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cameraswitch, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildCameraError() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  color: Colors.white70,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  _cameraError ?? '카메라를 사용할 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeCamera,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return _buildCameraError();
    }

    if (_isInitializingCamera || !_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.lightBlueAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraPreview(),
            _buildPoseSkeleton(),
            _buildTopGuide(),
            _buildCloseButton(),
            _buildCounter(),
            _buildStateBadge(),
            _buildStartButton(),
            _buildBackButton(),
            _buildCameraSwitchButton(),
            _buildPoseDebugText(),
          ],
        ),
      ),
    );
  }
}

class _PoseLandmark {
  final double x;
  final double y;
  final double z;
  final double visibility;

  const _PoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });
}

class _PoseSkeletonPainter extends CustomPainter {
  final List<_PoseLandmark> landmarks;
  final Size imageSize;
  final bool mirror;

  const _PoseSkeletonPainter({
    required this.landmarks,
    required this.imageSize,
    required this.mirror,
  });

  static const List<(int, int)> _connections = [
    (11, 12),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
    (11, 23),
    (12, 24),
    (23, 24),
    (23, 25),
    (25, 27),
    (27, 29),
    (29, 31),
    (27, 31),
    (24, 26),
    (26, 28),
    (28, 30),
    (30, 32),
    (28, 32),
    (0, 7),
    (0, 8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(BoxFit.cover, imageSize, size);
    final outputRect = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );

    final linePaint = Paint()
      ..color = const Color(0xFF37D7FF)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = const Color(0xFF62F0A8)
      ..style = PaintingStyle.fill;

    final jointStrokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final connection in _connections) {
      final start = _pointFor(connection.$1, outputRect);
      final end = _pointFor(connection.$2, outputRect);
      if (start == null || end == null) continue;
      canvas.drawLine(start, end, linePaint);
    }

    for (var index = 0; index < landmarks.length; index++) {
      final point = _pointFor(index, outputRect);
      if (point == null) continue;
      canvas.drawCircle(point, 5.5, jointPaint);
      canvas.drawCircle(point, 5.5, jointStrokePaint);
    }
  }

  Offset? _pointFor(int index, Rect outputRect) {
    if (index < 0 || index >= landmarks.length) return null;

    final landmark = landmarks[index];
    if (landmark.visibility > 0 && landmark.visibility < 0.25) return null;

    final x = mirror ? 1 - landmark.x : landmark.x;
    return Offset(
      outputRect.left + x * outputRect.width,
      outputRect.top + landmark.y * outputRect.height,
    );
  }

  @override
  bool shouldRepaint(covariant _PoseSkeletonPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.mirror != mirror;
  }
}
