import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'capture_entry.dart';
import 'capture_store.dart';

const _captureRequestIdKey = 'dioCaptureViewerRequestId';
const _captureStopwatchKey = 'dioCaptureViewerStopwatch';

typedef CaptureLogger =
    void Function(Object error, StackTrace stackTrace, String message);

/// Captures Dio traffic and sends it to a [CaptureStore].
class CaptureInterceptor extends Interceptor {
  CaptureInterceptor(this._store, {CaptureLogger? logger}) : _logger = logger;

  final CaptureStore _store;
  final CaptureLogger? _logger;
  int _sequence = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_store.isCaptureEnabled) {
      handler.next(options);
      return;
    }

    try {
      final requestId = _nextRequestId();
      final stopwatch = Stopwatch()..start();
      options.extra[_captureRequestIdKey] = requestId;
      options.extra[_captureStopwatchKey] = stopwatch;
      _store.addEntry(
        CaptureEntry(
          id: requestId,
          method: options.method,
          url: options.uri.toString(),
          headers: _sanitizeHeaders(options.headers),
          requestData: _safePayload(options.data),
          queryParameters: _safeMap(options.queryParameters),
          timestamp: DateTime.now(),
        ),
      );
    } catch (error, stackTrace) {
      _log(error, stackTrace, 'Failed to record Dio capture request');
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_store.isCaptureEnabled) {
      handler.next(response);
      return;
    }

    final duration = _elapsedDuration(response.requestOptions);
    _updateEntry(
      response.requestOptions,
      statusCode: response.statusCode,
      responseData: _safePayload(
        response.data,
        contentType: response.headers.value(Headers.contentTypeHeader),
      ),
      duration: duration,
    );
    handler.next(response);
  }

  @override
  // Dio 5.0 uses DioError; newer Dio 5.x keeps it as a deprecated typedef.
  // Use the older name here so this package works across the whole 5.x range.
  // ignore: deprecated_member_use
  void onError(DioError err, ErrorInterceptorHandler handler) {
    if (!_store.isCaptureEnabled) {
      handler.next(err);
      return;
    }

    final duration = _elapsedDuration(err.requestOptions);
    _updateEntry(
      err.requestOptions,
      statusCode: err.response?.statusCode,
      responseData: _safePayload(
        err.response?.data,
        contentType: err.response?.headers.value(Headers.contentTypeHeader),
      ),
      errorMessage: err.message ?? err.error?.toString(),
      duration: duration,
    );
    handler.next(err);
  }

  void _updateEntry(
    RequestOptions options, {
    int? statusCode,
    Object? responseData,
    String? errorMessage,
    Duration? duration,
  }) {
    if (!_store.isCaptureEnabled) {
      return;
    }

    try {
      final requestId = options.extra[_captureRequestIdKey] as String?;
      if (requestId == null) {
        return;
      }
      _store.updateEntry(
        requestId,
        statusCode: statusCode,
        responseData: responseData,
        errorMessage: errorMessage,
        duration: duration,
      );
    } catch (error, stackTrace) {
      _log(error, stackTrace, 'Failed to update Dio capture request');
    }
  }

  Duration? _elapsedDuration(RequestOptions options) {
    final stopwatch = options.extra[_captureStopwatchKey];
    if (stopwatch is! Stopwatch) {
      return null;
    }
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  String _nextRequestId() {
    _sequence += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      final lowerKey = key.toLowerCase();
      if (lowerKey == 'authorization' ||
          lowerKey == 'cookie' ||
          lowerKey == 'set-cookie' ||
          lowerKey.contains('token')) {
        return MapEntry(key, '<redacted>');
      }
      return MapEntry(key, value);
    });
  }

  Map<String, dynamic>? _safeMap(Map<String, dynamic> value) {
    if (value.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(value);
  }

  Object? _safePayload(Object? value, {String? contentType}) {
    if (value == null) {
      return null;
    }

    if (_isFileContentType(contentType)) {
      return _filePlaceholder(contentType: contentType, value: value);
    }

    if (value is FormData) {
      return <String, Object>{
        'fields': value.fields
            .map((entry) => <String, String>{entry.key: entry.value})
            .toList(growable: false),
        'files': value.files
            .map(
              (entry) => <String, Object?>{
                'field': entry.key,
                'filename': entry.value.filename,
                'length': entry.value.length,
                'content': _filePlaceholder(
                  filename: entry.value.filename,
                  contentType: entry.value.contentType?.toString(),
                  length: entry.value.length,
                ),
              },
            )
            .toList(growable: false),
      };
    }

    if (value is Map ||
        value is Iterable ||
        value is String ||
        value is num ||
        value is bool) {
      return value;
    }

    return value.toString();
  }

  bool _isFileContentType(String? contentType) {
    if (contentType == null) {
      return false;
    }
    final normalized = contentType.toLowerCase();
    return normalized.startsWith('image/') ||
        normalized.startsWith('video/') ||
        normalized.startsWith('audio/') ||
        normalized == 'application/octet-stream' ||
        normalized == 'application/pdf' ||
        normalized.contains('zip') ||
        normalized.contains('multipart/form-data');
  }

  String _filePlaceholder({
    String? filename,
    String? contentType,
    Object? value,
    int? length,
  }) {
    final parts = <String>[];
    if (filename != null && filename.isNotEmpty) {
      parts.add(filename);
    }
    if (contentType != null && contentType.isNotEmpty) {
      parts.add(contentType.split(';').first.trim());
    }
    final byteLength = length ?? _byteLength(value);
    if (byteLength != null) {
      parts.add(_formatBytes(byteLength));
    }
    if (parts.isEmpty) {
      parts.add('file content');
    }
    return '[${parts.join(', ')}]';
  }

  int? _byteLength(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is List<int>) {
      return value.length;
    }
    if (value is String) {
      return value.length;
    }
    return null;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  void _log(Object error, StackTrace stackTrace, String message) {
    final logger = _logger;
    if (logger != null) {
      logger(error, stackTrace, message);
      return;
    }
    developer.log(
      message,
      name: 'dio_capture_viewer',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
