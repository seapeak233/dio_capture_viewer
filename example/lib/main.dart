import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_capture_viewer/dio_capture_viewer.dart';
import 'package:flutter/material.dart';

import 'capture_settings_page.dart';

void main() {
  runApp(const ExampleApp());
}

const apiHost = 'https://jsonplaceholder.typicode.com';

final navigatorKey = GlobalKey<NavigatorState>();

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
);

final dio = Dio(BaseOptions(baseUrl: apiHost, responseType: ResponseType.json))
  ..interceptors.add(captureController.createInterceptor());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      appBar: AppBar(title: const Text('Dio Capture Viewer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () =>
                    _runRequest(() => dio.get<dynamic>('/posts/1')),
                child: const Text('GET post'),
              ),
              FilledButton.tonal(
                onPressed: () => _runRequest(
                  () => dio.get<dynamic>(
                    '/comments',
                    queryParameters: {'postId': 1},
                  ),
                ),
                child: const Text('GET comments'),
              ),
              FilledButton.tonal(
                onPressed: () => _runRequest(
                  () => dio.post<dynamic>(
                    '/posts',
                    data: {'title': 'hello', 'body': 'capture me', 'userId': 1},
                  ),
                ),
                child: const Text('POST'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _runRequest(() => dio.get<dynamic>('/missing-endpoint')),
                child: const Text('Error'),
              ),
              OutlinedButton(
                onPressed: () => captureController.store.togglePanel(),
                child: const Text('Toggle viewer'),
              ),
              OutlinedButton(
                onPressed: () {
                  captureController.store.showMini();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExampleCaptureSettingsPage(
                        store: captureController.store,
                        host: apiHost,
                      ),
                    ),
                  );
                },
                child: const Text('Capture settings'),
              ),
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
}
