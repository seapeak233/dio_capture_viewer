/// Captured Dio request/response pair for the in-app network viewer.
class CaptureEntry {
  const CaptureEntry({
    required this.id,
    required this.method,
    required this.url,
    required this.timestamp,
    this.headers,
    this.requestData,
    this.queryParameters,
    this.statusCode,
    this.responseData,
    this.errorMessage,
    this.duration,
  });

  final String id;
  final String method;
  final String url;
  final Map<String, dynamic>? headers;
  final Object? requestData;
  final Map<String, dynamic>? queryParameters;
  final int? statusCode;
  final Object? responseData;
  final String? errorMessage;
  final DateTime timestamp;
  final Duration? duration;

  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;

  bool get isError =>
      errorMessage != null || (statusCode != null && statusCode! >= 400);

  int get requestSize =>
      _payloadSize(headers) +
      _payloadSize(queryParameters) +
      _payloadSize(requestData);

  int get responseSize => _payloadSize(responseData);

  CaptureEntry copyWith({
    int? statusCode,
    Object? responseData,
    String? errorMessage,
    Duration? duration,
  }) {
    return CaptureEntry(
      id: id,
      method: method,
      url: url,
      headers: headers,
      requestData: requestData,
      queryParameters: queryParameters,
      statusCode: statusCode ?? this.statusCode,
      responseData: responseData ?? this.responseData,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp,
      duration: duration ?? this.duration,
    );
  }

  static int _payloadSize(Object? value) {
    if (value == null) {
      return 0;
    }
    return value.toString().length;
  }
}
