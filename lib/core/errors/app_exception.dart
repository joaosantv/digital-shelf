/// Categorias de falhas de domínio tratadas pela aplicação.
enum AppErrorType {
  timeout,
  network,
  server,
  permissionDenied,
  auth,
  validation,
  cache,
}

/// Exceção base de domínio com mensagem amigável e flag de recuperação.
class AppException implements Exception {
  /// Mensagem descritiva para exibição segura na camada de interface.
  final String message;

  /// Classificação semântica do erro.
  final AppErrorType type;

  /// Indica se o usuário pode tentar repetir a operação.
  final bool canRetry;

  const AppException(this.message, {required this.type, this.canRetry = true});

  @override
  String toString() => 'AppException($type): $message';
}

/// Erro lançado quando uma requisição excede o tempo limite configurado.
class TimeoutAppException extends AppException {
  const TimeoutAppException([
    super.message = 'O serviço demorou para responder. Verifique sua conexão e tente novamente.',
  ]) : super(type: AppErrorType.timeout, canRetry: true);
}

/// Erro lançado quando não há conectividade ou ocorre falha de transporte.
class NetworkAppException extends AppException {
  const NetworkAppException([
    super.message =
        'Sem conexão com a internet. Não foi possível contatar o servidor.',
  ]) : super(type: AppErrorType.network, canRetry: true);
}

/// Erro lançado quando o servidor retorna status inválido ou JSON corrompido.
class ServerAppException extends AppException {
  const ServerAppException([
    super.message = 'O servidor retornou uma resposta inesperada. Tente novamente em instantes.',
  ]) : super(type: AppErrorType.server, canRetry: true);
}

/// Erro lançado quando o usuário nega ou bloqueia uma permissão nativa.
class PermissionDeniedAppException extends AppException {
  const PermissionDeniedAppException([
    super.message = 'Permissão negada para acessar câmera ou galeria. Você pode continuar usando a capa padrão.',
  ]) : super(type: AppErrorType.permissionDenied, canRetry: false);
}

/// Erro lançado durante autenticação, cadastro ou validação de sessão.
class AuthAppException extends AppException {
  const AuthAppException([
    super.message = 'Não foi possível autenticar sua conta. Confira os dados.',
  ]) : super(type: AppErrorType.auth, canRetry: false);
}

/// Erro lançado quando dados de entrada violam regras de negócio.
class ValidationAppException extends AppException {
  const ValidationAppException([
    super.message = 'Os dados informados são inválidos.',
  ]) : super(type: AppErrorType.validation, canRetry: false);
}

/// Erro lançado em falhas ao ler ou gravar o cache local.
class CacheAppException extends AppException {
  const CacheAppException([
    super.message = 'Não foi possível acessar o cache local do dispositivo.',
  ]) : super(type: AppErrorType.cache, canRetry: false);
}
