/// Modelo que representa uma oferta de jogo retornada pela API CheapShark.
class DealModel {
  /// Identificador único da oferta na CheapShark.
  final String dealID;

  /// Título do jogo em promoção.
  final String title;

  /// Preço promocional atual em dólar (USD).
  final double salePrice;

  /// Preço cheio original em dólar (USD).
  final double normalPrice;

  /// Percentual de desconto calculado pela API (0 a 100).
  final double savings;

  /// Pontuação no Metacritic (0 quando não informada).
  final int metacriticScore;

  /// URL da miniatura/capa oficial da oferta.
  final String thumb;

  const DealModel({
    required this.dealID,
    required this.title,
    required this.salePrice,
    required this.normalPrice,
    required this.savings,
    required this.metacriticScore,
    required this.thumb,
  });

  /// Converte um mapa JSON da API CheapShark ou do cache local em [DealModel].
  factory DealModel.fromJson(Map<String, dynamic> json) {
    final dealId = (json['dealID'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();

    if (dealId.isEmpty || title.isEmpty) {
      throw const FormatException(
        'Oferta inválida: dealID e title são obrigatórios.',
      );
    }

    return DealModel(
      dealID: dealId,
      title: title,
      salePrice: _parseDouble(json['salePrice']),
      normalPrice: _parseDouble(json['normalPrice']),
      savings: _parseDouble(json['savings']),
      metacriticScore: _parseInt(json['metacriticScore']),
      thumb: (json['thumb'] ?? '').toString().trim(),
    );
  }

  /// Converte a oferta para JSON para persistência em cache local.
  Map<String, dynamic> toJson() {
    return {
      'dealID': dealID,
      'title': title,
      'salePrice': salePrice,
      'normalPrice': normalPrice,
      'savings': savings,
      'metacriticScore': metacriticScore,
      'thumb': thumb,
    };
  }

  /// Percentual de desconto arredondado para exibição em badge.
  int get discountPercent => savings.round().clamp(0, 100);

  /// URL de redirecionamento oficial da oferta na loja parceira.
  String get storeRedirectUrl =>
      'https://www.cheapshark.com/redirect?dealID=$dealID';

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? (double.tryParse(value)?.round() ?? 0);
    }
    return 0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DealModel &&
        other.dealID == dealID &&
        other.title == title &&
        other.salePrice == salePrice &&
        other.normalPrice == normalPrice &&
        other.savings == savings &&
        other.metacriticScore == metacriticScore &&
        other.thumb == thumb;
  }

  @override
  int get hashCode => Object.hash(
    dealID,
    title,
    salePrice,
    normalPrice,
    savings,
    metacriticScore,
    thumb,
  );
}
