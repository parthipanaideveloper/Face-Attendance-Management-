import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_attendance_app/services/ml_service.dart';
import 'package:student_attendance_app/main.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:student_attendance_app/core/providers/db_provider.dart';
import 'package:student_attendance_app/core/theme/app_theme.dart';
import 'package:face_anti_spoofing_detector/face_anti_spoofing_detector.dart';
import 'package:student_attendance_app/features/attendance/scanner_screen.dart';
import 'package:student_attendance_app/features/attendance/home_screen.dart';
import 'package:flutter/foundation.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _regCtrl = TextEditingController();
  final TextEditingController _deptCtrl = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  String _gender = 'Male';
  String _designation = 'Teaching Staff';
  bool _isProcessing = false;

  int _poseStep = 0; // 0: Idle, 1: Straight, 2: Left, 3: Right, 4: Up, 5: Down, 6: Done
  List<List<double>> _collectedEmbeddings = [];
  String _instructionText = "";
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.10,
    ),
  );
  String? _profileImagePath;

  // We use ValueNotifier to instantly update the popup dialog text without full screen rebuilds
  final ValueNotifier<String> _dialogInstruction = ValueNotifier<String>("");
  final ValueNotifier<int> _dialogStep = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;
    _controller = CameraController(cameras[1], ResolutionPreset.high, enableAudio: false, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
    try {
      await _controller!.initialize();
      await FaceAntiSpoofingDetector.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print("Camera init error: $e");
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _startRegistration() async {
    if (_nameCtrl.text.isEmpty || _regCtrl.text.isEmpty || _deptCtrl.text.isEmpty) {
      _showError("Please fill all fields");
      return;
    }
    
    _collectedEmbeddings.clear();
    _poseStep = -1; // -1 means countdown
    setState(() {
      _dialogStep.value = _poseStep;
    });

    // 3 Second Countdown to prevent the Admin's face from being accidentally scanned!
    for (int i = 3; i > 0; i--) {
      _dialogInstruction.value = "Get Ready in $i...";
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() {
      _poseStep = 1;
    });
    _dialogStep.value = 1;
    _dialogInstruction.value = "Look Straight at the camera";
    _flutterTts.speak("Please look straight at the camera.");
    _controller!.startImageStream((image) => _processRegistrationStream(image));
  }

  int _framesCapturedInCurrentPose = 0;

  Future<void> _processRegistrationStream(CameraImage image) async {
    if (_isProcessing || _poseStep == 0 || _poseStep > 5) return;
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
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final yaw = face.headEulerAngleY ?? 0.0;
        final pitch = face.headEulerAngleX ?? 0.0;

        // Spoofing detection disabled during registration for stability
        
        bool poseMatched = false;
        // Loosened thresholds to prevent getting stuck
        if (_poseStep == 1) poseMatched = true; // Any face looking at the phone is considered "straight" enough
        else if (_poseStep == 2 && yaw > 12) poseMatched = true; // Turn right/left
        else if (_poseStep == 3 && yaw < -12) poseMatched = true;
        else if (_poseStep == 4 && pitch > 8) poseMatched = true; // Look up
        else if (_poseStep == 5 && pitch < -8) poseMatched = true; // Look down

        if (poseMatched) {
          final embedding = await MLService().getEmbeddingFromStream(bytes, image.width, image.height, face, cameras[1].sensorOrientation);
          if (embedding != null) {
            _collectedEmbeddings.add(embedding);
            _framesCapturedInCurrentPose++;
            
            if (_poseStep == 1 && _framesCapturedInCurrentPose == 1) {
              try {
                await _controller!.stopImageStream();
                final file = await _controller!.takePicture();
                final directory = await getApplicationDocumentsDirectory();
                _profileImagePath = "${directory.path}/${_regCtrl.text}.jpg";
                await File(file.path).copy(_profileImagePath!);
                await _controller!.startImageStream((img) => _processRegistrationStream(img));
              } catch (e) {
                print("Failed to take profile picture: $e");
                if (!_controller!.value.isStreamingImages) {
                  await _controller!.startImageStream((img) => _processRegistrationStream(img));
                }
              }
            }

            if (_framesCapturedInCurrentPose < 8) {
               // Update UI to show scanning progress
               if (_poseStep == 1) _dialogInstruction.value = "Look Straight... $_framesCapturedInCurrentPose/8";
               else if (_poseStep == 2) _dialogInstruction.value = "Turn Head Left... $_framesCapturedInCurrentPose/8";
               else if (_poseStep == 3) _dialogInstruction.value = "Turn Head Right... $_framesCapturedInCurrentPose/8";
               else if (_poseStep == 4) _dialogInstruction.value = "Tilt Head Up... $_framesCapturedInCurrentPose/8";
               else if (_poseStep == 5) _dialogInstruction.value = "Tilt Head Down... $_framesCapturedInCurrentPose/8";
               
               // 150ms gap between frames to capture micro-expressions
               await Future.delayed(const Duration(milliseconds: 150));
            } else {
               // Move to next pose
               _poseStep++;
               _dialogStep.value = _poseStep;
               _framesCapturedInCurrentPose = 0;

               if (_poseStep == 2) { _dialogInstruction.value = "Turn Head to the Left"; _flutterTts.speak("Turn Head Left"); }
               else if (_poseStep == 3) { _dialogInstruction.value = "Turn Head to the Right"; _flutterTts.speak("Turn Head Right"); }
               else if (_poseStep == 4) { _dialogInstruction.value = "Tilt Head Upwards"; _flutterTts.speak("Look Up"); }
               else if (_poseStep == 5) { _dialogInstruction.value = "Tilt Head Downwards"; _flutterTts.speak("Look Down"); }
               else if (_poseStep == 6) {
                 _dialogInstruction.value = "Processing 40-Frame Model...";
                 _flutterTts.speak("Scan complete. Processing.");
                 await _controller!.stopImageStream();
                 _finalizeRegistration();
               }
            }
          }
        }
      }
    } catch (e) {
      print("Stream error: $e");
    }
    _isProcessing = false;
  }

  Future<void> _finalizeRegistration() async {
    try {
      final db = ref.read(databaseProvider);
      final existing = await db.getStudentByRegisterNo(_regCtrl.text);
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee with this Register Number already exists!"), backgroundColor: Colors.redAccent));
          setState(() => _poseStep = 0);
        }
        return;
      }

      final student = {
        'name': _nameCtrl.text,
        'register_no': _regCtrl.text,
        'dept': _deptCtrl.text,
        'gender': _gender,
        'designation': _designation,
        'image_path': _profileImagePath ?? '',
        'embedding': jsonEncode(_collectedEmbeddings)
      };
      
      await db.insertStudent(student);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee Registered Successfully!"), backgroundColor: AppTheme.accentEmerald));
        Future.delayed(const Duration(seconds: 1), () async {
          if (mounted) {
            if (_controller != null) {
              await _controller!.dispose();
              _controller = null;
            }
            final homeState = context.findAncestorStateOfType<HomeScreenState>();
            if (homeState != null) {
               homeState.switchToTab(0);
            } else {
               Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
            }
          }
        });
      }
    } catch (e) {
      _showError("Database Error: $e");
      setState(() => _poseStep = 0);
    }
  }

  Future<void> _uploadPhotos() async {
    if (_nameCtrl.text.isEmpty || _regCtrl.text.isEmpty || _deptCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields first!")));
      return;
    }

    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isEmpty) return;
    
    setState(() {
      _poseStep = -1; // Loading state
      _dialogInstruction.value = "Processing ${images.length} photos...";
    });

    int processedCount = 0;
    _collectedEmbeddings.clear();

    try {
      for (var imgFile in images) {
        final File file = File(imgFile.path);
        final face = await MLService().detectFace(file);
        if (face != null) {
          final embedding = await MLService().getEmbedding(file, face);
          if (embedding != null) {
             _collectedEmbeddings.add(embedding);
             processedCount++;
             if (_profileImagePath == null) {
                final directory = await getApplicationDocumentsDirectory();
                _profileImagePath = "${directory.path}/${_regCtrl.text}.jpg";
                await file.copy(_profileImagePath!);
             }
          }
        }
      }

      if (_collectedEmbeddings.isEmpty) {
        throw Exception("No valid faces found in any of the uploaded photos.");
      }

      _dialogInstruction.value = "Successfully extracted $processedCount vectors. Finalizing...";
      await Future.delayed(const Duration(seconds: 1));
      await _finalizeRegistration();

    } catch (e) {
      _showError("Photo Processing Error: $e");
      setState(() => _poseStep = 0);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: AppTheme.accentCyan),
      filled: true,
      fillColor: AppTheme.cardColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentCyan, width: 2)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _nameCtrl.dispose();
    _regCtrl.dispose();
    _deptCtrl.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    
    if (_poseStep != 0) {
      return Scaffold(
        backgroundColor: AppTheme.bgColor,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Face Registration", 
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 40),
                Container(
                  height: 350, width: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentCyan, width: 4),
                    boxShadow: [BoxShadow(color: AppTheme.accentCyan.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: ClipOval(
                        child: _controller != null && _controller!.value.isInitialized && _poseStep > 0
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: isPortrait 
                                ? (_controller!.value.previewSize?.height ?? 350)
                                : (_controller!.value.previewSize?.width ?? 350),
                            height: isPortrait 
                                ? (_controller!.value.previewSize?.width ?? 350)
                                : (_controller!.value.previewSize?.height ?? 350),
                            child: CameraPreview(_controller!),
                          ),
                        )
                      : const Center(child: Icon(Icons.cloud_upload, size: 100, color: AppTheme.accentCyan)),
                  ),
                ),
                const SizedBox(height: 40),
                ValueListenableBuilder<String>(
                  valueListenable: _dialogInstruction,
                  builder: (context, text, child) {
                    return Text(
                      text,
                      style: const TextStyle(color: AppTheme.accentEmerald, fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                const SizedBox(height: 40),
                if (_poseStep == -1) 
                  const CircularProgressIndicator(color: AppTheme.accentEmerald),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text("Employee Registration", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Full Name", Icons.person)),
            const SizedBox(height: 16),
            TextField(controller: _regCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Register Number", Icons.badge)),
            const SizedBox(height: 16),
            TextField(controller: _deptCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Department", Icons.business)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _gender,
              dropdownColor: AppTheme.cardColor,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Gender", Icons.person),
              items: ['Male', 'Female', 'Others'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) => setState(() => _gender = val!),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _designation,
              dropdownColor: AppTheme.cardColor,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Designation", Icons.work),
              items: ['Teaching Staff', 'Non-Teaching Staff', 'Admin'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => _designation = val!),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_poseStep > 0 || _controller == null || !_controller!.value.isInitialized) ? null : _startRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Start 3D Face Scan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.bgColor)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _poseStep > 0 ? null : _uploadPhotos,
                icon: const Icon(Icons.photo_library, color: Colors.orangeAccent),
                label: const Text("Upload Photos (Gallery)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orangeAccent, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
