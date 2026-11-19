import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/backlog_viewmodel.dart';
import '../viewmodels/deals_viewmodel.dart';
import 'backlog_tab.dart';
import 'deals_tab.dart';
import 'game_form_screen.dart';

/// Tela principal autenticada com navegação por abas e indicador de status.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthViewModel>().user?.uid;
      if (uid != null && uid.isNotEmpty) {
        context.read<BacklogViewModel>().loadGames(uid);
      }
    });
  }

  Future<void> _openCreateGame() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const GameFormScreen()),
    );
  }

  Future<void> _logout() async {
    final backlogVm = context.read<BacklogViewModel>();
    final authVm = context.read<AuthViewModel>();
    backlogVm.clearSessionData();
    await authVm.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dealsVm = context.watch<DealsViewModel>();
    final backlogVm = context.watch<BacklogViewModel>();
    final isOfflineCache = dealsVm.isFromCache || backlogVm.isFromCache;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Shelf'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (isOfflineCache
                            ? theme.colorScheme.primary
                            : AppTheme.successGreen)
                        .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOfflineCache
                      ? theme.colorScheme.primary
                      : AppTheme.successGreen,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOfflineCache ? Icons.cloud_off : Icons.cloud_done,
                    size: 14,
                    color: isOfflineCache
                        ? theme.colorScheme.primary
                        : AppTheme.successGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOfflineCache ? 'Offline (Cache)' : 'Online',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isOfflineCache
                          ? theme.colorScheme.primary
                          : AppTheme.successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: const Key('logout_button'),
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [DealsTab(), BacklogTab()],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              key: const Key('add_game_fab'),
              onPressed: _openCreateGame,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Jogo'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Explorar Ofertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Minha Estante',
          ),
        ],
      ),
    );
  }
}
