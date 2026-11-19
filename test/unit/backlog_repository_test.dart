import 'package:digital_shelf/core/errors/app_exception.dart';
import 'package:digital_shelf/data/models/backlog_game_model.dart';
import 'package:digital_shelf/data/repositories/backlog_repository.dart';
import 'package:digital_shelf/data/services/firestore_service.dart';
import 'package:digital_shelf/data/services/local_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFirestoreService implements FirestoreService {
  final Map<String, BacklogGameModel> store = {};
  bool shouldFailWithNetwork = false;
  bool shouldFailWithPermission = false;
  int _nextId = 1;

  @override
  Future<List<BacklogGameModel>> getBacklogGames(String ownerId) async {
    if (shouldFailWithPermission) {
      throw const PermissionDeniedAppException();
    }
    if (shouldFailWithNetwork) {
      throw const NetworkAppException();
    }
    return store.values.where((g) => g.ownerId == ownerId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<BacklogGameModel> createBacklogGame(BacklogGameModel game) async {
    if (shouldFailWithNetwork) {
      throw const NetworkAppException();
    }
    final id = game.id.isEmpty ? 'doc-${_nextId++}' : game.id;
    final created = game.copyWith(id: id);
    store[id] = created;
    return created;
  }

  @override
  Future<BacklogGameModel> updateBacklogGame(BacklogGameModel game) async {
    if (shouldFailWithNetwork) {
      throw const NetworkAppException();
    }
    store[game.id] = game;
    return game;
  }

  @override
  Future<void> deleteBacklogGame({
    required String gameId,
    required String ownerId,
  }) async {
    if (shouldFailWithNetwork) {
      throw const NetworkAppException();
    }
    final existing = store[gameId];
    if (existing != null && existing.ownerId == ownerId) {
      store.remove(gameId);
    }
  }
}

void main() {
  group('BacklogRepository - Sincronização Online e Fallback Cache', () {
    late _FakeFirestoreService firestoreService;
    late LocalCacheService cacheService;
    late BacklogRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      firestoreService = _FakeFirestoreService();
      cacheService = LocalCacheService(preferences: prefs);
      repository = BacklogRepository(
        firestoreService: firestoreService,
        cacheService: cacheService,
      );
    });

    test(
      'busca jogos online, marca isFromCache false e atualiza cache local',
      () async {
        final game = BacklogGameModel(
          id: 'g1',
          ownerId: 'uid-user-a',
          title: 'Hades',
          status: BacklogStatus.jogando,
          targetPrice: 12.50,
          notes: 'Fugindo do Tártaro',
          updatedAt: DateTime(2026, 11, 19, 10, 0),
        );
        firestoreService.store['g1'] = game;

        final result = await repository.getGames('uid-user-a');

        expect(result.isFromCache, isFalse);
        expect(result.games.length, 1);
        expect(result.games.first.title, 'Hades');

        final cached = await cacheService.getCachedBacklogGames('uid-user-a');
        expect(cached, isNotNull);
        expect(cached!.games.length, 1);
        expect(cached.games.first.id, 'g1');
      },
    );

    test(
      'retorna cache local com isFromCache true quando Firestore falha',
      () async {
        final cachedGame = BacklogGameModel(
          id: 'g2',
          ownerId: 'uid-user-a',
          title: 'Hollow Knight',
          status: BacklogStatus.queroJogar,
          updatedAt: DateTime(2026, 11, 19, 9, 30),
        );
        await cacheService.saveBacklogGames('uid-user-a', [cachedGame]);

        firestoreService.shouldFailWithNetwork = true;
        final result = await repository.getGames('uid-user-a');

        expect(result.isFromCache, isTrue);
        expect(result.lastUpdated, isNotNull);
        expect(result.games.single.title, 'Hollow Knight');
      },
    );

    test(
      'propaga AppException quando Firestore falha e cache está vazio',
      () async {
        firestoreService.shouldFailWithNetwork = true;

        await expectLater(
          () => repository.getGames('uid-user-a'),
          throwsA(isA<NetworkAppException>()),
        );
      },
    );

    test(
      'não mascara PermissionDeniedAppException mesmo com cache existente',
      () async {
        final cachedGame = BacklogGameModel(
          id: 'g3',
          ownerId: 'uid-user-a',
          title: 'Celeste',
          status: BacklogStatus.zerado,
          updatedAt: DateTime(2026, 11, 19, 8, 0),
        );
        await cacheService.saveBacklogGames('uid-user-a', [cachedGame]);
        firestoreService.shouldFailWithPermission = true;

        await expectLater(
          () => repository.getGames('uid-user-a'),
          throwsA(isA<PermissionDeniedAppException>()),
        );
      },
    );

    test(
      'mantém cache sincronizado após addGame, updateGame e deleteGame',
      () async {
        final created = await repository.addGame(
          BacklogGameModel(
            id: '',
            ownerId: 'uid-user-a',
            title: 'Dead Cells',
            status: BacklogStatus.queroJogar,
            updatedAt: DateTime.now(),
          ),
        );

        final updated = await repository.updateGame(
          created.copyWith(status: BacklogStatus.zerado),
        );

        var cached = await cacheService.getCachedBacklogGames('uid-user-a');
        expect(cached!.games.single.status, BacklogStatus.zerado);

        await repository.deleteGame(gameId: updated.id, ownerId: 'uid-user-a');

        cached = await cacheService.getCachedBacklogGames('uid-user-a');
        expect(cached!.games, isEmpty);
      },
    );
  });
}
