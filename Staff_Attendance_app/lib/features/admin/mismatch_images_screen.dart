import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';

class MismatchImagesScreen extends StatefulWidget {
  const MismatchImagesScreen({super.key});

  @override
  State<MismatchImagesScreen> createState() => _MismatchImagesScreenState();
}

class _MismatchImagesScreenState extends State<MismatchImagesScreen> {
  List<File> _images = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final folderPath = '${directory.path}/Mismatch_Images';
      final folder = Directory(folderPath);
      
      if (await folder.exists()) {
        final List<File> files = [];
        await for (var entity in folder.list(recursive: false, followLinks: false)) {
          if (entity is File && entity.path.endsWith('.jpg')) {
            files.add(entity);
          }
        }
        
        // Cache last modified times to avoid multiple async reads during sort
        final Map<String, DateTime> modTimes = {};
        for (var file in files) {
          modTimes[file.path] = await file.lastModified();
        }
        
        // Sort by newest first
        files.sort((a, b) => modTimes[b.path]!.compareTo(modTimes[a.path]!));
        
        if (mounted) {
          setState(() {
            _images = files;
          });
        }
      }
    } catch (e) {
      print("Error loading images: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteImage(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        _loadImages();
      }
    } catch (e) {
      print("Error deleting image: $e");
    }
  }

  Future<void> _shareImage(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'Mismatch Image captured by Face Attendance');
    } catch (e) {
      print("Error sharing image: $e");
    }
  }

  void _showImageDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(file, fit: BoxFit.contain),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                  onPressed: () {
                    Navigator.pop(context);
                    _shareImage(file);
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text("Share", style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteImage(file);
                  },
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text("Delete", style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Mismatch Captures"),
        backgroundColor: AppTheme.cardColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : _images.isEmpty
              ? const Center(
                  child: Text(
                    "No mismatch images captured yet.",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    final file = _images[index];
                    return GestureDetector(
                      onTap: () => _showImageDialog(file),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(file, fit: BoxFit.cover),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black.withOpacity(0.6),
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                child: Text(
                                  file.path.split('/').last.replaceAll('mismatch_', '').replaceAll('.jpg', ''),
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
