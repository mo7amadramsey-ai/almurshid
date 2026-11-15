import 'package:flutter_test/flutter_test.dart';
import 'package:almurshid/crawler/due.dart';

void main() {
  submissionTests();
  test('english due date with time', () {
    final d = parseDueDate('<div><strong>Opened:</strong> Sunday, 1 November 2026, 8:00 AM</div>'
        '<div><strong>Due:</strong> Monday, 2 December 2026, 11:59 PM</div>');
    expect(d, DateTime(2026, 12, 2, 23, 59));
  });
  test('month-first format', () {
    expect(parseDueDate('<p>Due: Tuesday, December 3, 2026, 9:30 AM</p>'), DateTime(2026, 12, 3, 9, 30));
  });
  test('arabic levantine month and Arabic-Indic digits', () {
    final d = parseDueDate('<div>تاريخ التسليم: الاثنين، ٢ كانون الأول ٢٠٢٦، 11:59 م</div>');
    expect(d, DateTime(2026, 12, 2, 23, 59));
  });
  test('quiz closes', () {
    expect(parseDueDate('<p>This quiz closes on Friday, 20 November 2026, 12:00 AM</p>'), DateTime(2026, 11, 20, 0, 0));
  });
  test('nothing found', () {
    expect(parseDueDate('<p>No dates here</p>'), isNull);
  });
}

void submissionTests() {
  test('submission status is read from the status label only', () {
    expect(parseSubmitted('<body>Submission status Submitted for grading Grading status Not graded</body>'), isTrue);
    expect(parseSubmitted('<body>Submission status No attempt Grading status Not graded</body>'), isFalse);
    expect(parseSubmitted('<body>Submission status Draft (not submitted)</body>'), isFalse);
    expect(parseSubmitted('<body>حالة التسليم تم التسليم للتقييم</body>'), isTrue);
    expect(parseSubmitted('<body>work must be submitted for grading by Friday</body>'), isNull);
  });
}
