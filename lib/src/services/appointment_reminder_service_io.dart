import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';

import '../data/app_data.dart';
import 'appointment_reminder_service_base.dart';
import 'platform_uri_service.dart';

Future<bool> openAppointmentReminderImpl(UserOrder order) async {
  if (_supportsNativeCalendarReminder) {
    try {
      final bool opened = await Add2Calendar.addEvent2Cal(
        Event(
          title: appointmentReminderTitle(order),
          description: appointmentReminderDescription(order),
          location: appointmentReminderLocation(order),
          startDate: order.scheduledAt,
          endDate: order.scheduledAt.add(appointmentEventDuration(order)),
          iosParams: const IOSParams(reminder: iosReminderLeadTime),
        ),
      );
      if (opened) {
        return true;
      }
    } catch (_) {
      // Fall back to a prefilled calendar URL below.
    }
  }

  return launchExternalUri(appointmentReminderFallbackUri(order));
}

bool get _supportsNativeCalendarReminder {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
