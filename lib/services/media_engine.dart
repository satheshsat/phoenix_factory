import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/conversion_options.dart';
import '../models/conversion_task.dart';
import '../models/media_category.dart';

class MediaStreamInfo {
  final String codec;
  final String type; // video, audio, image
  final String? resolution;
  final String? bitrate;
  final String? frameRate;
  final String? sampleRate;
  final String? channels;

  MediaStreamInfo({
    required this.codec,
    required this.type,
    this.resolution,
    this.bitrate,
    this.frameRate,
    this.sampleRate,
    this.channels,
  });
}

class MediaInfoResult {
  final String formatName;
  final Duration? duration;
  final int sizeBytes;
  final int? overallBitrate;
  final List<MediaStreamInfo> streams;

  MediaInfoResult({
    required this.formatName,
    this.duration,
    required this.sizeBytes,
    this.overallBitrate,
    this.streams = const [],
  });
}

class MediaEngine {
  static final MediaEngine _instance = MediaEngine._internal();
  factory MediaEngine() => _instance;
  MediaEngine._internal();

  String? _ffmpegPath;
  String? _ffprobePath;
  String? _ffmpegVersion;

  final Map<String, Process> _runningProcesses = {};

  bool get isFFmpegAvailable => _ffmpegPath != null;
  String? get ffmpegVersion => _ffmpegVersion;
  String? get ffmpegPath => _ffmpegPath;

  Future<void> initialize() async {
    if (kIsWeb) return;

    final home = Platform.environment['HOME'] ?? '';
    final searchPaths = [
      p.join(home, '.local', 'bin', 'ffmpeg'),
      '/usr/local/bin/ffmpeg',
      '/usr/bin/ffmpeg',
      p.join(Directory.current.path, 'bin', 'ffmpeg'),
      p.join(Directory.current.path, 'ffmpeg'),
      'ffmpeg',
    ];

    for (final path in searchPaths) {
      try {
        final result = await Process.run(path, ['-version']);
        if (result.exitCode == 0) {
          _ffmpegPath = path;
          final firstLine = (result.stdout as String).split('\n').first;
          _ffmpegVersion = firstLine;
          debugPrint('Found FFmpeg at: $path ($firstLine)');
          break;
        }
      } catch (_) {}
    }

    // Also look for ffprobe
    final probePaths = [
      p.join(home, '.local', 'bin', 'ffprobe'),
      '/usr/local/bin/ffprobe',
      '/usr/bin/ffprobe',
      'ffprobe',
    ];

    for (final path in probePaths) {
      try {
        final result = await Process.run(path, ['-version']);
        if (result.exitCode == 0) {
          _ffprobePath = path;
          debugPrint('Found FFprobe at: $path');
          break;
        }
      } catch (_) {}
    }
  }

  Future<MediaInfoResult?> inspectMedia(String filePath) async {
    if (kIsWeb) return null;
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final sizeBytes = file.lengthSync();

    if (_ffprobePath != null) {
      try {
        final result = await Process.run(_ffprobePath!, [
          '-v', 'quiet',
          '-print_format', 'json',
          '-show_format',
          '-show_streams',
          filePath,
        ]);

        if (result.exitCode == 0) {
          final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
          final formatData = data['format'] as Map<String, dynamic>? ?? {};
          final streamsData = data['streams'] as List<dynamic>? ?? [];

          final durationSec = double.tryParse(formatData['duration']?.toString() ?? '0') ?? 0.0;
          final overallBitrate = int.tryParse(formatData['bit_rate']?.toString() ?? '0');

          final streams = <MediaStreamInfo>[];
          for (final s in streamsData) {
            final m = s as Map<String, dynamic>;
            final codecType = m['codec_type']?.toString() ?? '';
            final codecName = m['codec_name']?.toString() ?? 'unknown';

            String? res;
            if (m['width'] != null && m['height'] != null) {
              res = '${m['width']}x${m['height']}';
            }

            streams.add(MediaStreamInfo(
              codec: codecName,
              type: codecType,
              resolution: res,
              bitrate: m['bit_rate'] != null ? '${int.parse(m['bit_rate'].toString()) ~/ 1000} kbps' : null,
              frameRate: m['r_frame_rate']?.toString(),
              sampleRate: m['sample_rate'] != null ? '${m['sample_rate']} Hz' : null,
              channels: m['channels'] != null ? '${m['channels']} ch' : null,
            ));
          }

          return MediaInfoResult(
            formatName: formatData['format_long_name']?.toString() ?? formatData['format_name']?.toString() ?? p.extension(filePath),
            duration: Duration(milliseconds: (durationSec * 1000).toInt()),
            sizeBytes: sizeBytes,
            overallBitrate: overallBitrate,
            streams: streams,
          );
        }
      } catch (e) {
        debugPrint('Error inspecting with ffprobe: $e');
      }
    }

    // Basic file info fallback
    return MediaInfoResult(
      formatName: p.extension(filePath).replaceAll('.', '').toUpperCase(),
      sizeBytes: sizeBytes,
    );
  }

