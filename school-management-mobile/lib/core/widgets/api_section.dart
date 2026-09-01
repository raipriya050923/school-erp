import 'package:flutter/material.dart';

import '../student_store.dart';
import '../theme/app_theme.dart';

/// Renders one [Loadable] section: spinner while loading, a retryable message
/// on failure, and [builder] once data has arrived.
class ApiSection<T> extends StatelessWidget {
  const ApiSection({
    super.key,
    required this.state,
    required this.onRetry,
    required this.builder,
    this.loadingHeight = 180,
  });

  final Loadable<T> state;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T value) builder;
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    if (state.hasValue) return builder(context, state.value as T);

    if (state.error != null) {
      return _ErrorBox(message: state.error!, onRetry: onRetry);
    }

    return SizedBox(
      height: loadingHeight,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.cloud_off_rounded,
                size: 20,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
