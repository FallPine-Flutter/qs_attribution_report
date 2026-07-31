import 'package:flutter_test/flutter_test.dart';
import 'package:qs_attribution_report/qs_attribution_report_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('$MethodChannelQsAttributionReport can be created', () {
    expect(
      MethodChannelQsAttributionReport(),
      isA<MethodChannelQsAttributionReport>(),
    );
  });
}
