import 'failed_attribution_report_type.dart';
import 'ios_attribution_report_config.dart';

class FailedAttributionReport {
  const FailedAttributionReport({
    required this.id,
    required this.type,
    required this.failedCount,
    required this.nextRetryTimeMs,
    this.apiUrl = "",
    this.data = "",
    this.sct = "",
    this.iosConfig,
  });

  final String id;
  final FailedAttributionReportType type;
  final String apiUrl;
  final String data;
  final String sct;
  final int failedCount;
  final int nextRetryTimeMs;
  final IosAttributionReportConfig? iosConfig;

  FailedAttributionReport copyWith({
    String? id,
    FailedAttributionReportType? type,
    String? apiUrl,
    String? data,
    String? sct,
    int? failedCount,
    int? nextRetryTimeMs,
    IosAttributionReportConfig? iosConfig,
  }) {
    return FailedAttributionReport(
      id: id ?? this.id,
      type: type ?? this.type,
      apiUrl: apiUrl ?? this.apiUrl,
      data: data ?? this.data,
      sct: sct ?? this.sct,
      failedCount: failedCount ?? this.failedCount,
      nextRetryTimeMs: nextRetryTimeMs ?? this.nextRetryTimeMs,
      iosConfig: iosConfig ?? this.iosConfig,
    );
  }
}
