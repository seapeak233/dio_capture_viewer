import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_capture_viewer/dio_capture_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture entry defaults to http pending state', () {
    final entry = CaptureEntry(
      id: 'http-1',
      method: 'GET',
      url: 'https://example.com/users',
      timestamp: DateTime(2026),
    );

    expect(entry.protocol, CaptureProtocol.http);
    expect(entry.state, CaptureState.pending);
    expect(entry.messages, isEmpty);
    expect(entry.closedAt, isNull);
  });

  test('capture entry can store stream messages immutably', () {
    final startedAt = DateTime(2026);
    final messageAt = DateTime(2026, 1, 1, 0, 0, 1);
    final entry = CaptureEntry(
      id: 'sse-1',
      method: 'SSE',
      url: 'https://example.com/events',
      protocol: CaptureProtocol.sse,
      state: CaptureState.open,
      timestamp: startedAt,
    );

    final updated = entry.copyWith(
      messages: [
        CaptureMessage(
          direction: CaptureMessageDirection.inbound,
          type: CaptureMessageType.event,
          data: {'event': 'message', 'data': 'hello'},
          timestamp: messageAt,
          label: 'message',
        ),
      ],
    );

    expect(entry.messages, isEmpty);
    expect(updated.messages, hasLength(1));
    expect(updated.messages.single.direction, CaptureMessageDirection.inbound);
    expect(updated.messages.single.type, CaptureMessageType.event);
    expect(updated.messages.single.label, 'message');
    expect(updated.responseSize, greaterThan(0));
  });

  test('builds curl command for json http request', () {
    final entry = CaptureEntry(
      id: 'http-curl',
      method: 'POST',
      url: 'https://example.com/users',
      headers: {'Authorization': '<redacted>', 'content-length': '42'},
      requestData: {'name': 'Felix', 'active': true},
      queryParameters: {'debug': true},
      timestamp: DateTime(2026),
    );

    final command = buildCurlCommand(entry);

    expect(command, startsWith('curl \\\n'));
    expect(command, contains('-X \\\n  POST'));
    expect(command, contains("-H \\\n  'Authorization: <redacted>'"));
    expect(command, contains("-H \\\n  'Content-Type: application/json'"));
    expect(
      command,
      contains("--data-raw \\\n  '{\"name\":\"Felix\",\"active\":true}'"),
    );
    expect(command, contains('https://example.com/users?debug=true'));
    expect(command, isNot(contains('content-length')));
  });

  test('builds curl command for sse request', () {
    final entry = CaptureEntry(
      id: 'sse-curl',
      method: 'SSE',
      url: 'https://example.com/events',
      protocol: CaptureProtocol.sse,
      headers: {'Cache-Control': 'no-cache'},
      timestamp: DateTime(2026),
    );

    final command = buildCurlCommand(entry);

    expect(command, startsWith('curl \\\n  -N'));
    expect(command, isNot(contains('-X')));
    expect(command, contains("-H \\\n  'Accept: text/event-stream'"));
    expect(command, contains('https://example.com/events'));
  });

  test('builds curl command for websocket request', () {
    final entry = CaptureEntry(
      id: 'ws-curl',
      method: 'WS',
      url: 'wss://example.com/socket',
      protocol: CaptureProtocol.webSocket,
      headers: {
        'Authorization': '<redacted>',
        'Connection': 'Upgrade',
        'Sec-WebSocket-Key': 'generated',
      },
      timestamp: DateTime(2026),
    );

    final command = buildCurlCommand(entry);

    expect(command, startsWith('curl \\\n  -N'));
    expect(command, isNot(contains('-X')));
    expect(command, contains("-H \\\n  'Authorization: <redacted>'"));
    expect(command, contains('wss://example.com/socket'));
    expect(command, isNot(contains('Connection: Upgrade')));
    expect(command, isNot(contains('Sec-WebSocket-Key')));
  });

  test('builds json lines export for captured entries', () {
    final store = CaptureStore(enabled: true);
    store.addEntry(
      CaptureEntry(
        id: 'http-export',
        method: 'POST',
        url: 'https://example.com/users?q=1',
        headers: {'Authorization': '<redacted>'},
        requestData: {'name': 'Felix'},
        queryParameters: {'q': 1},
        statusCode: 201,
        responseData: {'id': 1},
        duration: const Duration(milliseconds: 42),
        timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
      ),
    );

    final file = buildCaptureLogExport(
      store,
      exportedAt: DateTime.utc(2026, 1, 2, 3, 5),
    );
    final lines = const LineSplitter().convert(file.content);
    final metadata = jsonDecode(lines[0]) as Map<String, dynamic>;
    final capture = jsonDecode(lines[1]) as Map<String, dynamic>;
    final request = capture['request'] as Map<String, dynamic>;
    final response = capture['response'] as Map<String, dynamic>;

    expect(file.fileName, 'dio-capture-2026-01-02T03-05-00-000Z.jsonl');
    expect(file.mimeType, contains('ndjson'));
    expect(lines, hasLength(2));
    expect(metadata['schema'], 'dio_capture_viewer.jsonl.v1');
    expect(metadata['entryCount'], 1);
    expect(capture['type'], 'capture');
    expect(capture['protocol'], 'http');
    expect(capture['state'], 'success');
    expect(capture['host'], 'example.com');
    expect(capture['path'], '/users');
    expect(capture['query'], 'q=1');
    expect(capture['statusCode'], 201);
    expect(capture['durationMs'], 42);
    expect(request['headers'], {'Authorization': '<redacted>'});
    expect(request['body'], {'name': 'Felix'});
    expect(response['body'], {'id': 1});
  });

  test('json lines export includes stream messages', () {
    final store = CaptureStore(enabled: true);
    final session = store.startStreamCapture(
      protocol: CaptureProtocol.webSocket,
      url: 'wss://example.com/socket',
    );
    session.addOutbound({'type': 'ping'}, label: 'send');
    session.close(code: 1000);

    final file = buildCaptureLogExport(store, exportedAt: DateTime.utc(2026));
    final lines = const LineSplitter().convert(file.content);
    final capture = jsonDecode(lines[1]) as Map<String, dynamic>;
    final messages = capture['messages'] as List<dynamic>;
    final firstMessage = messages.first as Map<String, dynamic>;

    expect(capture['protocol'], 'webSocket');
    expect(capture['state'], 'closed');
    expect(messages, hasLength(2));
    expect(firstMessage['direction'], 'outbound');
    expect(firstMessage['type'], 'message');
    expect(firstMessage['label'], 'send');
  });

  test('store keeps newest entries within max cache size', () {
    final store = CaptureStore(enabled: true, maxCacheSize: 20);

    for (var index = 0; index < 25; index += 1) {
      store.addEntry(
        CaptureEntry(
          id: '$index',
          method: 'GET',
          url: 'https://example.com/$index',
          timestamp: DateTime(2026),
        ),
      );
    }

    expect(store.entries, hasLength(20));
    expect(store.entries.first.id, '24');
    expect(store.entries.last.id, '5');
  });

  test(
    'store records websocket stream session as success after open and close',
    () {
      final store = CaptureStore(enabled: true);
      final session = store.startStreamCapture(
        protocol: CaptureProtocol.webSocket,
        url: 'wss://example.com/socket',
        headers: {'x-debug': '1'},
      );

      session.addOutbound({'type': 'ping'}, label: 'send');
      session.addInbound({'type': 'pong'}, label: 'receive');
      session.close(code: 1000, reason: 'normal');

      expect(store.entries, hasLength(1));
      final entry = store.entries.single;
      expect(entry.id, session.id);
      expect(entry.method, 'WS');
      expect(entry.protocol, CaptureProtocol.webSocket);
      expect(entry.state, CaptureState.success);
      expect(entry.isSuccess, isTrue);
      expect(entry.isError, isFalse);
      expect(entry.headers, {'x-debug': '1'});
      expect(entry.closedAt, isNotNull);
      expect(entry.messages, hasLength(3));
      expect(entry.messages[0].direction, CaptureMessageDirection.outbound);
      expect(entry.messages[0].type, CaptureMessageType.message);
      expect(entry.messages[1].direction, CaptureMessageDirection.inbound);
      expect(entry.messages[2].type, CaptureMessageType.close);
      expect(entry.messages[2].data, {'code': 1000, 'reason': 'normal'});
    },
  );

  test('store records sse events and failures', () {
    final store = CaptureStore(enabled: true);
    final session = store.startStreamCapture(
      protocol: CaptureProtocol.sse,
      url: 'https://example.com/events',
    );

    session.addEvent('connected', label: 'open');
    session.fail(StateError('stream failed'));

    final entry = store.entries.single;
    expect(entry.method, 'SSE');
    expect(entry.protocol, CaptureProtocol.sse);
    expect(entry.state, CaptureState.error);
    expect(entry.errorMessage, contains('stream failed'));
    expect(entry.closedAt, isNotNull);
    expect(entry.messages, hasLength(2));
    expect(entry.messages.first.type, CaptureMessageType.event);
    expect(entry.messages.last.type, CaptureMessageType.error);
  });

  test('open stream session counts as success before it closes', () {
    final store = CaptureStore(enabled: true);
    store.startStreamCapture(
      protocol: CaptureProtocol.sse,
      url: 'https://example.com/events',
    );

    final stats = store.stats;
    expect(store.entries.single.state, CaptureState.success);
    expect(store.entries.single.isSuccess, isTrue);
    expect(stats.success, 1);
    expect(stats.pending, 0);
  });

  test('stream session is no-op when capture is disabled', () {
    final store = CaptureStore(enabled: false);
    final session = store.startStreamCapture(
      protocol: CaptureProtocol.webSocket,
      url: 'wss://example.com/socket',
    );

    session.addInbound('message');
    session.close();

    expect(store.entries, isEmpty);
  });

  test('deleted stream entry is not recreated by later session updates', () {
    final store = CaptureStore(enabled: true);
    final session = store.startStreamCapture(
      protocol: CaptureProtocol.webSocket,
      url: 'wss://example.com/socket',
    );

    store.deleteEntry(session.id);
    session.addInbound('late message');
    session.close();

    expect(store.entries, isEmpty);
  });

  test('cleared stream entries are not recreated by later session updates', () {
    final store = CaptureStore(enabled: true);
    final session = store.startStreamCapture(
      protocol: CaptureProtocol.sse,
      url: 'https://example.com/events',
    );

    store.clearEntries();
    session.addEvent('late event');
    session.fail('late error');

    expect(store.entries, isEmpty);
  });

  test(
    'stream messages are throttled while close still notifies immediately',
    () async {
      final store = CaptureStore(
        enabled: true,
        streamNotifyInterval: const Duration(milliseconds: 40),
      );
      var notifications = 0;
      store.addListener(() => notifications += 1);

      final session = store.startStreamCapture(
        protocol: CaptureProtocol.webSocket,
        url: 'wss://example.com/socket',
      );
      final afterStart = notifications;

      session.addInbound('first');
      session.addInbound('second');

      expect(store.entries.single.messages, hasLength(2));
      expect(notifications, afterStart);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(notifications, afterStart + 1);

      session.close();

      expect(store.entries.single.messages, hasLength(3));
      expect(notifications, afterStart + 2);
    },
  );

  test('zero stream notify interval refreshes every message immediately', () {
    final store = CaptureStore(
      enabled: true,
      streamNotifyInterval: Duration.zero,
    );
    var notifications = 0;
    store.addListener(() => notifications += 1);

    final session = store.startStreamCapture(
      protocol: CaptureProtocol.webSocket,
      url: 'wss://example.com/socket',
    );
    final afterStart = notifications;

    session.addInbound('first');
    session.addInbound('second');

    expect(store.entries.single.messages, hasLength(2));
    expect(notifications, afterStart + 2);
  });

  test('controller passes stream notify interval to owned store', () {
    final controller = DioCaptureViewerController.init(
      enabled: true,
      streamNotifyInterval: Duration.zero,
    );
    var notifications = 0;
    controller.store.addListener(() => notifications += 1);

    final session = controller.store.startStreamCapture(
      protocol: CaptureProtocol.sse,
      url: 'https://example.com/events',
    );
    final afterStart = notifications;

    session.addEvent('first');

    expect(notifications, afterStart + 1);
  });

  test('cleanup preserves open streams and removes http entries first', () {
    final store = CaptureStore(enabled: true, maxCacheSize: 20);
    final sessions = <CaptureStreamSession>[];

    for (var index = 0; index < 3; index += 1) {
      sessions.add(
        store.startStreamCapture(
          protocol: CaptureProtocol.webSocket,
          url: 'wss://example.com/socket/$index',
        ),
      );
    }

    for (var index = 0; index < 20; index += 1) {
      store.addEntry(
        CaptureEntry(
          id: 'http-$index',
          method: 'GET',
          url: 'https://example.com/$index',
          statusCode: 200,
          timestamp: DateTime(2026),
        ),
      );
    }

    final ids = store.entries.map((entry) => entry.id).toSet();
    for (final session in sessions) {
      expect(ids, contains(session.id));
    }
    expect(store.entries, hasLength(20));
    expect(
      store.entries.where((entry) => entry.protocol == CaptureProtocol.http),
      hasLength(17),
    );
  });

  test('cleanup allows overflow when all entries are open streams', () {
    final store = CaptureStore(enabled: true, maxCacheSize: 20);

    for (var index = 0; index < 25; index += 1) {
      store.startStreamCapture(
        protocol: CaptureProtocol.sse,
        url: 'https://example.com/events/$index',
      );
    }

    expect(store.entries, hasLength(25));
    expect(
      store.entries.every((entry) => entry.state == CaptureState.success),
      isTrue,
    );
  });

  test('cleanup removes closed stream entries when eligible', () {
    final store = CaptureStore(enabled: true, maxCacheSize: 20);

    for (var index = 0; index < 19; index += 1) {
      store.startStreamCapture(
        protocol: CaptureProtocol.webSocket,
        url: 'wss://example.com/open/$index',
      );
    }

    final closedSession = store.startStreamCapture(
      protocol: CaptureProtocol.sse,
      url: 'https://example.com/closed',
    );
    closedSession.close();

    store.startStreamCapture(
      protocol: CaptureProtocol.webSocket,
      url: 'wss://example.com/new-open',
    );

    final ids = store.entries.map((entry) => entry.id).toSet();
    expect(ids, isNot(contains(closedSession.id)));
    expect(store.entries, hasLength(20));
    expect(
      store.entries.where(
        (entry) =>
            entry.state == CaptureState.success && entry.closedAt == null,
      ),
      hasLength(20),
    );
  });

  test('interceptor records request and response', () async {
    final store = CaptureStore(enabled: true);
    final dio = Dio()
      ..interceptors.add(CaptureInterceptor(store))
      ..httpClientAdapter = _FakeAdapter(
        ResponseBody.fromString(
          '{"code":200,"data":true}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

    await dio.get<dynamic>(
      'https://example.com/users',
      queryParameters: {'q': 1},
    );

    expect(store.entries, hasLength(1));
    final entry = store.entries.single;
    expect(entry.method, 'GET');
    expect(entry.url, 'https://example.com/users?q=1');
    expect(entry.statusCode, 200);
    expect(entry.responseData, {'code': 200, 'data': true});
    expect(entry.duration, isNotNull);
  });

  test('interceptor redacts sensitive headers', () async {
    final store = CaptureStore(enabled: true);
    final dio = Dio()
      ..interceptors.add(CaptureInterceptor(store))
      ..httpClientAdapter = _FakeAdapter(ResponseBody.fromString('{}', 200));

    await dio.get<dynamic>(
      'https://example.com/secure',
      options: Options(headers: {'Authorization': 'Bearer secret'}),
    );

    expect(store.entries.single.headers?['Authorization'], '<redacted>');
  });

  test(
    'interceptor summarizes uploaded files instead of showing file content',
    () async {
      final store = CaptureStore(enabled: true);
      final dio = Dio()
        ..interceptors.add(CaptureInterceptor(store))
        ..httpClientAdapter = _FakeAdapter(ResponseBody.fromString('{}', 200));
      final formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(
          [1, 2, 3, 4],
          filename: 'avatar.png',
          contentType: DioMediaType('image', 'png'),
        ),
      });

      await dio.post<dynamic>('https://example.com/upload', data: formData);

      final requestData = store.entries.single.requestData as Map;
      final files = requestData['files'] as List;
      expect(files.single['content'], '[avatar.png, image/png, 4B]');
      expect(files.single, isNot(containsPair('bytes', anything)));
    },
  );

  test(
    'interceptor summarizes media responses instead of showing file content',
    () async {
      final store = CaptureStore(enabled: true);
      final dio = Dio()
        ..interceptors.add(CaptureInterceptor(store))
        ..httpClientAdapter = _FakeAdapter(
          ResponseBody.fromBytes(
            [1, 2, 3, 4, 5],
            200,
            headers: {
              Headers.contentTypeHeader: ['image/png'],
            },
          ),
        );

      await dio.get<dynamic>('https://example.com/avatar.png');

      expect(store.entries.single.responseData, '[image/png, 5B]');
    },
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responseBody);

  final ResponseBody responseBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return responseBody;
  }

  @override
  void close({bool force = false}) {}
}
