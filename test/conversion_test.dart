import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:phoenix_factory/models/conversion_options.dart';
import 'package:phoenix_factory/models/conversion_task.dart';
import 'package:phoenix_factory/models/media_category.dart';
import 'package:phoenix_factory/services/media_engine.dart';

void main() {
  late MediaEngine engine;
  late String outputDir;
  late String testMediaDir;

  setUpAll(() async {
    engine = MediaEngine();
    await engine.initialize();
    testMediaDir = '/home/sathesh/Documents/phoenix_factory/test_media';
    outputDir = p.join(testMediaDir, 'output');
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  });

  test('MediaEngine detects FFmpeg and ffprobe', () {
    expect(engine.isFFmpegAvailable, isTrue);
    expect(engine.ffmpegPath, isNotNull);
  });

  test('MediaEngine inspects sample_clip.mp4 correctly', () async {
    final clipPath = p.join(testMediaDir, 'sample_clip.mp4');
    expect(File(clipPath).existsSync(), isTrue);

    final info = await engine.inspectMedia(clipPath);
    expect(info, isNotNull);
    expect(info!.sizeBytes, greaterThan(0));
    expect(info.streams, isNotEmpty);
  });

  test('Converts video to MP3 audio extraction', () async {
    final clipPath = p.join(testMediaDir, 'sample_clip.mp4');
    final mp3Format = MediaCategories.findById('extract_audio')!;

    final task = ConversionTask(
      id: 'test_task_audio',
      sourcePath: clipPath,
      fileName: 'sample_clip.mp4',
      sourceSize: File(clipPath).lengthSync(),
      targetFormat: mp3Format,
      options: ConversionOptions(),
    );

    await engine.convertTask(task, outputDir, (t) {});

    expect(task.status, TaskStatus.completed);
    expect(task.outputFilePath, isNotNull);
    expect(File(task.outputFilePath!).existsSync(), isTrue);
    expect(File(task.outputFilePath!).lengthSync(), greaterThan(0));
  });

  test('Pure Dart image conversion and grayscale filter works', () async {
    // 1. Create a dummy test image
    final testImg = img.Image(width: 200, height: 200);
    for (int y = 0; y < 200; y++) {
      for (int x = 0; x < 200; x++) {
        testImg.setPixelRgb(x, y, 255, 100, 50);
      }
    }
    final inputImgPath = p.join(testMediaDir, 'test_input.png');
    await File(inputImgPath).writeAsBytes(img.encodePng(testImg));

    // 2. Convert to JPG with grayscale filter
    final jpgFormat = MediaCategories.findById('jpg')!;
    final task = ConversionTask(
      id: 'test_task_image',
      sourcePath: inputImgPath,
      fileName: 'test_input.png',
      sourceSize: File(inputImgPath).lengthSync(),
      targetFormat: jpgFormat,
      options: ConversionOptions(
        imageFilter: ImageFilterType.grayscale,
        imageQuality: 85,
      ),
    );

    await engine.convertTask(task, outputDir, (t) {});

    expect(task.status, TaskStatus.completed);
    expect(task.outputFilePath, isNotNull);
    expect(File(task.outputFilePath!).existsSync(), isTrue);
    expect(File(task.outputFilePath!).lengthSync(), greaterThan(0));
  });

  test('Pure Dart image to PDF conversion works', () async {
    final inputImgPath = p.join(testMediaDir, 'test_input.png');
    final pdfFormat = MediaCategories.findById('img_to_pdf')!;

    final task = ConversionTask(
      id: 'test_task_pdf',
      sourcePath: inputImgPath,
      fileName: 'test_input.png',
      sourceSize: File(inputImgPath).lengthSync(),
      targetFormat: pdfFormat,
      options: ConversionOptions(),
    );

    await engine.convertTask(task, outputDir, (t) {});

    expect(task.status, TaskStatus.completed);
    expect(task.outputFilePath, isNotNull);
    expect(File(task.outputFilePath!).existsSync(), isTrue);
    expect(File(task.outputFilePath!).lengthSync(), greaterThan(0));
  });

  test('Extracts video frame at timestamp via MediaEngine', () async {
    final clipPath = p.join(testMediaDir, 'sample_clip.mp4');
    final frameBytes = await engine.extractVideoFrame(clipPath, const Duration(seconds: 1));
    expect(frameBytes, isNotNull);
    expect(frameBytes!.length, greaterThan(100));
  });

  test('Converts video with Start/End trimming and spatial crop', () async {
    final clipPath = p.join(testMediaDir, 'sample_clip.mp4');
    final mp4Format = MediaCategories.findById('mp4')!;

    final task = ConversionTask(
      id: 'test_task_trim_crop',
      sourcePath: clipPath,
      fileName: 'sample_clip.mp4',
      sourceSize: File(clipPath).lengthSync(),
      targetFormat: mp4Format,
      options: ConversionOptions(
        enableTrim: true,
        startTime: '00:00:01.000',
        endTime: '00:00:02.500',
        enableCrop: true,
        cropWidth: 320,
        cropHeight: 180,
        cropX: 0,
        cropY: 0,
      ),
    );

    await engine.convertTask(task, outputDir, (t) {});

    expect(task.status, TaskStatus.completed);
    expect(task.outputFilePath, isNotNull);
    final outFile = File(task.outputFilePath!);
    expect(outFile.existsSync(), isTrue);
    expect(outFile.lengthSync(), greaterThan(0));

    // Verify output info
    final info = await engine.inspectMedia(task.outputFilePath!);
    expect(info, isNotNull);
    expect(info!.streams, isNotEmpty);
  });
}
