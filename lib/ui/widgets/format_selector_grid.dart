import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_category.dart';
import '../../providers/conversion_provider.dart';

class FormatSelectorGrid extends StatelessWidget {
  final VoidCallback onFormatChosen;

  const FormatSelectorGrid({
    super.key,
    required this.onFormatChosen,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversionProvider>();
    final formats = MediaCategories.getForCategory(provider.currentCategory);
    final theme = Theme.of(context);

    if (formats.isEmpty) {
      return const Center(child: Text('No formats available in this category.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.25,
      ),
      itemCount: formats.length,
      itemBuilder: (context, index) {
        final fmt = formats[index];
        final isSelected = provider.selectedFormat?.id == fmt.id;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              provider.setSelectedFormat(fmt);
              onFormatChosen();
            },
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? fmt.color.withValues(alpha: 0.15) : theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? fmt.color : Colors.grey.withValues(alpha: 0.18),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: fmt.color.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: fmt.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(fmt.icon, color: fmt.color, size: 24),
                      ),
                      if (fmt.isSpecialTool)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TOOL',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        )
                      else if (isSelected)
                        Icon(Icons.check_circle, color: fmt.color, size: 18),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmt.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? fmt.color : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fmt.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
