import 'package:flutter_test/flutter_test.dart';

import 'package:freshline_tt/src/data/app_data.dart';

void main() {
  test('timeSlots covers working hours through 10 PM', () {
    expect(timeSlots, isNotEmpty);
    expect(timeSlots.first, '9:00 AM');
    expect(timeSlots, contains('6:00 PM'));
    expect(timeSlots.last, '10:00 PM');
  });
}

