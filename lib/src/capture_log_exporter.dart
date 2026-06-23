import 'dart:convert';
import 'dart:typed_data';

import 'capture_entry.dart';
import 'capture_store.dart';

const _jsonLineSchema = 'dio_capture_viewer.jsonl.v1';

/// Prepared export content returned to app code by the viewer export action.
class CaptureExportFile {
  CaptureExportFile({
    required this.fileName,
    required this.mimeType,
    required this.content,
  });

  /// Suggested file name, including extension.
  final String fileName;

  /// MIME type for the exported content.
  final String mimeType;

  /// Text content of the export file.
  final String content;

  /// UTF-8 bytes for integrations that save binary file data.
  Uint8List get bytes => Uint8List.fromList(utf8.encode(content));
}

/// Builds a JSON Lines network log export from the current capture cache.
///
/// The output uses one metadata line followed by one line per captured entry.
/// JSON Lines is easy to import into common log viewers and can still be read
/// line-by-line by lightweight scripts.
CaptureExportFile buildCaptureLogExport(
  CaptureStore store, {
  DateTime? exportedAt,
  String? fileName,
}) {
  final exportTime = exportedAt ?? DateTime.now();
  final entries = store.entries;
  final buffer = StringBuffer();

  void writeLine(Map<String, Object?> value) {
    buffer.writeln(jsonEncode(_jsonSafeValue(value)));
  }

  writeLine({
    'type': 'metadata',
    'schema': _jsonLineSchema,
    'exportedAt': exportTime.toIso8601String(),
    'entryCount': entries.length,
    'stats': {
      'total': store.stats.total,
      'success': store.stats.success,
      'error': store.stats.error,
      'pending': store.stats.pending,
    },
  });

  for (final entry in entries) {
    writeLine(_entryToJson(entry));
  }

  return CaptureExportFile(
    fileName: fileName ?? _defaultExportFileName(exportTime),
    mimeType: 'application/x-ndjson; charset=utf-8',
    content: buffer.toString(),
  );
}

Map<String, Object?> _entryToJson(CaptureEntry entry) {
  final uri = Uri.tryParse(entry.url);
  return {
    'type': 'capture',
    'id': entry.id,
    'protocol': entry.protocol.name,
    'state': entry.state.name,
    'method': entry.method,
    'url': entry.url,
    if (uri != null && uri.host.isNotEmpty) 'host': uri.host,
    if (uri != null) 'path': uri.path.isEmpty ? '/' : uri.path,
    if (uri != null && uri.query.isNotEmpty) 'query': uri.query,
    'statusCode': entry.statusCode,
    'success': entry.isSuccess,
    'error': entry.isError,
    'timestamp': entry.timestamp.toIso8601String(),
    'closedAt': entry.closedAt?.toIso8601String(),
    'durationMs': entry.duration?.inMilliseconds,
    'request': {
      'headers': entry.headers,
      'queryParameters': entry.queryParameters,
      'body': entry.requestData,
      'sizeBytes': entry.requestSize,
    },
    'response': {
      'body': entry.responseData,
      'errorMessage': entry.errorMessage,
      'sizeBytes': entry.responseSize,
    },
    if (entry.messages.isNotEmpty)
      'messages': entry.messages.map(_messageToJson).toList(growable: false),
  };
}

Map<String, Object?> _messageToJson(CaptureMessage message) {
  return {
    'direction': message.direction.name,
    'type': message.type.name,
    'timestamp': message.timestamp.toIso8601String(),
    if (message.label != null) 'label': message.label,
    'data': message.data,
  };
}

Object? _jsonSafeValue(Object? value) {
  if (value == null || value is String || value is bool) {
    return value;
  }
  if (value is num) {
    if (value is double && !value.isFinite) {
      return value.toString();
    }
    return value;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Duration) {
    return value.inMilliseconds;
  }
  if (value is Map) {
    return value.map(
      (key, nestedValue) =>
          MapEntry(key.toString(), _jsonSafeValue(nestedValue)),
    );
  }
  if (value is Iterable) {
    return value.map(_jsonSafeValue).toList(growable: false);
  }
  return value.toString();
}

String _defaultExportFileName(DateTime value) {
  final timestamp = value
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  return 'dio-capture-$timestamp.jsonl';
}
