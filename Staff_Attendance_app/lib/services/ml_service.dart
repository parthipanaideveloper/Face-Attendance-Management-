import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  Interpreter? _interpreter;
  String? initError;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: true, // Enabled for blink/liveness detection
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool get isInitialized => _interpreter != null;

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');
      print('MobileFaceNet TFLite Model loaded successfully');
    } catch (e) {
      initError = e.toString();
      print('Error loading model: $e');
    }
  }

  Future<Face?> detectFace(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isNotEmpty) {
      return faces.first; // return the first face found
    }
    return null;
  }

  Future<List<Face>> detectFacesStream(InputImage inputImage) async {
    return await _faceDetector.processImage(inputImage);
  }

  Future<List<double>?> getEmbeddingFromStream(Uint8List bytes, int width, int height, Face face, int sensorOrientation) async {
    if (_interpreter == null) throw Exception("Model not loaded: $initError");

    var imgData = img.Image(width: width, height: height);
    final int frameSize = width * height;

    for (int h = 0; h < height; h++) {
      for (int w = 0; w < width; w++) {
        final int yIndex = h * width + w;
        final int uvIndex = frameSize + (h ~/ 2) * width + (w ~/ 2) * 2;

        if (uvIndex + 1 >= bytes.length) continue;

        final y = bytes[yIndex];
        final v = bytes[uvIndex];
        final u = bytes[uvIndex + 1];

        int r = (y + (1.370705 * (v - 128))).round().clamp(0, 255);
        int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).round().clamp(0, 255);
        int b = (y + (1.732446 * (u - 128))).round().clamp(0, 255);

        imgData.setPixelRgb(w, h, r, g, b);
      }
    }

    final rotatedImage = img.copyRotate(imgData, angle: sensorOrientation);

    final bbox = face.boundingBox;
    int x = max(0, bbox.left.toInt());
    int y = max(0, bbox.top.toInt());
    int right = min(rotatedImage.width, bbox.right.toInt());
    int bottom = min(rotatedImage.height, bbox.bottom.toInt());
    int w = right - x;
    int h = bottom - y;

    if (w <= 0 || h <= 0) throw Exception("Face crop invalid: w=$w, h=$h, bounds=${rotatedImage.width}x${rotatedImage.height}");

    final croppedImage = img.copyCrop(rotatedImage, x: x, y: y, width: w, height: h);
    final resizedImage = img.copyResize(croppedImage, width: 112, height: 112);

    var input = List.generate(1, (i) => 
      List.generate(112, (j) => 
        List.generate(112, (k) => 
          List.generate(3, (l) => 0.0))));

    for (int yy = 0; yy < 112; yy++) {
      for (int xx = 0; xx < 112; xx++) {
        final pixel = resizedImage.getPixel(xx, yy);
        input[0][yy][xx][0] = (pixel.r - 127.5) / 128.0;
        input[0][yy][xx][1] = (pixel.g - 127.5) / 128.0;
        input[0][yy][xx][2] = (pixel.b - 127.5) / 128.0;
      }
    }

    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final int outputSize = outputShape.length > 1 ? outputShape[1] : outputShape[0];
    var output = List.generate(1, (i) => List.filled(outputSize, 0.0));
    _interpreter!.run(input, output);

    List<double> emb = output[0];
    double norm = 0.0;
    for (int i = 0; i < emb.length; i++) {
      norm += emb[i] * emb[i];
    }
    norm = sqrt(norm);
    if (norm > 0) {
      for (int i = 0; i < emb.length; i++) {
        emb[i] = emb[i] / norm;
      }
    }
    return emb;
  }

  Future<List<double>?> getEmbedding(File imageFile, Face face) async {
    if (_interpreter == null) return null;

    final bytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    // Crop face
    final bbox = face.boundingBox;
    int x = max(0, bbox.left.toInt());
    int y = max(0, bbox.top.toInt());
    int w = min(originalImage.width - x, bbox.width.toInt());
    int h = min(originalImage.height - y, bbox.height.toInt());

    if (w <= 0 || h <= 0) return null;

    final croppedImage = img.copyCrop(originalImage, x: x, y: y, width: w, height: h);

    // Resize to 112x112
    final resizedImage = img.copyResize(croppedImage, width: 112, height: 112);

    // Normalize input to float32 [-1, 1]
    var input = List.generate(1, (i) => 
      List.generate(112, (j) => 
        List.generate(112, (k) => 
          List.generate(3, (l) => 0.0))));

    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[0][y][x][0] = (pixel.r - 127.5) / 128.0;
        input[0][y][x][1] = (pixel.g - 127.5) / 128.0;
        input[0][y][x][2] = (pixel.b - 127.5) / 128.0;
      }
    }

    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final int outputSize = outputShape.length > 1 ? outputShape[1] : outputShape[0];
    var output = List.generate(1, (i) => List.filled(outputSize, 0.0));
    _interpreter!.run(input, output);

    List<double> emb = output[0];
    double norm = 0.0;
    for (int i = 0; i < emb.length; i++) {
      norm += emb[i] * emb[i];
    }
    norm = sqrt(norm);
    if (norm > 0) {
      for (int i = 0; i < emb.length; i++) {
        emb[i] = emb[i] / norm;
      }
    }
    return emb;
  }

  double euclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 9999.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow((e1[i] - e2[i]), 2);
    }
    return sqrt(sum);
  }

  void dispose() {
    _interpreter?.close();
    _faceDetector.close();
  }
}
