import 'dart:math' as math;

import '../config/app_config.dart' show supabaseUrl;

enum AppRole { customer, salonOwner, employee, admin }

extension AppRoleLabel on AppRole {
  String get value {
    switch (this) {
      case AppRole.customer:
        return 'customer';
      case AppRole.salonOwner:
        return 'salon_owner';
      case AppRole.employee:
        return 'employee';
      case AppRole.admin:
        return 'admin';
    }
  }

  String get label {
    switch (this) {
      case AppRole.customer:
        return 'Customer';
      case AppRole.salonOwner:
        return 'Salon Owner';
      case AppRole.employee:
        return 'Employee';
      case AppRole.admin:
        return 'Admin';
    }
  }

  String get description {
    switch (this) {
      case AppRole.customer:
        return 'Browse salons, book services, shop products, and manage your account.';
      case AppRole.salonOwner:
        return 'Manage your salon, packages, services, team, earnings, and bookings.';
      case AppRole.employee:
        return 'See your assigned bookings, manage your profile, and follow your salon schedule.';
      case AppRole.admin:
        return 'Review salons, monitor the platform, payments, admins, and notifications.';
    }
  }
}

AppRole appRoleFromValue(String rawValue) {
  switch (rawValue.trim().toLowerCase()) {
    case 'salon_owner':
      return AppRole.salonOwner;
    case 'employee':
      return AppRole.employee;
    case 'admin':
      return AppRole.admin;
    case 'customer':
    default:
      return AppRole.customer;
  }
}

const String adminOwnerEmail = 'admin.com';

const String freshlineInvoicePrefix = 'FRH';
const int _freshlineInvoiceDigits = 10;
final math.Random _freshlineInvoiceRandom = math.Random();

String generateFreshlineInvoiceNumber() {
  final int timePart = DateTime.now().millisecondsSinceEpoch % 100000000;
  final int randomPart = _freshlineInvoiceRandom.nextInt(100);
  return '$freshlineInvoicePrefix${timePart.toString().padLeft(8, '0')}${randomPart.toString().padLeft(2, '0')}';
}

String normalizeFreshlineInvoiceNumber(String? rawValue, {String? sourceId}) {
  final String candidate = (rawValue ?? '').trim().toUpperCase();
  final String digits = candidate.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isNotEmpty) {
    final String paddedDigits = digits.padLeft(_freshlineInvoiceDigits, '0');
    final int startIndex = paddedDigits.length > _freshlineInvoiceDigits
        ? paddedDigits.length - _freshlineInvoiceDigits
        : 0;
    return '$freshlineInvoicePrefix${paddedDigits.substring(startIndex)}';
  }

  final String seed = (sourceId ?? candidate).trim();
  if (seed.isEmpty) {
    return generateFreshlineInvoiceNumber();
  }

  int hash = 0;
  for (final int codeUnit in seed.codeUnits) {
    hash = (hash * 131 + codeUnit) % 10000000000;
  }
  return '$freshlineInvoicePrefix${hash.toString().padLeft(_freshlineInvoiceDigits, '0')}';
}

class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  final int id;
  final String imagePath;
  final String title;
  final String subtitle;
}

class Salon {
  const Salon({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.rating,
    required this.reviews,
    required this.location,
    required this.distance,
    required this.services,
    this.description = '',
    this.nameAr,
    this.locationAr,
    this.descriptionAr,
    this.phone = '',
    this.priceLabel = '\$\$',
    this.homeServiceAvailable = false,
    this.address,
    this.addressAr,
    this.latitude,
    this.longitude,
    this.packages = const <ServicePackage>[],
    this.serviceItems = const <ServiceItem>[],
  });

  final String id;
  final String name;
  final String imagePath;
  final double rating;
  final int reviews;
  final String location;
  final String distance;
  final List<String> services;
  final String description;
  final String? nameAr;
  final String? locationAr;
  final String? descriptionAr;
  final String phone;
  final String priceLabel;
  final bool homeServiceAvailable;
  final String? address;
  final String? addressAr;
  final double? latitude;
  final double? longitude;
  final List<ServicePackage> packages;
  final List<ServiceItem> serviceItems;

  factory Salon.fromSupabase(
    Map<String, dynamic> json, {
    required String fallbackImagePath,
  }) {
    final String name = _stringValue(
      json['name'] ?? json['title'] ?? json['salon_name'],
      fallback: 'FreshLine Salon',
    );
    final String city = _stringValue(
      json['city'] ?? json['location'] ?? json['area'],
      fallback: 'Manama',
    );

    return Salon(
      id: _stringValue(json['id'], fallback: name.toLowerCase()),
      name: name,
      nameAr: _nullableStringValue(json['name_ar']),
      imagePath: normalizeCatalogImageUrl(
        json['image_url'] ?? json['image'] ?? json['image_path'],
        fallback: fallbackImagePath,
      ),
      rating: _doubleValue(json['rating'], fallback: 0),
      reviews: _intValue(
        json['reviews'] ?? json['reviews_count'] ?? json['review_count'],
        fallback: 0,
      ),
      location: city,
      locationAr:
          _nullableStringValue(json['city_ar']) ??
          _nullableStringValue(json['location_ar']),
      distance: _stringValue(json['distance'], fallback: ''),
      services: _stringListValue(
        json['services'] ?? json['service_names'] ?? json['tags'],
      ),
      description: _stringValue(
        json['description'] ?? json['about'] ?? json['bio'],
        fallback:
            'A FreshLine salon with appointment booking, service packages, and product recommendations.',
      ),
      descriptionAr: _nullableStringValue(json['description_ar']),
      phone: _stringValue(
        json['phone'] ?? json['phone_number'] ?? json['mobile'],
        fallback: '',
      ),
      priceLabel: _stringValue(
        json['price_label'] ?? json['price_tier'],
        fallback: '\$\$',
      ),
      homeServiceAvailable:
          json['home_service_available'] == true ||
          json['supports_home_service'] == true ||
          _stringValue(
            json['visit_mode'] ?? json['service_mode'],
            fallback: '',
          ).toLowerCase().contains('home'),
      address: _nullableStringValue(json['address']),
      addressAr: _nullableStringValue(json['address_ar']),
      latitude: _nullableDoubleValue(json['latitude'] ?? json['lat']),
      longitude: _nullableDoubleValue(json['longitude'] ?? json['lng']),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.price,
    required this.rating,
    this.reviewsCount = 0,
    required this.category,
    this.description = '',
    this.nameAr,
    this.categoryAr,
    this.descriptionAr,
    this.salonId,
    this.stock = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String imagePath;
  final num price;
  final double rating;
  final int reviewsCount;
  final String category;
  final String description;
  final String? nameAr;
  final String? categoryAr;
  final String? descriptionAr;
  final String? salonId;
  final int stock;
  final bool isActive;

  factory Product.fromSupabase(
    Map<String, dynamic> json, {
    required String fallbackImagePath,
  }) {
    final String name = _stringValue(
      json['name'] ?? json['title'] ?? json['product_name'],
      fallback: 'FreshLine Product',
    );

    return Product(
      id: _stringValue(json['id'], fallback: name.toLowerCase()),
      name: name,
      nameAr: _nullableStringValue(json['name_ar']),
      imagePath: normalizeCatalogImageUrl(
        json['image_url'] ?? json['image'] ?? json['image_path'],
        fallback: fallbackImagePath,
      ),
      price: _numValue(json['price'], fallback: 0),
      rating: _doubleValue(json['rating'], fallback: 0),
      reviewsCount: _intValue(
        json['reviews_count'] ?? json['review_count'],
        fallback: 0,
      ),
      category: _stringValue(json['category'], fallback: 'General'),
      categoryAr: _nullableStringValue(json['category_ar']),
      description: _stringValue(
        json['description'] ?? json['details'] ?? json['about'],
        fallback:
            'A FreshLine product selected to support hair care, styling, and salon aftercare.',
      ),
      descriptionAr: _nullableStringValue(json['description_ar']),
      salonId: _nullableStringValue(json['salon_id']),
      stock: _intValue(json['stock'], fallback: 0),
      isActive: json['is_active'] != false,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? imagePath,
    num? price,
    double? rating,
    int? reviewsCount,
    String? category,
    String? description,
    String? nameAr,
    String? categoryAr,
    String? descriptionAr,
    String? salonId,
    int? stock,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      category: category ?? this.category,
      description: description ?? this.description,
      nameAr: nameAr ?? this.nameAr,
      categoryAr: categoryAr ?? this.categoryAr,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      salonId: salonId ?? this.salonId,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
    );
  }
}

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.role,
    required this.rating,
    this.profileId,
    this.email = '',
    this.phone = '',
    this.reviewsCount = 0,
    this.monthlySalary = 0,
    this.supportsInShop = true,
    this.supportsHomeService = false,
    this.canLogin = false,
    this.isActive = true,
    this.availabilityLabel = 'Available today',
    this.workStartMinutes,
    this.workEndMinutes,
    this.breakStartMinutes,
    this.breakEndMinutes,
    this.salaryPaidForMonth,
    this.salaryLastPaidAt,
  });

  final String id;
  final String name;
  final String imagePath;
  final String role;
  final double rating;
  final String? profileId;
  final String email;
  final String phone;
  final int reviewsCount;
  final double monthlySalary;
  final bool supportsInShop;
  final bool supportsHomeService;
  final bool canLogin;
  final bool isActive;
  final String availabilityLabel;
  final int? workStartMinutes;
  final int? workEndMinutes;
  final int? breakStartMinutes;
  final int? breakEndMinutes;
  final DateTime? salaryPaidForMonth;
  final DateTime? salaryLastPaidAt;

  DateTime get salaryDueDate {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  bool isSalaryReceivedForMonth([DateTime? referenceDate]) {
    final DateTime? paidForMonth = salaryPaidForMonth;
    if (paidForMonth == null) {
      return false;
    }
    final DateTime reference = referenceDate ?? DateTime.now();
    return paidForMonth.year == reference.year &&
        paidForMonth.month == reference.month;
  }

  String salaryStatusLabel([DateTime? referenceDate]) {
    return isSalaryReceivedForMonth(referenceDate) ? 'Received' : 'Pending';
  }

  factory Employee.fromSupabase(
    Map<String, dynamic> json, {
    required String fallbackImagePath,
  }) {
    return Employee(
      id: _stringValue(
        json['id'],
        fallback: _stringValue(
          json['profile_id'] ?? json['email'],
          fallback: 'freshline-employee',
        ),
      ),
      profileId: _nullableStringValue(json['profile_id']),
      name: _stringValue(
        json['full_name'] ?? json['name'],
        fallback: 'FreshLine Employee',
      ),
      imagePath: normalizeProfileImageUrl(
        json['image_url'] ??
            json['avatar_url'] ??
            json['image_path'] ??
            fallbackImagePath,
      ),
      role: _stringValue(json['role_title'], fallback: 'Salon Employee'),
      rating: _doubleValue(json['rating'], fallback: 0),
      reviewsCount: _intValue(json['reviews_count'], fallback: 0),
      email: _stringValue(json['email'], fallback: ''),
      phone: _stringValue(json['phone'], fallback: ''),
      monthlySalary: _doubleValue(json['monthly_salary_bhd'], fallback: 0),
      supportsInShop: json['supports_in_shop'] != false,
      supportsHomeService: json['supports_home_service'] == true,
      canLogin: json['can_login'] == true,
      isActive: json['is_active'] != false,
      availabilityLabel: _stringValue(
        json['availability_label'],
        fallback: json['is_active'] == false
            ? 'Account paused'
            : 'Available today',
      ),
      workStartMinutes: _readTimeMinutes(json['work_start_time']),
      workEndMinutes: _readTimeMinutes(json['work_end_time']),
      breakStartMinutes: _readTimeMinutes(json['break_start_time']),
      breakEndMinutes: _readTimeMinutes(json['break_end_time']),
      salaryPaidForMonth: _readDateTime(json['salary_paid_for_month']),
      salaryLastPaidAt: _readDateTime(json['salary_last_paid_at']),
    );
  }

  Employee copyWith({
    String? id,
    String? name,
    String? imagePath,
    String? role,
    double? rating,
    String? profileId,
    String? email,
    String? phone,
    int? reviewsCount,
    double? monthlySalary,
    bool? supportsInShop,
    bool? supportsHomeService,
    bool? canLogin,
    bool? isActive,
    String? availabilityLabel,
    int? workStartMinutes,
    int? workEndMinutes,
    int? breakStartMinutes,
    int? breakEndMinutes,
    DateTime? salaryPaidForMonth,
    DateTime? salaryLastPaidAt,
    bool clearSalaryPaidForMonth = false,
    bool clearSalaryLastPaidAt = false,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      role: role ?? this.role,
      rating: rating ?? this.rating,
      profileId: profileId ?? this.profileId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      supportsInShop: supportsInShop ?? this.supportsInShop,
      supportsHomeService: supportsHomeService ?? this.supportsHomeService,
      canLogin: canLogin ?? this.canLogin,
      isActive: isActive ?? this.isActive,
      availabilityLabel: availabilityLabel ?? this.availabilityLabel,
      workStartMinutes: workStartMinutes ?? this.workStartMinutes,
      workEndMinutes: workEndMinutes ?? this.workEndMinutes,
      breakStartMinutes: breakStartMinutes ?? this.breakStartMinutes,
      breakEndMinutes: breakEndMinutes ?? this.breakEndMinutes,
      salaryPaidForMonth: clearSalaryPaidForMonth
          ? null
          : salaryPaidForMonth ?? this.salaryPaidForMonth,
      salaryLastPaidAt: clearSalaryLastPaidAt
          ? null
          : salaryLastPaidAt ?? this.salaryLastPaidAt,
    );
  }
}

