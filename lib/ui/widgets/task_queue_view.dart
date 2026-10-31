import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../models/conversion_task.dart';
import '../../providers/conversion_provider.dart';
import '../dialogs/media_inspector_dialog.dart';
import '../dialogs/output_settings_dialog.dart';
import '../dialogs/video_clip_crop_dialog.dart';

class TaskQueueView extends StatefulWidget {
  final VoidCallback onPickFormat;

  const TaskQueueView({
    super.key,
    required this.onPickFormat,
  });

  @override
  State<TaskQueueView> createState() => _TaskQueueViewState();
}

class _TaskQueueViewState extends State<TaskQueueView> {
  bool _isDragging = false;

  Future<void> _pickFiles(BuildContext context) async {
    final provider = context.read<ConversionProvider>();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Select Files to Convert',
    );

    if (result != null && result.paths.isNotEmpty) {
      final validPaths = result.paths.whereType<String>().toList();
      provider.addFiles(validPaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversionProvider>();
    final theme = Theme.of(context);

    final content = Column(
      children: [
        // Top Action Control Bar
        _buildTopActionBar(context, provider, theme),

        // Main Queue / Dropzone Area
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: _isDragging ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
            child: provider.tasks.isEmpty
                ? _buildEmptyDropzone(context, provider, theme)
                : _buildTaskList(context, provider, theme),
          ),
        ),

        // Bottom Summary & Status Bar
        _buildBottomStatusBar(context, provider, theme),
      ],
    );

