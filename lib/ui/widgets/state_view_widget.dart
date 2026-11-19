import 'package:flutter/material.dart';

import '../../core/state/ui_state.dart';

/// Widget reutilizável que renderiza os estados [Loading], [Error], [Empty] e [Success].
class StateViewWidget<T> extends StatelessWidget {
  /// Estado atual fornecido pelo ViewModel.
  final UiState<T> state;

  /// Construtor chamado quando o estado é [Success].
  final Widget Function(
    BuildContext context,
    T data,
    bool isFromCache,
    DateTime? lastUpdated,
  )
  onSuccess;

  /// Callback acionado ao tocar em *"Tentar novamente"* no estado [Error].
  final VoidCallback? onRetry;

  /// Texto opcional exibido abaixo do indicador de progresso no estado [Loading].
  final String? loadingMessage;

  /// Título opcional exibido no estado [Empty].
  final String? emptyTitle;

  /// Ícone ilustrativo exibido no estado [Empty].
  final IconData emptyIcon;

  const StateViewWidget({
    super.key,
    required this.state,
    required this.onSuccess,
    this.onRetry,
    this.loadingMessage,
    this.emptyTitle,
    this.emptyIcon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (state) {
      Loading<T>() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (loadingMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  loadingMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      Error<T>(:final message, :final canRetry) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Não foi possível carregar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (canRetry && onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      ),
      Empty<T>(:final message) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 56, color: theme.colorScheme.secondary),
              if (emptyTitle != null) ...[
                const SizedBox(height: 16),
                Text(
                  emptyTitle!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      Success<T>(:final data, :final isFromCache, :final lastUpdated) =>
        onSuccess(context, data, isFromCache, lastUpdated),
    };
  }
}
