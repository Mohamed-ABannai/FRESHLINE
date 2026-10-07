import '../data/app_data.dart';
import 'appointment_reminder_service_base.dart';
import 'platform_uri_service.dart';

Future<bool> openAppointmentReminderImpl(UserOrder order) {
  return launchExternalUri(appointmentReminderFallbackUri(order));
}
