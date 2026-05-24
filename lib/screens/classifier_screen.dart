import 'dart:async';
import 'dart:io';


import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/model_service.dart';
import '../widgets/prediction_overlay.dart';
import '../widgets/camera_controls.dart';

/// Main classifier screen — manages camera, model lifecycle, and inference loop.
class ClassifierScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ClassifierScreen({super.key, required this.cameras});

  @override
  State<ClassifierScreen> createState() => _ClassifierScreenState();
}

class _ClassifierScreenState extends State<ClassifierScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  final ModelService _modelService = ModelService();

  PredictionResult? _currentPrediction;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  bool _isSystemReady = false;
  bool _isFlashOn = false;
  String? _errorMessage;

  // For displaying a frozen captured image
  File? _capturedImage;
  bool _isShowingCapturedImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle for camera resource management
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _modelService.dispose();
    super.dispose();
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isSystemReady = false;
    });
  }

  Future<void> _initialize() async {
    setState(() {
      _errorMessage = null;
      _isSystemReady = false;
      _currentPrediction = null;
      _isShowingCapturedImage = false;
      _capturedImage = null;
    });

    // 1. Check cameras
    if (widget.cameras.isEmpty) {
      _setError("No camera found on this device.");
      return;
    }

    // 2. Load model
    await _modelService.loadModel();
    if (_modelService.loadError != null) {
      _setError(_modelService.loadError!);
      return;
    }

    // 3. Initialize camera (prefer back camera)
    final backCamera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
    } catch (e) {
      _setError("Failed to initialize camera: $e");
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSystemReady = true;
    });

    // 4. Start live inference stream
    _startImageStream();
  }

  /// Calculate camera sensor rotation for inference.
  int _getCameraRotation() {
    if (_cameraController == null) return 0;
    final sensorOrientation =
        _cameraController!.description.sensorOrientation;
    // For back cameras, sensorOrientation is typically 90 on Android
    return sensorOrientation;
  }

  void _startImageStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isShowingCapturedImage) {
      return;
    }

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingFrame || !_modelService.isLoaded) return;
      if (!mounted || _isShowingCapturedImage) return;

      _isProcessingFrame = true;

      final result = await _modelService.predictFromCamera(
        image,
        _getCameraRotation(),
      );

      if (mounted && !_isShowingCapturedImage) {
        setState(() {
          if (result != null) {
            _currentPrediction = result;
          }
          _isProcessingFrame = false;
        });
      } else {
        _isProcessingFrame = false;
      }
    });
  }

  void _stopImageStream() {
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
  }

  /// Capture a photo, freeze preview, and classify the image.
  Future<void> _captureAndClassify() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // Stop the live stream before capturing
      _stopImageStream();

      final xFile = await _cameraController!.takePicture();
      final file = File(xFile.path);

      setState(() {
        _capturedImage = file;
        _isShowingCapturedImage = true;
        _currentPrediction = null;
      });

      // Classify the captured image
      final result = await _modelService.predictFromFile(file);

      if (mounted) {
        setState(() {
          _currentPrediction = result;
          _isCapturing = false;
        });
      }
    } catch (e) {
      debugPrint("Capture error: $e");
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isShowingCapturedImage = false;
          _capturedImage = null;
        });
        // Restart live stream
        _startImageStream();
      }
    }
  }

  /// Pick from gallery and classify.
  Future<void> _pickAndClassify() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      _stopImageStream();

      final file = await _modelService.pickImageFromGallery();

      if (file == null) {
        if (mounted) {
          setState(() {
            _isCapturing = false;
          });
          // Restart stream if not showing captured
          if (!_isShowingCapturedImage) {
            _startImageStream();
          }
        }
        return;
      }

      setState(() {
        _capturedImage = file;
        _isShowingCapturedImage = true;
        _currentPrediction = null;
      });

      final result = await _modelService.predictFromFile(file);

      if (mounted) {
        setState(() {
          _currentPrediction = result;
          _isCapturing = false;
        });
      }
    } catch (e) {
      debugPrint("Gallery classify error: $e");
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  /// Return to live camera mode from captured image view.
  void _returnToLiveMode() {
    setState(() {
      _isShowingCapturedImage = false;
      _capturedImage = null;
      _currentPrediction = null;
    });
    _startImageStream();
  }

  /// Toggle flash on/off.
  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;

    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      if (mounted) {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      }
    } catch (e) {
      debugPrint("Flash toggle error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Error state
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    // Loading state
    if (!_isSystemReady) {
      return _buildLoadingView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview or captured image
          _isShowingCapturedImage && _capturedImage != null
              ? _buildCapturedImageView()
              : _buildCameraPreview(),

          // Top gradient overlay
          _buildTopGradient(),

          // Top status bar
          _buildTopBar(),

          // Prediction overlay — positioned above controls
          Positioned(
            left: 0,
            right: 0,
            bottom: _isShowingCapturedImage ? 80 : 140,
            child: PredictionOverlay(
              prediction: _currentPrediction,
              isProcessing: _isProcessingFrame,
            ),
          ),

          // Bottom controls (only in live mode)
          if (!_isShowingCapturedImage)
            CameraControls(
              onCapture: _captureAndClassify,
              onGalleryPick: _pickAndClassify,
              onFlashToggle: _toggleFlash,
              isFlashOn: _isFlashOn,
              isCapturing: _isCapturing,
            ),

          // Back-to-live button (in captured mode)
          if (_isShowingCapturedImage)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _returnToLiveMode,
                      icon: const Icon(Icons.videocam_rounded, size: 20),
                      label: const Text(
                        'Back to Live Camera',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const SizedBox.expand(
        child: ColoredBox(color: Colors.black),
      );
    }

    final mediaSize = MediaQuery.of(context).size;
    final cameraAspect = _cameraController!.value.aspectRatio;

    // Scale to fill the entire screen (cover mode)
    final scale = 1 / (cameraAspect * (mediaSize.width / mediaSize.height));

    return ClipRect(
      child: Transform.scale(
        scale: scale > 1 ? scale : 1 / scale,
        child: Center(
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildCapturedImageView() {
    return SizedBox.expand(
      child: Image.file(
        _capturedImage!,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildTopGradient() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 120,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.black.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              // App icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Color(0xFF1DB954),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plant Identifier',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    _isShowingCapturedImage
                        ? 'Photo Analysis'
                        : 'Live Detection',
                    style: TextStyle(
                      color: _isShowingCapturedImage
                          ? const Color(0xFFFFAB00)
                          : const Color(0xFF1DB954),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Live indicator dot
              if (!_isShowingCapturedImage)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1DB954),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated loader
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Loading Plant Identifier',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Initializing AI model & camera...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: const Color(0xFF1DB954),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFFF5252),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _initialize,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
