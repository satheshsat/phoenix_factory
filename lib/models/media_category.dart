import 'package:flutter/material.dart';

enum MediaCategoryType {
  video,
  audio,
  picture,
  document,
  presets,
  tools,
}

class FormatDefinition {
  final String id;
  final String name;
  final String extension;
  final String description;
  final IconData icon;
  final Color color;
  final MediaCategoryType category;
  final bool isSpecialTool;

  const FormatDefinition({
    required this.id,
    required this.name,
    required this.extension,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    this.isSpecialTool = false,
  });
}

class MediaCategories {
  static const List<FormatDefinition> videoFormats = [
    FormatDefinition(
      id: 'mp4',
      name: 'MP4',
      extension: 'mp4',
      description: 'Universal video format (H.264/AAC)',
      icon: Icons.movie_outlined,
      color: Color(0xFF6366F1), // Indigo
      category: MediaCategoryType.video,
    ),
    FormatDefinition(
      id: 'mkv',
      name: 'MKV',
      extension: 'mkv',
      description: 'Matroska multi-track container',
      icon: Icons.video_collection_outlined,
      color: Color(0xFF8B5CF6), // Purple
      category: MediaCategoryType.video,
    ),
    FormatDefinition(
      id: 'webm',
      name: 'WebM',
      extension: 'webm',
      description: 'HTML5 & Web streaming (VP9/Opus)',
      icon: Icons.public_outlined,
      color: Color(0xFF06B6D4), // Cyan
      category: MediaCategoryType.video,
    ),
    FormatDefinition(
      id: 'avi',
      name: 'AVI',
      extension: 'avi',
      description: 'Audio Video Interleave',
      icon: Icons.video_camera_back_outlined,
      color: Color(0xFF3B82F6), // Blue
      category: MediaCategoryType.video,
    ),
    FormatDefinition(
      id: 'mov',
      name: 'MOV',
      extension: 'mov',
      description: 'Apple QuickTime Movie',
      icon: Icons.apple,
      color: Color(0xFFA855F7), // Fuchsia
      category: MediaCategoryType.video,
    ),
    FormatDefinition(
      id: 'video_to_gif',
      name: 'GIF Animation',
      extension: 'gif',
      description: 'Convert clip to animated GIF',
      icon: Icons.animation_outlined,
      color: Color(0xFFEC4899), // Pink
      category: MediaCategoryType.video,
    ),
    FormatDefinition(
      id: 'extract_audio',
      name: 'Extract Audio',
      extension: 'mp3',
      description: 'Rip high-quality audio from video',
      icon: Icons.music_video_outlined,
      color: Color(0xFFF59E0B), // Amber
      category: MediaCategoryType.video,
      isSpecialTool: true,
    ),
    FormatDefinition(
      id: 'flv',
      name: 'FLV',
      extension: 'flv',
      description: 'Flash Video stream format',
      icon: Icons.play_circle_outline,
      color: Color(0xFFEF4444), // Red
      category: MediaCategoryType.video,
    ),
  ];

  static const List<FormatDefinition> audioFormats = [
    FormatDefinition(
      id: 'mp3',
      name: 'MP3',
      extension: 'mp3',
      description: 'MPEG Layer-3 universal audio',
      icon: Icons.audiotrack_outlined,
      color: Color(0xFF10B981), // Emerald
      category: MediaCategoryType.audio,
    ),
    FormatDefinition(
      id: 'wav',
      name: 'WAV',
      extension: 'wav',
      description: 'Uncompressed Studio PCM Master',
      icon: Icons.graphic_eq_outlined,
      color: Color(0xFF14B8A6), // Teal
      category: MediaCategoryType.audio,
    ),
    FormatDefinition(
      id: 'aac',
      name: 'AAC',
      extension: 'aac',
      description: 'Advanced Audio Coding for Apple/Android',
      icon: Icons.surround_sound_outlined,
      color: Color(0xFF3B82F6), // Blue
      category: MediaCategoryType.audio,
    ),
    FormatDefinition(
      id: 'flac',
      name: 'FLAC',
      extension: 'flac',
      description: 'Free Lossless Audio Codec (Hi-Fi)',
      icon: Icons.album_outlined,
      color: Color(0xFF8B5CF6), // Violet
      category: MediaCategoryType.audio,
    ),
    FormatDefinition(
      id: 'ogg',
      name: 'OGG',
      extension: 'ogg',
      description: 'Ogg Vorbis open audio stream',
      icon: Icons.speaker_outlined,
      color: Color(0xFFF97316), // Orange
      category: MediaCategoryType.audio,
    ),
    FormatDefinition(
      id: 'm4a',
      name: 'M4A',
      extension: 'm4a',
      description: 'MPEG-4 Audio / Apple Lossless',
      icon: Icons.headphones_outlined,
      color: Color(0xFF6366F1), // Indigo
      category: MediaCategoryType.audio,
    ),
    FormatDefinition(
      id: 'opus',
      name: 'OPUS',
      extension: 'opus',
      description: 'Ultra-low latency modern voice & music',
      icon: Icons.mic_external_on_outlined,
      color: Color(0xFFD946EF), // Fuchsia
      category: MediaCategoryType.audio,
    ),
  ];

