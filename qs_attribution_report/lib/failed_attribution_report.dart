class FailedAttributionReport {
  const FailedAttributionReport({
    required this.id,
    required this.apiUrl,
    required this.data,
    required this.sct,
    required this.failedCount,
    required this.nextRetryTimeMs,
  });

  final String id;
  final String apiUrl;
  final String data;
  final String sct;
  final int failedCount;
  final int nextRetryTimeMs;

  factory FailedAttributionReport.fromJson(Map<String, dynamic> json) {
    return FailedAttributionReport(
      id: json["id"] as String? ?? "",
      apiUrl: json["apiUrl"] as String? ?? "",
      data: json["data"] as String? ?? "",
      sct: json["sct"] as String? ?? "",
      failedCount: json["failedCount"] as int? ?? 0,
      nextRetryTimeMs: json["nextRetryTimeMs"] as int? ?? 0,
    );
  }

  FailedAttributionReport copyWith({
    String? id,
    String? apiUrl,
    String? data,
    String? sct,
    int? failedCount,
    int? nextRetryTimeMs,
  }) {
    return FailedAttributionReport(
      id: id ?? this.id,
      apiUrl: apiUrl ?? this.apiUrl,
      data: data ?? this.data,
      sct: sct ?? this.sct,
      failedCount: failedCount ?? this.failedCount,
      nextRetryTimeMs: nextRetryTimeMs ?? this.nextRetryTimeMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "apiUrl": apiUrl,
      "data": data,
      "sct": sct,
      "failedCount": failedCount,
      "nextRetryTimeMs": nextRetryTimeMs,
    };
  }
}
