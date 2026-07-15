import 'package:dio_capture_viewer/dio_capture_viewer.dart';
import 'package:dio_capture_viewer_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('export button follows captured entries', (tester) async {
    captureController.store.clearEntries();
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    OutlinedButton exportButton() => tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Export logs'),
    );

    expect(exportButton().onPressed, isNull);

    captureController.store.addEntry(
      CaptureEntry(
        id: 'export-test',
        method: 'GET',
        url: 'https://example.com/export-test',
        timestamp: DateTime(2026),
        state: CaptureState.success,
        statusCode: 200,
      ),
    );
    await tester.pump();

    expect(exportButton().onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