  /// Extracts a video frame at a given timestamp into memory (JPEG bytes)
  Future<Uint8List?> extractVideoFrame(String videoPath, Duration timestamp) async {
    if (kIsWeb || !isFFmpegAvailable) return null;
    try {
      final hours = timestamp.inHours.toString().padLeft(2, '0');
      final minutes = (timestamp.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (timestamp.inSeconds % 60).toString().padLeft(2, '0');
      final millis = (timestamp.inMilliseconds % 1000).toString().padLeft(3, '0');
      final timeStr = '$hours:$minutes:$seconds.$millis';

      final result = await Process.run(
        _ffmpegPath!,
        [
          '-ss', timeStr,
          '-i', videoPath,
          '-vframes', '1',
          '-f', 'image2pipe',
          '-vcodec', 'mjpeg',
          '-',
        ],
        stdoutEncoding: null,
      );

      if (result.exitCode == 0 && result.stdout is List<int>) {
        return Uint8List.fromList(result.stdout as List<int>);
      }
    } catch (e) {
      debugPrint('Error extracting video frame: $e');
    }
    return null;
  }

  Future<void> convertTask(
    ConversionTask task,
    String outputDir,
    void Function(ConversionTask) onUpdate,
  ) async {
    task.status = TaskStatus.converting;
    task.progress = 0.0;
    onUpdate(task);

    final inputBaseName = p.basenameWithoutExtension(task.sourcePath);
    final targetExt = task.targetFormat.extension;
    final outFileName = '${inputBaseName}_phoenix.$targetExt';
    final outPath = p.join(outputDir, outFileName);
    task.outputFilePath = outPath;

    try {
      if (task.targetFormat.category == MediaCategoryType.picture) {
        await _convertImagePureDart(task, outPath, onUpdate);
      } else if (task.targetFormat.category == MediaCategoryType.document) {
        await _convertDocumentPureDart(task, outPath, onUpdate);
      } else {
        // Video, Audio, Presets
        if (isFFmpegAvailable) {
          await _convertMediaWithFFmpeg(task, outPath, onUpdate);
        } else {
          // If FFmpeg is missing on this system, try pure Dart image fallback or fail gracefully
          throw Exception('FFmpeg is required for video/audio transcoding. Please install FFmpeg on your system.');
        }
      }

      final outFile = File(outPath);
      if (outFile.existsSync()) {
        task.outputSize = outFile.lengthSync();
        task.status = TaskStatus.completed;
        task.progress = 1.0;
      } else {
        throw Exception('Output file was not generated.');
      }
    } catch (e) {
      task.status = TaskStatus.failed;
      task.errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _runningProcesses.remove(task.id);
      onUpdate(task);
    }
  }

  Future<void> _convertImagePureDart(
    ConversionTask task,
    String outPath,
    void Function(ConversionTask) onUpdate,
  ) async {
    task.progress = 0.2;
    onUpdate(task);

    final bytes = await File(task.sourcePath).readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image file format.');
    }

    task.progress = 0.4;
    onUpdate(task);

    final opt = task.options;

    // 1. Rotation
    if (opt.rotationDegrees != 0) {
      image = img.copyRotate(image, angle: opt.rotationDegrees);
    }

    // 2. Resizing
    if (opt.imageWidth != null || opt.imageHeight != null) {
      image = img.copyResize(
        image,
        width: opt.imageWidth,
        height: opt.imageHeight,
        maintainAspect: opt.keepAspectRatio,
      );
    }

    // 3. Filters
    switch (opt.imageFilter) {
      case ImageFilterType.grayscale:
        image = img.grayscale(image);
        break;
      case ImageFilterType.sepia:
        image = img.sepia(image);
        break;
      case ImageFilterType.invert:
        image = img.invert(image);
        break;
      case ImageFilterType.none:
        break;
    }

    task.progress = 0.7;
    onUpdate(task);

    // 4. Encode to target format
    List<int> encodedBytes;
    final ext = task.targetFormat.extension.toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        encodedBytes = img.encodeJpg(image, quality: opt.imageQuality);
        break;
      case 'png':
        encodedBytes = img.encodePng(image);
        break;
      case 'bmp':
        encodedBytes = img.encodeBmp(image);
        break;
      case 'ico':
        encodedBytes = img.encodeIco(image);
        break;
      case 'gif':
        encodedBytes = img.encodeGif(image);
        break;
      default:
        encodedBytes = img.encodePng(image);
    }

