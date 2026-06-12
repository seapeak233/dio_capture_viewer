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
