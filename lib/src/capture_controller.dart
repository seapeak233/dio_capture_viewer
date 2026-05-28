import 'dart:async' show FutureOr;

import 'package:flutter/material.dart';

import 'capture_interceptor.dart';
import 'capture_store.dart';

typedef CaptureViewerAction =
    FutureOr<void> Function(BuildContext context, CaptureStore store);

typedef CaptureViewerCloseHandler =
    FutureOr<bool> Function(BuildContext context, CaptureStore store);

/// One object that owns the capture store, viewer labels, navigation context,
/// and optional viewer button callbacks.
class DioCaptureViewerController {
  DioCaptureViewerController({
    CaptureStore? store,
    CapturePreferences? preferences,
    bool enabled = false,
    bool showPanel = false,
    int maxCacheSize = CaptureStore.defaultMaxCacheSize,
    this.navigatorKey,
    this.label = 'Dio Capture',
    this.host,
    this.onSettingsTap,
    this.onCloseTap,
    this.confirmClose = true,
  }) : assert(
         store == null || preferences == null,
         'Pass either store or preferences, not both.',
       ),
       store =
           store ??
           CaptureStore(
             preferences: preferences,
             enabled: enabled,
             maxCacheSize: maxCacheSize,
           ) {
    if (showPanel) {
      this.store.showPanel();
    }
  }

  factory DioCaptureViewerController.init({
    CapturePreferences? preferences,
    bool enabled = false,
    bool showPanel = false,
    int maxCacheSize = CaptureStore.defaultMaxCacheSize,
    GlobalKey<NavigatorState>? navigatorKey,
    String label = 'Dio Capture',
    String? host,
    CaptureViewerAction? onSettingsTap,
    CaptureViewerCloseHandler? onCloseTap,
    bool confirmClose = true,
  }) {
    return DioCaptureViewerController(
      preferences: preferences,
      enabled: enabled,
      showPanel: showPanel,
      maxCacheSize: maxCacheSize,
      navigatorKey: navigatorKey,
      label: label,
      host: host,
      onSettingsTap: onSettingsTap,
      onCloseTap: onCloseTap,
      confirmClose: confirmClose,
    );
  }

  /// Shared state used by both [CaptureInterceptor] and
  /// [DioCaptureViewerOverlay].
  final CaptureStore store;

  /// Optional navigator key used to make viewer button callbacks work from
  /// `MaterialApp.builder`.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Title shown in the full-screen capture viewer.
  final String label;

  /// Current API host or base URL shown in the floating viewer.
  final String? host;

  /// Called when the full-screen viewer settings button is tapped.
  final CaptureViewerAction? onSettingsTap;

  /// Called when the compact viewer close button is tapped.
  ///
  /// Return `true` to hide the viewer. Return `false` to keep it visible.
  final CaptureViewerCloseHandler? onCloseTap;

  /// Whether the built-in close confirmation should be used when
  /// [onCloseTap] is not provided.
  final bool confirmClose;

  BuildContext? get navigatorContext => navigatorKey?.currentContext;

  NavigatorState? get navigator => navigatorKey?.currentState;

  BuildContext actionContext(BuildContext fallback) {
    return navigatorContext ?? fallback;
  }

  CaptureInterceptor createInterceptor({CaptureLogger? logger}) {
    return CaptureInterceptor(store, logger: logger);
  }

  void restore() {
    store.restore();
  }
}
