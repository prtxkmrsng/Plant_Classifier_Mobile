import 'dart:math' as math;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:pytorch_lite/image_utils_isolate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../utils/label_parser.dart';

/// Prediction result with parsed taxonomy and confidence.
class PredictionResult {
  final TaxonomyResult taxonomy;
  final String rawLabel;
  final double confidence;

  const PredictionResult({
    required this.taxonomy,
    required this.rawLabel,
    required this.confidence,
  });
}

/// Helper function to run in Isolate for image preprocessing
/// Replicates Python's transforms.Resize(256) and CenterCrop(224)
Uint8List _preprocessImageIsolate(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;

  // 1. Resize smaller edge to 256
  img.Image resized;
  if (image.width < image.height) {
    resized = img.copyResize(image, width: 256);
  } else {
    resized = img.copyResize(image, height: 256);
  }

  // 2. Center crop to 224x224
  final x = (resized.width - 224) ~/ 2;
  final y = (resized.height - 224) ~/ 2;
  final cropped = img.copyCrop(resized, x: x, y: y, width: 224, height: 224);

  return img.encodeJpg(cropped);
}

/// Service that manages loading the PyTorch Lite model and running inference.
class ModelService {
  ClassificationModel? _model;
  bool _isLoading = false;
  String? _loadError;
  int _numberOfClasses = 0;

  bool get isLoaded => _model != null;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  Future<void> loadModel() async {
    if (_isLoading || _model != null) return;

    _isLoading = true;
    _loadError = null;

    try {
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      final labels =
          labelsData.split('\n').where((line) => line.trim().isNotEmpty);
      _numberOfClasses = labels.length;

      _model = await PytorchLite.loadClassificationModel(
        "assets/best_plant_model.ptl",
        224,
        224,
        _numberOfClasses,
        labelPath: "assets/labels.txt",
      );
    } catch (e) {
      _loadError = "Failed to load model: $e";
      debugPrint(_loadError);
    } finally {
      _isLoading = false;
    }
  }

  Future<PredictionResult?> predictFromCamera(
    CameraImage cameraImage,
    int rotation,
  ) async {
    if (_model == null) return null;

    try {
      // Convert CameraImage to Jpeg bytes
      final rawBytes = await ImageUtilsIsolate.convertCameraImageToBytes(cameraImage, rotation: rotation);
      if (rawBytes == null) return null;

      // Apply Resize(256) + CenterCrop(224)
      final croppedBytes = await compute(_preprocessImageIsolate, rawBytes);

      // Run inference using imageLib mode to bypass Android BitmapFactory RGB_565 corruption
      final scores = await _model!.getImagePredictionList(
        croppedBytes,
        preProcessingMethod: PreProcessingMethod.imageLib,
      );

      final floatBytes = await ImageUtilsIsolate.convertImageBytesToFloatBuffer(
        croppedBytes,
        224,
        224,
        [0.485, 0.456, 0.406],
        [0.229, 0.224, 0.225],
      );
      final floatList = Float32List.view(floatBytes.buffer);
      debugPrint("DART TENSOR FIRST 5 VALUES: ${floatList.take(5).toList()}");

      debugPrint("INFERENCE COMPLETED. SCORES LENGTH: ${scores.length}");
      if (scores.isNotEmpty) {
        var sortedScores = List<double>.from(scores)..sort((a, b) => b.compareTo(a));
        debugPrint("TOP 5 SCORES: ${sortedScores.take(5).toList()}");
      }

      if (scores.isEmpty) return null;

      final rawLabel = await _model!.getImagePrediction(
        croppedBytes,
        preProcessingMethod: PreProcessingMethod.imageLib,
      );

      if (rawLabel.trim().isEmpty) return null;

      final confidence = _getConfidence(scores);
      final taxonomy = LabelParser.parse(rawLabel);

      debugPrint("PREDICTED RAW LABEL: $rawLabel (Confidence: ${(confidence * 100).toStringAsFixed(1)}%)");
      debugPrint("PARSED TAXONOMY: Kingdom=${taxonomy.kingdom}, Phylum=${taxonomy.phylum}, Class=${taxonomy.className}, Order=${taxonomy.order}, Family=${taxonomy.family}, Genus=${taxonomy.genus}, Species=${taxonomy.species}");

      return PredictionResult(
        taxonomy: taxonomy,
        rawLabel: rawLabel,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint("Camera inference error: $e");
      return null;
    }
  }

  Future<PredictionResult?> predictFromFile(File imageFile) async {
    if (_model == null) return null;

    try {
      final imageBytes = await imageFile.readAsBytes();
      
      // Apply Resize(256) + CenterCrop(224)
      final croppedBytes = await compute(_preprocessImageIsolate, imageBytes);

      final scores = await _model!.getImagePredictionList(
        croppedBytes,
        preProcessingMethod: PreProcessingMethod.imageLib,
      );

      final floatBytes = await ImageUtilsIsolate.convertImageBytesToFloatBuffer(
        croppedBytes,
        224,
        224,
        [0.485, 0.456, 0.406],
        [0.229, 0.224, 0.225],
      );
      final floatList = Float32List.view(floatBytes.buffer);
      debugPrint("DART TENSOR FIRST 5 VALUES: ${floatList.take(5).toList()}");

      debugPrint("INFERENCE COMPLETED. SCORES LENGTH: ${scores.length}");
      if (scores.isNotEmpty) {
        var sortedScores = List<double>.from(scores)..sort((a, b) => b.compareTo(a));
        debugPrint("TOP 5 SCORES: ${sortedScores.take(5).toList()}");
      }

      if (scores.isEmpty) return null;

      final rawLabel = await _model!.getImagePrediction(
        croppedBytes,
        preProcessingMethod: PreProcessingMethod.imageLib,
      );

      if (rawLabel.trim().isEmpty) return null;

      final confidence = _getConfidence(scores);
      final taxonomy = LabelParser.parse(rawLabel);

      debugPrint("PREDICTED RAW LABEL: $rawLabel (Confidence: ${(confidence * 100).toStringAsFixed(1)}%)");
      debugPrint("PARSED TAXONOMY: Kingdom=${taxonomy.kingdom}, Phylum=${taxonomy.phylum}, Class=${taxonomy.className}, Order=${taxonomy.order}, Family=${taxonomy.family}, Genus=${taxonomy.genus}, Species=${taxonomy.species}");

      return PredictionResult(
        taxonomy: taxonomy,
        rawLabel: rawLabel,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint("Image inference error: $e");
      return null;
    }
  }

  Future<File?> pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint("Gallery picker error: $e");
    }
    return null;
  }

  double _getConfidence(List<double> scores) {
    if (scores.isEmpty) return 0.0;
    
    final maxScore = scores.reduce(math.max);
    
    // Check if the model already applied Softmax (sum of scores ~ 1.0)
    double sum = 0.0;
    for (final s in scores) sum += s;
    
    if ((sum - 1.0).abs() < 0.1) {
      return maxScore.clamp(0.0, 1.0);
    }
    
    // Otherwise apply softmax to get confidence
    double sumExp = 0.0;
    for (final s in scores) {
      sumExp += math.exp((s - maxScore).clamp(-80.0, 80.0));
    }
    if (sumExp == 0.0) return 0.0;
    
    return (1.0 / sumExp).clamp(0.0, 1.0);
  }

  void dispose() {
    _model = null;
  }
}
