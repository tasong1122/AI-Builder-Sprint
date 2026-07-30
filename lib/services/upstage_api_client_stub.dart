class UpstageApiClient {
  // Signals that direct Upstage API calls are unavailable on this platform.
  Future<String> createReminderMessage({
    required String apiKey,
    required String prompt,
  }) {
    throw UnsupportedError('Upstage API is not available on this platform.');
  }
}
