import 'package:dio_capture_viewer/dio_capture_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<DioCaptureViewerController> pumpViewer(
    WidgetTester tester,
    double width,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);

    final controller = DioCaptureViewerController.init(
      enabled: true,
      showPanel: true,
      label: 'Example API',
      host: 'https://example.com',
    );
    controller.store.showPanel(minimized: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const SizedBox.expand(),
            DioCaptureViewer(controller: controller),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('uses a single title row and split panes at 840 pixels', (
    tester,
  ) async {
    await pumpViewer(tester, 840);

    expect(find.byKey(const ValueKey('dio-capture-desktop-layout')), findsOne);
    expect(
      find.byKey(const ValueKey('dio-capture-desktop-title-bar')),
      findsOne,
    );
    expect(find.text('Example API'), findsOne);
    expect(find.text('https://example.com'), findsOne);
    expect(find.text('Select a request to inspect details'), findsOne);

    final listPane = tester.getRect(
      find.byKey(const ValueKey('dio-capture-request-list-pane')),
    );
    final detailsPane = tester.getRect(
      find.byKey(const ValueKey('dio-capture-request-details-pane')),
    );
    expect(listPane.right, lessThanOrEqualTo(detailsPane.left));

    final titleCenter = tester.getCenter(find.text('Example API')).dy;
    final hostCenter = tester.getCenter(find.text('https://example.com')).dy;
    expect(titleCenter, closeTo(hostCenter, 1));
  });

  testWidgets('keeps the compact stacked layout below 840 pixels', (
    tester,
  ) async {
    await pumpViewer(tester, 839);

    expect(find.byKey(const ValueKey('dio-capture-compact-layout')), findsOne);
    expect(
      find.byKey(const ValueKey('dio-capture-desktop-layout')),
      findsNothing,
    );
  });

  testWidgets('marks active SSE and WebSocket entries as continuing', (
    tester,
  ) async {
    final controller = await pumpViewer(tester, 840);
    final sse = controller.store.startStreamCapture(
      protocol: CaptureProtocol.sse,
      url: 'https://example.com/events',
    );
    final webSocket = controller.store.startStreamCapture(
      protocol: CaptureProtocol.webSocket,
      url: 'wss://example.com/socket',
    );
    await tester.pump();

    expect(find.text('Connected...'), findsNWidgets(2));

    sse.close();
    webSocket.fail('connection lost');
    await tester.pump();

    expect(find.text('Connected...'), findsNothing);
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
  });
}
