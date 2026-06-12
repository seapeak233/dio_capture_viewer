# SSE and WebSocket Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dependency-free manual SSE and WebSocket capture support to `dio_capture_viewer`.

**Architecture:** Extend the existing capture model with protocol, state, and message concepts while keeping all HTTP fields compatible. Add `CaptureStore.startStreamCapture` and a lightweight session handle that updates entries only while capture is enabled and the entry has not been manually deleted or cleared. Update viewer labels/details and README examples without adding package dependencies.

**Tech Stack:** Dart 3, Flutter, Dio 5, flutter_test.

---

## File Structure

- Modify `lib/src/capture_entry.dart`: add stream enums, `CaptureMessage`, additive fields, and copy helpers.
- Modify `lib/src/capture_store.dart`: add stream session API, manual deletion tracking, and protected cleanup.
- Modify `lib/src/capture_viewer.dart`: display stream status and message payloads.
- Modify `lib/dio_capture_viewer.dart`: export public stream model/session types through existing exports.
- Modify `test/dio_capture_viewer_test.dart`: add behavior tests before production code.
- Modify `README.md` and `README_zh.md`: document dependency-free manual adapters and remove completed TODOs.

## Tasks

### Task 1: Stream Model

**Files:**
- Modify: `test/dio_capture_viewer_test.dart`
- Modify: `lib/src/capture_entry.dart`

- [ ] Add failing tests that instantiate `CaptureEntry` with `CaptureProtocol.sse`, append `CaptureMessage` values through `copyWith`, and verify default HTTP compatibility.
- [ ] Run `flutter test test/dio_capture_viewer_test.dart`; expected failure: missing stream enums/classes/fields.
- [ ] Implement `CaptureProtocol`, `CaptureState`, `CaptureMessageDirection`, `CaptureMessageType`, `CaptureMessage`, additive `CaptureEntry` fields, stream-aware size calculations, and expanded `copyWith`.
- [ ] Run `dart format lib/src/capture_entry.dart test/dio_capture_viewer_test.dart`.
- [ ] Run `flutter test test/dio_capture_viewer_test.dart`; expected pass.
- [ ] Commit model changes.

### Task 2: Manual Stream Session API

**Files:**
- Modify: `test/dio_capture_viewer_test.dart`
- Modify: `lib/src/capture_store.dart`

- [ ] Add failing tests for `startStreamCapture`, inbound/outbound messages, `addEvent`, `close`, `fail`, disabled capture no-op behavior, delete no-op behavior, and `clearEntries` no-op behavior.
- [ ] Run `flutter test test/dio_capture_viewer_test.dart`; expected failure: missing store/session APIs.
- [ ] Implement `CaptureStreamSession`, `CaptureStore.startStreamCapture`, internal stream message updates, `deleteEntry`, deleted id tracking, clear behavior, and state updates.
- [ ] Run `dart format lib/src/capture_store.dart test/dio_capture_viewer_test.dart`.
- [ ] Run `flutter test test/dio_capture_viewer_test.dart`; expected pass.
- [ ] Commit store/session changes.

### Task 3: Protected Cache Cleanup

**Files:**
- Modify: `test/dio_capture_viewer_test.dart`
- Modify: `lib/src/capture_store.dart`

- [ ] Add failing tests showing cleanup preserves open SSE/WebSocket entries, removes ordinary HTTP entries first, allows temporary overflow when all entries are open streams, and removes closed streams when eligible.
- [ ] Run `flutter test test/dio_capture_viewer_test.dart`; expected failure: old cleanup removes by index only.
- [ ] Replace cleanup with priority-based removal and keep selected entry consistent when removed.
- [ ] Run `dart format lib/src/capture_store.dart test/dio_capture_viewer_test.dart`.
- [ ] Run `flutter test test/dio_capture_viewer_test.dart`; expected pass.
- [ ] Commit cleanup changes.

### Task 4: Viewer Support

**Files:**
- Modify: `lib/src/capture_viewer.dart`

- [ ] Update method chip color mapping for `SSE` and `WS`.
- [ ] Update status text/color and overview rows for stream states.
- [ ] Change the third details tab label to `Messages` for stream entries and render message sections with timestamp, direction, type/label, and payload.
- [ ] Include stream messages in Copy All.
- [ ] Run `dart format lib/src/capture_viewer.dart`.
- [ ] Run `flutter test test/dio_capture_viewer_test.dart`; expected pass.
- [ ] Commit viewer changes.

### Task 5: README Examples

**Files:**
- Modify: `README.md`
- Modify: `README_zh.md`

- [ ] Add dependency-free SSE/WebSocket manual capture sections with short adapter snippets.
- [ ] Remove completed TODO items for SSE and WebSocket support.
- [ ] Run `dart format lib test` only if code changed during this task.
- [ ] Run `flutter test`; expected pass.
- [ ] Commit documentation changes.

### Task 6: Final Verification

**Files:**
- Verify all modified files.

- [ ] Run `dart format --output=none --set-exit-if-changed lib test`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run `git status --short` and inspect final diff/log.
