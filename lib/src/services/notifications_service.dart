import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/app_data.dart';
import '../utils/network_request.dart';

abstract class NotificationsService {
  Future<List<AppNotificationItem>> loadNotifications({required AppUser user});

  void dispose() {}
}

class SupabaseNotificationsService implements NotificationsService {
  SupabaseNotificationsService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<AppNotificationItem>> loadNotifications({
    required AppUser user,
  }) async {
    final String filterQuery = await _filterQuery(user);
    final Uri uri = Uri.parse(
      '$supabaseUrl/rest/v1/notifications?select=title,title_ar,body,body_ar,created_at,is_read,audience$filterQuery&order=created_at.desc',
    );
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.get(uri, headers: _supabaseHeaders()),
      fallback: 'Freshline could not load notifications right now.',
    );

    if (response.statusCode == 404 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      return const <AppNotificationItem>[];
    }

    final String? transientMessage = freshlineTransientHttpErrorMessage(
      response.statusCode,
    );
    if (transientMessage != null) {
      throw StateError(transientMessage);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <AppNotificationItem>[];
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      return const <AppNotificationItem>[];
    }

    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .map((Map<String, dynamic> row) => _notificationFromJson(user, row))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _client.close();
  }

  Map<String, String> _supabaseHeaders() => <String, String>{
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $supabaseAnonKey',
  };

  Future<String> _filterQuery(AppUser user) async {
    final String? profileId = user.profileId?.trim();
    switch (user.role) {
      case AppRole.customer:
        if (profileId != null && profileId.isNotEmpty) {
          return '&or=${Uri.encodeQueryComponent('(audience.eq.all_users,and(audience.eq.single_user,target_profile_id.eq.$profileId))')}';
        }
        return '&audience=eq.all_users';
      case AppRole.salonOwner:
      case AppRole.employee:
        final List<String> audienceFilters = <String>['audience.eq.all_salons'];
        if (profileId != null && profileId.isNotEmpty) {
          audienceFilters.add(
            'and(audience.eq.single_user,target_profile_id.eq.$profileId)',
          );
          final String salonId = await _loadSalonNotificationTargetId(user);
          if (salonId.isNotEmpty) {
            audienceFilters.add(
              'and(audience.eq.single_salon,target_salon_id.eq.$salonId)',
            );
          }
        }
        if (audienceFilters.length == 1) {
          return '&audience=eq.all_salons';
        }
        return '&or=${Uri.encodeQueryComponent('(${audienceFilters.join(',')})')}';
      case AppRole.admin:
        return '&audience=eq.admins';
    }
  }

  Future<String> _loadSalonNotificationTargetId(AppUser user) async {
    final String profileId = user.profileId?.trim() ?? '';
    if (profileId.isEmpty) {
      return '';
    }

    late final Uri uri;
    if (user.role == AppRole.salonOwner) {
      uri = Uri.parse(
        '$supabaseUrl/rest/v1/salons?select=id&owner_id=eq.$profileId&limit=1',
      );
    } else if (user.role == AppRole.employee) {
      uri = Uri.parse(
        '$supabaseUrl/rest/v1/salon_employees?select=salon_id&profile_id=eq.$profileId&is_active=eq.true&limit=1',
      );
    } else {
      return '';
    }

    final http.Response response = await performFreshlineHttpRequest(
      () => _client.get(uri, headers: _supabaseHeaders()),
      fallback: 'Freshline could not load notifications right now.',
    );
    final String? transientMessage = freshlineTransientHttpErrorMessage(
      response.statusCode,
    );
    if (transientMessage != null) {
      throw StateError(transientMessage);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return '';
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic> || decoded.isEmpty) {
      return '';
    }

    final Map<String, dynamic> row = Map<String, dynamic>.from(
      decoded.first as Map,
    );
    return _readString(row['salon_id'] ?? row['id']);
  }

  AppNotificationItem _notificationFromJson(
    AppUser user,
    Map<String, dynamic> row,
  ) {
    final String title = _readString(row['title'], fallback: 'Notification');
    final String titleAr = _readString(row['title_ar']);
    final String message = _readString(row['body']);
    final String messageAr = _readString(row['body_ar']);
    final String details =
        '$title $titleAr $message $messageAr ${_readString(row['audience'])}'
            .toLowerCase();

    return AppNotificationItem(
      title: title,
      message: message,
      titleAr: titleAr.isEmpty ? null : titleAr,
      messageAr: messageAr.isEmpty ? null : messageAr,
      icon: _notificationIconKey(details),
      createdAt:
          DateTime.tryParse(_readString(row['created_at'])) ?? DateTime.now(),
      unread: !_readBool(row['is_read']),
    );
  }
}

class MemoryNotificationsService implements NotificationsService {
  MemoryNotificationsService({List<AppNotificationItem>? notifications})
    : notifications = notifications ?? <AppNotificationItem>[];

  final List<AppNotificationItem> notifications;

  @override
  Future<List<AppNotificationItem>> loadNotifications({
    required AppUser user,
  }) async {
    return List<AppNotificationItem>.from(notifications);
  }

  @override
  void dispose() {}
}

String _readString(Object? value, {String fallback = ''}) {
  final String text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }

  final String normalized = (value ?? '').toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

String _notificationIconKey(String details) {
  if (details.contains('order') ||
      details.contains('product') ||
      details.contains('طلب') ||
      details.contains('منتج')) {
    return 'cart';
  }
  if (details.contains('booking') ||
      details.contains('appointment') ||
      details.contains('salon') ||
      details.contains('حجز') ||
      details.contains('موعد') ||
      details.contains('صالون')) {
    return 'calendar';
  }
  return 'sparkles';
}
