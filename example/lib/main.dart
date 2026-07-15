import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_capture_viewer/dio_capture_viewer.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:toastification/toastification.dart';

import 'capture_settings_page.dart';

void main() {
  runApp(const ExampleApp());
}

const apiHost = 'https://jsonplaceholder.typicode.com';

final navigatorKey = GlobalKey<NavigatorState>();
final lastExportedLogPath = ValueNotifier<String?>(null);
bool _isExportLoadingVisible = false;

final captureController = DioCaptureViewerController.init(
  enabled: true,
  showPanel: true,
  navigatorKey: navigatorKey,
  label: 'Example API',
  host: apiHost,
  onSettingsTap: (_, store) {
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ExampleCaptureSettingsPage(store: store, host: apiHost),
      ),
    );
  },
  onCloseTap: _confirmCloseViewer,
  exportHandler: CaptureExportHandler(
    exportStart: _showExportLoading,
    exportEnd: _saveExportedLog,
  ),
  toast: (_, message) {
    _showMessage(message);
  },
);

final dio = Dio(BaseOptions(baseUrl: apiHost, responseType: ResponseType.json))
  ..interceptors.add(captureController.createInterceptor());

final mockDio =
    Dio(BaseOptions(baseUrl: apiHost, responseType: ResponseType.json))
      ..interceptors.add(captureController.createInterceptor())
      ..httpClientAdapter = _MockHttpAdapter();

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Dio Capture Viewer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        builder: (context, child) {
          return DioCaptureViewerOverlay(
            controller: captureController,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const ExampleHomePage(),
      ),
    );
  }
}

Future<bool> _confirmCloseViewer(
  BuildContext context,
  CaptureStore store,
) async {
  final dialogContext = navigatorKey.currentContext ?? context;
  final shouldClose = await showDialog<bool>(
    context: dialogContext,
    builder: (context) => AlertDialog(
      title: const Text('Hide capture viewer?'),
      content: const Text('You can reopen it from the debug page.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Hide'),
        ),
      ],
    ),
  );
  return shouldClose ?? false;
}

void _showExportLoading(BuildContext context, CaptureStore store) {
  final dialogContext = navigatorKey.currentContext ?? context;
  _isExportLoadingVisible = true;
  unawaited(
    showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 14),
                Text('Exporting logs...'),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _isExportLoadingVisible = false),
  );
}

Future<void> _saveExportedLog(
  BuildContext context,
  CaptureStore store,
  CaptureExportFile file,
) async {
  final dialogContext = navigatorKey.currentContext ?? context;
  if (_isExportLoadingVisible) {
    Navigator.of(dialogContext, rootNavigator: true).pop();
  }

  final extensionStart = file.fileName.lastIndexOf('.');
  final name = extensionStart == -1
      ? file.fileName
      : file.fileName.substring(0, extensionStart);
  final extension = extensionStart == -1
      ? 'jsonl'
      : file.fileName.substring(extensionStart + 1);

  try {
    final savedPath = await FileSaver.instance.saveFile(
      name: name,
      bytes: file.bytes,
      fileExtension: extension,
      mimeType: MimeType.custom,
      customMimeType: file.mimeType,
    );
    lastExportedLogPath.value = savedPath.isEmpty ? null : savedPath;
    _showMessage('Exported ${file.fileName}', type: ToastificationType.success);
  } catch (error) {
    _showMessage(
      'Export failed: $error',
      long: true,
      type: ToastificationType.error,
    );
  }
}

Future<void> _openExportedLog(String filePath) async {
  final result = await OpenFilex.open(filePath);
  if (result.type == ResultType.done) {
    return;
  }
  _showMessage(
    'Open failed: ${result.message}',
    long: true,
    type: ToastificationType.error,
  );
}

