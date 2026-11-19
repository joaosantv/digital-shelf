/// Status válidos para um jogo na estante pessoal do usuário.
class BacklogStatus {
  BacklogStatus._();

  static const String queroJogar = 'Quero jogar';
  static const String jogando = 'Jogando';
  static const String zerado = 'Zerado';

  /// Lista ordenada dos status aceitos pela interface e pelas regras de segurança.
  static const List<String> values = [queroJogar, jogando, zerado];

  /// Verifica se o status informado pertence ao domínio permitido.
  static bool isValid(String status) => values.contains(status);
}

/// Modelo de jogo salvo na estante/backlog pessoal do jogador.
class BacklogGameModel {
  /// Identificador do documento no Firestore ou armazenamento local.
  final String id;

  /// UID do usuário proprietário do registro.
  final String ownerId;

  /// Nome do jogo.
  final String title;

  /// Status atual na estante (*Quero jogar*, *Jogando* ou *Zerado*).
  final String status;

  /// Preço-alvo desejado pelo usuário (opcional).
  final double? targetPrice;

  /// Anotações pessoais sobre o jogo, progresso ou conquistas.
  final String notes;

  /// URL da capa oficial vinda da API ou preenchida manualmente.
  final String coverUrl;

  /// Caminho local da foto/print anexado pelo usuário (não persistido em logs).
  final String? localPhotoPath;

  /// Data e hora da última atualização do item.
  final DateTime updatedAt;

  const BacklogGameModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    this.targetPrice,
    this.notes = '',
    this.coverUrl = '',
    this.localPhotoPath,
    required this.updatedAt,
  });

  /// Reconstrói [BacklogGameModel] a partir de JSON local ou mapa do Firestore.
  factory BacklogGameModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final resolvedId = (id ?? json['id'] ?? '').toString().trim();
    final ownerId = (json['ownerId'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    final rawStatus = (json['status'] ?? BacklogStatus.queroJogar).toString();
    final status = BacklogStatus.isValid(rawStatus)
        ? rawStatus
        : BacklogStatus.queroJogar;

    final rawTargetPrice = json['targetPrice'];
    double? parsedTargetPrice;
    if (rawTargetPrice is num) {
      parsedTargetPrice = rawTargetPrice.toDouble();
    } else if (rawTargetPrice is String && rawTargetPrice.trim().isNotEmpty) {
      parsedTargetPrice = double.tryParse(rawTargetPrice.trim());
    }

    final rawUpdatedAt = json['updatedAt'];
    DateTime parsedUpdatedAt;
    if (rawUpdatedAt is DateTime) {
      parsedUpdatedAt = rawUpdatedAt;
    } else if (rawUpdatedAt is int) {
      parsedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(rawUpdatedAt);
    } else if (rawUpdatedAt is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt) ?? DateTime.now();
    } else {
      parsedUpdatedAt = DateTime.now();
    }

    final rawLocalPhoto = json['localPhotoPath']?.toString().trim();

    return BacklogGameModel(
      id: resolvedId,
      ownerId: ownerId,
      title: title,
      status: status,
      targetPrice: parsedTargetPrice,
      notes: (json['notes'] ?? '').toString(),
      coverUrl: (json['coverUrl'] ?? '').toString().trim(),
      localPhotoPath: (rawLocalPhoto == null || rawLocalPhoto.isEmpty)
          ? null
          : rawLocalPhoto,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Serializa o modelo completo para armazenamento em cache local.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'title': title,
      'status': status,
      'targetPrice': targetPrice,
      'notes': notes,
      'coverUrl': coverUrl,
      'localPhotoPath': localPhotoPath,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Serializa os campos persistidos na coleção `backlog_games` do Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'title': title,
      'status': status,
      'targetPrice': targetPrice,
      'notes': notes,
      'coverUrl': coverUrl,
      'localPhotoPath': localPhotoPath,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Cria uma cópia alterando apenas os campos informados.
  BacklogGameModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? status,
    double? targetPrice,
    bool clearTargetPrice = false,
    String? notes,
    String? coverUrl,
    String? localPhotoPath,
    bool clearLocalPhotoPath = false,
    DateTime? updatedAt,
  }) {
    return BacklogGameModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      status: status ?? this.status,
      targetPrice: clearTargetPrice ? null : (targetPrice ?? this.targetPrice),
      notes: notes ?? this.notes,
      coverUrl: coverUrl ?? this.coverUrl,
      localPhotoPath: clearLocalPhotoPath
          ? null
          : (localPhotoPath ?? this.localPhotoPath),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BacklogGameModel &&
        other.id == id &&
        other.ownerId == ownerId &&
        other.title == title &&
        other.status == status &&
        other.targetPrice == targetPrice &&
        other.notes == notes &&
        other.coverUrl == coverUrl &&
        other.localPhotoPath == localPhotoPath &&
        other.updatedAt.millisecondsSinceEpoch ==
            updatedAt.millisecondsSinceEpoch;
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    title,
    status,
    targetPrice,
    notes,
    coverUrl,
    localPhotoPath,
    updatedAt.millisecondsSinceEpoch,
  );
}
