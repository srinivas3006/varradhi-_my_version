import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/utils/log_safe.dart';

void main() {
  test('full mobile numbers are masked, in any format', () {
    for (final raw in [
      '9876543210',
      '+919876543210',
      '+91 98765 43210',
      '098765-43210',
    ]) {
      final out = LogSafe.scrub('mobile=$raw failed');
      expect(out, isNot(contains('9876543210')), reason: raw);
      expect(out, isNot(contains('98765')), reason: raw);
      expect(out, contains('******10'), reason: raw);
    }
  });

  test('tokens are hidden', () {
    const jwt = 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjEifQ'
        '.eyJwaG9uZV9udW1iZXIiOiIrOTE5ODc2NTQzMjEwIn0'
        '.c2lnbmF0dXJlc2lnbmF0dXJlc2lnbmF0dXJl';
    final out = LogSafe.scrub('id_token=$jwt; Authorization: Bearer abc.def');
    expect(out, isNot(contains('eyJhbGci')));
    expect(out, isNot(contains('abc.def')));
    expect(out, contains('***TOKEN***'));
  });

  test('OTP codes are hidden', () {
    expect(LogSafe.scrub('code 123456 rejected'), 'code **** rejected');
  });

  test('ordinary text is left readable', () {
    expect(LogSafe.scrub('[firebase_auth/invalid-verification-code] bad'),
        '[firebase_auth/invalid-verification-code] bad');
  });

  test('maskMobile keeps only the ends', () {
    expect(LogSafe.maskMobile('9876543210'), '98******10');
    expect(LogSafe.maskMobile(null), '***');
  });
}
