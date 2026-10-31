import 'package:flutter/material.dart';
import '../../services/media_engine.dart';
import '../../models/conversion_task.dart';

class MediaInspectorDialog extends StatefulWidget {
  final String filePath;
  final String fileName;

  const MediaInspectorDialog({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<MediaInspectorDialog> createState() => _MediaInspectorDialogState();
}

class _MediaInspectorDialogState extends State<MediaInspectorDialog> {
  MediaInfoResult? _info;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMediaInfo();
  }

  Future<void> _loadMediaInfo() async {
    final result = await MediaEngine().inspectMedia(widget.filePath);
    if (mounted) {
      setState(() {
        _info = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.canvasColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.analytics_outlined, color: theme.colorScheme.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Media Inspector', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
              const Divider(height: 1),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _info == null
                        ? const Center(child: Text('Unable to read media metadata'))
                        : ListView(
                            children: [
                              _buildInfoRow('Container Format', _info!.formatName),
                              _buildInfoRow('File Size', ConversionTask.formatBytes(_info!.sizeBytes)),
                              if (_info!.duration != null)
                                _buildInfoRow('Duration', _formatDuration(_info!.duration!)),
                              if (_info!.overallBitrate != null)
                                _buildInfoRow('Overall Bitrate', '${_info!.overallBitrate! ~/ 1000} kbps'),
                              const SizedBox(height: 16),
                              const Text('Streams & Codecs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 8),
                              if (_info!.streams.isEmpty)
                                const Text('No detailed stream metadata found.', style: TextStyle(color: Colors.grey))
                              else
                                ..._info!.streams.map((stream) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.cardColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                stream.type == 'video'
                                                    ? Icons.videocam
                                                    : stream.type == 'audio'
                                                        ? Icons.audiotrack
                                                        : Icons.subtitles,
                                                size: 16,
                                                color: theme.colorScheme.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Stream: ${stream.type.toUpperCase()}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  stream.codec.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          if (stream.resolution != null)
                                            Text('Resolution: ${stream.resolution}', style: const TextStyle(fontSize: 12)),
                                          if (stream.bitrate != null)
                                            Text('Bitrate: ${stream.bitrate}', style: const TextStyle(fontSize: 12)),
                                          if (stream.sampleRate != null)
                                            Text('Sample Rate: ${stream.sampleRate}', style: const TextStyle(fontSize: 12)),
                                          if (stream.channels != null)
                                            Text('Channels: ${stream.channels}', style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )),
                            ],
                          ),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
