class ApiConstants {
  ApiConstants._();

  /// Default address for an Android emulator.
  ///
  /// 10.0.2.2 means the host computer from inside
  /// the Android emulator.
  ///
  /// You can override this when running Flutter:
  ///
  /// flutter run --dart-define=
  /// BACKEND_BASE_URL=http://192.168.0.105:8000
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
