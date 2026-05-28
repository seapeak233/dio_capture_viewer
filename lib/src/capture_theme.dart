import 'package:flutter/material.dart';

class CaptureTheme {
  CaptureTheme(BuildContext context)
    : colorScheme = Theme.of(context).colorScheme,
      textTheme = Theme.of(context).textTheme;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  Color get surface => colorScheme.surface;
  Color get background => colorScheme.surfaceContainerLowest;
  Color get inputFill => colorScheme.surfaceContainerHighest;
  Color get borderSubtle => colorScheme.outlineVariant;
  Color get textPrimary => colorScheme.onSurface;
  Color get textBody => colorScheme.onSurface;
  Color get textMuted => colorScheme.onSurfaceVariant;
  Color get brandAccent => colorScheme.primary;
  Color get brandSoft => colorScheme.primaryContainer;
  Color get success => Colors.green.shade600;
  Color get error => colorScheme.error;
  Color get warning => Colors.orange.shade700;
  Color get warningContainer => Colors.orange.shade100;
  Color get info => Colors.blue.shade600;
  Color get shadow => Colors.black.withAlpha(36);
}
