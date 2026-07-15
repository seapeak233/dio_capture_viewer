# dio_capture_viewer example

This Flutter app demonstrates `dio_capture_viewer` with local mock data.

The page has three request groups:

- Real requests to JSONPlaceholder.
- Mock HTTP requests through an in-app `HttpClientAdapter`.
- Mock SSE and WebSocket sessions that emit 10 different messages, one every
  3 seconds, with normal-close and error-close examples.

Run it with:

```sh
flutter run
```

Desktop targets are included as well:

```sh
flutter run -d macos
flutter run -d windows
flutter run -d linux
```