class EmployeeScheduleEntry {
  const EmployeeScheduleEntry({
    required this.id,
    required this.employeeId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    this.supportsHomeService = false,
    this.supportsInShop = true,
    this.isAvailable = true,
  });

  final String id;
  final String employeeId;
  /// 0 = Sunday, 6 = Saturday.
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final bool supportsHomeService;
  final bool supportsInShop;
  final bool isAvailable;

  factory EmployeeScheduleEntry.fromSupabase(Map<String, dynamic> json) {
    final int? start = _readTimeMinutes(json['start_time']);
    final int? end = _readTimeMinutes(json['end_time']);
    return EmployeeScheduleEntry(
      id: _stringValue(
        json['id'],
        fallback: 'schedule-${DateTime.now().millisecondsSinceEpoch}',
      ),
      employeeId: _stringValue(json['employee_id'], fallback: ''),
      weekday: (_intValue(json['weekday'], fallback: 0).clamp(0, 6) as num).toInt(),
      startMinutes:
          ((start ?? 9 * 60).clamp(0, 24 * 60) as num).toInt(),
      endMinutes: ((end ?? 22 * 60).clamp(0, 24 * 60) as num).toInt(),
      supportsHomeService: json['supports_home_service'] == true,
      supportsInShop: json['supports_in_shop'] != false,
      isAvailable: json['is_available'] != false,
    );
  }
}

class EmployeeSalaryPayment {
  const EmployeeSalaryPayment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.salonId,
    required this.amount,
    required this.salaryMonth,
    required this.confirmedAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String salonId;
  final double amount;
  final DateTime salaryMonth;
  final DateTime confirmedAt;

  factory EmployeeSalaryPayment.fromSupabase(
    Map<String, dynamic> json, {
    required String employeeName,
  }) {
    final DateTime now = DateTime.now();
    return EmployeeSalaryPayment(
      id: _stringValue(
        json['id'],
        fallback:
            '${_stringValue(json['employee_id'], fallback: 'employee')}-${_stringValue(json['salary_month'], fallback: now.toIso8601String())}',
      ),
      employeeId: _stringValue(json['employee_id'], fallback: ''),
      employeeName: employeeName,
      salonId: _stringValue(json['salon_id'], fallback: ''),
      amount: _doubleValue(json['amount_bhd'], fallback: 0),
      salaryMonth: (_readDateTime(json['salary_month']) ?? now).toLocal(),
      confirmedAt:
          (_readDateTime(json['confirmed_at'] ?? json['created_at']) ?? now)
              .toLocal(),
    );
  }

  EmployeeSalaryPayment copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? salonId,
    double? amount,
    DateTime? salaryMonth,
    DateTime? confirmedAt,
  }) {
    return EmployeeSalaryPayment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      salonId: salonId ?? this.salonId,
      amount: amount ?? this.amount,
      salaryMonth: salaryMonth ?? this.salaryMonth,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}

class ServicePackage {
  const ServicePackage({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.description,
    this.nameAr,
    this.descriptionAr,
    this.salonId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final num price;
  final String duration;
  final String description;
  final String? nameAr;
  final String? descriptionAr;
  final String? salonId;
  final bool isActive;

  factory ServicePackage.fromSupabase(Map<String, dynamic> json) {
    return ServicePackage(
      id: _stringValue(json['id'], fallback: 'package'),
      salonId: _nullableStringValue(json['salon_id']),
      name: _stringValue(json['name'], fallback: 'Salon Package'),
      nameAr: _nullableStringValue(json['name_ar']),
      price: _numValue(json['price_bhd'] ?? json['price'], fallback: 0),
      duration: _durationLabelFromSupabaseValue(
        json['duration_minutes'] ?? json['duration'],
      ),
      description: _stringValue(json['description'], fallback: ''),
      descriptionAr: _nullableStringValue(json['description_ar']),
      isActive: json['is_active'] != false,
    );
  }

  ServicePackage copyWith({
    String? id,
    String? name,
    num? price,
    String? duration,
    String? description,
    String? nameAr,
    String? descriptionAr,
    String? salonId,
    bool? isActive,
  }) {
    return ServicePackage(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      nameAr: nameAr ?? this.nameAr,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      salonId: salonId ?? this.salonId,
      isActive: isActive ?? this.isActive,
    );
  }
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    this.description = '',
    this.nameAr,
    this.descriptionAr,
    this.salonId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final num price;
  final String duration;
  final String description;
  final String? nameAr;
  final String? descriptionAr;
  final String? salonId;
  final bool isActive;

  factory ServiceItem.fromSupabase(Map<String, dynamic> json) {
    return ServiceItem(
      id: _stringValue(json['id'], fallback: 'service'),
      salonId: _nullableStringValue(json['salon_id']),
      name: _stringValue(json['name'], fallback: 'Salon Service'),
      nameAr: _nullableStringValue(json['name_ar']),
      price: _numValue(json['price_bhd'] ?? json['price'], fallback: 0),
      duration: _durationLabelFromSupabaseValue(
        json['duration_minutes'] ?? json['duration'],
      ),
      description: _stringValue(json['description'], fallback: ''),
      descriptionAr: _nullableStringValue(json['description_ar']),
      isActive: json['is_active'] != false,
    );
  }

  ServiceItem copyWith({
    String? id,
    String? name,
    num? price,
    String? duration,
    String? description,
    String? nameAr,
    String? descriptionAr,
    String? salonId,
    bool? isActive,
  }) {
    return ServiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      nameAr: nameAr ?? this.nameAr,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      salonId: salonId ?? this.salonId,
      isActive: isActive ?? this.isActive,
    );
  }
}

class BranchLocation {
  const BranchLocation({
    required this.id,
    required this.name,
    required this.address,
  });

  final String id;
  final String name;
  final String address;
}

class BookingSelection {
  const BookingSelection({
    required this.serviceId,
    required this.serviceName,
    this.serviceNameAr,
    required this.price,
    required this.salonName,
    this.salonNameAr,
    this.appointmentDuration,
  });

