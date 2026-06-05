import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/main.dart';
import 'package:staff_attendance_app/services/ml_service.dart';
import 'package:staff_attendance_app/database/db_helper.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
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
  int _countdown = 0;
  String? _successName;

  int _totalStaffs = 0;
  int _presentToday = 0;
  
  Timer? _idleTimer;
  bool _isIdle = false;

  List<Map<String, dynamic>> _cachedStaffs = [];
  bool _embeddingsLoaded = false;
  CameraImage? _lastImage;
  bool _isSavingImage = false;
  String? _mismatchCorrectionRegNo;
  bool _isSuccessCancelled = false;
  bool _isDialogVisible = false;
  int _overrideCountdown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLiveStats();
    _loadStaffEmbeddings();
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
        _totalStaffs = stats['total_staffs'];
        _presentToday = stats['present_today'];
      });
    }
  }

  Future<void> _loadStaffEmbeddings() async {
    final db = ref.read(databaseProvider);
    final staffs = await db.getAllStaffs();
    
    for (var staff in staffs) {
      if (staff['embedding'] != null) {
        try {
          var decoded = jsonDecode(staff['embedding']);
          List<List<double>> parsedEmbeddings = [];
          if (decoded is List && decoded.isNotEmpty) {
            if (decoded[0] is List) {
              for (var emb in decoded) {
                parsedEmbeddings.add(List<double>.from(emb.map((e) => e.toDouble())));
              }
            } else {
              parsedEmbeddings.add(List<double>.from(decoded.map((e) => e.toDouble())));
            }
          }
          staff['parsed_embeddings'] = parsedEmbeddings;
        } catch (e) {
          staff['parsed_embeddings'] = <List<double>>[];
        }
      } else {
        staff['parsed_embeddings'] = <List<double>>[];
      }
    }
    
    if (mounted) {
      setState(() {
        _cachedStaffs = staffs;
        _embeddingsLoaded = true;
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;
    _controller = CameraController(
      cameras[1], 
      ResolutionPreset.low, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
      _startScanning();
      _flutterTts.speak("Look at the camera");
    } catch (e) {
      print("Camera init error: $e");
    }
  }

  void _resetIdleTimer(bool faceDetected) {
    if (faceDetected) {
      _idleTimer?.cancel();
      if (_isIdle) {
        setState(() => _isIdle = false);
      }
    } else {
      if (_idleTimer == null || !_idleTimer!.isActive) {
        _idleTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() => _isIdle = true);
          }
        });
      }
    }
  }

  int _livenessStep = 0; // Keeping for reference but unused
  List<int> _challengeSequence = [];
  DateTime? _challengeStartTime;

  DateTime _lastProcessTime = DateTime.now();

  void _startScanning() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    _controller!.startImageStream((CameraImage image) async {
      _lastImage = image;
      if (_isProcessing || _isDialogVisible || _overrideCountdown > 0) return;
      
      // Throttle processing to max ~1.5 frames per second to keep UI buttery smooth
      final now = DateTime.now();
      if (now.difference(_lastProcessTime).inMilliseconds < 600) return;
      
      _isProcessing = true;
      _lastProcessTime = now;

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
          _resetIdleTimer(true);
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
          _resetIdleTimer(false);
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
      if (!_embeddingsLoaded) return;
      
      if (_mismatchCorrectionRegNo != null) {
        // OVERRIDE LOGIC: Verify the face against the selected PIN's database embedding
        final overrideRegNo = _mismatchCorrectionRegNo!;
        final staff = _cachedStaffs.firstWhere((s) => s['register_no'] == overrideRegNo, orElse: () => <String, dynamic>{});
        if (staff.isNotEmpty) {
          final staffName = staff['name'] ?? 'Unknown';
          List<List<double>> staffEmbeddings = staff['parsed_embeddings'] ?? [];
          
          double minDistance = 999.0;
          for (var dbEmbedding in staffEmbeddings) {
            double distance = MLService().euclideanDistance(embedding, dbEmbedding);
            if (distance < minDistance) {
              minDistance = distance;
            }
          }

          // Use a slightly relaxed threshold for manual PIN entry (0.75) compared to strict 0.65
          if (minDistance < 0.75) {
            setState(() { _mismatchCorrectionRegNo = null; });
            _showPendingSuccess(staff, staffName);
            return;
          } else {
            // Unregistered or completely unmatched face
            setState(() { 
              _mismatchCorrectionRegNo = null; 
              _statusText = "Face Not Matched"; 
            });
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              setState(() { _challengePassed = false; _livenessStep = 0; });
              _isProcessing = false;
            }
            return;
          }
        }

      }
      
      String? recognizedRegNo;
      String? recognizedName;
      double minDistance = 999.0;

      for (var staff in _cachedStaffs) {
        List<List<double>> staffEmbeddings = staff['parsed_embeddings'] ?? [];
        if (staffEmbeddings.isEmpty) continue;

        for (var dbEmbedding in staffEmbeddings) {
          double distance = MLService().euclideanDistance(embedding, dbEmbedding);
          if (distance < minDistance) {
            minDistance = distance;
            // STRICT THRESHOLD (0.65) to prevent false positives and name confusion
            if (minDistance < 0.65) {
              recognizedRegNo = staff['register_no'];
              recognizedName = staff['name'];
            }
          }
        }
      }

      if (recognizedRegNo != null) {
        final staff = _cachedStaffs.firstWhere((s) => s['register_no'] == recognizedRegNo);
        _showPendingSuccess(staff, recognizedName!);
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
      if (errStr.length > 100) errStr = errStr.substring(0, 100);
      setState(() { _statusText = "Err: $errStr"; });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() { _challengePassed = false; _livenessStep = 0; });
        _isProcessing = false;
      }
    }
  }

  Map<String, dynamic>? _successStaff;

  void _showPendingSuccess(Map<String, dynamic> staff, String name) async {
    _isSuccessCancelled = false;
    _loadLiveStats(); 
    
    String pronounceName = name.replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ').toLowerCase(); 
    String registerNo = staff['register_no'] ?? '';
    
    if (registerNo.toUpperCase().startsWith('SMSNS')) {
      _flutterTts.speak("Confirming $pronounceName in 5 seconds");
    } else {
      _flutterTts.speak("Confirming $pronounceName in 5 seconds");
    }
    
    setState(() {
      _scanSuccess = true;
      _successName = name;
      _successStaff = staff;
      _countdown = 5;
      _statusText = "Confirming Entry...";
    });

    for (int i = 5; i > 0; i--) {
      if (!mounted || _isSuccessCancelled) return;
      setState(() { _countdown = i; });
      await Future.delayed(const Duration(seconds: 1));
    }
    
    if (!mounted || _isSuccessCancelled) return;

    // Log attendance NOW after the delay
    final db = ref.read(databaseProvider);
    final result = await db.logAttendance(registerNo, name, staff['dept'] ?? '');
    
    if (mounted) {
      if (registerNo.toUpperCase().startsWith('SMSNS')) {
        _flutterTts.speak("Nandri $pronounceName");
      } else {
        _flutterTts.speak("Marked ${result['marked_type']}");
      }
      
      setState(() {
        _scanSuccess = false;
        _challengePassed = false;
        _livenessStep = 0;
        _successName = null;
        _successStaff = null;
        _statusText = "Align face in view";
        _faceRect = null;
      });
      _isProcessing = false;
      _loadLiveStats();
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
    _idleTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveMismatchImage(CameraImage? imageToSave, String detectedName, String actualName) async {
    if (imageToSave == null || _isSavingImage) return;
    setState(() { _isSavingImage = true; });
    
    try {
      final img.Image convertedImage = _convertYUV420ToImage(imageToSave);
      img.Image finalImage = convertedImage;
      if (convertedImage.width > 640) {
        finalImage = img.copyResize(convertedImage, width: 640);
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final folderPath = '${directory.path}/Mismatch_Images';
      final folder = Directory(folderPath);
      if (!(await folder.exists())) {
        await folder.create(recursive: true);
      }
      
      String safeDetected = detectedName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      String safeActual = actualName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filePath = '$folderPath/mismatch_Detected_${safeDetected}_Actual_${safeActual}_$timestamp.jpg';
      
      final File file = File(filePath);
      await file.writeAsBytes(img.encodeJpg(finalImage, quality: 50));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Mismatch Image Saved!\nPath: $filePath", style: const TextStyle(fontSize: 12)),
          backgroundColor: AppTheme.accentEmerald,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      print("Error saving image: ${e.toString()}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error saving image: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() { _isSavingImage = false; });
    }
  }

  void _showMismatchCorrectionDialog() {
    _isSuccessCancelled = true; // Instantly cancel any pending wrong attendance
    _isDialogVisible = true;
    final CameraImage? frozenImage = _lastImage;
    final String wronglyDetectedName = _successName ?? 'Unknown';
    
    setState(() { 
      _isIdle = true; 
      _scanSuccess = false; // Hide success overlay so dialog is visible
    }); 
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? selectedRegNo;
        String pinCode = "";
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<Map<String, dynamic>> matchedStaffs = [];
            if (pinCode.isNotEmpty) {
              matchedStaffs = _cachedStaffs.where((s) => (s['register_no'] ?? '').toString().contains(pinCode)).toList();
              // Auto-select if there is exactly 1 match and pinCode has at least 2 digits
              if (matchedStaffs.length == 1 && pinCode.length >= 2 && selectedRegNo == null) {
                selectedRegNo = matchedStaffs.first['register_no'];
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.cardColor,
              title: const Text("Correct Mismatch", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Enter your ID number to verify mismatch:", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Text(pinCode.isEmpty ? "----" : pinCode, style: const TextStyle(color: AppTheme.accentCyan, fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  // Matching Staff Info
                  if (selectedRegNo != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.accentEmerald.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text("Selected: ${_cachedStaffs.firstWhere((s) => s['register_no'] == selectedRegNo, orElse: () => {'name': ''})['name']}", style: const TextStyle(color: AppTheme.accentEmerald, fontWeight: FontWeight.bold)),
                    )
                  else if (matchedStaffs.isNotEmpty && pinCode.isNotEmpty)
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        itemCount: matchedStaffs.length > 2 ? 2 : matchedStaffs.length,
                        itemBuilder: (c, i) => ListTile(
                          dense: true,
                          title: Text("${matchedStaffs[i]['name']} (${matchedStaffs[i]['register_no']})", style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            setDialogState(() {
                              selectedRegNo = matchedStaffs[i]['register_no'];
                            });
                          },
                        ),
                      ),
                    )
                  else if (pinCode.isNotEmpty)
                    const Text("No exact match found", style: TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: 250,
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var i = 1; i <= 9; i++)
                          ElevatedButton(
                            onPressed: () => setDialogState(() {
                              pinCode += i.toString();
                              selectedRegNo = null; // reset selection on new digit
                            }),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text(i.toString(), style: const TextStyle(fontSize: 24, color: Colors.white)),
                          ),
                        ElevatedButton(
                          onPressed: () => setDialogState(() {
                            if (pinCode.isNotEmpty) pinCode = pinCode.substring(0, pinCode.length - 1);
                            selectedRegNo = null;
                          }),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.5), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Icon(Icons.backspace, color: Colors.white),
                        ),
                        ElevatedButton(
                          onPressed: () => setDialogState(() {
                            pinCode += '0';
                            selectedRegNo = null;
                          }),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('0', style: TextStyle(fontSize: 24, color: Colors.white)),
                        ),
                        ElevatedButton(
                          onPressed: () => setDialogState(() {
                            pinCode = "";
                            selectedRegNo = null;
                          }),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent.withOpacity(0.5), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Icon(Icons.clear, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _isDialogVisible = false;
                    setState(() { _isIdle = false; });
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
                  onPressed: selectedRegNo == null ? null : () async {
                    Navigator.pop(context);
                    _isDialogVisible = false;
                    
                    final String actualName = _cachedStaffs.firstWhere((s) => s['register_no'] == selectedRegNo, orElse: () => {'name': 'Unknown'})['name'] ?? 'Unknown';
                    // Save the screenshot with both names
                    _saveMismatchImage(frozenImage, wronglyDetectedName, actualName);
                    
                    setState(() { 
                      _isIdle = false; 
                      _statusText = "Look at the camera...";
                      _overrideCountdown = 3;
                    });
                    
                    _flutterTts.speak("Look at the camera");
                    
                    for (int i = 3; i > 0; i--) {
                      if (!mounted) return;
                      setState(() { _overrideCountdown = i; });
                      await Future.delayed(const Duration(seconds: 1));
                    }
                    
                    if (!mounted) return;
                    setState(() {
                      _mismatchCorrectionRegNo = selectedRegNo;
                      _overrideCountdown = 0;
                    });
                  },
                  child: const Text("Re-verify & Mark", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    
    var imgData = img.Image(width: width, height: height);
    
    // Assuming NV21 format for Android or BGRA8888 for iOS
    if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          final int index = (h * width + w) * 4;
          final b = cameraImage.planes[0].bytes[index];
          final g = cameraImage.planes[0].bytes[index + 1];
          final r = cameraImage.planes[0].bytes[index + 2];
          imgData.setPixelRgb(w, h, r, g, b);
        }
      }
    } else {
      // NV21 or YUV420
      if (cameraImage.planes.length == 1) {
        final int frameSize = width * height;
        final bytes = cameraImage.planes[0].bytes;
        for (int h = 0; h < height; h++) {
          for (int w = 0; w < width; w++) {
            final int yIndex = h * width + w;
            final int uvIndex = frameSize + (h ~/ 2) * width + (w ~/ 2) * 2;
            
            int y = 0, u = 128, v = 128;
            if (yIndex < bytes.length) y = bytes[yIndex];
            if (uvIndex < bytes.length - 1) {
              v = bytes[uvIndex];
              u = bytes[uvIndex + 1];
            }
            
            int r = (y + (1.370705 * (v - 128))).round().clamp(0, 255);
            int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).round().clamp(0, 255);
            int b = (y + (1.732446 * (u - 128))).round().clamp(0, 255);
            
            imgData.setPixelRgb(w, h, r, g, b);
          }
        }
      } else {
        for (int h = 0; h < height; h++) {
          for (int w = 0; w < width; w++) {
            final int yIndex = h * cameraImage.planes[0].bytesPerRow + w;
            final int uvIndex = (h ~/ 2) * cameraImage.planes[1].bytesPerRow + (w ~/ 2) * 2;
            
            int y = 0, u = 128, v = 128;
            if (yIndex < cameraImage.planes[0].bytes.length) {
              y = cameraImage.planes[0].bytes[yIndex];
            }
            if (uvIndex < cameraImage.planes[1].bytes.length - 1) {
              v = cameraImage.planes[1].bytes[uvIndex];
              u = cameraImage.planes[1].bytes[uvIndex + 1];
            }
            
            int r = (y + (1.370705 * (v - 128))).round().clamp(0, 255);
            int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).round().clamp(0, 255);
            int b = (y + (1.732446 * (u - 128))).round().clamp(0, 255);
            
            imgData.setPixelRgb(w, h, r, g, b);
          }
        }
      }
    }
    
    if (cameras.isNotEmpty && cameras.length > 1) {
      imgData = img.copyRotate(imgData, angle: cameras[1].sensorOrientation);
    }
    return imgData;
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
                // Header (compact)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Hug contents tightly
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/St-Marys-school-logo.webp', height: 50, width: 50, fit: BoxFit.contain),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "St.Mary's School Attendance", 
                              style: TextStyle(
                                color: AppTheme.accentCyan, 
                                fontSize: 18, 
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatBadge("Total", _totalStaffs.toString(), Colors.white),
                          const SizedBox(width: 15),
                          _buildStatBadge("Present", _presentToday.toString(), AppTheme.accentEmerald),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                if (_scanSuccess)
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        _statusText, 
                        style: const TextStyle(
                          color: AppTheme.accentEmerald, 
                          fontSize: 28, 
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 10)]
                        )
                      ).animate().fadeIn(delay: 100.ms),
                    ],
                  )
                else
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
                if (_overrideCountdown > 0)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentCyan, width: 4),
                      ),
                      child: Text(
                        "$_overrideCountdown",
                        style: const TextStyle(color: AppTheme.accentCyan, fontSize: 60, fontWeight: FontWeight.bold),
                      ),
                    ).animate(onPlay: (c) => c.repeat()).scale(duration: 500.ms, curve: Curves.easeInOut),
                  ),
                
                if (_scanSuccess && _successStaff != null)
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 80),
                          const SizedBox(height: 15),
                          Text(
                            _successStaff!['name'] ?? 'Unknown',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black87, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _successStaff!['register_no'] ?? '',
                            style: const TextStyle(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentEmerald,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _statusText,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Countdown: $_countdown",
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                  )
                else if (!_scanSuccess)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: frameColor, width: 2),
                      ),
                      child: Text(
                        _statusText, 
                        style: TextStyle(
                          color: frameColor,
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ), 
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // MISMATCH BUZZER BUTTON
          if (!_isIdle)
            Positioned(
              right: 20,
              bottom: 120,
              child: FloatingActionButton(
                heroTag: "mismatchBuzzer",
                backgroundColor: Colors.redAccent,
                onPressed: _showMismatchCorrectionDialog,
                child: const Icon(Icons.report_problem, color: Colors.white, size: 30),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .shake(hz: 2, curve: Curves.easeInOut, duration: 1500.ms),
            ),

          // BLACKOUT IDLE SCREEN
          if (_isIdle)
            AnimatedOpacity(
              opacity: _isIdle ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
        ],
      ),
    );
  }
}
