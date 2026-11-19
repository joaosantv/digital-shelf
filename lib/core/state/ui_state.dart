/// Estados de interface tipados e exaustivos para o padrão MVVM.
sealed class UiState<T> {
  const UiState();
}

/// Estado exibido enquanto uma operação assíncrona está em andamento.
final class Loading<T> extends UiState<T> {
  const Loading();
}

/// Estado que representa dados carregados com sucesso (online ou em cache).
final class Success<T> extends UiState<T> {
  /// Dados retornados pela operação.
  final T data;

  /// Indica se os dados foram recuperados do cache local offline.
  final bool isFromCache;

  /// Momento da última sincronização conhecida dos dados.
  final DateTime? lastUpdated;

  const Success(this.data, {this.isFromCache = false, this.lastUpdated});
}

/// Estado exibido quando a consulta foi concluída sem retornar registros.
final class Empty<T> extends UiState<T> {
  /// Mensagem amigável explicando a ausência de resultados.
  final String message;

  const Empty([this.message = 'Nenhum item encontrado.']);
}

/// Estado exibido quando ocorre falha recuperável ou impeditiva.
final class Error<T> extends UiState<T> {
  /// Mensagem clara em português para orientação do usuário.
  final String message;

  /// Define se a interface deve oferecer ação de nova tentativa.
  final bool canRetry;

  const Error(this.message, {this.canRetry = true});
}
