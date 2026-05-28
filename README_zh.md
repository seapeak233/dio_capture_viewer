# dio_capture_viewer 中文文档

一个用于 Flutter 应用的轻量级 Dio 请求抓包查看器。

它通过一个 Dio Interceptor 捕获请求与响应，并在应用内提供一个可拖拽的 Material 悬浮面板，方便在开发、联调、QA 和内部调试环境中查看网络请求。

## 功能特性

- 应用内悬浮抓包面板，支持迷你、贴边和全屏查看模式。
- 捕获 Dio 请求、响应、错误、状态码、耗时和请求/响应内容。
- 自动脱敏 `authorization`、`cookie`、`set-cookie` 以及包含 `token` 的请求头。
- 支持按 URL 过滤请求列表。
- 支持复制请求和响应内容，便于排查问题。
- 提供设置入口回调，宿主应用可自行暴露抓包开关、最大缓存数量和当前 host。
- 提供可选持久化桥接接口，方便接入应用自己的配置存储。

## 安装

在应用的 `pubspec.yaml` 中添加依赖。

如果是在本地项目中使用：

```yaml
dependencies:
  dio_capture_viewer:
    path: ../dio_capture_viewer
```

如果已经发布到包仓库，也可以使用版本号依赖：

```yaml
dependencies:
  dio_capture_viewer: ^0.0.1
```

然后执行：

```bash
flutter pub get
```

## 快速接入

创建一个 `DioCaptureViewerController`，把它创建的 interceptor 添加到 Dio，然后用 `DioCaptureViewerOverlay` 包住应用内容。

```dart
import 'package:dio/dio.dart';
import 'package:dio_capture_viewer/dio_capture_viewer.dart';
import 'package:flutter/material.dart';

const apiHost = 'https://jsonplaceholder.typicode.com';

final navigatorKey = GlobalKey<NavigatorState>();

final captureController = DioCaptureViewerController.init(
  enabled: true,
  showPanel: true,
  navigatorKey: navigatorKey,
  label: 'Example API',
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

final dio = Dio(
  BaseOptions(
    baseUrl: apiHost,
    responseType: ResponseType.json,
  ),
)..interceptors.add(captureController.createInterceptor());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 和 DioCaptureViewerController 使用同一个 navigatorKey。
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

如果不需要从浮窗按钮打开页面，`navigatorKey` 可以不传。只要使用 `onSettingsTap` 打开设置页，或在 `onCloseTap` 中弹窗，就建议把同一个 `navigatorKey` 同时传给 `DioCaptureViewerController` 和 `MaterialApp`。

## 常用配置

包内不导出设置页，只提供 `onSettingsTap` 设置入口回调。宿主应用可以单独开一个抓包设置页，和业务调试页面区分开。

关闭按钮也可以通过 `onCloseTap` 接管。返回 `true` 时包内会隐藏悬浮窗，返回 `false` 时保持显示。

### 开启或关闭抓包

```dart
captureController.store.setEnabled(true);
captureController.store.setEnabled(false);
```

关闭抓包时，当前已缓存的请求记录会被清空。

### 显示或隐藏悬浮面板

```dart
captureController.store.showPanel();
captureController.store.hidePanel();
captureController.store.togglePanel();
```

### 调整最大缓存数量

```dart
captureController.store.setMaxCacheSize(200);
```

缓存数量会被限制在 `20` 到 `500` 之间，默认值是 `100`。

也可以使用常量构建设置 UI：

```dart
CaptureStore.minCacheSize;
CaptureStore.maxCacheSizeLimit;
CaptureStore.defaultMaxCacheSize;
```

### 展示当前 Host

悬浮窗不会读取 Dio 实例，只接收外部传入的展示值：

```dart
DioCaptureViewerOverlay(
  controller: captureController,
  child: child,
);
```

### 清空请求记录

```dart
captureController.store.clearEntries();
```

## 持久化设置

如果应用已有自己的配置存储，可以实现 `CapturePreferences`，并传给 `CaptureStore`。

```dart
class AppCapturePreferences implements CapturePreferences {
  AppCapturePreferences(this.storage);

  final MyStorage storage;

  @override
  String? read(String key) {
    return storage.readString(key);
  }

  @override
  Future<void> write(String key, String value) {
    return storage.writeString(key, value);
  }
}

final captureStore = CaptureStore(
  preferences: AppCapturePreferences(storage),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  captureStore.restore();
  runApp(const App());
}
```

目前会持久化以下配置：

- 抓包开关。
- 最大缓存请求数量。

## 查看器交互

- 迷你面板可以拖拽移动。
- 迷你面板闲置后会自动贴边，减少对业务界面的遮挡。
- 点击迷你面板可展开全屏查看器。
- 全屏查看器中可以查看请求列表、请求头、查询参数、请求体、响应体、错误信息和耗时。
- 可通过搜索框按 URL 过滤请求。
- 可复制请求或响应内容。

## 运行示例

进入示例目录并运行：

```bash
cd example
flutter pub get
flutter run
```

示例应用使用 `https://jsonplaceholder.typicode.com`，页面上提供了 GET、POST 和错误请求按钮，可直接观察抓包面板效果。

## 安全提醒

这个包主要用于开发、测试、QA 和内部调试版本。虽然请求头中常见敏感字段会自动脱敏，但仍不建议在面向终端用户的生产环境中展示抓包面板或暴露真实生产流量。
