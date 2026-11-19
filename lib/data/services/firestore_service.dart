import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../models/backlog_game_model.dart';

/// Contrato de persistência remota para a coleção `backlog_games`.
abstract class FirestoreService {
  /// Lista os jogos da estante pertencentes exclusivamente a [ownerId].
  Future<List<BacklogGameModel>> getBacklogGames(String ownerId);

  /// Cria um novo jogo associado ao proprietário [BacklogGameModel.ownerId].
  Future<BacklogGameModel> createBacklogGame(BacklogGameModel game);

  /// Atualiza um jogo existente garantindo correspondência de [ownerId].
  Future<BacklogGameModel> updateBacklogGame(BacklogGameModel game);

  /// Remove o documento [gameId] pertencente a [ownerId].
  Future<void> deleteBacklogGame({
    required String gameId,
    required String ownerId,
  });
}

/// Implementação conectada ao Cloud Firestore (produção ou Emulator).
class FirebaseFirestoreService implements FirestoreService {
  static const String _collectionName = 'backlog_games';
  static const Duration defaultTimeout = Duration(seconds: 8);

  final FirebaseFirestore _firestore;
  final Duration _timeout;

  FirebaseFirestoreService({
    FirebaseFirestore? firestore,
    this._timeout = defaultTimeout,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  @override
  Future<List<BacklogGameModel>> getBacklogGames(String ownerId) async {
    if (ownerId.trim().isEmpty) {
      throw const AuthAppException('Usuário não autenticado.');
    }

    try {
      final snapshot = await _collection
          .where('ownerId', isEqualTo: ownerId)
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);

      final games = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        final rawUpdatedAt = data['updatedAt'];
        if (rawUpdatedAt is Timestamp) {
          data['updatedAt'] = rawUpdatedAt.toDate();
        }
        return BacklogGameModel.fromJson(data, id: doc.id);
      }).toList();

      games.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return games;
    } on TimeoutException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw const TimeoutAppException(
        'Tempo limite excedido ao consultar o Firestore. Verifique a conexão ou o emulador.',
      );
    } on FirebaseException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw _mapFirestoreException(e);
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw ServerAppException('Erro ao consultar o Firestore: $e');
    }
  }

  @override
  Future<BacklogGameModel> createBacklogGame(BacklogGameModel game) async {
    if (game.ownerId.trim().isEmpty) {
      throw const AuthAppException('Usuário não autenticado.');
    }

    try {
      final payload = game.toFirestore();
      if (game.id.trim().isEmpty) {
        final docRef = await _firestore
            .collection(_collectionName)
            .add(payload)
            .timeout(_timeout);
        return game.copyWith(id: docRef.id);
      }

      final docRef = _collection.doc(game.id.trim());
      await docRef.set(payload).timeout(_timeout);
      return game.copyWith(id: docRef.id);
    } on TimeoutException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw const TimeoutAppException(
        'Tempo limite excedido ao salvar o jogo no Firestore.',
      );
    } on FirebaseException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw _mapFirestoreException(e);
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw ServerAppException('Erro ao salvar o jogo no Firestore: $e');
    }
  }

  @override
  Future<BacklogGameModel> updateBacklogGame(BacklogGameModel game) async {
    if (game.ownerId.trim().isEmpty) {
      throw const AuthAppException('Usuário não autenticado.');
    }
    if (game.id.trim().isEmpty) {
      throw const ValidationAppException(
        'Identificador do jogo obrigatório para atualização.',
      );
    }

    try {
      await _collection
          .doc(game.id.trim())
          .update(game.toFirestore())
          .timeout(_timeout);
      return game;
    } on TimeoutException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw const TimeoutAppException(
        'Tempo limite excedido ao atualizar o jogo no Firestore.',
      );
    } on FirebaseException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw _mapFirestoreException(e);
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw ServerAppException('Erro ao atualizar o jogo no Firestore: $e');
    }
  }

  @override
  Future<void> deleteBacklogGame({
    required String gameId,
    required String ownerId,
  }) async {
    if (ownerId.trim().isEmpty) {
      throw const AuthAppException('Usuário não autenticado.');
    }
    if (gameId.trim().isEmpty) {
      throw const ValidationAppException('Identificador do jogo inválido.');
    }

    try {
      await _collection.doc(gameId.trim()).delete().timeout(_timeout);
    } on TimeoutException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw const TimeoutAppException(
        'Tempo limite excedido ao excluir o jogo no Firestore.',
      );
    } on FirebaseException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw _mapFirestoreException(e);
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      throw ServerAppException('Erro ao excluir o jogo no Firestore: $e');
    }
  }

  AppException _mapFirestoreException(FirebaseException error) {
    final details = error.message?.trim();
    final suffix = (details != null && details.isNotEmpty) ? ' ($details)' : '';

    switch (error.code) {
      case 'permission-denied':
        return PermissionDeniedAppException(
          'Acesso negado pelas regras de segurança do Firestore$suffix.',
        );
      case 'not-found':
        return ServerAppException(
          'Jogo não encontrado na estante remota$suffix.',
        );
      case 'deadline-exceeded':
        return TimeoutAppException(
          'Tempo limite excedido ao sincronizar com o Firestore$suffix.',
        );
      case 'unavailable':
        return NetworkAppException('Firestore indisponível no momento$suffix.');
      default:
        return ServerAppException(
          'Erro ao sincronizar dados com o Firestore (${error.code})$suffix.',
        );
    }
  }
}

/// Implementação em memória com isolamento estrito por `ownerId`.
class InMemoryFirestoreService implements FirestoreService {
  final Map<String, BacklogGameModel> _storage = {};
  int _counter = 1;

  /// Quando verdadeiro, simula indisponibilidade de rede nas consultas remotas.
  bool simulateOffline = false;

  @override
  Future<List<BacklogGameModel>> getBacklogGames(String ownerId) async {
    if (simulateOffline) {
      throw const NetworkAppException(
        'Modo offline ativo. Não foi possível contatar o Firestore.',
      );
    }

    final games =
        _storage.values.where((game) => game.ownerId == ownerId).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return games;
  }

  @override
  Future<BacklogGameModel> createBacklogGame(BacklogGameModel game) async {
    if (simulateOffline) {
      throw const NetworkAppException(
        'Sem conexão para salvar o jogo na nuvem.',
      );
    }

    final resolvedId = game.id.trim().isEmpty
        ? 'game-${_counter++}'
        : game.id.trim();
    final created = game.copyWith(id: resolvedId);
    _storage[resolvedId] = created;
    return created;
  }

  @override
  Future<BacklogGameModel> updateBacklogGame(BacklogGameModel game) async {
    if (simulateOffline) {
      throw const NetworkAppException(
        'Sem conexão para atualizar o jogo na nuvem.',
      );
    }

    final existing = _storage[game.id];
    if (existing == null) {
      throw const ServerAppException('Jogo não encontrado na estante.');
    }
    if (existing.ownerId != game.ownerId) {
      throw const PermissionDeniedAppException(
        'Você não tem permissão para alterar este jogo.',
      );
    }

    _storage[game.id] = game;
    return game;
  }

  @override
  Future<void> deleteBacklogGame({
    required String gameId,
    required String ownerId,
  }) async {
    if (simulateOffline) {
      throw const NetworkAppException(
        'Sem conexão para excluir o jogo na nuvem.',
      );
    }

    final existing = _storage[gameId];
    if (existing == null) return;
    if (existing.ownerId != ownerId) {
      throw const PermissionDeniedAppException(
        'Você não tem permissão para excluir este jogo.',
      );
    }

    _storage.remove(gameId);
  }
}
