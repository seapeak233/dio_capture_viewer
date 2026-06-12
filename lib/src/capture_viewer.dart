import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'capture_controller.dart';
import 'capture_entry.dart';
import 'capture_store.dart';
import 'capture_theme.dart';

const _jsonEncoder = JsonEncoder.withIndent('  ');
const _miniPanelWidth = 210.0;
const _miniPanelHeight = 54.0;
const _dockedPanelWidth = 34.0;
const _dockedPanelHeight = 52.0;
const _dockedPanelAlpha = 168;
const _compactPanelAnimationDuration = Duration(milliseconds: 220);
const _compactPanelAnimationCurve = Curves.easeOutCubic;

/// Global overlay widget for inspecting captured Dio traffic.
class DioCaptureViewer extends StatelessWidget {
  const DioCaptureViewer({
    this.controller,
    this.store,
    this.label,
    this.host,
    this.baseUrl,
    this.onSettingsTap,
    this.onCloseTap,
    this.actionContext,
    this.confirmClose,
    super.key,
  }) : assert(
         (controller == null) != (store == null),
         'Pass exactly one of controller or store.',
       );

  final DioCaptureViewerController? controller;
  final CaptureStore? store;
  final String? label;
  final String? host;
  @Deprecated('Use host instead. This value is only used for display.')
  final String? baseUrl;
  final CaptureViewerAction? onSettingsTap;
  final CaptureViewerCloseHandler? onCloseTap;
  final BuildContext? actionContext;
  final bool? confirmClose;

