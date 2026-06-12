# SSE and WebSocket Capture Design

## Goal

Add SSE and WebSocket capture support to `dio_capture_viewer` without adding runtime dependencies beyond the package's current Flutter and Dio dependencies.

## Scope

This change adds a protocol-neutral manual stream capture API to the main package and documents lightweight adapter patterns for common SSE and WebSocket clients. It does not add a hard dependency on `web_socket_channel`, EventSource packages, or any other network client library.

The package remains centered on the floating viewer, `CaptureStore`, and Dio interceptor. Dio HTTP capture keeps working through the existing interceptor API.

## Architecture

The current `CaptureEntry` model represents one HTTP request and its response. The new model keeps those fields for compatibility and adds protocol and stream-message fields so HTTP, SSE, and WebSocket captures can share the same viewer list.

New public model concepts:

- `CaptureProtocol`: identifies `http`, `sse`, and `webSocket`.
- `CaptureState`: identifies `pending`, `open`, `closed`, `success`, and `error`.
- `CaptureMessageDirection`: identifies inbound, outbound, and internal lifecycle messages.
- `CaptureMessageType`: identifies message, event, open, close, and error messages.
- `CaptureMessage`: stores a stream/frame/event payload with timestamp, direction, type, and optional label.

`CaptureEntry` remains the list item and details source. Existing HTTP fields stay available:

- `method`
- `url`
- `headers`
- `requestData`
- `queryParameters`
- `statusCode`
- `responseData`
- `errorMessage`
- `timestamp`
- `duration`

New stream fields are additive:

- `protocol`
- `state`
- `messages`
- `closedAt`

HTTP entries default to `CaptureProtocol.http`. Stream entries use `SSE` or `WS` as their method label so the current list layout can remain compact.

## Store API

`CaptureStore` gains a manual stream API:

```dart
final session = store.startStreamCapture(
  protocol: CaptureProtocol.webSocket,
  url: 'wss://example.com/socket',
  headers: {'Authorization': 'Bearer token'},
);

session.addOutbound({'type': 'ping'});
session.addInbound({'type': 'pong'});
session.close();
```

For SSE:

```dart
final session = store.startStreamCapture(
  protocol: CaptureProtocol.sse,
  url: 'https://example.com/events',
);

session.addInbound({'event': 'message', 'data': data});
session.fail(error);
```

`CaptureStreamSession` is a lightweight handle that only knows its store and entry id. It exposes:

- `id`
- `addInbound(Object? data, {String? label})`
- `addOutbound(Object? data, {String? label})`
- `addEvent(Object? data, {String? label})`
- `close({int? code, String? reason})`
- `fail(Object error)`

When capture is disabled, starting a session returns a handle that does not add entries or messages.

## Manual Delete Behavior

Manual removal must prevent later updates from bringing an entry back.

`CaptureStore` tracks deleted entry ids in memory. When an entry is deleted by id or when all entries are cleared, existing `CaptureStreamSession` handles for those ids become no-op handles. Calls such as `addInbound`, `close`, and `fail` return without adding or recreating entries.

This behavior applies to:

- Explicit single-entry deletion.
- `clearEntries()`.

Automatic cleanup is separate from manual deletion. It removes eligible entries from the list without marking open stream sessions as manually deleted because open stream entries should be protected by the cleanup policy. If a closed stream entry is later removed by automatic cleanup, further updates to that old session remain no-ops because the entry no longer exists.

## Cache Cleanup Policy

`maxCacheSize` remains the target size, but open SSE and WebSocket entries are protected.

When entries exceed the limit, cleanup removes entries in this priority order:

1. Closed, successful, or failed HTTP entries.
2. Closed or failed SSE/WebSocket entries.
3. Pending HTTP entries.

Open SSE/WebSocket entries are not removed by automatic cleanup. If the list contains more open streams than `maxCacheSize`, the list may temporarily exceed the configured limit. Once those streams close or fail, a later cleanup can remove them.

The selected entry is cleared if its entry is removed by cleanup.

## Viewer Behavior

The viewer keeps the existing layout and makes small protocol-aware changes:

- List chips show HTTP methods, `SSE`, or `WS`.
- Status text shows HTTP status for HTTP entries and `Open`, `Closed`, or `Error` for streams.
- Details tabs keep `Overview` and `Request`.
- The third tab shows `Response` for HTTP and `Messages` for SSE/WebSocket.
- The messages view lists timestamp, direction, type/label, and payload.

The search box continues to filter by URL only.

## Documentation

Both root README files get:

- A short explanation that SSE and WebSocket support is manual and dependency-free.
- A WebSocket adapter snippet that captures outbound sends, inbound stream events, close, and error.
- An SSE adapter snippet that captures inbound events, close, and error.

The snippets are examples only. They do not add package dependencies to this library.

## Testing

Tests cover behavior, not implementation details:

- HTTP capture remains compatible with the existing interceptor test.
- `startStreamCapture` adds open SSE/WebSocket entries and appends inbound/outbound messages.
- `close` and `fail` update stream state without recreating entries.
- Deleting a stream entry makes later session updates no-op.
- `clearEntries` makes later session updates no-op.
- Cleanup protects open stream entries and removes older ordinary HTTP entries first.
- Cleanup can remove closed stream entries after lower-priority entries are gone.

Implementation follows red-green-refactor: write each test first, run it to confirm failure, then implement the minimal production change.

## Non-Goals

This feature does not:

- Add new packages to `pubspec.yaml`.
- Create separate extension packages.
- Automatically monkey-patch WebSocket or SSE clients.
- Persist captured messages.
- Add binary frame decoding beyond storing safe payload representations.
