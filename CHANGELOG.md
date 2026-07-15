## 1.0.0

* Added macOS, Windows, and Linux runners to the example app.
* Added a responsive desktop viewer layout with a single-row header, request
  list, and request details pane at widths of 840 logical pixels and above.
* Updated the example app to use a cross-platform toast implementation and a
  dedicated viewer actions section.
* Updated desktop log export to use the native save dialog on macOS, Windows,
  and Linux.

## 0.2.0

* Added optional `exportHandler` support on the controller and overlay. When it
  is omitted, the export button is hidden.
* Added JSON Lines (`.jsonl` / NDJSON) export generation with metadata,
  request/response payloads, SSE events, and WebSocket messages.
* Added `CaptureExportFile` and `buildCaptureLogExport` for apps that want to
  trigger or save exports outside the built-in viewer button.
* Updated the full-screen header layout to show status/actions on the first row
  and host on the second row, without the title.
* Normalized exported log states for clearer HTTP and stream log reading.
* Updated the example app to save exported logs with `file_saver` and open the
  latest exported log with `open_filex`.

## 0.1.1

* Added protocol-aware `Copy To Curl` generation for HTTP, SSE, and WebSocket
  captures.
* Updated the Overview footer to show separate `Copy All` and `Copy To Curl`
  actions.
* Added an optional `toast` callback for viewer action feedback. It is not
  required; when omitted, no built-in toast or snackbar is shown.
* Added example app wiring for third-party toast feedback with `fluttertoast`.

## 0.1.0

* Added dependency-free manual capture support for Server-Sent Events (SSE)
  streams and WebSocket sessions.
* Added stream session APIs for inbound, outbound, event, normal close, and
  error close reporting.
* Added protocol-aware viewer states for connected, closed, and failed stream
  captures.
* Added throttled stream message UI refreshes with configurable
  `streamNotifyInterval`; set it to `Duration.zero` for immediate refreshes.
* Protected connected SSE/WebSocket entries from automatic cache cleanup until
  they close or fail.
* Added a compact Messages tab with divider-separated rows and automatic
  scroll-to-bottom behavior when new messages arrive.
* Added file-like payload placeholders for images, videos, audio files, PDFs,
  archives, binary responses, and uploaded files instead of rendering raw file
  content.
* Expanded the example app with real requests, local mock HTTP requests, and
  advanced SSE/WebSocket mock streams.

## 0.0.1

* Initial release with Dio request capture, floating viewer UI, settings page,
  controller-based setup, optional persistence, and payload copy actions.
