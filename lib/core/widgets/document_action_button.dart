import 'package:flutter/material.dart';

/// Shared presentation only: callers own generation, permissions and file APIs.
class DocumentActionButton extends StatelessWidget {
  const DocumentActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.filename,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final String? filename;

  @override
  Widget build(BuildContext context) {
    final button = primary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label),
          );
    return filename == null
        ? button
        : Tooltip(message: filename!, child: button);
  }
}
