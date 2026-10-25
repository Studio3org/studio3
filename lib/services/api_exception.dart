class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.ambiguous = false});

  final String message;
  final int? statusCode;

  /// True when we genuinely don't know whether the server received/committed
  /// the request (a timeout or connection error, never a real response) —
  /// as opposed to a definitive rejection (a real HTTP response came back,
  /// even an error one). A caller retrying after an ambiguous failure risks
  /// duplicating a write that actually already succeeded.
  final bool ambiguous;

  @override
  String toString() => message;
}
