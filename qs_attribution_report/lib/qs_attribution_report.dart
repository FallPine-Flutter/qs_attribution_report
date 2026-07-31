import 'dart:async';
import 'dart:convert';

import 'package:ip_location/ip_location.dart';
import 'package:ip_location/ip_location_model.dart';
import 'package:qs_aes_encrypt/qs_aes_encrypt.dart';
import 'package:qs_device_info/qs_device_info.dart';
import 'package:qs_log/qs_log.dart';
import 'package:qs_net_request/qs_net_request.dart';
import 'package:qs_storage_tool/qs_storage_tool.dart';
import 'package:qs_asa_attribution_info/qs_asa_attribution_info.dart';

import 'failed_attribution_report.dart';
import 'failed_attribution_report_type.dart';
import 'ios_attribution_report_config.dart';

class QsAttributionReport {
  static const String _attributionDataUploadedKey =
      "qs_attribution_report_attribution_info_report_success";
  static const int _maxRetryDelaySeconds = 60;

  static final List<FailedAttributionReport> _failedReports = [];
  static bool _isRetryLoopRunning = false;

  /// 安卓归因数据上报
  static Future<bool> reportAndroidAttributionInfo({
    // 接口地址
    required String apiUrl,
    // AES 加密密钥
    required String aesSecretKey,
    // AES 加密 IV
    required String aesIv,
    // 请求头 sct token
    required String aesSctToken,
    // 用户 ID
    required String userId,
    // 应用包名
    required String packageName,
    required String adjustAdid,
    required String? trackerToken,
    required String? trackerName,
    required String? network,
    required String? campaign,
    required String? adgroup,
    required String? creative,
    required String? clickLabel,
    required String? costType,
    required num? costAmount,
    required String? costCurrency,
    required String? jsonResponse,
  }) async {
    final isUploaded = await QsStorageTool.getBool(
      key: _attributionDataUploadedKey,
    );
    if (isUploaded == true) {
      return true;
    }

    Map<String, dynamic> params = {
      "packageName": packageName,
      "userId": userId,
      "adjustAdid": adjustAdid,
      "trackerToken": trackerToken,
      "trackerName": trackerName,
      "network": network,
      "campaign": campaign,
      "adgroup": adgroup,
      "creative": creative,
      "clickLabel": clickLabel,
      "costType": costType,
      "costAmount": costAmount,
      "costCurrency": costCurrency,
      "osName": _getDeviceType(),
      "appVersion": await _getAppVersion(),
      "source": "app_sdk",
      "raw": _getRawData(jsonResponse),
    };

    final content = _myJsonEncode(params);
    if (content.isEmpty) {
      return false;
    }

    // JSON 或 AES 失败属于本地不可恢复错误，不启动后台重试。
    String encryptedParams = QsAesEncrypt.encrypt(
      secretKey: aesSecretKey,
      iv: aesIv,
      content: content,
    );
    if (encryptedParams.isEmpty) {
      QsLog.error("加密失败");
      return false;
    }

    final success = await _reportEncryptedAttributionInfo(
      apiUrl: apiUrl,
      encryptedParams: encryptedParams,
      aesSctToken: aesSctToken,
    );
    if (success) {
      await _markAttributionDataUploaded();
    }
    return success;
  }

  /// iOS归因数据上报
  static Future<bool> reportIOSAttributionInfo({
    required String apiUrl, // 接口地址
    required String aesSecretKey, // aes secret key
    required String aesIv, // aes iv
    required String aesSctToken, // aes sct token
    required String userId, // 用户ID
    required String fcmId, // 推送 ID
    required String locale, // 用户语言环境，例如 en_US
    required bool pushState, // 推送开关，true/false 或 1/0
  }) async {
    final isUploaded = await QsStorageTool.getBool(
      key: _attributionDataUploadedKey,
    );
    if (isUploaded == true) {
      return true;
    }

    final config = IosAttributionReportConfig(
      apiUrl: apiUrl,
      aesSecretKey: aesSecretKey,
      aesIv: aesIv,
      aesSctToken: aesSctToken,
      userId: userId,
      fcmId: fcmId,
      locale: locale,
      pushState: pushState,
    );

    final success = await _reportIOSAttributionInfo(config: config);
    if (success) {
      await _markAttributionDataUploaded();
    }
    return success;
  }

