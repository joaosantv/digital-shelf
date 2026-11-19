import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/deal_model.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/backlog_viewmodel.dart';
import '../viewmodels/deals_viewmodel.dart';
import '../widgets/state_view_widget.dart';

/// Aba de pesquisa e visualização de promoções reais via CheapShark API.
class DealsTab extends StatefulWidget {
  const DealsTab({super.key});

  @override
  State<DealsTab> createState() => _DealsTabState();
}

class _DealsTabState extends State<DealsTab> {
  static const List<String> _quickQueries = [
    'Hades',
    'Witcher',
    'Hollow Knight',
    'Cyberpunk',
  ];

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final initialQuery = context.read<DealsViewModel>().currentQuery;
    _searchController = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch([String? overrideQuery]) async {
    FocusScope.of(context).unfocus();
    final query = overrideQuery ?? _searchController.text;
    if (overrideQuery != null) {
      _searchController.text = overrideQuery;
    }
    await context.read<DealsViewModel>().searchDeals(query);
  }

  Future<void> _saveDeal(DealModel deal) async {
    final authVm = context.read<AuthViewModel>();
    final backlogVm = context.read<BacklogViewModel>();
    final ownerId = authVm.user?.uid ?? '';

    await backlogVm.addDealToBacklog(ownerId: ownerId, deal: deal);
    if (!mounted) return;

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
    final dealsVm = context.watch<DealsViewModel>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('deals_search_field'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performSearch(),
                  decoration: const InputDecoration(
                    hintText: 'Buscar jogo de PC (ex.: Hades, Elden Ring)...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                key: const Key('deals_search_button'),
                onPressed: () => _performSearch(),
                child: const Text('Buscar'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quickQueries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final suggestion = _quickQueries[index];
              return ActionChip(
                label: Text(suggestion),
                onPressed: () => _performSearch(suggestion),
              );
            },
          ),
        ),
        if (dealsVm.isFromCache)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                  Icons.offline_bolt_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dados em cache (offline)${_formatSyncTime(dealsVm.lastUpdated)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: StateViewWidget<List<DealModel>>(
            state: dealsVm.state,
            onRetry: dealsVm.retry,
            loadingMessage: 'Buscando promoções na CheapShark...',
            emptyIcon: Icons.local_offer_outlined,
            emptyTitle: 'Explore ofertas de PC',
            onSuccess: (context, deals, isFromCache, lastUpdated) {
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: deals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final deal = deals[index];
                  return _DealCard(deal: deal, onSave: () => _saveDeal(deal));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DealCard extends StatelessWidget {
  final DealModel deal;
  final VoidCallback onSave;

  const _DealCard({required this.deal, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 96,
                height: 60,
                child: deal.thumb.isNotEmpty
                    ? Image.network(
                        deal.thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _DealThumbFallback(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                      )
                    : _DealThumbFallback(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deal.title,
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
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${deal.discountPercent}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'US\$ ${deal.salePrice.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (deal.normalPrice > deal.salePrice)
                        Text(
                          'US\$ ${deal.normalPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      if (deal.metacriticScore > 0)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          label: Text('MC ${deal.metacriticScore}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      key: Key('save_deal_${deal.dealID}'),
                      onPressed: onSave,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('Salvar na Estante'),
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

class _DealThumbFallback extends StatelessWidget {
  final Color color;

  const _DealThumbFallback({required this.color});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: const Center(child: Icon(Icons.sports_esports_rounded, size: 28)),
    );
  }
}
