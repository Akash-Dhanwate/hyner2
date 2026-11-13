import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/page_content.dart';

class ThemePresetPicker extends ConsumerStatefulWidget {
  const ThemePresetPicker({super.key});

  @override
  ConsumerState<ThemePresetPicker> createState() => _ThemePresetPickerState();
}

class _ThemePresetPickerState extends ConsumerState<ThemePresetPicker> {
  bool _saving = false;
  String? _error;

  Future<void> _select(ThemePreset preset) async {
    if (_saving || ref.read(themePresetProvider) == preset) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(themePresetProvider.notifier).select(preset);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Theme could not be saved. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(themePresetProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Theme', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Choose a colour palette. Your light or dark appearance stays the same.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560
                ? 4
                : constraints.maxWidth >= 300 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 22
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final preset in ThemePreset.values)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      selected: selected == preset,
                      button: true,
                      label: '${preset.label} theme',
                      excludeSemantics: true,
                      enabled: !_saving,
                      onTap: _saving ? null : () => _select(preset),
                      child: Material(
                        color: theme.colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: selected == preset
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            width: selected == preset ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('theme-preset-${preset.name}'),
                          onTap: _saving ? null : () => _select(preset),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ExcludeSemantics(
                                  child: _PalettePreview(preset: preset),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        preset.label,
                                        style: theme.textTheme.labelLarge,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      selected == preset
                                          ? Icons.check_circle_outline
                                          : Icons.circle_outlined,
                                      size: 20,
                                      color: selected == preset
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (_saving) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(semanticsLabel: 'Saving theme'),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          InlineNotice(_error!, isError: true),
        ],
      ],
    );
  }
}

class _PalettePreview extends StatelessWidget {
  const _PalettePreview({required this.preset});
  final ThemePreset preset;
  @override
  Widget build(BuildContext context) {
    final colors = HynerTheme.build(
      Theme.of(context).brightness,
      preset: preset,
    ).colorScheme;
    return Container(
      height: 60,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FractionallySizedBox(
                  widthFactor: .8,
                  child: Container(height: 4, color: colors.onSurfaceVariant),
                ),
                Row(
                  children: [
                    for (final color in [
                      colors.primary,
                      colors.primaryContainer,
                      colors.outlineVariant,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