  static const List<FormatDefinition> pictureFormats = [
    FormatDefinition(
      id: 'png',
      name: 'PNG',
      extension: 'png',
      description: 'Portable Network Graphics (Transparency)',
      icon: Icons.image_outlined,
      color: Color(0xFF0EA5E9), // Sky Blue
      category: MediaCategoryType.picture,
    ),
    FormatDefinition(
      id: 'jpg',
      name: 'JPG / JPEG',
      extension: 'jpg',
      description: 'Joint Photographic Experts Group',
      icon: Icons.photo_size_select_actual_outlined,
      color: Color(0xFFF59E0B), // Amber
      category: MediaCategoryType.picture,
    ),
    FormatDefinition(
      id: 'webp',
      name: 'WebP',
      extension: 'webp',
      description: 'Next-gen Google high compression web image',
      icon: Icons.filter_hdr_outlined,
      color: Color(0xFF10B981), // Emerald
      category: MediaCategoryType.picture,
    ),
    FormatDefinition(
      id: 'ico',
      name: 'ICO',
      extension: 'ico',
      description: 'Windows icon / Favicon format',
      icon: Icons.crop_square_outlined,
      color: Color(0xFF8B5CF6), // Purple
      category: MediaCategoryType.picture,
    ),
    FormatDefinition(
      id: 'bmp',
      name: 'BMP',
      extension: 'bmp',
      description: 'Standard Windows Bitmap',
      icon: Icons.grid_on_outlined,
      color: Color(0xFF64748B), // Slate
      category: MediaCategoryType.picture,
    ),
    FormatDefinition(
      id: 'gif_img',
      name: 'GIF',
      extension: 'gif',
      description: 'Graphic Interchange Format (Image)',
      icon: Icons.gif_box_outlined,
      color: Color(0xFFEC4899), // Pink
      category: MediaCategoryType.picture,
    ),
  ];

  static const List<FormatDefinition> documentFormats = [
    FormatDefinition(
      id: 'img_to_pdf',
      name: 'Images -> PDF',
      extension: 'pdf',
      description: 'Combine photos & scans into a multi-page PDF',
      icon: Icons.picture_as_pdf_outlined,
      color: Color(0xFFEF4444), // Red
      category: MediaCategoryType.document,
      isSpecialTool: true,
    ),
    FormatDefinition(
      id: 'text_to_pdf',
      name: 'Text -> PDF',
      extension: 'pdf',
      description: 'Convert text, code or notes to a polished PDF',
      icon: Icons.article_outlined,
      color: Color(0xFFF97316), // Orange
      category: MediaCategoryType.document,
      isSpecialTool: true,
    ),
  ];

  static const List<FormatDefinition> presetFormats = [
    FormatDefinition(
      id: 'preset_iphone',
      name: 'Apple iPhone / iPad',
      extension: 'mp4',
      description: 'Optimized H.264 profile for iOS devices',
      icon: Icons.phone_iphone_outlined,
      color: Color(0xFF38BDF8),
      category: MediaCategoryType.presets,
    ),
    FormatDefinition(
      id: 'preset_android',
      name: 'Android Device',
      extension: 'mp4',
      description: 'Universal MP4 playback for Android phones',
      icon: Icons.phone_android_outlined,
      color: Color(0xFF22C55E),
      category: MediaCategoryType.presets,
    ),
    FormatDefinition(
      id: 'preset_discord',
      name: 'Discord Video (<25MB)',
      extension: 'mp4',
      description: 'Intelligent compression to fit Discord limits',
      icon: Icons.forum_outlined,
      color: Color(0xFF5865F2),
      category: MediaCategoryType.presets,
    ),
    FormatDefinition(
      id: 'preset_youtube',
      name: 'YouTube 1080p',
      extension: 'mp4',
      description: 'High bitrate YouTube upload recommendation',
      icon: Icons.smart_display_outlined,
      color: Color(0xFFFF0000),
      category: MediaCategoryType.presets,
    ),
    FormatDefinition(
      id: 'preset_tiktok',
      name: 'TikTok / Shorts (9:16)',
      extension: 'mp4',
      description: 'Vertical 1080x1920 crop and scale',
      icon: Icons.stay_current_portrait_outlined,
      color: Color(0xFFE11D48),
      category: MediaCategoryType.presets,
    ),
  ];

  static List<FormatDefinition> getForCategory(MediaCategoryType category) {
    switch (category) {
      case MediaCategoryType.video:
        return videoFormats;
      case MediaCategoryType.audio:
        return audioFormats;
      case MediaCategoryType.picture:
        return pictureFormats;
      case MediaCategoryType.document:
        return documentFormats;
      case MediaCategoryType.presets:
        return presetFormats;
      case MediaCategoryType.tools:
        return [];
    }
  }

  static FormatDefinition? findById(String id) {
    for (final fmt in [
      ...videoFormats,
      ...audioFormats,
      ...pictureFormats,
      ...documentFormats,
      ...presetFormats,
    ]) {
      if (fmt.id == id) return fmt;
    }
    return null;
  }
}
