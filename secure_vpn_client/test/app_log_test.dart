import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/services/app_log.dart';
void main(){test('scrub',(){expect(AppLog.scrubMessage('{"pass":"x"}').redacted,isTrue);});}
