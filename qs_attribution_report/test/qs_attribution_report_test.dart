import 'package:flutter_test/flutter_test.dart';
import 'package:qs_attribution_report/qs_attribution_report_platform_interface.dart';
import 'package:qs_attribution_report/qs_attribution_report_method_channel.dart';

void main() {
  final QsAttributionReportPlatform initialPlatform =
      QsAttributionReportPlatform.instance;

  test('$MethodChannelQsAttributionReport is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelQsAttributionReport>());
  });
}
