import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../models/media_category.dart';
import '../../providers/conversion_provider.dart';
import '../../providers/theme_provider.dart';
import '../dialogs/media_inspector_dialog.dart';
import '../widgets/format_selector_grid.dart';
import '../widgets/task_queue_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0; // 0 = Queue View, 1 = Format Catalog

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversionProvider>().initialize();
    });
  }

  Future<void> _inspectAnyFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Media File to Inspect',
    );
    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => MediaInspectorDialog(
            filePath: result.files.single.path!,
            fileName: result.files.single.name,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversionProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Scaffold(
          appBar: isMobile
              ? AppBar(
                  title: const Text('Phornix Factory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.analytics_outlined),
                      tooltip: 'Media Inspector',
                      onPressed: () => _inspectAnyFile(context),
                    ),
                    PopupMenuButton<AppThemeMode>(
                      icon: const Icon(Icons.palette_outlined),
                      tooltip: 'Change Theme',
                      onSelected: (mode) => themeProvider.setTheme(mode),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: AppThemeMode.darkStudio, child: Text('Dark Studio')),
                        PopupMenuItem(value: AppThemeMode.classicBlue, child: Text('Classic Blue')),
                        PopupMenuItem(value: AppThemeMode.cyberNeon, child: Text('Cyber Neon')),
                        PopupMenuItem(value: AppThemeMode.lightClean, child: Text('Clean Light')),
                      ],
                    ),
                  ],
                )
              : null,
          drawer: isMobile ? Drawer(child: _buildSidebarContent(context, provider, themeProvider, theme)) : null,
          body: isMobile
              ? Column(
                  children: [
                    _buildHeader(context, provider, themeProvider, theme, isMobile: true),
                    Expanded(
                      child: _currentTabIndex == 0
                          ? TaskQueueView(onPickFormat: () => setState(() => _currentTabIndex = 1))
                          : FormatSelectorGrid(onFormatChosen: () => setState(() => _currentTabIndex = 0)),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Desktop Sidebar
                    Container(
                      width: 240,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        border: Border(right: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                      ),
                      child: _buildSidebarContent(context, provider, themeProvider, theme),
                    ),

                    // Main Center Stage
                    Expanded(
                      child: Column(
                        children: [
                          _buildHeader(context, provider, themeProvider, theme, isMobile: false),
                          Expanded(
                            child: _currentTabIndex == 0
                                ? TaskQueueView(onPickFormat: () => setState(() => _currentTabIndex = 1))
                                : FormatSelectorGrid(onFormatChosen: () => setState(() => _currentTabIndex = 0)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSidebarContent(
    BuildContext context,
    ConversionProvider provider,
    ThemeProvider themeProvider,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // Logo & Branding
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEF4444), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_motion, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Phornix Factory',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Universal Converter',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Categories List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            children: [
              _buildCategoryItem(
                context,
                title: 'Video',
                subtitle: 'MP4, MKV, WebM, AVI, GIF',
                icon: Icons.movie_outlined,
                color: const Color(0xFF6366F1),
                category: MediaCategoryType.video,
                provider: provider,
              ),
              _buildCategoryItem(
                context,
                title: 'Audio',
                subtitle: 'MP3, WAV, FLAC, AAC, OGG',
                icon: Icons.audiotrack_outlined,
                color: const Color(0xFF10B981),
                category: MediaCategoryType.audio,
                provider: provider,
              ),
              _buildCategoryItem(
                context,
                title: 'Picture',
                subtitle: 'PNG, JPG, WebP, ICO, BMP',
                icon: Icons.image_outlined,
                color: const Color(0xFF0EA5E9),
                category: MediaCategoryType.picture,
                provider: provider,
              ),
              _buildCategoryItem(
                context,
                title: 'Document',
                subtitle: 'Images to PDF, Text to PDF',
                icon: Icons.picture_as_pdf_outlined,
                color: const Color(0xFFEF4444),
                category: MediaCategoryType.document,
                provider: provider,
              ),
              _buildCategoryItem(
                context,
                title: 'Device Presets',
                subtitle: 'iPhone, Android, Discord, TikTok',
                icon: Icons.devices_outlined,
                color: const Color(0xFFF59E0B),
                category: MediaCategoryType.presets,
                provider: provider,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Divider(),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.analytics_outlined, color: Colors.deepPurpleAccent, size: 20),
                  title: const Text('Media Inspector', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Examine streams & codecs', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    _inspectAnyFile(context);
                  },
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Bottom Theme selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.palette_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<AppThemeMode>(
                  isExpanded: true,
                  value: themeProvider.currentTheme,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                  items: const [
                    DropdownMenuItem(value: AppThemeMode.darkStudio, child: Text('Dark Studio', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: AppThemeMode.classicBlue, child: Text('Classic Blue', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: AppThemeMode.cyberNeon, child: Text('Cyber Neon', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: AppThemeMode.lightClean, child: Text('Clean Light', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (mode) {
                    if (mode != null) themeProvider.setTheme(mode);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required MediaCategoryType category,
    required ConversionProvider provider,
  }) {
    final isSelected = provider.currentCategory == category;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: isSelected ? Colors.white : color, size: 16),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? theme.textTheme.bodyLarge?.color : null,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isSelected ? Container(width: 3, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))) : null,
          onTap: () {
            provider.setCurrentCategory(category);
            setState(() => _currentTabIndex = 1);
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(); // close drawer if open
            }
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ConversionProvider provider,
    ThemeProvider themeProvider,
    ThemeData theme, {
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // View Switcher Tabs
            SegmentedButton<int>(
              segments: [
                ButtonSegment<int>(
                  value: 0,
                  icon: const Icon(Icons.queue_music_outlined, size: 15),
                  label: Text('Queue (${provider.tasks.length})', style: const TextStyle(fontSize: 12)),
                ),
                const ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.grid_view_rounded, size: 15),
                  label: Text('Formats', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_currentTabIndex},
              onSelectionChanged: (set) => setState(() => _currentTabIndex = set.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),

            const SizedBox(width: 14),

            // Active target format indicator badge
            if (provider.selectedFormat != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: provider.selectedFormat!.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: provider.selectedFormat!.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(provider.selectedFormat!.icon, size: 13, color: provider.selectedFormat!.color),
                    const SizedBox(width: 5),
                    Text(
                      'Default Target: ${provider.selectedFormat!.name}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: provider.selectedFormat!.color,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
