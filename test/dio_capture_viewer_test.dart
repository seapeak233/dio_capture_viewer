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
