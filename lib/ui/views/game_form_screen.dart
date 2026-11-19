import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/backlog_game_model.dart';
import '../../data/services/media_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/backlog_viewmodel.dart';

/// Tela de criação e edição de jogo na estante com anexo opcional de foto.
class GameFormScreen extends StatefulWidget {
  /// Item existente para edição; quando `null`, cria um novo registro.
  final BacklogGameModel? existingGame;

  const GameFormScreen({super.key, this.existingGame});

  @override
  State<GameFormScreen> createState() => _GameFormScreenState();
}

class _GameFormScreenState extends State<GameFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetPriceController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _notesController;

  late String _selectedStatus;
  String? _localPhotoPath;
  String? _photoFeedback;

  bool get _isEditing => widget.existingGame != null;

  @override
  void initState() {
    super.initState();
    final game = widget.existingGame;
    _titleController = TextEditingController(text: game?.title ?? '');
    _targetPriceController = TextEditingController(
      text: game?.targetPrice != null
          ? game!.targetPrice!.toStringAsFixed(2)
          : '',
    );
    _coverUrlController = TextEditingController(text: game?.coverUrl ?? '');
    _notesController = TextEditingController(text: game?.notes ?? '');
    _selectedStatus = game?.status ?? BacklogStatus.queroJogar;
    _localPhotoPath = game?.localPhotoPath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetPriceController.dispose();
    _coverUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(MediaSourceType source) async {
    final backlogVm = context.read<BacklogViewModel>();
    final result = await backlogVm.capturePhoto(source);
    if (!mounted) return;

    setState(() {
      if (result.captured && result.path != null) {
        _localPhotoPath = result.path;
      }
      _photoFeedback = result.feedbackMessage;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.feedbackMessage)));
  }

  void _removeLocalPhoto() {
    setState(() {
      _localPhotoPath = null;
      _photoFeedback = 'Foto local removida. A capa oficial será mantida.';
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final authVm = context.read<AuthViewModel>();
    final backlogVm = context.read<BacklogViewModel>();
    final ownerId = authVm.user?.uid ?? widget.existingGame?.ownerId ?? '';

    final rawPrice = _targetPriceController.text.trim().replaceAll(',', '.');
    final parsedPrice = rawPrice.isEmpty ? null : double.tryParse(rawPrice);

    final game = BacklogGameModel(
      id: widget.existingGame?.id ?? '',
      ownerId: ownerId,
      title: _titleController.text.trim(),
      status: _selectedStatus,
      targetPrice: parsedPrice,
      notes: _notesController.text.trim(),
      coverUrl: _coverUrlController.text.trim(),
      localPhotoPath: _localPhotoPath,
      updatedAt: DateTime.now(),
    );

    final saved = await backlogVm.saveGame(game, isNew: !_isEditing);
    if (!mounted) return;

    final message = backlogVm.lastFeedbackMessage;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }

    if (saved) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backlogVm = context.watch<BacklogViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Jogo' : 'Novo Jogo na Estante'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CoverPreviewCard(
                  localPhotoPath: _localPhotoPath,
                  coverUrl: _coverUrlController.text.trim(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('game_form_camera_button'),
                      onPressed: backlogVm.isMutating
                          ? null
                          : () => _pickPhoto(MediaSourceType.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Câmera'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('game_form_gallery_button'),
                      onPressed: backlogVm.isMutating
                          ? null
                          : () => _pickPhoto(MediaSourceType.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeria'),
                    ),
                    if (_localPhotoPath != null)
                      TextButton.icon(
                        onPressed: backlogVm.isMutating
                            ? null
                            : _removeLocalPhoto,
                        icon: const Icon(Icons.close),
                        label: const Text('Usar capa oficial'),
                      ),
                  ],
                ),
                if (_photoFeedback != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.65,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _photoFeedback!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('game_form_title_field'),
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  enabled: !backlogVm.isMutating,
                  decoration: const InputDecoration(
                    labelText: 'Nome do jogo *',
                    hintText: 'Ex.: Hades II',
                    prefixIcon: Icon(Icons.videogame_asset_outlined),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Informe o nome do jogo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('game_form_status_dropdown'),
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status na estante *',
                    prefixIcon: Icon(Icons.bookmark_outline),
                  ),
                  items: BacklogStatus.values
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: backlogVm.isMutating
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _selectedStatus = value;
                            });
                          }
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('game_form_target_price_field'),
                  controller: _targetPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  enabled: !backlogVm.isMutating,
                  decoration: const InputDecoration(
                    labelText: 'Preço-alvo (US\$)',
                    hintText: 'Ex.: 19.99',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final parsed = double.tryParse(
                      trimmed.replaceAll(',', '.'),
                    );
                    if (parsed == null || parsed < 0) {
                      return 'Informe um valor numérico válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('game_form_cover_url_field'),
                  controller: _coverUrlController,
                  textInputAction: TextInputAction.next,
                  enabled: !backlogVm.isMutating,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'URL da capa oficial (opcional)',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('game_form_notes_field'),
                  controller: _notesController,
                  maxLines: 3,
                  enabled: !backlogVm.isMutating,
                  decoration: const InputDecoration(
                    labelText: 'Anotações e conquistas',
                    hintText: 'Progresso, DLCs, meta de platinar...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('game_form_save_button'),
                  onPressed: backlogVm.isMutating ? null : _save,
                  icon: backlogVm.isMutating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    backlogVm.isMutating ? 'Salvando...' : 'Salvar na Estante',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverPreviewCard extends StatelessWidget {
  final String? localPhotoPath;
  final String coverUrl;

  const _CoverPreviewCard({
    required this.localPhotoPath,
    required this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget preview;
    if (localPhotoPath != null && !kIsWeb) {
      preview = Image.file(
        File(localPhotoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildNetworkOrFallback(theme),
      );
    } else {
      preview = _buildNetworkOrFallback(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: preview,
      ),
    );
  }

  Widget _buildNetworkOrFallback(ThemeData theme) {
    if (coverUrl.isNotEmpty) {
      return Image.network(
        coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultIcon(theme),
      );
    }
    return _defaultIcon(theme);
  }

  Widget _defaultIcon(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sports_esports_rounded,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'Capa padrão do Digital Shelf',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