  static Future<bool> _reportIOSAttributionInfo({
    required IosAttributionReportConfig config,
    bool saveFailedReport = true,
  }) async {
    final attributionToken =
        await QsAsaAttributionInfo.getAttributionToken() ?? "";
    final attribution = await QsAsaAttributionInfo.getAttributionInfo();
    if (attribution == null || attribution.isEmpty) {
      QsLog.error("获取iOS ASA归因信息失败");
      if (saveFailedReport) {
        _saveFailedAttributionReport(
          FailedAttributionReport(
            id: _createFailedReportId(),
            type: FailedAttributionReportType.iosAsaInfo,
            iosConfig: config,
            failedCount: 1,
            nextRetryTimeMs: _nextRetryTimeMs(failedCount: 1),
          ),
        );
        _startFailedReportsRetry();
      }
      return false;
    }

    // 获取位置信息
    final location = await _getLocationByIp();

    Map<String, dynamic> params = {
      "userId": config.userId,
      "fcmId": config.fcmId,
      "appVersion": await _getAppVersion(),
      "deviceType": _getDeviceType(),
      "deviceModel": await _getDeviceModel(),
      "deviceOSVersion": await _getDeviceOSVersion(),
      "timezone": location?.timezone ?? "",
      "locale": config.locale,
      "ipCountry": location?.country ?? "",
      "ipState": location?.regionName ?? "",
      "ipCity": location?.city ?? "",
      "ipAddress": location?.query ?? "",
      "pushState": config.pushState,
      "attributionToken": attributionToken,
      "attribution": attribution,
    };

    final content = _myJsonEncode(params);
    if (content.isEmpty) {
      return false;
    }

    // JSON 或 AES 失败属于本地不可恢复错误，不启动后台重试。
    String encryptedParams = QsAesEncrypt.encrypt(
      secretKey: config.aesSecretKey,
      iv: config.aesIv,
      content: content,
    );
    if (encryptedParams.isEmpty) {
      QsLog.error("加密失败");
      return false;
    }

    if (saveFailedReport) {
      return _reportEncryptedAttributionInfo(
        apiUrl: config.apiUrl,
        encryptedParams: encryptedParams,
        aesSctToken: config.aesSctToken,
      );
    }

    return _postEncryptedAttributionInfo(
      apiUrl: config.apiUrl,
      encryptedParams: encryptedParams,
      aesSctToken: config.aesSctToken,
    );
  }

  static Future<bool> _reportEncryptedAttributionInfo({
    required String apiUrl,
    required String encryptedParams,
    required String aesSctToken,
  }) async {
    final success = await _postEncryptedAttributionInfo(
      apiUrl: apiUrl,
      encryptedParams: encryptedParams,
      aesSctToken: aesSctToken,
    );
    if (success) {
      return true;
    }

    _saveFailedAttributionReport(
      // 只在内存中保存已加密内容，避免把明文归因参数和 AES 信息落盘。
      FailedAttributionReport(
        id: _createFailedReportId(),
        type: FailedAttributionReportType.encryptedData,
        apiUrl: apiUrl,
        data: encryptedParams,
        sct: aesSctToken,
        failedCount: 1,
        nextRetryTimeMs: _nextRetryTimeMs(failedCount: 1),
      ),
    );
    _startFailedReportsRetry();
    return false;
  }

  static Future<bool> _postEncryptedAttributionInfo({
    required String apiUrl,
    required String encryptedParams,
    required String aesSctToken,
  }) async {
    try {
      var response = await QsNetRequest.getInstance().postJson(
        apiUrl,
        parameters: {"data": encryptedParams},
        headers: {"sct": aesSctToken},
        isShowLoading: false,
        onError: (error) {
          QsLog.error("上传归因数据失败: ${error.message}");
        },
      );

      if (response?["code"] != 0) {
        QsLog.error("上传归因数据失败: ${response?["message"] ?? response}");
        return false;
      }
      QsLog.info("上传归因数据成功");
      return true;
    } catch (e) {
      QsLog.error("上传归因数据异常: $e");
      return false;
    }
  }

  static void _startFailedReportsRetry() {
    if (_isRetryLoopRunning) {
      return;
    }

    // 防止同一进程内多次失败或多次恢复调用启动并发补报循环。
    _isRetryLoopRunning = true;
    unawaited(_runFailedReportsRetryLoop());
  }

  static Future<void> _markAttributionDataUploaded() async {
    await QsStorageTool.setBool(key: _attributionDataUploadedKey, value: true);
    _failedReports.clear();
  }

