import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PickedEvidence {
  final String tempPath;
  final String fileName;
  final int fileSize;
  final String fileType; // 'photo', 'video', 'audio', 'document'
  final String mimeType;

  PickedEvidence({
    required this.tempPath,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.mimeType,
  });

  String get formattedSize => EvidenceService.formatBytes(fileSize);
}

class EvidenceService {
  static final ImagePicker _picker = ImagePicker();

  static const int maxFileSize = 50 * 1024 * 1024; // 50 MB limit

  /// Pick evidence by type string
  static Future<PickedEvidence?> pickEvidence(String type) async {
    switch (type.toLowerCase()) {
      case 'photo':
      case 'image':
        return choosePhoto();
      case 'video':
        return chooseVideo();
      case 'audio':
        return chooseAudio();
      case 'document':
      case 'doc':
      default:
        return chooseDocument();
    }
  }

  /// Take photo using camera
  static Future<PickedEvidence?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo == null) return null;

      final file = File(photo.path);
      final size = await file.length();
      if (size > maxFileSize) {
        throw Exception('Selected photo exceeds the 50 MB size limit.');
      }

      return PickedEvidence(
        tempPath: photo.path,
        fileName: p.basename(photo.path),
        fileSize: size,
        fileType: 'photo',
        mimeType: 'image/jpeg',
      );
    } catch (e) {
      debugPrint('Error taking photo: $e');
      rethrow;
    }
  }

  /// Choose photo from gallery
  static Future<PickedEvidence?> choosePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo == null) return null;

      final file = File(photo.path);
      final size = await file.length();
      if (size > maxFileSize) {
        throw Exception('Selected photo exceeds the 50 MB size limit.');
      }

      return PickedEvidence(
        tempPath: photo.path,
        fileName: p.basename(photo.path),
        fileSize: size,
        fileType: 'photo',
        mimeType: 'image/jpeg',
      );
    } catch (e) {
      debugPrint('Error choosing photo: $e');
      rethrow;
    }
  }

  /// Record video using camera
  static Future<PickedEvidence?> recordVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 3),
      );
      if (video == null) return null;

      final file = File(video.path);
      final size = await file.length();
      if (size > maxFileSize) {
        throw Exception('Recorded video exceeds the 50 MB size limit.');
      }

      return PickedEvidence(
        tempPath: video.path,
        fileName: p.basename(video.path),
        fileSize: size,
        fileType: 'video',
        mimeType: 'video/mp4',
      );
    } catch (e) {
      debugPrint('Error recording video: $e');
      rethrow;
    }
  }

  /// Choose video from gallery
  static Future<PickedEvidence?> chooseVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (video == null) return null;

      final file = File(video.path);
      final size = await file.length();
      if (size > maxFileSize) {
        throw Exception('Selected video exceeds the 50 MB size limit.');
      }

      return PickedEvidence(
        tempPath: video.path,
        fileName: p.basename(video.path),
        fileSize: size,
        fileType: 'video',
        mimeType: 'video/mp4',
      );
    } catch (e) {
      debugPrint('Error choosing video: $e');
      rethrow;
    }
  }

  /// Choose audio file from device
  static Future<PickedEvidence?> chooseAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final path = result.files.first.path;
      if (path == null) return null;

      final file = File(path);
      final size = await file.length();
      if (size > maxFileSize) {
        throw Exception('Selected audio exceeds the 50 MB size limit.');
      }

      return PickedEvidence(
        tempPath: path,
        fileName: result.files.first.name,
        fileSize: size,
        fileType: 'audio',
        mimeType: 'audio/mpeg',
      );
    } catch (e) {
      debugPrint('Error picking audio: $e');
      rethrow;
    }
  }

  /// Choose document / PDF file
  static Future<PickedEvidence?> chooseDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'rtf'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final path = result.files.first.path;
      if (path == null) return null;

      final file = File(path);
      final size = await file.length();
      if (size > maxFileSize) {
        throw Exception('Selected document exceeds the 50 MB size limit.');
      }

      final ext = p.extension(path).toLowerCase();
      String mime = 'application/pdf';
      if (ext == '.doc' || ext == '.docx') mime = 'application/msword';
      if (ext == '.txt') mime = 'text/plain';

      return PickedEvidence(
        tempPath: path,
        fileName: result.files.first.name,
        fileSize: size,
        fileType: 'document',
        mimeType: mime,
      );
    } catch (e) {
      debugPrint('Error picking document: $e');
      rethrow;
    }
  }

  /// Copy picked file to private persistent app storage
  static Future<String> persistAttachment(PickedEvidence evidence) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final evidenceDir = Directory(p.join(docsDir.path, 'evidence'));
    if (!await evidenceDir.exists()) {
      await evidenceDir.create(recursive: true);
    }

    // Clean and sanitize filename with timestamp prefix
    final safeName = evidence.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final targetPath = p.join(evidenceDir.path, uniqueName);

    final sourceFile = File(evidence.tempPath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file at temporary path does not exist.');
    }

    await sourceFile.copy(targetPath);
    return targetPath;
  }

  /// Open/View file using native device application (PDF, Media Player, etc.)
  static Future<OpenResult> openFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return OpenResult(type: ResultType.fileNotFound, message: 'File not found on device storage');
    }
    return await OpenFilex.open(filePath);
  }

  /// Format bytes to human readable format
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final value = bytes / (1 << (i * 10));
    return '${value.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
