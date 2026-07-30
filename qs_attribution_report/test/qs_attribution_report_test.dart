import 'package:flutter_test/flutter_test.dart';
import 'package:qs_attribution_report/qs_attribution_report.dart';
import 'package:qs_attribution_report/qs_attribution_report_platform_interface.dart';
import 'package:qs_attribution_report/qs_attribution_report_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockQsAttributionReportPlatform
    with MockPlatformInterfaceMixin
    implements QsAttributionReportPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final QsAttributionReportPlatform initialPlatform = QsAttributionReportPlatform.instance;

  test('$MethodChannelQsAttributionReport is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelQsAttributionReport>());
  });

  test('getPlatformVersion', () async {
    QsAttributionReport qsAttributionReportPlugin = QsAttributionReport();
    MockQsAttributionReportPlatform fakePlatform = MockQsAttributionReportPlatform();
    QsAttributionReportPlatform.instance = fakePlatform;

    expect(await qsAttributionReportPlugin.getPlatformVersion(), '42');
  });
}
