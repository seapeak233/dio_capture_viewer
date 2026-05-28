import 'dart:async' show FutureOr, unawaited;

import 'package:flutter/material.dart';

import 'capture_entry.dart';

const _captureEnabledKey = 'dio_capture_viewer_enabled';
const _captureMaxCacheSizeKey = 'dio_capture_viewer_max_cache_size';

enum CapturePanelMode { mini, full, docked }

enum CaptureDockSide { left, right }

/// Optional storage bridge for apps that want capture settings to survive
/// process restarts.
abstract interface class CapturePreferences {
  String? read(String key);

  FutureOr<void> write(String key, String value);
}

/// Shared state for the Dio interceptor and the floating viewer overlay.
class CaptureStore extends ChangeNotifier {
  static const int minCacheSize = 20;
  static const int maxCacheSizeLimit = 500;
  static const int defaultMaxCacheSize = 100;

  CaptureStore({
    CapturePreferences? preferences,
    bool enabled = false,
    int maxCacheSize = defaultMaxCacheSize,
  }) : _preferences = preferences,
       _isEnabled = enabled,
       _maxCacheSize = maxCacheSize.clamp(minCacheSize, maxCacheSizeLimit);

  final CapturePreferences? _preferences;
  final List<CaptureEntry> _entries = <CaptureEntry>[];

  bool _isEnabled;
  bool _isPanelVisible = false;
  CapturePanelMode _panelMode = CapturePanelMode.mini;
  CaptureDockSide _dockSide = CaptureDockSide.left;
  int _maxCacheSize;
  Offset _panelPosition = const Offset(50, 100);
  CaptureEntry? _selectedEntry;
  int _currentTabIndex = 0;
  String _searchFilter = '';

  List<CaptureEntry> get entries => List.unmodifiable(_entries);

  List<CaptureEntry> get filteredEntries {
    final filter = _searchFilter.trim().toLowerCase();
    if (filter.isEmpty) {
      return entries;
    }
    return _entries
        .where((entry) => entry.url.toLowerCase().contains(filter))
        .toList(growable: false);
  }

  bool get isEnabled => _isEnabled;
  bool get isCaptureEnabled => _isEnabled;
  bool get isPanelVisible => _isPanelVisible;
  bool get isMinimized => _panelMode != CapturePanelMode.full;
  bool get isDocked => _panelMode == CapturePanelMode.docked;
  CapturePanelMode get panelMode => _panelMode;
  CaptureDockSide get dockSide => _dockSide;
  int get maxCacheSize => _maxCacheSize;
  Offset get panelPosition => _panelPosition;
  CaptureEntry? get selectedEntry => _selectedEntry;
  int get currentTabIndex => _currentTabIndex;
  String get searchFilter => _searchFilter;

  void restore() {
    final enabled = _readBool(_captureEnabledKey);
    final maxCacheSize = _readInt(_captureMaxCacheSizeKey);
    if (enabled != null) {
      _isEnabled = enabled;
      _isPanelVisible = enabled;
    }
    if (maxCacheSize != null) {
      _maxCacheSize = maxCacheSize.clamp(minCacheSize, maxCacheSizeLimit);
    }
    notifyListeners();
  }

  void setEnabled(bool value) {
    _isEnabled = value;
    if (!value) {
      _entries.clear();
      _selectedEntry = null;
    }
    _writePreference(_captureEnabledKey, value.toString());
    notifyListeners();
  }

  void setMaxCacheSize(int value) {
    _maxCacheSize = value.clamp(minCacheSize, maxCacheSizeLimit);
    _cleanupEntries();
    _writePreference(_captureMaxCacheSizeKey, _maxCacheSize.toString());
    notifyListeners();
  }

  void showPanel({bool minimized = true}) {
    _isPanelVisible = true;
    _panelMode = minimized ? CapturePanelMode.mini : CapturePanelMode.full;
    notifyListeners();
  }

  void hidePanel() {
    _isPanelVisible = false;
    notifyListeners();
  }

