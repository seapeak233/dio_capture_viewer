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

  test('store records websocket stream session messages and close', () {
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
    expect(entry.state, CaptureState.closed);
    expect(entry.headers, {'x-debug': '1'});
    expect(entry.closedAt, isNotNull);
    expect(entry.messages, hasLength(3));
    expect(entry.messages[0].direction, CaptureMessageDirection.outbound);
    expect(entry.messages[0].type, CaptureMessageType.message);
    expect(entry.messages[1].direction, CaptureMessageDirection.inbound);
    expect(entry.messages[2].type, CaptureMessageType.close);
    expect(entry.messages[2].data, {'code': 1000, 'reason': 'normal'});
  });

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
