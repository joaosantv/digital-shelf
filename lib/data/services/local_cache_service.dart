import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/backlog_game_model.dart';
import '../models/deal_model.dart';

/// Serviço de cache local em JSON utilizando [SharedPreferences].
class LocalCacheService {
  static const String _dealsJsonKey = 'cached_deals_json';
  static const String _dealsUpdatedAtKey = 'cached_deals_updated_at';
  static const String _dealsQueryKey = 'cached_deals_query';
  static const String _backlogJsonPrefix = 'cached_backlog_json_';
  static const String _backlogUpdatedAtPrefix = 'cached_backlog_updated_at_';

  SharedPreferences? _preferences;

  LocalCacheService({this._preferences});

  Future<SharedPreferences> _getPrefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  /// Salva a última lista de ofertas pesquisadas e o instante da sincronização.
  Future<void> saveDeals(
    List<DealModel> deals, {
    String query = '',
    DateTime? syncedAt,
  }) async {
    final prefs = await _getPrefs();
    final encoded = jsonEncode(deals.map((deal) => deal.toJson()).toList());
    final timestamp = (syncedAt ?? DateTime.now()).toIso8601String();

    await prefs.setString(_dealsJsonKey, encoded);
    await prefs.setString(_dealsUpdatedAtKey, timestamp);
    await prefs.setString(_dealsQueryKey, query);
  }

  /// Recupera as últimas ofertas salvas em cache local, se disponíveis.
  Future<({List<DealModel> deals, DateTime? lastUpdated, String query})?>
  getCachedDeals() async {
    final prefs = await _getPrefs();
    final rawJson = prefs.getString(_dealsJsonKey);
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return null;

      final deals = decoded
          .whereType<Map>()
          .map((item) => DealModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      final rawTimestamp = prefs.getString(_dealsUpdatedAtKey);
      final lastUpdated = rawTimestamp != null
          ? DateTime.tryParse(rawTimestamp)
          : null;
      final query = prefs.getString(_dealsQueryKey) ?? '';

      return (deals: deals, lastUpdated: lastUpdated, query: query);
    } on FormatException {
      return null;
    }
  }

  /// Salva a estante de jogos do usuário [ownerId] no cache local.
  Future<void> saveBacklogGames(
    String ownerId,
    List<BacklogGameModel> games, {
    DateTime? syncedAt,
  }) async {
    if (ownerId.trim().isEmpty) return;

    final prefs = await _getPrefs();
    final encoded = jsonEncode(games.map((game) => game.toJson()).toList());
    final timestamp = (syncedAt ?? DateTime.now()).toIso8601String();

    await prefs.setString('$_backlogJsonPrefix$ownerId', encoded);
    await prefs.setString('$_backlogUpdatedAtPrefix$ownerId', timestamp);
  }

  /// Recupera a estante em cache pertencente ao usuário [ownerId].
  Future<({List<BacklogGameModel> games, DateTime? lastUpdated})?>
  getCachedBacklogGames(String ownerId) async {
    if (ownerId.trim().isEmpty) return null;

    final prefs = await _getPrefs();
    final rawJson = prefs.getString('$_backlogJsonPrefix$ownerId');
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return null;

      final games = decoded
          .whereType<Map>()
          .map(
            (item) =>
                BacklogGameModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((game) => game.ownerId == ownerId)
          .toList();

      final rawTimestamp = prefs.getString('$_backlogUpdatedAtPrefix$ownerId');
      final lastUpdated = rawTimestamp != null
          ? DateTime.tryParse(rawTimestamp)
          : null;

      return (games: games, lastUpdated: lastUpdated);
    } on FormatException {
      return null;
    }
  }

  /// Remove o cache da estante associado ao usuário [ownerId].
  Future<void> clearBacklogCache(String ownerId) async {
    if (ownerId.trim().isEmpty) return;
    final prefs = await _getPrefs();
    await prefs.remove('$_backlogJsonPrefix$ownerId');
    await prefs.remove('$_backlogUpdatedAtPrefix$ownerId');
  }
}