  void togglePanel({bool minimized = true}) {
    if (_isPanelVisible) {
      hidePanel();
      return;
    }
    showPanel(minimized: minimized);
  }

  void toggleMinimized() {
    _panelMode = _panelMode == CapturePanelMode.full
        ? CapturePanelMode.mini
        : CapturePanelMode.full;
    notifyListeners();
  }

  void showMini({double? availableWidth, double? miniWidth}) {
    if (_panelMode == CapturePanelMode.docked &&
        availableWidth != null &&
        miniWidth != null) {
      _panelPosition = Offset(
        _dockSide == CaptureDockSide.left
            ? 0
            : (availableWidth - miniWidth).clamp(0, double.infinity).toDouble(),
        _panelPosition.dy,
      );
    }
    _panelMode = CapturePanelMode.mini;
    notifyListeners();
  }

  void dockPanel({
    required double availableWidth,
    required double dragWidth,
    required double dockedWidth,
  }) {
    _dockSide = _panelPosition.dx + dragWidth / 2 < availableWidth / 2
        ? CaptureDockSide.left
        : CaptureDockSide.right;
    _panelPosition = Offset(
      _dockSide == CaptureDockSide.left
          ? 0
          : (availableWidth - dockedWidth).clamp(0, double.infinity).toDouble(),
      _panelPosition.dy,
    );
    _panelMode = CapturePanelMode.docked;
    notifyListeners();
  }

  void updatePanelPosition(Offset position) {
    _panelPosition = Offset(
      position.dx.clamp(0, double.infinity).toDouble(),
      position.dy.clamp(0, double.infinity).toDouble(),
    );
    notifyListeners();
  }

  void addEntry(CaptureEntry entry) {
    if (!isCaptureEnabled) {
      return;
    }
    _entries.insert(0, entry);
    _cleanupEntries();
    notifyListeners();
  }

  void updateEntry(
    String id, {
    int? statusCode,
    Object? responseData,
    String? errorMessage,
    Duration? duration,
  }) {
    if (!isCaptureEnabled) {
      return;
    }

    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return;
    }

    final updatedEntry = _entries[index].copyWith(
      statusCode: statusCode,
      responseData: responseData,
      errorMessage: errorMessage,
      duration: duration,
    );
    _entries[index] = updatedEntry;
    if (_selectedEntry?.id == id) {
      _selectedEntry = updatedEntry;
    }
    notifyListeners();
  }

  void clearEntries() {
    _entries.clear();
    _selectedEntry = null;
    notifyListeners();
  }

  void selectEntry(CaptureEntry entry) {
    _selectedEntry = entry;
    notifyListeners();
  }

  void setTab(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void setSearchFilter(String value) {
    _searchFilter = value;
    notifyListeners();
  }

  void clearSearchFilter() {
    _searchFilter = '';
    FocusManager.instance.primaryFocus?.unfocus();
    notifyListeners();
  }

  ({int total, int success, int error, int pending}) get stats {
    final total = _entries.length;
    final success = _entries.where((entry) => entry.isSuccess).length;
    final error = _entries.where((entry) => entry.isError).length;
    final pending = _entries
        .where(
          (entry) => entry.statusCode == null && entry.errorMessage == null,
        )
        .length;
    return (total: total, success: success, error: error, pending: pending);
  }

  void _cleanupEntries() {
    if (_entries.length <= _maxCacheSize) {
      return;
    }
    _entries.removeRange(_maxCacheSize, _entries.length);
  }

  bool? _readBool(String key) {
    final raw = _preferences?.read(key);
    if (raw == null) {
      return null;
    }
    return raw == 'true';
  }

  int? _readInt(String key) {
    final raw = _preferences?.read(key);
    if (raw == null) {
      return null;
    }
    return int.tryParse(raw);
  }

  void _writePreference(String key, String value) {
    final result = _preferences?.write(key, value);
    if (result is Future<void>) {
      unawaited(result);
    }
  }
}
