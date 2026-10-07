import '../data/app_data.dart';

const Duration defaultAppointmentDuration = Duration(hours: 1);
const Duration iosReminderLeadTime = Duration(hours: 1);

Duration appointmentEventDuration(UserOrder order) =>
    order.appointmentDuration ?? defaultAppointmentDuration;

String appointmentReminderTitle(UserOrder order) =>
    '${order.serviceName} at ${order.salonName}';

String appointmentReminderDescription(UserOrder order) {
  final List<String> lines = <String>[
    'FreshLine appointment',
    'Service: ${order.serviceName}',
    'Specialist: ${order.employeeName}',
    'Visit mode: ${order.visitMode}',
  ];

  final String? location = appointmentReminderLocation(order);
  if (location != null) {
    lines.add('Location: $location');
  }

  return lines.join('\n');
}

String? appointmentReminderLocation(UserOrder order) {
  final String location = (order.address ?? order.salonName).trim();
  return location.isEmpty ? null : location;
}

Uri appointmentReminderFallbackUri(UserOrder order) {
  final Map<String, String> queryParameters = <String, String>{
    'action': 'TEMPLATE',
    'text': appointmentReminderTitle(order),
    'details': appointmentReminderDescription(order),
    'dates':
        '${_calendarTimestamp(order.scheduledAt.toUtc())}/${_calendarTimestamp(order.scheduledAt.add(appointmentEventDuration(order)).toUtc())}',
  };

  final String? location = appointmentReminderLocation(order);
  if (location != null) {
    queryParameters['location'] = location;
  }

  return Uri.https('calendar.google.com', '/calendar/render', queryParameters);
}

String _calendarTimestamp(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}T${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}Z';
}