    task.progress = 0.9;
    onUpdate(task);

    await File(outPath).writeAsBytes(encodedBytes);
    task.progress = 1.0;
  }

  Future<void> _convertDocumentPureDart(
    ConversionTask task,
    String outPath,
    void Function(ConversionTask) onUpdate,
  ) async {
    task.progress = 0.2;
    onUpdate(task);

    final pdf = pw.Document();

    if (task.targetFormat.id == 'img_to_pdf') {
      final imageBytes = await File(task.sourcePath).readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: task.options.pageSize == 'letter' ? PdfPageFormat.letter : PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    } else {
      // text_to_pdf
      final textContent = await File(task.sourcePath).readAsString();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: task.options.pageSize == 'letter' ? PdfPageFormat.letter : PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  p.basename(task.sourcePath),
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Paragraph(
                text: textContent,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
            ];
          },
        ),
      );
    }

    task.progress = 0.8;
    onUpdate(task);

    final bytes = await pdf.save();
    await File(outPath).writeAsBytes(bytes);
    task.progress = 1.0;
  }

  Future<void> _convertMediaWithFFmpeg(
    ConversionTask task,
    String outPath,
    void Function(ConversionTask) onUpdate,
  ) async {
    final opt = task.options;
    final args = <String>['-y'];

    // Trimming start
    if (opt.enableTrim && opt.startTime.isNotEmpty && opt.startTime != '00:00:00') {
      args.addAll(['-ss', opt.startTime]);
    }

    // Input file
    args.addAll(['-i', task.sourcePath]);

    // Trimming end / duration
    if (opt.enableTrim && opt.endTime.isNotEmpty) {
      args.addAll(['-to', opt.endTime]);
    }

    // Presets & Special formats
    final fmtId = task.targetFormat.id;

    if (fmtId == 'extract_audio') {
      // Audio extraction mode
      args.addAll(['-vn', '-acodec', 'libmp3lame', '-b:a', opt.audioBitrate]);
    } else if (fmtId == 'video_to_gif') {
      // Video to animated GIF
      args.addAll(['-vf', 'fps=15,scale=480:-1:flags=lanczos', '-c:v', 'gif']);
    } else if (fmtId == 'preset_tiktok') {
      // TikTok 9:16 vertical crop
      args.addAll([
        '-vf', 'crop=ih*9/16:ih,scale=1080:1920',
        '-c:v', 'libx264',
        '-preset', 'fast',
        '-c:a', 'aac',
      ]);
    } else if (fmtId == 'preset_discord') {
      // Discord limit target
      args.addAll([
        '-c:v', 'libx264',
        '-crf', '28',
        '-preset', 'fast',
        '-c:a', 'aac',
        '-b:a', '96k',
      ]);
    } else if (fmtId == 'preset_iphone' || fmtId == 'preset_android') {
      // Mobile preset
      args.addAll([
        '-c:v', 'libx264',
        '-profile:v', 'high',
        '-level', '4.1',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'aac',
        '-b:a', '160k',
      ]);
    } else if (task.targetFormat.category == MediaCategoryType.video) {
      // Standard Video
      // Video Codec
      if (opt.videoCodec == 'h264') {
        args.addAll(['-c:v', 'libx264']);
      } else if (opt.videoCodec == 'hevc') {
        args.addAll(['-c:v', 'libx265']);
      } else if (opt.videoCodec == 'vp9') {
        args.addAll(['-c:v', 'libvpx-vp9']);
      } else if (opt.videoCodec == 'copy') {
        args.addAll(['-c:v', 'copy']);
      }

      // Resolution
      if (opt.resolution != 'original') {
        args.addAll(['-s', opt.resolution]);
      }

      // Bitrate
      if (opt.videoBitrate != 'auto') {
        args.addAll(['-b:v', opt.videoBitrate]);
      }

      // FPS
      if (opt.fps != 'auto') {
        args.addAll(['-r', opt.fps]);
      }

      // Aspect Ratio
      if (opt.aspectRatio != 'original') {
        args.addAll(['-aspect', opt.aspectRatio]);
      }

      // Video filters (Crop, Speed)
      final vFilters = <String>[];
      if (opt.enableCrop && opt.cropWidth != null && opt.cropHeight != null) {
        final x = opt.cropX ?? 0;
        final y = opt.cropY ?? 0;
        vFilters.add('crop=${opt.cropWidth}:${opt.cropHeight}:$x:$y');
      }
      if (opt.speed != '1.0') {
        final speedVal = double.tryParse(opt.speed) ?? 1.0;
        if (speedVal > 0) {
          vFilters.add('setpts=${(1.0 / speedVal).toStringAsFixed(4)}*PTS');
        }
      }
      if (vFilters.isNotEmpty) {
        args.addAll(['-vf', vFilters.join(',')]);
      }

      // Audio stream inside video
      if (opt.audioCodec == 'mute') {
        args.add('-an');
      } else {
        if (opt.audioCodec == 'aac') {
          args.addAll(['-c:a', 'aac']);
        } else if (opt.audioCodec == 'mp3') {
          args.addAll(['-c:a', 'libmp3lame']);
        } else if (opt.audioCodec == 'copy') {
          args.addAll(['-c:a', 'copy']);
        }
        if (opt.audioBitrate.isNotEmpty) {
          args.addAll(['-b:a', opt.audioBitrate]);
        }
      }

      // Audio filters (Volume, Speed)
      final aFilters = <String>[];
      if (opt.volume != 1.0) {
        aFilters.add('volume=${opt.volume}');
      }
      if (opt.speed != '1.0') {
        final speedVal = double.tryParse(opt.speed) ?? 1.0;
        if (speedVal >= 0.5 && speedVal <= 2.0) {
          aFilters.add('atempo=$speedVal');
        }
      }
      if (aFilters.isNotEmpty && opt.audioCodec != 'mute') {
        args.addAll(['-filter:a', aFilters.join(',')]);
      }
    } else if (task.targetFormat.category == MediaCategoryType.audio) {
      // Standard Audio
      args.add('-vn'); // no video

      if (task.targetFormat.id == 'mp3') {
        args.addAll(['-c:a', 'libmp3lame']);
      } else if (task.targetFormat.id == 'aac') {
        args.addAll(['-c:a', 'aac']);
      } else if (task.targetFormat.id == 'ogg') {
        args.addAll(['-c:a', 'libvorbis']);
      } else if (task.targetFormat.id == 'flac') {
        args.addAll(['-c:a', 'flac']);
      } else if (task.targetFormat.id == 'opus') {
        args.addAll(['-c:a', 'libopus']);
      } else if (task.targetFormat.id == 'wav') {
        args.addAll(['-c:a', 'pcm_s16le']);
      }

      if (opt.audioBitrate.isNotEmpty) {
        args.addAll(['-b:a', opt.audioBitrate]);
      }
      if (opt.sampleRate != 'original') {
        args.addAll(['-ar', opt.sampleRate]);
      }
      if (opt.channels == 'mono') {
        args.addAll(['-ac', '1']);
      } else if (opt.channels == 'stereo') {
        args.addAll(['-ac', '2']);
      }
      if (opt.volume != 1.0) {
        args.addAll(['-filter:a', 'volume=${opt.volume}']);
      }
    }

    // Realtime progress report
    args.addAll(['-progress', 'pipe:1', outPath]);

    debugPrint('Running FFmpeg: $_ffmpegPath ${args.join(" ")}');

    final process = await Process.start(_ffmpegPath!, args);
    _runningProcesses[task.id] = process;

    // Read duration if not yet known
    int totalDurationMs = 0;
    final info = await inspectMedia(task.sourcePath);
    if (info?.duration != null) {
      totalDurationMs = info!.duration!.inMilliseconds;
    }

    final completer = Completer<void>();

    // Parse stdout progress
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      final parts = line.split('=');
      if (parts.length == 2) {
        final key = parts[0].trim();
        final value = parts[1].trim();

        if (key == 'out_time_us') {
          final us = int.tryParse(value) ?? 0;
          final currentMs = us ~/ 1000;
          if (totalDurationMs > 0) {
            final p = (currentMs / totalDurationMs).clamp(0.0, 0.99);
            task.progress = p;
            onUpdate(task);
          }
        } else if (key == 'fps') {
          task.currentFps = value;
        } else if (key == 'speed') {
          task.speed = value;
          onUpdate(task);
        } else if (key == 'progress' && value == 'end') {
          task.progress = 1.0;
          onUpdate(task);
        }
      }
    });

    final errorBuffer = StringBuffer();
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      errorBuffer.writeln(line);
      // Fallback regex for time if out_time_us isn't triggered
      final match = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(line);
      if (match != null && totalDurationMs > 0) {
        final h = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final s = double.parse(match.group(3)!);
        final curMs = (h * 3600000 + m * 60000 + s * 1000).toInt();
        task.progress = (curMs / totalDurationMs).clamp(0.0, 0.99);
        onUpdate(task);
      }
    });

    process.exitCode.then((code) {
      if (code == 0) {
        completer.complete();
      } else {
        completer.completeError(
          Exception('FFmpeg exited with error code $code:\n${errorBuffer.toString().split('\n').take(4).join('\n')}'),
        );
      }
    });

    await completer.future;
  }

  void cancelTask(String taskId) {
    final process = _runningProcesses[taskId];
    if (process != null) {
      process.kill();
      _runningProcesses.remove(taskId);
    }
  }
}
