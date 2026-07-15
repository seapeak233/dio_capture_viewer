/// Describes how to interpret an application-level status code in a JSON
/// response object.
class CaptureBusinessCodeRule {
  const CaptureBusinessCodeRule({
    required this.field,
    required this.successCodes,
  }) : assert(field != '');

  /// Preserves the viewer's original `code == 200` behavior when no custom
  /// rules are supplied to the controller.
  static const List<CaptureBusinessCodeRule> defaultRules =
      <CaptureBusinessCodeRule>[
        CaptureBusinessCodeRule(field: 'code', successCodes: <Object>{200}),
      ];

  /// Top-level field to read from a JSON response object.
  final String field;

  /// Values that represent an application-level success response.
  ///
  /// Numeric strings and numbers are compared by numeric value, so `"10000"`
  /// matches `10000`.
  final Set<Object> successCodes;
}
