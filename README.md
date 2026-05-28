# dio_capture_viewer

[中文文档](README_zh.md)

A lightweight in-app request capture viewer for Flutter apps that use Dio.

It adds one Dio interceptor and a floating Material UI panel where you can
inspect request headers, query parameters, request bodies, response payloads,
errors, status codes, and request durations.

## Features

- Floating draggable viewer with compact, docked, and full-screen modes.
- Dio interceptor for request, response, error, duration, and payload capture.
- Header redaction for authorization, cookies, and token-like fields.
- Filterable request list and copy actions for payloads.
- Settings entry callback and optional persistence bridge.

## Usage

Create one `DioCaptureViewerController`, attach its interceptor to Dio, then
place the overlay above your app content.

```dart
import 'package:dio/dio.dart';
import 'package:dio_capture_viewer/dio_capture_viewer.dart';
import 'package:flutter/material.dart';

const apiHost = 'https://api.example.com';

final navigatorKey = GlobalKey<NavigatorState>();

final captureController = DioCaptureViewerController.init(
  enabled: true,
  showPanel: true,
  navigatorKey: navigatorKey,
  host: apiHost,
  onSettingsTap: (context, store) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YourCaptureSettingsPage(store: store),
      ),
    );
  },
  onCloseTap: (context, store) async {
    return await confirmHideCaptureViewer(context);
  },
);

final dio = Dio(BaseOptions(baseUrl: apiHost))
  ..interceptors.add(captureController.createInterceptor());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Use the same key passed to DioCaptureViewerController.
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return DioCaptureViewerOverlay(
          controller: captureController,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomePage(),
    );
  }
}
```

The `navigatorKey` is optional if you do not open routes from viewer buttons.
When you use `onSettingsTap` or show dialogs from `onCloseTap`, pass the same
key to both `DioCaptureViewerController` and `MaterialApp`.

`CaptureStore` exposes the settings you can place in your own capture settings
page:

```dart
captureController.store.setEnabled(true);
captureController.store.setMaxCacheSize(200);

final enabled = captureController.store.isEnabled;
final maxCacheSize = captureController.store.maxCacheSize;
```

If your app has its own persistence layer, implement `CapturePreferences` and
pass it into `CaptureStore(preferences: yourPreferences)`, then call
`captureStore.restore()` during startup.

The package does not export a settings page. It only provides the setting entry
callback, the floating viewer modes, the capture store, and the Dio interceptor.

## Notes

This package is meant for development, QA, and internal debug builds. Avoid
showing captured production traffic to end users.
