import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../models/conversion_task.dart';
import '../../services/media_engine.dart';

class VideoClipCropDialog extends StatefulWidget {
  final ConversionTask task;

  const VideoClipCropDialog({
    super.key,
    required this.task,
  });

  static Future<bool?> show(BuildContext context, ConversionTask task) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VideoClipCropDialog(task: task),
    );
  }

  @override
  State<VideoClipCropDialog> createState() => _VideoClipCropDialogState();
}

class _VideoClipCropDialogState extends State<VideoClipCropDialog> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  bool _useNativePlayer = false;
  bool _isLoading = true;

  Duration _totalDuration = const Duration(minutes: 1);
  Duration _currentPosition = Duration.zero;
  Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;

  bool _isPlaying = false;
  bool _isPreviewingClip = false;
  Timer? _playbackTimer;
  double _playbackSpeed = 1.0;

  // Frame engine cache
  Uint8List? _currentFrameBytes;
  bool _isFetchingFrame = false;

  // Spatial Crop
  bool _enableCrop = false;
  double _cropLeft = 0.0;
  double _cropTop = 0.0;
  double _cropWidth = 1.0;
  double _cropHeight = 1.0;
  String _cropPreset = 'free'; // 'free', '16:9', '9:16', '1:1', '4:3'
  int _videoNativeWidth = 1920;
  int _videoNativeHeight = 1080;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeOptions();
    _initializePlayer();
  }

  void _initializeOptions() {
    final opt = widget.task.options;
    if (opt.enableTrim) {
      if (opt.startTime.isNotEmpty) {
        _startTime = _parseTimestamp(opt.startTime);
      }
      if (opt.endTime.isNotEmpty) {
        _endTime = _parseTimestamp(opt.endTime);
      }
    }

    _enableCrop = opt.enableCrop;
    _cropPreset = opt.cropAspectRatio;
    if (opt.cropWidth != null && opt.cropHeight != null) {
      final cw = opt.cropWidth!.toDouble();
      final ch = opt.cropHeight!.toDouble();
      final cx = (opt.cropX ?? 0).toDouble();
      final cy = (opt.cropY ?? 0).toDouble();
      _cropLeft = cx / _videoNativeWidth;
      _cropTop = cy / _videoNativeHeight;
      _cropWidth = cw / _videoNativeWidth;
      _cropHeight = ch / _videoNativeHeight;
    }
  }

  Future<void> _initializePlayer() async {
    setState(() => _isLoading = true);

    // 1. Inspect media to get native duration and resolution
    try {
      final info = await MediaEngine().inspectMedia(widget.task.sourcePath);
      if (info != null) {
        if (info.duration != null && info.duration! > Duration.zero) {
          _totalDuration = info.duration!;
        }
        for (final s in info.streams) {
          if (s.type == 'video' && s.resolution != null) {
            final resParts = s.resolution!.split('x');
            if (resParts.length == 2) {
              _videoNativeWidth = int.tryParse(resParts[0]) ?? 1920;
              _videoNativeHeight = int.tryParse(resParts[1]) ?? 1080;
            }
          }
        }
      }
    } catch (_) {}

    if (_endTime == Duration.zero || _endTime > _totalDuration) {
      _endTime = _totalDuration;
    }

    // 2. Try native video player if not in test
    bool nativeSuccess = false;
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');

    if (!isTest) {
      try {
        final file = File(widget.task.sourcePath);
        if (file.existsSync()) {
          final controller = VideoPlayerController.file(file);
          await controller.initialize();
          _videoPlayerController = controller;
          _useNativePlayer = true;
          nativeSuccess = true;
          if (controller.value.duration > Duration.zero) {
            _totalDuration = controller.value.duration;
            if (_endTime == Duration.zero || _endTime > _totalDuration) {
              _endTime = _totalDuration;
            }
          }
          if (controller.value.size.width > 0) {
            _videoNativeWidth = controller.value.size.width.toInt();
            _videoNativeHeight = controller.value.size.height.toInt();
          }
          controller.addListener(_onNativePlayerStateChange);
        }
      } catch (e) {
        debugPrint('Native video player unavailable on this target: $e. Using high-speed frame engine.');
      }
    }

    if (!nativeSuccess) {
      // Use high-speed frame extraction
      _fetchFrameAt(_currentPosition);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onNativePlayerStateChange() {
    if (!mounted || _videoPlayerController == null) return;
    final pos = _videoPlayerController!.value.position;
    setState(() {
      _currentPosition = pos;
      _isPlaying = _videoPlayerController!.value.isPlaying;
    });

    if (_isPreviewingClip && pos >= _endTime) {
      _videoPlayerController!.pause();
      _videoPlayerController!.seekTo(_startTime);
      setState(() {
        _isPlaying = false;
        _isPreviewingClip = false;
      });
    }
  }

  Future<void> _fetchFrameAt(Duration pos) async {
    if (_isFetchingFrame) return;
    _isFetchingFrame = true;
    try {
      final bytes = await MediaEngine().extractVideoFrame(widget.task.sourcePath, pos);
      if (mounted && bytes != null) {
        setState(() {
          _currentFrameBytes = bytes;
        });
      }
    } catch (_) {
    } finally {
      _isFetchingFrame = false;
    }
  }

  void _togglePlayPause() {
    if (_useNativePlayer && _videoPlayerController != null) {
      if (_isPlaying) {
        _videoPlayerController!.pause();
      } else {
        if (_currentPosition >= _totalDuration) {
          _videoPlayerController!.seekTo(Duration.zero);
        }
        _videoPlayerController!.play();
      }
    } else {
      // Simulated playback using frame stepper
      if (_isPlaying) {
        _playbackTimer?.cancel();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isPlaying = true);
        const frameIntervalMs = 100; // ~10 fps preview on desktop
        _playbackTimer = Timer.periodic(const Duration(milliseconds: frameIntervalMs), (timer) {
          final nextMs = _currentPosition.inMilliseconds + (frameIntervalMs * _playbackSpeed).toInt();
          if (nextMs >= _totalDuration.inMilliseconds) {
            timer.cancel();
            setState(() {
              _isPlaying = false;
              _currentPosition = _totalDuration;
            });
            return;
          }

          if (_isPreviewingClip && nextMs >= _endTime.inMilliseconds) {
            timer.cancel();
            setState(() {
              _isPlaying = false;
              _isPreviewingClip = false;
              _currentPosition = _startTime;
            });
            _fetchFrameAt(_startTime);
            return;
          }

          final newPos = Duration(milliseconds: nextMs);
          setState(() {
            _currentPosition = newPos;
          });
          _fetchFrameAt(newPos);
        });
      }
    }
  }

  void _seekTo(Duration target) {
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > _totalDuration) clamped = _totalDuration;

    setState(() {
      _currentPosition = clamped;
    });

    if (_useNativePlayer && _videoPlayerController != null) {
      _videoPlayerController!.seekTo(clamped);
    } else {
      _fetchFrameAt(clamped);
    }
  }

  void _stepTime(int milliseconds) {
    final next = _currentPosition + Duration(milliseconds: milliseconds);
    _seekTo(next);
  }

  void _setStartTime() {
    setState(() {
      _startTime = _currentPosition;
      if (_startTime > _endTime) {
        _endTime = _totalDuration;
      }
    });
  }

  void _setEndTime() {
    setState(() {
      _endTime = _currentPosition;
      if (_endTime < _startTime) {
        _startTime = Duration.zero;
      }
    });
  }

  void _previewClipSegment() {
    _seekTo(_startTime);
    setState(() {
      _isPreviewingClip = true;
    });
    if (!_isPlaying) {
      _togglePlayPause();
    }
  }

  void _resetTrim() {
    setState(() {
      _startTime = Duration.zero;
      _endTime = _totalDuration;
    });
  }

  void _applyCropPreset(String preset) {
    setState(() {
      _cropPreset = preset;
      _enableCrop = true;
      if (preset == '16:9') {
        _cropLeft = 0.0;
        _cropTop = 0.0;
        _cropWidth = 1.0;
        _cropHeight = 1.0;
      } else if (preset == '9:16') {
        // Vertical center crop
        const targetW = 9 / 16;
        _cropWidth = targetW;
        _cropHeight = 1.0;
        _cropLeft = (1.0 - _cropWidth) / 2;
        _cropTop = 0.0;
      } else if (preset == '1:1') {
        // Square center crop
        _cropWidth = 0.6;
        _cropHeight = 0.6;
        _cropLeft = 0.2;
        _cropTop = 0.2;
      } else if (preset == '4:3') {
        _cropWidth = 0.75;
        _cropHeight = 1.0;
        _cropLeft = 0.125;
        _cropTop = 0.0;
      } else {
        // Free
        _cropLeft = 0.1;
        _cropTop = 0.1;
        _cropWidth = 0.8;
        _cropHeight = 0.8;
      }
    });
  }

  void _saveAndApply() {
    final opt = widget.task.options;

    // Apply Trim
    opt.enableTrim = true;
    opt.startTime = _formatDuration(_startTime);
    opt.endTime = _formatDuration(_endTime);

    // Apply Crop
    opt.enableCrop = _enableCrop;
    opt.cropAspectRatio = _cropPreset;
    if (_enableCrop) {
      final px = (_cropLeft * _videoNativeWidth).round();
      final py = (_cropTop * _videoNativeHeight).round();
      final pw = (_cropWidth * _videoNativeWidth).round();
      final ph = (_cropHeight * _videoNativeHeight).round();

      // Ensure even dimensions for ffmpeg H.264
      opt.cropX = px % 2 == 0 ? px : px - 1;
      opt.cropY = py % 2 == 0 ? py : py - 1;
      opt.cropWidth = pw % 2 == 0 ? pw : pw - 1;
      opt.cropHeight = ph % 2 == 0 ? ph : ph - 1;
    }

    Navigator.of(context).pop(true);
  }

  String _formatDuration(Duration d, {bool includeMillis = true}) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (!includeMillis) return '$hours:$minutes:$seconds';
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

  Duration _parseTimestamp(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length == 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final secParts = parts[2].split('.');
        final seconds = int.tryParse(secParts[0]) ?? 0;
        final millis = secParts.length > 1 ? (int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0) : 0;
        return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
      }
    } catch (_) {}
    return Duration.zero;
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _videoPlayerController?.removeListener(_onNativePlayerStateChange);
    _videoPlayerController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 760;

    final clipDuration = _endTime > _startTime ? _endTime - _startTime : Duration.zero;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(theme),

            // Tabs (Clip vs Crop)
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                tabs: const [
                  Tab(icon: Icon(Icons.content_cut, size: 18), text: 'Clip Timeline (Start & End)'),
                  Tab(icon: Icon(Icons.crop, size: 18), text: 'Crop Frame (Spatial)'),
                ],
              ),
            ),

            // Video Player & Controls
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading video stream...'),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Video Preview Viewport
                          _buildVideoViewport(theme),

                          const SizedBox(height: 16),

                          // Timeline Scrubber & Markers
                          _buildTimelineBar(theme, clipDuration),

                          const SizedBox(height: 16),

                          // Transport Bar (Play/Pause, Frame Steppers, Set Start / Set End)
                          _buildTransportControls(theme, isCompact),

                          const SizedBox(height: 16),

                          // Tab Specific Settings
                          AnimatedBuilder(
                            animation: _tabController,
                            builder: (context, _) {
                              return _tabController.index == 0
                                  ? _buildClipControls(theme, clipDuration)
                                  : _buildCropControls(theme);
                            },
                          ),
                        ],
                      ),
                    ),
            ),

            // Footer Actions
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(widget.task.sourcePath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_videoNativeWidth}x$_videoNativeHeight • ${_formatDuration(_totalDuration, includeMillis: false)} • ${widget.task.targetFormat.name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoViewport(ThemeData theme) {
    final aspectRatio = _videoNativeWidth > 0 && _videoNativeHeight > 0
        ? _videoNativeWidth / _videoNativeHeight
        : 16 / 9;

    return AspectRatio(
      aspectRatio: aspectRatio.clamp(1.0, 2.4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Surface
            if (_useNativePlayer && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
              VideoPlayer(_videoPlayerController!)
            else if (_currentFrameBytes != null)
              Image.memory(
                _currentFrameBytes!,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline, size: 64, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text(
                      'Preview Ready',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),

            // Spatial Crop Box Overlay (when Crop Tab is active or enabled)
            if (_enableCrop)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxW = constraints.maxWidth;
                    final boxH = constraints.maxHeight;

                    final cropPixelLeft = _cropLeft * boxW;
                    final cropPixelTop = _cropTop * boxH;
                    final cropPixelWidth = _cropWidth * boxW;
                    final cropPixelHeight = _cropHeight * boxH;

                    return Stack(
                      children: [
                        // Dimmed exterior mask
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.55),
                            BlendMode.srcOut,
                          ),
                          child: Stack(
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                ),
                              ),
                              Positioned(
                                left: cropPixelLeft,
                                top: cropPixelTop,
                                width: cropPixelWidth,
                                height: cropPixelHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Border with Grid Lines
                        Positioned(
                          left: cropPixelLeft,
                          top: cropPixelTop,
                          width: cropPixelWidth,
                          height: cropPixelHeight,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _cropLeft = (_cropLeft + details.delta.dx / boxW).clamp(0.0, 1.0 - _cropWidth);
                                _cropTop = (_cropTop + details.delta.dy / boxH).clamp(0.0, 1.0 - _cropHeight);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF6366F1), width: 2),
                              ),
                              child: Stack(
                                children: [
                                  // Grid 3x3 lines
                                  Column(
                                    children: [
                                      Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.25)))))),
                                      Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.25)))))),
                                      const Expanded(child: SizedBox()),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.25)))))),
                                      Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.25)))))),
                                      const Expanded(child: SizedBox()),
                                    ],
                                  ),
                                  // Center label
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${(_cropWidth * _videoNativeWidth).round()}x${(_cropHeight * _videoNativeHeight).round()}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Top Playback Speed indicator badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_playbackSpeed}x',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineBar(ThemeData theme, Duration clipDuration) {
    final totalMs = _totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds : 1;
    final currentMs = _currentPosition.inMilliseconds.clamp(0, totalMs);
    final startMs = _startTime.inMilliseconds.clamp(0, totalMs);
    final endMs = _endTime.inMilliseconds.clamp(0, totalMs);

    final startPct = startMs / totalMs;
    final endPct = endMs / totalMs;

    return Column(
      children: [
        // Time labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_currentPosition),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: theme.colorScheme.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Clip: ${_formatDuration(clipDuration)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Text(
              _formatDuration(_totalDuration),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Custom Scrubber Track with highlighted trim region
        SizedBox(
          height: 36,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Full Background Track
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Selected Clip Interval (Vibrant Gradient)
                  Positioned(
                    left: startPct * w,
                    width: ((endPct - startPct) * w).clamp(0.0, w),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Start Marker Flag
                  Positioned(
                    left: (startPct * w - 6).clamp(0.0, w - 12),
                    child: Tooltip(
                      message: 'Start Time: ${_formatDuration(_startTime)}',
                      child: Container(
                        width: 12,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.arrow_right, color: Colors.white, size: 10),
                      ),
                    ),
                  ),

                  // End Marker Flag
                  Positioned(
                    left: (endPct * w - 6).clamp(0.0, w - 12),
                    child: Tooltip(
                      message: 'End Time: ${_formatDuration(_endTime)}',
                      child: Container(
                        width: 12,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.arrow_left, color: Colors.white, size: 10),
                      ),
                    ),
                  ),

                  // Slider touch target
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 0,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                    ),
                    child: Slider(
                      value: currentMs.toDouble(),
                      min: 0.0,
                      max: totalMs.toDouble(),
                      onChanged: (val) {
                        _seekTo(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransportControls(ThemeData theme, bool isCompact) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // Stepper: -1s
        OutlinedButton.icon(
          onPressed: () => _stepTime(-1000),
          icon: const Icon(Icons.replay_10, size: 16),
          label: const Text('-1s'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),

        // Stepper: -0.1s
        OutlinedButton(
          onPressed: () => _stepTime(-100),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          child: const Text('◀ -0.1s'),
        ),

        // Big Play/Pause Button
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            iconSize: 32,
            color: Colors.white,
            icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            tooltip: _isPlaying ? 'Pause' : 'Play',
            onPressed: _togglePlayPause,
          ),
        ),

        // Stepper: +0.1s
        OutlinedButton(
          onPressed: () => _stepTime(100),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          child: const Text('+0.1s ▶'),
        ),

        // Stepper: +1s
        OutlinedButton.icon(
          onPressed: () => _stepTime(1000),
          icon: const Icon(Icons.forward_10, size: 16),
          label: const Text('+1s'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),

        const SizedBox(width: 8),

        // SET START BUTTON (Mark In)
        ElevatedButton.icon(
          onPressed: _setStartTime,
          icon: const Icon(Icons.flag_outlined, size: 16, color: Colors.white),
          label: const Text('[ Set Start'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            elevation: 2,
          ),
        ),

        // SET END BUTTON (Mark Out)
        ElevatedButton.icon(
          onPressed: _setEndTime,
          icon: const Icon(Icons.flag, size: 16, color: Colors.white),
          label: const Text('] Set End'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            elevation: 2,
          ),
        ),

        // Preview Segment Button
        OutlinedButton.icon(
          onPressed: _previewClipSegment,
          icon: const Icon(Icons.play_circle_fill, size: 16),
          label: const Text('Preview Clip'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildClipControls(ThemeData theme, Duration clipDuration) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Clip Interval Fine-Tuning',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _resetTrim,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Reset Range'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              // Start Time Indicator
              _buildTimeCard(
                theme: theme,
                title: 'Start Time',
                timeText: _formatDuration(_startTime),
                color: const Color(0xFF10B981),
                onNudgeBack: () => setState(() => _startTime = _startTime > const Duration(milliseconds: 500) ? _startTime - const Duration(milliseconds: 500) : Duration.zero),
                onNudgeForward: () => setState(() => _startTime = _startTime + const Duration(milliseconds: 500)),
              ),

              // End Time Indicator
              _buildTimeCard(
                theme: theme,
                title: 'End Time',
                timeText: _formatDuration(_endTime),
                color: const Color(0xFFEF4444),
                onNudgeBack: () => setState(() => _endTime = _endTime > _startTime + const Duration(milliseconds: 500) ? _endTime - const Duration(milliseconds: 500) : _startTime),
                onNudgeForward: () => setState(() => _endTime = _endTime < _totalDuration ? _endTime + const Duration(milliseconds: 500) : _totalDuration),
              ),

              // Playback Speed dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    value: _playbackSpeed,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 0.5, child: Text('0.5x Speed')),
                      DropdownMenuItem(value: 1.0, child: Text('1.0x Normal')),
                      DropdownMenuItem(value: 1.5, child: Text('1.5x Speed')),
                      DropdownMenuItem(value: 2.0, child: Text('2.0x Fast')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _playbackSpeed = val);
                        _videoPlayerController?.setPlaybackSpeed(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard({
    required ThemeData theme,
    required String title,
    required String timeText,
    required Color color,
    required VoidCallback onNudgeBack,
    required VoidCallback onNudgeForward,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              Text(
                timeText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove, size: 14),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            tooltip: '-0.5s',
            onPressed: onNudgeBack,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 14),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            tooltip: '+0.5s',
            onPressed: onNudgeForward,
          ),
        ],
      ),
    );
  }

  Widget _buildCropControls(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.crop_free, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Spatial Video Crop Overlay',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Switch(
                value: _enableCrop,
                onChanged: (val) {
                  setState(() => _enableCrop = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select an aspect ratio preset or adjust the crop box freely over the video preview.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('Free Crop', 'free'),
              _buildPresetChip('16:9 Landscape', '16:9'),
              _buildPresetChip('9:16 TikTok / Reel', '9:16'),
              _buildPresetChip('1:1 Square', '1:1'),
              _buildPresetChip('4:3 Standard', '4:3'),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _enableCrop = false;
                    _cropLeft = 0.0;
                    _cropTop = 0.0;
                    _cropWidth = 1.0;
                    _cropHeight = 1.0;
                  });
                },
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Reset Crop'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String preset) {
    final isSelected = _enableCrop && _cropPreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyCropPreset(preset),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _saveAndApply,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Apply Clip & Crop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
