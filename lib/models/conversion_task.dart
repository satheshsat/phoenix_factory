import 'conversion_options.dart';
import 'media_category.dart';

enum TaskStatus {
  queued,
  converting,
  completed,
  failed,
  cancelled,
}

class ConversionTask {
  final String id;
  final String sourcePath;
  final String fileName;
  final int sourceSize;
  FormatDefinition targetFormat;
  ConversionOptions options;
  TaskStatus status;
  double progress; // 0.0 to 1.0
  String? speed;
  String? eta;
  String? currentFps;
  Duration? duration;
  String? outputFilePath;
  int? outputSize;
  String? errorMessage;
  DateTime createdAt;

  ConversionTask({
    required this.id,
    required this.sourcePath,
    required this.fileName,
    required this.sourceSize,
    required this.targetFormat,
    required this.options,
    this.status = TaskStatus.queued,
    this.progress = 0.0,
    this.speed,
    this.eta,
    this.currentFps,
    this.duration,
    this.outputFilePath,
    this.outputSize,
    this.errorMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedSourceSize => formatBytes(sourceSize);
  String get formattedOutputSize => outputSize != null ? formatBytes(outputSize!) : '--';

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
