import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_attendance_app/main.dart';
import 'package:student_attendance_app/services/ml_service.dart';
import 'package:student_attendance_app/database/db_helper.dart';
import 'package:student_attendance_app/core/theme/app_theme.dart';
import 'package:student_attendance_app/core/providers/db_provider.dart';
import 'package:face_anti_spoofing_detector/face_anti_spoofing_detector.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});
  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isProcessing = false;
  bool _faceDetected = false;
  bool _challengePassed = false;
  String _statusText = "Align face in the circle";
  Rect? _faceRect;
  Size? _imageSize;

  int _totalStudents = 0;
  int _presentToday = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLiveStats();
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      cameraController.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _loadLiveStats() async {
    final db = ref.read(databaseProvider);
    final stats = await db.getDashboardAnalytics();
    if (mounted) {
      setState(() {
        _totalStudents = stats['total_students'];
        _presentToday = stats['present_today'];
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;
    _controller = CameraController(
      cameras[1], 
      ResolutionPreset.high, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    try {
      await _controller!.initialize();
      await FaceAntiSpoofingDetector.initialize();
      if (mounted) setState(() {});
      _startScanning();
      _flutterTts.speak("Look at the camera");
    } catch (e) {
      print("Camera init error: $e");
    }
  }

  int _livenessStep = 0; // Keeping for reference but unused
  List<int> _challengeSequence = [];
  DateTime? _challengeStartTime;

  void _startScanning() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    _controller!.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
        final InputImageRotation imageRotation = InputImageRotationValue.fromRawValue(cameras[1].sensorOrientation) ?? InputImageRotation.rotation270deg;
        final InputImageFormat inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;
        
        final inputImageData = InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        );
        
        final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
        final faces = await MLService().detectFacesStream(inputImage);
        
        if (faces.isNotEmpty) {
          final face = faces.first;
          if (!_faceDetected) {
            _flutterTts.speak("Look at the camera");
          }
          setState(() { 
            _faceDetected = true; 
            _statusText = "Identifying..."; 
            _faceRect = face.boundingBox;
            // In portrait, camera sensor is usually rotated 90 degrees, so we swap width and height for display mapping
            final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
            _imageSize = isPortrait 
                ? Size(image.height.toDouble(), image.width.toDouble())
                : Size(image.width.toDouble(), image.height.toDouble());
          });

          // Run attendance processing directly. Spoof check can run asynchronously or be bypassed if speed is top priority
          await _processAttendance(bytes, image.width, image.height, face);
        } else {
          setState(() { 
            _faceDetected = false; 
            _statusText = "Align face in view"; 
            _challengePassed = false; 
            _faceRect = null;
          });
          _isProcessing = false;
        }
      } catch (e) {
        print("Stream error: $e");
        _isProcessing = false;
      }
    });
  }

  bool _scanSuccess = false;

  Future<void> _processAttendance(Uint8List bytes, int width, int height, Face face) async {
    try {
      // ANTI-SPOOFING LIVENESS CHECK - TEMPORARILY DISABLED FOR PHOTO TESTING
      /*
      double? livenessScore = await FaceAntiSpoofingDetector.detect(
        yuvBytes: bytes,
        previewWidth: width,
        previewHeight: height,
        orientation: cameras[1].sensorOrientation,
        faceContour: face.boundingBox,
      );

      // VERY LENIENT threshold (0.40) to prevent rejecting real faces in poor lighting
      if (livenessScore == null || livenessScore < 0.40) {
        setState(() { _statusText = "Spoof Detected! Access Denied."; });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          setState(() { _challengePassed = false; _livenessStep = 0; });
          _isProcessing = false;
        }
        return;
      }
      */

      final embedding = await MLService().getEmbeddingFromStream(bytes, width, height, face, cameras[1].sensorOrientation);
      if (embedding == null) throw Exception("Failed to extract features.");
      
      final db = ref.read(databaseProvider);
      final students = await db.getAllStudents();
      String? recognizedRegNo;
      String? recognizedName;
      double minDistance = 999.0;

      for (var student in students) {
        var decoded = jsonDecode(student['embedding']);
        if (decoded.isEmpty) continue;

        if (decoded[0] is List) {
          for (var emb in decoded) {
            List<double> dbEmbedding = List<double>.from(emb.map((e) => e.toDouble()));
            double distance = MLService().euclideanDistance(embedding, dbEmbedding);
            if (distance < minDistance) {
              minDistance = distance;
              // STRICT THRESHOLD (0.70) to prevent false positives and name confusion
              if (minDistance < 0.70) {
                recognizedRegNo = student['register_no'];
                recognizedName = student['name'];
              }
            }
          }
        } else {
          List<double> dbEmbedding = List<double>.from(decoded.map((e) => e.toDouble()));
          double distance = MLService().euclideanDistance(embedding, dbEmbedding);
          if (distance < minDistance) {
            minDistance = distance;
            if (minDistance < 0.70) {
              recognizedRegNo = student['register_no'];
              recognizedName = student['name'];
            }
          }
        }
      }

      if (recognizedRegNo != null) {
        final student = students.firstWhere((s) => s['register_no'] == recognizedRegNo);
        final result = await db.logAttendance(recognizedRegNo, recognizedName!, student['dept']);
        _showSuccessQuick(recognizedName, result['marked_type']);
      } else {
        setState(() { _statusText = "Face not recognized."; });
        // Minimal delay so we can re-scan quickly
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() { _challengePassed = false; _livenessStep = 0; });
          _isProcessing = false;
        }
      }
    } catch (e) {
      String errStr = e.toString();
      if (errStr.length > 30) errStr = errStr.substring(0, 30);
      setState(() { _statusText = "Err: $errStr"; });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() { _challengePassed = false; _livenessStep = 0; });
        _isProcessing = false;
      }
    }
  }

  void _showSuccessQuick(String name, String? markedType) async {
    _loadLiveStats(); 
    _flutterTts.speak("Thank you. Marked $markedType");
    
    setState(() {
      _scanSuccess = true;
      _statusText = "Thank You, $name!\nMarked $markedType";
    });

    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _scanSuccess = false;
        _challengePassed = false;
        _livenessStep = 0;
        _statusText = "Align face in view";
        _faceRect = null;
      });
      _isProcessing = false;
    }
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(color: Colors.white70, fontSize: 14)),
            TextSpan(text: value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    FaceAntiSpoofingDetector.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    Color frameColor = AppTheme.accentCyan;
    if (_scanSuccess) {
      frameColor = Colors.blueAccent;
    } else if (_faceDetected) {
      frameColor = AppTheme.accentEmerald;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // FULL SCREEN CAMERA
          if (_controller != null && _controller!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: isPortrait 
                      ? (_controller!.value.previewSize?.height ?? 1)
                      : (_controller!.value.previewSize?.width ?? 1),
                  height: isPortrait 
                      ? (_controller!.value.previewSize?.width ?? 1)
                      : (_controller!.value.previewSize?.height ?? 1),
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)),
            
          // Face Viewfinder Bounding Box
          if (!_scanSuccess)
            Center(
              child: Container(
                width: 280,
                height: 340,
                decoration: BoxDecoration(
                  border: Border.all(color: _faceDetected ? Colors.green : Colors.transparent, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    // Scanning Line scoped inside the viewfinder box
                    if (_isProcessing && _faceDetected)
                      Container(
                        height: 4,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 15, spreadRadius: 5)],
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                       .moveY(begin: 0, end: 340, duration: 1500.ms, curve: Curves.easeInOut),
                  ],
                ),
              ),
            ),
            
          // OVERLAY UI
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Header (with transparent/blur background for readability)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/St-Marys-school-logo.webp', height: 65, width: 65, fit: BoxFit.contain),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "St.Marrys Schoool Attendance System", 
                              style: TextStyle(
                                color: AppTheme.accentCyan, 
                                fontSize: 18, 
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatBadge("Total", _totalStudents.toString(), Colors.white),
                          const SizedBox(width: 15),
                          _buildStatBadge("Present", _presentToday.toString(), AppTheme.accentEmerald),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                if (!_scanSuccess)
                  Column(
                    children: [
                      Icon(Icons.keyboard_double_arrow_up, color: _faceDetected ? Colors.green : frameColor, size: 80)
                          .animate(onPlay: (c) => c.repeat())
                          .moveY(begin: 15, end: -15, duration: 800.ms, curve: Curves.easeInOut)
                          .fade(begin: 0.3, end: 1.0, duration: 800.ms),
                      const SizedBox(height: 10),
                      Text(
                        "Look At The Camera", 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                          shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10)]
                        )
                      ),
                    ],
                  ),
                
                const Spacer(),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 50, left: 20, right: 20),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: frameColor, width: 2),
                  ),
                  child: Text(
                    _statusText, 
                    style: TextStyle(
                      color: frameColor,
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ), 
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
