enum WatermarkPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

enum ImageFilterType {
  none,
  grayscale,
  sepia,
  invert,
}

class ConversionOptions {
  // Video Options
  String resolution; // 'original', '1920x1080', '1280x720', etc.
  String videoCodec; // 'auto', 'h264', 'hevc', 'vp9', 'copy'
  String videoBitrate; // 'auto', '8M', '4M', '2M', '1M'
  String fps; // 'auto', '60', '30', '24'
  String aspectRatio; // 'original', '16:9', '4:3', '9:16', '1:1'
  String speed; // '1.0', '0.5', '1.5', '2.0'
  String preset; // 'fast', 'medium', 'slow'

  // Audio Options
  String audioCodec; // 'auto', 'aac', 'mp3', 'opus', 'flac', 'copy', 'mute'
  String audioBitrate; // '320k', '256k', '192k', '128k', '64k'
  String sampleRate; // 'original', '48000', '44100'
  String channels; // 'original', 'stereo', 'mono'
  double volume; // 1.0 = 100%, 1.5 = 150%, 2.0 = 200%

  // Trimming
  bool enableTrim;
  String startTime; // '00:00:00'
  String endTime; // '00:00:00'

  // Spatial Video Cropping
  bool enableCrop;
  int? cropX;
  int? cropY;
  int? cropWidth;
  int? cropHeight;
  String cropAspectRatio; // 'free', '16:9', '9:16', '1:1', '4:3', 'custom'

  // Watermark
  bool enableWatermark;
  String watermarkText;
  WatermarkPosition watermarkPosition;

  // Image Specific Options
  int? imageWidth;
  int? imageHeight;
  bool keepAspectRatio;
  int imageQuality; // 1-100
  ImageFilterType imageFilter;
  int rotationDegrees; // 0, 90, 180, 270

  // Document Options
  String pageSize; // 'a4', 'letter'

  ConversionOptions({
    this.resolution = 'original',
    this.videoCodec = 'auto',
    this.videoBitrate = 'auto',
    this.fps = 'auto',
    this.aspectRatio = 'original',
    this.speed = '1.0',
    this.preset = 'medium',
    this.audioCodec = 'auto',
    this.audioBitrate = '192k',
    this.sampleRate = 'original',
    this.channels = 'original',
    this.volume = 1.0,
    this.enableTrim = false,
    this.startTime = '00:00:00',
    this.endTime = '',
    this.enableCrop = false,
    this.cropX,
    this.cropY,
    this.cropWidth,
    this.cropHeight,
    this.cropAspectRatio = 'free',
    this.enableWatermark = false,
    this.watermarkText = '',
    this.watermarkPosition = WatermarkPosition.bottomRight,
    this.imageWidth,
    this.imageHeight,
    this.keepAspectRatio = true,
    this.imageQuality = 90,
    this.imageFilter = ImageFilterType.none,
    this.rotationDegrees = 0,
    this.pageSize = 'a4',
  });

  ConversionOptions copyWith({
    String? resolution,
    String? videoCodec,
    String? videoBitrate,
    String? fps,
    String? aspectRatio,
    String? speed,
    String? preset,
    String? audioCodec,
    String? audioBitrate,
    String? sampleRate,
    String? channels,
    double? volume,
    bool? enableTrim,
    String? startTime,
    String? endTime,
    bool? enableCrop,
    int? cropX,
    int? cropY,
    int? cropWidth,
    int? cropHeight,
    String? cropAspectRatio,
    bool? enableWatermark,
    String? watermarkText,
    WatermarkPosition? watermarkPosition,
    int? imageWidth,
    int? imageHeight,
    bool? keepAspectRatio,
    int? imageQuality,
    ImageFilterType? imageFilter,
    int? rotationDegrees,
    String? pageSize,
  }) {
    return ConversionOptions(
      resolution: resolution ?? this.resolution,
      videoCodec: videoCodec ?? this.videoCodec,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      fps: fps ?? this.fps,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      speed: speed ?? this.speed,
      preset: preset ?? this.preset,
      audioCodec: audioCodec ?? this.audioCodec,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      volume: volume ?? this.volume,
      enableTrim: enableTrim ?? this.enableTrim,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      enableCrop: enableCrop ?? this.enableCrop,
      cropX: cropX ?? this.cropX,
      cropY: cropY ?? this.cropY,
      cropWidth: cropWidth ?? this.cropWidth,
      cropHeight: cropHeight ?? this.cropHeight,
      cropAspectRatio: cropAspectRatio ?? this.cropAspectRatio,
      enableWatermark: enableWatermark ?? this.enableWatermark,
      watermarkText: watermarkText ?? this.watermarkText,
      watermarkPosition: watermarkPosition ?? this.watermarkPosition,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      keepAspectRatio: keepAspectRatio ?? this.keepAspectRatio,
      imageQuality: imageQuality ?? this.imageQuality,
      imageFilter: imageFilter ?? this.imageFilter,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}
