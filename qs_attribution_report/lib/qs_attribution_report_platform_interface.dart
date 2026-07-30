import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'qs_attribution_report_method_channel.dart';

abstract class QsAttributionReportPlatform extends PlatformInterface {
  /// Constructs a QsAttributionReportPlatform.
  QsAttributionReportPlatform() : super(token: _token);

  static final Object _token = Object();

  static QsAttributionReportPlatform _instance = MethodChannelQsAttributionReport();

  /// The default instance of [QsAttributionReportPlatform] to use.
  ///
  /// Defaults to [MethodChannelQsAttributionReport].
  static QsAttributionReportPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QsAttributionReportPlatform] when
  /// they register themselves.
  static set instance(QsAttributionReportPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
