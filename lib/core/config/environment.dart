/// Build environments. Selected at compile time via `--dart-define=ENV=...`,
/// never at runtime in a production build.
enum Environment {
  dev(label: 'Development', shortCode: 'DEV'),
  staging(label: 'Staging', shortCode: 'STG'),
  prod(label: 'Production', shortCode: 'PROD');

  const Environment({required this.label, required this.shortCode});

  final String label;
  final String shortCode;

  bool get isProduction => this == Environment.prod;

  /// Whether developer affordances (the component gallery, the environment
  /// switcher, verbose logging) are available.
  bool get allowsDeveloperTools => this != Environment.prod;

  static Environment fromName(String? name) => values.firstWhere(
    (e) => e.name == name?.toLowerCase(),
    orElse: () => Environment.dev,
  );
}
