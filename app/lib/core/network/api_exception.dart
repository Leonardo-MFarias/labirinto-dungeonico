/// Erro de uma chamada à API com status diferente de 2xx (RNF-06). [message]
/// vem do corpo `{"error": "..."}` que o backend devolve quando presente.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
