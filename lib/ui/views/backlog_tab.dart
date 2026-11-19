import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/backlog_game_model.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/backlog_viewmodel.dart';
import '../widgets/state_view_widget.dart';
import 'game_form_screen.dart';

/// Aba que exibe a estante pessoal do jogador com filtro e ações de CRUD.
class BacklogTab extends StatelessWidget {
  const BacklogTab({super.key});

  Future<void> _openEdit(BuildContext context, BacklogGameModel game) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => GameFormScreen(existingGame: game),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BacklogGameModel game,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remover da estante'),
          content: Text(
            'Deseja remover "${game.title}" da sua estante pessoal?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final authVm = context.read<AuthViewModel>();
    final backlogVm = context.read<BacklogViewModel>();
    final ownerId = authVm.user?.uid ?? game.ownerId;

    await backlogVm.deleteGame(gameId: game.id, ownerId: ownerId);
    if (!context.mounted) return;

    final message = backlogVm.lastFeedbackMessage;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _formatSyncTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return ' • última sinc. $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backlogVm = context.watch<BacklogViewModel>();

    const filters = [BacklogViewModel.filterAll, ...BacklogStatus.values];

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = filters[index];
              return ChoiceChip(
                label: Text(filter),
                selected: backlogVm.statusFilter == filter,
                onSelected: (_) => backlogVm.setStatusFilter(filter),
              );
            },
          ),
        ),
        if (backlogVm.isFromCache)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.offline_pin_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dados em cache (offline)${_formatSyncTime(backlogVm.lastUpdated)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: StateViewWidget<List<BacklogGameModel>>(
            state: backlogVm.filteredState,
            onRetry: backlogVm.retry,
            loadingMessage: 'Carregando sua estante...',
            emptyIcon: Icons.collections_bookmark_outlined,
            emptyTitle: 'Estante sem jogos neste filtro',
            onSuccess: (context, games, isFromCache, lastUpdated) {
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                itemCount: games.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final game = games[index];
                  return _BacklogGameCard(
                    game: game,
                    onEdit: () => _openEdit(context, game),
                    onDelete: () => _confirmDelete(context, game),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BacklogGameCard extends StatelessWidget {
  final BacklogGameModel game;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BacklogGameCard({
    required this.game,
    required this.onEdit,
    required this.onDelete,
  });

  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case BacklogStatus.jogando:
        return theme.colorScheme.primary;
      case BacklogStatus.zerado:
        return AppTheme.successGreen;
      default:
        return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(game.status, theme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BacklogCoverThumb(
              localPhotoPath: game.localPhotoPath,
              coverUrl: game.coverUrl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          game.status,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (game.targetPrice != null)
                        Text(
                          'Alvo: US\$ ${game.targetPrice!.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (game.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      game.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('edit_game_${game.id}'),
                  tooltip: 'Editar',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: Key('delete_game_${game.id}'),
                  tooltip: 'Excluir',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BacklogCoverThumb extends StatelessWidget {
  final String? localPhotoPath;
  final String coverUrl;

  const _BacklogCoverThumb({
    required this.localPhotoPath,
    required this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    if (localPhotoPath != null && !kIsWeb) {
      content = Image.file(
        File(localPhotoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _networkOrDefault(theme),
      );
    } else {
      content = _networkOrDefault(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: 72, height: 72, child: content),
    );
  }

  Widget _networkOrDefault(ThemeData theme) {
    if (coverUrl.isNotEmpty) {
      return Image.network(
        coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultThumb(theme),
      );
    }
    return _defaultThumb(theme);
  }

  Widget _defaultThumb(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.sports_esports_rounded,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
