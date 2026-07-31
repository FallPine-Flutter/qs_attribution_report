class IosAttributionReportConfig {
  const IosAttributionReportConfig({
    required this.apiUrl,
    required this.aesSecretKey,
    required this.aesIv,
    required this.aesSctToken,
    required this.userId,
    required this.fcmId,
    required this.locale,
    required this.pushState,
  });

  final String apiUrl;
  final String aesSecretKey;
  final String aesIv;
  final String aesSctToken;
  final String userId;
  final String fcmId;
  final String locale;
  final bool pushState;
}
