/// Captured Dio request/response pair for the in-app network viewer.
enum CaptureProtocol { http, sse, webSocket }

enum CaptureState { pending, open, closed, success, error }

enum CaptureMessageDirection { inbound, outbound, internal }

enum CaptureMessageType { message, event, open, close, error }

/// Captured SSE event, WebSocket frame, or stream lifecycle message.
class CaptureMessage {
  const CaptureMessage({
    required this.direction,
    required this.type,
    required this.timestamp,
    this.data,
    this.label,
  });

  final CaptureMessageDirection direction;
  final CaptureMessageType type;
  final DateTime timestamp;
  final Object? data;
  final String? label;
}

/// Captured network entry for the in-app network viewer.
class CaptureEntry {
  const CaptureEntry({
    required this.id,
    required this.method,
    required this.url,
    required this.timestamp,
    this.protocol = CaptureProtocol.http,
    this.state = CaptureState.pending,
    this.headers,
    this.requestData,
    this.queryParameters,
    this.statusCode,
    this.responseData,
    this.errorMessage,
    this.duration,
    this.messages = const <CaptureMessage>[],
    this.closedAt,
  });

  final String id;
  final String method;
  final String url;
  final CaptureProtocol protocol;
  final CaptureState state;
  final Map<String, dynamic>? headers;
  final Object? requestData;
  final Map<String, dynamic>? queryParameters;
  final int? statusCode;
  final Object? responseData;
  final String? errorMessage;
  final DateTime timestamp;
  final Duration? duration;
  final List<CaptureMessage> messages;
  final DateTime? closedAt;

  bool get isSuccess =>
      state == CaptureState.success ||
      (statusCode != null && statusCode! >= 200 && statusCode! < 300);

  bool get isError =>
      state == CaptureState.error ||
      errorMessage != null ||
      (statusCode != null && statusCode! >= 400);

  int get requestSize =>
      _payloadSize(headers) +
      _payloadSize(queryParameters) +
      _payloadSize(requestData);

  int get responseSize =>
      _payloadSize(responseData) +
      messages.fold<int>(0, (total, message) => total + message.size);

  CaptureEntry copyWith({
    CaptureProtocol? protocol,
    CaptureState? state,
    Map<String, dynamic>? headers,
    Object? requestData,
    Map<String, dynamic>? queryParameters,
    int? statusCode,
    Object? responseData,
    String? errorMessage,
    Duration? duration,
    List<CaptureMessage>? messages,
    DateTime? closedAt,
  }) {
    return CaptureEntry(
      id: id,
      method: method,
      url: url,
      protocol: protocol ?? this.protocol,
      state: state ?? this.state,
      headers: headers ?? this.headers,
      requestData: requestData ?? this.requestData,
      queryParameters: queryParameters ?? this.queryParameters,
      statusCode: statusCode ?? this.statusCode,
      responseData: responseData ?? this.responseData,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp,
      duration: duration ?? this.duration,
      messages: messages ?? this.messages,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  static int _payloadSize(Object? value) {
    if (value == null) {
      return 0;
    }
    return value.toString().length;
  }
}

extension on CaptureMessage {
  int get size => CaptureEntry._payloadSize(data) + _payloadSize(label);

  static int _payloadSize(Object? value) {
    if (value == null) {
      return 0;
    }
    return value.toString().length;
  }
}
