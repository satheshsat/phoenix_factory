import 'package:flutter/material.dart';

import '../../models/conversion_options.dart';
import '../../models/conversion_task.dart';
import '../../models/media_category.dart';
import 'video_clip_crop_dialog.dart';

class OutputSettingsDialog extends StatefulWidget {
  final ConversionTask task;
  final Function(ConversionOptions options) onSave;

  const OutputSettingsDialog({
    super.key,
    required this.task,
    required this.onSave,
  });

  @override
  State<OutputSettingsDialog> createState() => _OutputSettingsDialogState();
}

class _OutputSettingsDialogState extends State<OutputSettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ConversionOptions _options;

  final TextEditingController _startTimeCtrl = TextEditingController();
  final TextEditingController _endTimeCtrl = TextEditingController();
  final TextEditingController _imgWidthCtrl = TextEditingController();
  final TextEditingController _imgHeightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _options = widget.task.options.copyWith();
    _startTimeCtrl.text = _options.startTime;
    _endTimeCtrl.text = _options.endTime;
    if (_options.imageWidth != null) _imgWidthCtrl.text = _options.imageWidth.toString();
    if (_options.imageHeight != null) _imgHeightCtrl.text = _options.imageHeight.toString();

    final isPicture = widget.task.targetFormat.category == MediaCategoryType.picture;
    _tabController = TabController(length: isPicture ? 2 : 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _imgWidthCtrl.dispose();
    _imgHeightCtrl.dispose();
    super.dispose();
  }

  void _save() {
    _options.startTime = _startTimeCtrl.text.trim();
    _options.endTime = _endTimeCtrl.text.trim();
    _options.imageWidth = int.tryParse(_imgWidthCtrl.text.trim());
    _options.imageHeight = int.tryParse(_imgHeightCtrl.text.trim());

    widget.onSave(_options);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPicture = widget.task.targetFormat.category == MediaCategoryType.picture;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.canvasColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.task.targetFormat.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.task.targetFormat.icon, color: widget.task.targetFormat.color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Output Configuration: ${widget.task.targetFormat.name}',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.task.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                tabs: isPicture
                    ? const [
                        Tab(icon: Icon(Icons.tune, size: 18), text: 'Image Settings'),
                        Tab(icon: Icon(Icons.photo_filter, size: 18), text: 'Filters & Effects'),
                      ]
                    : const [
                        Tab(icon: Icon(Icons.videocam_outlined, size: 18), text: 'Video Stream'),
                        Tab(icon: Icon(Icons.audiotrack_outlined, size: 18), text: 'Audio Stream'),
                        Tab(icon: Icon(Icons.content_cut, size: 18), text: 'Trim & Clip'),
                      ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: isPicture
                      ? [
                          _buildImageSettingsTab(theme),
                          _buildImageFiltersTab(theme),
                        ]
                      : [
                          _buildVideoStreamTab(theme),
                          _buildAudioStreamTab(theme),
                          _buildTrimTab(theme),
                        ],
                ),
              ),

              const SizedBox(height: 16),
              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Apply Settings'),
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoStreamTab(ThemeData theme) {
    return ListView(
      children: [
        _buildDropdownRow(
          title: 'Resolution',
          value: _options.resolution,
          items: const [
            DropdownMenuItem(value: 'original', child: Text('Default (Keep Original)')),
            DropdownMenuItem(value: '3840x2160', child: Text('4K Ultra HD (3840x2160)')),
            DropdownMenuItem(value: '2560x1440', child: Text('2K QHD (2560x1440)')),
            DropdownMenuItem(value: '1920x1080', child: Text('1080p Full HD (1920x1080)')),
            DropdownMenuItem(value: '1280x720', child: Text('720p HD Ready (1280x720)')),
            DropdownMenuItem(value: '854x480', child: Text('480p SD (854x480)')),
          ],
          onChanged: (v) => setState(() => _options.resolution = v!),
        ),
        _buildDropdownRow(
          title: 'Video Encoder',
          value: _options.videoCodec,
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Auto (Recommended)')),
            DropdownMenuItem(value: 'h264', child: Text('H.264 / AVC (Broad Compatibility)')),
            DropdownMenuItem(value: 'hevc', child: Text('H.265 / HEVC (High Efficiency)')),
            DropdownMenuItem(value: 'vp9', child: Text('VP9 (Google Open Codec)')),
            DropdownMenuItem(value: 'copy', child: Text('Passthrough (Copy Without Re-encoding)')),
          ],
          onChanged: (v) => setState(() => _options.videoCodec = v!),
        ),
        _buildDropdownRow(
          title: 'Video Bitrate',
          value: _options.videoBitrate,
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Auto Bitrate')),
            DropdownMenuItem(value: '10M', child: Text('10 Mbps (Ultra Quality)')),
            DropdownMenuItem(value: '6M', child: Text('6 Mbps (High Quality)')),
            DropdownMenuItem(value: '3M', child: Text('3 Mbps (Standard Quality)')),
            DropdownMenuItem(value: '1.5M', child: Text('1.5 Mbps (Medium)')),
            DropdownMenuItem(value: '800k', child: Text('800 kbps (Small File)')),
          ],
          onChanged: (v) => setState(() => _options.videoBitrate = v!),
        ),
        _buildDropdownRow(
          title: 'Frame Rate (FPS)',
          value: _options.fps,
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Auto (Match Source)')),
            DropdownMenuItem(value: '60', child: Text('60 FPS (Ultra Smooth)')),
            DropdownMenuItem(value: '30', child: Text('30 FPS (Standard Video)')),
            DropdownMenuItem(value: '24', child: Text('24 FPS (Cinematic)')),
          ],
          onChanged: (v) => setState(() => _options.fps = v!),
        ),
        _buildDropdownRow(
          title: 'Aspect Ratio',
          value: _options.aspectRatio,
          items: const [
            DropdownMenuItem(value: 'original', child: Text('Original Aspect Ratio')),
            DropdownMenuItem(value: '16:9', child: Text('16:9 Widescreen (YouTube / TV)')),
            DropdownMenuItem(value: '4:3', child: Text('4:3 Classic TV')),
            DropdownMenuItem(value: '9:16', child: Text('9:16 Vertical (TikTok / Reels)')),
            DropdownMenuItem(value: '1:1', child: Text('1:1 Square (Instagram)')),
          ],
          onChanged: (v) => setState(() => _options.aspectRatio = v!),
        ),
      ],
    );
  }

  Widget _buildAudioStreamTab(ThemeData theme) {
    return ListView(
      children: [
        _buildDropdownRow(
          title: 'Audio Encoder',
          value: _options.audioCodec,
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Auto (Recommended)')),
            DropdownMenuItem(value: 'aac', child: Text('AAC (Advanced Audio Coding)')),
            DropdownMenuItem(value: 'mp3', child: Text('MP3 (MPEG Layer 3)')),
            DropdownMenuItem(value: 'opus', child: Text('Opus (High Efficiency)')),
            DropdownMenuItem(value: 'flac', child: Text('FLAC (Lossless)')),
            DropdownMenuItem(value: 'copy', child: Text('Copy (Direct Stream Passthrough)')),
            DropdownMenuItem(value: 'mute', child: Text('Disable Audio (Mute Stream)')),
          ],
          onChanged: (v) => setState(() => _options.audioCodec = v!),
        ),
        _buildDropdownRow(
          title: 'Audio Bitrate',
          value: _options.audioBitrate,
          items: const [
            DropdownMenuItem(value: '320k', child: Text('320 kbps (Studio Quality)')),
            DropdownMenuItem(value: '256k', child: Text('256 kbps (Very High)')),
            DropdownMenuItem(value: '192k', child: Text('192 kbps (Standard)')),
            DropdownMenuItem(value: '128k', child: Text('128 kbps (Good)')),
            DropdownMenuItem(value: '64k', child: Text('64 kbps (Voice / Low Bandwidth)')),
          ],
          onChanged: (v) => setState(() => _options.audioBitrate = v!),
        ),
        _buildDropdownRow(
          title: 'Audio Channels',
          value: _options.channels,
          items: const [
            DropdownMenuItem(value: 'original', child: Text('Keep Original Channels')),
            DropdownMenuItem(value: 'stereo', child: Text('Stereo (2 Channels)')),
            DropdownMenuItem(value: 'mono', child: Text('Mono (1 Channel)')),
          ],
          onChanged: (v) => setState(() => _options.channels = v!),
        ),
        const SizedBox(height: 12),
        Text('Volume Boost: ${(_options.volume * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: _options.volume,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          label: '${(_options.volume * 100).toInt()}%',
          onChanged: (v) => setState(() => _options.volume = v),
        ),
      ],
    );
  }

  Widget _buildTrimTab(ThemeData theme) {
    return ListView(
      children: [
        if (widget.task.targetFormat.category == MediaCategoryType.video) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.15),
                  const Color(0xFFEC4899).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.movie_filter_rounded, color: Color(0xFF6366F1), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visual Video Player & Trimmer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Play video, scrub timeline, set start & end points, and apply spatial crop',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final res = await VideoClipCropDialog.show(context, widget.task);
                    if (res == true && mounted) {
                      setState(() {
                        _options = widget.task.options;
                        _startTimeCtrl.text = _options.startTime;
                        _endTimeCtrl.text = _options.endTime;
                      });
                    }
                  },
                  icon: const Icon(Icons.play_circle_fill, size: 16),
                  label: const Text('Play & Crop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(
          title: const Text('Enable Time Trimming', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Cut specific start and end points of this media file'),
          value: _options.enableTrim,
          onChanged: (v) => setState(() => _options.enableTrim = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startTimeCtrl,
                enabled: _options.enableTrim,
                decoration: const InputDecoration(
                  labelText: 'Start Time (HH:MM:SS)',
                  hintText: '00:00:00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.play_arrow),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _endTimeCtrl,
                enabled: _options.enableTrim,
                decoration: const InputDecoration(
                  labelText: 'End Time (HH:MM:SS)',
                  hintText: '00:05:00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.stop),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.blue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Format Factory fast trimming cuts your media with sub-second frame accuracy.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSettingsTab(ThemeData theme) {
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _imgWidthCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Width (px)',
                  hintText: 'e.g. 1920',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _imgHeightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Height (px)',
                  hintText: 'e.g. 1080',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Maintain Aspect Ratio'),
          value: _options.keepAspectRatio,
          onChanged: (v) => setState(() => _options.keepAspectRatio = v ?? true),
        ),
        const SizedBox(height: 12),
        Text('Image Quality: ${_options.imageQuality}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: _options.imageQuality.toDouble(),
          min: 10,
          max: 100,
          divisions: 18,
          label: '${_options.imageQuality}%',
          onChanged: (v) => setState(() => _options.imageQuality = v.toInt()),
        ),
      ],
    );
  }

  Widget _buildImageFiltersTab(ThemeData theme) {
    return ListView(
      children: [
        _buildDropdownRow(
          title: 'Color Filter Effect',
          value: _options.imageFilter,
          items: const [
            DropdownMenuItem(value: ImageFilterType.none, child: Text('None (Natural Colors)')),
            DropdownMenuItem(value: ImageFilterType.grayscale, child: Text('Grayscale / B&W')),
            DropdownMenuItem(value: ImageFilterType.sepia, child: Text('Sepia Vintage')),
            DropdownMenuItem(value: ImageFilterType.invert, child: Text('Invert Colors / Negative')),
          ],
          onChanged: (v) => setState(() => _options.imageFilter = v!),
        ),
        _buildDropdownRow(
          title: 'Rotation Angle',
          value: _options.rotationDegrees,
          items: const [
            DropdownMenuItem(value: 0, child: Text('0° (Normal Orientation)')),
            DropdownMenuItem(value: 90, child: Text('90° Clockwise')),
            DropdownMenuItem(value: 180, child: Text('180° Upside Down')),
            DropdownMenuItem(value: 270, child: Text('270° Counter-Clockwise')),
          ],
          onChanged: (v) => setState(() => _options.rotationDegrees = v!),
        ),
      ],
    );
  }

  Widget _buildDropdownRow<T>({
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: Container(height: 1, color: Colors.grey.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}
