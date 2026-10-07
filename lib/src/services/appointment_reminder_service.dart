import '../data/app_data.dart';
import 'appointment_reminder_service_stub.dart'
    if (dart.library.io) 'appointment_reminder_service_io.dart'
    if (dart.library.html) 'appointment_reminder_service_web.dart';

Future<bool> openAppointmentReminder(UserOrder order) =>
    openAppointmentReminderImpl(order);
