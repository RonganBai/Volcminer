class LedToggleResult {
  const LedToggleResult({
    required this.success,
    required this.message,
    required this.targets,
  });

  final bool success;
  final String message;
  final List<String> targets;
}