    final isTesting = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTesting) {
      return content;
    }

    return DropTarget(
      onEnter: (_) => setState(() => _isDragging = true),
      onLeave: () => setState(() => _isDragging = false),
      onDrop: (detail) {
        setState(() => _isDragging = false);
        final paths = <String>[];
        for (final item in detail.items) {
          if (item is DropFileItem && item.localPath != null && item.localPath!.isNotEmpty) {
            paths.add(item.localPath!);
          }
        }
        if (paths.isNotEmpty) {
          provider.addFiles(paths);
        }
      },
      child: content,
    );
  }

  Widget _buildTopActionBar(BuildContext context, ConversionProvider provider, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.isProcessing ? Colors.orange : const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            icon: Icon(
              provider.isProcessing
                  ? (provider.isPaused ? Icons.play_arrow : Icons.pause)
                  : Icons.play_arrow_rounded,
              size: 18,
            ),
            label: Text(
              provider.isProcessing
                  ? (provider.isPaused ? 'Resume' : 'Pause')
                  : 'Start Converting',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: provider.tasks.isEmpty
                ? null
                : () {
                    if (provider.isProcessing) {
                      if (provider.isPaused) {
                        provider.resumeConversion();
                      } else {
                        provider.pauseConversion();
                      }
                    } else {
                      provider.startConversion();
                    }
                  },
          ),
          if (provider.isProcessing)
            IconButton(
              tooltip: 'Stop All',
              icon: const Icon(Icons.stop_rounded, color: Colors.red),
              onPressed: () => provider.stopConversion(),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Files', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _pickFiles(context),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.tune, size: 16),
            label: Text(
              provider.selectedFormat != null ? 'Format: ${provider.selectedFormat!.name}' : 'Select Format',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: widget.onPickFormat,
          ),
          TextButton.icon(
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Open Folder', style: TextStyle(fontSize: 12)),
            onPressed: () => provider.openOutputDirectory(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.cleaning_services_outlined, size: 16),
            label: const Text('Clear Done', style: TextStyle(fontSize: 12)),
            onPressed: provider.completedCount > 0 ? () => provider.clearCompleted() : null,
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.red),
            label: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 12)),
            onPressed: provider.tasks.isNotEmpty ? () => provider.clearAll() : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDropzone(BuildContext context, ConversionProvider provider, ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDragging ? theme.colorScheme.primary : Colors.grey.withValues(alpha: 0.2),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (provider.selectedFormat?.color ?? theme.colorScheme.primary).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 44,
                  color: provider.selectedFormat?.color ?? theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Drag & Drop Files Here',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Any Video, Audio, Picture, or Document will be queued for conversion to ${provider.selectedFormat?.name ?? "target format"}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Browse Files'),
                    onPressed: () => _pickFiles(context),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.category_outlined, size: 18),
                    label: const Text('Change Format'),
                    onPressed: widget.onPickFormat,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, ConversionProvider provider, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.tasks.length,
      itemBuilder: (context, index) {
        final task = provider.tasks[index];
        return _buildTaskCard(context, provider, task, theme);
      },
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    ConversionProvider provider,
    ConversionTask task,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: task.status == TaskStatus.converting
              ? theme.colorScheme.primary
              : Colors.grey.withValues(alpha: 0.15),
          width: task.status == TaskStatus.converting ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Format Icon Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: task.targetFormat.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(task.targetFormat.icon, color: task.targetFormat.color, size: 24),
                ),
                const SizedBox(width: 14),

                // File Name & Sizes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Target format badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: task.targetFormat.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-> ${task.targetFormat.name}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: task.targetFormat.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Size: ${task.formattedSourceSize}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                          if (task.status == TaskStatus.completed && task.outputSize != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_right_alt, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Out: ${task.formattedOutputSize}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                          if (task.speed != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              'Speed: ${task.speed}',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                            ),
                          ],
                          if (task.currentFps != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${task.currentFps} fps',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                      if (task.options.enableTrim || task.options.enableCrop) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (task.options.enableTrim)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.content_cut, size: 10, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${task.options.startTime} - ${task.options.endTime.isEmpty ? "End" : task.options.endTime}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                    ),
                                  ],
                                ),
                              ),
                            if (task.options.enableCrop)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.crop, size: 10, color: Color(0xFFEC4899)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Crop: ${task.options.cropAspectRatio}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEC4899)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.status == TaskStatus.completed)
                      IconButton(
                        tooltip: 'Play / Open Converted File',
                        icon: const Icon(Icons.play_circle_fill, color: Colors.green, size: 26),
                        onPressed: () => provider.openConvertedFile(task),
                      ),
                    if (task.status == TaskStatus.failed)
                      IconButton(
                        tooltip: 'Retry Conversion',
                        icon: const Icon(Icons.refresh, color: Colors.orange),
                        onPressed: () => provider.retryTask(task.id),
                      ),
                    IconButton(
                      tooltip: 'Inspect Media Info',
                      icon: const Icon(Icons.info_outline, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => MediaInspectorDialog(
                            filePath: task.sourcePath,
                            fileName: task.fileName,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Video Clip & Crop (Play, Set Start & End)',
                      icon: Icon(
                        Icons.content_cut_rounded,
                        size: 20,
                        color: (task.options.enableTrim || task.options.enableCrop)
                            ? const Color(0xFF6366F1)
                            : null,
                      ),
                      onPressed: () async {
                        final updated = await VideoClipCropDialog.show(context, task);
                        if (updated == true && mounted) {
                          setState(() {});
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Output Settings',
                      icon: const Icon(Icons.settings_outlined, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => OutputSettingsDialog(
                            task: task,
                            onSave: (newOpt) => provider.updateTaskOptions(task.id, newOpt),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close, size: 20, color: Colors.redAccent),
                      onPressed: () => provider.removeTask(task.id),
                    ),
                  ],
                ),
              ],
            ),

            // Live Progress Bar (if converting or completed)
            if (task.status == TaskStatus.converting || task.status == TaskStatus.completed || task.status == TaskStatus.failed) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.status == TaskStatus.completed ? 1.0 : task.progress,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    task.status == TaskStatus.completed
                        ? Colors.green
                        : task.status == TaskStatus.failed
                            ? Colors.red
                            : theme.colorScheme.primary,
                  ),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    task.status == TaskStatus.completed
                        ? 'Completed'
                        : task.status == TaskStatus.failed
                            ? 'Failed: ${task.errorMessage ?? "Error occurred"}'
                            : 'Converting... ${(task.progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: task.status == TaskStatus.completed
                          ? Colors.green
                          : task.status == TaskStatus.failed
                              ? Colors.red
                              : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomStatusBar(BuildContext context, ConversionProvider provider, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Column(
        children: [
          if (provider.isProcessing) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: provider.overallProgress,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Hardware & Engine indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.mediaEngine.isFFmpegAvailable ? Colors.green : Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.mediaEngine.isFFmpegAvailable
                          ? 'FFmpeg 7.0 Hardware Engine Active'
                          : 'Pure Dart Processing Engine Active',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(width: 24),

                // Task statistics chips
                Text(
                  'Total: ${provider.totalTasks} | Queued: ${provider.queuedCount} | Active: ${provider.convertingCount} | Done: ${provider.completedCount}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(width: 24),

                // Output directory selector
                InkWell(
                  onTap: () => provider.pickOutputDirectory(),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          provider.outputDirectory.isNotEmpty ? provider.outputDirectory : 'Choose Folder',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
