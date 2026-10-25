import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'palette.dart';

/// Snackbar + haptic confirmation for every save / copy / export.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> notify(
  BuildContext context,
  String message, {
  bool success = false,
  SnackBarAction? action,
}) {
  HapticFeedback.lightImpact();
  final m = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return m.showSnackBar(SnackBar(
    action: action,
    content: Row(children: [
      if (success) ...[
        const Icon(Icons.check_circle_rounded, color: Palette.success),
        const SizedBox(width: 8),
      ],
      Expanded(child: Text(message)),
    ]),
  ));
}

/// Modal linear-progress dialog. Close with `Navigator.of(context, rootNavigator: true).pop()`.
void showProgress(BuildContext context, ValueListenable<double> progress, String label) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (ctx, v, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            Semantics(label: label, value: '${(v * 100).round()} percent',
                child: LinearProgressIndicator(value: v <= 0 ? null : v)),
          ]),
        ),
      ),
    ),
  );
}