  @override
  Widget build(BuildContext context) {
    final effectiveStore = controller?.store ?? store!;
    final effectiveLabel = label ?? controller?.label ?? 'Dio Capture';
    final effectiveHost = host ?? controller?.host ?? baseUrl;
    final effectiveSettingsTap = onSettingsTap ?? controller?.onSettingsTap;
    final effectiveCloseTap = onCloseTap ?? controller?.onCloseTap;
    final effectiveConfirmClose =
        confirmClose ?? controller?.confirmClose ?? true;

    return ListenableBuilder(
      listenable: effectiveStore,
      builder: (context, _) {
        if (!effectiveStore.isPanelVisible) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: Stack(
            children: [
              if (effectiveStore.panelMode == CapturePanelMode.full)
                _FullPanel(
                  controller: controller,
                  store: effectiveStore,
                  label: effectiveLabel,
                  host: effectiveHost,
                  onSettingsTap: effectiveSettingsTap,
                  actionContext: actionContext,
                )
              else
                _CompactPanel(
                  controller: controller,
                  store: effectiveStore,
                  label: effectiveLabel,
                  host: effectiveHost,
                  onCloseTap: effectiveCloseTap,
                  actionContext: actionContext,
                  confirmClose: effectiveConfirmClose,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Convenience builder that layers [DioCaptureViewer] above [child].
///
/// Prefer passing a [DioCaptureViewerController]. The legacy `store` + callback
/// parameters remain available for apps that want to manage every value
/// separately.
class DioCaptureViewerOverlay extends StatelessWidget {
  const DioCaptureViewerOverlay({
    required this.child,
    this.controller,
    this.store,
    this.label,
    this.host,
    this.baseUrl,
    this.onSettingsTap,
    this.onCloseTap,
    this.confirmClose,
    super.key,
  }) : assert(
         (controller == null) != (store == null),
         'Pass exactly one of controller or store.',
       );

  final Widget child;
  final DioCaptureViewerController? controller;
  final CaptureStore? store;
  final String? label;
  final String? host;
  @Deprecated('Use host instead. This value is only used for display.')
  final String? baseUrl;
  final CaptureViewerAction? onSettingsTap;
  final CaptureViewerCloseHandler? onCloseTap;
  final bool? confirmClose;

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (overlayContext) => Stack(
            children: [
              child,
              DioCaptureViewer(
                controller: controller,
                store: store,
                label: label,
                host: host,
                baseUrl: baseUrl,
                onSettingsTap: onSettingsTap,
                onCloseTap: onCloseTap,
                actionContext: context,
                confirmClose: confirmClose,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactPanel extends StatefulWidget {
  const _CompactPanel({
    required this.controller,
    required this.store,
    required this.label,
    required this.host,
    required this.onCloseTap,
    required this.actionContext,
    required this.confirmClose,
  });

  final DioCaptureViewerController? controller;
  final CaptureStore store;
  final String label;
  final String? host;
  final CaptureViewerCloseHandler? onCloseTap;
  final BuildContext? actionContext;
  final bool confirmClose;

  @override
  State<_CompactPanel> createState() => _CompactPanelState();
}

class _CompactPanelState extends State<_CompactPanel> {
  Timer? _dockTimer;
  CapturePanelMode? _lastPanelMode;
  bool _dragged = false;

  CaptureStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _lastPanelMode = store.panelMode;
    if (store.panelMode == CapturePanelMode.mini) {
      _scheduleDock(const Duration(seconds: 3));
    }
  }

  @override
  void didUpdateWidget(covariant _CompactPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      _dockTimer?.cancel();
    }
    final modeChanged = _lastPanelMode != store.panelMode;
    _lastPanelMode = store.panelMode;
    if (modeChanged && store.panelMode == CapturePanelMode.mini) {
      _scheduleDock(const Duration(seconds: 3));
    } else if (store.panelMode != CapturePanelMode.mini) {
      _dockTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _dockTimer?.cancel();
    super.dispose();
  }

  void _scheduleDock(Duration delay) {
    _dockTimer?.cancel();
    _dockTimer = Timer(delay, () {
      if (!mounted || store.panelMode != CapturePanelMode.mini) {
        return;
      }
      store.dockPanel(
        availableWidth: MediaQuery.sizeOf(context).width,
        dragWidth: _miniPanelWidth,
        dockedWidth: _dockedPanelWidth,
      );
    });
  }

  void _handlePanStart(DragStartDetails details) {
    _dragged = false;
    _dockTimer?.cancel();
    if (store.isDocked) {
      store.showMini(
        availableWidth: MediaQuery.sizeOf(context).width,
        miniWidth: _miniPanelWidth,
      );
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _dragged = true;
    final size = MediaQuery.sizeOf(context);
    final maxX = size.width - _miniPanelWidth;
    final maxY = size.height - _miniPanelHeight;
    store.updatePanelPosition(
      Offset(
        (store.panelPosition.dx + details.delta.dx).clamp(0.0, maxX),
        (store.panelPosition.dy + details.delta.dy).clamp(0.0, maxY),
      ),
    );
  }

  void _handlePanEnd(DragEndDetails details) {
    _scheduleDock(const Duration(seconds: 1));
  }

  void _handleTap() {
    _dockTimer?.cancel();
    if (store.isDocked) {
      store.showMini(
        availableWidth: MediaQuery.sizeOf(context).width,
        miniWidth: _miniPanelWidth,
      );
      _scheduleDock(const Duration(seconds: 3));
      return;
    }
    if (!_dragged) {
      store.toggleMinimized();
    }
  }

  Future<void> _handleClose(BuildContext context) async {
    _dockTimer?.cancel();
    final closeHandler = widget.onCloseTap;
    if (closeHandler != null) {
      final fallbackContext = widget.actionContext ?? context;
      final actionContext =
          widget.controller?.actionContext(fallbackContext) ?? fallbackContext;
      final shouldClose = await closeHandler(actionContext, store);
      if (shouldClose) {
        store.hidePanel();
      }
      return;
    }
    if (!widget.confirmClose) {
      store.hidePanel();
      return;
    }
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close capture viewer?'),
        content: const Text('You can reopen the viewer from your debug entry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (shouldClose == true) {
      store.hidePanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FloatingPanel(
      store: store,
      label: widget.label,
      host: widget.host,
      onTap: _handleTap,
      onClose: _handleClose,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
    );
  }
}

class _FloatingPanel extends StatelessWidget {
  const _FloatingPanel({
    required this.store,
    required this.label,
    required this.host,
    required this.onTap,
    required this.onClose,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final CaptureStore store;
  final String label;
  final String? host;
  final VoidCallback onTap;
  final void Function(BuildContext context) onClose;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    final stats = store.stats;
    final size = MediaQuery.sizeOf(context);
    final isDocked = store.isDocked;
    final isLeft = store.dockSide == CaptureDockSide.left;
    final panelWidth = isDocked ? _dockedPanelWidth : _miniPanelWidth;
    final panelHeight = isDocked ? _dockedPanelHeight : _miniPanelHeight;
    final left = isDocked
        ? (isLeft ? 0.0 : size.width - panelWidth)
        : store.panelPosition.dx.clamp(0.0, size.width - panelWidth);
    final top = store.panelPosition.dy.clamp(0.0, size.height - panelHeight);
    final statusColor = stats.error > 0
        ? theme.error
        : stats.success > 0
        ? theme.success
        : theme.textMuted;

    return AnimatedPositioned(
      duration: _compactPanelAnimationDuration,
      curve: _compactPanelAnimationCurve,
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onTap,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: _compactPanelAnimationDuration,
            curve: _compactPanelAnimationCurve,
            width: panelWidth,
            height: panelHeight,
            padding: EdgeInsets.only(
              left: isDocked ? 4 : 0,
              right: isDocked ? 4 : 0,
            ),
            decoration: BoxDecoration(
              color: theme.surface.withAlpha(
                isDocked ? _dockedPanelAlpha : 230,
              ),
              borderRadius: isDocked
                  ? BorderRadius.horizontal(
                      left: Radius.circular(isLeft ? 0 : 8),
                      right: Radius.circular(isLeft ? 8 : 0),
                    )
                  : BorderRadius.circular(8),
              border: Border.all(color: theme.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: theme.shadow,
                  blurRadius: isDocked ? 14 : 18,
                  offset: Offset(0, isDocked ? 6 : 8),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: isDocked
                  ? _DockedPanelContent(
                      key: const ValueKey('dio-capture-docked-content'),
                      success: stats.success,
                      error: stats.error,
                    )
                  : _MiniPanelContent(
                      key: const ValueKey('dio-capture-mini-content'),
                      title: _shortBaseUrl(host ?? label),
                      success: stats.success,
                      error: stats.error,
                      statusColor: statusColor,
                      onExpand: store.toggleMinimized,
                      onClose: () => onClose(context),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPanelContent extends StatelessWidget {
  const _MiniPanelContent({
    required this.title,
    required this.success,
    required this.error,
    required this.statusColor,
    required this.onExpand,
    required this.onClose,
    super.key,
  });

  final String title;
  final int success;
  final int error;
  final Color statusColor;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 96) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 6,
              height: double.infinity,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
              ),
            ),
          );
        }

        return ClipRect(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'OK $success  ERR $error',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onExpand,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.open_in_full, size: 16),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, size: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DockedPanelContent extends StatelessWidget {
  const _DockedPanelContent({
    required this.success,
    required this.error,
    super.key,
  });

  final int success;
  final int error;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DockedStatText(value: success, color: theme.success),
        const SizedBox(height: 3),
        Container(width: 18, height: 1, color: theme.borderSubtle),
        const SizedBox(height: 3),
        _DockedStatText(value: error, color: theme.error),
      ],
    );
  }
}

class _DockedStatText extends StatelessWidget {
  const _DockedStatText({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    return Text(
      value.toString(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FullPanel extends StatelessWidget {
  const _FullPanel({
    required this.controller,
    required this.store,
    required this.label,
    required this.host,
    required this.onSettingsTap,
    required this.actionContext,
  });

  final DioCaptureViewerController? controller;
  final CaptureStore store;
  final String label;
  final String? host;
  final CaptureViewerAction? onSettingsTap;
  final BuildContext? actionContext;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 720;
    final theme = CaptureTheme(context);

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.98, end: 1),
        duration: _compactPanelAnimationDuration,
        curve: _compactPanelAnimationCurve,
        builder: (context, scale, child) => Opacity(
          opacity: ((scale - 0.98) / 0.02).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        ),
        child: Material(
          color: Colors.black54,
          child: SafeArea(
            child: Center(
              child: Container(
                width: isCompact ? size.width : size.width * 0.92,
                height: isCompact ? size.height : size.height * 0.82,
                constraints: const BoxConstraints(maxWidth: 1180),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(isCompact ? 0 : 8),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _Header(
                      store: store,
                      label: label,
                      host: host,
                      onSettingsTap: onSettingsTap,
                      controller: controller,
                      actionContext: actionContext,
                    ),
                    Expanded(
                      child: isCompact
                          ? Column(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _EntryList(store: store),
                                ),
                                Divider(height: 1, color: theme.borderSubtle),
                                Expanded(
                                  flex: 3,
                                  child: _EntryDetails(store: store),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                SizedBox(
                                  width: 380,
                                  child: _EntryList(store: store),
                                ),
                                VerticalDivider(
                                  width: 1,
                                  color: theme.borderSubtle,
                                ),
                                Expanded(child: _EntryDetails(store: store)),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.store,
    required this.label,
    required this.host,
    required this.onSettingsTap,
    required this.actionContext,
  });

  final DioCaptureViewerController? controller;
  final CaptureStore store;
  final String label;
  final String? host;
  final CaptureViewerAction? onSettingsTap;
  final BuildContext? actionContext;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    final stats = store.stats;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatText(
                      label: 'OK',
                      value: stats.success,
                      color: theme.success,
                    ),
                    const SizedBox(width: 8),
                    _StatText(
                      label: 'ERR',
                      value: stats.error,
                      color: theme.error,
                    ),
                  ],
                ),
                if (host != null)
                  Text(
                    host!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          _HeaderTextButton(label: 'Clear', onTap: store.clearEntries),
          const SizedBox(width: 6),
          if (onSettingsTap != null)
            _HeaderIconButton(
              onTap: () {
                store.showMini();
                final fallbackContext = actionContext ?? context;
                final targetContext =
                    controller?.actionContext(fallbackContext) ??
                    fallbackContext;
                onSettingsTap!(targetContext, store);
              },
              icon: Icons.settings_outlined,
            ),
          _HeaderIconButton(onTap: store.toggleMinimized, icon: Icons.minimize),
        ],
      ),
    );
  }
}

class _HeaderTextButton extends StatelessWidget {
  const _HeaderTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: theme.brandSoft.withAlpha(160),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.brandAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.onTap, required this.icon});

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: theme.textMuted),
      ),
    );
  }
}

class _StatText extends StatelessWidget {
  const _StatText({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    return Text(
      '$label $value',
      style: theme.textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.store});

  final CaptureStore store;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    final entries = store.filteredEntries;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: theme.background,
            border: Border(bottom: BorderSide(color: theme.borderSubtle)),
          ),
          child: Row(
            children: [
              Icon(Icons.filter_list, size: 14, color: theme.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: Center(
                    child: TextField(
                      controller: TextEditingController.fromValue(
                        TextEditingValue(
                          text: store.searchFilter,
                          selection: TextSelection.collapsed(
                            offset: store.searchFilter.length,
                          ),
                        ),
                      ),
                      onChanged: store.setSearchFilter,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.brandAccent,
                        fontWeight: FontWeight.w600,
                      ),
                      strutStyle: const StrutStyle(
                        forceStrutHeight: true,
                        height: 1.2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Filter URL',
                        hintStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textMuted,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),
              if (store.searchFilter.isNotEmpty)
                InkWell(
                  onTap: store.clearSearchFilter,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  customBorder: const CircleBorder(),
                  radius: 12,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    store.searchFilter.isEmpty
                        ? 'No captured requests'
                        : 'No matching requests',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textMuted,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, _) =>
                      Divider(height: 1, color: theme.borderSubtle),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _EntryTile(
                      entry: entry,
                      selected: store.selectedEntry?.id == entry.id,
                      onTap: () => store.selectEntry(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final CaptureEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    final statusColor = _statusColor(context, entry);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? theme.brandSoft.withAlpha(180) : null,
          border: Border(
            left: BorderSide(
              color: selected ? theme.brandAccent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _urlPath(entry.url),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _MethodChip(method: entry.method),
                const SizedBox(width: 8),
                Text(
                  _timeText(entry.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textMuted,
                  ),
                ),
                if (entry.duration != null) ...[
                  const SizedBox(width: 6),
                  _DurationTag(duration: entry.duration!),
                ],
                const Spacer(),
                Text(
                  _statusText(entry),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationTag extends StatelessWidget {
  const _DurationTag({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    final isSlow = duration.inMilliseconds > 1000;
    final backgroundColor = isSlow ? theme.warningContainer : theme.inputFill;
    final textColor = isSlow ? theme.warning : theme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _durationText(duration),
        style: theme.textTheme.labelSmall?.copyWith(color: textColor),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    final color = switch (method.toUpperCase()) {
      'GET' => theme.success,
      'POST' => theme.info,
      'PUT' || 'PATCH' => theme.warning,
      'DELETE' => theme.error,
      'SSE' => theme.info,
      'WS' => theme.brandAccent,
      _ => theme.textMuted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        method.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EntryDetails extends StatelessWidget {
  const _EntryDetails({required this.store});

  final CaptureStore store;

  @override
  Widget build(BuildContext context) {
    final entry = store.selectedEntry;
    final theme = CaptureTheme(context);
    if (entry == null) {
      return Center(
        child: Text(
          'Select a request to inspect details',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textMuted),
        ),
      );
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.borderSubtle)),
          ),
          child: Row(
            children: [
              _TabButton(store: store, index: 0, label: 'Overview'),
              _TabButton(store: store, index: 1, label: 'Request'),
              _TabButton(
                store: store,
                index: 2,
                label: entry.protocol == CaptureProtocol.http
                    ? 'Response'
                    : 'Messages',
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: switch (store.currentTabIndex) {
            0 => _OverviewTab(entry: entry),
            1 => _PayloadTab(
              sections: [
                _PayloadSection('Headers', entry.headers),
                _PayloadSection('Query Parameters', entry.queryParameters),
                _PayloadSection('Request Body', entry.requestData),
              ],
            ),
            2 =>
              entry.protocol == CaptureProtocol.http
                  ? _PayloadTab(
                      sections: [
                        _PayloadSection('Response Data', entry.responseData),
                        _PayloadSection('Error Message', entry.errorMessage),
                      ],
                    )
                  : _MessagesTab(messages: entry.messages),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.store,
    required this.index,
    required this.label,
  });

  final CaptureStore store;
  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    final selected = store.currentTabIndex == index;

    return InkWell(
      onTap: () => store.setTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? theme.brandAccent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? theme.brandAccent : theme.textMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.entry});

  final CaptureEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Method', value: entry.method),
                _InfoRow(label: 'URL', value: entry.url),
                _InfoRow(
                  label: 'Protocol',
                  value: _protocolText(entry.protocol),
                ),
                _InfoRow(label: 'Status', value: _statusText(entry)),
                _InfoRow(label: 'Time', value: _dateTimeText(entry.timestamp)),
                if (entry.closedAt != null)
                  _InfoRow(
                    label: 'Closed',
                    value: _dateTimeText(entry.closedAt!),
                  ),
                if (entry.duration != null)
                  _InfoRow(
                    label: 'Duration',
                    value: '${entry.duration!.inMilliseconds} ms',
                    isWarning: entry.duration!.inMilliseconds > 1000,
                  ),
                _InfoRow(
                  label: 'Request Size',
                  value: _formatBytes(entry.requestSize),
                ),
                _InfoRow(
                  label: 'Response Size',
                  value: _formatBytes(entry.responseSize),
                ),
                if (entry.protocol != CaptureProtocol.http)
                  _InfoRow(
                    label: 'Messages',
                    value: entry.messages.length.toString(),
                  ),
                if (entry.errorMessage != null)
                  _InfoRow(
                    label: 'Error',
                    value: entry.errorMessage!,
                    isError: true,
                  ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(top: BorderSide(color: theme.borderSubtle)),
          ),
          child: FilledButton.icon(
            onPressed: () => _copyAllData(context, entry),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy All'),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isError = false,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isError;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isError
                    ? theme.error
                    : isWarning
                    ? theme.warning
                    : theme.textBody,
                fontWeight: (isError || isWarning)
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayloadSection {
  const _PayloadSection(this.title, this.data);

  final String title;
  final Object? data;
}

class _PayloadTab extends StatelessWidget {
  const _PayloadTab({required this.sections});

  final List<_PayloadSection> sections;

  @override
  Widget build(BuildContext context) {
    final visibleSections = sections
        .where((section) => !_isEmptyPayload(section.data))
        .toList(growable: false);
    final theme = CaptureTheme(context);

    if (visibleSections.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: visibleSections.length,
      separatorBuilder: (context, _) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final section = visibleSections[index];
        return _PayloadView(
          title: section.title,
          data: section.data,
          initiallyCollapsed: section.title == 'Headers',
        );
      },
    );
  }
}

class _MessagesTab extends StatefulWidget {
  const _MessagesTab({required this.messages});

  final List<CaptureMessage> messages;

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  late final ScrollController _scrollController;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lastMessageCount = widget.messages.length;
    if (_lastMessageCount > 0) {
      _scrollToBottom(animated: false);
    }
  }

  @override
  void didUpdateWidget(covariant _MessagesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > _lastMessageCount) {
      _scrollToBottom(animated: true);
    }
    _lastMessageCount = widget.messages.length;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      _scrollController.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    if (widget.messages.isEmpty) {
      return Center(
        child: Text(
          'No messages',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textMuted),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: widget.messages.length,
      separatorBuilder: (context, _) =>
          Divider(height: 1, color: theme.borderSubtle),
      itemBuilder: (context, index) {
        return _MessageRow(message: widget.messages[index]);
      },
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final CaptureMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    final direction = _messageDirectionText(message.direction);
    final title = message.label ?? _messageTypeText(message.type);
    final payload = _payloadText(message.data);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _timeText(message.timestamp),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.textMuted,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                direction,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _messageDirectionColor(theme, message.direction),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: () => _copyText(context, payload),
                icon: const Icon(Icons.copy, size: 14),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          SelectableText(
            payload,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textBody,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayloadView extends StatefulWidget {
  const _PayloadView({
    required this.title,
    required this.data,
    this.initiallyCollapsed = false,
  });

  final String title;
  final Object? data;
  final bool initiallyCollapsed;

  @override
  State<_PayloadView> createState() => _PayloadViewState();
}

class _PayloadViewState extends State<_PayloadView> {
  late bool _isCollapsed;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.initiallyCollapsed;
  }

  @override
  void didUpdateWidget(covariant _PayloadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.data != widget.data) {
      _isCollapsed = widget.initiallyCollapsed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);
    final payloadText = _isCollapsed
        ? '{\n  ...collapsed; tap Expand to view\n}'
        : _payloadText(widget.data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (widget.initiallyCollapsed) ...[
              _PayloadHeaderAction(
                label: _isCollapsed ? 'Expand' : 'Collapse',
                onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              tooltip: 'Copy',
              onPressed: () => _copyText(context, payloadText),
              icon: const Icon(Icons.copy, size: 16),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.borderSubtle),
          ),
          child: SelectableText(
            payloadText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textBody,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _PayloadHeaderAction extends StatelessWidget {
  const _PayloadHeaderAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CaptureTheme(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.brandAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

void _copyAllData(BuildContext context, CaptureEntry entry) {
  final buffer = StringBuffer()
    ..writeln('Method: ${entry.method}')
    ..writeln('URL: ${entry.url}')
    ..writeln('Status: ${entry.statusCode}')
    ..writeln('Time: ${entry.timestamp.toIso8601String()}');

  if (entry.duration != null) {
    buffer.writeln('Duration: ${entry.duration!.inMilliseconds} ms');
  }
  if (entry.errorMessage != null) {
    buffer.writeln('Error: ${entry.errorMessage}');
  }

  void writePayload(String title, Object? data) {
    if (_isEmptyPayload(data)) {
      return;
    }
    buffer
      ..writeln()
      ..writeln('$title:')
      ..writeln(_payloadText(data));
  }

  writePayload('Headers', entry.headers);
  writePayload('Query Parameters', entry.queryParameters);
  writePayload('Request Body', entry.requestData);
  writePayload('Response Data', entry.responseData);
  if (entry.messages.isNotEmpty) {
    writePayload(
      'Messages',
      entry.messages
          .map(
            (message) => <String, Object?>{
              'time': message.timestamp.toIso8601String(),
              'direction': _messageDirectionText(message.direction),
              'type': _messageTypeText(message.type),
              if (message.label != null) 'label': message.label,
              'data': message.data,
            },
          )
          .toList(growable: false),
    );
  }

  _copyText(context, buffer.toString());
}

void _copyText(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
  );
}

String _payloadText(Object? data) {
  if (data == null) {
    return 'null';
  }
  if (data is String) {
    try {
      return _jsonEncoder.convert(jsonDecode(data));
    } catch (_) {
      return data;
    }
  }
  if (data is Map || data is Iterable || data is num || data is bool) {
    try {
      return _jsonEncoder.convert(data);
    } catch (_) {
      return data.toString();
    }
  }
  return data.toString();
}

bool _isEmptyPayload(Object? data) {
  if (data == null) {
    return true;
  }
  if (data is String) {
    return data.trim().isEmpty;
  }
  if (data is Map) {
    return data.isEmpty;
  }
  if (data is Iterable) {
    return data.isEmpty;
  }
  return false;
}

Color _statusColor(BuildContext context, CaptureEntry entry) {
  final theme = CaptureTheme(context);
  if (entry.protocol != CaptureProtocol.http) {
    return switch (entry.state) {
      CaptureState.open ||
      CaptureState.closed ||
      CaptureState.success => theme.success,
      CaptureState.error => theme.error,
      CaptureState.pending => theme.warning,
    };
  }
  if (_businessCode(entry) case final code? when code != 200) {
    return theme.warning;
  }
  if (entry.isSuccess) {
    return theme.success;
  }
  if (entry.isError) {
    return theme.error;
  }
  return theme.warning;
}

String _statusText(CaptureEntry entry) {
  if (entry.protocol != CaptureProtocol.http) {
    return switch (entry.state) {
      CaptureState.open => 'Open',
      CaptureState.closed => 'Closed',
      CaptureState.error => 'Error',
      CaptureState.success => entry.closedAt == null ? 'Connected' : 'Closed',
      CaptureState.pending => 'Pending',
    };
  }
  if (entry.isSuccess || entry.statusCode != null) {
    final statusText = entry.statusCode.toString();
    if (_businessCode(entry) case final code? when code != 200) {
      return '$statusText [$code]';
    }
    return statusText;
  }
  if (entry.errorMessage != null) {
    return 'Error';
  }
  return 'Pending';
}

String _protocolText(CaptureProtocol protocol) {
  return switch (protocol) {
    CaptureProtocol.http => 'HTTP',
    CaptureProtocol.sse => 'SSE',
    CaptureProtocol.webSocket => 'WebSocket',
  };
}

String _messageDirectionText(CaptureMessageDirection direction) {
  return switch (direction) {
    CaptureMessageDirection.inbound => 'IN',
    CaptureMessageDirection.outbound => 'OUT',
    CaptureMessageDirection.internal => 'SYS',
  };
}

Color _messageDirectionColor(
  CaptureTheme theme,
  CaptureMessageDirection direction,
) {
  return switch (direction) {
    CaptureMessageDirection.inbound => theme.success,
    CaptureMessageDirection.outbound => theme.info,
    CaptureMessageDirection.internal => theme.textMuted,
  };
}

String _messageTypeText(CaptureMessageType type) {
  return switch (type) {
    CaptureMessageType.message => 'message',
    CaptureMessageType.event => 'event',
    CaptureMessageType.open => 'open',
    CaptureMessageType.close => 'close',
    CaptureMessageType.error => 'error',
  };
}

int? _businessCode(CaptureEntry entry) {
  final data = entry.responseData;
  if (data is Map) {
    final code = data['code'];
    if (code is int) {
      return code;
    }
    if (code is num) {
      return code.toInt();
    }
    if (code is String) {
      return int.tryParse(code);
    }
  }
  return null;
}

String _urlPath(String url) {
  try {
    final uri = Uri.parse(url);
    final query = uri.query.isEmpty ? '' : '?${uri.query}';
    return '${uri.path.isEmpty ? '/' : uri.path}$query';
  } catch (_) {
    return url;
  }
}

String _shortBaseUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.host.isEmpty ? url : uri.host;
  } catch (_) {
    return url;
  }
}

String _timeText(DateTime timestamp) {
  return '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}.'
      '${timestamp.millisecond.toString().padLeft(3, '0')}';
}

String _durationText(Duration duration) {
  final milliseconds = duration.inMilliseconds;
  if (milliseconds < 1000) {
    return '${milliseconds}ms';
  }
  return '${(milliseconds / 1000).toStringAsFixed(1)}s';
}

String _dateTimeText(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} ${_timeText(value)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}