  final String serviceId;
  final String serviceName;
  final String? serviceNameAr;
  final num price;
  final String salonName;
  final String? salonNameAr;
  final Duration? appointmentDuration;
}

class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    this.address = '',
    this.role = AppRole.customer,
    this.avatarPath = defaultProfileImageUrl,
    this.profileId,
    this.isAdminOwner = false,
    this.isEmailTwoFactorEnabled = false,
    this.isEmailVerified = true,
    this.preferredLanguage = 'EN',
  });

  final String name;
  final String email;
  final String phone;
  final String city;
  final String address;
  final AppRole role;
  final String avatarPath;
  final String? profileId;
  final bool isAdminOwner;
  final bool isEmailTwoFactorEnabled;
  final bool isEmailVerified;
  final String preferredLanguage;

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? city,
    String? address,
    AppRole? role,
    String? avatarPath,
    String? profileId,
    bool? isAdminOwner,
    bool? isEmailTwoFactorEnabled,
    bool? isEmailVerified,
    String? preferredLanguage,
  }) {
    return AppUser(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      address: address ?? this.address,
      role: role ?? this.role,
      avatarPath: avatarPath ?? this.avatarPath,
      profileId: profileId ?? this.profileId,
      isAdminOwner: isAdminOwner ?? this.isAdminOwner,
      isEmailTwoFactorEnabled:
          isEmailTwoFactorEnabled ?? this.isEmailTwoFactorEnabled,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'city': city,
      'address': address,
      'role': role.value,
      'avatar_path': avatarPath,
      'profile_id': profileId,
      'is_admin_owner': isAdminOwner,
      'is_email_two_factor_enabled': isEmailTwoFactorEnabled,
      'is_email_verified': isEmailVerified,
      'preferred_language': preferredLanguage,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final String preferredLanguageRaw = (json['preferred_language'] ?? 'EN')
        .toString()
        .trim()
        .toUpperCase();
    return AppUser(
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      role: appRoleFromValue((json['role'] ?? '').toString()),
      avatarPath: normalizeProfileImageUrl(json['avatar_path']),
      profileId: (json['profile_id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['profile_id'] ?? '').toString().trim(),
      isAdminOwner: json['is_admin_owner'] == true,
      isEmailTwoFactorEnabled: json['is_email_two_factor_enabled'] == true,
      isEmailVerified: json['is_email_verified'] != false,
      preferredLanguage: preferredLanguageRaw == 'AR' ? 'AR' : 'EN',
    );
  }
}

class SignInAttempt {
  const SignInAttempt.authenticated({required this.user})
    : challengeEmail = null,
      challengeProfileId = null,
      requestedRole = null;

  const SignInAttempt.requiresEmailOtp({
    required this.challengeEmail,
    required this.challengeProfileId,
    required this.requestedRole,
  }) : user = null;

  final AppUser? user;
  final String? challengeEmail;
  final String? challengeProfileId;
  final AppRole? requestedRole;

  bool get requiresEmailOtp => user == null;
}

enum SalonRequestStatus { pending, approved, rejected, needsInfo }

extension SalonRequestStatusValue on SalonRequestStatus {
  String get value {
    switch (this) {
      case SalonRequestStatus.pending:
        return 'pending';
      case SalonRequestStatus.approved:
        return 'approved';
      case SalonRequestStatus.rejected:
        return 'rejected';
      case SalonRequestStatus.needsInfo:
        return 'needs_info';
    }
  }

  String get label {
    switch (this) {
      case SalonRequestStatus.pending:
        return 'Pending Review';
      case SalonRequestStatus.approved:
        return 'Approved';
      case SalonRequestStatus.rejected:
        return 'Rejected';
      case SalonRequestStatus.needsInfo:
        return 'Needs Info';
    }
  }
}

SalonRequestStatus salonRequestStatusFromValue(String rawValue) {
  switch (rawValue.trim().toLowerCase()) {
    case 'approved':
      return SalonRequestStatus.approved;
    case 'rejected':
      return SalonRequestStatus.rejected;
    case 'needs_info':
      return SalonRequestStatus.needsInfo;
    case 'pending':
    default:
      return SalonRequestStatus.pending;
  }
}

enum SalonUploadType { salonImage, commercialRegistration, governmentLicense }

extension SalonUploadTypeMeta on SalonUploadType {
  String get label {
    switch (this) {
      case SalonUploadType.salonImage:
        return 'Salon Image';
      case SalonUploadType.commercialRegistration:
        return 'Commercial Registration';
      case SalonUploadType.governmentLicense:
        return 'Government License';
    }
  }
}

class UploadedSalonAsset {
  const UploadedSalonAsset({
    required this.fileName,
    required this.storagePath,
    required this.publicUrl,
    required this.contentType,
  });

  final String fileName;
  final String storagePath;
  final String publicUrl;
  final String contentType;

  factory UploadedSalonAsset.fromPublicUrl(
    String? publicUrl, {
    required String fallbackName,
    String contentType = 'application/octet-stream',
  }) {
    final String resolvedUrl = (publicUrl ?? '').trim();
    final Uri? uri = resolvedUrl.isEmpty ? null : Uri.tryParse(resolvedUrl);
    final List<String> segments = uri?.pathSegments ?? const <String>[];
    final int publicIndex = segments.indexOf('public');
    final List<String> trailingSegments =
        publicIndex >= 0 && publicIndex + 2 <= segments.length
        ? segments.sublist(publicIndex + 2)
        : segments;
    final String storagePath = trailingSegments.join('/');
    final String fileName = trailingSegments.isNotEmpty
        ? Uri.decodeComponent(trailingSegments.last)
        : fallbackName;

    return UploadedSalonAsset(
      fileName: fileName,
      storagePath: storagePath,
      publicUrl: resolvedUrl,
      contentType: contentType,
    );
  }
}

class SalonRegistrationRequest {
  const SalonRegistrationRequest({
    this.id,
    required this.ownerId,
    required this.salonName,
    required this.salonEmail,
    required this.salonPhone,
    required this.city,
    required this.address,
    required this.locationUrl,
    this.websiteUrl,
    this.salonImage,
    this.commercialRegistration,
    this.governmentLicense,
    this.status = SalonRequestStatus.pending,
    this.adminNote,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String ownerId;
  final String salonName;
  final String salonEmail;
  final String salonPhone;
  final String city;
  final String address;
  final String locationUrl;
  final String? websiteUrl;
  final UploadedSalonAsset? salonImage;
  final UploadedSalonAsset? commercialRegistration;
  final UploadedSalonAsset? governmentLicense;
  final SalonRequestStatus status;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isEditable =>
      status == SalonRequestStatus.pending ||
      status == SalonRequestStatus.needsInfo;

  bool get isApproved => status == SalonRequestStatus.approved;

  SalonRegistrationRequest copyWith({
    String? id,
    String? ownerId,
    String? salonName,
    String? salonEmail,
    String? salonPhone,
    String? city,
    String? address,
    String? locationUrl,
    String? websiteUrl,
    UploadedSalonAsset? salonImage,
    UploadedSalonAsset? commercialRegistration,
    UploadedSalonAsset? governmentLicense,
    SalonRequestStatus? status,
    String? adminNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearAdminNote = false,
  }) {
    return SalonRegistrationRequest(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      salonName: salonName ?? this.salonName,
      salonEmail: salonEmail ?? this.salonEmail,
      salonPhone: salonPhone ?? this.salonPhone,
      city: city ?? this.city,
      address: address ?? this.address,
      locationUrl: locationUrl ?? this.locationUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      salonImage: salonImage ?? this.salonImage,
      commercialRegistration:
          commercialRegistration ?? this.commercialRegistration,
      governmentLicense: governmentLicense ?? this.governmentLicense,
      status: status ?? this.status,
      adminNote: clearAdminNote ? null : adminNote ?? this.adminNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SalonOwnerSession {
  const SalonOwnerSession({required this.user, this.request});

  final AppUser user;
  final SalonRegistrationRequest? request;
}

class SalonMapInfo {
  const SalonMapInfo({
    required this.salonId,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String salonId;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
}

class AppNotificationItem {
  AppNotificationItem({
    required this.title,
    required this.message,
    required this.icon,
    this.titleAr,
    this.messageAr,
    DateTime? createdAt,
    this.unread = false,
  }) : createdAt = createdAt ?? DateTime.now();

  final String title;
  final String message;
  final String icon;
  final String? titleAr;
  final String? messageAr;
  final DateTime createdAt;
  final bool unread;

  String get timeLabel => formatNotificationTimestamp(createdAt);

  String localizedTitleForLanguage(String languageCode) {
    if (languageCode.trim().toUpperCase() == 'AR') {
      final String localized = (titleAr ?? '').trim();
      if (localized.isNotEmpty) {
        return localized;
      }
    }
    return title;
  }

  String localizedMessageForLanguage(String languageCode) {
    if (languageCode.trim().toUpperCase() == 'AR') {
      final String localized = (messageAr ?? '').trim();
      if (localized.isNotEmpty) {
        return localized;
      }
    }
    return message;
  }

  String localizedTimeLabelForLanguage(String languageCode) {
    return formatNotificationTimestampForLanguage(
      createdAt,
      languageCode: languageCode,
    );
  }

  AppNotificationItem copyWith({
    String? title,
    String? message,
    String? icon,
    String? titleAr,
    String? messageAr,
    DateTime? createdAt,
    bool? unread,
  }) {
    return AppNotificationItem(
      title: title ?? this.title,
      message: message ?? this.message,
      icon: icon ?? this.icon,
      titleAr: titleAr ?? this.titleAr,
      messageAr: messageAr ?? this.messageAr,
      createdAt: createdAt ?? this.createdAt,
      unread: unread ?? this.unread,
    );
  }
}

class SupportTopic {
  const SupportTopic({required this.question, required this.answer});

  final String question;
  final String answer;
}

class CatalogData {
  const CatalogData({required this.salons, required this.products});

  final List<Salon> salons;
  final List<Product> products;
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.rewardPercent,
    required this.features,
    this.nameAr,
    this.featuresAr = const <String>[],
  });

  final String id;
  final String name;
  final num price;
  final int rewardPercent;
  final List<String> features;
  final String? nameAr;
  final List<String> featuresAr;
}

const double salonMonthlySubscriptionPrice = 30;
const double salonYearlySubscriptionPrice = 280;

enum SubscriptionCycleOption { monthly, yearly }

SubscriptionCycleOption subscriptionCycleFromValue(String? rawValue) {
  switch ((rawValue ?? '').trim().toLowerCase()) {
    case 'yearly':
      return SubscriptionCycleOption.yearly;
    case 'monthly':
    default:
      return SubscriptionCycleOption.monthly;
  }
}

extension SubscriptionCycleOptionLabel on SubscriptionCycleOption {
  String get label {
    switch (this) {
      case SubscriptionCycleOption.monthly:
        return 'Monthly';
      case SubscriptionCycleOption.yearly:
        return 'Yearly';
    }
  }

  double get salonPrice {
    switch (this) {
      case SubscriptionCycleOption.monthly:
        return salonMonthlySubscriptionPrice;
      case SubscriptionCycleOption.yearly:
        return salonYearlySubscriptionPrice;
    }
  }
}

class CustomerSubscriptionStatus {
  const CustomerSubscriptionStatus({
    required this.plan,
    this.startsAt,
    this.endsAt,
    this.autoRenew = true,
  });

  final SubscriptionPlan plan;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool autoRenew;

  CustomerSubscriptionStatus copyWith({
    SubscriptionPlan? plan,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? autoRenew,
  }) {
    return CustomerSubscriptionStatus(
      plan: plan ?? this.plan,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      autoRenew: autoRenew ?? this.autoRenew,
    );
  }
}

class SalonSubscriptionStatus {
  const SalonSubscriptionStatus({
    required this.cycle,
    required this.amount,
    this.expiresAt,
    this.autoRenew = false,
  });

  final SubscriptionCycleOption cycle;
  final double amount;
  final DateTime? expiresAt;
  final bool autoRenew;

  SalonSubscriptionStatus copyWith({
    SubscriptionCycleOption? cycle,
    double? amount,
    DateTime? expiresAt,
    bool? autoRenew,
  }) {
    return SalonSubscriptionStatus(
      cycle: cycle ?? this.cycle,
      amount: amount ?? this.amount,
      expiresAt: expiresAt ?? this.expiresAt,
      autoRenew: autoRenew ?? this.autoRenew,
    );
  }
}

class ManagedUserRecord {
  const ManagedUserRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.avatarUrl,
    required this.role,
    required this.isActive,
    required this.bookingsCount,
    required this.productOrdersCount,
    required this.totalSpent,
    required this.loyaltyPoints,
    this.createdAt,
    this.lastLoginAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String avatarUrl;
  final AppRole role;
  final bool isActive;
  final int bookingsCount;
  final int productOrdersCount;
  final double totalSpent;
  final int loyaltyPoints;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  String get statusLabel => isActive ? 'Active' : 'Disabled';

  ManagedUserRecord copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? city,
    String? avatarUrl,
    AppRole? role,
    bool? isActive,
    int? bookingsCount,
    int? productOrdersCount,
    double? totalSpent,
    int? loyaltyPoints,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return ManagedUserRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      bookingsCount: bookingsCount ?? this.bookingsCount,
      productOrdersCount: productOrdersCount ?? this.productOrdersCount,
      totalSpent: totalSpent ?? this.totalSpent,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

class AdminCustomerSubscriptionRecord {
  const AdminCustomerSubscriptionRecord({
    required this.user,
    required this.subscription,
  });

  final ManagedUserRecord user;
  final CustomerSubscriptionStatus subscription;
}

class AdminSalonRecord {
  const AdminSalonRecord({
    required this.salon,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.isActive,
    this.ownerAvatarUrl = defaultProfileImageUrl,
    this.subscriptionStatus,
  });

  final Salon salon;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String ownerAvatarUrl;
  final bool isActive;
  final SalonSubscriptionStatus? subscriptionStatus;
}

class AdminSalonRequestRecord {
  const AdminSalonRequestRecord({
    required this.request,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    this.ownerAvatarUrl = defaultProfileImageUrl,
    this.reviewedByName,
    this.reviewedByEmail,
    this.reviewedAt,
  });

  final SalonRegistrationRequest request;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String ownerAvatarUrl;
  final String? reviewedByName;
  final String? reviewedByEmail;
  final DateTime? reviewedAt;
}

class AdminActivityLogRecord {
  const AdminActivityLogRecord({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actorEmail,
    required this.actorRole,
    required this.actionType,
    required this.summary,
    required this.createdAt,
    this.targetTable,
    this.targetId,
  });

  final String id;
  final String actorId;
  final String actorName;
  final String actorEmail;
  final AppRole actorRole;
  final String actionType;
  final String summary;
  final DateTime createdAt;
  final String? targetTable;
  final String? targetId;
}

class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.customerSubscriptionRevenue,
    required this.salonSubscriptionRevenue,
    required this.bookingRevenue,
    required this.productRevenue,
    required this.totalRevenue,
    required this.customerCount,
    required this.salonCount,
    required this.requestCount,
    required this.customerSubscriptionCount,
    required this.salonSubscriptionCount,
    required this.productCount,
    required this.productOrderCount,
  });

  final double customerSubscriptionRevenue;
  final double salonSubscriptionRevenue;
  final double bookingRevenue;
  final double productRevenue;
  final double totalRevenue;
  final int customerCount;
  final int salonCount;
  final int requestCount;
  final int customerSubscriptionCount;
  final int salonSubscriptionCount;
  final int productCount;
  final int productOrderCount;
}

class AdminSnapshot {
  const AdminSnapshot({
    required this.metrics,
    required this.users,
    required this.salons,
    required this.adminSalons,
    required this.requests,
    required this.coupons,
    required this.admins,
    required this.customerSubscriptions,
    required this.adminProducts,
    required this.activityLogs,
  });

  final AdminDashboardMetrics metrics;
  final List<ManagedUserRecord> users;
  final List<Salon> salons;
  final List<AdminSalonRecord> adminSalons;
  final List<AdminSalonRequestRecord> requests;
  final List<PromoCouponRecord> coupons;
  final List<AdminTeamMember> admins;
  final List<AdminCustomerSubscriptionRecord> customerSubscriptions;
  final List<Product> adminProducts;
  final List<AdminActivityLogRecord> activityLogs;
}

class PromoCouponRecord {
  const PromoCouponRecord({
    this.id,
    required this.code,
    this.description,
    this.descriptionAr,
    required this.discountPercent,
    this.targetPlanId,
    this.minOrderAmountBhd,
    this.maxDiscountBhd,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.updatedAt,
    this.salonId,
  });

  final String? id;
  final String code;
  final String? description;
  final String? descriptionAr;
  final int discountPercent;
  final String? targetPlanId;
  final double? minOrderAmountBhd;
  final double? maxDiscountBhd;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? salonId;

  String get normalizedCode => code.trim().toUpperCase();
  bool get appliesToAllPlans => (targetPlanId ?? '').trim().isEmpty;
  bool get hasMinimumOrder => (minOrderAmountBhd ?? 0) > 0;
  bool get hasMaxDiscount => (maxDiscountBhd ?? 0) > 0;
  bool get hasSchedule => startsAt != null || endsAt != null;
  bool get isWelcomeFirstOrderCoupon => normalizedCode == 'FRESH20';
  bool get isSalonCoupon => (salonId ?? '').trim().isNotEmpty;
  SubscriptionPlan? get targetPlan => subscriptionPlanById(targetPlanId);

  bool matchesPlan(SubscriptionPlan? plan) {
    if (appliesToAllPlans) {
      return true;
    }
    return plan?.id == targetPlanId;
  }

  bool isAvailableAt(DateTime value) {
    if (startsAt != null && value.isBefore(startsAt!)) {
      return false;
    }
    if (endsAt != null && value.isAfter(endsAt!)) {
      return false;
    }
    return true;
  }

  bool meetsMinimumOrder(num subtotal) {
    if (!hasMinimumOrder) {
      return true;
    }
    return subtotal >= (minOrderAmountBhd ?? 0);
  }

  bool isEligibleForOrderCount(int orderCount) {
    if (!isWelcomeFirstOrderCoupon) {
      return true;
    }
    return orderCount <= 0;
  }

  String? orderCountValidationMessage(int orderCount) {
    if (!isWelcomeFirstOrderCoupon || orderCount <= 0) {
      return null;
    }
    return 'Fresh20% welcome coupon has ended because this account already has orders.';
  }

  int? get scheduledDurationDays {
    if (startsAt == null || endsAt == null) {
      return null;
    }
    final DateTime startDate = DateTime(
      startsAt!.year,
      startsAt!.month,
      startsAt!.day,
    );
    final DateTime endDate = DateTime(endsAt!.year, endsAt!.month, endsAt!.day);
    return endDate.difference(startDate).inDays + 1;
  }

  PromoCouponRecord copyWith({
    String? id,
    String? code,
    String? description,
    String? descriptionAr,
    int? discountPercent,
    String? targetPlanId,
    double? minOrderAmountBhd,
    double? maxDiscountBhd,
    bool? isActive,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? salonId,
    bool clearTargetPlanId = false,
    bool clearMinOrderAmountBhd = false,
    bool clearMaxDiscountBhd = false,
    bool clearStartsAt = false,
    bool clearEndsAt = false,
  }) {
    return PromoCouponRecord(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      discountPercent: discountPercent ?? this.discountPercent,
      targetPlanId: clearTargetPlanId
          ? null
          : targetPlanId ?? this.targetPlanId,
      minOrderAmountBhd: clearMinOrderAmountBhd
          ? null
          : minOrderAmountBhd ?? this.minOrderAmountBhd,
      maxDiscountBhd: clearMaxDiscountBhd
          ? null
          : maxDiscountBhd ?? this.maxDiscountBhd,
      isActive: isActive ?? this.isActive,
      startsAt: clearStartsAt ? null : startsAt ?? this.startsAt,
      endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      salonId: salonId ?? this.salonId,
    );
  }
}

class PaymentCardInfo {
  const PaymentCardInfo({
    required this.id,
    required this.holderName,
    required this.brand,
    required this.last4,
    required this.expiryLabel,
  });

  final String id;
  final String holderName;
  final String brand;
  final String last4;
  final String expiryLabel;

  String get displayLabel => '$brand •••• $last4';
}

class DeliveryLocationSelection {
  const DeliveryLocationSelection({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  String get shortLabel =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  String get fullLabel =>
      'Pinned location: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

class SavedCustomerAddress {
  const SavedCustomerAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.location,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String addressLine;
  final DeliveryLocationSelection location;
  final bool isDefault;

  String get subtitle => '$addressLine\n${location.fullLabel}';
}

class ProductOrderLineItem {
  const ProductOrderLineItem({
    required this.productId,
    required this.productName,
    this.productNameAr,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String productName;
  final String? productNameAr;
  final int quantity;
  final num unitPrice;

  num get lineTotal => unitPrice * quantity;
}

class RatedOrderProductItem {
  const RatedOrderProductItem({
    required this.productId,
    required this.productName,
    this.productNameAr,
    required this.quantity,
    required this.unitPrice,
    this.reviewSubmitted = false,
    this.existingRating,
  });

  final String productId;
  final String productName;
  final String? productNameAr;
  final int quantity;
  final num unitPrice;
  final bool reviewSubmitted;
  final double? existingRating;

  num get lineTotal => unitPrice * quantity;

  RatedOrderProductItem copyWith({
    String? productId,
    String? productName,
    String? productNameAr,
    int? quantity,
    num? unitPrice,
    bool? reviewSubmitted,
    double? existingRating,
  }) {
    return RatedOrderProductItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productNameAr: productNameAr ?? this.productNameAr,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      reviewSubmitted: reviewSubmitted ?? this.reviewSubmitted,
      existingRating: existingRating ?? this.existingRating,
    );
  }
}

enum UserOrderType { salonBooking, productOrder }

class UserOrder {
  const UserOrder({
    required this.id,
    required this.type,
    required this.salonName,
    this.salonNameAr,
    required this.serviceName,
    this.serviceNameAr,
    required this.employeeName,
    this.employeeNameAr,
    required this.visitMode,
    this.visitModeAr,
    required this.scheduledAt,
    required this.total,
    required this.statusLabel,
    this.statusLabelAr,
    required this.loyaltyPointsGained,
    this.invoiceNumber,
    this.customerName,
    this.customerPhone,
    this.appointmentDuration,
    this.salonId,
    this.employeeId,
    this.address,
    this.addressDetails,
    this.location,
    this.cardLabel,
    this.productItems = const <RatedOrderProductItem>[],
    this.salonReviewSubmitted = false,
    this.employeeReviewSubmitted = false,
    this.reminderAdded = false,
  });

  final String id;
  final UserOrderType type;
  final String salonName;
  final String? salonNameAr;
  final String serviceName;
  final String? serviceNameAr;
  final String employeeName;
  final String? employeeNameAr;
  final String? invoiceNumber;
  final String? customerName;
  final String? customerPhone;
  final String visitMode;
  final String? visitModeAr;
  final DateTime scheduledAt;
  final num total;
  final String statusLabel;
  final String? statusLabelAr;
  final int loyaltyPointsGained;
  final Duration? appointmentDuration;
  final String? salonId;
  final String? employeeId;
  final String? address;
  final String? addressDetails;
  final DeliveryLocationSelection? location;
  final String? cardLabel;
  final List<RatedOrderProductItem> productItems;
  final bool salonReviewSubmitted;
  final bool employeeReviewSubmitted;
  final bool reminderAdded;

  bool get isProductOrder => type == UserOrderType.productOrder;
  bool get isClaimedProductOrder =>
      isProductOrder && (employeeId ?? '').trim().isNotEmpty;
  bool get isUnassignedProductOrder => isProductOrder && !isClaimedProductOrder;
  bool get hasPendingProductReviews =>
      productItems.any((RatedOrderProductItem item) => !item.reviewSubmitted);
  String get displayInvoiceNumber =>
      normalizeFreshlineInvoiceNumber(invoiceNumber, sourceId: id);

  UserOrder copyWith({
    String? id,
    UserOrderType? type,
    String? salonName,
    String? salonNameAr,
    String? serviceName,
    String? serviceNameAr,
    String? employeeName,
    String? employeeNameAr,
    String? invoiceNumber,
    String? customerName,
    String? customerPhone,
    String? visitMode,
    String? visitModeAr,
    DateTime? scheduledAt,
    num? total,
    String? statusLabel,
    String? statusLabelAr,
    int? loyaltyPointsGained,
    Duration? appointmentDuration,
    String? salonId,
    String? employeeId,
    String? address,
    String? addressDetails,
    DeliveryLocationSelection? location,
    String? cardLabel,
    List<RatedOrderProductItem>? productItems,
    bool? salonReviewSubmitted,
    bool? employeeReviewSubmitted,
    bool? reminderAdded,
  }) {
    return UserOrder(
      id: id ?? this.id,
      type: type ?? this.type,
      salonName: salonName ?? this.salonName,
      salonNameAr: salonNameAr ?? this.salonNameAr,
      serviceName: serviceName ?? this.serviceName,
      serviceNameAr: serviceNameAr ?? this.serviceNameAr,
      employeeName: employeeName ?? this.employeeName,
      employeeNameAr: employeeNameAr ?? this.employeeNameAr,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      visitMode: visitMode ?? this.visitMode,
      visitModeAr: visitModeAr ?? this.visitModeAr,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      total: total ?? this.total,
      statusLabel: statusLabel ?? this.statusLabel,
      statusLabelAr: statusLabelAr ?? this.statusLabelAr,
      loyaltyPointsGained: loyaltyPointsGained ?? this.loyaltyPointsGained,
      appointmentDuration: appointmentDuration ?? this.appointmentDuration,
      salonId: salonId ?? this.salonId,
      employeeId: employeeId ?? this.employeeId,
      address: address ?? this.address,
      addressDetails: addressDetails ?? this.addressDetails,
      location: location ?? this.location,
      cardLabel: cardLabel ?? this.cardLabel,
      productItems: productItems ?? this.productItems,
      salonReviewSubmitted: salonReviewSubmitted ?? this.salonReviewSubmitted,
      employeeReviewSubmitted:
          employeeReviewSubmitted ?? this.employeeReviewSubmitted,
      reminderAdded: reminderAdded ?? this.reminderAdded,
    );
  }
}

class CustomerCommerceSnapshot {
  const CustomerCommerceSnapshot({
    required this.activeOrders,
    required this.completedOrders,
    required this.bookedSlotKeys,
    required this.loyaltyPoints,
  });

  final List<UserOrder> activeOrders;
  final List<UserOrder> completedOrders;
  final Set<String> bookedSlotKeys;
  final int loyaltyPoints;
}

class SalonFinanceSnapshot {
  const SalonFinanceSnapshot({
    required this.bookingRevenue,
    required this.productRevenue,
    required this.subscriptionCost,
    required this.salaryCost,
    required this.bookingProfit,
    required this.completedBookings,
    required this.upcomingBookings,
  });

  final double bookingRevenue;
  final double productRevenue;
  final double subscriptionCost;
  final double salaryCost;
  final double bookingProfit;
  final int completedBookings;
  final int upcomingBookings;

  double get totalRevenue => bookingRevenue + productRevenue;
}

class SalonWorkspaceSnapshot {
  const SalonWorkspaceSnapshot({
    required this.salon,
    required this.employees,
    required this.bookings,
    required this.finance,
    this.productOrders = const <UserOrder>[],
    this.salaryPayments = const <EmployeeSalaryPayment>[],
    this.packages = const <ServicePackage>[],
    this.services = const <ServiceItem>[],
    this.products = const <Product>[],
    this.coupons = const <PromoCouponRecord>[],
    this.subscriptionStatus,
    this.currentEmployee,
  });

  final Salon salon;
  final List<Employee> employees;
  final List<UserOrder> bookings;
  final SalonFinanceSnapshot finance;
  final List<UserOrder> productOrders;
  final List<EmployeeSalaryPayment> salaryPayments;
  final List<ServicePackage> packages;
  final List<ServiceItem> services;
  final List<Product> products;
  final List<PromoCouponRecord> coupons;
  final SalonSubscriptionStatus? subscriptionStatus;
  final Employee? currentEmployee;
}

class OnboardingSlide {
  const OnboardingSlide({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  final String imagePath;
  final String title;
  final String subtitle;
}

class SocialContact {
  const SocialContact({required this.label, required this.value, this.uri});

  final String label;
  final String value;
  final String? uri;
}

class PlatformUserSnapshot {
  const PlatformUserSnapshot({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.avatarPath,
    required this.statusLabel,
    required this.bookingsCount,
    required this.productOrdersCount,
    required this.totalSpent,
    required this.loyaltyPoints,
    required this.lastActivity,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String avatarPath;
  final String statusLabel;
  final int bookingsCount;
  final int productOrdersCount;
  final double totalSpent;
  final int loyaltyPoints;
  final String lastActivity;
}

class AdminTeamMember {
  const AdminTeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.avatarPath,
    required this.roleTitle,
    required this.storagePath,
    required this.lastAction,
    this.isActive = true,
    this.isOwner = false,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String avatarPath;
  final String roleTitle;
  final String storagePath;
  final String lastAction;
  final bool isActive;
  final bool isOwner;

  AdminTeamMember copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? city,
    String? avatarPath,
    String? roleTitle,
    String? storagePath,
    String? lastAction,
    bool? isActive,
    bool? isOwner,
  }) {
    return AdminTeamMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      avatarPath: avatarPath ?? this.avatarPath,
      roleTitle: roleTitle ?? this.roleTitle,
      storagePath: storagePath ?? this.storagePath,
      lastAction: lastAction ?? this.lastAction,
      isActive: isActive ?? this.isActive,
      isOwner: isOwner ?? this.isOwner,
    );
  }
}

const String defaultProfileImageUrl =
    '$supabaseUrl/storage/v1/object/public/All/profileimage.jpeg';
const String legacyCatalogImageUrl =
    '$supabaseUrl/storage/v1/object/public/All/defaultimage.jpeg';
const String legacyUnifiedCatalogImageUrl =
    '$supabaseUrl/storage/v1/object/public/All/dd.png';
const String defaultSalonImageUrl =
    '$supabaseUrl/storage/v1/object/public/All/FrslineS.png';
const String defaultProductImageUrl =
    '$supabaseUrl/storage/v1/object/public/All/FrslineP.png';
const String defaultCatalogImageUrl = defaultProductImageUrl;

enum PlatformMediaType { profile, salon, product }

extension PlatformMediaTypeValue on PlatformMediaType {
  String get value {
    switch (this) {
      case PlatformMediaType.profile:
        return 'profile';
      case PlatformMediaType.salon:
        return 'salon';
      case PlatformMediaType.product:
        return 'product';
    }
  }
}

class PlatformMediaDefaults {
  const PlatformMediaDefaults({
    this.profileImageUrl = defaultProfileImageUrl,
    this.salonImageUrl = defaultSalonImageUrl,
    this.productImageUrl = defaultProductImageUrl,
    this.profileRevision = 'profile-default',
    this.salonRevision = 'salon-default',
    this.productRevision = 'product-default',
  });

  final String profileImageUrl;
  final String salonImageUrl;
  final String productImageUrl;
  final String profileRevision;
  final String salonRevision;
  final String productRevision;

  PlatformMediaDefaults copyWith({
    String? profileImageUrl,
    String? salonImageUrl,
    String? productImageUrl,
    String? profileRevision,
    String? salonRevision,
    String? productRevision,
  }) {
    return PlatformMediaDefaults(
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      salonImageUrl: salonImageUrl ?? this.salonImageUrl,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      profileRevision: profileRevision ?? this.profileRevision,
      salonRevision: salonRevision ?? this.salonRevision,
      productRevision: productRevision ?? this.productRevision,
    );
  }

  factory PlatformMediaDefaults.fromSupabaseRows(
    List<Map<String, dynamic>> rows,
  ) {
    PlatformMediaDefaults defaults = const PlatformMediaDefaults();
    for (final Map<String, dynamic> row in rows) {
      final String mediaType = _stringValue(
        row['media_type'],
        fallback: '',
      ).toLowerCase();
      final String defaultUrl = _stringValue(row['default_url'], fallback: '');
      final DateTime? updatedAt = _readDateTime(row['updated_at']);
      final String revision =
          updatedAt?.toUtc().toIso8601String() ?? defaultUrl;
      switch (mediaType) {
        case 'profile':
          defaults = defaults.copyWith(
            profileImageUrl: defaultUrl.isEmpty
                ? defaults.profileImageUrl
                : defaultUrl,
            profileRevision: revision,
          );
          break;
        case 'salon':
          defaults = defaults.copyWith(
            salonImageUrl: defaultUrl.isEmpty
                ? defaults.salonImageUrl
                : defaultUrl,
            salonRevision: revision,
          );
          break;
        case 'product':
          defaults = defaults.copyWith(
            productImageUrl: defaultUrl.isEmpty
                ? defaults.productImageUrl
                : defaultUrl,
            productRevision: revision,
          );
          break;
        default:
          break;
      }
    }
    return defaults;
  }
}

PlatformMediaDefaults _platformMediaDefaults = const PlatformMediaDefaults();

PlatformMediaDefaults get currentPlatformMediaDefaults =>
    _platformMediaDefaults;

void applyPlatformMediaDefaults(PlatformMediaDefaults defaults) {
  _platformMediaDefaults = defaults;
}

String currentDefaultProfileImageUrl({bool cacheBusted = true}) {
  return _resolvedDefaultImageUrl(
    _platformMediaDefaults.profileImageUrl,
    _platformMediaDefaults.profileRevision,
    cacheBusted: cacheBusted,
  );
}

String currentDefaultSalonImageUrl({bool cacheBusted = true}) {
  return _resolvedDefaultImageUrl(
    _platformMediaDefaults.salonImageUrl,
    _platformMediaDefaults.salonRevision,
    cacheBusted: cacheBusted,
  );
}

String currentDefaultProductImageUrl({bool cacheBusted = true}) {
  return _resolvedDefaultImageUrl(
    _platformMediaDefaults.productImageUrl,
    _platformMediaDefaults.productRevision,
    cacheBusted: cacheBusted,
  );
}

String normalizeProfileImageUrl(Object? value) {
  final String resolved = _stringValue(value, fallback: '');
  if (resolved.isEmpty ||
      _matchesManagedImage(resolved, defaultProfileImageUrl)) {
    return currentDefaultProfileImageUrl();
  }
  if (_matchesManagedImage(resolved, _platformMediaDefaults.profileImageUrl)) {
    return currentDefaultProfileImageUrl();
  }
  return resolved;
}

bool isDefaultProfileImageSelection(Object? value) {
  final String resolved = _stringValue(value, fallback: '');
  return resolved.isEmpty ||
      _matchesManagedImage(resolved, defaultProfileImageUrl) ||
      _matchesManagedImage(resolved, _platformMediaDefaults.profileImageUrl);
}

String? canonicalProfileImageForWrite(Object? value) {
  final String resolved = _stringValue(value, fallback: '');
  return isDefaultProfileImageSelection(resolved) ? null : resolved;
}

bool isDefaultSalonImageSelection(Object? value) {
  final String resolved = _stringValue(value, fallback: '');
  return resolved.isEmpty ||
      _matchesManagedImage(resolved, defaultSalonImageUrl) ||
      _matchesManagedImage(resolved, legacyCatalogImageUrl) ||
      _matchesManagedImage(resolved, legacyUnifiedCatalogImageUrl) ||
      _matchesManagedImage(resolved, _platformMediaDefaults.salonImageUrl);
}

String? canonicalSalonImageForWrite(Object? value) {
  final String resolved = _stringValue(value, fallback: '');
  return isDefaultSalonImageSelection(resolved) ? null : resolved;
}

bool isDefaultProductImageSelection(Object? value) {
  final String resolved = _stringValue(value, fallback: '');
  return resolved.isEmpty ||
      _matchesManagedImage(resolved, defaultProductImageUrl) ||
      _matchesManagedImage(resolved, legacyCatalogImageUrl) ||
      _matchesManagedImage(resolved, legacyUnifiedCatalogImageUrl) ||
      _matchesManagedImage(resolved, _platformMediaDefaults.productImageUrl);
}

String? canonicalProductImageForWrite(Object? value) {
  final String resolved = _stringValue(value, fallback: '');
  return isDefaultProductImageSelection(resolved) ? null : resolved;
}

const String _assets = 'assets/images';

const List<PromoBanner> banners = <PromoBanner>[
  PromoBanner(
    id: 1,
    imagePath: '$_assets/banner-1.jpg',
    title: 'Fresh Look, Fresh Start',
    subtitle: '20% off your first visit',
  ),
  PromoBanner(
    id: 2,
    imagePath: '$_assets/banner-2.jpg',
    title: 'Premium Salon Experience',
    subtitle: 'Book now & save',
  ),
];

const List<Salon> salons = <Salon>[
  Salon(
    id: '1',
    name: 'Freshline Signature Lounge',
    imagePath: '$_assets/salon-1.jpg',
    rating: 4.9,
    reviews: 234,
    location: 'Seef',
    distance: '1.2 km',
    description:
        'Luxury grooming lounge with express appointments, premium beard care, and home-service specialists.',
    phone: '+973 3900 1111',
    priceLabel: '\$\$\$',
    homeServiceAvailable: true,
    services: <String>[
      'Haircut',
      'Beard Trim',
      'Hot Towel Shave',
      'Home Visit',
    ],
  ),
  Salon(
    id: '2',
    name: 'Trim & Tone Studio',
    imagePath: '$_assets/salon-2.jpg',
    rating: 4.8,
    reviews: 189,
    location: 'Adliya',
    distance: '2.5 km',
    description:
        'Modern barber and styling studio focused on fades, color refresh, and quick booking slots.',
    phone: '+973 3900 2222',
    priceLabel: '\$\$',
    homeServiceAvailable: true,
    services: <String>['Hair Color', 'Styling', 'Kids Cut', 'Home Visit'],
  ),
  Salon(
    id: '3',
    name: 'Royal Blade House',
    imagePath: '$_assets/salon-3.jpg',
    rating: 4.7,
    reviews: 312,
    location: 'Juffair',
    distance: '3.1 km',
    description:
        'High-end barber house with package bundles, grooming treatments, and aftercare products.',
    phone: '+973 3900 3333',
    priceLabel: '\$\$\$',
    homeServiceAvailable: false,
    services: <String>['Full Service', 'Spa Treatment', 'Hair Care'],
  ),
];

const List<Product> products = <Product>[
  Product(
    id: 'p1',
    name: 'Premium Hair Kit',
    imagePath: '$_assets/product-1.jpg',
    price: 45.99,
    rating: 4.8,
    category: 'Hair Care',
    description:
        'A salon-style hair kit with cleansing, treatment, and finishing essentials for daily use.',
  ),
  Product(
    id: 'p2',
    name: 'Styling Cream',
    imagePath: '$_assets/product-2.jpg',
    price: 28.5,
    rating: 4.6,
    category: 'Styling',
    description:
        'A lightweight styling cream that adds hold, texture, and a clean finish without stiffness.',
  ),
  Product(
    id: 'p3',
    name: 'Argan Hair Serum',
    imagePath: '$_assets/product-3.jpg',
    price: 34.99,
    rating: 4.9,
    category: 'Treatment',
    description:
        'A nourishing argan serum made to smooth frizz, add shine, and support dry hair recovery.',
  ),
];

const List<Employee> employees = <Employee>[
  Employee(
    id: 'e1',
    name: 'Marco Silva',
    imagePath: '$_assets/barber-1.jpg',
    role: 'Senior Stylist',
    rating: 4.9,
    supportsInShop: true,
    supportsHomeService: true,
    availabilityLabel: 'Available for shop and home service',
  ),
  Employee(
    id: 'e2',
    name: 'Elena Rose',
    imagePath: '$_assets/barber-2.jpg',
    role: 'Color Specialist',
    rating: 4.8,
    supportsInShop: true,
    supportsHomeService: false,
    availabilityLabel: 'Available in salon today',
  ),
  Employee(
    id: 'e3',
    name: 'James Park',
    imagePath: '$_assets/barber-3.jpg',
    role: 'Barber',
    rating: 4.7,
    supportsInShop: true,
    supportsHomeService: true,
    availabilityLabel: 'Available for evening home visits',
  ),
];

const List<ServicePackage> salonPackages = <ServicePackage>[
  ServicePackage(
    id: 'pkg1',
    name: 'Basic Cut',
    price: 25,
    duration: '30 min',
    description: 'Professional haircut with wash',
  ),
  ServicePackage(
    id: 'pkg2',
    name: 'Premium Styling',
    price: 55,
    duration: '60 min',
    description: 'Cut, wash, style & finish',
  ),
  ServicePackage(
    id: 'pkg3',
    name: 'VIP Package',
    price: 95,
    duration: '90 min',
    description: 'Full service: cut, color, style, beard',
  ),
];

const List<ServiceItem> salonServices = <ServiceItem>[
  ServiceItem(id: 'srv1', name: 'Haircut', price: 25, duration: '30 min'),
  ServiceItem(id: 'srv2', name: 'Beard Trim', price: 15, duration: '20 min'),
  ServiceItem(id: 'srv3', name: 'Hair Color', price: 65, duration: '90 min'),
  ServiceItem(
    id: 'srv4',
    name: 'Hot Towel Shave',
    price: 20,
    duration: '25 min',
  ),
  ServiceItem(
    id: 'srv5',
    name: 'Deep Conditioning',
    price: 35,
    duration: '40 min',
  ),
];

const List<BranchLocation> bookingLocations = <BranchLocation>[
  BranchLocation(
    id: 'l1',
    name: 'Downtown Branch',
    address: '123 Main St, Suite 4',
  ),
  BranchLocation(
    id: 'l2',
    name: 'Midtown Branch',
    address: '456 Oak Ave, Floor 2',
  ),
  BranchLocation(id: 'l3', name: 'Uptown Branch', address: '789 Park Blvd'),
];

const List<String> timeSlots = <String>[
  '9:00 AM',
  '9:30 AM',
  '10:00 AM',
  '10:30 AM',
  '11:00 AM',
  '11:30 AM',
  '12:00 PM',
  '12:30 PM',
  '1:00 PM',
  '1:30 PM',
  '2:00 PM',
  '2:30 PM',
  '3:00 PM',
  '3:30 PM',
  '4:00 PM',
  '4:30 PM',
  '5:00 PM',
  '5:30 PM',
  '6:00 PM',
  '6:30 PM',
  '7:00 PM',
  '7:30 PM',
  '8:00 PM',
  '8:30 PM',
  '9:00 PM',
  '9:30 PM',
  '10:00 PM',
];

const String userAvatarPath = defaultProfileImageUrl;

const List<SalonMapInfo> salonMapInfo = <SalonMapInfo>[
  SalonMapInfo(
    salonId: '1',
    address: 'Road 2819, Seef District, Manama',
    city: 'Manama',
    latitude: 26.2317,
    longitude: 50.5362,
  ),
  SalonMapInfo(
    salonId: '2',
    address: 'Road 3801, Adliya, Manama',
    city: 'Manama',
    latitude: 26.2194,
    longitude: 50.5907,
  ),
  SalonMapInfo(
    salonId: '3',
    address: 'Al Shabab Ave, Juffair, Manama',
    city: 'Manama',
    latitude: 26.2147,
    longitude: 50.6108,
  ),
];

const List<PlatformUserSnapshot> platformUsers = <PlatformUserSnapshot>[
  PlatformUserSnapshot(
    id: 'usr-001',
    name: 'Ali Hasan',
    email: 'ali@freshline.app',
    phone: '+973 3300 1100',
    city: 'Manama',
    avatarPath: '$_assets/user-avatar.jpg',
    statusLabel: 'Active subscription',
    bookingsCount: 6,
    productOrdersCount: 3,
    totalSpent: 286.50,
    loyaltyPoints: 1420,
    lastActivity: 'Completed a haircut booking 2 hours ago',
  ),
  PlatformUserSnapshot(
    id: 'usr-002',
    name: 'Sara Ahmed',
    email: 'sara@freshline.app',
    phone: '+973 3300 2200',
    city: 'Seef',
    avatarPath: '$_assets/barber-2.jpg',
    statusLabel: 'Waiting for home-service booking',
    bookingsCount: 4,
    productOrdersCount: 5,
    totalSpent: 412.90,
    loyaltyPoints: 1985,
    lastActivity: 'Paid for Premium Hair Kit 35 minutes ago',
  ),
  PlatformUserSnapshot(
    id: 'usr-003',
    name: 'Khalid Yusuf',
    email: 'khalid@freshline.app',
    phone: '+973 3300 3300',
    city: 'Juffair',
    avatarPath: '$_assets/barber-3.jpg',
    statusLabel: 'No current subscription',
    bookingsCount: 2,
    productOrdersCount: 1,
    totalSpent: 138.00,
    loyaltyPoints: 430,
    lastActivity: 'Appointment reminder scheduled for tomorrow',
  ),
];

const List<AdminTeamMember> seedAdminTeam = <AdminTeamMember>[
  AdminTeamMember(
    id: 'ops-01',
    name: 'Maha Al Khalifa',
    email: 'maha@freshline.app',
    phone: '+973 3700 1111',
    city: 'Manama',
    avatarPath: '$_assets/barber-2.jpg',
    roleTitle: 'Operations Admin',
    storagePath: 'admins/maha-al-khalifa/profile.jpg',
    lastAction: 'Approved Freshline Signature Lounge',
  ),
  AdminTeamMember(
    id: 'ops-02',
    name: 'Sultan Ahmed',
    email: 'sultan@freshline.app',
    phone: '+973 3700 2222',
    city: 'Seef',
    avatarPath: '$_assets/barber-1.jpg',
    roleTitle: 'Payments Admin',
    storagePath: 'admins/sultan-ahmed/profile.jpg',
    lastAction: 'Reviewed subscription payment batch',
  ),
  AdminTeamMember(
    id: 'ops-03',
    name: 'Nora Salman',
    email: 'nora@freshline.app',
    phone: '+973 3700 3333',
    city: 'Juffair',
    avatarPath: '$_assets/user-avatar.jpg',
    roleTitle: 'Support Admin',
    storagePath: 'admins/nora-salman/profile.jpg',
    lastAction: 'Updated a user status record',
    isActive: false,
  ),
];

const List<SupportTopic> customerSupportTopics = <SupportTopic>[
  SupportTopic(
    question: 'How do I book a barber salon?',
    answer:
        'Open a salon, choose a package or service, select visit type, pick an available employee and time, then continue to address and payment.',
  ),
  SupportTopic(
    question: 'How do product orders work?',
    answer:
        'Products use a separate cart and checkout flow from salon bookings, so you can continue shopping for products only.',
  ),
  SupportTopic(
    question: 'When do I receive notifications?',
    answer:
        'You receive notifications when admins publish announcements, when a product order status changes, and when your appointment is confirmed or near its time.',
  ),
  SupportTopic(
    question: 'How do I create a customer account?',
    answer:
        'Start with your email, username, and password, then continue to the second screen to add your phone number, city, and profile photo before finishing the account.',
  ),
  SupportTopic(
    question: 'Can I change my username and profile photo later?',
    answer:
        'Yes. Open Settings, go to Account Details, and update your username, photo, phone number, city, or address at any time.',
  ),
  SupportTopic(
    question: 'What happens if I do not upload a profile photo?',
    answer:
        'Freshline keeps the default profile image for your account until you decide to upload a new one.',
  ),
  SupportTopic(
    question: 'How do I add a payment card?',
    answer:
        'You can add a card from Settings under Saved Cards, or during checkout when booking a service or subscribing to a plan.',
  ),
  SupportTopic(
    question: 'Can I save more than one card?',
    answer:
        'Yes. You can save multiple cards and use the most suitable one when paying for bookings, subscriptions, or future orders.',
  ),
  SupportTopic(
    question: 'How do I subscribe to a membership plan?',
    answer:
        'Open Subscription from Settings or Home, choose a plan, confirm with one of your saved cards, and the plan will activate immediately after payment.',
  ),
  SupportTopic(
    question: 'What do loyalty points do?',
    answer:
        'You earn loyalty points from eligible product orders and bookings, active plans can increase the bonus percentage you receive, and available points can be redeemed as a discount during product checkout.',
  ),
  SupportTopic(
    question: 'How does home service work?',
    answer:
        'When a salon supports home service, choose that visit mode during booking, then confirm the address so the employee can reach your location.',
  ),
  SupportTopic(
    question: 'Can I continue shopping after adding a product to the cart?',
    answer:
        'Yes. Freshline shows a compact confirmation at the top of the screen, and you can open the cart anytime from the navigation bar whenever you are ready.',
  ),
  SupportTopic(
    question: 'What currency does Freshline use?',
    answer:
        'All displayed prices and payments in the customer experience are shown in Bahraini Dinar (BHD).',
  ),
  SupportTopic(
    question: 'How do I cancel or reschedule a booking?',
    answer:
        'Open your orders or booking details and follow the available actions. If the booking can no longer be changed, contact support for help.',
  ),
  SupportTopic(
    question: 'Why is my card payment not going through?',
    answer:
        'Please double-check the card number, expiry date, and CVV, then try again. If the issue continues, use another saved card or contact your bank.',
  ),
  SupportTopic(
    question: 'How do product delivery updates appear?',
    answer:
        'Freshline sends notifications when a product order is received and whenever its payment or order status changes.',
  ),
  SupportTopic(
    question: 'How do I contact support quickly?',
    answer:
        'You can open Contact Us from Settings and reach Freshline by phone, email, WhatsApp, or the listed social channels.',
  ),
];

const List<SupportTopic> salonOwnerSupportTopics = <SupportTopic>[
  SupportTopic(
    question: 'How do I submit or update my salon request?',
    answer:
        'Open the request hub, fill in the salon details, upload the required files, then submit. You can still update the request until it is approved.',
  ),
  SupportTopic(
    question: 'How do I manage packages, services, and products?',
    answer:
        'Open Catalog from the owner workspace to add, edit, or pause packages, services, and products that appear in the salon experience.',
  ),
  SupportTopic(
    question: 'How do salon notifications work?',
    answer:
        'Freshline sends notifications for new bookings, admin updates, and platform announcements directly to the salon workspace notification inbox.',
  ),
  SupportTopic(
    question: 'How do I add employees and login access?',
    answer:
        'Open Team, add the employee profile, then decide whether that employee can login and whether they support shop visits, home service, or both.',
  ),
  SupportTopic(
    question: 'How do subscription payments work for salons?',
    answer:
        'The salon subscription screen shows the active cycle, amount, renewal status, and expiry date so you can keep the workspace active.',
  ),
  SupportTopic(
    question: 'Where can I review revenue and profit?',
    answer:
        'Open Revenue & Profit from owner settings to review revenue, salary cost, subscription cost, and the current operating profit snapshot.',
  ),
  SupportTopic(
    question: 'How do I contact support for salon issues?',
    answer:
        'Open Help & Support from the owner settings and use Freshline support channels for subscription issues, approval questions, or operational problems.',
  ),
];

const List<SupportTopic> employeeSupportTopics = <SupportTopic>[
  SupportTopic(
    question: 'How do I see my assigned bookings?',
    answer:
        'Open the employee bookings screen to review assigned appointments, product tasks, and upcoming service times for your workday.',
  ),
  SupportTopic(
    question: 'Can I edit my account details?',
    answer:
        'Yes. Open Account Details from employee settings to update your profile photo, phone number, city, address, and password.',
  ),
  SupportTopic(
    question: 'Will I receive salon notifications?',
    answer:
        'Yes. Employees can receive direct notifications tied to their profile plus salon-wide notifications sent to the salon they belong to.',
  ),
  SupportTopic(
    question: 'Can I manage other employees or pricing?',
    answer:
        'No. Employee access is limited to assigned bookings, profile management, and service-day tools. Team management and pricing stay with the salon owner.',
  ),
  SupportTopic(
    question: 'How do I get help quickly?',
    answer:
        'Open Help & Support from employee settings to use the same Freshline support channels for schedule questions, access issues, or technical help.',
  ),
];

const List<SupportTopic> adminSupportTopics = <SupportTopic>[
  SupportTopic(
    question: 'What can I do from the admin dashboard?',
    answer:
        'The dashboard gives admins a quick view of revenue, users, salons, requests, coupons, and recent admin activity across the platform.',
  ),
  SupportTopic(
    question: 'How do salon requests get reviewed?',
    answer:
        'Open the Requests tab, inspect the request details, then approve, reject, or request more information. The owner receives the result as a notification.',
  ),
  SupportTopic(
    question: 'How do admin notifications work?',
    answer:
        'Use the Notify tab to choose the audience, optionally target a specific user or salon, then send an in-app notification directly into their inbox.',
  ),
  SupportTopic(
    question: 'Who can create or manage other admins?',
    answer:
        'Only the admin owner can create new admin accounts, edit existing admins, or disable platform admin accounts.',
  ),
  SupportTopic(
    question: 'How should I handle support or payment issues?',
    answer:
        'Use the admin tools to review user details, request status, notifications, and payment context, then contact Freshline support when an incident needs escalation.',
  ),
  SupportTopic(
    question: 'Can admins update their own profile?',
    answer:
        'Yes. Admin account details can be updated from admin settings, including profile photo, phone number, city, address, and password.',
  ),
];

const List<SupportTopic> supportTopics = customerSupportTopics;

List<SupportTopic> supportTopicsForRole(AppRole role) {
  switch (role) {
    case AppRole.customer:
      return customerSupportTopics;
    case AppRole.salonOwner:
      return salonOwnerSupportTopics;
    case AppRole.employee:
      return employeeSupportTopics;
    case AppRole.admin:
      return adminSupportTopics;
  }
}

const List<String> aiQuickPrompts = <String>[
  'Suggest a haircut for an oval face',
  'Best beard style with a fade?',
  'اقترح لي قصة شعر مناسبة',
];

const List<SubscriptionPlan> subscriptionPlans = <SubscriptionPlan>[
  SubscriptionPlan(
    id: 'bronze',
    name: 'Bronze',
    nameAr: 'برونزي',
    price: 4.99,
    rewardPercent: 5,
    features: <String>[
      '5% extra loyalty points on every order',
      'Priority order reminders',
      'Product offers in the home screen',
    ],
    featuresAr: <String>[
      'نقاط ولاء إضافية 5٪ على كل طلب',
      'تذكيرات الطلبات ذات أولوية',
      'عروض المنتجات في الصفحة الرئيسية',
    ],
  ),
  SubscriptionPlan(
    id: 'silver',
    name: 'Silver',
    nameAr: 'فضي',
    price: 9.99,
    rewardPercent: 10,
    features: <String>[
      '10% extra loyalty points on every order',
      'Faster booking support visibility',
      'Early access to featured salon deals',
    ],
    featuresAr: <String>[
      'نقاط ولاء إضافية 10٪ على كل طلب',
      'ظهور أسرع لدعم الحجوزات',
      'وصول مبكر لعروض الصالونات المميزة',
    ],
  ),
  SubscriptionPlan(
    id: 'gold',
    name: 'Gold',
    nameAr: 'ذهبي',
    price: 14.99,
    rewardPercent: 20,
    features: <String>[
      '20% extra loyalty points on every order',
      'Best plan badge in settings',
      'Top placement for exclusive offers and reminders',
    ],
    featuresAr: <String>[
      'نقاط ولاء إضافية 20٪ على كل طلب',
      'شارة أفضل باقة في الإعدادات',
      'أولوية أعلى للعروض والتذكيرات الحصرية',
    ],
  ),
];

SubscriptionPlan? subscriptionPlanById(String? id) {
  final String normalizedId = (id ?? '').trim().toLowerCase();
  if (normalizedId.isEmpty) {
    return null;
  }
  return subscriptionPlans
      .where((SubscriptionPlan plan) => plan.id == normalizedId)
      .firstOrNull;
}

const List<OnboardingSlide> onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    imagePath: '$_assets/banner-1.jpg',
    title: 'Book your salon faster',
    subtitle:
        'Find salons, compare services, and move from browsing to booking in a few taps.',
  ),
  OnboardingSlide(
    imagePath: '$_assets/salon-1.jpg',
    title: 'Choose visit or home service',
    subtitle:
        'Pick whether you go to the salon or the stylist comes to your location.',
  ),
  OnboardingSlide(
    imagePath: '$_assets/product-1.jpg',
    title: 'Shop, subscribe, and earn',
    subtitle:
        'Discover products, subscribe to a plan, and collect loyalty points after each order.',
  ),
];

String formatNotificationTimestamp(DateTime value) {
  final DateTime now = DateTime.now();
  final Duration difference = now.difference(value);

  if (difference.inSeconds < 60) {
    return 'Now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} hr ago';
  }
  if (difference.inDays == 1) {
    return 'Yesterday';
  }
  return '${value.day}/${value.month}/${value.year}';
}

String formatNotificationTimestampForLanguage(
  DateTime value, {
  required String languageCode,
}) {
  if (languageCode.trim().toUpperCase() != 'AR') {
    return formatNotificationTimestamp(value);
  }

  final DateTime now = DateTime.now();
  final Duration difference = now.difference(value);

  if (difference.inSeconds < 60) {
    return 'الآن';
  }
  if (difference.inMinutes < 60) {
    return 'قبل ${difference.inMinutes} دقيقة';
  }
  if (difference.inHours < 24) {
    return 'قبل ${difference.inHours} ساعة';
  }
  if (difference.inDays == 1) {
    return 'أمس';
  }
  return '${value.day}/${value.month}/${value.year}';
}

String formatCalendarDate(DateTime value) {
  final DateTime local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String normalizeCatalogImageUrl(Object? value, {required String fallback}) {
  final String resolved = _stringValue(value, fallback: fallback);
  final String normalizedFallback = _normalizedCatalogFallback(fallback);
  if (resolved.isEmpty ||
      _matchesManagedImage(resolved, legacyCatalogImageUrl) ||
      _matchesManagedImage(resolved, legacyUnifiedCatalogImageUrl) ||
      _matchesManagedImage(resolved, fallback)) {
    return normalizedFallback;
  }
  return resolved;
}

String _normalizedCatalogFallback(String fallback) {
  if (_matchesManagedImage(fallback, defaultSalonImageUrl) ||
      _matchesManagedImage(fallback, _platformMediaDefaults.salonImageUrl)) {
    return currentDefaultSalonImageUrl();
  }
  if (_matchesManagedImage(fallback, defaultProductImageUrl) ||
      _matchesManagedImage(fallback, _platformMediaDefaults.productImageUrl)) {
    return currentDefaultProductImageUrl();
  }
  return fallback;
}

String _resolvedDefaultImageUrl(
  String url,
  String revision, {
  required bool cacheBusted,
}) {
  final String resolved = _stringValue(url, fallback: '');
  if (!cacheBusted || !resolved.startsWith('http')) {
    return resolved;
  }
  final Uri? parsed = Uri.tryParse(resolved);
  if (parsed == null) {
    return resolved;
  }
  final Map<String, String> query = Map<String, String>.from(
    parsed.queryParameters,
  );
  query['v'] = revision;
  return parsed.replace(queryParameters: query).toString();
}

bool _matchesManagedImage(String left, String right) {
  final String leftValue = _stripManagedImageVersion(left);
  final String rightValue = _stripManagedImageVersion(right);
  return leftValue.isNotEmpty &&
      rightValue.isNotEmpty &&
      leftValue == rightValue;
}

String _stripManagedImageVersion(String value) {
  final String resolved = _stringValue(value, fallback: '');
  if (!resolved.startsWith('http')) {
    return resolved;
  }
  final Uri? parsed = Uri.tryParse(resolved);
  if (parsed == null) {
    return resolved;
  }
  if (!parsed.queryParameters.containsKey('v')) {
    return resolved;
  }
  final Map<String, String> query = Map<String, String>.from(
    parsed.queryParameters,
  )..remove('v');
  final String stripped = parsed
      .replace(queryParameters: query.isEmpty ? <String, String>{} : query)
      .toString();
  return stripped.endsWith('?')
      ? stripped.substring(0, stripped.length - 1)
      : stripped;
}

const List<SocialContact> socialContacts = <SocialContact>[
  SocialContact(
    label: 'WhatsApp',
    value: '+973 3533 6641',
    uri: 'https://wa.me/97335336641',
  ),
  SocialContact(
    label: 'Instagram',
    value: 'https://instagram.com/freshline.app',
    uri: 'https://instagram.com/freshline.app',
  ),
  SocialContact(
    label: 'TikTok',
    value: 'https://tiktok.com/@freshline.app',
    uri: 'https://tiktok.com/@freshline.app',
  ),
  SocialContact(
    label: 'X',
    value: 'https://x.com/freshlineapp',
    uri: 'https://x.com/freshlineapp',
  ),
  SocialContact(
    label: 'YouTube',
    value: 'https://youtube.com/@freshlineapp',
    uri: 'https://youtube.com/@freshlineapp',
  ),
];

SalonMapInfo mapInfoForSalon(String salonId) {
  for (final SalonMapInfo info in salonMapInfo) {
    if (info.salonId == salonId) {
      return info;
    }
  }

  return salonMapInfo.first;
}

String _stringValue(Object? value, {required String fallback}) {
  final String text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

double _doubleValue(Object? value, {required double fallback}) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse((value ?? '').toString()) ?? fallback;
}

int _intValue(Object? value, {required int fallback}) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse((value ?? '').toString()) ?? fallback;
}

num _numValue(Object? value, {required num fallback}) {
  if (value is num) {
    return value;
  }

  return num.tryParse((value ?? '').toString()) ?? fallback;
}

DateTime? _readDateTime(Object? value) {
  final String raw = (value ?? '').toString().trim();
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

int? _readTimeMinutes(Object? value) {
  final String raw = (value ?? '').toString().trim();
  if (raw.isEmpty) {
    return null;
  }

  final RegExp match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$');
  final RegExpMatch? parts = match.firstMatch(raw);
  if (parts == null) {
    return null;
  }

  final int hour = int.tryParse(parts.group(1) ?? '') ?? -1;
  final int minute = int.tryParse(parts.group(2) ?? '') ?? -1;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return (hour * 60) + minute;
}

String? _nullableStringValue(Object? value) {
  final String text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

double? _nullableDoubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse((value ?? '').toString());
}

List<String> _stringListValue(Object? value) {
  if (value is List) {
    return value
        .where((Object? item) => item != null)
        .map((Object? item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  return const <String>[];
}

String _durationLabelFromSupabaseValue(
  Object? value, {
  String fallback = '30 min',
}) {
  final int durationMinutes = _intValue(value, fallback: -1);
  if (durationMinutes > 0) {
    return '$durationMinutes min';
  }
  return _stringValue(value, fallback: fallback);
}