void _showMessage(
  String message, {
  bool long = false,
  ToastificationType type = ToastificationType.info,
}) {
  toastification.show(
    type: type,
    style: ToastificationStyle.simple,
    title: Text(message),
    alignment: Alignment.bottomCenter,
    autoCloseDuration: Duration(seconds: long ? 4 : 2),
    showProgressBar: false,
  );
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  String _lastResult = 'Tap a button to send a request.';

  Future<void> _runRequest(Future<Response<dynamic>> Function() request) async {
    setState(() => _lastResult = 'Loading...');
    try {
      final response = await request();
      const encoder = JsonEncoder.withIndent('  ');
      setState(() => _lastResult = encoder.convert(response.data));
    } catch (error) {
      // Dio 5.0 uses DioError; newer Dio 5.x keeps it as a deprecated typedef.
      // ignore: deprecated_member_use
      final message = error is DioError
          ? error.message ?? error.toString()
          : error.toString();
      setState(() => _lastResult = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dio Capture Viewer'),
        actions: [
          ValueListenableBuilder<String?>(
            valueListenable: lastExportedLogPath,
            builder: (context, filePath, _) {
              final canOpen = filePath != null && filePath.isNotEmpty;
              return IconButton(
                tooltip: canOpen ? 'Open exported log' : 'No exported log yet',
                onPressed: canOpen ? () => _openExportedLog(filePath) : null,
                icon: const Icon(Icons.open_in_new),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ButtonGroup(
            title: 'Real requests',
            children: [
              _SmallButton(
                label: 'GET post',
                onPressed: () =>
                    _runRequest(() => dio.get<dynamic>('/posts/1')),
              ),
              _SmallButton(
                label: 'GET comments',
                onPressed: () => _runRequest(
                  () => dio.get<dynamic>(
                    '/comments',
                    queryParameters: {'postId': 1},
                  ),
                ),
              ),
              _SmallButton(
                label: 'POST',
                onPressed: () => _runRequest(
                  () => dio.post<dynamic>(
                    '/posts',
                    data: {'title': 'hello', 'body': 'capture me', 'userId': 1},
                  ),
                ),
              ),
              _SmallButton(
                label: 'Error',
                onPressed: () =>
                    _runRequest(() => dio.get<dynamic>('/missing-endpoint')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ButtonGroup(
            title: 'Mock HTTP',
            children: [
              _SmallButton(
                label: 'GET',
                filled: true,
                onPressed: () =>
                    _runRequest(() => mockDio.get<dynamic>('/posts/1')),
              ),
              _SmallButton(
                label: 'List',
                filled: true,
                onPressed: () => _runRequest(
                  () => mockDio.get<dynamic>(
                    '/comments',
                    queryParameters: {'postId': 1},
                  ),
                ),
              ),
              _SmallButton(
                label: 'POST',
                filled: true,
                onPressed: () => _runRequest(
                  () => mockDio.post<dynamic>(
                    '/posts',
                    data: {'title': 'hello', 'body': 'capture me', 'userId': 1},
                  ),
                ),
              ),
              _SmallButton(
                label: 'Error',
                onPressed: () => _runRequest(
                  () => mockDio.get<dynamic>('/missing-endpoint'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ButtonGroup(
            title: 'Mock SSE and WebSocket',
            subtitle: 'Advanced manual stream capture',
            children: [
              _SmallButton(
                label: 'WS close',
                filled: true,
                onPressed: () => _mockWebSocket(closeNormally: true),
              ),
              _SmallButton(
                label: 'WS error',
                onPressed: () => _mockWebSocket(closeNormally: false),
              ),
              _SmallButton(
                label: 'SSE close',
                filled: true,
                onPressed: () => _mockSse(closeNormally: true),
              ),
              _SmallButton(
                label: 'SSE error',
                onPressed: () => _mockSse(closeNormally: false),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SmallButton(
                label: 'Toggle viewer',
                onPressed: () => captureController.store.togglePanel(),
              ),
              _SmallButton(label: 'Settings', onPressed: _openSettings),
            ],
          ),
          const SizedBox(height: 24),
          Text('Last response', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _lastResult,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    captureController.store.showMini();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExampleCaptureSettingsPage(
          store: captureController.store,
          host: apiHost,
        ),
      ),
    );
  }

  Future<void> _mockWebSocket({required bool closeNormally}) async {
    final session = captureController.store.startStreamCapture(
      protocol: CaptureProtocol.webSocket,
      url: 'wss://mock.local/realtime',
      headers: {'Sec-WebSocket-Protocol': 'chat.v1'},
    );

    session.addOutbound({'type': 'subscribe', 'room': 'debug'});
    setState(() {
      _lastResult = const JsonEncoder.withIndent('  ').convert({
        'mock': 'websocket',
        'sessionId': session.id,
        'frames': 10,
        'state': 'streaming',
      });
    });

    for (var index = 1; index <= 10; index += 1) {
      await Future<void>.delayed(const Duration(seconds: 3));
      session.addInbound({
        'type': 'message',
        'sequence': index,
        'from': index.isOdd ? 'qa-bot' : 'debug-server',
        'body': 'Local WebSocket frame #$index',
        'latencyMs': 30 + index * 7,
      }, label: 'frame-$index');
    }

    if (closeNormally) {
      session.close(code: 1000, reason: 'normal closure after 10 frames');
    } else {
      session.fail('Mock WebSocket abnormal closure after frame 10: code 1006');
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _lastResult = const JsonEncoder.withIndent('  ').convert({
        'mock': 'websocket',
        'sessionId': session.id,
        'frames': 10,
        'state': closeNormally ? 'closed' : 'error',
      });
    });
  }

  Future<void> _mockSse({required bool closeNormally}) async {
    final session = captureController.store.startStreamCapture(
      protocol: CaptureProtocol.sse,
      url: 'https://mock.local/events',
    );

    setState(() {
      _lastResult = const JsonEncoder.withIndent('  ').convert({
        'mock': 'sse',
        'sessionId': session.id,
        'events': 10,
        'state': 'streaming',
      });
    });

    for (var index = 1; index <= 10; index += 1) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final eventName = index % 3 == 0 ? 'heartbeat' : 'notification';
      session.addEvent({
        'event': eventName,
        'id': index,
        'data': {
          'title': 'Local SSE event #$index',
          'unread': index,
          'priority': index.isEven ? 'normal' : 'high',
        },
      }, label: eventName);
    }

    if (closeNormally) {
      session.close(reason: 'server finished stream after 10 events');
    } else {
      session.fail('Mock SSE connection dropped after event 10');
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _lastResult = const JsonEncoder.withIndent('  ').convert({
        'mock': 'sse',
        'sessionId': session.id,
        'events': 10,
        'state': closeNormally ? 'closed' : 'error',
      });
    });
  }
}

class _ButtonGroup extends StatelessWidget {
  const _ButtonGroup({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: children),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: WidgetStateProperty.all(const Size(0, 32)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      textStyle: WidgetStateProperty.all(
        Theme.of(context).textTheme.labelSmall,
      ),
    );

    if (filled) {
      return FilledButton.tonal(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}

class _MockHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));

    final path = options.uri.path;
    if (path == '/posts/1') {
      return _jsonResponse(options, 200, {
        'id': 1,
        'title': 'Local mock post',
        'body': 'This response is generated inside the example app.',
        'userId': 1,
      });
    }

    if (path == '/comments') {
      final postId = options.uri.queryParameters['postId'];
      return _jsonResponse(options, 200, [
        {
          'id': 1,
          'postId': postId,
          'name': 'Mock QA comment',
          'email': 'qa@example.local',
          'body': 'Captured from a local Dio adapter.',
        },
        {
          'id': 2,
          'postId': postId,
          'name': 'Mock dev comment',
          'email': 'dev@example.local',
          'body': 'No network request was made.',
        },
      ]);
    }

    if (path == '/posts' && options.method.toUpperCase() == 'POST') {
      return _jsonResponse(options, 201, {
        'id': 101,
        'created': true,
        'received': options.data,
      });
    }

    return _jsonResponse(options, 404, {
      'code': 404,
      'message': 'Mock endpoint not found',
      'path': path,
    });
  }

  ResponseBody _jsonResponse(
    RequestOptions options,
    int statusCode,
    Object body,
  ) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'x-mock-source': ['example'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