  static Future<void> _runFailedReportsRetryLoop() async {
    try {
      while (true) {
        final reports = _getFailedAttributionReports();
        if (reports.isEmpty) {
          return;
        }

        final nowTimeMs = DateTime.now().millisecondsSinceEpoch;
        // 只处理已到补报时间的数据，未到期的数据继续留在内存队列中。
        final dueReports = reports
            .where((report) => report.nextRetryTimeMs <= nowTimeMs)
            .toList();

        if (dueReports.isEmpty) {
          final nextRetryTimeMs = reports
              .map((report) => report.nextRetryTimeMs)
              .reduce((a, b) => a < b ? a : b);
          final delayMs = nextRetryTimeMs - nowTimeMs;
          await Future.delayed(
            Duration(
              // 队列内可能存在很久以后的时间戳，这里限制单次等待，方便新数据更快被处理。
              milliseconds: delayMs.clamp(0, _maxRetryDelaySeconds * 1000),
            ),
          );
          continue;
        }

        for (final report in dueReports) {
          if (_failedReports.isEmpty) {
            return;
          }

          final success = await _retryFailedAttributionReport(report);
          if (success) {
            await _markAttributionDataUploaded();
            return;
          }

          final failedCount = report.failedCount + 1;
          _replaceFailedAttributionReport(
            report.copyWith(
              failedCount: failedCount,
              nextRetryTimeMs: _nextRetryTimeMs(failedCount: failedCount),
            ),
          );
        }
      }
    } finally {
      _isRetryLoopRunning = false;
    }
  }

  static Future<bool> _retryFailedAttributionReport(
    FailedAttributionReport report,
  ) async {
    switch (report.type) {
      case FailedAttributionReportType.encryptedData:
        return _postEncryptedAttributionInfo(
          apiUrl: report.apiUrl,
          encryptedParams: report.data,
          aesSctToken: report.sct,
        );
      case FailedAttributionReportType.iosAsaInfo:
        final config = report.iosConfig;
        if (config == null) {
          QsLog.error("iOS ASA归因补报配置为空");
          return false;
        }
        return _reportIOSAttributionInfo(
          config: config,
          saveFailedReport: false,
        );
    }
  }

  static List<FailedAttributionReport> _getFailedAttributionReports() {
    return List.of(_failedReports);
  }

  static void _saveFailedAttributionReport(FailedAttributionReport report) {
    _replaceFailedAttributionReport(report);
    QsLog.info("归因数据上报失败，已加入内存后台重试队列");
  }

  static void _replaceFailedAttributionReport(FailedAttributionReport report) {
    final reportIndex = _failedReports.indexWhere(
      (item) => item.id == report.id,
    );
    if (reportIndex >= 0) {
      _failedReports[reportIndex] = report;
    } else {
      _failedReports.add(report);
    }
  }

  static String _createFailedReportId() {
    return "${DateTime.now().microsecondsSinceEpoch}";
  }

  static int _nextRetryTimeMs({required int failedCount}) {
    return DateTime.now()
        .add(_retryDelay(failedCount: failedCount))
        .millisecondsSinceEpoch;
  }

  static Duration _retryDelay({required int failedCount}) {
    // 前三次使用固定短间隔，之后指数退避，但最大等待不超过 1 分钟。
    if (failedCount <= 1) {
      return const Duration(seconds: 2);
    }
    if (failedCount == 2) {
      return const Duration(seconds: 5);
    }
    if (failedCount == 3) {
      return const Duration(seconds: 10);
    }

    var delaySeconds = 10;
    for (var i = 3; i < failedCount; i++) {
      delaySeconds *= 2;
      if (delaySeconds >= _maxRetryDelaySeconds) {
        return const Duration(seconds: _maxRetryDelaySeconds);
      }
    }
    return Duration(seconds: delaySeconds);
  }

  /// 根据 IP 获取省市区信息
  static Future<IpLocationModel?> _getLocationByIp() async {
    try {
      IpLocationModel? location = await IpLocation.getIpLocation();
      return location;
    } catch (e) {
      QsLog.error("获取位置信息失败: $e");
      return null;
    }
  }

  /// 自定义 JSON 编码
  static String _myJsonEncode(Object? params) {
    try {
      return jsonEncode(params);
    } catch (e) {
      QsLog.error("jsonEncode error: $e");
      return "";
    }
  }

  static String _getDeviceType() {
    try {
      return QsDeviceInfo.getDeviceType();
    } catch (e) {
      QsLog.error("获取设备类型失败: $e");
      return "";
    }
  }

  static Future<String> _getAppVersion() async {
    try {
      return await QsDeviceInfo.getAppVersion() ?? "";
    } catch (e) {
      QsLog.error("获取应用版本失败: $e");
      return "";
    }
  }

  static Future<String> _getDeviceModel() async {
    try {
      return await QsDeviceInfo.getDeviceModel();
    } catch (e) {
      QsLog.error("获取设备型号失败: $e");
      return "";
    }
  }

  static Future<String> _getDeviceOSVersion() async {
    try {
      return await QsDeviceInfo.getDeviceOSVersion();
    } catch (e) {
      QsLog.error("获取设备系统版本失败: $e");
      return "";
    }
  }

  static dynamic _getRawData(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(value);
    } catch (error) {
      QsLog.error("归因数据解析失败: $error");
      return null;
    }
  }
}
