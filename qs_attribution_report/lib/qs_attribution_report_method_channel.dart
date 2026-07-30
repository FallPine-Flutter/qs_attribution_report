import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'qs_attribution_report_platform_interface.dart';

/// An implementation of [QsAttributionReportPlatform] that uses method channels.
class MethodChannelQsAttributionReport extends QsAttributionReportPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('qs_attribution_report');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
