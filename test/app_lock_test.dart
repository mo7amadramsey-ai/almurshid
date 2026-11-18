import 'package:flutter_test/flutter_test.dart';
import 'package:almurshid/app_lock.dart';

void main() {
  test('re-lock only after 45 s away and never during a strict session', () {
    expect(shouldRelock(away: const Duration(seconds: 44), strictActive: false), isFalse);
    expect(shouldRelock(away: const Duration(seconds: 45), strictActive: false), isTrue);
    expect(shouldRelock(away: const Duration(minutes: 10), strictActive: false), isTrue);
    expect(shouldRelock(away: const Duration(minutes: 10), strictActive: true), isFalse);
    expect(shouldRelock(away: Duration.zero, strictActive: false), isFalse);
  });
}
