import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../models/deal_model.dart';

/// Serviço responsável por consultar ofertas reais de jogos na API CheapShark.
class CheapSharkService {
  static const String _baseHost = 'www.cheapshark.com';
  static const String _dealsPath = '/api/1.0/deals';
  static const Duration defaultTimeout = Duration(seconds: 4);

  final http.Client _client;
  final Duration _timeout;

  CheapSharkService({http.Client? client, this._timeout = defaultTimeout})
    : _client = client ?? http.Client();

  /// Busca até 20 ofertas na API CheapShark para o termo [query] informado.
  ///
  /// Aplica timeout de 4 segundos, valida status HTTP e converte falhas de
  /// rede ou JSON inválido em [AppException].
  Future<List<DealModel>> fetchDeals({String query = ''}) async {
    final trimmedQuery = query.trim();
    final queryParameters = <String, String>{
      'title': trimmedQuery,
      'pageSize': '20',
    };

    final uri = Uri.https(_baseHost, _dealsPath, queryParameters);

    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw ServerAppException(
          'A API CheapShark retornou erro HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const ServerAppException(
          'Formato de resposta inesperado ao consultar promoções.',
        );
      }

      final deals = <DealModel>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          deals.add(DealModel.fromJson(item));
        } else if (item is Map) {
          deals.add(DealModel.fromJson(Map<String, dynamic>.from(item)));
        } else {
          throw const ServerAppException(
            'Item inválido recebido na lista de promoções.',
          );
        }
      }
      return deals;
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const TimeoutAppException(
        'Tempo limite de 4 segundos excedido ao buscar promoções na CheapShark.',
      );
    } on SocketException {
      throw const NetworkAppException(
        'Sem conexão com a internet para buscar promoções.',
      );
    } on http.ClientException {
      throw const NetworkAppException(
        'Falha de comunicação de rede ao consultar promoções.',
      );
    } on FormatException {
      throw const ServerAppException(
        'Não foi possível interpretar os dados retornados pelo servidor.',
      );
    }
  }
}
