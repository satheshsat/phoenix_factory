import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/conversion_options.dart';
import '../models/conversion_task.dart';
import '../models/media_category.dart';
import '../services/media_engine.dart';
import '../services/storage_service.dart';

class ConversionProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final MediaEngine _mediaEngine = MediaEngine();
  final Uuid _uuid = const Uuid();

  final List<ConversionTask> _tasks = [];
  String _outputDirectory = '';
  bool _isProcessing = false;
  bool _isPaused = false;
  MediaCategoryType _currentCategory = MediaCategoryType.video;
  FormatDefinition? _selectedFormat;
  int _concurrencyLimit = 2;

  List<ConversionTask> get tasks => _tasks;
  String get outputDirectory => _outputDirectory;
  bool get isProcessing => _isProcessing;
  bool get isPaused => _isPaused;
  MediaCategoryType get currentCategory => _currentCategory;
  FormatDefinition? get selectedFormat => _selectedFormat;
  MediaEngine get mediaEngine => _mediaEngine;
  int get concurrencyLimit => _concurrencyLimit;

  // Statistics
  int get totalTasks => _tasks.length;
  int get completedCount => _tasks.where((t) => t.status == TaskStatus.completed).length;
  int get convertingCount => _tasks.where((t) => t.status == TaskStatus.converting).length;
  int get queuedCount => _tasks.where((t) => t.status == TaskStatus.queued).length;
  int get failedCount => _tasks.where((t) => t.status == TaskStatus.failed).length;

  double get overallProgress {
    if (_tasks.isEmpty) return 0.0;
    double sum = 0.0;
    for (final t in _tasks) {
      if (t.status == TaskStatus.completed) {
        sum += 1.0;
      } else if (t.status == TaskStatus.converting) {
        sum += t.progress;
      }
    }
    return (sum / _tasks.length).clamp(0.0, 1.0);
  }

  Future<void> initialize() async {
    await _mediaEngine.initialize();
    _outputDirectory = await _storageService.getOutputDirectory();
    _selectedFormat = MediaCategories.videoFormats.first;
    notifyListeners();
  }

  void setCurrentCategory(MediaCategoryType cat) {
    _currentCategory = cat;
    final formats = MediaCategories.getForCategory(cat);
    if (formats.isNotEmpty) {
      _selectedFormat = formats.first;
    }
    notifyListeners();
  }

  void setSelectedFormat(FormatDefinition format) {
    _selectedFormat = format;
    notifyListeners();
  }

  void setConcurrencyLimit(int limit) {
    _concurrencyLimit = limit;
    notifyListeners();
  }

  Future<void> pickOutputDirectory() async {
    final picked = await _storageService.pickCustomDirectory();
    if (picked != null) {
      _outputDirectory = picked;
      notifyListeners();
    }
  }

  Future<void> openOutputDirectory() async {
    await _storageService.openDirectory(_outputDirectory);
  }

  Future<void> openConvertedFile(ConversionTask task) async {
    if (task.outputFilePath != null) {
      await _storageService.openFile(task.outputFilePath!);
    }
  }

  void addFiles(
    List<String> filePaths, {
    FormatDefinition? targetFormat,
    ConversionOptions? options,
  }) {
    final fmt = targetFormat ?? _selectedFormat ?? MediaCategories.videoFormats.first;

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!file.existsSync()) continue;

      // Avoid exact duplicates in queue
      final exists = _tasks.any((t) => t.sourcePath == filePath && t.status != TaskStatus.completed);
      if (exists) continue;

      final task = ConversionTask(
        id: _uuid.v4(),
        sourcePath: filePath,
        fileName: p.basename(filePath),
        sourceSize: file.lengthSync(),
        targetFormat: fmt,
        options: options?.copyWith() ?? ConversionOptions(),
      );

      _tasks.add(task);
    }

    notifyListeners();
  }

  void removeTask(String id) {
    final task = _tasks.firstWhere((t) => t.id == id, orElse: () => _tasks.first);
    if (task.status == TaskStatus.converting) {
      _mediaEngine.cancelTask(task.id);
    }
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == TaskStatus.completed);
    notifyListeners();
  }

  void clearAll() {
    for (final t in _tasks) {
      if (t.status == TaskStatus.converting) {
        _mediaEngine.cancelTask(t.id);
      }
    }
    _tasks.clear();
    _isProcessing = false;
    _isPaused = false;
    notifyListeners();
  }

  void updateTaskOptions(String id, ConversionOptions newOptions) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index].options = newOptions;
      notifyListeners();
    }
  }

  void updateTaskFormat(String id, FormatDefinition newFormat) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index].targetFormat = newFormat;
      notifyListeners();
    }
  }

  void retryTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index].status = TaskStatus.queued;
      _tasks[index].progress = 0.0;
      _tasks[index].errorMessage = null;
      notifyListeners();
      if (!_isProcessing) {
        startConversion();
      }
    }
  }

  Future<void> startConversion() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _isPaused = false;
    notifyListeners();

    while (_isProcessing && !_isPaused) {
      final queued = _tasks.where((t) => t.status == TaskStatus.queued).toList();
      if (queued.isEmpty) {
        break;
      }

      final task = queued.first;
      await _mediaEngine.convertTask(
        task,
        _outputDirectory,
        (updatedTask) {
          notifyListeners();
        },
      );
    }

    _isProcessing = false;
    notifyListeners();
  }

  void pauseConversion() {
    _isPaused = true;
    _isProcessing = false;
    notifyListeners();
  }

  void resumeConversion() {
    _isPaused = false;
    startConversion();
  }

  void stopConversion() {
    _isProcessing = false;
    _isPaused = false;
    for (final t in _tasks) {
      if (t.status == TaskStatus.converting) {
        _mediaEngine.cancelTask(t.id);
        t.status = TaskStatus.cancelled;
      }
    }
    notifyListeners();
  }
}
