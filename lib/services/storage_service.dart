import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  String? _customOutputDir;

  Future<String> getOutputDirectory() async {
    if (_customOutputDir != null && Directory(_customOutputDir!).existsSync()) {
      return _customOutputDir!;
    }

    try {
      if (kIsWeb) {
        return 'PhoenixFactory_Output';
      }

      Directory? baseDir;
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        baseDir = await getDownloadsDirectory();
        baseDir ??= await getApplicationDocumentsDirectory();
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      final outDir = Directory(p.join(baseDir.path, 'PhoenixFactory_Output'));
      if (!outDir.existsSync()) {
        await outDir.create(recursive: true);
      }
      return outDir.path;
    } catch (e) {
      debugPrint('Error getting output directory: $e');
      final fallback = Directory(p.join(Directory.current.path, 'PhoenixFactory_Output'));
      if (!fallback.existsSync()) {
        await fallback.create(recursive: true);
      }
      return fallback.path;
    }
  }

  void setCustomOutputDir(String path) {
    _customOutputDir = path;
  }

  Future<String?> pickCustomDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Output Destination Folder',
      );
      if (selectedDirectory != null) {
        _customOutputDir = selectedDirectory;
        return selectedDirectory;
      }
    } catch (e) {
      debugPrint('Error picking directory: $e');
    }
    return null;
  }

  Future<void> openDirectory(String dirPath) async {
    try {
      if (kIsWeb) return;

      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }

      if (Platform.isLinux) {
        await Process.run('xdg-open', [dirPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dirPath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [dirPath]);
      } else {
        final uri = Uri.file(dirPath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      debugPrint('Could not open directory $dirPath: $e');
    }
  }

  Future<void> openFile(String filePath) async {
    try {
      if (kIsWeb) return;

      final file = File(filePath);
      if (!file.existsSync()) return;

      if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      } else {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      debugPrint('Could not open file $filePath: $e');
    }
  }
}
