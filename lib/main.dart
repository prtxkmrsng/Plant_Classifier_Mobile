import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

// Global reference pointer listing the physical cameras accessible on the host machine hardware
List<CameraDescription> globalAccessibleCameras = [];

Future<void> main() async {
  // Enforce binding guarantees for native platform channels before invoking asynchronous calls
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Populate the global lookup system array with current platform camera descriptions
    globalAccessibleCameras = await availableCameras();
  } catch (e) {
    debugPrint("Failed to locate camera hardware channels: $e");
  }

  runApp(const MasterApplicationRoot());
}

class MasterApplicationRoot extends StatelessWidget {
  const MasterApplicationRoot({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instant Plant Identifier',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const RealTimeClassifierScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RealTimeClassifierScreen extends StatefulWidget {
  const RealTimeClassifierScreen({Key? key}) : super(key: key);

  @override
  _RealTimeClassifierScreenState createState() =>
      _RealTimeClassifierScreenState();
}

class _RealTimeClassifierScreenState extends State<RealTimeClassifierScreen> {
  CameraController? _hardwareCameraController;
  ClassificationModel? _onDeviceModelInterpreter;

  String _currentLabelOutput = "Initializing ML Core Systems...";
  bool _isEngineProcessingFrame = false;
  bool _isSystemReady = false;

  @override
  void initState() {
    super.initState();
    _spinUpInferenceEngine();
  }

  Future<void> _spinUpInferenceEngine() async {
    // 1. Structural Validation of Machine Camera Availability
    if (globalAccessibleCameras.isEmpty) {
      setState(() {
        _currentLabelOutput =
            "Hardware Error: No back-facing camera arrays detected.";
      });
      return;
    }

    // 2. Initialize Model Parameters to match your python validation script
    try {
      // Read labels asset to determine number of classes for the model
      String labelsData = await rootBundle.loadString('assets/labels.txt');
      int numberOfClasses = labelsData
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .length;

      _onDeviceModelInterpreter = await PytorchLite.loadClassificationModel(
        "assets/best_plant_model.ptl",
        224,
        224,
        numberOfClasses,
        labelPath: "assets/labels.txt",
        ensureMatchingNumberOfClasses: false,
      );
    } catch (e) {
      setState(() {
        _currentLabelOutput =
            "Asset Fault: Failed to compile local model bytecode - $e";
      });
      return;
    }

    // 3. Bind the physical rear camera using optimal medium resolution configs
    _hardwareCameraController = CameraController(
      globalAccessibleCameras[0],
      ResolutionPreset
          .medium, // Configures 720p layouts to minimize video memory footprint
      enableAudio: false,
    );

    try {
      await _hardwareCameraController!.initialize();
    } catch (e) {
      setState(() {
        _currentLabelOutput =
            "Driver Failure: Failed to attach video stream pipe - $e";
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSystemReady = true;
      _currentLabelOutput = "Aim camera steady at flowers or leaves";
    });

    // 4. Hook into the Live Frame Buffer Stream Pipeline
    _hardwareCameraController!.startImageStream((
      CameraImage inputFrameBuffer,
    ) async {
      // Gate check: If the interpreter is busy calculating the previous matrix pass, instantly drop the current frame
      if (_isEngineProcessingFrame || _onDeviceModelInterpreter == null) return;

      if (!mounted) return;
      setState(() {
        _isEngineProcessingFrame = true;
      });

      try {
        // Execute native inference directly against mobile runtime memory registers
        String predictionResult = await _onDeviceModelInterpreter!
            .getCameraImagePrediction(
              inputFrameBuffer, // Only pass the raw image stream frame buffer here
            );

        if (mounted && predictionResult.trim().isNotEmpty) {
          setState(() {
            _currentLabelOutput = predictionResult;
          });
        }
      } catch (inferenceFault) {
        debugPrint("Inference Pipeline Drop Check: $inferenceFault");
      } finally {
        if (mounted) {
          setState(() {
            _isEngineProcessingFrame = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // Cleanly tear down streams and hardware drivers to prevent device kernel leaks
    _hardwareCameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSystemReady ||
        _hardwareCameraController == null ||
        !_hardwareCameraController!.value.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _currentLabelOutput,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. The Underlying Native Camera Canvas Render Target Layer
          CameraPreview(_hardwareCameraController!),

          // 2. Translucent Processing Indicators & Graphical HUD Overlay Layer
          Positioned(
            top: 50,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isEngineProcessingFrame
                    ? Colors.amber.withOpacity(0.8)
                    : Colors.green.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isEngineProcessingFrame ? Icons.bolt : Icons.visibility,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          // 3. Bottom HUD Text Display Card for Real-time Label Updates
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.green.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "REAL-TIME CLASSIFICATION RESULT",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentLabelOutput,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
