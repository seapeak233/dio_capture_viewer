import 'dart:convert';

import 'capture_entry.dart';

/// Builds a shell-ready curl command from a captured request entry.
String buildCurlCommand(CaptureEntry entry) {
  final options = <String>['curl'];
  final protocol = entry.protocol;
  final method = _effectiveMethod(entry);
  final headers = _normalizedHeaders(entry.headers, protocol);
  final body = _bodyCommandParts(entry.requestData);

  if (protocol == CaptureProtocol.sse ||
      protocol == CaptureProtocol.webSocket) {
    options.add('-N');
  }

  if (_shouldWriteMethod(method, protocol)) {
    options
      ..add('-X')
      ..add(method);
  }

  if (protocol == CaptureProtocol.sse && !_hasHeader(headers, 'accept')) {
    headers.add(const _CurlHeader('Accept', 'text/event-stream'));
  }

  if (body.usesJsonBody && !_hasHeader(headers, 'content-type')) {
    headers.add(const _CurlHeader('Content-Type', 'application/json'));
  }

  for (final header in headers) {
    options
      ..add('-H')
      ..add('${header.name}: ${header.value}');
  }

  options.addAll(body.parts);
  options.add(_urlWithQueryParameters(entry.url, entry.queryParameters));

  return _formatCommand(options);
}

String _effectiveMethod(CaptureEntry entry) {
  final method = entry.method.trim().toUpperCase();
  return switch (entry.protocol) {
    CaptureProtocol.sse => method == 'SSE' ? 'GET' : method,
    CaptureProtocol.webSocket => 'GET',
    CaptureProtocol.http => method,
  };
}

bool _shouldWriteMethod(String method, CaptureProtocol protocol) {
  if (protocol == CaptureProtocol.webSocket) {
    return false;
  }
  if (protocol == CaptureProtocol.sse && method == 'GET') {
    return false;
  }
  return method.isNotEmpty && method != 'GET';
}

List<_CurlHeader> _normalizedHeaders(
  Map<String, dynamic>? headers,
  CaptureProtocol protocol,
) {
  if (headers == null || headers.isEmpty) {
    return <_CurlHeader>[];
  }

  final result = <_CurlHeader>[];
  for (final entry in headers.entries) {
    final name = entry.key.trim();
    final value = entry.value;
    if (name.isEmpty || value == null || _shouldSkipHeader(name, protocol)) {
      continue;
    }
    result.add(_CurlHeader(name, _headerValueText(value)));
  }
  return result;
}

bool _shouldSkipHeader(String name, CaptureProtocol protocol) {
  final lowerName = name.toLowerCase();
  if (lowerName == 'content-length') {
    return true;
  }
  if (protocol == CaptureProtocol.webSocket) {
    return lowerName == 'connection' ||
        lowerName == 'upgrade' ||
        lowerName == 'sec-websocket-key' ||
        lowerName == 'sec-websocket-version' ||
        lowerName == 'sec-websocket-extensions';
  }
  return false;
}

String _headerValueText(Object value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).join(', ');
  }
  return value.toString();
}

bool _hasHeader(List<_CurlHeader> headers, String name) {
  final lowerName = name.toLowerCase();
  return headers.any((header) => header.name.toLowerCase() == lowerName);
}

_CurlBodyParts _bodyCommandParts(Object? data) {
  if (_isEmptyPayload(data)) {
    return const _CurlBodyParts(<String>[], usesJsonBody: false);
  }
  if (data is Map && _isCapturedFormData(data)) {
    return _formCommandParts(data);
  }

  final body = _requestBodyText(data!);
  return _CurlBodyParts(<String>[
    '--data-raw',
    body,
  ], usesJsonBody: _isJson(data));
}

bool _isCapturedFormData(Map<Object?, Object?> data) {
  return data['fields'] is Iterable || data['files'] is Iterable;
}

_CurlBodyParts _formCommandParts(Map<Object?, Object?> data) {
  final parts = <String>[];
  final fields = data['fields'];
  if (fields is Iterable) {
    for (final field in fields) {
      if (field is Map) {
        for (final entry in field.entries) {
          parts
            ..add('--form-string')
            ..add('${entry.key}=${entry.value}');
        }
      }
    }
  }

  final files = data['files'];
  if (files is Iterable) {
    for (final file in files) {
      if (file is Map) {
        final field = file['field']?.toString();
        final filename = file['filename']?.toString();
        if (field == null || field.isEmpty) {
          continue;
        }
        parts
          ..add('--form')
          ..add(
            '$field=@${filename == null || filename.isEmpty ? '<file>' : filename}',
          );
      }
    }
  }

  return _CurlBodyParts(parts, usesJsonBody: false);
}

String _requestBodyText(Object data) {
  if (data is String) {
    return data;
  }
  if (_isJson(data)) {
    return jsonEncode(data);
  }
  return data.toString();
}

bool _isJson(Object? data) {
  return data is Map || data is Iterable || data is num || data is bool;
}

bool _isEmptyPayload(Object? data) {
  if (data == null) {
    return true;
  }
  if (data is String) {
    return data.trim().isEmpty;
  }
  if (data is Map) {
    return data.isEmpty;
  }
  if (data is Iterable) {
    return data.isEmpty;
  }
  return false;
}

String _urlWithQueryParameters(
  String url,
  Map<String, dynamic>? queryParameters,
) {
  if (queryParameters == null || queryParameters.isEmpty || url.contains('?')) {
    return url;
  }

  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    return url;
  }

  final normalizedQuery = <String, String>{};
  for (final entry in queryParameters.entries) {
    if (entry.value == null) {
      continue;
    }
    normalizedQuery[entry.key] = entry.value.toString();
  }
  if (normalizedQuery.isEmpty) {
    return url;
  }

  return uri.replace(queryParameters: normalizedQuery).toString();
}

String _formatCommand(List<String> parts) {
  if (parts.length == 1) {
    return parts.single;
  }
  final buffer = StringBuffer(parts.first);
  for (final part in parts.skip(1)) {
    buffer
      ..write(' \\')
      ..write('\n  ')
      ..write(_shellQuote(part));
  }
  return buffer.toString();
}

String _shellQuote(String value) {
  if (value.isEmpty) {
    return "''";
  }
  if (RegExp(r'^[A-Za-z0-9_./:=+-]+$').hasMatch(value)) {
    return value;
  }
  return "'${value.replaceAll("'", "'\\''")}'";
}

class _CurlHeader {
  const _CurlHeader(this.name, this.value);

  final String name;
  final String value;
}

class _CurlBodyParts {
  const _CurlBodyParts(this.parts, {required this.usesJsonBody});

  final List<String> parts;
  final bool usesJsonBody;
}
