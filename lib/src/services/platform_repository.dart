import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/app_data.dart';
import '../utils/bahrain_locations.dart';
import '../utils/bahrain_phone.dart';
import '../utils/network_request.dart';
import '../utils/password_hash.dart';
import '../utils/upload_preparation.dart';

const String _twoFactorSignInOtpPurpose = 'two_factor_sign_in';
const String _emailVerificationOtpPurpose = 'email_verification';
const String _passwordResetOtpPurpose = 'password_reset';
const String _memoryOtpCode = '246810';
const String _otpPolicyMessage = 'Freshline cannot send due to policy';
const String _otpRateLimitErrorCode = 'OTP_RATE_LIMIT';

class AuthOtpDispatchResult {
  const AuthOtpDispatchResult({
    this.previewCode,
    this.usedLocalFallback = false,
  });

  final String? previewCode;
  final bool usedLocalFallback;

  bool get hasPreviewCode => (previewCode ?? '').trim().isNotEmpty;
}

class CustomerRatingReview {
  const CustomerRatingReview({
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String reviewerName;
  final int rating;
  final String comment;
  final DateTime createdAt;
}

abstract class PlatformRepository {
  Future<String?> pickAndUploadProfileImage({required String profileKey});

  Future<String?> pickAndUploadSalonProductImage({required String productKey});

  Future<String?> pickAndUploadPlatformDefaultImage({
    required PlatformMediaType mediaType,
  });

  Future<PlatformMediaDefaults> loadPlatformMediaDefaults();

  Future<PlatformMediaDefaults> savePlatformMediaDefaults({
    required AppUser actor,
    required PlatformMediaDefaults defaults,
  });

  Future<SignInAttempt> beginSignIn({
    required AppRole role,
    required String email,
    required String password,
  });

  Future<AppUser> completeTwoFactorSignIn({
    required String email,
    required String profileId,
    required String code,
  });

  Future<AppUser> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String password,
    String? avatarPath,
  });

  Future<void> verifyEmailAddressCode({
    required String email,
    required String code,
  });

  Future<AuthOtpDispatchResult> sendEmailVerificationCode({
    required String email,
  });

  Future<AppUser> updateProfile({
    required AppUser user,
    required String name,
    required String phone,
    required String city,
    required String address,
    required String avatarPath,
  });

  Future<AppUser> refreshUser({required AppUser user});

  Future<AppUser> updatePreferredLanguage({
    required AppUser user,
    required String languageCode,
  });

  Future<void> changePassword({
    required AppUser user,
    required String currentPassword,
    required String newPassword,
  });

  Future<AuthOtpDispatchResult> sendPasswordResetCode({required String email});

  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  });

  Future<void> completePasswordReset({
    required String email,
    required String verificationToken,
    required String newPassword,
  });

  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<List<CustomerRatingReview>> loadSalonReviews({required String salonId});

  Future<List<CustomerRatingReview>> loadEmployeeReviews({
    required String employeeId,
  });

  Future<AuthOtpDispatchResult> sendEmailTwoFactorSetupCode({
    required AppUser user,
  });

  Future<AppUser> enableEmailTwoFactor({
    required AppUser user,
    required String code,
  });

  Future<AppUser> disableEmailTwoFactor({required AppUser user});

  Future<List<PaymentCardInfo>> loadSavedCards({required AppUser user});

  Future<List<SavedCustomerAddress>> loadSavedAddresses({
    required AppUser user,
  });

  Future<PaymentCardInfo> saveCard({
    required AppUser user,
    required PaymentCardInfo card,
  });

  Future<void> removeSavedCard({
    required AppUser user,
    required PaymentCardInfo card,
  });

  Future<SubscriptionPlan?> loadActivePlan({required AppUser user});

  Future<CustomerSubscriptionStatus?> loadCustomerSubscriptionStatus({
    required AppUser user,
  });

  Future<CustomerSubscriptionStatus?> updateCustomerSubscriptionAutoRenew({
    required AppUser user,
    required bool autoRenew,
  });

  Future<List<PromoCouponRecord>> loadPromoCoupons({bool activeOnly = false});

  Future<void> subscribeToPlan({
    required AppUser user,
    required SubscriptionPlan plan,
    required PaymentCardInfo card,
  });

  Future<CustomerCommerceSnapshot> loadCustomerCommerce({
    required AppUser user,
  });

  Future<List<Employee>> loadSalonEmployees({required String salonId});

  Future<Map<String, List<EmployeeScheduleEntry>>> loadEmployeeSchedules({
    required List<String> employeeIds,
  });

  Future<SalonSubscriptionStatus?> activateSalonSubscription({
    required AppUser user,
    required SubscriptionCycleOption cycle,
  });

  Future<SalonSubscriptionStatus?> updateSalonSubscriptionAutoRenew({
    required AppUser user,
    required bool autoRenew,
  });

  Future<void> placeProductOrder({
    required AppUser user,
    required UserOrder order,
    required List<ProductOrderLineItem> items,
    required DeliveryLocationSelection location,
    required String addressDetails,
    required String? couponCode,
    required num couponDiscount,
    required int loyaltyPointsRedeemed,
    required num loyaltyDiscount,
    required num taxAmount,
  });

  Future<void> placeSalonBooking({
    required AppUser user,
    required UserOrder order,
  });

  Future<void> completeOrder({required AppUser user, required UserOrder order});

  Future<void> submitSalonReview({
    required AppUser user,
    required UserOrder order,
    required int salonRating,
    required int employeeRating,
    String comment,
  });

  Future<void> submitProductReview({
    required AppUser user,
    required UserOrder order,
    required String productId,
    required int rating,
    String comment,
  });

  Future<SalonWorkspaceSnapshot> loadSalonWorkspace({required AppUser user});

  Future<void> takeSalonProductOrder({
    required AppUser actor,
    required String orderId,
  });

  Future<List<UserOrder>> loadAdminProductOrders({required AppUser actor});

  Future<void> takeAdminProductOrder({
    required AppUser actor,
    required String orderId,
  });

  Future<Employee> saveSalonEmployee({
    required AppUser actor,
    String? employeeId,
    String? profileId,
    required String name,
    required String roleTitle,
    required String email,
    required String phone,
    required double monthlySalary,
    required bool supportsInShop,
    required bool supportsHomeService,
    required bool canLogin,
    String? workStartTime,
    String? workEndTime,
    String? breakStartTime,
    String? breakEndTime,
    String? password,
    String? avatarPath,
  });

  Future<void> setSalonEmployeeActive({
    required AppUser actor,
    required String employeeId,
    required bool isActive,
  });

  Future<void> deleteSalonEmployee({
    required AppUser actor,
    required String employeeId,
  });

  Future<ServicePackage> saveSalonPackage({
    required AppUser actor,
    String? packageId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    required bool isActive,
  });

  Future<void> deleteSalonPackage({
    required AppUser actor,
    required String packageId,
  });

  Future<ServiceItem> saveSalonService({
    required AppUser actor,
    String? serviceId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    required bool isActive,
  });

  Future<void> deleteSalonService({
    required AppUser actor,
    required String serviceId,
  });

  Future<Product> saveSalonProduct({
    required AppUser actor,
    String? productId,
    required String name,
    required String category,
    required String description,
    required double price,
    required int stock,
    required bool isActive,
    String? imagePath,
  });

  Future<void> deleteSalonProduct({
    required AppUser actor,
    required String productId,
  });

  Future<Product> saveAdminProduct({
    required AppUser actor,
    String? productId,
    required String name,
    required String category,
    required String description,
    required double price,
    required int stock,
    required bool isActive,
    String? salonId,
    String? imagePath,
  });

  Future<void> deleteAdminProduct({
    required AppUser actor,
    required String productId,
  });

  Future<PromoCouponRecord> saveSalonCoupon({
    required AppUser actor,
    required PromoCouponRecord coupon,
  });

  Future<void> setSalonEmployeeSalaryReceived({
    required AppUser actor,
    required String employeeId,
    required bool isReceived,
  });

  Future<AdminSnapshot> loadAdminSnapshot();

  Future<void> sendAdminNotification({
    required AppUser actor,
    required String title,
    required String body,
    required String audience,
    String? targetProfileId,
    String? targetSalonId,
  });

  Future<void> syncDevicePushToken({
    required AppUser user,
    required String token,
  });

  Future<void> removeDevicePushToken({
    required AppUser user,
    required String token,
  });

  Future<AdminTeamMember> saveAdminAccount({
    required AppUser actor,
    String? adminId,
    required String name,
    required String email,
    required String phone,
    required String city,
    String? password,
    String? avatarPath,
  });

  Future<void> setAdminAccountActive({
    required AppUser actor,
    required String adminId,
    required bool isActive,
  });

  Future<PromoCouponRecord> savePromoCoupon({
    required PromoCouponRecord coupon,
  });

  Future<void> updateManagedUser({
    required AppUser actor,
    required ManagedUserRecord user,
    required String name,
    required String email,
    required String phone,
    required String city,
    required AppRole role,
  });

  Future<void> setUserActive({
    required AppUser actor,
    required String userId,
    required bool isActive,
  });

  Future<void> reviewSalonRequest({
    required AdminSalonRequestRecord record,
    required SalonRequestStatus status,
    required String adminNote,
    required AppUser admin,
  });

  void dispose() {}
}

class MemoryPlatformRepository implements PlatformRepository {
  MemoryPlatformRepository() {
    final DateTime now = DateTime.now();
    final DateTime currentSalaryMonth = DateTime(now.year, now.month, 1);
    final AppUser seededUser = AppUser(
      profileId: 'usr-001',
      name: 'Alex Freshline',
      email: 'alex@freshline.app',
      phone: supportPhoneDisplay,
      city: 'Manama',
      role: AppRole.customer,
    );
    final AppUser seededAdmin = AppUser(
      profileId: 'admin-001',
      name: 'Freshline Admin Owner',
      email: adminOwnerEmail,
      phone: supportPhoneDisplay,
      city: 'Manama',
      role: AppRole.admin,
      isAdminOwner: true,
    );

    _usersByEmail[seededUser.email.toLowerCase()] = seededUser;
    _usersByEmail[seededAdmin.email.toLowerCase()] = seededAdmin;
    _passwordsByUserId[seededUser.profileId!] = hashProfilePassword(
      'freshline123',
    );
    _passwordsByUserId[seededAdmin.profileId!] = hashProfilePassword(
      'freshline123',
    );
    _isActiveByUserId[seededUser.profileId!] = true;
    _isActiveByUserId[seededAdmin.profileId!] = true;
    _adminLastActionByUserId[seededAdmin.profileId!] =
        'Admin owner access ready';

    for (final AdminTeamMember admin in seedAdminTeam) {
      final String profileId = admin.id;
      final AppUser adminUser = AppUser(
        profileId: profileId,
        name: admin.name,
        email: admin.email,
        phone: admin.phone,
        city: admin.city,
        role: AppRole.admin,
        avatarPath: admin.avatarPath,
      );
      _usersByEmail[admin.email.toLowerCase()] = adminUser;
      _passwordsByUserId[profileId] = hashProfilePassword('freshline123');
      _isActiveByUserId[profileId] = admin.isActive;
      _adminLastActionByUserId[profileId] = admin.lastAction;
    }

    _employeesBySalonId.addAll(<String, List<Employee>>{
      '1': <Employee>[
        employees[0].copyWith(
          id: 'salon-1-e1',
          reviewsCount: 24,
          monthlySalary: 320,
          canLogin: true,
          email: 'marco@freshline.app',
          phone: '+973 3900 1101',
          salaryPaidForMonth: currentSalaryMonth,
          salaryLastPaidAt: now.subtract(const Duration(days: 1)),
        ),
        employees[1].copyWith(
          id: 'salon-1-e2',
          reviewsCount: 19,
          monthlySalary: 280,
          canLogin: true,
          email: 'elena@freshline.app',
          phone: '+973 3900 1102',
        ),
        employees[2].copyWith(
          id: 'salon-1-e3',
          reviewsCount: 17,
          monthlySalary: 260,
          canLogin: true,
          email: 'james@freshline.app',
          phone: '+973 3900 1103',
        ),
      ],
      '2': <Employee>[
        employees[0].copyWith(
          id: 'salon-2-e1',
          name: 'Rami Ashraf',
          role: 'Lead Barber',
          reviewsCount: 14,
          monthlySalary: 300,
          canLogin: true,
          email: 'rami@freshline.app',
          phone: '+973 3900 2201',
          salaryPaidForMonth: currentSalaryMonth,
          salaryLastPaidAt: now.subtract(const Duration(days: 2)),
        ),
        employees[1].copyWith(
          id: 'salon-2-e2',
          name: 'Nora Ali',
          role: 'Styling Artist',
          reviewsCount: 11,
          monthlySalary: 255,
          canLogin: true,
          email: 'nora@freshline.app',
          phone: '+973 3900 2202',
        ),
      ],
      '3': <Employee>[
        employees[2].copyWith(
          id: 'salon-3-e1',
          name: 'Omar Faisal',
          role: 'Treatment Specialist',
          reviewsCount: 21,
          monthlySalary: 340,
          canLogin: true,
          email: 'omar@freshline.app',
          phone: '+973 3900 3301',
        ),
      ],
    });

    _salaryPaymentsBySalonId.addAll(<String, List<EmployeeSalaryPayment>>{
      for (final MapEntry<String, List<Employee>> entry
          in _employeesBySalonId.entries)
        entry.key: entry.value
            .where(
              (Employee employee) =>
                  employee.salaryPaidForMonth != null &&
                  employee.salaryLastPaidAt != null,
            )
            .map(
              (Employee employee) => EmployeeSalaryPayment(
                id: 'salary-${entry.key}-${employee.id}-${employee.salaryPaidForMonth!.millisecondsSinceEpoch}',
                employeeId: employee.id,
                employeeName: employee.name,
                salonId: entry.key,
                amount: employee.monthlySalary,
                salaryMonth: employee.salaryPaidForMonth!,
                confirmedAt: employee.salaryLastPaidAt!,
              ),
            )
            .toList(growable: false),
    });

    _packagesBySalonId.addAll(<String, List<ServicePackage>>{
      for (final Salon salon in salons)
        salon.id: salonPackages
            .map(
              (ServicePackage item) => item.copyWith(
                id: '${salon.id}-${item.id}',
                salonId: salon.id,
              ),
            )
            .toList(growable: false),
    });

    _servicesBySalonId.addAll(<String, List<ServiceItem>>{
      for (final Salon salon in salons)
        salon.id: salonServices
            .map(
              (ServiceItem item) => item.copyWith(
                id: '${salon.id}-${item.id}',
                salonId: salon.id,
              ),
            )
            .toList(growable: false),
    });

    _productsBySalonId.addAll(<String, List<Product>>{
      '1': <Product>[
        products[0].copyWith(
          id: 'salon-1-p1',
          salonId: '1',
          stock: 40,
          isActive: true,
        ),
        products[2].copyWith(
          id: 'salon-1-p2',
          salonId: '1',
          stock: 24,
          isActive: true,
        ),
      ],
      '2': <Product>[
        products[1].copyWith(
          id: 'salon-2-p1',
          salonId: '2',
          stock: 60,
          isActive: true,
        ),
      ],
      '3': <Product>[
        products[2].copyWith(
          id: 'salon-3-p1',
          salonId: '3',
          stock: 32,
          isActive: true,
        ),
      ],
    });

    _adminProducts.addAll(
      products
          .asMap()
          .entries
          .map(
            (MapEntry<int, Product> entry) => entry.value.copyWith(
              id: 'global-p${entry.key + 1}',
              stock: switch (entry.key) {
                0 => 40,
                1 => 60,
                _ => 55,
              },
              isActive: true,
            ),
          )
          .toList(growable: false),
    );

    _salonSubscriptionsBySalonId.addAll(<String, SalonSubscriptionStatus>{
      '1': SalonSubscriptionStatus(
        cycle: SubscriptionCycleOption.monthly,
        amount: salonMonthlySubscriptionPrice,
        expiresAt: now.add(const Duration(days: 18)),
        autoRenew: false,
      ),
      '2': SalonSubscriptionStatus(
        cycle: SubscriptionCycleOption.yearly,
        amount: salonYearlySubscriptionPrice,
        expiresAt: now.add(const Duration(days: 240)),
        autoRenew: true,
      ),
      '3': SalonSubscriptionStatus(
        cycle: SubscriptionCycleOption.monthly,
        amount: salonMonthlySubscriptionPrice,
        expiresAt: now.add(const Duration(days: 11)),
        autoRenew: false,
      ),
    });

    _customerSubscriptionsByUserId[seededUser.profileId!] =
        CustomerSubscriptionStatus(
          plan: subscriptionPlans[1],
          startsAt: now.subtract(const Duration(days: 12)),
          endsAt: now.add(const Duration(days: 18)),
          autoRenew: true,
        );

    for (final MapEntry<String, List<Employee>> entry
        in _employeesBySalonId.entries) {
      for (final Employee employee in entry.value) {
        final String profileId = 'profile-${employee.id}';
        final AppUser employeeUser = AppUser(
          profileId: profileId,
          name: employee.name,
          email: employee.email.isEmpty
              ? '${employee.id}@freshline.app'
              : employee.email,
          phone: employee.phone,
          city: 'Manama',
          role: AppRole.employee,
          avatarPath: employee.imagePath,
        );
        _usersByEmail[employeeUser.email.toLowerCase()] = employeeUser;
        _passwordsByUserId[profileId] = hashProfilePassword('freshline123');
        _isActiveByUserId[profileId] = employee.isActive;
        _employeeIdByProfileId[profileId] = employee.id;
      }
    }
  }

  final Map<String, AppUser> _usersByEmail = <String, AppUser>{};
  final Map<String, String> _passwordsByUserId = <String, String>{};
  final Map<String, bool> _isActiveByUserId = <String, bool>{};
  final Map<String, List<PaymentCardInfo>> _cardsByUserId =
      <String, List<PaymentCardInfo>>{};
  final Map<String, List<SavedCustomerAddress>> _addressesByUserId =
      <String, List<SavedCustomerAddress>>{};
  final Map<String, CustomerSubscriptionStatus> _customerSubscriptionsByUserId =
      <String, CustomerSubscriptionStatus>{};
  final Map<String, List<UserOrder>> _ordersByUserId =
      <String, List<UserOrder>>{};
  final Map<String, int> _loyaltyPointsByUserId = <String, int>{};
  final Map<String, String> _adminLastActionByUserId = <String, String>{};
  final Map<String, List<Employee>> _employeesBySalonId =
      <String, List<Employee>>{};
  final Map<String, List<ServicePackage>> _packagesBySalonId =
      <String, List<ServicePackage>>{};
  final Map<String, List<ServiceItem>> _servicesBySalonId =
      <String, List<ServiceItem>>{};
  final Map<String, List<Product>> _productsBySalonId =
      <String, List<Product>>{};
  final List<Product> _adminProducts = <Product>[];
  final List<AdminActivityLogRecord> _activityLogs = <AdminActivityLogRecord>[];
  final Map<String, List<EmployeeSalaryPayment>> _salaryPaymentsBySalonId =
      <String, List<EmployeeSalaryPayment>>{};
  final Map<String, SalonSubscriptionStatus> _salonSubscriptionsBySalonId =
      <String, SalonSubscriptionStatus>{};
  final Map<String, String> _employeeIdByProfileId = <String, String>{};
  final Map<String, _MemorySalonReviewRecord> _salonReviewsByBookingId =
      <String, _MemorySalonReviewRecord>{};
  final Map<String, _MemoryProductReviewRecord> _productReviewsByKey =
      <String, _MemoryProductReviewRecord>{};
  final Map<String, Set<String>> _pushTokensByUserId = <String, Set<String>>{};
  final Map<String, String> _emailOtpCodesByKey = <String, String>{};
  final Map<String, String> _passwordResetTokensByEmail = <String, String>{};
  final List<PromoCouponRecord> _promoCoupons = <PromoCouponRecord>[
    const PromoCouponRecord(
      id: 'coupon-001',
      code: 'FRESH20',
      description: '20% welcome discount for the first order only.',
      discountPercent: 20,
      isActive: true,
    ),
  ];

  @override
  Future<String?> pickAndUploadProfileImage({
    required String profileKey,
  }) async {
    final PreparedUploadFile? uploadFile = await pickFreshlineImageUpload(
      dialogTitle: 'Select profile image',
    );
    if (uploadFile == null) {
      return null;
    }

    return Uri.dataFromBytes(
      uploadFile.bytes,
      mimeType: uploadFile.contentType,
    ).toString();
  }

  @override
  Future<String?> pickAndUploadSalonProductImage({
    required String productKey,
  }) async {
    final PreparedUploadFile? uploadFile = await pickFreshlineImageUpload(
      dialogTitle: 'Select product image',
    );
    if (uploadFile == null) {
      return null;
    }

    return Uri.dataFromBytes(
      uploadFile.bytes,
      mimeType: uploadFile.contentType,
    ).toString();
  }

  @override
  Future<String?> pickAndUploadPlatformDefaultImage({
    required PlatformMediaType mediaType,
  }) async {
    final PreparedUploadFile? uploadFile = await pickFreshlineImageUpload(
      dialogTitle: 'Select ${mediaType.value} default image',
    );
    if (uploadFile == null) {
      return null;
    }

    return Uri.dataFromBytes(
      uploadFile.bytes,
      mimeType: uploadFile.contentType,
    ).toString();
  }

  @override
  Future<PlatformMediaDefaults> loadPlatformMediaDefaults() async {
    return currentPlatformMediaDefaults;
  }

  @override
  Future<PlatformMediaDefaults> savePlatformMediaDefaults({
    required AppUser actor,
    required PlatformMediaDefaults defaults,
  }) async {
    if (actor.role != AppRole.admin || !actor.isAdminOwner) {
      throw StateError('Only the admin owner can update default images.');
    }
    applyPlatformMediaDefaults(defaults);
    return defaults;
  }

  @override
  Future<SignInAttempt> beginSignIn({
    required AppRole role,
    required String email,
    required String password,
  }) async {
    final AppUser? user = _usersByEmail[email.trim().toLowerCase()];
    if (user == null || user.role != role) {
      throw StateError('Account was not found for this role.');
    }

    final String userId = user.profileId ?? '';
    if (!verifyProfilePassword(
      storedPasswordHash: _passwordsByUserId[userId] ?? '',
      password: password,
    )) {
      throw StateError('Email or password is incorrect.');
    }

    if (_isActiveByUserId[userId] == false) {
      throw StateError('This account is disabled.');
    }

    if (role == AppRole.employee) {
      final String? employeeId = _employeeIdByProfileId[userId];
      if (employeeId == null) {
        throw StateError('Employee account details were not found.');
      }
      final Employee? employee = _employeesBySalonId.values
          .expand((List<Employee> items) => items)
          .where((Employee item) => item.id == employeeId)
          .firstOrNull;
      if (employee == null || !employee.canLogin) {
        throw StateError('This employee account cannot sign in yet.');
      }
      if (!employee.isActive) {
        throw StateError('This employee account is paused.');
      }
    }

    return SignInAttempt.authenticated(user: user);
  }

  @override
  Future<AppUser> completeTwoFactorSignIn({
    required String email,
    required String profileId,
    required String code,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final AppUser? user = _usersByEmail[normalizedEmail];
    if (user == null) {
      throw StateError('Account was not found.');
    }

    final String otpKey = _authEmailOtpKey(
      email: normalizedEmail,
      purpose: _twoFactorSignInOtpPurpose,
      profileId: profileId,
    );
    if (_emailOtpCodesByKey[otpKey] != code.trim()) {
      throw StateError('The verification code is invalid or has expired.');
    }
    _emailOtpCodesByKey.remove(otpKey);
    return user;
  }

  @override
  Future<AppUser> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String password,
    String? avatarPath,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(phone);
    final String normalizedCity = normalizeBahrainLocation(city);
    if (_usersByEmail.containsKey(normalizedEmail)) {
      throw StateError('This email is already used by another account.');
    }

    final String userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final AppUser user = AppUser(
      profileId: userId,
      name: name.trim(),
      email: normalizedEmail,
      phone: normalizedPhone,
      city: normalizedCity,
      role: AppRole.customer,
      avatarPath: normalizeProfileImageUrl(avatarPath),
      isEmailVerified: false,
    );
    _usersByEmail[normalizedEmail] = user;
    _passwordsByUserId[userId] = hashProfilePassword(password);
    _isActiveByUserId[userId] = true;
    return user;
  }

  @override
  Future<void> verifyEmailAddressCode({
    required String email,
    required String code,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final AppUser? user = _usersByEmail[normalizedEmail];
    if (user == null) {
      throw StateError('The verification code is invalid or has expired.');
    }

    final String otpKey = _authEmailOtpKey(
      email: normalizedEmail,
      purpose: _emailVerificationOtpPurpose,
      profileId: user.profileId,
    );
    if (_emailOtpCodesByKey[otpKey] != code.trim()) {
      throw StateError('The verification code is invalid or has expired.');
    }

    _emailOtpCodesByKey.remove(otpKey);
    _storeUser(user.copyWith(isEmailVerified: true));
  }

  @override
  Future<AuthOtpDispatchResult> sendEmailVerificationCode({
    required String email,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final AppUser? user = _usersByEmail[normalizedEmail];
    if (user == null || user.isEmailVerified) {
      return const AuthOtpDispatchResult();
    }

    _emailOtpCodesByKey[_authEmailOtpKey(
          email: normalizedEmail,
          purpose: _emailVerificationOtpPurpose,
          profileId: user.profileId,
        )] =
        _memoryOtpCode;
    return const AuthOtpDispatchResult(
      previewCode: _memoryOtpCode,
      usedLocalFallback: true,
    );
  }

  @override
  Future<AppUser> updateProfile({
    required AppUser user,
    required String name,
    required String phone,
    required String city,
    required String address,
    required String avatarPath,
  }) async {
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(phone);
    final String normalizedCity = normalizeBahrainLocation(city);
    final AppUser updated = user.copyWith(
      name: name.trim(),
      phone: normalizedPhone,
      city: normalizedCity,
      address: address.trim(),
      avatarPath: normalizeProfileImageUrl(avatarPath),
    );
    _storeUser(updated);
    return updated;
  }

  @override
  Future<AppUser> refreshUser({required AppUser user}) async {
    return _usersByEmail[user.email.trim().toLowerCase()] ?? user;
  }

  @override
  Future<AppUser> updatePreferredLanguage({
    required AppUser user,
    required String languageCode,
  }) async {
    final String normalizedLanguage = languageCode.trim().toUpperCase() == 'AR'
        ? 'AR'
        : 'EN';
    final AppUser updated = user.copyWith(
      preferredLanguage: normalizedLanguage,
    );
    _storeUser(updated);
    return updated;
  }

  @override
  Future<void> changePassword({
    required AppUser user,
    required String currentPassword,
    required String newPassword,
  }) async {
    final String userId = user.profileId ?? '';
    if (!verifyProfilePassword(
      storedPasswordHash: _passwordsByUserId[userId] ?? '',
      password: currentPassword,
    )) {
      throw StateError('The current password is incorrect.');
    }
    _passwordsByUserId[userId] = hashProfilePassword(newPassword);
  }

  @override
  Future<AuthOtpDispatchResult> sendPasswordResetCode({
    required String email,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final AppUser? user = _usersByEmail[normalizedEmail];
    if (user == null) {
      throw StateError('This email is not registered.');
    }
    _emailOtpCodesByKey[_authEmailOtpKey(
          email: normalizedEmail,
          purpose: _passwordResetOtpPurpose,
          profileId: user.profileId,
        )] =
        _memoryOtpCode;
    return const AuthOtpDispatchResult(
      previewCode: _memoryOtpCode,
      usedLocalFallback: true,
    );
  }

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final AppUser? user = _usersByEmail[normalizedEmail];
    if (user == null) {
      throw StateError('The verification code is invalid or has expired.');
    }
    final String otpKey = _authEmailOtpKey(
      email: normalizedEmail,
      purpose: _passwordResetOtpPurpose,
      profileId: user.profileId,
    );
    if (_emailOtpCodesByKey[otpKey] != code.trim()) {
      throw StateError('The verification code is invalid or has expired.');
    }
    _emailOtpCodesByKey.remove(otpKey);
    final String token =
        'reset-${user.profileId ?? normalizedEmail}-${DateTime.now().millisecondsSinceEpoch}';
    _passwordResetTokensByEmail[normalizedEmail] = token;
    return token;
  }

  @override
  Future<void> completePasswordReset({
    required String email,
    required String verificationToken,
    required String newPassword,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final AppUser? user = _usersByEmail[normalizedEmail];
    if (user == null ||
        _passwordResetTokensByEmail[normalizedEmail] !=
            verificationToken.trim()) {
      throw StateError('Freshline could not complete the password reset.');
    }
    _passwordResetTokensByEmail.remove(normalizedEmail);
    final String userId = user.profileId ?? '';
    if (userId.isEmpty) {
      throw StateError(
        'Freshline could not reset the password for this account.',
      );
    }
    _passwordsByUserId[userId] = hashProfilePassword(newPassword);
  }

  @override
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final String verificationToken = await verifyPasswordResetCode(
      email: email,
      code: code,
    );
    await completePasswordReset(
      email: email,
      verificationToken: verificationToken,
      newPassword: newPassword,
    );
  }

  @override
  Future<List<CustomerRatingReview>> loadSalonReviews({
    required String salonId,
  }) async {
    final String normalizedSalonId = salonId.trim();
    if (normalizedSalonId.isEmpty) {
      return const <CustomerRatingReview>[];
    }
    return const <CustomerRatingReview>[];
  }

  @override
  Future<List<CustomerRatingReview>> loadEmployeeReviews({
    required String employeeId,
  }) async {
    final String normalizedEmployeeId = employeeId.trim();
    if (normalizedEmployeeId.isEmpty) {
      return const <CustomerRatingReview>[];
    }
    return const <CustomerRatingReview>[];
  }

  @override
  Future<AuthOtpDispatchResult> sendEmailTwoFactorSetupCode({
    required AppUser user,
  }) async {
    return const AuthOtpDispatchResult();
  }

  @override
  Future<AppUser> enableEmailTwoFactor({
    required AppUser user,
    required String code,
  }) async {
    final AppUser updated = user.copyWith(isEmailTwoFactorEnabled: false);
    _storeUser(updated);
    return updated;
  }

  @override
  Future<AppUser> disableEmailTwoFactor({required AppUser user}) async {
    final AppUser updated = user.copyWith(isEmailTwoFactorEnabled: false);
    _storeUser(updated);
    return updated;
  }

  void _storeUser(AppUser user) {
    _usersByEmail.remove(user.email.toLowerCase());
    _usersByEmail[user.email.toLowerCase()] = user;
  }

  String _authEmailOtpKey({
    required String email,
    required String purpose,
    String? profileId,
  }) {
    final String normalizedProfileId = (profileId ?? '').trim();
    return '${email.trim().toLowerCase()}|$purpose|$normalizedProfileId';
  }

  @override
  Future<List<PaymentCardInfo>> loadSavedCards({required AppUser user}) async {
    return List<PaymentCardInfo>.from(
      _cardsByUserId[user.profileId] ?? const <PaymentCardInfo>[],
    );
  }

  @override
  Future<List<SavedCustomerAddress>> loadSavedAddresses({
    required AppUser user,
  }) async {
    return List<SavedCustomerAddress>.from(
      _addressesByUserId[user.profileId] ?? const <SavedCustomerAddress>[],
    );
  }

  @override
  Future<PaymentCardInfo> saveCard({
    required AppUser user,
    required PaymentCardInfo card,
  }) async {
    final List<PaymentCardInfo> cards = _cardsByUserId.putIfAbsent(
      user.profileId ?? '',
      () => <PaymentCardInfo>[],
    );
    cards.removeWhere((PaymentCardInfo item) => item.id == card.id);
    cards.insert(0, card);
    return card;
  }

  @override
  Future<void> removeSavedCard({
    required AppUser user,
    required PaymentCardInfo card,
  }) async {
    final List<PaymentCardInfo>? cards = _cardsByUserId[user.profileId ?? ''];
    cards?.removeWhere((PaymentCardInfo item) => item.id == card.id);
  }

  @override
  Future<SubscriptionPlan?> loadActivePlan({required AppUser user}) async {
    return _customerSubscriptionsByUserId[user.profileId ?? '']?.plan;
  }

  @override
  Future<CustomerSubscriptionStatus?> loadCustomerSubscriptionStatus({
    required AppUser user,
  }) async {
    return _customerSubscriptionsByUserId[user.profileId ?? ''];
  }

  @override
  Future<CustomerSubscriptionStatus?> updateCustomerSubscriptionAutoRenew({
    required AppUser user,
    required bool autoRenew,
  }) async {
    final CustomerSubscriptionStatus? current =
        _customerSubscriptionsByUserId[user.profileId ?? ''];
    if (current == null) {
      return null;
    }
    final CustomerSubscriptionStatus updated = current.copyWith(
      autoRenew: autoRenew,
    );
    _customerSubscriptionsByUserId[user.profileId ?? ''] = updated;
    _recordMemoryActivity(
      actor: user,
      actionType: 'customer_subscription_auto_renew_updated',
      targetTable: 'customer_subscriptions',
      targetId: user.profileId,
      actionSummary:
          '${user.name} turned ${autoRenew ? 'on' : 'off'} auto-renew for the ${updated.plan.name} plan.',
    );
    return updated;
  }

  @override
  Future<List<PromoCouponRecord>> loadPromoCoupons({
    bool activeOnly = false,
  }) async {
    final DateTime now = DateTime.now();
    return _promoCoupons
        .where(
          (PromoCouponRecord coupon) =>
              !coupon.isSalonCoupon &&
              (!activeOnly || (coupon.isActive && coupon.isAvailableAt(now))),
        )
        .map((PromoCouponRecord coupon) => coupon.copyWith())
        .toList(growable: false);
  }

  @override
  Future<void> subscribeToPlan({
    required AppUser user,
    required SubscriptionPlan plan,
    required PaymentCardInfo card,
  }) async {
    final DateTime now = DateTime.now();
    _customerSubscriptionsByUserId[user.profileId ??
        ''] = CustomerSubscriptionStatus(
      plan: plan,
      startsAt: now,
      endsAt: now.add(const Duration(days: 30)),
      autoRenew: true,
    );
    _recordMemoryActivity(
      actor: user,
      actionType: 'customer_subscription_started',
      targetTable: 'customer_subscriptions',
      targetId: user.profileId,
      actionSummary:
          '${user.name} subscribed to the ${plan.name} plan using ${card.displayLabel}.',
    );
  }

  @override
  Future<CustomerCommerceSnapshot> loadCustomerCommerce({
    required AppUser user,
  }) async {
    final List<UserOrder> orders = List<UserOrder>.from(
      _ordersByUserId[user.profileId ?? ''] ?? const <UserOrder>[],
    );
    final List<UserOrder> activeOrders = orders
        .where((UserOrder order) => !_isCompletedOrder(order))
        .toList(growable: false);
    final List<UserOrder> completedOrders = orders
        .where(_isCompletedOrder)
        .toList(growable: false);
    final Set<String> bookedSlotKeys = _ordersByUserId.values
        .expand((List<UserOrder> items) => items)
        .where(
          (UserOrder order) =>
              !order.isProductOrder &&
              !_isCompletedOrder(order) &&
              order.salonId != null &&
              order.employeeId != null,
        )
        .map(
          (UserOrder order) => _bookingSlotKey(
            salonId: order.salonId!,
            employeeId: order.employeeId!,
            scheduledAt: order.scheduledAt,
          ),
        )
        .toSet();

    return CustomerCommerceSnapshot(
      activeOrders: activeOrders,
      completedOrders: completedOrders,
      bookedSlotKeys: bookedSlotKeys,
      loyaltyPoints: _loyaltyPointsByUserId[user.profileId ?? ''] ?? 0,
    );
  }

  @override
  Future<List<Employee>> loadSalonEmployees({required String salonId}) async {
    final List<Employee> employees = List<Employee>.from(
      _employeesBySalonId[salonId] ?? const <Employee>[],
    );
    if (employees.isEmpty) {
      return const <Employee>[];
    }
    return employees
        .map(_hydrateMemoryEmployee)
        .where((Employee employee) => employee.isActive)
        .toList(growable: false);
  }

  @override
  Future<Map<String, List<EmployeeScheduleEntry>>> loadEmployeeSchedules({
    required List<String> employeeIds,
  }) async {
    final Map<String, List<EmployeeScheduleEntry>> schedules =
        <String, List<EmployeeScheduleEntry>>{};
    for (final String employeeId in employeeIds) {
      final String normalized = employeeId.trim();
      if (normalized.isEmpty) {
        continue;
      }
      schedules[normalized] = <EmployeeScheduleEntry>[
        for (int weekday = 0; weekday <= 6; weekday += 1)
          EmployeeScheduleEntry(
            id: 'mem-$normalized-$weekday',
            employeeId: normalized,
            weekday: weekday,
            startMinutes: 9 * 60,
            endMinutes: 22 * 60,
            supportsInShop: true,
            supportsHomeService: true,
            isAvailable: true,
          ),
      ];
    }
    return schedules;
  }

  @override
  Future<SalonSubscriptionStatus?> activateSalonSubscription({
    required AppUser user,
    required SubscriptionCycleOption cycle,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(user);
    final DateTime now = DateTime.now();
    final bool autoRenew =
        _salonSubscriptionsBySalonId[salonId]?.autoRenew ?? false;
    final SalonSubscriptionStatus status = SalonSubscriptionStatus(
      cycle: cycle,
      amount: cycle.salonPrice,
      expiresAt: now.add(
        Duration(days: cycle == SubscriptionCycleOption.yearly ? 365 : 30),
      ),
      autoRenew: autoRenew,
    );
    _salonSubscriptionsBySalonId[salonId] = status;
    final String salonName =
        salons.where((Salon item) => item.id == salonId).firstOrNull?.name ??
        'Salon';
    _recordMemoryActivity(
      actor: user,
      actionType: 'salon_subscription_started',
      targetTable: 'salons',
      targetId: salonId,
      actionSummary:
          '${user.name} activated the ${cycle.label.toLowerCase()} plan for $salonName.',
    );
    return status;
  }

  @override
  Future<SalonSubscriptionStatus?> updateSalonSubscriptionAutoRenew({
    required AppUser user,
    required bool autoRenew,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(user);
    final SalonSubscriptionStatus? current =
        _salonSubscriptionsBySalonId[salonId];
    if (current == null) {
      return null;
    }
    final SalonSubscriptionStatus updated = current.copyWith(
      autoRenew: autoRenew,
    );
    _salonSubscriptionsBySalonId[salonId] = updated;
    final String salonName =
        salons.where((Salon item) => item.id == salonId).firstOrNull?.name ??
        'Salon';
    _recordMemoryActivity(
      actor: user,
      actionType: 'salon_subscription_auto_renew_updated',
      targetTable: 'salons',
      targetId: salonId,
      actionSummary:
          '${user.name} turned ${autoRenew ? 'on' : 'off'} auto-renew for $salonName.',
    );
    return updated;
  }

  @override
  Future<void> placeProductOrder({
    required AppUser user,
    required UserOrder order,
    required List<ProductOrderLineItem> items,
    required DeliveryLocationSelection location,
    required String addressDetails,
    required String? couponCode,
    required num couponDiscount,
    required int loyaltyPointsRedeemed,
    required num loyaltyDiscount,
    required num taxAmount,
  }) async {
    final String userId = user.profileId ?? '';
    await _rememberAddress(
      user: user,
      addressDetails: addressDetails,
      location: location,
    );
    await _reserveMemoryProductStock(items);
    final List<UserOrder> orders = _ordersByUserId.putIfAbsent(
      userId,
      () => <UserOrder>[],
    );
    orders.insert(
      0,
      order.copyWith(
        invoiceNumber: order.displayInvoiceNumber,
        customerName: user.name,
        customerPhone: user.phone,
        productItems: items
            .map(
              (ProductOrderLineItem item) => RatedOrderProductItem(
                productId: item.productId,
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
              ),
            )
            .toList(growable: false),
      ),
    );
    final int nextBalance =
        (_loyaltyPointsByUserId[userId] ?? 0) -
        loyaltyPointsRedeemed +
        order.loyaltyPointsGained;
    _loyaltyPointsByUserId[userId] = nextBalance < 0 ? 0 : nextBalance;
    _recordMemoryActivity(
      actor: user,
      actionType: 'product_order_paid',
      targetTable: 'product_orders',
      targetId: order.id,
      actionSummary:
          '${user.name} placed product order ${order.displayInvoiceNumber} for BHD ${order.total.toStringAsFixed(2)}.',
    );
  }

  @override
  Future<void> placeSalonBooking({
    required AppUser user,
    required UserOrder order,
  }) async {
    final bool slotTaken = _ordersByUserId.values
        .expand((List<UserOrder> items) => items)
        .where(
          (UserOrder item) =>
              !item.isProductOrder &&
              !_isCompletedOrder(item) &&
              item.salonId == order.salonId &&
              item.employeeId == order.employeeId,
        )
        .any(
          (UserOrder item) =>
              item.scheduledAt.isAtSameMomentAs(order.scheduledAt),
        );
    if (slotTaken) {
      throw StateError(
        'This time was just booked. Please choose another slot.',
      );
    }

    final String userId = user.profileId ?? '';
    if (order.location != null &&
        (order.addressDetails ?? '').trim().isNotEmpty) {
      await _rememberAddress(
        user: user,
        addressDetails: order.addressDetails!,
        location: order.location!,
      );
    }
    final List<UserOrder> orders = _ordersByUserId.putIfAbsent(
      userId,
      () => <UserOrder>[],
    );
    orders.insert(
      0,
      order.copyWith(
        invoiceNumber: order.displayInvoiceNumber,
        customerName: user.name,
        customerPhone: user.phone,
      ),
    );
    _loyaltyPointsByUserId[userId] =
        (_loyaltyPointsByUserId[userId] ?? 0) + order.loyaltyPointsGained;
    _recordMemoryActivity(
      actor: user,
      actionType: 'salon_booking_paid',
      targetTable: 'salon_bookings',
      targetId: order.id,
      actionSummary:
          '${user.name} booked ${order.serviceName} at ${order.salonName} for BHD ${order.total.toStringAsFixed(2)}.',
    );
  }

  @override
  Future<void> completeOrder({
    required AppUser user,
    required UserOrder order,
  }) async {
    _updateMemoryOrderEverywhere(
      orderId: order.id,
      mutate: (UserOrder current) => current.copyWith(
        statusLabel: current.isProductOrder ? 'Delivered' : 'Completed',
      ),
    );
    if (user.role == AppRole.admin && order.isProductOrder) {
      _recordMemoryActivity(
        actor: user,
        actionType: 'admin_product_order_completed',
        targetTable: 'product_orders',
        targetId: order.id,
        actionSummary:
            '${user.name} marked product order ${order.displayInvoiceNumber} as delivered.',
      );
    }
  }

  @override
  Future<void> submitSalonReview({
    required AppUser user,
    required UserOrder order,
    required int salonRating,
    required int employeeRating,
    String comment = '',
  }) async {
    _salonReviewsByBookingId[order.id] = _MemorySalonReviewRecord(
      bookingId: order.id,
      salonId: order.salonId ?? '',
      employeeId: order.employeeId ?? '',
      salonRating: salonRating,
      employeeRating: employeeRating,
      comment: comment.trim(),
    );
    _updateMemoryOrder(
      userId: user.profileId ?? '',
      orderId: order.id,
      mutate: (UserOrder current) => current.copyWith(
        salonReviewSubmitted: true,
        employeeReviewSubmitted: true,
      ),
    );
    _recalculateMemoryEmployeeRatings(order.employeeId);
  }

  @override
  Future<void> submitProductReview({
    required AppUser user,
    required UserOrder order,
    required String productId,
    required int rating,
    String comment = '',
  }) async {
    final String key = '${order.id}|$productId';
    _productReviewsByKey[key] = _MemoryProductReviewRecord(
      orderId: order.id,
      productId: productId,
      rating: rating,
      comment: comment.trim(),
    );
    _updateMemoryOrder(
      userId: user.profileId ?? '',
      orderId: order.id,
      mutate: (UserOrder current) => current.copyWith(
        productItems: current.productItems
            .map(
              (RatedOrderProductItem item) => item.productId == productId
                  ? item.copyWith(
                      reviewSubmitted: true,
                      existingRating: rating.toDouble(),
                    )
                  : item,
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<SalonWorkspaceSnapshot> loadSalonWorkspace({
    required AppUser user,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(user);
    final Salon salon = salons.firstWhere(
      (Salon item) => item.id == salonId,
      orElse: () => salons.first,
    );
    final List<ServicePackage> packages = List<ServicePackage>.from(
      _packagesBySalonId[salonId] ?? const <ServicePackage>[],
    )..sort((ServicePackage a, ServicePackage b) => a.name.compareTo(b.name));
    final List<ServiceItem> services = List<ServiceItem>.from(
      _servicesBySalonId[salonId] ?? const <ServiceItem>[],
    )..sort((ServiceItem a, ServiceItem b) => a.name.compareTo(b.name));
    final List<Product> productsForSalon = List<Product>.from(
      _productsBySalonId[salonId] ?? const <Product>[],
    )..sort((Product a, Product b) => a.name.compareTo(b.name));
    final List<PromoCouponRecord> salonCoupons =
        _promoCoupons
            .where((PromoCouponRecord coupon) => coupon.salonId == salonId)
            .map((PromoCouponRecord coupon) => coupon.copyWith())
            .toList(growable: false)
          ..sort((PromoCouponRecord a, PromoCouponRecord b) {
            final DateTime aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
            final DateTime bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
    final List<Employee> employees =
        (_employeesBySalonId[salonId] ?? const <Employee>[])
            .map(_hydrateMemoryEmployee)
            .toList(growable: false);
    final List<EmployeeSalaryPayment> salaryPayments =
        List<EmployeeSalaryPayment>.from(
          _salaryPaymentsBySalonId[salonId] ?? const <EmployeeSalaryPayment>[],
        )..sort(
          (EmployeeSalaryPayment a, EmployeeSalaryPayment b) =>
              b.confirmedAt.compareTo(a.confirmedAt),
        );
    final List<UserOrder> allBookings =
        _ordersByUserId.entries
            .expand((MapEntry<String, List<UserOrder>> entry) {
              final AppUser? customer = _usersByEmail.values
                  .where((AppUser item) => item.profileId == entry.key)
                  .firstOrNull;
              return entry.value
                  .where(
                    (UserOrder order) =>
                        !order.isProductOrder && order.salonId == salonId,
                  )
                  .map(
                    (UserOrder order) => order.copyWith(
                      customerName: customer?.name ?? order.customerName,
                      customerPhone: customer?.phone ?? order.customerPhone,
                    ),
                  );
            })
            .toList(growable: false)
          ..sort(
            (UserOrder a, UserOrder b) =>
                b.scheduledAt.compareTo(a.scheduledAt),
          );
    final Set<String> salonProductIds = productsForSalon
        .map((Product item) => item.id)
        .where((String id) => id.trim().isNotEmpty)
        .toSet();
    final List<UserOrder> allProductOrders =
        _ordersByUserId.entries
            .expand((MapEntry<String, List<UserOrder>> entry) {
              final AppUser? customer = _usersByEmail.values
                  .where((AppUser item) => item.profileId == entry.key)
                  .firstOrNull;
              return entry.value
                  .where(
                    (UserOrder order) =>
                        order.isProductOrder &&
                        _memoryProductOrderMatchesSalon(
                          order: order,
                          salonId: salonId,
                          salonProductIds: salonProductIds,
                        ),
                  )
                  .map(
                    (UserOrder order) => order.copyWith(
                      salonId: salonId,
                      salonName: salon.name,
                      customerName: customer?.name ?? order.customerName,
                      customerPhone: customer?.phone ?? order.customerPhone,
                      employeeName: (order.employeeId ?? '').trim().isEmpty
                          ? 'Available for team'
                          : order.employeeName,
                    ),
                  );
            })
            .toList(growable: false)
          ..sort(
            (UserOrder a, UserOrder b) =>
                b.scheduledAt.compareTo(a.scheduledAt),
          );
    final Employee? currentEmployee = user.role == AppRole.employee
        ? employees
              .where((Employee item) => item.profileId == user.profileId)
              .firstOrNull
        : null;
    final List<UserOrder> visibleBookings = currentEmployee == null
        ? allBookings
        : allBookings
              .where(
                (UserOrder order) => order.employeeId == currentEmployee.id,
              )
              .toList(growable: false);
    final List<UserOrder> visibleProductOrders = currentEmployee == null
        ? allProductOrders
        : allProductOrders
              .where((UserOrder order) {
                final String assignedEmployeeId = (order.employeeId ?? '')
                    .trim();
                return assignedEmployeeId.isEmpty ||
                    assignedEmployeeId == currentEmployee.id;
              })
              .toList(growable: false);
    final double bookingRevenue = allBookings.fold<double>(
      0,
      (double sum, UserOrder order) => sum + (order.total.toDouble()),
    );
    final double productRevenue = allProductOrders.fold<double>(
      0,
      (double sum, UserOrder order) =>
          sum +
          order.productItems.fold<double>(
            0,
            (double orderSum, RatedOrderProductItem item) =>
                orderSum + item.lineTotal.toDouble(),
          ),
    );
    final double salaryCost = salaryPayments.fold<double>(
      0,
      (double sum, EmployeeSalaryPayment payment) => sum + payment.amount,
    );
    final double monthlySalaryBaseline = employees
        .where((Employee employee) => employee.isActive)
        .fold<double>(
          0,
          (double sum, Employee employee) => sum + employee.monthlySalary,
        );
    final SalonSubscriptionStatus subscriptionStatus =
        _salonSubscriptionsBySalonId[salonId] ??
        const SalonSubscriptionStatus(
          cycle: SubscriptionCycleOption.monthly,
          amount: salonMonthlySubscriptionPrice,
        );
    final double subscriptionCost = subscriptionStatus.amount;
    final int completedBookings = allBookings
        .where((UserOrder order) => _isCompletedOrder(order))
        .length;
    final int upcomingBookings = allBookings.length - completedBookings;

    return SalonWorkspaceSnapshot(
      salon: Salon(
        id: salon.id,
        name: salon.name,
        imagePath: salon.imagePath,
        rating: salon.rating,
        reviews: salon.reviews,
        location: salon.location,
        distance: salon.distance,
        services: salon.services,
        description: salon.description,
        phone: salon.phone,
        priceLabel: salon.priceLabel,
        homeServiceAvailable: salon.homeServiceAvailable,
        address: salon.address,
        latitude: salon.latitude,
        longitude: salon.longitude,
        packages: packages
            .where((ServicePackage item) => item.isActive)
            .toList(growable: false),
        serviceItems: services
            .where((ServiceItem item) => item.isActive)
            .toList(growable: false),
      ),
      employees: employees,
      bookings: visibleBookings,
      productOrders: visibleProductOrders,
      finance: SalonFinanceSnapshot(
        bookingRevenue: bookingRevenue,
        productRevenue: productRevenue,
        subscriptionCost: subscriptionCost,
        salaryCost: salaryCost == 0 ? monthlySalaryBaseline : salaryCost,
        bookingProfit:
            bookingRevenue -
            (salaryCost == 0 ? monthlySalaryBaseline : salaryCost) -
            subscriptionCost,
        completedBookings: completedBookings,
        upcomingBookings: upcomingBookings,
      ),
      salaryPayments: salaryPayments,
      packages: packages,
      services: services,
      products: productsForSalon,
      coupons: salonCoupons,
      subscriptionStatus: subscriptionStatus,
      currentEmployee: currentEmployee,
    );
  }

  @override
  Future<void> takeSalonProductOrder({
    required AppUser actor,
    required String orderId,
  }) async {
    if (actor.role != AppRole.employee) {
      throw StateError('Only employees can take product orders.');
    }
    final String employeeId =
        _employeeIdByProfileId[actor.profileId ?? ''] ?? '';
    if (employeeId.trim().isEmpty) {
      throw StateError('Employee account details were not found.');
    }
    final String normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      throw StateError('Product order details are missing.');
    }
    _updateMemoryOrderEverywhere(
      orderId: normalizedOrderId,
      mutate: (UserOrder current) {
        if (!current.isProductOrder) {
          return current;
        }
        final String existingEmployeeId = (current.employeeId ?? '').trim();
        if (existingEmployeeId.isNotEmpty && existingEmployeeId != employeeId) {
          throw StateError(
            'This product order was already taken by another employee.',
          );
        }
        if (existingEmployeeId == employeeId) {
          return current;
        }
        return current.copyWith(
          employeeId: employeeId,
          employeeName: actor.name,
          statusLabel: _isCompletedOrder(current)
              ? current.statusLabel
              : 'Accepted',
        );
      },
    );
  }

  @override
  Future<List<UserOrder>> loadAdminProductOrders({
    required AppUser actor,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can view customer product orders.');
    }
    return _ordersByUserId.values
        .expand((List<UserOrder> items) => items)
        .where((UserOrder order) => order.isProductOrder)
        .map((UserOrder order) => order.copyWith())
        .toList(growable: false)
      ..sort((UserOrder a, UserOrder b) {
        return b.scheduledAt.compareTo(a.scheduledAt);
      });
  }

  @override
  Future<void> takeAdminProductOrder({
    required AppUser actor,
    required String orderId,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can take product orders.');
    }
    final String adminId = (actor.profileId ?? '').trim();
    if (adminId.isEmpty) {
      throw StateError('Admin account details are missing.');
    }
    final String normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      throw StateError('Product order details are missing.');
    }
    _updateMemoryOrderEverywhere(
      orderId: normalizedOrderId,
      mutate: (UserOrder current) {
        if (!current.isProductOrder) {
          return current;
        }
        final String existingAssigneeId = (current.employeeId ?? '').trim();
        if (existingAssigneeId.isNotEmpty && existingAssigneeId != adminId) {
          throw StateError(
            'This product order was already taken by another admin.',
          );
        }
        if (existingAssigneeId == adminId) {
          return current;
        }
        return current.copyWith(
          employeeId: adminId,
          employeeName: actor.name,
          statusLabel: _isCompletedOrder(current)
              ? current.statusLabel
              : 'Accepted',
        );
      },
    );
    _recordMemoryActivity(
      actor: actor,
      actionType: 'admin_product_order_taken',
      targetTable: 'product_orders',
      targetId: normalizedOrderId,
      actionSummary:
          '${actor.name} accepted customer product order ${normalizeFreshlineInvoiceNumber(null, sourceId: normalizedOrderId)}.',
    );
  }

  @override
  Future<Employee> saveSalonEmployee({
    required AppUser actor,
    String? employeeId,
    String? profileId,
    required String name,
    required String roleTitle,
    required String email,
    required String phone,
    required double monthlySalary,
    required bool supportsInShop,
    required bool supportsHomeService,
    required bool canLogin,
    String? workStartTime,
    String? workEndTime,
    String? breakStartTime,
    String? breakEndTime,
    String? password,
    String? avatarPath,
  }) async {
    int? parseMinutes(String? value) {
      final String raw = (value ?? '').trim();
      if (raw.isEmpty) {
        return null;
      }
      final RegExp match = RegExp(r'^(\\d{1,2}):(\\d{2})(?::\\d{2})?$');
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

    final String normalizedPhone = normalizeBahrainPhoneOrThrow(
      phone,
      fieldLabel: 'Employee phone number',
    );
    final String normalizedActorCity = normalizeBahrainLocation(actor.city);
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final List<Employee> employees = _employeesBySalonId.putIfAbsent(
      salonId,
      () => <Employee>[],
    );
    final String normalizedEmail = email.trim().toLowerCase();
    final Employee? existingEmployee = employees
        .where((Employee item) => item.id == (employeeId ?? '').trim())
        .firstOrNull;
    final String resolvedProfileId = (profileId ?? '').trim().isNotEmpty
        ? profileId!.trim()
        : 'profile-${employeeId ?? DateTime.now().millisecondsSinceEpoch}';
    final String resolvedEmployeeId = (employeeId ?? '').trim().isNotEmpty
        ? employeeId!.trim()
        : 'emp-${DateTime.now().millisecondsSinceEpoch}';

    final AppUser employeeUser = AppUser(
      profileId: resolvedProfileId,
      name: name.trim(),
      email: normalizedEmail,
      phone: normalizedPhone,
      city: normalizedActorCity,
      role: AppRole.employee,
      avatarPath: normalizeProfileImageUrl(avatarPath),
    );
    _usersByEmail[normalizedEmail] = employeeUser;
    _passwordsByUserId[resolvedProfileId] = hashProfilePassword(
      (password ?? '').trim().isEmpty ? 'freshline123' : password!.trim(),
    );
    _isActiveByUserId[resolvedProfileId] = true;
    _employeeIdByProfileId[resolvedProfileId] = resolvedEmployeeId;

    final Employee employee = Employee(
      id: resolvedEmployeeId,
      profileId: resolvedProfileId,
      name: name.trim(),
      imagePath: employeeUser.avatarPath,
      role: roleTitle.trim(),
      rating: existingEmployee?.rating ?? 0,
      reviewsCount: existingEmployee?.reviewsCount ?? 0,
      email: normalizedEmail,
      phone: normalizedPhone,
      monthlySalary: monthlySalary,
      supportsInShop: supportsInShop,
      supportsHomeService: supportsHomeService,
      canLogin: canLogin,
      isActive: true,
      availabilityLabel: 'Available today',
      workStartMinutes:
          parseMinutes(workStartTime) ?? existingEmployee?.workStartMinutes,
      workEndMinutes:
          parseMinutes(workEndTime) ?? existingEmployee?.workEndMinutes,
      breakStartMinutes:
          parseMinutes(breakStartTime) ?? existingEmployee?.breakStartMinutes,
      breakEndMinutes:
          parseMinutes(breakEndTime) ?? existingEmployee?.breakEndMinutes,
      salaryPaidForMonth: existingEmployee?.salaryPaidForMonth,
      salaryLastPaidAt: existingEmployee?.salaryLastPaidAt,
    );

    final int existingIndex = employees.indexWhere(
      (Employee item) => item.id == resolvedEmployeeId,
    );
    if (existingIndex >= 0) {
      employees[existingIndex] = employee;
    } else {
      employees.insert(0, employee);
    }
    return employee;
  }

  @override
  Future<void> setSalonEmployeeActive({
    required AppUser actor,
    required String employeeId,
    required bool isActive,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final List<Employee> employees =
        _employeesBySalonId[salonId] ?? <Employee>[];
    final int index = employees.indexWhere(
      (Employee item) => item.id == employeeId,
    );
    if (index < 0) {
      return;
    }
    final Employee current = employees[index];
    employees[index] = current.copyWith(
      isActive: isActive,
      availabilityLabel: isActive ? 'Available today' : 'Account paused',
    );
    final String? linkedProfileId = current.profileId;
    if ((linkedProfileId ?? '').isNotEmpty) {
      _isActiveByUserId[linkedProfileId!] = isActive;
    }
  }

  @override
  Future<void> deleteSalonEmployee({
    required AppUser actor,
    required String employeeId,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final List<Employee> employees =
        _employeesBySalonId[salonId] ?? <Employee>[];
    final Employee? existing = employees
        .where((Employee item) => item.id == employeeId)
        .firstOrNull;
    if (existing == null) {
      return;
    }
    employees.removeWhere((Employee item) => item.id == employeeId);
    if ((existing.profileId ?? '').isNotEmpty) {
      _employeeIdByProfileId.remove(existing.profileId);
      _passwordsByUserId.remove(existing.profileId);
      _isActiveByUserId.remove(existing.profileId);
    }
    if (existing.email.isNotEmpty) {
      _usersByEmail.remove(existing.email.toLowerCase());
    }
  }

  @override
  Future<ServicePackage> saveSalonPackage({
    required AppUser actor,
    String? packageId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    required bool isActive,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final bool useArabic = _useArabicLanguage(actor.preferredLanguage);
    final List<ServicePackage> packages = _packagesBySalonId.putIfAbsent(
      salonId,
      () => <ServicePackage>[],
    );
    final ServicePackage saved = ServicePackage(
      id: (packageId ?? '').trim().isEmpty
          ? 'pkg-${DateTime.now().millisecondsSinceEpoch}'
          : packageId!.trim(),
      salonId: salonId,
      name: name.trim(),
      nameAr: useArabic || _containsArabicText(name) ? name.trim() : null,
      description: description.trim(),
      descriptionAr: useArabic || _containsArabicText(description)
          ? description.trim()
          : null,
      price: price,
      duration: '$durationMinutes min',
      isActive: isActive,
    );
    final int index = packages.indexWhere(
      (ServicePackage item) => item.id == saved.id,
    );
    if (index >= 0) {
      packages[index] = saved;
    } else {
      packages.insert(0, saved);
    }
    return saved;
  }

  @override
  Future<void> deleteSalonPackage({
    required AppUser actor,
    required String packageId,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final List<ServicePackage> packages =
        _packagesBySalonId[salonId] ?? <ServicePackage>[];
    packages.removeWhere((ServicePackage item) => item.id == packageId);
  }

  @override
  Future<ServiceItem> saveSalonService({
    required AppUser actor,
    String? serviceId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    required bool isActive,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final bool useArabic = _useArabicLanguage(actor.preferredLanguage);
    final List<ServiceItem> services = _servicesBySalonId.putIfAbsent(
      salonId,
      () => <ServiceItem>[],
    );
    final ServiceItem saved = ServiceItem(
      id: (serviceId ?? '').trim().isEmpty
          ? 'srv-${DateTime.now().millisecondsSinceEpoch}'
          : serviceId!.trim(),
      salonId: salonId,
      name: name.trim(),
      nameAr: useArabic || _containsArabicText(name) ? name.trim() : null,
      description: description.trim(),
      descriptionAr: useArabic || _containsArabicText(description)
          ? description.trim()
          : null,
      price: price,
      duration: '$durationMinutes min',
      isActive: isActive,
    );
    final int index = services.indexWhere(
      (ServiceItem item) => item.id == saved.id,
    );
    if (index >= 0) {
      services[index] = saved;
    } else {
      services.insert(0, saved);
    }
    return saved;
  }

  @override
  Future<void> deleteSalonService({
    required AppUser actor,
    required String serviceId,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final List<ServiceItem> services =
        _servicesBySalonId[salonId] ?? <ServiceItem>[];
    services.removeWhere((ServiceItem item) => item.id == serviceId);
  }

  @override
  Future<Product> saveSalonProduct({
    required AppUser actor,
    String? productId,
    required String name,
    required String category,
    required String description,
    required double price,
    required int stock,
    required bool isActive,
    String? imagePath,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final bool useArabic = _useArabicLanguage(actor.preferredLanguage);
    final bool isCreating = (productId ?? '').trim().isEmpty;
    final List<Product> productsForSalon = _productsBySalonId.putIfAbsent(
      salonId,
      () => <Product>[],
    );
    final Product saved = Product(
      id: (productId ?? '').trim().isEmpty
          ? 'prd-${DateTime.now().millisecondsSinceEpoch}'
          : productId!.trim(),
      salonId: salonId,
      name: name.trim(),
      nameAr: useArabic || _containsArabicText(name) ? name.trim() : null,
      imagePath: normalizeCatalogImageUrl(
        imagePath,
        fallback: currentDefaultProductImageUrl(),
      ),
      price: price,
      rating: productsForSalon
          .firstWhere(
            (Product item) => item.id == productId,
            orElse: () => Product(
              id: '',
              name: '',
              imagePath: currentDefaultProductImageUrl(),
              price: 0,
              rating: 0,
              category: '',
            ),
          )
          .rating,
      reviewsCount:
          productsForSalon
              .where((Product item) => item.id == productId)
              .map((Product item) => item.reviewsCount)
              .firstOrNull ??
          0,
      category: category.trim(),
      categoryAr: useArabic || _containsArabicText(category)
          ? category.trim()
          : null,
      description: description.trim(),
      descriptionAr: useArabic || _containsArabicText(description)
          ? description.trim()
          : null,
      stock: stock,
      isActive: isActive,
    );
    final int index = productsForSalon.indexWhere(
      (Product item) => item.id == saved.id,
    );
    if (index >= 0) {
      productsForSalon[index] = saved;
    } else {
      productsForSalon.insert(0, saved);
    }
    _recordMemoryActivity(
      actor: actor,
      actionType: isCreating
          ? 'salon_product_created'
          : 'salon_product_updated',
      targetTable: 'products',
      targetId: saved.id,
      actionSummary:
          '${actor.name} ${isCreating ? 'added' : 'updated'} salon product ${saved.name}.',
    );
    return saved;
  }

  @override
  Future<void> deleteSalonProduct({
    required AppUser actor,
    required String productId,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final List<Product> productsForSalon =
        _productsBySalonId[salonId] ?? <Product>[];
    final Product? existingProduct = productsForSalon
        .where((Product item) => item.id == productId)
        .firstOrNull;
    productsForSalon.removeWhere((Product item) => item.id == productId);
    if (existingProduct != null) {
      _recordMemoryActivity(
        actor: actor,
        actionType: 'salon_product_deleted',
        targetTable: 'products',
        targetId: existingProduct.id,
        actionSummary:
            '${actor.name} deleted salon product ${existingProduct.name}.',
      );
    }
  }

  @override
  Future<Product> saveAdminProduct({
    required AppUser actor,
    String? productId,
    required String name,
    required String category,
    required String description,
    required double price,
    required int stock,
    required bool isActive,
    String? salonId,
    String? imagePath,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can manage platform products.');
    }
    final String normalizedProductId = (productId ?? '').trim();
    final bool isCreating = normalizedProductId.isEmpty;
    final int adminProductIndex = _adminProducts.indexWhere(
      (Product item) => item.id == normalizedProductId,
    );
    final ({String salonId, int index, Product product})? salonProductMatch =
        normalizedProductId.isEmpty
        ? null
        : _findMemoryProductEntry(normalizedProductId);
    final bool matchedSalonProduct =
        salonProductMatch != null && salonProductMatch.salonId != '__admin__';
    final Product existing = adminProductIndex >= 0
        ? _adminProducts[adminProductIndex]
        : salonProductMatch?.product ??
              Product(
                id: '',
                name: '',
                imagePath: currentDefaultProductImageUrl(),
                price: 0,
                rating: 0,
                category: '',
              );
    final Product saved = Product(
      id: normalizedProductId.isEmpty
          ? 'global-prd-${DateTime.now().millisecondsSinceEpoch}'
          : normalizedProductId,
      name: name.trim(),
      imagePath: normalizeCatalogImageUrl(
        imagePath,
        fallback: currentDefaultProductImageUrl(),
      ),
      price: price,
      rating: existing.rating,
      reviewsCount: existing.reviewsCount,
      category: category.trim(),
      description: description.trim(),
      salonId: matchedSalonProduct
          ? salonProductMatch.salonId
          : _nullableString(salonId),
      stock: stock,
      isActive: isActive,
    );
    if (adminProductIndex >= 0) {
      _adminProducts[adminProductIndex] = saved;
    } else if (matchedSalonProduct) {
      final List<Product> salonProducts =
          _productsBySalonId[salonProductMatch.salonId] ?? <Product>[];
      salonProducts[salonProductMatch.index] = saved;
    } else {
      _adminProducts.insert(0, saved);
    }
    _recordMemoryActivity(
      actor: actor,
      actionType: isCreating
          ? 'admin_product_created'
          : 'admin_product_updated',
      targetTable: 'products',
      targetId: saved.id,
      actionSummary:
          '${actor.name} ${isCreating ? 'added' : 'updated'} product ${saved.name}.',
    );
    return saved;
  }

  @override
  Future<void> deleteAdminProduct({
    required AppUser actor,
    required String productId,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can delete platform products.');
    }
    final Product? existingAdminProduct = _adminProducts
        .where((Product item) => item.id == productId)
        .firstOrNull;
    _adminProducts.removeWhere((Product item) => item.id == productId);
    final ({String salonId, int index, Product product})? salonProductMatch =
        _findMemoryProductEntry(productId);
    if (salonProductMatch != null) {
      final List<Product> salonProducts =
          _productsBySalonId[salonProductMatch.salonId] ?? <Product>[];
      salonProducts.removeAt(salonProductMatch.index);
    }
    final Product? deletedProduct =
        existingAdminProduct ?? salonProductMatch?.product;
    if (deletedProduct != null) {
      _recordMemoryActivity(
        actor: actor,
        actionType: 'admin_product_deleted',
        targetTable: 'products',
        targetId: deletedProduct.id,
        actionSummary: '${actor.name} deleted product ${deletedProduct.name}.',
      );
    }
  }

  @override
  Future<PromoCouponRecord> saveSalonCoupon({
    required AppUser actor,
    required PromoCouponRecord coupon,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final PromoCouponRecord saved = coupon.copyWith(
      id: (coupon.id ?? '').trim().isEmpty
          ? 'salon-coupon-${DateTime.now().millisecondsSinceEpoch}'
          : coupon.id,
      code: coupon.normalizedCode,
      salonId: salonId,
      createdAt: coupon.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final int index = _promoCoupons.indexWhere(
      (PromoCouponRecord item) =>
          (item.id ?? '').trim().isNotEmpty && item.id == saved.id,
    );
    if (index >= 0) {
      _promoCoupons[index] = saved;
    } else {
      _promoCoupons.insert(0, saved);
    }
    return saved;
  }

  @override
  Future<void> setSalonEmployeeSalaryReceived({
    required AppUser actor,
    required String employeeId,
    required bool isReceived,
  }) async {
    final String salonId = _resolveMemorySalonIdForUser(actor);
    final List<Employee> employees =
        _employeesBySalonId[salonId] ?? <Employee>[];
    final int index = employees.indexWhere(
      (Employee item) => item.id == employeeId,
    );
    if (index < 0) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime currentMonth = DateTime(now.year, now.month, 1);
    final Employee currentEmployee = employees[index];
    employees[index] = currentEmployee.copyWith(
      salaryPaidForMonth: isReceived ? currentMonth : null,
      salaryLastPaidAt: isReceived ? now : null,
      clearSalaryPaidForMonth: !isReceived,
      clearSalaryLastPaidAt: !isReceived,
    );
    final List<EmployeeSalaryPayment> salaryPayments = _salaryPaymentsBySalonId
        .putIfAbsent(salonId, () => <EmployeeSalaryPayment>[]);
    salaryPayments.removeWhere(
      (EmployeeSalaryPayment payment) =>
          payment.employeeId == employeeId &&
          payment.salaryMonth.year == currentMonth.year &&
          payment.salaryMonth.month == currentMonth.month,
    );
    if (isReceived) {
      salaryPayments.insert(
        0,
        EmployeeSalaryPayment(
          id: 'salary-$salonId-$employeeId-${currentMonth.millisecondsSinceEpoch}',
          employeeId: employeeId,
          employeeName: currentEmployee.name,
          salonId: salonId,
          amount: currentEmployee.monthlySalary,
          salaryMonth: currentMonth,
          confirmedAt: now,
        ),
      );
    }
  }

  @override
  Future<AdminSnapshot> loadAdminSnapshot() async {
    final List<ManagedUserRecord> users = _usersByEmail.values
        .map(
          (AppUser user) => ManagedUserRecord(
            id: user.profileId ?? user.email,
            name: user.name,
            email: user.email,
            phone: user.phone,
            city: user.city,
            avatarUrl: user.avatarPath,
            role: user.role,
            isActive: _isActiveByUserId[user.profileId ?? ''] ?? true,
            bookingsCount: 0,
            productOrdersCount: 0,
            totalSpent: 0,
            loyaltyPoints: 0,
          ),
        )
        .toList(growable: false);
    final Map<String, ManagedUserRecord> usersById = users
        .fold<Map<String, ManagedUserRecord>>(<String, ManagedUserRecord>{}, (
          Map<String, ManagedUserRecord> map,
          ManagedUserRecord user,
        ) {
          map[user.id] = user;
          return map;
        });
    final List<AdminTeamMember> admins =
        _usersByEmail.values
            .where((AppUser user) => user.role == AppRole.admin)
            .map(_memoryAdminFromUser)
            .toList(growable: false)
          ..sort((AdminTeamMember a, AdminTeamMember b) {
            if (a.isOwner != b.isOwner) {
              return a.isOwner ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    final List<AdminCustomerSubscriptionRecord> customerSubscriptions =
        _customerSubscriptionsByUserId.entries
            .map((MapEntry<String, CustomerSubscriptionStatus> entry) {
              final ManagedUserRecord? user = usersById[entry.key];
              if (user == null) {
                return null;
              }
              return AdminCustomerSubscriptionRecord(
                user: user,
                subscription: entry.value,
              );
            })
            .whereType<AdminCustomerSubscriptionRecord>()
            .toList(growable: false)
          ..sort((
            AdminCustomerSubscriptionRecord a,
            AdminCustomerSubscriptionRecord b,
          ) {
            return a.user.name.toLowerCase().compareTo(
              b.user.name.toLowerCase(),
            );
          });
    final List<AdminSalonRecord> adminSalons =
        salons
            .map(
              (Salon salon) => AdminSalonRecord(
                salon: salon,
                ownerName: 'Salon Owner',
                ownerEmail: 'owner@freshline.app',
                ownerPhone: salon.phone,
                isActive: true,
                subscriptionStatus: _salonSubscriptionsBySalonId[salon.id],
              ),
            )
            .toList(growable: false)
          ..sort((AdminSalonRecord a, AdminSalonRecord b) {
            return a.salon.name.toLowerCase().compareTo(
              b.salon.name.toLowerCase(),
            );
          });
    final List<Product> adminProducts =
        <Product>[
          ..._adminProducts,
          ..._productsBySalonId.values.expand((List<Product> items) => items),
        ]..sort((Product a, Product b) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    const double bookingRevenue = 0;
    const double productRevenue = 0;
    final double customerSubscriptionRevenue = _customerSubscriptionsByUserId
        .values
        .fold<double>(
          0,
          (double sum, CustomerSubscriptionStatus subscription) =>
              sum + subscription.plan.price.toDouble(),
        );
    final double salonSubscriptionRevenue = _salonSubscriptionsBySalonId.values
        .fold<double>(
          0,
          (double sum, SalonSubscriptionStatus subscription) =>
              sum + subscription.amount,
        );

    return AdminSnapshot(
      metrics: AdminDashboardMetrics(
        customerSubscriptionRevenue: customerSubscriptionRevenue,
        salonSubscriptionRevenue: salonSubscriptionRevenue,
        bookingRevenue: bookingRevenue,
        productRevenue: productRevenue,
        totalRevenue:
            customerSubscriptionRevenue +
            salonSubscriptionRevenue +
            bookingRevenue +
            productRevenue,
        customerCount: users
            .where((ManagedUserRecord user) => user.role == AppRole.customer)
            .length,
        salonCount: salons.length,
        requestCount: 0,
        customerSubscriptionCount: customerSubscriptions.length,
        salonSubscriptionCount: adminSalons
            .where((AdminSalonRecord salon) => salon.subscriptionStatus != null)
            .length,
        productCount: adminProducts.length,
        productOrderCount: _ordersByUserId.values
            .expand((List<UserOrder> items) => items)
            .where((UserOrder order) => order.isProductOrder)
            .length,
      ),
      users: users,
      salons: List<Salon>.from(salons),
      adminSalons: adminSalons,
      requests: const <AdminSalonRequestRecord>[],
      coupons: _promoCoupons
          .where((PromoCouponRecord coupon) => !coupon.isSalonCoupon)
          .map((PromoCouponRecord coupon) => coupon.copyWith())
          .toList(growable: false),
      admins: admins,
      customerSubscriptions: customerSubscriptions,
      adminProducts: adminProducts,
      activityLogs: List<AdminActivityLogRecord>.from(_activityLogs)
        ..sort(
          (AdminActivityLogRecord a, AdminActivityLogRecord b) =>
              b.createdAt.compareTo(a.createdAt),
        ),
    );
  }

  @override
  Future<void> sendAdminNotification({
    required AppUser actor,
    required String title,
    required String body,
    required String audience,
    String? targetProfileId,
    String? targetSalonId,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can send notifications.');
    }

    final String normalizedTitle = title.trim();
    final String normalizedBody = body.trim();
    final String normalizedAudience = audience.trim();
    final String resolvedTargetProfileId = _readString(targetProfileId);
    final String resolvedTargetSalonId = _readString(targetSalonId);

    if (normalizedTitle.isEmpty) {
      throw StateError('Enter a notification title.');
    }
    if (normalizedBody.isEmpty) {
      throw StateError('Enter a notification message.');
    }
    if (normalizedAudience == 'single_user' &&
        resolvedTargetProfileId.isEmpty) {
      throw StateError('Choose the user who should receive it.');
    }
    if (normalizedAudience == 'single_salon' && resolvedTargetSalonId.isEmpty) {
      throw StateError('Choose the salon that should receive it.');
    }

    final String actorId = actor.profileId ?? actor.email.toLowerCase();
    _adminLastActionByUserId[actorId] = 'Sent $normalizedAudience notification';
    _recordMemoryActivity(
      actor: actor,
      actionType: 'admin_notification_sent',
      targetTable: 'notifications',
      targetId: resolvedTargetProfileId.isNotEmpty
          ? resolvedTargetProfileId
          : resolvedTargetSalonId,
      actionSummary:
          '${actor.name} sent a ${normalizedAudience.replaceAll('_', ' ')} notification.',
    );
  }

  @override
  Future<void> syncDevicePushToken({
    required AppUser user,
    required String token,
  }) async {
    final String profileId = user.profileId?.trim() ?? '';
    final String normalizedToken = token.trim();
    if (profileId.isEmpty || normalizedToken.isEmpty) {
      return;
    }

    _pushTokensByUserId
        .putIfAbsent(profileId, () => <String>{})
        .add(normalizedToken);
  }

  @override
  Future<void> removeDevicePushToken({
    required AppUser user,
    required String token,
  }) async {
    final String profileId = user.profileId?.trim() ?? '';
    final String normalizedToken = token.trim();
    if (profileId.isEmpty || normalizedToken.isEmpty) {
      return;
    }

    final Set<String>? tokens = _pushTokensByUserId[profileId];
    tokens?.remove(normalizedToken);
    if (tokens != null && tokens.isEmpty) {
      _pushTokensByUserId.remove(profileId);
    }
  }

  @override
  Future<AdminTeamMember> saveAdminAccount({
    required AppUser actor,
    String? adminId,
    required String name,
    required String email,
    required String phone,
    required String city,
    String? password,
    String? avatarPath,
  }) async {
    if (actor.role != AppRole.admin || !actor.isAdminOwner) {
      throw StateError('Only the admin owner can manage admin accounts.');
    }

    final String normalizedAdminId = _readString(adminId);
    final bool isCreating = normalizedAdminId.isEmpty;

    final String normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty ||
        (!normalizedEmail.contains('@') &&
            normalizedEmail != adminOwnerEmail)) {
      throw StateError('Enter a valid admin email.');
    }
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(
      phone,
      fieldLabel: 'Admin phone number',
    );
    final String normalizedCity = normalizeBahrainLocation(city);
    final String resolvedAvatarPath = _readString(
      avatarPath,
      fallback: currentDefaultProfileImageUrl(),
    );

    if (isCreating) {
      if (_usersByEmail.containsKey(normalizedEmail)) {
        throw StateError('This email is already used by another account.');
      }
      final String resolvedPassword = password?.trim() ?? '';
      if (resolvedPassword.isEmpty) {
        throw StateError('Enter a password for the new admin.');
      }
      final String userId = 'admin-${DateTime.now().millisecondsSinceEpoch}';
      final AppUser adminUser = AppUser(
        profileId: userId,
        name: name.trim(),
        email: normalizedEmail,
        phone: normalizedPhone,
        city: normalizedCity,
        role: AppRole.admin,
        avatarPath: resolvedAvatarPath,
      );
      _usersByEmail[normalizedEmail] = adminUser;
      _passwordsByUserId[userId] = hashProfilePassword(resolvedPassword);
      _isActiveByUserId[userId] = true;
      _adminLastActionByUserId[userId] = 'Admin account created';
      _recordMemoryActivity(
        actor: actor,
        actionType: 'admin_created',
        targetTable: 'profiles',
        targetId: userId,
        actionSummary: '${actor.name} created admin ${adminUser.name}.',
      );
      return _memoryAdminFromUser(adminUser);
    }

    final AppUser existingUser = _usersByEmail.values.firstWhere(
      (AppUser user) =>
          user.profileId == normalizedAdminId && user.role == AppRole.admin,
      orElse: () => throw StateError('Freshline could not find this admin.'),
    );
    if (existingUser.isAdminOwner && normalizedEmail != adminOwnerEmail) {
      throw StateError('The admin owner email must stay as admin.com.');
    }
    if (existingUser.email.toLowerCase() != normalizedEmail &&
        _usersByEmail.containsKey(normalizedEmail)) {
      throw StateError('This email is already used by another account.');
    }

    _usersByEmail.remove(existingUser.email.toLowerCase());
    final AppUser updatedUser = existingUser.copyWith(
      name: name.trim(),
      email: normalizedEmail,
      phone: normalizedPhone,
      city: normalizedCity,
      avatarPath: resolvedAvatarPath,
    );
    _usersByEmail[normalizedEmail] = updatedUser;
    final String resolvedPassword = password?.trim() ?? '';
    if (resolvedPassword.isNotEmpty) {
      _passwordsByUserId[normalizedAdminId] = hashProfilePassword(
        resolvedPassword,
      );
    }
    _adminLastActionByUserId[normalizedAdminId] = 'Admin account updated';
    _recordMemoryActivity(
      actor: actor,
      actionType: 'admin_updated',
      targetTable: 'profiles',
      targetId: normalizedAdminId,
      actionSummary: '${actor.name} updated admin ${updatedUser.name}.',
    );
    return _memoryAdminFromUser(updatedUser);
  }

  @override
  Future<void> setAdminAccountActive({
    required AppUser actor,
    required String adminId,
    required bool isActive,
  }) async {
    if (actor.role != AppRole.admin || !actor.isAdminOwner) {
      throw StateError('Only the admin owner can manage admin accounts.');
    }
    final AppUser adminUser = _usersByEmail.values.firstWhere(
      (AppUser user) => user.profileId == adminId && user.role == AppRole.admin,
      orElse: () => throw StateError('Freshline could not find this admin.'),
    );
    if (adminUser.isAdminOwner && !isActive) {
      throw StateError('The admin owner cannot be disabled.');
    }
    _isActiveByUserId[adminId] = isActive;
    _adminLastActionByUserId[adminId] = isActive
        ? 'Admin account enabled'
        : 'Admin account disabled';
    _recordMemoryActivity(
      actor: actor,
      actionType: isActive ? 'admin_enabled' : 'admin_disabled',
      targetTable: 'profiles',
      targetId: adminId,
      actionSummary:
          '${actor.name} ${isActive ? 'enabled' : 'disabled'} admin ${adminUser.name}.',
    );
  }

  @override
  Future<PromoCouponRecord> savePromoCoupon({
    required PromoCouponRecord coupon,
  }) async {
    final PromoCouponRecord normalized = coupon.copyWith(
      code: coupon.normalizedCode,
      salonId: null,
    );
    final int index = _promoCoupons.indexWhere(
      (PromoCouponRecord item) =>
          item.id == normalized.id ||
          item.normalizedCode == normalized.normalizedCode,
    );
    if (index >= 0) {
      _promoCoupons[index] = normalized.copyWith(
        id: _promoCoupons[index].id,
        createdAt: _promoCoupons[index].createdAt,
        updatedAt: DateTime.now(),
      );
      return _promoCoupons[index];
    }

    final PromoCouponRecord created = normalized.copyWith(
      id: 'coupon-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _promoCoupons.insert(0, created);
    return created;
  }

  @override
  Future<void> updateManagedUser({
    required AppUser actor,
    required ManagedUserRecord user,
    required String name,
    required String email,
    required String phone,
    required String city,
    required AppRole role,
  }) async {
    final String trimmedName = name.trim();
    final String normalizedEmail = email.trim().toLowerCase();
    if (user.role == AppRole.admin && !actor.isAdminOwner) {
      throw StateError('Only the admin owner can manage admin accounts.');
    }
    final bool isPromotingToAdmin =
        user.role != AppRole.admin && role == AppRole.admin;
    if (isPromotingToAdmin && !actor.isAdminOwner) {
      throw StateError('Only the admin owner can add a new admin.');
    }
    final AppUser existing = _usersByEmail[user.email.toLowerCase()]!;
    if (existing.isAdminOwner && role != AppRole.admin) {
      throw StateError('The admin owner role cannot be changed.');
    }
    if (existing.isAdminOwner &&
        email.trim().toLowerCase() != adminOwnerEmail) {
      throw StateError('The admin owner email must stay as admin.com.');
    }
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(phone);
    final String normalizedCity = normalizeBahrainLocation(city);
    _usersByEmail.remove(user.email.toLowerCase());
    _usersByEmail[normalizedEmail] = existing.copyWith(
      name: trimmedName,
      email: normalizedEmail,
      phone: normalizedPhone,
      city: normalizedCity,
      role: role,
    );
    _recordMemoryActivity(
      actor: actor,
      actionType: 'user_updated',
      targetTable: 'profiles',
      targetId: user.id,
      actionSummary:
          '${actor.name} updated ${role.label.toLowerCase()} $trimmedName.',
    );
  }

  @override
  Future<void> setUserActive({
    required AppUser actor,
    required String userId,
    required bool isActive,
  }) async {
    final AppUser? existingUser = _usersByEmail.values
        .where((AppUser user) => user.profileId == userId)
        .firstOrNull;
    if (existingUser?.isAdminOwner == true && !isActive) {
      throw StateError('The admin owner cannot be disabled.');
    }
    _isActiveByUserId[userId] = isActive;
    if (existingUser != null) {
      _recordMemoryActivity(
        actor: actor,
        actionType: isActive ? 'user_enabled' : 'user_disabled',
        targetTable: 'profiles',
        targetId: existingUser.profileId,
        actionSummary:
            '${actor.name} ${isActive ? 'enabled' : 'disabled'} ${existingUser.role.label.toLowerCase()} ${existingUser.name}.',
      );
    }
  }

  @override
  Future<void> reviewSalonRequest({
    required AdminSalonRequestRecord record,
    required SalonRequestStatus status,
    required String adminNote,
    required AppUser admin,
  }) async {
    _recordMemoryActivity(
      actor: admin,
      actionType: 'salon_request_${status.value}',
      targetTable: 'salon_applications',
      targetId: record.request.id,
      actionSummary:
          '${admin.name} marked salon request ${record.request.salonName} as ${status.label.toLowerCase()}.',
    );
  }

  void _recordMemoryActivity({
    required AppUser actor,
    required String actionType,
    required String actionSummary,
    String? targetTable,
    String? targetId,
    DateTime? createdAt,
  }) {
    final String actorId = actor.profileId ?? actor.email.toLowerCase();
    _activityLogs.insert(
      0,
      AdminActivityLogRecord(
        id: 'activity-${DateTime.now().microsecondsSinceEpoch}',
        actorId: actorId,
        actorName: actor.name,
        actorEmail: actor.email,
        actorRole: actor.role,
        actionType: actionType,
        summary: actionSummary,
        createdAt: createdAt ?? DateTime.now(),
        targetTable: _nullableString(targetTable),
        targetId: _nullableString(targetId),
      ),
    );
    if (_activityLogs.length > 200) {
      _activityLogs.removeRange(200, _activityLogs.length);
    }
    _adminLastActionByUserId[actorId] = actionSummary;
  }

  AdminTeamMember _memoryAdminFromUser(AppUser user) {
    final String userId = user.profileId ?? user.email.toLowerCase();
    return AdminTeamMember(
      id: userId,
      name: user.name,
      email: user.email,
      phone: user.phone,
      city: user.city,
      avatarPath: user.avatarPath,
      roleTitle: user.isAdminOwner ? 'Admin Owner' : 'Platform Admin',
      storagePath: 'admins/${_safeKey(userId)}/profile.jpg',
      lastAction:
          _adminLastActionByUserId[userId] ??
          (user.isAdminOwner
              ? 'Admin owner access ready'
              : 'Admin account is ready'),
      isActive: _isActiveByUserId[userId] ?? true,
      isOwner: user.isAdminOwner,
    );
  }

  Future<void> _rememberAddress({
    required AppUser user,
    required String addressDetails,
    required DeliveryLocationSelection location,
  }) async {
    final String userId = user.profileId ?? '';
    final List<SavedCustomerAddress> addresses = _addressesByUserId.putIfAbsent(
      userId,
      () => <SavedCustomerAddress>[],
    );
    final SavedCustomerAddress? existing = addresses
        .where(
          (SavedCustomerAddress item) =>
              item.addressLine.trim().toLowerCase() ==
                  addressDetails.trim().toLowerCase() &&
              _sameLocation(item.location, location),
        )
        .firstOrNull;
    final SavedCustomerAddress saved =
        existing ??
        SavedCustomerAddress(
          id: 'address-${DateTime.now().millisecondsSinceEpoch}',
          label: addresses.isEmpty
              ? 'Home'
              : 'Saved Address ${addresses.length + 1}',
          addressLine: addressDetails.trim(),
          location: location,
          isDefault: true,
        );
    final List<SavedCustomerAddress> clearedDefaults = addresses
        .where((SavedCustomerAddress item) => item.id != saved.id)
        .map(
          (SavedCustomerAddress item) => SavedCustomerAddress(
            id: item.id,
            label: item.label,
            addressLine: item.addressLine,
            location: item.location,
            isDefault: false,
          ),
        )
        .toList(growable: false);
    addresses
      ..clear()
      ..addAll(clearedDefaults);
    addresses.insert(
      0,
      SavedCustomerAddress(
        id: saved.id,
        label: saved.label,
        addressLine: saved.addressLine,
        location: saved.location,
        isDefault: true,
      ),
    );
    final AppUser? storedUser = _usersByEmail[user.email];
    if (storedUser != null) {
      _usersByEmail[user.email] = storedUser.copyWith(
        address: addressDetails.trim(),
      );
    }
  }

  Future<void> _reserveMemoryProductStock(
    List<ProductOrderLineItem> items,
  ) async {
    final Map<String, int> quantitiesByProductId =
        _productOrderQuantitiesByProductId(items);
    final Map<String, ({String salonId, int index, Product product})>
    matchedProducts =
        <String, ({String salonId, int index, Product product})>{};

    for (final MapEntry<String, int> entry in quantitiesByProductId.entries) {
      final ({String salonId, int index, Product product})? match =
          _findMemoryProductEntry(entry.key);
      if (match == null) {
        throw StateError('One of the selected products could not be found.');
      }
      if (!match.product.isActive) {
        throw StateError('${match.product.name} is not available right now.');
      }
      if (match.product.stock < entry.value) {
        throw StateError(
          '${match.product.name} only has ${match.product.stock} item${match.product.stock == 1 ? '' : 's'} left.',
        );
      }
      matchedProducts[entry.key] = match;
    }

    for (final MapEntry<String, int> entry in quantitiesByProductId.entries) {
      final ({String salonId, int index, Product product}) match =
          matchedProducts[entry.key]!;
      if (match.salonId == '__admin__') {
        final Product current = _adminProducts[match.index];
        _adminProducts[match.index] = current.copyWith(
          stock: math.max(0, current.stock - entry.value),
        );
      } else {
        final List<Product> products = _productsBySalonId[match.salonId]!;
        final Product current = products[match.index];
        products[match.index] = current.copyWith(
          stock: math.max(0, current.stock - entry.value),
        );
      }
    }
  }

  ({String salonId, int index, Product product})? _findMemoryProductEntry(
    String productId,
  ) {
    final String normalizedId = productId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }
    for (final MapEntry<String, List<Product>> entry
        in _productsBySalonId.entries) {
      final int index = entry.value.indexWhere(
        (Product product) => product.id == normalizedId,
      );
      if (index >= 0) {
        return (salonId: entry.key, index: index, product: entry.value[index]);
      }
    }
    final int adminIndex = _adminProducts.indexWhere(
      (Product product) => product.id == normalizedId,
    );
    if (adminIndex >= 0) {
      return (
        salonId: '__admin__',
        index: adminIndex,
        product: _adminProducts[adminIndex],
      );
    }
    return null;
  }

  Employee _hydrateMemoryEmployee(Employee employee) {
    final String? profileId = employee.profileId;
    if ((profileId ?? '').isEmpty) {
      return employee;
    }
    final AppUser? profile = _usersByEmail.values
        .where((AppUser user) => user.profileId == profileId)
        .firstOrNull;
    if (profile == null) {
      return employee;
    }
    return employee.copyWith(
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      imagePath: profile.avatarPath,
      isActive: _isActiveByUserId[profileId!] ?? employee.isActive,
      availabilityLabel: (_isActiveByUserId[profileId] ?? employee.isActive)
          ? employee.availabilityLabel
          : 'Account paused',
    );
  }

  void _updateMemoryOrder({
    required String userId,
    required String orderId,
    required UserOrder Function(UserOrder current) mutate,
  }) {
    final List<UserOrder> orders = _ordersByUserId[userId] ?? <UserOrder>[];
    final int index = orders.indexWhere(
      (UserOrder order) => order.id == orderId,
    );
    if (index < 0) {
      return;
    }
    orders[index] = mutate(orders[index]);
  }

  void _updateMemoryOrderEverywhere({
    required String orderId,
    required UserOrder Function(UserOrder current) mutate,
  }) {
    for (final List<UserOrder> orders in _ordersByUserId.values) {
      final int index = orders.indexWhere(
        (UserOrder order) => order.id == orderId,
      );
      if (index < 0) {
        continue;
      }
      orders[index] = mutate(orders[index]);
      return;
    }
  }

  bool _memoryProductOrderMatchesSalon({
    required UserOrder order,
    required String salonId,
    required Set<String> salonProductIds,
  }) {
    if ((order.salonId ?? '').trim() == salonId) {
      return true;
    }
    return order.productItems.any(
      (RatedOrderProductItem item) => salonProductIds.contains(item.productId),
    );
  }

  void _recalculateMemoryEmployeeRatings(String? employeeId) {
    final String normalized = (employeeId ?? '').trim();
    if (normalized.isEmpty) {
      return;
    }
    final List<_MemorySalonReviewRecord> employeeReviews =
        _salonReviewsByBookingId.values
            .where((item) => item.employeeId == normalized)
            .toList(growable: false);
    final double rating = employeeReviews.isEmpty
        ? 0
        : employeeReviews.fold<double>(
                0,
                (double sum, _MemorySalonReviewRecord item) =>
                    sum + item.employeeRating,
              ) /
              employeeReviews.length;
    for (final List<Employee> employees in _employeesBySalonId.values) {
      final int index = employees.indexWhere(
        (Employee employee) => employee.id == normalized,
      );
      if (index >= 0) {
        employees[index] = employees[index].copyWith(
          rating: rating,
          reviewsCount: employeeReviews.length,
        );
        return;
      }
    }
  }

  String _resolveMemorySalonIdForUser(AppUser user) {
    if (user.role == AppRole.employee) {
      final String? employeeId = _employeeIdByProfileId[user.profileId ?? ''];
      if (employeeId != null) {
        for (final MapEntry<String, List<Employee>> entry
            in _employeesBySalonId.entries) {
          final bool matches = entry.value.any(
            (Employee employee) => employee.id == employeeId,
          );
          if (matches) {
            return entry.key;
          }
        }
      }
    }
    if (salons.any((Salon salon) => salon.id == '1')) {
      return '1';
    }
    return salons.first.id;
  }

  @override
  void dispose() {}
}

class _MemorySalonReviewRecord {
  const _MemorySalonReviewRecord({
    required this.bookingId,
    required this.salonId,
    required this.employeeId,
    required this.salonRating,
    required this.employeeRating,
    required this.comment,
  });

  final String bookingId;
  final String salonId;
  final String employeeId;
  final int salonRating;
  final int employeeRating;
  final String comment;
}

class _MemoryProductReviewRecord {
  const _MemoryProductReviewRecord({
    required this.orderId,
    required this.productId,
    required this.rating,
    required this.comment,
  });

  final String orderId;
  final String productId;
  final int rating;
  final String comment;
}

class _ResolvedSalonWorkspace {
  const _ResolvedSalonWorkspace({
    required this.salon,
    this.currentEmployee,
    this.subscriptionStatus,
  });

  final Salon salon;
  final Employee? currentEmployee;
  final SalonSubscriptionStatus? subscriptionStatus;
}

class _SalonProductOrdersLoadResult {
  const _SalonProductOrdersLoadResult({
    required this.orders,
    required this.productRevenue,
  });

  final List<UserOrder> orders;
  final double productRevenue;
}

class SupabasePlatformRepository implements PlatformRepository {
  SupabasePlatformRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, String> _passwordResetTokensByEmail = <String, String>{};
  final Map<String, String> _localFallbackOtpCodesByKey = <String, String>{};

  Future<void> _signInSupabaseAuthUser({
    required String email,
    required String password,
    required String fallback,
  }) async {
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.post(
        Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
        headers: <String, String>{
          ..._supabaseHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'email': email.trim().toLowerCase(),
          'password': password.trim(),
        }),
      ),
      fallback: fallback,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw StateError(_readAuthError(response, fallback: fallback));
  }

  String _generateOtpCode() {
    final int value = math.Random.secure().nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }

  Map<String, String> _splitSalonReviewComment(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) {
      return const <String, String>{};
    }
    try {
      final dynamic decoded = jsonDecode(text);
      if (decoded is Map) {
        final String salon = _readString(decoded['salon'] ?? decoded['salonComment']);
        final String employee =
            _readString(decoded['employee'] ?? decoded['employeeComment']);
        return <String, String>{
          if (salon.trim().isNotEmpty) 'salon': salon.trim(),
          if (employee.trim().isNotEmpty) 'employee': employee.trim(),
        };
      }
    } catch (_) {
      // Not JSON encoded.
    }
    return <String, String>{'salon': text};
  }

  Future<AuthOtpDispatchResult> _sendManagedEmailOtp({
    required String email,
    required String purpose,
    required String profileId,
    required String fallback,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final String normalizedProfileId = profileId.trim();
    if (normalizedEmail.isEmpty || normalizedProfileId.isEmpty) {
      throw StateError(fallback);
    }
    final bool allowLocalFallback = _allowsLocalOtpFallbackForPurpose(purpose);

    http.Response response;
    try {
      response = await performFreshlineHttpRequest(
        () => _client.post(
          Uri.parse('$supabaseUrl/functions/v1/send-auth-otp'),
          headers: <String, String>{
            ..._supabaseHeaders(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'email': normalizedEmail,
            'purpose': purpose.trim(),
            'profileId': normalizedProfileId,
          }),
        ),
        fallback: fallback,
      );
    } catch (error) {
      if (allowLocalFallback) {
        final String code = _generateOtpCode();
        _localFallbackOtpCodesByKey[_authEmailOtpKey(
              email: normalizedEmail,
              purpose: purpose,
              profileId: normalizedProfileId,
            )] =
            code;
        return AuthOtpDispatchResult(previewCode: code, usedLocalFallback: true);
      }
      rethrow;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final String body = response.body.trim();
      if (body.isEmpty) {
        return const AuthOtpDispatchResult();
      }
      try {
        final dynamic decoded = jsonDecode(body);
        if (decoded is Map) {
          final String previewCode =
              _readString(decoded['previewCode'] ?? decoded['preview_code']);
          if (previewCode.trim().isNotEmpty) {
            return AuthOtpDispatchResult(
              previewCode: previewCode.trim(),
              usedLocalFallback: true,
            );
          }
        }
      } catch (_) {
        // ignore and treat as a normal success
      }
      return const AuthOtpDispatchResult();
    }

    final String message = _readAuthError(response, fallback: fallback);
    if (response.statusCode == 429 || _isOtpRateLimitError(message)) {
      throw StateError(_otpRateLimitMessage());
    }
    if (_isMissingOtpEdgeFunctionError(message) && allowLocalFallback) {
      final String code = _generateOtpCode();
      _localFallbackOtpCodesByKey[_authEmailOtpKey(
            email: normalizedEmail,
            purpose: purpose,
            profileId: normalizedProfileId,
          )] =
          code;
      return AuthOtpDispatchResult(previewCode: code, usedLocalFallback: true);
    }
    if (_shouldUseLocalOtpFallback(message, allowLocalFallback: allowLocalFallback)) {
      final String code = _generateOtpCode();
      _localFallbackOtpCodesByKey[_authEmailOtpKey(
            email: normalizedEmail,
            purpose: purpose,
            profileId: normalizedProfileId,
          )] =
          code;
      return AuthOtpDispatchResult(previewCode: code, usedLocalFallback: true);
    }
    throw StateError(message);
  }

  String _authEmailOtpKey({
    required String email,
    required String purpose,
    String? profileId,
  }) {
    final String normalizedProfileId = (profileId ?? '').trim();
    return '${email.trim().toLowerCase()}|$purpose|$normalizedProfileId';
  }

  @override
  Future<String?> pickAndUploadProfileImage({
    required String profileKey,
  }) async {
    return _pickAndUploadImageAsset(
      dialogTitle: 'Select profile image',
      folder: 'profiles/${_safeKey(profileKey)}',
      fallbackError: 'Freshline could not upload the profile image.',
    );
  }

  @override
  Future<String?> pickAndUploadSalonProductImage({
    required String productKey,
  }) async {
    return _pickAndUploadImageAsset(
      dialogTitle: 'Select product image',
      folder: 'products/${_safeKey(productKey)}',
      fallbackError: 'Freshline could not upload the product image.',
    );
  }

  @override
  Future<String?> pickAndUploadPlatformDefaultImage({
    required PlatformMediaType mediaType,
  }) {
    return _pickAndUploadImageAsset(
      dialogTitle: 'Select ${mediaType.value} default image',
      folder: 'defaults/${mediaType.value}',
      fallbackError:
          'Freshline could not upload the ${mediaType.value} default image.',
    );
  }

  @override
  Future<PlatformMediaDefaults> loadPlatformMediaDefaults() async {
    final List<Map<String, dynamic>> rows = _toRowMaps(
      await _getRows(
        '/rest/v1/platform_media_defaults?select=media_type,default_url,updated_at',
      ),
    );
    final PlatformMediaDefaults defaults =
        PlatformMediaDefaults.fromSupabaseRows(rows);
    applyPlatformMediaDefaults(defaults);
    return defaults;
  }

  @override
  Future<PlatformMediaDefaults> savePlatformMediaDefaults({
    required AppUser actor,
    required PlatformMediaDefaults defaults,
  }) async {
    if (actor.role != AppRole.admin || !actor.isAdminOwner) {
      throw StateError('Only the admin owner can update default images.');
    }

    final List<dynamic> rows = await _postRows(
      '/rest/v1/platform_media_defaults?on_conflict=media_type',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'media_type': PlatformMediaType.profile.value,
          'default_url': defaults.profileImageUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        <String, dynamic>{
          'media_type': PlatformMediaType.salon.value,
          'default_url': defaults.salonImageUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        <String, dynamic>{
          'media_type': PlatformMediaType.product.value,
          'default_url': defaults.productImageUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
      prefer: 'resolution=merge-duplicates,return=representation',
      fallback: 'Freshline could not save the default images.',
    );
    final PlatformMediaDefaults saved = PlatformMediaDefaults.fromSupabaseRows(
      _toRowMaps(rows),
    );
    applyPlatformMediaDefaults(saved);
    return saved;
  }

  @override
  Future<SignInAttempt> beginSignIn({
    required AppRole role,
    required String email,
    required String password,
  }) async {
    final Map<String, dynamic>? profile = await _fetchProfileByEmail(email);
    if (profile == null) {
      throw StateError('Account was not found.');
    }

    final AppRole storedRole = appRoleFromValue(
      _readString(profile['role'], fallback: AppRole.customer.value),
    );
    if (storedRole != role) {
      throw StateError('This account belongs to a different role.');
    }

    final String authUserId = _readString(profile['auth_user_id']);
    if (authUserId.isNotEmpty) {
      await _signInSupabaseAuthUser(
        email: email,
        password: password,
        fallback: 'Email or password is incorrect.',
      );
    } else {
      final String storedPassword = _readString(profile['password_hash']);
      final bool adminPlaceholder =
          storedRole == AppRole.admin &&
          storedPassword == 'replace-this-with-a-real-hash';
      if (!verifyProfilePassword(
            storedPasswordHash: storedPassword,
            password: password,
          ) &&
          !adminPlaceholder) {
        throw StateError('Email or password is incorrect.');
      }
    }

    if (!_readBool(profile['is_active'], fallback: true)) {
      throw StateError('This account is disabled.');
    }

    if (storedRole == AppRole.employee) {
      final List<Map<String, dynamic>> employeeRows = _toRowMaps(
        await _getRows(
          '/rest/v1/salon_employees?select=id,can_login,is_active&profile_id=eq.${_readString(profile['id'])}&limit=1',
        ),
      );
      if (employeeRows.isEmpty) {
        throw StateError('Employee account details were not found.');
      }
      if (!_readBool(employeeRows.first['can_login'], fallback: false)) {
        throw StateError('This employee account cannot sign in yet.');
      }
      if (!_readBool(employeeRows.first['is_active'], fallback: true)) {
        throw StateError('This employee account is paused.');
      }
    }

    final AppUser user = _userFromProfile(profile);
    await _touchLastLogin(user.profileId);
    return SignInAttempt.authenticated(user: user);
  }

  @override
  Future<AppUser> completeTwoFactorSignIn({
    required String email,
    required String profileId,
    required String code,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final Map<String, dynamic>? profile = await _fetchProfileByEmail(
      normalizedEmail,
    );
    if (profile == null) {
      throw StateError('Account was not found.');
    }
    if (_readString(profile['id']) != profileId.trim()) {
      throw StateError('Freshline could not match the verification challenge.');
    }
    if (!_readBool(profile['is_active'], fallback: true)) {
      throw StateError('This account is disabled.');
    }

    final AppRole storedRole = appRoleFromValue(
      _readString(profile['role'], fallback: AppRole.customer.value),
    );
    if (storedRole == AppRole.employee) {
      final List<Map<String, dynamic>> employeeRows = _toRowMaps(
        await _getRows(
          '/rest/v1/salon_employees?select=id,can_login,is_active&profile_id=eq.${_readString(profile['id'])}&limit=1',
        ),
      );
      if (employeeRows.isEmpty) {
        throw StateError('Employee account details were not found.');
      }
      if (!_readBool(employeeRows.first['can_login'], fallback: false)) {
        throw StateError('This employee account cannot sign in yet.');
      }
      if (!_readBool(employeeRows.first['is_active'], fallback: true)) {
        throw StateError('This employee account is paused.');
      }
    }

    await _verifyManagedEmailOtp(
      email: normalizedEmail,
      purpose: _twoFactorSignInOtpPurpose,
      code: code,
      profileId: profileId,
      fallback: 'The verification code is invalid or has expired.',
    );

    final AppUser user = _userFromProfile(profile);
    await _touchLastLogin(user.profileId);
    return user;
  }

  @override
  Future<void> verifyEmailAddressCode({
    required String email,
    required String code,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final Map<String, dynamic>? profile = await _fetchProfileByEmail(
      normalizedEmail,
    );
    if (profile == null) {
      throw StateError('The verification code is invalid or has expired.');
    }

    await _verifyManagedEmailOtp(
      email: normalizedEmail,
      purpose: _emailVerificationOtpPurpose,
      code: code,
      profileId: _readString(profile['id']),
      fallback: 'The verification code is invalid or has expired.',
    );
    await _markProfileEmailVerified(email: normalizedEmail);
  }

  @override
  Future<AuthOtpDispatchResult> sendEmailVerificationCode({
    required String email,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final Map<String, dynamic>? profile = await _fetchProfileByEmail(
      normalizedEmail,
    );
    if (profile == null) {
      throw StateError('Account was not found.');
    }
    if (!_profileRequiresEmailVerification(profile)) {
      return const AuthOtpDispatchResult();
    }
    return _sendManagedEmailOtp(
      email: normalizedEmail,
      purpose: _emailVerificationOtpPurpose,
      profileId: _readString(profile['id']),
      fallback: 'Freshline could not send the verification code right now.',
    );
  }

  @override
  Future<AppUser> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String password,
    String? avatarPath,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(phone);
    final String normalizedCity = normalizeBahrainLocation(city);
    final String? normalizedAvatar = canonicalProfileImageForWrite(avatarPath);
    final Map<String, dynamic>? existing = await _fetchProfileByEmail(
      normalizedEmail,
    );
    if (existing != null && !_canReusePendingCustomerProfile(existing)) {
      throw StateError('This email is already used by another account.');
    }

    final List<dynamic> rows = await _postRows(
      '/rest/v1/profiles?on_conflict=email',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'role': AppRole.customer.value,
          'full_name': name.trim(),
          'username': _safeKey(name),
          'email': normalizedEmail,
          'password_hash': hashProfilePassword(password.trim()),
          'phone': normalizedPhone,
          'city': normalizedCity,
          'avatar_url': normalizedAvatar,
          'is_active': true,
          'is_super_admin': false,
          // Keep customer sign-ups out of Supabase Auth so the app can create
          // accounts immediately without triggering email/OTP delivery. Email
          // verification is handled later from the profile settings flow.
          'auth_user_id': null,
        },
      ],
      prefer: 'resolution=merge-duplicates,return=representation',
      fallback: 'Freshline could not create the account.',
    );

    if (rows.isEmpty) {
      final Map<String, dynamic>? linkedProfile = await _fetchProfileByEmail(
        normalizedEmail,
      );
      if (linkedProfile == null) {
        throw StateError('Freshline could not create the account.');
      }
      final AppUser linkedUser = _userFromProfile(linkedProfile);
      await _insertWelcomeNotificationIfNeeded(linkedUser);
      return linkedUser;
    }

    final AppUser user = _userFromProfile(
      Map<String, dynamic>.from(rows.first as Map),
    );
    await _insertWelcomeNotificationIfNeeded(user);
    return user;
  }

  @override
  Future<AppUser> updateProfile({
    required AppUser user,
    required String name,
    required String phone,
    required String city,
    required String address,
    required String avatarPath,
  }) async {
    final String userId = _requireProfileId(user);
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(phone);
    final String normalizedCity = normalizeBahrainLocation(city);
    final Map<String, dynamic> updateBody = <String, dynamic>{
      'full_name': name.trim(),
      'username': _safeKey(name),
      'phone': normalizedPhone,
      'city': normalizedCity,
      'address': address.trim(),
      'avatar_url': canonicalProfileImageForWrite(avatarPath),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    List<dynamic> rows;
    try {
      rows = await _patchRows(
        '/rest/v1/profiles?id=eq.$userId',
        body: updateBody,
        prefer: 'return=representation',
        fallback: 'Freshline could not update the profile.',
      );
    } catch (error) {
      final String message = error.toString().toLowerCase();
      if (!message.contains('address')) {
        rethrow;
      }

      updateBody.remove('address');
      rows = await _patchRows(
        '/rest/v1/profiles?id=eq.$userId',
        body: updateBody,
        prefer: 'return=representation',
        fallback: 'Freshline could not update the profile.',
      );
    }

    if (rows.isEmpty) {
      throw StateError('Freshline could not update the profile.');
    }
    return _userFromProfile(
      Map<String, dynamic>.from(rows.first as Map),
    ).copyWith(address: address.trim());
  }

  @override
  Future<AppUser> refreshUser({required AppUser user}) async {
    final String profileId = _readString(user.profileId);
    final Map<String, dynamic>? profile = profileId.isEmpty
        ? await _fetchProfileByEmail(user.email)
        : await _fetchProfileById(profileId);
    if (profile == null) {
      throw StateError('Account was not found.');
    }
    return _userFromProfile(profile).copyWith(
      address: _readString(profile['address']),
      preferredLanguage: user.preferredLanguage,
      isEmailTwoFactorEnabled: user.isEmailTwoFactorEnabled,
    );
  }

  @override
  Future<AppUser> updatePreferredLanguage({
    required AppUser user,
    required String languageCode,
  }) async {
    final String normalizedLanguage = languageCode.trim().toUpperCase() == 'AR'
        ? 'AR'
        : 'EN';
    return user.copyWith(preferredLanguage: normalizedLanguage);
  }

  @override
  Future<void> changePassword({
    required AppUser user,
    required String currentPassword,
    required String newPassword,
  }) async {
    final String userId = _requireProfileId(user);
    final Map<String, dynamic>? profile = await _fetchProfileById(userId);
    if (profile == null) {
      throw StateError('Account was not found.');
    }
    if (!verifyProfilePassword(
      storedPasswordHash: _readString(profile['password_hash']),
      password: currentPassword,
    )) {
      throw StateError('The current password is incorrect.');
    }

    await _patchRows(
      '/rest/v1/profiles?id=eq.$userId',
      body: <String, dynamic>{
        'password_hash': hashProfilePassword(newPassword),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not change the password.',
    );
  }

  @override
  Future<AuthOtpDispatchResult> sendPasswordResetCode({
    required String email,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final Map<String, dynamic>? profile = await _fetchProfileByEmail(
      normalizedEmail,
    );
    if (profile == null) {
      throw StateError('This email is not registered.');
    }
    return _sendManagedEmailOtp(
      email: normalizedEmail,
      purpose: _passwordResetOtpPurpose,
      profileId: _readString(profile['id']),
      fallback: 'Freshline could not send the password reset code right now.',
    );
  }

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final Map<String, dynamic>? profile = await _fetchProfileByEmail(
      normalizedEmail,
    );
    if (profile == null) {
      throw StateError('The verification code is invalid or has expired.');
    }

    await _verifyManagedEmailOtp(
      email: normalizedEmail,
      purpose: _passwordResetOtpPurpose,
      code: code,
      profileId: _readString(profile['id']),
      fallback: 'The verification code is invalid or has expired.',
    );
    final String verificationToken =
        'reset-${_safeKey(normalizedEmail)}-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(10000)}';
    _passwordResetTokensByEmail[normalizedEmail] = verificationToken;
    return verificationToken;
  }

  @override
  Future<void> completePasswordReset({
    required String email,
    required String verificationToken,
    required String newPassword,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final Map<String, dynamic>? profile = await _fetchProfileByEmail(
      normalizedEmail,
    );
    if (profile == null) {
      throw StateError('Freshline could not reset the password.');
    }
    if (_passwordResetTokensByEmail[normalizedEmail] !=
        verificationToken.trim()) {
      throw StateError(
        'The password reset request expired. Request a new code and try again.',
      );
    }

    await _patchRows(
      '/rest/v1/profiles?id=eq.${_readString(profile['id'])}',
      body: <String, dynamic>{
        'password_hash': hashProfilePassword(newPassword),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not reset the password.',
    );
    _passwordResetTokensByEmail.remove(normalizedEmail);
  }

  @override
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final String verificationToken = await verifyPasswordResetCode(
      email: email,
      code: code,
    );
    await completePasswordReset(
      email: email,
      verificationToken: verificationToken,
      newPassword: newPassword,
    );
  }

  @override
  Future<List<CustomerRatingReview>> loadSalonReviews({
    required String salonId,
  }) async {
    final String normalizedSalonId = salonId.trim();
    if (normalizedSalonId.isEmpty) {
      return const <CustomerRatingReview>[];
    }

    final List<dynamic> rows = await _getRows(
      '/rest/v1/salon_reviews?select=salon_rating,comment,created_at,customer:profiles(full_name,username)&salon_id=eq.$normalizedSalonId&order=created_at.desc',
    );
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) {
          final Map<String, dynamic> json = Map<String, dynamic>.from(row);
          final Map<String, dynamic>? customer = (json['customer'] is Map)
              ? Map<String, dynamic>.from(json['customer'] as Map)
              : null;
          return CustomerRatingReview(
            reviewerName: _readString(
              customer?['full_name'] ?? customer?['username'],
              fallback: 'User',
            ),
            rating: _readInt(json['salon_rating'], fallback: 0),
            comment: () {
              final Map<String, String> parts =
                  _splitSalonReviewComment(_readString(json['comment']));
              return parts['salon'] ?? parts['employee'] ?? '';
            }(),
            createdAt: DateTime.tryParse(_readString(json['created_at'])) ??
                DateTime.now(),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<CustomerRatingReview>> loadEmployeeReviews({
    required String employeeId,
  }) async {
    final String normalizedEmployeeId = employeeId.trim();
    if (normalizedEmployeeId.isEmpty) {
      return const <CustomerRatingReview>[];
    }

    final List<dynamic> rows = await _getRows(
      '/rest/v1/salon_reviews?select=employee_rating,comment,created_at,customer:profiles(full_name,username)&employee_id=eq.$normalizedEmployeeId&order=created_at.desc',
    );
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) {
          final Map<String, dynamic> json = Map<String, dynamic>.from(row);
          final Map<String, dynamic>? customer = (json['customer'] is Map)
              ? Map<String, dynamic>.from(json['customer'] as Map)
              : null;
          return CustomerRatingReview(
            reviewerName: _readString(
              customer?['full_name'] ?? customer?['username'],
              fallback: 'User',
            ),
            rating: _readInt(json['employee_rating'], fallback: 0),
            comment: () {
              final Map<String, String> parts =
                  _splitSalonReviewComment(_readString(json['comment']));
              return parts['employee'] ?? parts['salon'] ?? '';
            }(),
            createdAt: DateTime.tryParse(_readString(json['created_at'])) ??
                DateTime.now(),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<AuthOtpDispatchResult> sendEmailTwoFactorSetupCode({
    required AppUser user,
  }) async {
    return const AuthOtpDispatchResult();
  }

  @override
  Future<AppUser> enableEmailTwoFactor({
    required AppUser user,
    required String code,
  }) async {
    return user.copyWith(isEmailTwoFactorEnabled: false);
  }

  @override
  Future<AppUser> disableEmailTwoFactor({required AppUser user}) async {
    return user.copyWith(isEmailTwoFactorEnabled: false);
  }

  @override
  Future<List<PaymentCardInfo>> loadSavedCards({required AppUser user}) async {
    final String userId = _requireProfileId(user);
    final List<dynamic> rows = await _getRows(
      '/rest/v1/saved_cards?select=*&customer_id=eq.$userId&order=is_default.desc,created_at.desc',
    );
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> row) =>
              _cardFromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<SavedCustomerAddress>> loadSavedAddresses({
    required AppUser user,
  }) async {
    final String userId = _requireProfileId(user);
    final List<dynamic> rows = await _getRows(
      '/rest/v1/customer_addresses?select=*&customer_id=eq.$userId&order=is_default.desc,updated_at.desc,created_at.desc',
    );
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> row) =>
              _savedAddressFromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Future<PaymentCardInfo> saveCard({
    required AppUser user,
    required PaymentCardInfo card,
  }) async {
    final String userId = _requireProfileId(user);
    final List<PaymentCardInfo> existingCards = await loadSavedCards(
      user: user,
    );
    final (_ExpiryPart month, _ExpiryPart year) = _parseExpiry(
      card.expiryLabel,
    );
    final List<dynamic> rows = await _postRows(
      '/rest/v1/saved_cards',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'customer_id': userId,
          'cardholder_name': card.holderName.trim(),
          'brand': card.brand.trim(),
          'last4': card.last4.trim(),
          'expiry_month': month.value,
          'expiry_year': year.value,
          'token_reference': 'manual-${DateTime.now().millisecondsSinceEpoch}',
          'is_default': existingCards.isEmpty,
        },
      ],
      prefer: 'return=representation',
      fallback: 'Freshline could not save the card.',
    );
    if (rows.isEmpty) {
      throw StateError('Freshline could not save the card.');
    }
    return _cardFromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  @override
  Future<void> removeSavedCard({
    required AppUser user,
    required PaymentCardInfo card,
  }) async {
    final String userId = _requireProfileId(user);
    await _deleteRows(
      '/rest/v1/saved_cards?id=eq.${card.id}&customer_id=eq.$userId',
      prefer: 'return=minimal',
      fallback: 'Freshline could not delete the card.',
    );
  }

  @override
  Future<SubscriptionPlan?> loadActivePlan({required AppUser user}) async {
    return (await loadCustomerSubscriptionStatus(user: user))?.plan;
  }

  @override
  Future<CustomerSubscriptionStatus?> loadCustomerSubscriptionStatus({
    required AppUser user,
  }) async {
    final String userId = _requireProfileId(user);
    final List<dynamic> rows = await _getRows(
      '/rest/v1/customer_subscriptions?select=plan_id,starts_at,ends_at,auto_renew,created_at&customer_id=eq.$userId&is_active=eq.true&order=created_at.desc&limit=1',
    );
    if (rows.isEmpty) {
      return null;
    }
    return _customerSubscriptionFromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  @override
  Future<CustomerSubscriptionStatus?> updateCustomerSubscriptionAutoRenew({
    required AppUser user,
    required bool autoRenew,
  }) async {
    final String userId = _requireProfileId(user);
    await _patchRows(
      '/rest/v1/customer_subscriptions?customer_id=eq.$userId&is_active=eq.true',
      body: <String, dynamic>{'auto_renew': autoRenew},
      prefer: 'return=minimal',
      fallback: 'Freshline could not update auto-renew for this subscription.',
    );
    final CustomerSubscriptionStatus? updated =
        await loadCustomerSubscriptionStatus(user: user);
    if (updated != null) {
      await _recordActivityLogSafely(
        actor: user,
        actionType: 'customer_subscription_auto_renew_updated',
        targetTable: 'customer_subscriptions',
        targetId: userId,
        actionSummary:
            '${user.name} turned ${autoRenew ? 'on' : 'off'} auto-renew for the ${updated.plan.name} plan.',
      );
    }
    return updated;
  }

  @override
  Future<List<PromoCouponRecord>> loadPromoCoupons({
    bool activeOnly = false,
  }) async {
    final StringBuffer path = StringBuffer(
      '/rest/v1/promo_coupons?select=*&salon_id=is.null',
    );
    if (activeOnly) {
      path.write('&is_active=eq.true');
    }
    path.write('&order=updated_at.desc,created_at.desc');

    final List<dynamic> rows = await _getRows(path.toString());
    final DateTime now = DateTime.now();
    final List<PromoCouponRecord> coupons = rows
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> row) =>
              _promoCouponFromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
    if (!activeOnly) {
      return coupons;
    }
    return coupons
        .where(
          (PromoCouponRecord coupon) =>
              coupon.isActive && coupon.isAvailableAt(now),
        )
        .toList(growable: false);
  }

  @override
  Future<void> subscribeToPlan({
    required AppUser user,
    required SubscriptionPlan plan,
    required PaymentCardInfo card,
  }) async {
    final String userId = _requireProfileId(user);
    final DateTime now = DateTime.now().toUtc();
    final DateTime endsAt = DateTime.utc(
      now.year,
      now.month + 1,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    await _patchRows(
      '/rest/v1/customer_subscriptions?customer_id=eq.$userId&is_active=eq.true',
      body: <String, dynamic>{'is_active': false, 'auto_renew': false},
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the current subscription.',
    );

    final List<dynamic> rows = await _postRows(
      '/rest/v1/customer_subscriptions',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'customer_id': userId,
          'plan_id': plan.id,
          'payment_status': 'paid',
          'is_active': true,
          'auto_renew': true,
          'ends_at': endsAt.toIso8601String(),
        },
      ],
      prefer: 'return=representation',
      fallback: 'Freshline could not activate the subscription.',
    );
    if (rows.isEmpty) {
      throw StateError('Freshline could not activate the subscription.');
    }

    final String subscriptionId = _readString(
      Map<String, dynamic>.from(rows.first as Map)['id'],
    );
    await _postRows(
      '/rest/v1/payment_transactions',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'profile_id': userId,
          'source_table': 'customer_subscriptions',
          'source_id': subscriptionId,
          'gateway_name': card.brand,
          'amount': plan.price,
          'currency_code': 'BHD',
          'payment_status': 'paid',
          'external_reference': 'sub-${DateTime.now().millisecondsSinceEpoch}',
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
      prefer: 'return=minimal',
      fallback: 'Freshline could not record the payment transaction.',
    );

    await _insertNotification(
      title: 'Subscription Activated',
      titleAr: 'تم تفعيل الاشتراك',
      body:
          '${plan.name} plan is active now. Payment completed with ${card.displayLabel}.',
      bodyAr:
          'أصبحت باقة ${plan.nameAr ?? plan.name} مفعلة الآن. اكتمل الدفع باستخدام ${card.displayLabel}.',
      audience: 'single_user',
      targetProfileId: userId,
    );
    await _recordActivityLogSafely(
      actor: user,
      actionType: 'customer_subscription_started',
      targetTable: 'customer_subscriptions',
      targetId: subscriptionId,
      actionSummary:
          '${user.name} subscribed to the ${plan.name} plan using ${card.displayLabel}.',
    );
  }

  @override
  Future<SalonSubscriptionStatus?> activateSalonSubscription({
    required AppUser user,
    required SubscriptionCycleOption cycle,
  }) async {
    final String userId = _requireProfileId(user);
    final DateTime expiryDate = DateTime.now().add(
      Duration(days: cycle == SubscriptionCycleOption.yearly ? 365 : 30),
    );
    final String formattedExpiryDate =
        '${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';

    final List<dynamic> rows = await _patchRows(
      '/rest/v1/salons?owner_id=eq.$userId&is_active=eq.true',
      body: <String, dynamic>{
        'subscription_cycle': cycle.name,
        'subscription_amount_bhd': cycle.salonPrice,
        'subscription_paid_until': formattedExpiryDate,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=representation',
      fallback: 'Freshline could not activate the salon subscription.',
    );

    final Map<String, dynamic>? row = rows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .firstOrNull;
    if (row == null) {
      final SalonSubscriptionStatus fallbackStatus = SalonSubscriptionStatus(
        cycle: cycle,
        amount: cycle.salonPrice,
        expiresAt: expiryDate,
      );
      await _recordActivityLogSafely(
        actor: user,
        actionType: 'salon_subscription_started',
        targetTable: 'salons',
        actionSummary:
            '${user.name} activated the ${cycle.label.toLowerCase()} salon plan.',
      );
      return fallbackStatus;
    }
    final SalonSubscriptionStatus status = _salonSubscriptionStatusFromJson(
      row,
    );
    await _recordActivityLogSafely(
      actor: user,
      actionType: 'salon_subscription_started',
      targetTable: 'salons',
      targetId: _readString(row['id']),
      actionSummary:
          '${user.name} activated the ${cycle.label.toLowerCase()} plan for ${_readString(row['name'], fallback: 'the salon')}.',
    );
    return status;
  }

  @override
  Future<SalonSubscriptionStatus?> updateSalonSubscriptionAutoRenew({
    required AppUser user,
    required bool autoRenew,
  }) async {
    final String userId = _requireProfileId(user);
    final List<dynamic> rows = await _patchRows(
      '/rest/v1/salons?owner_id=eq.$userId&is_active=eq.true',
      body: <String, dynamic>{
        'subscription_auto_renew': autoRenew,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=representation',
      fallback:
          'Freshline could not update auto-renew for the salon subscription.',
    );
    final Map<String, dynamic>? row = rows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .firstOrNull;
    if (row == null) {
      return null;
    }
    final SalonSubscriptionStatus status = _salonSubscriptionStatusFromJson(
      row,
    );
    await _recordActivityLogSafely(
      actor: user,
      actionType: 'salon_subscription_auto_renew_updated',
      targetTable: 'salons',
      targetId: _readString(row['id']),
      actionSummary:
          '${user.name} turned ${autoRenew ? 'on' : 'off'} auto-renew for ${_readString(row['name'], fallback: 'the salon')}.',
    );
    return status;
  }

  @override
  Future<CustomerCommerceSnapshot> loadCustomerCommerce({
    required AppUser user,
  }) async {
    final String userId = _requireProfileId(user);
    final bool useArabic = _useArabicLanguage(user.preferredLanguage);
    final List<List<dynamic>>
    results = await Future.wait<List<dynamic>>(<Future<List<dynamic>>>[
      _getRows(
        '/rest/v1/loyalty_wallets?select=points_balance&customer_id=eq.$userId&limit=1',
      ),
      _getRows(
        '/rest/v1/product_orders?select=id,order_number,payment_status,total_amount,notes,created_at&customer_id=eq.$userId&order=created_at.desc',
      ),
      _getRows(
        '/rest/v1/salon_bookings?select=id,booking_number,salon_id,employee_id,visit_mode,manual_address,appointment_at,booking_status,total_amount,loyalty_points_earned,notes,created_at&customer_id=eq.$userId&order=appointment_at.desc',
      ),
      _getRows(
        '/rest/v1/salon_bookings?select=salon_id,employee_id,appointment_at,notes,booking_status&booking_status=in.(pending,confirmed)',
      ),
    ]);

    final List<Map<String, dynamic>> walletRows = _toRowMaps(results[0]);
    final List<Map<String, dynamic>> productRows = _toRowMaps(results[1]);
    final List<Map<String, dynamic>> bookingRows = _toRowMaps(results[2]);
    final List<Map<String, dynamic>> activeBookingRows = _toRowMaps(results[3]);
    final List<String> productOrderIds = productRows
        .map((Map<String, dynamic> row) => _readString(row['id']))
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    final List<Map<String, dynamic>> productItemRows = productOrderIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _toRowMaps(
            await _getRows(
              '/rest/v1/product_order_items?select=order_id,product_id,product_name,product_name_ar,quantity,unit_price&order_id=in.(${_inFilterValues(productOrderIds)})',
            ),
          );
    final List<Map<String, dynamic>> salonReviewRows = _toRowMaps(
      await _getRows(
        '/rest/v1/salon_reviews?select=booking_id,salon_rating,employee_rating&customer_id=eq.$userId',
      ),
    );
    final List<Map<String, dynamic>> productReviewRows = productOrderIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _toRowMaps(
            await _getRows(
              '/rest/v1/product_reviews?select=order_id,product_id,rating&customer_id=eq.$userId&order_id=in.(${_inFilterValues(productOrderIds)})',
            ),
          );
    final Map<String, List<RatedOrderProductItem>> productItemsByOrderId =
        <String, List<RatedOrderProductItem>>{};
    final Map<String, double> productRatingsByOrderKey = productReviewRows
        .fold<Map<String, double>>(<String, double>{}, (
          Map<String, double> map,
          Map<String, dynamic> row,
        ) {
          final String orderId = _readString(row['order_id']);
          final String productId = _readString(row['product_id']);
          if (orderId.isNotEmpty && productId.isNotEmpty) {
            map['$orderId|$productId'] = _readDouble(row['rating']);
          }
          return map;
        });
    for (final Map<String, dynamic> row in productItemRows) {
      final String orderId = _readString(row['order_id']);
      final String productId = _readString(row['product_id']);
      if (orderId.isEmpty) {
        continue;
      }
      final RatedOrderProductItem item = RatedOrderProductItem(
        productId: productId,
        productName: _localizedProductNameFromRow(row, useArabic: useArabic),
        productNameAr: _nullableString(row['product_name_ar']),
        quantity: _readInt(row['quantity'], fallback: 1),
        unitPrice: _readDouble(row['unit_price']),
        reviewSubmitted: productRatingsByOrderKey.containsKey(
          '$orderId|$productId',
        ),
        existingRating: productRatingsByOrderKey['$orderId|$productId'],
      );
      productItemsByOrderId
          .putIfAbsent(orderId, () => <RatedOrderProductItem>[])
          .add(item);
    }
    final Map<String, Map<String, dynamic>> salonReviewsByBookingId =
        salonReviewRows.fold<Map<String, Map<String, dynamic>>>(
          <String, Map<String, dynamic>>{},
          (Map<String, Map<String, dynamic>> map, Map<String, dynamic> row) {
            final String bookingId = _readString(row['booking_id']);
            if (bookingId.isNotEmpty) {
              map[bookingId] = row;
            }
            return map;
          },
        );

    final List<UserOrder> activeOrders = <UserOrder>[];
    final List<UserOrder> completedOrders = <UserOrder>[];

    for (final Map<String, dynamic> row in productRows) {
      final Map<String, dynamic> metadata = _decodeOrderMetadata(row['notes']);
      final UserOrder order = UserOrder(
        id: _readString(row['id']),
        type: UserOrderType.productOrder,
        invoiceNumber: _nullableString(row['order_number']),
        salonName: _localizedMetadataValue(
          metadata,
          key: 'salon_name',
          useArabic: useArabic,
          fallback: useArabic ? 'طلب منتجات' : 'Product Order',
        ),
        serviceName: _productSummaryFromMetadata(
          metadata,
          useArabic: useArabic,
        ),
        employeeName: _localizedMetadataValue(
          metadata,
          key: 'employee_name',
          useArabic: useArabic,
          fallback: useArabic ? 'توصيل فريش لاين' : 'Freshline Delivery',
        ),
        visitMode: _localizedMetadataValue(
          metadata,
          key: 'visit_mode',
          useArabic: useArabic,
          fallback: useArabic ? 'توصيل منزلي' : 'Home delivery',
        ),
        scheduledAt: (_readDateTime(row['created_at']) ?? DateTime.now())
            .toLocal(),
        total: _readDouble(row['total_amount']),
        statusLabel: _localizedMetadataValue(
          metadata,
          key: 'status_label',
          useArabic: useArabic,
          fallback: useArabic ? 'قيد التجهيز' : 'Preparing',
        ),
        loyaltyPointsGained: _readInt(metadata['loyalty_points_gained']),
        address: _readString(metadata['delivery_address']),
        cardLabel: _readString(metadata['card_label']),
        productItems:
            productItemsByOrderId[_readString(row['id'])] ??
            const <RatedOrderProductItem>[],
      );
      if (_isCompletedOrderStatus(order.statusLabel)) {
        completedOrders.add(order);
      } else {
        activeOrders.add(order);
      }
    }

    for (final Map<String, dynamic> row in bookingRows) {
      final Map<String, dynamic> metadata = _decodeOrderMetadata(row['notes']);
      final String bookingStatus = _readString(
        row['booking_status'],
        fallback: 'pending',
      );
      final Map<String, dynamic>? review =
          salonReviewsByBookingId[_readString(row['id'])];
      final UserOrder order = UserOrder(
        id: _readString(row['id']),
        type: UserOrderType.salonBooking,
        invoiceNumber: _nullableString(row['booking_number']),
        salonId: _readString(row['salon_id']),
        employeeId: _readString(metadata['employee_key'] ?? row['employee_id']),
        salonName: _localizedMetadataValue(
          metadata,
          key: 'salon_name',
          useArabic: useArabic,
          fallback: useArabic ? 'صالون فريش لاين' : 'Freshline Salon',
        ),
        serviceName: _localizedMetadataValue(
          metadata,
          key: 'service_name',
          useArabic: useArabic,
          fallback: useArabic ? 'حجز صالون' : 'Salon booking',
        ),
        employeeName: _localizedMetadataValue(
          metadata,
          key: 'employee_name',
          useArabic: useArabic,
          fallback: useArabic ? 'خبير فريش لاين' : 'Freshline Stylist',
        ),
        visitMode: _visitModeLabelForLanguage(
          _readString(row['visit_mode']),
          useArabic: useArabic,
          fallback: _readString(metadata['visit_mode']),
          fallbackArabic: _readString(metadata['visit_mode_ar']),
        ),
        scheduledAt: (_readDateTime(row['appointment_at']) ?? DateTime.now())
            .toLocal(),
        total: _readDouble(row['total_amount']),
        statusLabel: _localizedMetadataValue(
          metadata,
          key: 'status_label',
          useArabic: useArabic,
          fallback: _bookingStatusLabelForLanguage(
            bookingStatus,
            useArabic: useArabic,
          ),
        ),
        loyaltyPointsGained: _readInt(row['loyalty_points_earned']),
        salonReviewSubmitted:
            review != null && _readDouble(review['salon_rating']) > 0,
        employeeReviewSubmitted:
            review != null && _readDouble(review['employee_rating']) > 0,
        appointmentDuration: _durationFromMinutes(
          metadata['appointment_duration_minutes'],
        ),
        address: _readString(
          row['manual_address'],
          fallback: _readString(metadata['address']),
        ),
        cardLabel: _readString(metadata['card_label']),
      );
      if (_isBookingCompleted(bookingStatus)) {
        completedOrders.add(order);
      } else {
        activeOrders.add(order);
      }
    }

    activeOrders.sort(
      (UserOrder a, UserOrder b) => b.scheduledAt.compareTo(a.scheduledAt),
    );
    completedOrders.sort(
      (UserOrder a, UserOrder b) => b.scheduledAt.compareTo(a.scheduledAt),
    );

    final Set<String> bookedSlotKeys = activeBookingRows
        .map((Map<String, dynamic> row) {
          final Map<String, dynamic> metadata = _decodeOrderMetadata(
            row['notes'],
          );
          final String salonId = _readString(row['salon_id']);
          final String employeeKey = _readString(
            metadata['employee_key'] ?? row['employee_id'],
          );
          final DateTime? appointmentAt = _readDateTime(
            row['appointment_at'],
          )?.toLocal();
          if (salonId.isEmpty || employeeKey.isEmpty || appointmentAt == null) {
            return null;
          }
          return _bookingSlotKey(
            salonId: salonId,
            employeeId: employeeKey,
            scheduledAt: appointmentAt,
          );
        })
        .whereType<String>()
        .toSet();

    final int loyaltyPoints = walletRows.isNotEmpty
        ? _readInt(walletRows.first['points_balance'])
        : _fallbackLoyaltyBalance(
            productRows: productRows,
            bookingRows: bookingRows,
          );

    return CustomerCommerceSnapshot(
      activeOrders: activeOrders,
      completedOrders: completedOrders,
      bookedSlotKeys: bookedSlotKeys,
      loyaltyPoints: loyaltyPoints < 0 ? 0 : loyaltyPoints,
    );
  }

  @override
  Future<List<Employee>> loadSalonEmployees({required String salonId}) async {
    final List<Employee> employees = await _loadSalonEmployeesInternal(
      salonId: salonId,
      includeInactive: false,
    );
    if (employees.isNotEmpty) {
      return employees;
    }
    return employeesForSalonFallback(salonId);
  }

  @override
  Future<Map<String, List<EmployeeScheduleEntry>>> loadEmployeeSchedules({
    required List<String> employeeIds,
  }) async {
    final List<String> normalizedIds = employeeIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return const <String, List<EmployeeScheduleEntry>>{};
    }

    final String inClause = normalizedIds.join(',');
    final List<dynamic> rows = await _getRows(
      '/rest/v1/employee_schedules?select=*&employee_id=in.($inClause)',
    );

    final Map<String, List<EmployeeScheduleEntry>> schedules =
        <String, List<EmployeeScheduleEntry>>{};
    for (final dynamic row in rows) {
      if (row is! Map) {
        continue;
      }
      final Map<String, dynamic> json = Map<String, dynamic>.from(row);
      final EmployeeScheduleEntry entry = EmployeeScheduleEntry.fromSupabase(
        json,
      );
      if (entry.employeeId.trim().isEmpty) {
        continue;
      }
      schedules.putIfAbsent(entry.employeeId, () => <EmployeeScheduleEntry>[]);
      schedules[entry.employeeId]!.add(entry);
    }

    return schedules;
  }

  @override
  Future<void> placeProductOrder({
    required AppUser user,
    required UserOrder order,
    required List<ProductOrderLineItem> items,
    required DeliveryLocationSelection location,
    required String addressDetails,
    required String? couponCode,
    required num couponDiscount,
    required int loyaltyPointsRedeemed,
    required num loyaltyDiscount,
    required num taxAmount,
  }) async {
    final String userId = _requireProfileId(user);
    final SavedCustomerAddress savedAddress = await _ensureCustomerAddress(
      user: user,
      addressDetails: addressDetails,
      location: location,
    );
    final List<Map<String, dynamic>> stockItems =
        _productStockReservationPayload(items);
    if (stockItems.isNotEmpty) {
      await _reserveSupabaseProductStock(stockItems);
    }
    final num subtotal = items.fold<num>(
      0,
      (num sum, ProductOrderLineItem item) => sum + item.lineTotal,
    );
    final Map<String, dynamic> metadata = <String, dynamic>{
      'salon_name': order.salonName,
      'salon_name_ar': order.salonNameAr,
      'employee_name': order.employeeName,
      'employee_name_ar': order.employeeNameAr,
      'visit_mode': order.visitMode,
      'visit_mode_ar': order.visitModeAr,
      'delivery_address': addressDetails,
      'delivery_location_label': location.fullLabel,
      'card_label': order.cardLabel,
      'status_label': order.statusLabel,
      'status_label_ar': order.statusLabelAr,
      'loyalty_points_gained': order.loyaltyPointsGained,
      'loyalty_points_redeemed': loyaltyPointsRedeemed,
      'coupon_code': couponCode,
      'coupon_discount': couponDiscount,
      'loyalty_discount': loyaltyDiscount,
      'tax_amount': taxAmount,
      'item_label': order.serviceName,
      'item_label_ar': order.serviceNameAr,
      'items_summary': items
          .map(
            (ProductOrderLineItem item) => <String, dynamic>{
              'name': item.productName,
              'name_ar': item.productNameAr,
              'quantity': item.quantity,
            },
          )
          .toList(growable: false),
    };

    final Map<String, dynamic> orderBody = <String, dynamic>{
      'order_number': (order.invoiceNumber ?? '').trim().isEmpty
          ? generateFreshlineInvoiceNumber()
          : normalizeFreshlineInvoiceNumber(
              order.invoiceNumber,
              sourceId: order.id,
            ),
      'customer_id': userId,
      'address_id': savedAddress.id,
      'payment_status': 'paid',
      'subtotal_amount': subtotal,
      'delivery_amount': 0,
      'discount_amount': couponDiscount + loyaltyDiscount,
      'loyalty_points_redeemed': loyaltyPointsRedeemed,
      'loyalty_discount_amount': loyaltyDiscount,
      'tax_amount': taxAmount,
      'total_amount': order.total,
      'notes': jsonEncode(metadata),
    };
    if ((couponCode ?? '').trim().isNotEmpty) {
      orderBody['coupon_code'] = couponCode;
      orderBody['coupon_discount_amount'] = couponDiscount;
    }

    List<dynamic> rows = const <dynamic>[];
    String orderId = '';
    try {
      for (int attempt = 0; ; attempt++) {
        try {
          rows = await _postRows(
            '/rest/v1/product_orders',
            body: <Map<String, dynamic>>[orderBody],
            prefer: 'return=representation',
            fallback: 'Freshline could not save the product order.',
          );
          break;
        } catch (error) {
          final String message = error.toString().toLowerCase();
          if (_isDuplicateInvoiceNumberError(error, 'order_number') &&
              attempt < 5) {
            orderBody['order_number'] = generateFreshlineInvoiceNumber();
            continue;
          }
          bool removedLegacyColumn = false;

          const List<String> optionalLegacyColumns = <String>[
            'coupon_code',
            'coupon_discount_amount',
            'loyalty_points_redeemed',
            'loyalty_discount_amount',
            'tax_amount',
          ];
          for (final String column in optionalLegacyColumns) {
            if (message.contains(column) && orderBody.containsKey(column)) {
              orderBody.remove(column);
              removedLegacyColumn = true;
            }
          }

          if (!removedLegacyColumn || attempt >= 2) {
            rethrow;
          }
        }
      }
      if (rows.isEmpty) {
        throw StateError('Freshline could not save the product order.');
      }

      orderId = _readString(Map<String, dynamic>.from(rows.first as Map)['id']);
      if (orderId.isEmpty) {
        throw StateError('Freshline could not save the product order.');
      }

      await _postRows(
        '/rest/v1/product_order_items',
        body: items
            .map(
              (ProductOrderLineItem item) => <String, dynamic>{
                'order_id': orderId,
                'product_id': _nullableUuid(item.productId),
                'product_name': item.productName,
                'product_name_ar': _nullableString(item.productNameAr),
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
                'line_total': item.lineTotal,
              },
            )
            .toList(growable: false),
        prefer: 'return=minimal',
        fallback: 'Freshline could not save the order items.',
      );
    } catch (_) {
      if (orderId.isNotEmpty) {
        try {
          await _deleteRows(
            '/rest/v1/product_orders?id=eq.$orderId',
            fallback: 'Freshline could not roll back the product order.',
          );
        } catch (_) {
          // Ignore rollback cleanup failures.
        }
      }
      if (stockItems.isNotEmpty) {
        try {
          await _restoreSupabaseProductStock(stockItems);
        } catch (_) {
          // Ignore restore failures and surface the original order error.
        }
      }
      rethrow;
    }

    await _recordPaymentTransaction(
      profileId: userId,
      sourceTable: 'product_orders',
      sourceId: orderId,
      gatewayName: _gatewayNameFromCardLabel(order.cardLabel),
      amount: order.total,
      externalReference: 'po-${DateTime.now().millisecondsSinceEpoch}',
    );
    await _applyLoyaltyMutation(
      userId: userId,
      sourceType: 'product_order',
      sourceId: orderId,
      gainedPoints: order.loyaltyPointsGained,
      redeemedPoints: loyaltyPointsRedeemed,
      description: 'Product order ${order.serviceName}',
    );

    final String salonId = _readString(order.salonId);
    if (salonId.isNotEmpty) {
      final String ownerProfileId = await _loadSalonOwnerProfileId(salonId);
      if (ownerProfileId.isNotEmpty) {
        await _insertNotificationSafely(
          title: 'New Product Order',
          body:
              'Order ${_readString(orderBody['order_number'])} from ${user.name} is waiting for your salon team.',
          audience: 'single_user',
          targetProfileId: ownerProfileId,
        );
      }
    }
    await _insertNotificationSafely(
      title: 'New Customer Product Order',
      body:
          'Order ${_readString(orderBody['order_number'])} from ${user.name} is ready for admin review.',
      audience: 'admins',
    );
    await _recordActivityLogSafely(
      actor: user,
      actionType: 'product_order_paid',
      targetTable: 'product_orders',
      targetId: orderId,
      actionSummary:
          '${user.name} placed product order ${_readString(orderBody['order_number'])} for BHD ${order.total.toStringAsFixed(2)}.',
    );
  }

  Future<void> _reserveSupabaseProductStock(
    List<Map<String, dynamic>> stockItems,
  ) async {
    if (stockItems.isEmpty) {
      return;
    }
    try {
      await _postRows(
        '/rest/v1/rpc/reserve_product_order_stock',
        body: <String, dynamic>{'p_items': stockItems},
        prefer: 'return=representation',
        fallback: 'Freshline could not reserve product stock.',
      );
      return;
    } catch (error) {
      if (!_isMissingProductStockReservationFunction(error)) {
        rethrow;
      }
    }
    await _reserveSupabaseProductStockLegacy(stockItems);
  }

  Future<void> _restoreSupabaseProductStock(
    List<Map<String, dynamic>> stockItems,
  ) async {
    if (stockItems.isEmpty) {
      return;
    }
    try {
      await _postRows(
        '/rest/v1/rpc/restore_product_order_stock',
        body: <String, dynamic>{'p_items': stockItems},
        prefer: 'return=minimal',
        fallback: 'Freshline could not restore product stock.',
      );
      return;
    } catch (error) {
      if (!_isMissingProductStockReservationFunction(error)) {
        rethrow;
      }
    }
    await _restoreSupabaseProductStockLegacy(stockItems);
  }

  Future<void> _reserveSupabaseProductStockLegacy(
    List<Map<String, dynamic>> stockItems,
  ) async {
    final Map<String, int> appliedQuantities = <String, int>{};
    try {
      for (final Map<String, dynamic> item in stockItems) {
        final String productId = _readString(item['product_id']);
        final int quantity = _readInt(item['quantity']);
        if (productId.isEmpty || quantity <= 0) {
          throw StateError('One of the selected products could not be found.');
        }
        final List<Map<String, dynamic>> rows = _toRowMaps(
          await _getRows(
            '/rest/v1/products?select=id,name,stock,is_active&id=eq.$productId&limit=1',
          ),
        );
        if (rows.isEmpty) {
          throw StateError('One of the selected products could not be found.');
        }
        final Map<String, dynamic> row = rows.first;
        final String productName = _readString(
          row['name'],
          fallback: 'This product',
        );
        final bool isActive = _readBool(row['is_active'], fallback: true);
        final int currentStock = _readInt(row['stock']);
        if (!isActive) {
          throw StateError('$productName is not available right now.');
        }
        if (currentStock < quantity) {
          throw StateError(
            '$productName only has $currentStock item${currentStock == 1 ? '' : 's'} left.',
          );
        }
        final List<dynamic> updatedRows = await _patchRows(
          '/rest/v1/products?id=eq.$productId&stock=eq.$currentStock',
          body: <String, dynamic>{
            'stock': currentStock - quantity,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          prefer: 'return=representation',
          fallback: 'Freshline could not update product stock.',
        );
        if (updatedRows.isEmpty) {
          throw StateError(
            '$productName stock changed just now. Please try checkout again.',
          );
        }
        appliedQuantities[productId] = quantity;
      }
    } catch (_) {
      if (appliedQuantities.isNotEmpty) {
        try {
          await _restoreSupabaseProductStockLegacy(
            appliedQuantities.entries
                .map(
                  (MapEntry<String, int> entry) => <String, dynamic>{
                    'product_id': entry.key,
                    'quantity': entry.value,
                  },
                )
                .toList(growable: false),
          );
        } catch (_) {
          // Ignore restore failures and surface the original stock error.
        }
      }
      rethrow;
    }
  }

  Future<void> _restoreSupabaseProductStockLegacy(
    List<Map<String, dynamic>> stockItems,
  ) async {
    for (final Map<String, dynamic> item in stockItems) {
      final String productId = _readString(item['product_id']);
      final int quantity = _readInt(item['quantity']);
      if (productId.isEmpty || quantity <= 0) {
        continue;
      }
      final List<Map<String, dynamic>> rows = _toRowMaps(
        await _getRows(
          '/rest/v1/products?select=stock&id=eq.$productId&limit=1',
        ),
      );
      if (rows.isEmpty) {
        continue;
      }
      final int currentStock = _readInt(rows.first['stock']);
      await _patchRows(
        '/rest/v1/products?id=eq.$productId',
        body: <String, dynamic>{
          'stock': currentStock + quantity,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        prefer: 'return=minimal',
        fallback: 'Freshline could not restore product stock.',
      );
    }
  }

  @override
  Future<void> placeSalonBooking({
    required AppUser user,
    required UserOrder order,
  }) async {
    final String userId = _requireProfileId(user);
    final String salonId = _readString(order.salonId);
    final String employeeKey = _readString(order.employeeId);
    if (salonId.isEmpty || employeeKey.isEmpty) {
      throw StateError('Freshline is missing the salon booking details.');
    }

    await _assertSalonSlotAvailable(
      salonId: salonId,
      employeeKey: employeeKey,
      scheduledAt: order.scheduledAt,
    );

    SavedCustomerAddress? savedAddress;
    if (order.location != null &&
        (order.addressDetails ?? '').trim().isNotEmpty &&
        order.visitMode.trim().toLowerCase() == 'come to you') {
      savedAddress = await _ensureCustomerAddress(
        user: user,
        addressDetails: order.addressDetails!,
        location: order.location!,
      );
    }

    final Map<String, dynamic> metadata = <String, dynamic>{
      'salon_name': order.salonName,
      'salon_name_ar': order.salonNameAr,
      'service_name': order.serviceName,
      'service_name_ar': order.serviceNameAr,
      'employee_key': employeeKey,
      'employee_name': order.employeeName,
      'employee_name_ar': order.employeeNameAr,
      'visit_mode': order.visitMode,
      'visit_mode_ar': order.visitModeAr,
      'appointment_duration_minutes': order.appointmentDuration?.inMinutes,
      'address': order.address,
      'card_label': order.cardLabel,
      'status_label': order.statusLabel,
      'status_label_ar': order.statusLabelAr,
    };

    final Map<String, dynamic> bookingBody = <String, dynamic>{
      'booking_number': (order.invoiceNumber ?? '').trim().isEmpty
          ? generateFreshlineInvoiceNumber()
          : normalizeFreshlineInvoiceNumber(
              order.invoiceNumber,
              sourceId: order.id,
            ),
      'customer_id': userId,
      'salon_id': salonId,
      'employee_id': _nullableUuid(order.employeeId),
      'visit_mode': _bookingVisitModeValue(order.visitMode),
      'address_id': savedAddress?.id,
      'manual_address': order.addressDetails ?? order.address,
      'appointment_at': order.scheduledAt.toUtc().toIso8601String(),
      'booking_status': 'confirmed',
      'payment_status': 'paid',
      'subtotal_amount': order.total,
      'discount_amount': 0,
      'total_amount': order.total,
      'loyalty_points_earned': order.loyaltyPointsGained,
      'notes': jsonEncode(metadata),
    };

    List<dynamic> rows;
    for (int attempt = 0; ; attempt++) {
      try {
        rows = await _postRows(
          '/rest/v1/salon_bookings',
          body: <Map<String, dynamic>>[bookingBody],
          prefer: 'return=representation',
          fallback: 'Freshline could not confirm the booking.',
        );
        break;
      } catch (error) {
        if (_isDuplicateInvoiceNumberError(error, 'booking_number') &&
            attempt < 5) {
          bookingBody['booking_number'] = generateFreshlineInvoiceNumber();
          continue;
        }
        rethrow;
      }
    }
    if (rows.isEmpty) {
      throw StateError('Freshline could not confirm the booking.');
    }

    final String bookingId = _readString(
      Map<String, dynamic>.from(rows.first as Map)['id'],
    );
    if (bookingId.isEmpty) {
      throw StateError('Freshline could not confirm the booking.');
    }

    await _recordPaymentTransaction(
      profileId: userId,
      salonId: salonId,
      sourceTable: 'salon_bookings',
      sourceId: bookingId,
      gatewayName: _gatewayNameFromCardLabel(order.cardLabel),
      amount: order.total,
      externalReference: 'bk-${DateTime.now().millisecondsSinceEpoch}',
    );
    await _applyLoyaltyMutation(
      userId: userId,
      sourceType: 'salon_booking',
      sourceId: bookingId,
      gainedPoints: order.loyaltyPointsGained,
      redeemedPoints: 0,
      description: 'Salon booking ${order.serviceName}',
    );

    final String ownerProfileId = await _loadSalonOwnerProfileId(salonId);
    if (ownerProfileId.isNotEmpty) {
      await _insertNotificationSafely(
        title: 'New Appointment',
        body:
            '${order.serviceName} is booked for ${_formatRepositoryDateTime(order.scheduledAt)} with invoice ${_readString(bookingBody['booking_number'])}.',
        titleAr: 'موعد جديد',
        bodyAr:
            '${order.serviceNameAr ?? order.serviceName} محجوز بتاريخ ${_formatRepositoryDateTime(order.scheduledAt)} برقم الفاتورة ${_readString(bookingBody['booking_number'])}.',
        audience: 'single_user',
        targetProfileId: ownerProfileId,
      );
    }

    final String employeeProfileId = await _loadEmployeeProfileId(employeeKey);
    if (employeeProfileId.isNotEmpty) {
      await _insertNotificationSafely(
        title: 'Appointment Assigned',
        body:
            '${order.customerName ?? 'A customer'} booked ${order.serviceName} for ${_formatRepositoryDateTime(order.scheduledAt)}.',
        titleAr: 'تم إسناد موعد',
        bodyAr:
            '${order.customerName ?? 'عميل'} حجز ${order.serviceNameAr ?? order.serviceName} بتاريخ ${_formatRepositoryDateTime(order.scheduledAt)}.',
        audience: 'single_user',
        targetProfileId: employeeProfileId,
      );
    }
    await _recordActivityLogSafely(
      actor: user,
      actionType: 'salon_booking_paid',
      targetTable: 'salon_bookings',
      targetId: bookingId,
      actionSummary:
          '${user.name} booked ${order.serviceName} at ${order.salonName} for BHD ${order.total.toStringAsFixed(2)}.',
    );
  }

  @override
  Future<void> completeOrder({
    required AppUser user,
    required UserOrder order,
  }) async {
    if (order.isProductOrder) {
      final List<dynamic> existing = await _getRows(
        '/rest/v1/product_orders?select=notes&id=eq.${order.id}&limit=1',
      );
      final Map<String, dynamic> currentRow = existing.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(existing.first as Map);
      final Map<String, dynamic> metadata = _decodeOrderMetadata(
        currentRow['notes'],
      );
      metadata['status_label'] = 'Delivered';
      metadata['status_label_ar'] = 'تم التسليم';
      metadata['completed_at'] = DateTime.now().toUtc().toIso8601String();
      await _patchRows(
        '/rest/v1/product_orders?id=eq.${order.id}',
        body: <String, dynamic>{'notes': jsonEncode(metadata)},
        prefer: 'return=minimal',
        fallback: 'Freshline could not update the product order.',
      );
      if (user.role == AppRole.admin) {
        await _recordActivityLogSafely(
          actor: user,
          actionType: 'admin_product_order_completed',
          targetTable: 'product_orders',
          targetId: order.id,
          actionSummary:
              '${user.name} marked product order ${order.displayInvoiceNumber} as delivered.',
        );
      }
      return;
    }

    final List<dynamic> existing = await _getRows(
      '/rest/v1/salon_bookings?select=notes&id=eq.${order.id}&limit=1',
    );
    final Map<String, dynamic> currentRow = existing.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(existing.first as Map);
    final Map<String, dynamic> metadata = _decodeOrderMetadata(
      currentRow['notes'],
    );
    metadata['status_label'] = 'Completed';
    metadata['status_label_ar'] = 'مكتمل';
    metadata['completed_at'] = DateTime.now().toUtc().toIso8601String();
    await _patchRows(
      '/rest/v1/salon_bookings?id=eq.${order.id}',
      body: <String, dynamic>{
        'booking_status': 'completed',
        'notes': jsonEncode(metadata),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the booking status.',
    );
  }

  @override
  Future<void> submitSalonReview({
    required AppUser user,
    required UserOrder order,
    required int salonRating,
    required int employeeRating,
    String comment = '',
  }) async {
    final String userId = _requireProfileId(user);
    final String bookingId = _readString(order.id);
    final String salonId = _readString(order.salonId);
    if (bookingId.isEmpty || salonId.isEmpty) {
      throw StateError(
        'Freshline is missing the booking details for this review.',
      );
    }

    await _postRows(
      '/rest/v1/salon_reviews?on_conflict=booking_id',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'booking_id': bookingId,
          'customer_id': userId,
          'salon_id': salonId,
          'employee_id': _nullableUuid(order.employeeId),
          'salon_rating': salonRating,
          'employee_rating': employeeRating,
          'comment': comment.trim(),
        },
      ],
      prefer: 'resolution=merge-duplicates,return=minimal',
      fallback: 'Freshline could not save the salon review.',
    );
    await _refreshSalonReviewSummary(
      salonId: salonId,
      employeeId: _nullableUuid(order.employeeId),
    );
  }

  @override
  Future<void> submitProductReview({
    required AppUser user,
    required UserOrder order,
    required String productId,
    required int rating,
    String comment = '',
  }) async {
    final String userId = _requireProfileId(user);
    final String orderId = _readString(order.id);
    final String normalizedProductId = _readString(productId);
    if (orderId.isEmpty || normalizedProductId.isEmpty) {
      throw StateError('Freshline is missing the product review details.');
    }

    await _postRows(
      '/rest/v1/product_reviews?on_conflict=order_id,product_id',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'order_id': orderId,
          'customer_id': userId,
          'product_id': _nullableUuid(normalizedProductId),
          'rating': rating,
          'comment': comment.trim(),
        },
      ],
      prefer: 'resolution=merge-duplicates,return=minimal',
      fallback: 'Freshline could not save the product review.',
    );
    await _refreshProductReviewSummary(productId: normalizedProductId);
  }

  @override
  Future<SalonWorkspaceSnapshot> loadSalonWorkspace({
    required AppUser user,
  }) async {
    final bool useArabic = _useArabicLanguage(user.preferredLanguage);
    final _ResolvedSalonWorkspace resolved = await _resolveSalonWorkspace(user);
    final List<Employee> employees = await _loadSalonEmployeesInternal(
      salonId: resolved.salon.id,
      includeInactive: true,
    );
    final List<List<dynamic>>
    workspaceRows = await Future.wait<List<dynamic>>(<Future<List<dynamic>>>[
      _getRows(
        '/rest/v1/salon_bookings?select=id,booking_number,customer_id,salon_id,employee_id,visit_mode,manual_address,appointment_at,booking_status,total_amount,loyalty_points_earned,notes,created_at&salon_id=eq.${resolved.salon.id}&order=appointment_at.desc',
      ),
      _getRows(
        '/rest/v1/salon_packages?select=*&salon_id=eq.${resolved.salon.id}&order=is_active.desc,created_at.asc',
      ),
      _getRows(
        '/rest/v1/salon_services?select=*&salon_id=eq.${resolved.salon.id}&order=is_active.desc,created_at.asc',
      ),
      _getRows(
        '/rest/v1/products?select=*&salon_id=eq.${resolved.salon.id}&order=is_active.desc,created_at.asc',
      ),
      _getRows(
        '/rest/v1/promo_coupons?select=*&salon_id=eq.${resolved.salon.id}&order=updated_at.desc,created_at.desc',
      ),
    ]);
    final List<dynamic> bookingRows = workspaceRows[0];
    final List<dynamic> packageRows = workspaceRows[1];
    final List<dynamic> serviceRows = workspaceRows[2];
    final List<dynamic> productRows = workspaceRows[3];
    final List<dynamic> couponRows = workspaceRows[4];
    final List<Map<String, dynamic>> bookings = _toRowMaps(bookingRows);
    final List<ServicePackage> packages = _toRowMaps(
      packageRows,
    ).map(ServicePackage.fromSupabase).toList(growable: false);
    final List<ServiceItem> services = _toRowMaps(
      serviceRows,
    ).map(ServiceItem.fromSupabase).toList(growable: false);
    final List<Product> products = _toRowMaps(productRows)
        .map(
          (Map<String, dynamic> row) => Product.fromSupabase(
            row,
            fallbackImagePath: currentDefaultProductImageUrl(),
          ),
        )
        .toList(growable: false);
    final List<PromoCouponRecord> coupons = _toRowMaps(
      couponRows,
    ).map(_promoCouponFromJson).toList(growable: false);
    final _SalonProductOrdersLoadResult productOrderResult =
        await _loadSalonProductOrdersForWorkspace(
          salon: resolved.salon,
          products: products,
          useArabic: useArabic,
        );
    final List<EmployeeSalaryPayment> salaryPayments =
        await _loadEmployeeSalaryPaymentsForSalon(
          salonId: resolved.salon.id,
          employees: employees,
        );
    final List<String> customerIds = bookings
        .map((Map<String, dynamic> row) => _readString(row['customer_id']))
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final Map<String, Map<String, dynamic>> customersById = customerIds.isEmpty
        ? const <String, Map<String, dynamic>>{}
        : _toRowMaps(
            await _getRows(
              '/rest/v1/profiles?select=id,full_name,username,phone&id=in.(${_inFilterValues(customerIds)})',
            ),
          ).fold<Map<String, Map<String, dynamic>>>(
            <String, Map<String, dynamic>>{},
            (Map<String, Map<String, dynamic>> map, Map<String, dynamic> row) {
              final String id = _readString(row['id']);
              if (id.isNotEmpty) {
                map[id] = row;
              }
              return map;
            },
          );

    final List<UserOrder> allBookings = bookings
        .map((Map<String, dynamic> row) {
          final Map<String, dynamic> metadata = _decodeOrderMetadata(
            row['notes'],
          );
          final String bookingStatus = _readString(
            row['booking_status'],
            fallback: 'pending',
          );
          final String customerId = _readString(row['customer_id']);
          final Map<String, dynamic>? customer = customersById[customerId];
          return UserOrder(
            id: _readString(row['id']),
            type: UserOrderType.salonBooking,
            invoiceNumber: _nullableString(row['booking_number']),
            salonId: _readString(row['salon_id']),
            employeeId: _readString(
              metadata['employee_key'] ?? row['employee_id'],
            ),
            salonName: _localizedMetadataValue(
              metadata,
              key: 'salon_name',
              useArabic: useArabic,
              fallback: useArabic
                  ? _readString(
                      resolved.salon.nameAr,
                      fallback: resolved.salon.name,
                    )
                  : resolved.salon.name,
            ),
            serviceName: _localizedMetadataValue(
              metadata,
              key: 'service_name',
              useArabic: useArabic,
              fallback: useArabic ? 'حجز صالون' : 'Salon booking',
            ),
            employeeName: _localizedMetadataValue(
              metadata,
              key: 'employee_name',
              useArabic: useArabic,
              fallback: useArabic ? 'خبير فريش لاين' : 'Freshline Stylist',
            ),
            customerName: _readString(
              customer?['full_name'] ?? customer?['username'],
              fallback: 'Freshline Customer',
            ),
            customerPhone: _nullableString(customer?['phone']),
            visitMode: _visitModeLabelForLanguage(
              _readString(row['visit_mode']),
              useArabic: useArabic,
              fallback: _readString(metadata['visit_mode']),
              fallbackArabic: _readString(metadata['visit_mode_ar']),
            ),
            scheduledAt:
                (_readDateTime(row['appointment_at']) ?? DateTime.now())
                    .toLocal(),
            total: _readDouble(row['total_amount']),
            statusLabel: _localizedMetadataValue(
              metadata,
              key: 'status_label',
              useArabic: useArabic,
              fallback: _bookingStatusLabelForLanguage(
                bookingStatus,
                useArabic: useArabic,
              ),
            ),
            loyaltyPointsGained: _readInt(row['loyalty_points_earned']),
            appointmentDuration: _durationFromMinutes(
              metadata['appointment_duration_minutes'],
            ),
            address: _readString(
              row['manual_address'],
              fallback: _readString(metadata['address']),
            ),
            cardLabel: _readString(metadata['card_label']),
          );
        })
        .toList(growable: false);

    final List<UserOrder> visibleBookings = resolved.currentEmployee == null
        ? allBookings
        : allBookings
              .where(
                (UserOrder order) =>
                    order.employeeId == resolved.currentEmployee!.id,
              )
              .toList(growable: false);
    final List<UserOrder> allProductOrders = productOrderResult.orders;
    final List<UserOrder> visibleProductOrders =
        resolved.currentEmployee == null
        ? allProductOrders
        : allProductOrders
              .where((UserOrder order) {
                final String assignedEmployeeId = (order.employeeId ?? '')
                    .trim();
                return assignedEmployeeId.isEmpty ||
                    assignedEmployeeId == resolved.currentEmployee!.id;
              })
              .toList(growable: false);
    final double productRevenue = productOrderResult.productRevenue;
    final double bookingRevenue = allBookings.fold<double>(
      0,
      (double sum, UserOrder order) => sum + order.total.toDouble(),
    );
    final double salaryCost = salaryPayments.fold<double>(
      0,
      (double sum, EmployeeSalaryPayment payment) => sum + payment.amount,
    );
    final SalonSubscriptionStatus subscriptionStatus =
        resolved.subscriptionStatus ??
        const SalonSubscriptionStatus(
          cycle: SubscriptionCycleOption.monthly,
          amount: salonMonthlySubscriptionPrice,
        );
    final double subscriptionCost = subscriptionStatus.amount;
    final int completedBookings = allBookings
        .where((UserOrder order) => _isCompletedOrder(order))
        .length;
    final int upcomingBookings = allBookings.length - completedBookings;

    return SalonWorkspaceSnapshot(
      salon: Salon(
        id: resolved.salon.id,
        name: resolved.salon.name,
        nameAr: resolved.salon.nameAr,
        imagePath: resolved.salon.imagePath,
        rating: resolved.salon.rating,
        reviews: resolved.salon.reviews,
        location: resolved.salon.location,
        locationAr: resolved.salon.locationAr,
        distance: resolved.salon.distance,
        services: resolved.salon.services,
        description: resolved.salon.description,
        descriptionAr: resolved.salon.descriptionAr,
        phone: resolved.salon.phone,
        priceLabel: resolved.salon.priceLabel,
        homeServiceAvailable: resolved.salon.homeServiceAvailable,
        address: resolved.salon.address,
        addressAr: resolved.salon.addressAr,
        latitude: resolved.salon.latitude,
        longitude: resolved.salon.longitude,
        packages: packages
            .where((ServicePackage item) => item.isActive)
            .toList(growable: false),
        serviceItems: services
            .where((ServiceItem item) => item.isActive)
            .toList(growable: false),
      ),
      employees: employees,
      bookings: visibleBookings,
      productOrders: visibleProductOrders,
      finance: SalonFinanceSnapshot(
        bookingRevenue: bookingRevenue,
        productRevenue: productRevenue,
        subscriptionCost: subscriptionCost,
        salaryCost: salaryCost,
        bookingProfit: bookingRevenue - salaryCost - subscriptionCost,
        completedBookings: completedBookings,
        upcomingBookings: upcomingBookings,
      ),
      salaryPayments: salaryPayments,
      packages: packages,
      services: services,
      products: products,
      coupons: coupons,
      subscriptionStatus: subscriptionStatus,
      currentEmployee: resolved.currentEmployee,
    );
  }

  @override
  Future<void> takeSalonProductOrder({
    required AppUser actor,
    required String orderId,
  }) async {
    if (actor.role != AppRole.employee) {
      throw StateError('Only employees can take product orders.');
    }
    final _ResolvedSalonWorkspace resolved = await _resolveSalonWorkspace(
      actor,
    );
    final Employee? employee = resolved.currentEmployee;
    if (employee == null) {
      throw StateError('Employee account details were not found.');
    }
    final String normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      throw StateError('Product order details are missing.');
    }
    final List<Map<String, dynamic>> rows = _toRowMaps(
      await _getRows(
        '/rest/v1/product_orders?select=notes,order_number&id=eq.$normalizedOrderId&limit=1',
      ),
    );
    if (rows.isEmpty) {
      throw StateError('Freshline could not find this product order.');
    }
    final Map<String, dynamic> metadata = _decodeOrderMetadata(
      rows.first['notes'],
    );
    final String assignedEmployeeId = _readString(
      metadata['assigned_employee_id'] ?? metadata['employee_key'],
    );
    if (assignedEmployeeId.isNotEmpty && assignedEmployeeId != employee.id) {
      throw StateError(
        'This product order was already taken by another employee.',
      );
    }
    if (assignedEmployeeId == employee.id) {
      return;
    }
    metadata['assigned_employee_id'] = employee.id;
    metadata['assigned_employee_name'] = employee.name;
    metadata['employee_key'] = employee.id;
    metadata['employee_name'] = employee.name;
    metadata['employee_name_ar'] = employee.name;
    if (!_isCompletedOrderStatus(_readString(metadata['status_label']))) {
      metadata['status_label'] = 'Accepted';
      metadata['status_label_ar'] = 'تم الاستلام';
    }
    metadata['claimed_at'] = DateTime.now().toUtc().toIso8601String();
    await _patchRows(
      '/rest/v1/product_orders?id=eq.$normalizedOrderId',
      body: <String, dynamic>{'notes': jsonEncode(metadata)},
      prefer: 'return=minimal',
      fallback: 'Freshline could not assign the product order.',
    );

    final String actorProfileId = actor.profileId?.trim() ?? '';
    if (actorProfileId.isNotEmpty) {
      await _insertNotificationSafely(
        title: 'Product Order Accepted',
        body:
            'You took order ${_readString(rows.first['order_number'], fallback: normalizeFreshlineInvoiceNumber(null, sourceId: normalizedOrderId))}.',
        titleAr: 'تم استلام طلب المنتج',
        bodyAr:
            'تم استلام الطلب ${_readString(rows.first['order_number'], fallback: normalizeFreshlineInvoiceNumber(null, sourceId: normalizedOrderId))}.',
        audience: 'single_user',
        targetProfileId: actorProfileId,
      );
    }
  }

  @override
  Future<List<UserOrder>> loadAdminProductOrders({
    required AppUser actor,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can view customer product orders.');
    }
    final bool useArabic = _useArabicLanguage(actor.preferredLanguage);
    final List<Map<String, dynamic>> orderRows = _toRowMaps(
      await _getRows(
        '/rest/v1/product_orders?select=id,order_number,customer_id,payment_status,total_amount,notes,created_at&order=created_at.desc',
      ),
    );
    if (orderRows.isEmpty) {
      return const <UserOrder>[];
    }

    final List<String> orderIds = orderRows
        .map((Map<String, dynamic> row) => _readString(row['id']))
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    final List<Map<String, dynamic>> itemRows = orderIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _toRowMaps(
            await _getRows(
              '/rest/v1/product_order_items?select=order_id,product_id,product_name,product_name_ar,quantity,unit_price,line_total&order_id=in.(${_inFilterValues(orderIds)})',
            ),
          );
    final List<String> customerIds = orderRows
        .map((Map<String, dynamic> row) => _readString(row['customer_id']))
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final Map<String, Map<String, dynamic>> customersById = customerIds.isEmpty
        ? const <String, Map<String, dynamic>>{}
        : _toRowMaps(
            await _getRows(
              '/rest/v1/profiles?select=id,full_name,username,phone&id=in.(${_inFilterValues(customerIds)})',
            ),
          ).fold<Map<String, Map<String, dynamic>>>(
            <String, Map<String, dynamic>>{},
            (Map<String, Map<String, dynamic>> map, Map<String, dynamic> row) {
              final String id = _readString(row['id']);
              if (id.isNotEmpty) {
                map[id] = row;
              }
              return map;
            },
          );

    final Map<String, List<RatedOrderProductItem>> productItemsByOrderId =
        <String, List<RatedOrderProductItem>>{};
    for (final Map<String, dynamic> row in itemRows) {
      final String orderId = _readString(row['order_id']);
      if (orderId.isEmpty) {
        continue;
      }
      productItemsByOrderId
          .putIfAbsent(orderId, () => <RatedOrderProductItem>[])
          .add(
            RatedOrderProductItem(
              productId: _readString(row['product_id']),
              productName: _localizedProductNameFromRow(
                row,
                useArabic: useArabic,
              ),
              productNameAr: _nullableString(row['product_name_ar']),
              quantity: _readInt(row['quantity'], fallback: 1),
              unitPrice: _readDouble(row['unit_price']),
            ),
          );
    }

    return orderRows
        .map((Map<String, dynamic> row) {
          final Map<String, dynamic> metadata = _decodeOrderMetadata(
            row['notes'],
          );
          final String orderId = _readString(row['id']);
          final String customerId = _readString(row['customer_id']);
          final Map<String, dynamic>? customer = customersById[customerId];
          final String assignedAdminId = _readString(
            metadata['assigned_admin_id'] ??
                metadata['assigned_employee_id'] ??
                metadata['employee_key'],
          );
          final String fallbackStatus = switch (_readString(
            row['payment_status'],
            fallback: 'pending',
          ).trim().toLowerCase()) {
            'paid' => useArabic ? 'قيد التجهيز' : 'Preparing',
            'failed' => useArabic ? 'فشل الدفع' : 'Failed',
            'refunded' => useArabic ? 'تم الاسترجاع' : 'Refunded',
            _ => useArabic ? 'بانتظار المعالجة' : 'Pending',
          };
          return UserOrder(
            id: orderId,
            type: UserOrderType.productOrder,
            invoiceNumber: _nullableString(row['order_number']),
            employeeId: assignedAdminId,
            salonName: _localizedMetadataValue(
              metadata,
              key: 'salon_name',
              useArabic: useArabic,
              fallback: useArabic ? 'طلبات فريش لاين' : 'Freshline Orders',
            ),
            serviceName: _productSummaryFromMetadata(
              metadata,
              useArabic: useArabic,
            ),
            employeeName: useArabic
                ? _readString(
                    metadata['assigned_admin_name_ar'] ??
                        metadata['assigned_employee_name_ar'] ??
                        metadata['employee_name_ar'] ??
                        metadata['assigned_admin_name'] ??
                        metadata['assigned_employee_name'] ??
                        metadata['employee_name'],
                    fallback: assignedAdminId.isEmpty
                        ? 'متاح لفريق الإدارة'
                        : 'إدارة فريش لاين',
                  )
                : _readString(
                    metadata['assigned_admin_name'] ??
                        metadata['assigned_employee_name'] ??
                        metadata['employee_name'],
                    fallback: assignedAdminId.isEmpty
                        ? 'Available for admin team'
                        : 'Freshline Admin',
                  ),
            customerName: _readString(
              customer?['full_name'] ?? customer?['username'],
              fallback: 'Freshline Customer',
            ),
            customerPhone: _nullableString(customer?['phone']),
            visitMode: _localizedMetadataValue(
              metadata,
              key: 'visit_mode',
              useArabic: useArabic,
              fallback: useArabic ? 'توصيل منزلي' : 'Home delivery',
            ),
            scheduledAt: (_readDateTime(row['created_at']) ?? DateTime.now())
                .toLocal(),
            total: _readDouble(row['total_amount']),
            statusLabel: _localizedMetadataValue(
              metadata,
              key: 'status_label',
              useArabic: useArabic,
              fallback: fallbackStatus,
            ),
            loyaltyPointsGained: _readInt(metadata['loyalty_points_gained']),
            address: _readString(metadata['delivery_address']),
            addressDetails: _readString(metadata['delivery_location_label']),
            cardLabel: _readString(metadata['card_label']),
            productItems:
                productItemsByOrderId[orderId] ??
                const <RatedOrderProductItem>[],
          );
        })
        .toList(growable: false)
      ..sort((UserOrder a, UserOrder b) {
        return b.scheduledAt.compareTo(a.scheduledAt);
      });
  }

  @override
  Future<void> takeAdminProductOrder({
    required AppUser actor,
    required String orderId,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can take product orders.');
    }
    final String adminProfileId = _requireProfileId(actor);
    final String normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      throw StateError('Product order details are missing.');
    }
    final List<Map<String, dynamic>> rows = _toRowMaps(
      await _getRows(
        '/rest/v1/product_orders?select=notes,order_number&id=eq.$normalizedOrderId&limit=1',
      ),
    );
    if (rows.isEmpty) {
      throw StateError('Freshline could not find this product order.');
    }
    final Map<String, dynamic> metadata = _decodeOrderMetadata(
      rows.first['notes'],
    );
    final String assignedAdminId = _readString(
      metadata['assigned_admin_id'] ??
          metadata['assigned_employee_id'] ??
          metadata['employee_key'],
    );
    if (assignedAdminId.isNotEmpty && assignedAdminId != adminProfileId) {
      throw StateError(
        'This product order was already taken by another admin.',
      );
    }
    if (assignedAdminId == adminProfileId) {
      return;
    }
    metadata['assigned_admin_id'] = adminProfileId;
    metadata['assigned_admin_name'] = actor.name;
    metadata['assigned_employee_id'] = adminProfileId;
    metadata['assigned_employee_name'] = actor.name;
    metadata['employee_key'] = adminProfileId;
    metadata['employee_name'] = actor.name;
    metadata['employee_name_ar'] = actor.name;
    if (!_isCompletedOrderStatus(_readString(metadata['status_label']))) {
      metadata['status_label'] = 'Accepted';
      metadata['status_label_ar'] = 'تم الاستلام';
    }
    metadata['claimed_at'] = DateTime.now().toUtc().toIso8601String();
    await _patchRows(
      '/rest/v1/product_orders?id=eq.$normalizedOrderId',
      body: <String, dynamic>{'notes': jsonEncode(metadata)},
      prefer: 'return=minimal',
      fallback: 'Freshline could not assign the product order.',
    );
    await _insertNotificationSafely(
      title: 'Admin Order Accepted',
      body:
          'You took order ${_readString(rows.first['order_number'], fallback: normalizeFreshlineInvoiceNumber(null, sourceId: normalizedOrderId))}.',
      audience: 'single_user',
      targetProfileId: adminProfileId,
    );
    await _recordActivityLogSafely(
      actor: actor,
      actionType: 'admin_product_order_taken',
      targetTable: 'product_orders',
      targetId: normalizedOrderId,
      actionSummary:
          '${actor.name} accepted customer product order ${_readString(rows.first['order_number'], fallback: normalizeFreshlineInvoiceNumber(null, sourceId: normalizedOrderId))}.',
    );
  }

  @override
  Future<Employee> saveSalonEmployee({
    required AppUser actor,
    String? employeeId,
    String? profileId,
    required String name,
    required String roleTitle,
    required String email,
    required String phone,
    required double monthlySalary,
    required bool supportsInShop,
    required bool supportsHomeService,
    required bool canLogin,
    String? workStartTime,
    String? workEndTime,
    String? breakStartTime,
    String? breakEndTime,
    String? password,
    String? avatarPath,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can manage employees.');
    }
    final _ResolvedSalonWorkspace resolved = await _resolveSalonWorkspace(
      actor,
    );
    final String normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw StateError('Employee email is required.');
    }
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(
      phone,
      fieldLabel: 'Employee phone number',
    );
    final String normalizedActorCity = normalizeBahrainLocation(actor.city);

    Map<String, dynamic>? linkedProfile;
    final String requestedProfileId = _readString(profileId);
    if (requestedProfileId.isNotEmpty) {
      linkedProfile = await _fetchProfileById(requestedProfileId);
    } else {
      linkedProfile = await _fetchProfileByEmail(normalizedEmail);
    }

    final String resolvedAvatarPath = _readString(
      avatarPath,
      fallback: normalizeProfileImageUrl(linkedProfile?['avatar_url']),
    );
    if (linkedProfile == null) {
      final List<dynamic> profileRows = await _postRows(
        '/rest/v1/profiles?on_conflict=email',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'role': AppRole.employee.value,
            'full_name': name.trim(),
            'username': _safeKey(name),
            'email': normalizedEmail,
            'password_hash': hashProfilePassword(
              _readString(password, fallback: 'freshline123'),
            ),
            'phone': normalizedPhone,
            'city': normalizedActorCity,
            'avatar_url': canonicalProfileImageForWrite(resolvedAvatarPath),
            'is_active': true,
          },
        ],
        prefer: 'resolution=merge-duplicates,return=representation',
        fallback: 'Freshline could not create the employee account.',
      );
      linkedProfile = profileRows.isEmpty
          ? null
          : Map<String, dynamic>.from(profileRows.first as Map);
    } else {
      final Map<String, dynamic> updateBody = <String, dynamic>{
        'role': AppRole.employee.value,
        'full_name': name.trim(),
        'username': _safeKey(name),
        'email': normalizedEmail,
        'phone': normalizedPhone,
        'city': normalizedActorCity,
        'avatar_url': canonicalProfileImageForWrite(resolvedAvatarPath),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if ((password ?? '').trim().isNotEmpty) {
        updateBody['password_hash'] = hashProfilePassword(password!.trim());
      }
      final List<dynamic> profileRows = await _patchRows(
        '/rest/v1/profiles?id=eq.${_readString(linkedProfile['id'])}',
        body: updateBody,
        prefer: 'return=representation',
        fallback: 'Freshline could not update the employee account.',
      );
      linkedProfile = profileRows.isEmpty
          ? linkedProfile
          : Map<String, dynamic>.from(profileRows.first as Map);
    }

    final Map<String, dynamic> employeePayload = <String, dynamic>{
      'salon_id': resolved.salon.id,
      'profile_id': _readString(linkedProfile?['id']),
      'full_name': name.trim(),
      'role_title': roleTitle.trim(),
      'phone': normalizedPhone,
      'email': normalizedEmail,
      'image_url': canonicalProfileImageForWrite(resolvedAvatarPath),
      'supports_in_shop': supportsInShop,
      'supports_home_service': supportsHomeService,
      'can_login': canLogin,
      'is_active': true,
      'monthly_salary_bhd': monthlySalary,
      if (_readString(workStartTime).isNotEmpty) 'work_start_time': workStartTime,
      if (_readString(workEndTime).isNotEmpty) 'work_end_time': workEndTime,
      if (_readString(breakStartTime).isNotEmpty)
        'break_start_time': breakStartTime,
      if (_readString(breakEndTime).isNotEmpty) 'break_end_time': breakEndTime,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final List<dynamic> employeeRows;
    if (_readString(employeeId).isEmpty) {
      employeeRows = await _postRows(
        '/rest/v1/salon_employees',
        body: <Map<String, dynamic>>[employeePayload],
        prefer: 'return=representation',
        fallback: 'Freshline could not create the employee.',
      );
    } else {
      employeeRows = await _patchRows(
        '/rest/v1/salon_employees?id=eq.${_readString(employeeId)}',
        body: employeePayload,
        prefer: 'return=representation',
        fallback: 'Freshline could not update the employee.',
      );
    }
    if (employeeRows.isEmpty) {
      throw StateError('Freshline could not save the employee.');
    }
    return Employee.fromSupabase(
      Map<String, dynamic>.from(employeeRows.first as Map),
      fallbackImagePath: resolvedAvatarPath,
    );
  }

  @override
  Future<void> setSalonEmployeeActive({
    required AppUser actor,
    required String employeeId,
    required bool isActive,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can manage employees.');
    }
    final List<Map<String, dynamic>> employeeRows = _toRowMaps(
      await _getRows(
        '/rest/v1/salon_employees?select=id,profile_id&id=eq.$employeeId&limit=1',
      ),
    );
    if (employeeRows.isEmpty) {
      return;
    }
    final String profileId = _readString(employeeRows.first['profile_id']);
    await _patchRows(
      '/rest/v1/salon_employees?id=eq.$employeeId',
      body: <String, dynamic>{
        'is_active': isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the employee status.',
    );
    if (profileId.isNotEmpty) {
      await _patchRows(
        '/rest/v1/profiles?id=eq.$profileId',
        body: <String, dynamic>{
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        prefer: 'return=minimal',
        fallback: 'Freshline could not update the employee account.',
      );
    }
  }

  @override
  Future<void> deleteSalonEmployee({
    required AppUser actor,
    required String employeeId,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can manage employees.');
    }
    final List<Map<String, dynamic>> employeeRows = _toRowMaps(
      await _getRows(
        '/rest/v1/salon_employees?select=id,profile_id&id=eq.$employeeId&limit=1',
      ),
    );
    if (employeeRows.isEmpty) {
      return;
    }
    final String profileId = _readString(employeeRows.first['profile_id']);
    await _deleteRows(
      '/rest/v1/salon_employees?id=eq.$employeeId',
      fallback: 'Freshline could not delete the employee.',
    );
    if (profileId.isNotEmpty) {
      await _deleteRows(
        '/rest/v1/profiles?id=eq.$profileId',
        fallback: 'Freshline could not remove the employee account.',
      );
    }
  }

  @override
  Future<ServicePackage> saveSalonPackage({
    required AppUser actor,
    String? packageId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    required bool isActive,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can manage packages.');
    }
    final bool useArabic = _useArabicLanguage(actor.preferredLanguage);
    final _ResolvedSalonWorkspace resolved = await _resolveSalonWorkspace(
      actor,
    );
    final Map<String, dynamic> body = <String, dynamic>{
      'salon_id': resolved.salon.id,
      'name': name.trim(),
      if (useArabic || _containsArabicText(name)) 'name_ar': name.trim(),
      'description': description.trim(),
      if (useArabic || _containsArabicText(description))
        'description_ar': description.trim(),
      'price_bhd': price,
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final List<dynamic> rows = _readString(packageId).isEmpty
        ? await _postRows(
            '/rest/v1/salon_packages',
            body: <Map<String, dynamic>>[body],
            prefer: 'return=representation',
            fallback: 'Freshline could not save the package.',
          )
        : await _patchRows(
            '/rest/v1/salon_packages?id=eq.${_readString(packageId)}',
            body: body,
            prefer: 'return=representation',
            fallback: 'Freshline could not update the package.',
          );
    if (rows.isEmpty) {
      throw StateError('Freshline could not save the package.');
    }
    return ServicePackage.fromSupabase(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  @override
  Future<void> deleteSalonPackage({
    required AppUser actor,
    required String packageId,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can delete packages.');
    }
    await _deleteRows(
      '/rest/v1/salon_packages?id=eq.$packageId',
      fallback: 'Freshline could not delete the package.',
    );
  }

  @override
  Future<ServiceItem> saveSalonService({
    required AppUser actor,
    String? serviceId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    required bool isActive,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can manage services.');
    }
    final bool useArabic = _useArabicLanguage(actor.preferredLanguage);
    final _ResolvedSalonWorkspace resolved = await _resolveSalonWorkspace(
      actor,
    );
    final Map<String, dynamic> body = <String, dynamic>{
      'salon_id': resolved.salon.id,
      'name': name.trim(),
      if (useArabic || _containsArabicText(name)) 'name_ar': name.trim(),
      'description': description.trim(),
      if (useArabic || _containsArabicText(description))
        'description_ar': description.trim(),
      'price_bhd': price,
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final List<dynamic> rows = _readString(serviceId).isEmpty
        ? await _postRows(
            '/rest/v1/salon_services',
            body: <Map<String, dynamic>>[body],
            prefer: 'return=representation',
            fallback: 'Freshline could not save the service.',
          )
        : await _patchRows(
            '/rest/v1/salon_services?id=eq.${_readString(serviceId)}',
            body: body,
            prefer: 'return=representation',
            fallback: 'Freshline could not update the service.',
          );
    if (rows.isEmpty) {
      throw StateError('Freshline could not save the service.');
    }
    return ServiceItem.fromSupabase(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  @override
  Future<void> deleteSalonService({
    required AppUser actor,
    required String serviceId,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can delete services.');
    }
    await _deleteRows(
      '/rest/v1/salon_services?id=eq.$serviceId',
      fallback: 'Freshline could not delete the service.',
    );
  }

  @override
  Future<Product> saveSalonProduct({
    required AppUser actor,
    String? productId,
    required String name,
    required String category,
    required String description,
    required double price,
    required int stock,
    required bool isActive,
    String? imagePath,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can manage products.');
    }
    final bool useArabic = _useArabicLanguage(actor.preferredLanguage);
    final bool isCreating = _readString(productId).isEmpty;
    final _ResolvedSalonWorkspace resolved = await _resolveSalonWorkspace(
      actor,
    );
    final Map<String, dynamic> body = <String, dynamic>{
      'salon_id': resolved.salon.id,
      'name': name.trim(),
      if (useArabic || _containsArabicText(name)) 'name_ar': name.trim(),
      'category': category.trim(),
      if (useArabic || _containsArabicText(category))
        'category_ar': category.trim(),
      'description': description.trim(),
      if (useArabic || _containsArabicText(description))
        'description_ar': description.trim(),
      'price': price,
      'stock': stock,
      'image_url': canonicalProductImageForWrite(imagePath),
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final List<dynamic> rows = _readString(productId).isEmpty
        ? await _postRows(
            '/rest/v1/products',
            body: <Map<String, dynamic>>[body],
            prefer: 'return=representation',
            fallback: 'Freshline could not save the product.',
          )
        : await _patchRows(
            '/rest/v1/products?id=eq.${_readString(productId)}',
            body: body,
            prefer: 'return=representation',
            fallback: 'Freshline could not update the product.',
          );
    if (rows.isEmpty) {
      throw StateError('Freshline could not save the product.');
    }
    final Product savedProduct = Product.fromSupabase(
      Map<String, dynamic>.from(rows.first as Map),
      fallbackImagePath: currentDefaultProductImageUrl(),
    );
    await _recordActivityLogSafely(
      actor: actor,
      actionType: isCreating
          ? 'salon_product_created'
          : 'salon_product_updated',
      targetTable: 'products',
      targetId: savedProduct.id,
      actionSummary:
          '${actor.name} ${isCreating ? 'added' : 'updated'} salon product ${savedProduct.name}.',
    );
    return savedProduct;
  }

  @override
  Future<void> deleteSalonProduct({
    required AppUser actor,
    required String productId,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can delete products.');
    }
    final List<Map<String, dynamic>> existingRows = _toRowMaps(
      await _getRows(
        '/rest/v1/products?select=id,name&id=eq.$productId&limit=1',
      ),
    );
    await _deleteRows(
      '/rest/v1/products?id=eq.$productId',
      fallback: 'Freshline could not delete the product.',
    );
    final Map<String, dynamic>? existingRow = existingRows.firstOrNull;
    await _recordActivityLogSafely(
      actor: actor,
      actionType: 'salon_product_deleted',
      targetTable: 'products',
      targetId: productId,
      actionSummary:
          '${actor.name} deleted salon product ${_readString(existingRow?['name'], fallback: 'product')}.',
    );
  }

  @override
  Future<Product> saveAdminProduct({
    required AppUser actor,
    String? productId,
    required String name,
    required String category,
    required String description,
    required double price,
    required int stock,
    required bool isActive,
    String? salonId,
    String? imagePath,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can manage platform products.');
    }
    final bool isCreating = _readString(productId).isEmpty;
    final Map<String, dynamic> body = <String, dynamic>{
      'salon_id': _nullableString(salonId),
      'name': name.trim(),
      'category': category.trim(),
      'description': description.trim(),
      'price': price,
      'stock': stock,
      'image_url': canonicalProductImageForWrite(imagePath),
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final List<dynamic> rows = _readString(productId).isEmpty
        ? await _postRows(
            '/rest/v1/products',
            body: <Map<String, dynamic>>[body],
            prefer: 'return=representation',
            fallback: 'Freshline could not save the platform product.',
          )
        : await _patchRows(
            '/rest/v1/products?id=eq.${_readString(productId)}',
            body: body,
            prefer: 'return=representation',
            fallback: 'Freshline could not update the platform product.',
          );
    if (rows.isEmpty) {
      throw StateError('Freshline could not save the platform product.');
    }
    final Product savedProduct = Product.fromSupabase(
      Map<String, dynamic>.from(rows.first as Map),
      fallbackImagePath: currentDefaultProductImageUrl(),
    );
    await _recordActivityLogSafely(
      actor: actor,
      actionType: isCreating
          ? 'admin_product_created'
          : 'admin_product_updated',
      targetTable: 'products',
      targetId: savedProduct.id,
      actionSummary:
          '${actor.name} ${isCreating ? 'added' : 'updated'} product ${savedProduct.name}.',
    );
    return savedProduct;
  }

  @override
  Future<void> deleteAdminProduct({
    required AppUser actor,
    required String productId,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can delete platform products.');
    }
    final List<Map<String, dynamic>> existingRows = _toRowMaps(
      await _getRows(
        '/rest/v1/products?select=id,name&id=eq.$productId&limit=1',
      ),
    );
    await _deleteRows(
      '/rest/v1/products?id=eq.$productId',
      fallback: 'Freshline could not delete the platform product.',
    );
    final Map<String, dynamic>? existingRow = existingRows.firstOrNull;
    await _recordActivityLogSafely(
      actor: actor,
      actionType: 'admin_product_deleted',
      targetTable: 'products',
      targetId: productId,
      actionSummary:
          '${actor.name} deleted product ${_readString(existingRow?['name'], fallback: 'product')}.',
    );
  }

  @override
  Future<PromoCouponRecord> saveSalonCoupon({
    required AppUser actor,
    required PromoCouponRecord coupon,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can manage salon offers.');
    }
    final _ResolvedSalonWorkspace resolved = await _resolveSalonWorkspace(
      actor,
    );
    final String normalizedDescription = (coupon.description ?? '').trim();
    final Map<String, dynamic> body = <String, dynamic>{
      'code': coupon.normalizedCode,
      'salon_id': resolved.salon.id,
      'description': normalizedDescription.isEmpty
          ? null
          : normalizedDescription,
      'discount_percent': coupon.discountPercent,
      'applicable_plan_id': coupon.appliesToAllPlans
          ? null
          : coupon.targetPlanId?.trim().toLowerCase(),
      'min_order_amount_bhd': coupon.minOrderAmountBhd,
      'max_discount_amount': coupon.maxDiscountBhd,
      'is_active': coupon.isActive,
      'starts_at': coupon.startsAt?.toUtc().toIso8601String(),
      'ends_at': coupon.endsAt?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final List<dynamic> rows = (coupon.id ?? '').trim().isEmpty
        ? await _postRows(
            '/rest/v1/promo_coupons',
            body: <Map<String, dynamic>>[body],
            prefer: 'return=representation',
            fallback: 'Freshline could not create the salon offer.',
          )
        : await _patchRows(
            '/rest/v1/promo_coupons?id=eq.${coupon.id}',
            body: body,
            prefer: 'return=representation',
            fallback: 'Freshline could not update the salon offer.',
          );
    if (rows.isEmpty) {
      throw StateError('Freshline could not save the salon offer.');
    }
    return _promoCouponFromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  @override
  Future<void> setSalonEmployeeSalaryReceived({
    required AppUser actor,
    required String employeeId,
    required bool isReceived,
  }) async {
    if (actor.role != AppRole.salonOwner) {
      throw StateError('Only salon owners can update salary status.');
    }
    final _ResolvedSalonWorkspace resolved = await _resolveSalonWorkspace(
      actor,
    );
    final List<Employee> employees = await _loadSalonEmployeesInternal(
      salonId: resolved.salon.id,
      includeInactive: true,
    );
    final Employee employee = employees.firstWhere(
      (Employee item) => item.id == employeeId,
      orElse: () => throw StateError(
        'Freshline could not find the employee salary details.',
      ),
    );
    final DateTime now = DateTime.now().toUtc();
    final DateTime salaryMonth = DateTime.utc(now.year, now.month, 1);
    final String salaryMonthKey =
        '${salaryMonth.year.toString().padLeft(4, '0')}-${salaryMonth.month.toString().padLeft(2, '0')}-${salaryMonth.day.toString().padLeft(2, '0')}';
    await _patchRows(
      '/rest/v1/salon_employees?id=eq.$employeeId',
      body: <String, dynamic>{
        'salary_paid_for_month': isReceived
            ? salaryMonth.toIso8601String()
            : null,
        'salary_last_paid_at': isReceived ? now.toIso8601String() : null,
        'updated_at': now.toIso8601String(),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the salary status.',
    );
    try {
      await _deleteRows(
        '/rest/v1/employee_salary_payments?employee_id=eq.$employeeId&salary_month=eq.$salaryMonthKey',
        fallback: 'Freshline could not update the salary confirmation.',
      );
      if (isReceived) {
        await _postRows(
          '/rest/v1/employee_salary_payments?on_conflict=employee_id,salary_month',
          body: <Map<String, dynamic>>[
            <String, dynamic>{
              'salon_id': resolved.salon.id,
              'employee_id': employeeId,
              'confirmed_by': _requireProfileId(actor),
              'amount_bhd': employee.monthlySalary,
              'salary_month': salaryMonthKey,
              'confirmed_at': now.toIso8601String(),
            },
          ],
          prefer: 'resolution=merge-duplicates,return=minimal',
          fallback: 'Freshline could not confirm the employee salary.',
        );
      }
    } catch (error) {
      if (!_isMissingEmployeeSalaryPaymentsSchema(error)) {
        rethrow;
      }
    }
  }

  @override
  Future<AdminSnapshot> loadAdminSnapshot() async {
    final List<List<dynamic>>
    results = await Future.wait<List<dynamic>>(<Future<List<dynamic>>>[
      _getRows(
        '/rest/v1/profiles?select=id,full_name,username,email,phone,city,avatar_url,role,is_active,is_super_admin,created_at,updated_at,last_login_at&order=created_at.desc',
      ),
      _getRows('/rest/v1/salon_applications?select=*&order=created_at.desc'),
      _getRows('/rest/v1/loyalty_wallets?select=customer_id,points_balance'),
      _getRows(
        '/rest/v1/salon_bookings?select=customer_id,total_amount,payment_status',
      ),
      _getRows(
        '/rest/v1/product_orders?select=customer_id,total_amount,payment_status',
      ),
      _getRows(
        '/rest/v1/salons?select=id,owner_id,name,city,image_url,phone,description,address,price_tier,supports_home_service,rating,reviews_count,is_active,subscription_cycle,subscription_amount_bhd,subscription_paid_until,subscription_auto_renew&order=name.asc',
      ),
      _getRows(
        '/rest/v1/payment_transactions?select=amount,source_table,payment_status',
      ),
      _getRows(
        '/rest/v1/promo_coupons?select=*&salon_id=is.null&order=updated_at.desc,created_at.desc',
      ),
      _getRows(
        '/rest/v1/customer_subscriptions?select=customer_id,plan_id,starts_at,ends_at,auto_renew,is_active,created_at&is_active=eq.true&order=created_at.desc',
      ),
      _getRows(
        '/rest/v1/products?select=*&order=is_active.desc,created_at.asc',
      ),
      () async {
        try {
          return await _getRows(
            '/rest/v1/admin_audit_logs?select=id,admin_id,action_type,target_table,target_id,action_summary,created_at&order=created_at.desc&limit=200',
          );
        } catch (_) {
          return <dynamic>[];
        }
      }(),
    ]);

    final List<dynamic> profilesRows = results[0];
    final List<dynamic> requestRows = results[1];
    final List<dynamic> walletRows = results[2];
    final List<dynamic> bookingRows = results[3];
    final List<dynamic> productOrderRows = results[4];
    final List<dynamic> salonRows = results[5];
    final List<dynamic> paymentRows = results[6];
    final List<dynamic> couponRows = results[7];
    final List<dynamic> customerSubscriptionRows = results[8];
    final List<dynamic> adminProductRows = results[9];
    final List<dynamic> activityLogRows = results[10];

    final List<Map<String, dynamic>> profileMaps = _toRowMaps(profilesRows);
    final List<Map<String, dynamic>> requestMaps = _toRowMaps(requestRows);
    final List<Map<String, dynamic>> walletMaps = _toRowMaps(walletRows);
    final List<Map<String, dynamic>> bookingMaps = _toRowMaps(bookingRows);
    final List<Map<String, dynamic>> orderMaps = _toRowMaps(productOrderRows);
    final List<Map<String, dynamic>> salonMaps = _toRowMaps(salonRows);
    final List<Map<String, dynamic>> paymentMaps = _toRowMaps(paymentRows);
    final List<Map<String, dynamic>> couponMaps = _toRowMaps(couponRows);
    final List<Map<String, dynamic>> customerSubscriptionMaps = _toRowMaps(
      customerSubscriptionRows,
    );
    final List<Map<String, dynamic>> adminProductMaps = _toRowMaps(
      adminProductRows,
    );
    final List<Map<String, dynamic>> activityLogMaps = _toRowMaps(
      activityLogRows,
    );

    final Map<String, Map<String, dynamic>> profilesById = profileMaps
        .fold<Map<String, Map<String, dynamic>>>(
          <String, Map<String, dynamic>>{},
          (Map<String, Map<String, dynamic>> acc, Map<String, dynamic> row) {
            acc[_readString(row['id'])] = row;
            return acc;
          },
        );
    final Map<String, int> pointsByCustomerId = walletMaps
        .fold<Map<String, int>>(<String, int>{}, (
          Map<String, int> acc,
          Map<String, dynamic> row,
        ) {
          acc[_readString(row['customer_id'])] = _readInt(
            row['points_balance'],
          );
          return acc;
        });

    final List<ManagedUserRecord> users = profileMaps
        .map((Map<String, dynamic> row) {
          final String userId = _readString(row['id']);
          final double paidBookings = _sumPaidTotalsForUser(
            rows: bookingMaps,
            userId: userId,
          );
          final double paidOrders = _sumPaidTotalsForUser(
            rows: orderMaps,
            userId: userId,
          );

          return ManagedUserRecord(
            id: userId,
            name: _readString(
              row['full_name'] ?? row['username'],
              fallback: 'Freshline User',
            ),
            email: _readString(row['email']),
            phone: _readString(row['phone']),
            city: _readString(row['city'], fallback: 'Manama'),
            avatarUrl: normalizeProfileImageUrl(row['avatar_url']),
            role: appRoleFromValue(
              _readString(row['role'], fallback: AppRole.customer.value),
            ),
            isActive: _readBool(row['is_active'], fallback: true),
            bookingsCount: bookingMaps
                .where(
                  (Map<String, dynamic> booking) =>
                      _readString(booking['customer_id']) == userId,
                )
                .length,
            productOrdersCount: orderMaps
                .where(
                  (Map<String, dynamic> order) =>
                      _readString(order['customer_id']) == userId,
                )
                .length,
            totalSpent: paidBookings + paidOrders,
            loyaltyPoints: pointsByCustomerId[userId] ?? 0,
            createdAt: _readDateTime(row['created_at']),
            lastLoginAt: _readDateTime(row['last_login_at']),
          );
        })
        .toList(growable: false);
    final Map<String, ManagedUserRecord> usersById = users
        .fold<Map<String, ManagedUserRecord>>(<String, ManagedUserRecord>{}, (
          Map<String, ManagedUserRecord> map,
          ManagedUserRecord user,
        ) {
          map[user.id] = user;
          return map;
        });
    final List<AdminTeamMember> admins =
        profileMaps
            .where(
              (Map<String, dynamic> row) =>
                  appRoleFromValue(
                    _readString(row['role'], fallback: AppRole.customer.value),
                  ) ==
                  AppRole.admin,
            )
            .map(_adminFromProfileRow)
            .toList(growable: false)
          ..sort((AdminTeamMember a, AdminTeamMember b) {
            if (a.isOwner != b.isOwner) {
              return a.isOwner ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    final Set<String> seenCustomerSubscriptionIds = <String>{};
    final List<AdminCustomerSubscriptionRecord> customerSubscriptions =
        customerSubscriptionMaps
            .where((Map<String, dynamic> row) {
              final String customerId = _readString(row['customer_id']);
              if (customerId.isEmpty ||
                  seenCustomerSubscriptionIds.contains(customerId)) {
                return false;
              }
              seenCustomerSubscriptionIds.add(customerId);
              return true;
            })
            .map((Map<String, dynamic> row) {
              final String customerId = _readString(row['customer_id']);
              final ManagedUserRecord? user = usersById[customerId];
              final SubscriptionPlan? plan = subscriptionPlanById(
                _readString(row['plan_id']),
              );
              if (user == null || plan == null) {
                return null;
              }
              return AdminCustomerSubscriptionRecord(
                user: user,
                subscription: CustomerSubscriptionStatus(
                  plan: plan,
                  startsAt: _readDateTime(row['starts_at']),
                  endsAt: _readDateTime(row['ends_at']),
                  autoRenew: _readBool(row['auto_renew'], fallback: true),
                ),
              );
            })
            .whereType<AdminCustomerSubscriptionRecord>()
            .toList(growable: false)
          ..sort((
            AdminCustomerSubscriptionRecord a,
            AdminCustomerSubscriptionRecord b,
          ) {
            return a.user.name.toLowerCase().compareTo(
              b.user.name.toLowerCase(),
            );
          });
    final List<AdminSalonRecord> adminSalons =
        salonMaps
            .map((Map<String, dynamic> row) {
              final String ownerId = _readString(row['owner_id']);
              final Map<String, dynamic>? owner = profilesById[ownerId];
              final bool hasSubscriptionData =
                  _readString(row['subscription_cycle']).isNotEmpty ||
                  _readNullableDouble(row['subscription_amount_bhd']) != null ||
                  _readString(row['subscription_paid_until']).isNotEmpty;
              return AdminSalonRecord(
                salon: Salon.fromSupabase(
                  row,
                  fallbackImagePath: currentDefaultSalonImageUrl(),
                ),
                ownerName: _readString(
                  owner?['full_name'] ?? owner?['username'],
                  fallback: 'Salon Owner',
                ),
                ownerEmail: _readString(owner?['email']),
                ownerPhone: _readString(owner?['phone'] ?? row['phone']),
                ownerAvatarUrl: normalizeProfileImageUrl(owner?['avatar_url']),
                isActive: _readBool(row['is_active'], fallback: true),
                subscriptionStatus: hasSubscriptionData
                    ? _salonSubscriptionStatusFromJson(row)
                    : null,
              );
            })
            .toList(growable: false)
          ..sort((AdminSalonRecord a, AdminSalonRecord b) {
            return a.salon.name.toLowerCase().compareTo(
              b.salon.name.toLowerCase(),
            );
          });

    final List<AdminSalonRequestRecord> requests = requestMaps
        .map((Map<String, dynamic> row) {
          final String ownerId = _readString(row['owner_id']);
          final Map<String, dynamic>? owner = profilesById[ownerId];
          final String reviewedById = _readString(row['reviewed_by']);
          final Map<String, dynamic>? reviewer = profilesById[reviewedById];
          return AdminSalonRequestRecord(
            request: _requestFromJson(row),
            ownerName: _readString(
              owner?['full_name'] ?? owner?['username'],
              fallback: 'Salon Owner',
            ),
            ownerEmail: _readString(owner?['email'] ?? row['business_email']),
            ownerPhone: _readString(owner?['phone']),
            ownerAvatarUrl: normalizeProfileImageUrl(owner?['avatar_url']),
            reviewedByName: _nullableString(
              reviewer?['full_name'] ?? reviewer?['username'],
            ),
            reviewedByEmail: _nullableString(reviewer?['email']),
            reviewedAt: _readDateTime(row['reviewed_at']),
          );
        })
        .toList(growable: false);
    final int pendingRequestCount = requests
        .where((AdminSalonRequestRecord record) => record.request.isEditable)
        .length;

    final double customerSubscriptionRevenue = _sumPaidTransactionsBySource(
      paymentRows: paymentMaps,
      sourceTable: 'customer_subscriptions',
    );
    double salonSubscriptionRevenue = _sumPaidTransactionsBySource(
      paymentRows: paymentMaps,
      sourceTable: 'salon_subscriptions',
    );
    if (salonSubscriptionRevenue == 0) {
      salonSubscriptionRevenue = salonMaps.fold<double>(0, (
        double sum,
        Map<String, dynamic> row,
      ) {
        if (_readString(row['subscription_paid_until']).isEmpty) {
          return sum;
        }
        return sum + _salonSubscriptionStatusFromJson(row).amount;
      });
    }

    final double paidOrdersRevenue = _sumPaidTotals(orderMaps);
    final double paidBookingsRevenue = _sumPaidTotals(bookingMaps);
    final List<PromoCouponRecord> coupons = couponMaps
        .map(_promoCouponFromJson)
        .toList(growable: false);
    final List<Product> adminProducts =
        adminProductMaps
            .map(
              (Map<String, dynamic> row) => Product.fromSupabase(
                row,
                fallbackImagePath: currentDefaultProductImageUrl(),
              ),
            )
            .toList(growable: false)
          ..sort((Product a, Product b) {
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    final List<AdminActivityLogRecord> activityLogs =
        activityLogMaps
            .map((Map<String, dynamic> row) {
              final String actorId = _readString(row['admin_id']);
              final Map<String, dynamic>? actorRow = profilesById[actorId];
              return AdminActivityLogRecord(
                id: _readString(row['id']),
                actorId: actorId,
                actorName: _readString(
                  actorRow?['full_name'] ?? actorRow?['username'],
                  fallback: actorId.isEmpty ? 'Freshline' : 'Unknown User',
                ),
                actorEmail: _readString(actorRow?['email']),
                actorRole: actorRow == null
                    ? AppRole.customer
                    : appRoleFromValue(
                        _readString(
                          actorRow['role'],
                          fallback: AppRole.customer.value,
                        ),
                      ),
                actionType: _readString(
                  row['action_type'],
                  fallback: 'activity_logged',
                ),
                summary: _readString(
                  row['action_summary'],
                  fallback: 'Activity logged.',
                ),
                createdAt:
                    _readDateTime(row['created_at']) ??
                    DateTime.fromMillisecondsSinceEpoch(0),
                targetTable: _nullableString(row['target_table']),
                targetId: _nullableString(row['target_id']),
              );
            })
            .toList(growable: false)
          ..sort(
            (AdminActivityLogRecord a, AdminActivityLogRecord b) =>
                b.createdAt.compareTo(a.createdAt),
          );
    final int salonSubscriptionCount = adminSalons
        .where((AdminSalonRecord salon) => salon.subscriptionStatus != null)
        .length;

    return AdminSnapshot(
      metrics: AdminDashboardMetrics(
        customerSubscriptionRevenue: customerSubscriptionRevenue,
        salonSubscriptionRevenue: salonSubscriptionRevenue,
        bookingRevenue: paidBookingsRevenue,
        productRevenue: paidOrdersRevenue,
        totalRevenue:
            customerSubscriptionRevenue +
            salonSubscriptionRevenue +
            paidOrdersRevenue +
            paidBookingsRevenue,
        customerCount: users
            .where((ManagedUserRecord user) => user.role == AppRole.customer)
            .length,
        salonCount: adminSalons.length,
        requestCount: pendingRequestCount,
        customerSubscriptionCount: customerSubscriptions.length,
        salonSubscriptionCount: salonSubscriptionCount,
        productCount: adminProducts.length,
        productOrderCount: orderMaps.length,
      ),
      users: users,
      salons:
          salonMaps
              .map(
                (Map<String, dynamic> row) => Salon.fromSupabase(
                  row,
                  fallbackImagePath: currentDefaultSalonImageUrl(),
                ),
              )
              .toList(growable: false)
            ..sort(
              (Salon a, Salon b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ),
      adminSalons: adminSalons,
      requests: requests,
      coupons: coupons,
      admins: admins,
      customerSubscriptions: customerSubscriptions,
      adminProducts: adminProducts,
      activityLogs: activityLogs,
    );
  }

  @override
  Future<AdminTeamMember> saveAdminAccount({
    required AppUser actor,
    String? adminId,
    required String name,
    required String email,
    required String phone,
    required String city,
    String? password,
    String? avatarPath,
  }) async {
    if (actor.role != AppRole.admin || !actor.isAdminOwner) {
      throw StateError('Only the admin owner can manage admin accounts.');
    }

    final String normalizedAdminId = _readString(adminId);
    final bool isCreating = normalizedAdminId.isEmpty;

    final String normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty ||
        (!normalizedEmail.contains('@') &&
            normalizedEmail != adminOwnerEmail)) {
      throw StateError('Enter a valid admin email.');
    }
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(
      phone,
      fieldLabel: 'Admin phone number',
    );
    final String normalizedCity = normalizeBahrainLocation(city);
    final String resolvedAvatarPath = _readString(
      avatarPath,
      fallback: currentDefaultProfileImageUrl(),
    );
    final String resolvedPassword = password?.trim() ?? '';

    if (isCreating) {
      if (resolvedPassword.isEmpty) {
        throw StateError('Enter a password for the new admin.');
      }
      final Map<String, dynamic>? existingProfile = await _fetchProfileByEmail(
        normalizedEmail,
      );
      if (existingProfile != null) {
        throw StateError('This email is already used by another account.');
      }
      final List<dynamic> rows = await _postRows(
        '/rest/v1/profiles',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'role': AppRole.admin.value,
            'full_name': name.trim(),
            'username': _safeKey(name),
            'email': normalizedEmail,
            'password_hash': hashProfilePassword(resolvedPassword),
            'phone': normalizedPhone,
            'city': normalizedCity,
            'avatar_url': canonicalProfileImageForWrite(resolvedAvatarPath),
            'is_active': true,
            'is_super_admin': false,
          },
        ],
        prefer: 'return=representation',
        fallback: 'Freshline could not create the admin account.',
      );
      if (rows.isEmpty) {
        throw StateError('Freshline could not create the admin account.');
      }
      final Map<String, dynamic> createdRow = Map<String, dynamic>.from(
        rows.first as Map,
      );
      final AdminTeamMember createdAdmin = _adminFromProfileRow(createdRow);
      await _recordActivityLogSafely(
        actor: actor,
        actionType: 'admin_created',
        targetTable: 'profiles',
        targetId: createdAdmin.id,
        actionSummary: '${actor.name} created admin ${createdAdmin.name}.',
      );
      return createdAdmin;
    }

    final Map<String, dynamic>? existingProfile = await _fetchProfileById(
      normalizedAdminId,
    );
    if (existingProfile == null ||
        appRoleFromValue(
              _readString(
                existingProfile['role'],
                fallback: AppRole.customer.value,
              ),
            ) !=
            AppRole.admin) {
      throw StateError('Freshline could not find this admin.');
    }
    if (_isAdminOwnerEmail(_readString(existingProfile['email'])) &&
        normalizedEmail != adminOwnerEmail) {
      throw StateError('The admin owner email must stay as admin.com.');
    }

    final Map<String, dynamic>? emailOwner = await _fetchProfileByEmail(
      normalizedEmail,
    );
    if (emailOwner != null &&
        _readString(emailOwner['id']) != normalizedAdminId) {
      throw StateError('This email is already used by another account.');
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'role': AppRole.admin.value,
      'full_name': name.trim(),
      'username': _safeKey(name),
      'email': normalizedEmail,
      'phone': normalizedPhone,
      'city': normalizedCity,
      'avatar_url': canonicalProfileImageForWrite(resolvedAvatarPath),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (resolvedPassword.isNotEmpty) {
      body['password_hash'] = hashProfilePassword(resolvedPassword);
    }

    final List<dynamic> rows = await _patchRows(
      '/rest/v1/profiles?id=eq.$normalizedAdminId',
      body: body,
      prefer: 'return=representation',
      fallback: 'Freshline could not update the admin account.',
    );
    if (rows.isEmpty) {
      throw StateError('Freshline could not update the admin account.');
    }
    final Map<String, dynamic> updatedRow = Map<String, dynamic>.from(
      rows.first as Map,
    );
    final AdminTeamMember updatedAdmin = _adminFromProfileRow(updatedRow);
    await _recordActivityLogSafely(
      actor: actor,
      actionType: 'admin_updated',
      targetTable: 'profiles',
      targetId: updatedAdmin.id,
      actionSummary: '${actor.name} updated admin ${updatedAdmin.name}.',
    );
    return updatedAdmin;
  }

  @override
  Future<void> setAdminAccountActive({
    required AppUser actor,
    required String adminId,
    required bool isActive,
  }) async {
    if (actor.role != AppRole.admin || !actor.isAdminOwner) {
      throw StateError('Only the admin owner can manage admin accounts.');
    }
    final Map<String, dynamic>? existingProfile = await _fetchProfileById(
      adminId,
    );
    if (existingProfile == null) {
      return;
    }
    if (_isAdminOwnerEmail(_readString(existingProfile['email'])) &&
        !isActive) {
      throw StateError('The admin owner cannot be disabled.');
    }
    await _patchRows(
      '/rest/v1/profiles?id=eq.$adminId',
      body: <String, dynamic>{
        'is_active': isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the admin status.',
    );
    await _recordActivityLogSafely(
      actor: actor,
      actionType: isActive ? 'admin_enabled' : 'admin_disabled',
      targetTable: 'profiles',
      targetId: adminId,
      actionSummary:
          '${actor.name} ${isActive ? 'enabled' : 'disabled'} admin ${_readString(existingProfile['full_name'] ?? existingProfile['username'], fallback: 'Admin')}.',
    );
  }

  @override
  Future<PromoCouponRecord> savePromoCoupon({
    required PromoCouponRecord coupon,
  }) async {
    final String normalizedDescription = (coupon.description ?? '').trim();
    final Map<String, dynamic> body = <String, dynamic>{
      'code': coupon.normalizedCode,
      'salon_id': null,
      'description': normalizedDescription.isEmpty
          ? null
          : normalizedDescription,
      'discount_percent': coupon.discountPercent,
      'applicable_plan_id': coupon.appliesToAllPlans
          ? null
          : coupon.targetPlanId?.trim().toLowerCase(),
      'min_order_amount_bhd': coupon.minOrderAmountBhd,
      'max_discount_amount': coupon.maxDiscountBhd,
      'is_active': coupon.isActive,
      'starts_at': coupon.startsAt?.toUtc().toIso8601String(),
      'ends_at': coupon.endsAt?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    bool removeUnsupportedCouponFields(String message) {
      bool removedAny = false;
      for (final String key in <String>[
        'applicable_plan_id',
        'min_order_amount_bhd',
        'max_discount_amount',
        'starts_at',
        'ends_at',
      ]) {
        if (message.contains(key) && body.containsKey(key)) {
          body.remove(key);
          removedAny = true;
        }
      }
      return removedAny;
    }

    Future<List<dynamic>> submitSave() {
      if ((coupon.id ?? '').trim().isNotEmpty) {
        return _patchRows(
          '/rest/v1/promo_coupons?id=eq.${coupon.id}',
          body: body,
          prefer: 'return=representation',
          fallback: 'Freshline could not save the coupon.',
        );
      }
      return _postRows(
        '/rest/v1/promo_coupons?on_conflict=code',
        body: <Map<String, dynamic>>[body],
        prefer: 'resolution=merge-duplicates,return=representation',
        fallback: 'Freshline could not create the coupon.',
      );
    }

    List<dynamic> rows;
    while (true) {
      try {
        rows = await submitSave();
        break;
      } catch (error) {
        final String message = error.toString().toLowerCase();
        if (!removeUnsupportedCouponFields(message)) {
          rethrow;
        }
      }
    }

    if (rows.isEmpty) {
      throw StateError('Freshline could not save the coupon.');
    }

    return _promoCouponFromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  @override
  Future<void> updateManagedUser({
    required AppUser actor,
    required ManagedUserRecord user,
    required String name,
    required String email,
    required String phone,
    required String city,
    required AppRole role,
  }) async {
    if (user.role == AppRole.admin && !actor.isAdminOwner) {
      throw StateError('Only the admin owner can manage admin accounts.');
    }
    final bool isPromotingToAdmin =
        user.role != AppRole.admin && role == AppRole.admin;
    if (isPromotingToAdmin && !actor.isAdminOwner) {
      throw StateError('Only the admin owner can add a new admin.');
    }
    if (user.role == AppRole.admin && role != AppRole.admin) {
      final Map<String, dynamic>? existingProfile = await _fetchProfileById(
        user.id,
      );
      if (_isAdminOwnerEmail(_readString(existingProfile?['email']))) {
        throw StateError('The admin owner role cannot be changed.');
      }
    }
    if (user.role == AppRole.admin) {
      final Map<String, dynamic>? existingProfile = await _fetchProfileById(
        user.id,
      );
      if (_isAdminOwnerEmail(_readString(existingProfile?['email'])) &&
          email.trim().toLowerCase() != adminOwnerEmail) {
        throw StateError('The admin owner email must stay as admin.com.');
      }
    }
    final String trimmedName = name.trim();
    final String normalizedEmail = email.trim().toLowerCase();
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(phone);
    final String normalizedCity = normalizeBahrainLocation(city);
    await _patchRows(
      '/rest/v1/profiles?id=eq.${user.id}',
      body: <String, dynamic>{
        'full_name': trimmedName,
        'username': _safeKey(name),
        'email': normalizedEmail,
        'phone': normalizedPhone,
        'city': normalizedCity,
        'role': role.value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the user.',
    );
    await _recordActivityLogSafely(
      actor: actor,
      actionType: 'user_updated',
      targetTable: 'profiles',
      targetId: user.id,
      actionSummary:
          '${actor.name} updated ${role.label.toLowerCase()} $trimmedName.',
    );
  }

  @override
  Future<void> setUserActive({
    required AppUser actor,
    required String userId,
    required bool isActive,
  }) async {
    final Map<String, dynamic>? existingProfile = await _fetchProfileById(
      userId,
    );
    if (_isAdminOwnerEmail(_readString(existingProfile?['email'])) &&
        !isActive) {
      throw StateError('The admin owner cannot be disabled.');
    }
    await _patchRows(
      '/rest/v1/profiles?id=eq.$userId',
      body: <String, dynamic>{
        'is_active': isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the user status.',
    );
    await _recordActivityLogSafely(
      actor: actor,
      actionType: isActive ? 'user_enabled' : 'user_disabled',
      targetTable: 'profiles',
      targetId: userId,
      actionSummary:
          '${actor.name} ${isActive ? 'enabled' : 'disabled'} ${appRoleFromValue(_readString(existingProfile?['role'], fallback: AppRole.customer.value)).label.toLowerCase()} ${_readString(existingProfile?['full_name'] ?? existingProfile?['username'], fallback: 'user')}.',
    );
  }

  @override
  Future<void> sendAdminNotification({
    required AppUser actor,
    required String title,
    required String body,
    required String audience,
    String? targetProfileId,
    String? targetSalonId,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Only admins can send notifications.');
    }

    final String normalizedTitle = title.trim();
    final String normalizedBody = body.trim();
    final String normalizedAudience = audience.trim();
    final String resolvedTargetProfileId = _readString(targetProfileId);
    final String resolvedTargetSalonId = _readString(targetSalonId);

    if (normalizedTitle.isEmpty) {
      throw StateError('Enter a notification title.');
    }
    if (normalizedBody.isEmpty) {
      throw StateError('Enter a notification message.');
    }
    if (normalizedAudience == 'single_user' &&
        resolvedTargetProfileId.isEmpty) {
      throw StateError('Choose the user who should receive it.');
    }
    if (normalizedAudience == 'single_salon' && resolvedTargetSalonId.isEmpty) {
      throw StateError('Choose the salon that should receive it.');
    }

    await _insertNotification(
      title: normalizedTitle,
      body: normalizedBody,
      titleAr: _containsArabicText(normalizedTitle) ? normalizedTitle : null,
      bodyAr: _containsArabicText(normalizedBody) ? normalizedBody : null,
      audience: normalizedAudience,
      targetProfileId: resolvedTargetProfileId.isEmpty
          ? null
          : resolvedTargetProfileId,
      targetSalonId: resolvedTargetSalonId.isEmpty
          ? null
          : resolvedTargetSalonId,
      createdByProfileId: _requireProfileId(actor),
    );
    await _recordActivityLogSafely(
      actor: actor,
      actionType: 'admin_notification_sent',
      targetTable: 'notifications',
      targetId: resolvedTargetProfileId.isNotEmpty
          ? resolvedTargetProfileId
          : resolvedTargetSalonId,
      actionSummary:
          '${actor.name} sent a ${normalizedAudience.replaceAll('_', ' ')} notification.',
    );
  }

  @override
  Future<void> syncDevicePushToken({
    required AppUser user,
    required String token,
  }) async {
    final String profileId = _requireProfileId(user);
    final String normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    await _postRows(
      '/rest/v1/device_push_tokens?on_conflict=fcm_token',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'profile_id': profileId,
          'fcm_token': normalizedToken,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
      prefer: 'resolution=merge-duplicates,return=minimal',
      fallback: 'Freshline could not sync the device push token.',
    );
  }

  @override
  Future<void> removeDevicePushToken({
    required AppUser user,
    required String token,
  }) async {
    final String profileId = _requireProfileId(user);
    final String normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    await _deleteRows(
      '/rest/v1/device_push_tokens?profile_id=eq.$profileId&fcm_token=eq.${Uri.encodeQueryComponent(normalizedToken)}',
      fallback: 'Freshline could not remove the device push token.',
    );
  }

  @override
  Future<void> reviewSalonRequest({
    required AdminSalonRequestRecord record,
    required SalonRequestStatus status,
    required String adminNote,
    required AppUser admin,
  }) async {
    final String adminId = _requireProfileId(admin);
    final List<dynamic> rows = await _patchRows(
      '/rest/v1/salon_applications?id=eq.${record.request.id}',
      body: <String, dynamic>{
        'status': status.value,
        'admin_note': adminNote.trim(),
        'reviewed_by': adminId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=representation',
      fallback: 'Freshline could not update the request status.',
    );
    if (rows.isEmpty) {
      throw StateError('Freshline could not update the request status.');
    }

    final Map<String, dynamic> updatedRow = Map<String, dynamic>.from(
      rows.first as Map,
    );
    if (status == SalonRequestStatus.approved) {
      await _ensureSalonFromRequest(updatedRow);
    }

    final String ownerId = _readString(updatedRow['owner_id']);
    await _insertNotification(
      title: _requestNotificationTitle(status),
      body: _requestNotificationBody(status, updatedRow),
      titleAr: switch (status) {
        SalonRequestStatus.approved => 'تمت الموافقة على الطلب',
        SalonRequestStatus.rejected => 'تم رفض الطلب',
        SalonRequestStatus.needsInfo => 'مطلوب معلومات إضافية',
        SalonRequestStatus.pending => 'تم تحديث الطلب',
      },
      bodyAr: switch (status) {
        SalonRequestStatus.approved =>
          'تمت الموافقة على طلب صالون ${_readString(updatedRow['salon_name'], fallback: 'فريش لاين')} ويمكنك الآن متابعة العمل على الصالون.',
        SalonRequestStatus.rejected =>
          'تم رفض طلب صالون ${_readString(updatedRow['salon_name'], fallback: 'فريش لاين')}. راجع ملاحظات الإدارة وأعد التقديم.',
        SalonRequestStatus.needsInfo =>
          'طلب صالون ${_readString(updatedRow['salon_name'], fallback: 'فريش لاين')} يحتاج إلى معلومات إضافية. راجع الملاحظات وحدّث البيانات.',
        SalonRequestStatus.pending =>
          'تم تحديث حالة طلب صالون ${_readString(updatedRow['salon_name'], fallback: 'فريش لاين')}.',
      },
      audience: 'single_user',
      targetProfileId: ownerId.isEmpty ? null : ownerId,
    );
    await _recordActivityLogSafely(
      actor: admin,
      actionType: 'salon_request_${status.value}',
      targetTable: 'salon_applications',
      targetId: record.request.id,
      actionSummary:
          '${admin.name} marked salon request ${record.request.salonName} as ${status.label.toLowerCase()}.',
    );
  }

  @override
  void dispose() {
    _client.close();
  }

  Future<void> _assertSalonSlotAvailable({
    required String salonId,
    required String employeeKey,
    required DateTime scheduledAt,
  }) async {
    final String encodedAppointment = Uri.encodeQueryComponent(
      scheduledAt.toUtc().toIso8601String(),
    );
    final List<Map<String, dynamic>> rows = _toRowMaps(
      await _getRows(
        '/rest/v1/salon_bookings?select=employee_id,notes&salon_id=eq.$salonId&appointment_at=eq.$encodedAppointment&booking_status=in.(pending,confirmed)',
      ),
    );

    final bool isTaken = rows.any((Map<String, dynamic> row) {
      final Map<String, dynamic> metadata = _decodeOrderMetadata(row['notes']);
      final String storedEmployeeKey = _readString(
        metadata['employee_key'] ?? row['employee_id'],
      );
      return storedEmployeeKey == employeeKey;
    });
    if (isTaken) {
      throw StateError(
        'This time was just booked. Please choose another slot.',
      );
    }
  }

  Future<void> _recordPaymentTransaction({
    required String profileId,
    String? salonId,
    required String sourceTable,
    required String sourceId,
    required String gatewayName,
    required num amount,
    required String externalReference,
  }) async {
    await _postRows(
      '/rest/v1/payment_transactions',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'profile_id': profileId,
          'salon_id': salonId,
          'source_table': sourceTable,
          'source_id': sourceId,
          'gateway_name': gatewayName,
          'amount': amount,
          'currency_code': 'BHD',
          'payment_status': 'paid',
          'external_reference': externalReference,
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
      prefer: 'return=minimal',
      fallback: 'Freshline could not record the payment transaction.',
    );
  }

  Future<void> _recordActivityLogSafely({
    required AppUser actor,
    required String actionType,
    required String actionSummary,
    String? targetTable,
    String? targetId,
  }) async {
    final String actorId = _requireProfileId(actor);
    try {
      await _postRows(
        '/rest/v1/admin_audit_logs',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'admin_id': actorId,
            'action_type': actionType,
            'target_table': _nullableString(targetTable),
            'target_id': _nullableUuid(targetId),
            'action_summary': actionSummary,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
        prefer: 'return=minimal',
        fallback: 'Freshline could not record the activity log.',
      );
    } catch (_) {
      // Activity logging should not block the user flow.
    }
  }

  Future<void> _applyLoyaltyMutation({
    required String userId,
    required String sourceType,
    required String sourceId,
    required int gainedPoints,
    required int redeemedPoints,
    required String description,
  }) async {
    if (gainedPoints == 0 && redeemedPoints == 0) {
      return;
    }

    final List<Map<String, dynamic>> rows = _toRowMaps(
      await _getRows(
        '/rest/v1/loyalty_wallets?select=points_balance,lifetime_points&customer_id=eq.$userId&limit=1',
      ),
    );
    final int currentBalance = rows.isEmpty
        ? 0
        : _readInt(rows.first['points_balance']);
    final int currentLifetime = rows.isEmpty
        ? 0
        : _readInt(rows.first['lifetime_points']);
    final int nextBalance = math.max(
      0,
      currentBalance - redeemedPoints + gainedPoints,
    );
    final int nextLifetime = math.max(0, currentLifetime + gainedPoints);

    await _postRows(
      '/rest/v1/loyalty_wallets?on_conflict=customer_id',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'customer_id': userId,
          'points_balance': nextBalance,
          'lifetime_points': nextLifetime,
        },
      ],
      prefer: 'resolution=merge-duplicates,return=minimal',
      fallback: 'Freshline could not update the loyalty wallet.',
    );

    final List<Map<String, dynamic>> transactions = <Map<String, dynamic>>[];
    if (redeemedPoints > 0) {
      transactions.add(<String, dynamic>{
        'customer_id': userId,
        'source_type': sourceType,
        'source_id': sourceId,
        'points_delta': -redeemedPoints,
        'description': 'Redeemed on $description',
      });
    }
    if (gainedPoints > 0) {
      transactions.add(<String, dynamic>{
        'customer_id': userId,
        'source_type': sourceType,
        'source_id': sourceId,
        'points_delta': gainedPoints,
        'description': 'Earned from $description',
      });
    }
    if (transactions.isEmpty) {
      return;
    }

    await _postRows(
      '/rest/v1/loyalty_transactions',
      body: transactions,
      prefer: 'return=minimal',
      fallback: 'Freshline could not save the loyalty transaction.',
    );
  }

  Future<SavedCustomerAddress> _ensureCustomerAddress({
    required AppUser user,
    required String addressDetails,
    required DeliveryLocationSelection location,
  }) async {
    final String userId = _requireProfileId(user);
    final String normalizedAddress = addressDetails.trim();
    if (normalizedAddress.isEmpty) {
      throw StateError('Freshline could not save an empty address.');
    }

    final List<SavedCustomerAddress> existingAddresses =
        await loadSavedAddresses(user: user);
    final SavedCustomerAddress? existing = existingAddresses
        .where(
          (SavedCustomerAddress item) =>
              item.addressLine.trim().toLowerCase() ==
                  normalizedAddress.toLowerCase() &&
              _sameLocation(item.location, location),
        )
        .firstOrNull;

    await _patchRows(
      '/rest/v1/customer_addresses?customer_id=eq.$userId&is_default=eq.true',
      body: <String, dynamic>{'is_default': false},
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the address selection.',
    );

    if (existing != null) {
      final List<dynamic> rows = await _patchRows(
        '/rest/v1/customer_addresses?id=eq.${existing.id}',
        body: <String, dynamic>{
          'label': existing.label,
          'full_name': user.name,
          'phone': user.phone,
          'city': user.city,
          'address_line': normalizedAddress,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'is_default': true,
        },
        prefer: 'return=representation',
        fallback: 'Freshline could not save the address.',
      );
      if (rows.isEmpty) {
        throw StateError('Freshline could not save the address.');
      }
      await _syncProfileAddress(userId: userId, address: normalizedAddress);
      return _savedAddressFromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
    }

    final String label = existingAddresses.isEmpty
        ? 'Home'
        : 'Saved Address ${existingAddresses.length + 1}';
    final List<dynamic> rows = await _postRows(
      '/rest/v1/customer_addresses',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'customer_id': userId,
          'label': label,
          'full_name': user.name,
          'phone': user.phone,
          'city': user.city,
          'address_line': normalizedAddress,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'is_default': true,
        },
      ],
      prefer: 'return=representation',
      fallback: 'Freshline could not save the address.',
    );
    if (rows.isEmpty) {
      throw StateError('Freshline could not save the address.');
    }
    await _syncProfileAddress(userId: userId, address: normalizedAddress);
    return _savedAddressFromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<void> _syncProfileAddress({
    required String userId,
    required String address,
  }) async {
    try {
      await _patchRows(
        '/rest/v1/profiles?id=eq.$userId',
        body: <String, dynamic>{
          'address': address,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        prefer: 'return=minimal',
        fallback: 'Freshline could not update the profile address.',
      );
    } catch (_) {
      // Address sync is helpful but should not block the order flow.
    }
  }

  Future<void> _verifyManagedEmailOtp({
    required String email,
    required String purpose,
    required String code,
    required String profileId,
    required String fallback,
  }) async {
    final bool allowLocalFallback = _allowsLocalOtpFallbackForPurpose(purpose);
    if (allowLocalFallback &&
        _verifyLocalFallbackOtp(
          email: email,
          purpose: purpose,
          code: code,
          profileId: profileId,
          fallback: fallback,
        )) {
      return;
    }

    http.Response response = await _postVerifyManagedEmailOtpRequest(
      email: email,
      purpose: purpose,
      code: code,
      profileId: profileId,
      fallback: fallback,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = _readAuthError(response, fallback: fallback);
      if (_isMissingOtpFunctionError(
            message,
            functionName: 'verify_auth_email_otp',
          ) &&
          profileId.trim().isNotEmpty) {
        response = await _postVerifyManagedEmailOtpRequest(
          email: email,
          purpose: purpose,
          code: code,
          fallback: fallback,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = _readAuthError(response, fallback: fallback);
      if (_isMissingOtpFunctionError(
        message,
        functionName: 'verify_auth_email_otp',
      )) {
        response = await _postVerifyManagedEmailOtpEdgeRequest(
          email: email,
          purpose: purpose,
          code: code,
          profileId: profileId,
          fallback: fallback,
        );
        if (response.statusCode == 404) {
          response = await _postVerifyManagedEmailOtpEdgeRequest(
            email: email,
            purpose: purpose,
            code: code,
            fallback: fallback,
          );
        }
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = _readAuthError(response, fallback: fallback);
      if (_isMissingOtpFunctionError(
        message,
        functionName: 'verify_auth_email_otp',
      )) {
        throw StateError(
          _otpBackendSetupMessage(functionName: 'verify_auth_email_otp'),
        );
      }
      if (_shouldUseLocalOtpFallback(message, allowLocalFallback: allowLocalFallback)) {
        throw StateError(
          _otpBackendSetupMessage(functionName: 'verify_auth_email_otp'),
        );
      }
      if (_isMissingOtpEdgeFunctionError(message)) {
        throw StateError(
          _otpBackendSetupMessage(functionName: 'verify-auth-otp'),
        );
      }
      throw StateError(message);
    }

    final String body = response.body.trim();
    if (body.isEmpty) {
      throw StateError(fallback);
    }

    try {
      final dynamic decoded = jsonDecode(body);
      final bool isVerified = switch (decoded) {
        bool value => value,
        Map<String, dynamic> value => _readBool(value['verify_auth_email_otp']),
        Map value => _readBool(value['verify_auth_email_otp']),
        _ => false,
      };
      if (!isVerified) {
        throw StateError(fallback);
      }
    } catch (_) {
      throw StateError(fallback);
    }
  }

  bool _verifyLocalFallbackOtp({
    required String email,
    required String purpose,
    required String code,
    required String profileId,
    required String fallback,
  }) {
    final String otpKey = _authEmailOtpKey(
      email: email,
      purpose: purpose,
      profileId: profileId,
    );
    final String expectedCode = _localFallbackOtpCodesByKey[otpKey] ?? '';
    if (expectedCode.isEmpty) {
      return false;
    }
    if (expectedCode != code.trim()) {
      throw StateError(fallback);
    }
    _localFallbackOtpCodesByKey.remove(otpKey);
    return true;
  }

  Future<http.Response> _postVerifyManagedEmailOtpRequest({
    required String email,
    required String purpose,
    required String code,
    String? profileId,
    required String fallback,
  }) {
    final String normalizedProfileId = profileId?.trim() ?? '';
    return performFreshlineHttpRequest(
      () => _client.post(
        Uri.parse('$supabaseUrl/rest/v1/rpc/verify_auth_email_otp'),
        headers: <String, String>{
          ..._supabaseHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'p_email': email.trim().toLowerCase(),
          'p_purpose': purpose,
          'p_code': code.trim(),
          if (normalizedProfileId.isNotEmpty)
            'p_profile_id': normalizedProfileId,
        }),
      ),
      fallback: fallback,
    );
  }

  Future<http.Response> _postVerifyManagedEmailOtpEdgeRequest({
    required String email,
    required String purpose,
    required String code,
    String? profileId,
    required String fallback,
  }) {
    final String normalizedProfileId = profileId?.trim() ?? '';
    return performFreshlineHttpRequest(
      () => _client.post(
        Uri.parse('$supabaseUrl/functions/v1/verify-auth-otp'),
        headers: <String, String>{
          ..._supabaseHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'email': email.trim().toLowerCase(),
          'purpose': purpose,
          'code': code.trim(),
          if (normalizedProfileId.isNotEmpty) 'profileId': normalizedProfileId,
        }),
      ),
      fallback: fallback,
    );
  }

  Future<void> _markProfileEmailVerified({required String email}) async {
    final String timestamp = DateTime.now().toUtc().toIso8601String();
    await _patchRows(
      '/rest/v1/profiles?email=eq.${Uri.encodeQueryComponent(email.trim().toLowerCase())}',
      body: <String, dynamic>{
        'email_verified_at': timestamp,
        'updated_at': timestamp,
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the email verification state.',
    );
  }

  Future<Map<String, dynamic>?> _fetchProfileByEmail(String email) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final List<dynamic> rows = await _getRows(
      '/rest/v1/profiles?select=*&email=eq.${Uri.encodeQueryComponent(normalizedEmail)}&limit=1',
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<Map<String, dynamic>?> _fetchProfileById(String userId) async {
    final List<dynamic> rows = await _getRows(
      '/rest/v1/profiles?select=*&id=eq.$userId&limit=1',
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<String> _loadEmployeeProfileId(String employeeId) async {
    final String normalizedEmployeeId = employeeId.trim();
    if (normalizedEmployeeId.isEmpty) {
      return '';
    }

    final List<Map<String, dynamic>> rows = _toRowMaps(
      await _getRows(
        '/rest/v1/salon_employees?select=profile_id&id=eq.$normalizedEmployeeId&limit=1',
      ),
    );
    if (rows.isEmpty) {
      return '';
    }
    return _readString(rows.first['profile_id']);
  }

  Future<String> _loadSalonOwnerProfileId(String salonId) async {
    final String normalizedSalonId = salonId.trim();
    if (normalizedSalonId.isEmpty) {
      return '';
    }

    final List<Map<String, dynamic>> rows = _toRowMaps(
      await _getRows(
        '/rest/v1/salons?select=owner_id&id=eq.$normalizedSalonId&limit=1',
      ),
    );
    if (rows.isEmpty) {
      return '';
    }
    return _readString(rows.first['owner_id']);
  }

  Future<void> _touchLastLogin(String? userId) async {
    if (userId == null || userId.trim().isEmpty) {
      return;
    }

    try {
      await _patchRows(
        '/rest/v1/profiles?id=eq.$userId',
        body: <String, dynamic>{
          'last_login_at': DateTime.now().toUtc().toIso8601String(),
        },
        prefer: 'return=minimal',
        fallback: 'Freshline could not update the last login time.',
      );
    } catch (_) {
      // Ignore non-blocking last-login writes.
    }
  }

  Future<void> _insertNotification({
    required String title,
    required String body,
    required String audience,
    String? titleAr,
    String? bodyAr,
    String? targetProfileId,
    String? targetSalonId,
    String? createdByProfileId,
  }) async {
    await _postRows(
      '/rest/v1/notifications',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'title': title,
          'title_ar': _nullableString(titleAr),
          'body': body,
          'body_ar': _nullableString(bodyAr),
          'audience': audience,
          'target_profile_id': targetProfileId,
          'target_salon_id': targetSalonId,
          'created_by': createdByProfileId,
          'sent_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
      prefer: 'return=minimal',
      fallback: 'Freshline could not create the notification.',
    );
  }

  Future<void> _insertNotificationSafely({
    required String title,
    required String body,
    required String audience,
    String? titleAr,
    String? bodyAr,
    String? targetProfileId,
    String? targetSalonId,
    String? createdByProfileId,
  }) async {
    try {
      await _insertNotification(
        title: title,
        body: body,
        audience: audience,
        titleAr: titleAr,
        bodyAr: bodyAr,
        targetProfileId: targetProfileId,
        targetSalonId: targetSalonId,
        createdByProfileId: createdByProfileId,
      );
    } catch (_) {
      // Notifications should not block booking or order flows.
    }
  }

  Future<void> _insertWelcomeNotificationIfNeeded(AppUser user) async {
    final String userId = _requireProfileId(user);
    try {
      final List<dynamic> existing = await _getRows(
        '/rest/v1/notifications?select=id&audience=eq.single_user&target_profile_id=eq.$userId&title=eq.${Uri.encodeQueryComponent('Welcome to FreshLine')}&limit=1',
      );
      if (existing.isNotEmpty) {
        return;
      }
    } catch (_) {
      // If we cannot check, fall back to inserting once (non-blocking).
    }
    await _insertNotificationSafely(
      title: 'Welcome to FreshLine',
      titleAr: 'مرحباً بك في فريش لاين',
      body:
          'Thanks for signing up. Your account is ready now, and you can verify your email later from Account Details.',
      bodyAr:
          'شكراً لتسجيلك. أصبح حسابك جاهزاً الآن ويمكنك التحقق من بريدك لاحقاً من تفاصيل الحساب.',
      audience: 'single_user',
      targetProfileId: userId,
    );
  }

  Future<void> _ensureSalonFromRequest(Map<String, dynamic> requestRow) async {
    final String requestId = _readString(requestRow['id']);
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(
      _readString(requestRow['phone']),
      fieldLabel: 'Salon phone number',
    );
    final DateTime nextMonthlyRenewal = DateTime.now().add(
      const Duration(days: 30),
    );
    final List<dynamic> existingSalons = await _getRows(
      '/rest/v1/salons?select=id&application_id=eq.$requestId&limit=1',
    );
    final Map<String, dynamic> payload = <String, dynamic>{
      'owner_id': _readString(requestRow['owner_id']),
      'application_id': requestId,
      'slug': _safeKey(_readString(requestRow['salon_name'])),
      'name': _readString(requestRow['salon_name']),
      'description': 'Approved Freshline salon.',
      'city': _readString(requestRow['city'], fallback: 'Manama'),
      'address': _readString(requestRow['address']),
      'phone': normalizedPhone,
      'website_url': _readString(requestRow['website_url']),
      'location_url': _readString(requestRow['location_url']),
      'image_url': canonicalSalonImageForWrite(requestRow['salon_image_url']),
      'subscription_cycle': SubscriptionCycleOption.monthly.name,
      'subscription_amount_bhd': salonMonthlySubscriptionPrice,
      'subscription_paid_until':
          '${nextMonthlyRenewal.year.toString().padLeft(4, '0')}-${nextMonthlyRenewal.month.toString().padLeft(2, '0')}-${nextMonthlyRenewal.day.toString().padLeft(2, '0')}',
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existingSalons.isEmpty) {
      await _postRows(
        '/rest/v1/salons?on_conflict=slug',
        body: <Map<String, dynamic>>[payload],
        prefer: 'resolution=merge-duplicates,return=minimal',
        fallback: 'Freshline could not create the approved salon.',
      );
      return;
    }

    final String salonId = _readString(
      Map<String, dynamic>.from(existingSalons.first as Map)['id'],
    );
    await _patchRows(
      '/rest/v1/salons?id=eq.$salonId',
      body: payload,
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the approved salon.',
    );
  }

  Future<List<Employee>> _loadSalonEmployeesInternal({
    required String salonId,
    required bool includeInactive,
  }) async {
    final List<Map<String, dynamic>> rows = _toRowMaps(
      await _getRows(
        '/rest/v1/salon_employees?select=*&salon_id=eq.$salonId&order=is_active.desc,created_at.asc',
      ),
    );
    final List<Employee> employees = rows
        .map(
          (Map<String, dynamic> row) => Employee.fromSupabase(
            row,
            fallbackImagePath: currentDefaultProfileImageUrl(),
          ),
        )
        .toList(growable: false);
    if (includeInactive) {
      return employees;
    }
    return employees
        .where((Employee employee) => employee.isActive)
        .toList(growable: false);
  }

  Future<_SalonProductOrdersLoadResult> _loadSalonProductOrdersForWorkspace({
    required Salon salon,
    required List<Product> products,
    required bool useArabic,
  }) async {
    final List<Map<String, dynamic>> orderRows = _toRowMaps(
      await _getRows(
        '/rest/v1/product_orders?select=id,order_number,customer_id,payment_status,total_amount,notes,created_at&order=created_at.desc',
      ),
    );
    if (orderRows.isEmpty) {
      return const _SalonProductOrdersLoadResult(
        orders: <UserOrder>[],
        productRevenue: 0,
      );
    }

    final Set<String> productIds = products
        .map((Product product) => product.id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    final Set<String> matchedOrderIds = orderRows
        .where((Map<String, dynamic> row) {
          final Map<String, dynamic> metadata = _decodeOrderMetadata(
            row['notes'],
          );
          return _readString(metadata['salon_name']) == salon.name ||
              _readString(metadata['salon_name_ar']) ==
                  _readString(salon.nameAr, fallback: salon.name);
        })
        .map((Map<String, dynamic> row) => _readString(row['id']))
        .where((String id) => id.isNotEmpty)
        .toSet();

    if (productIds.isNotEmpty) {
      final List<Map<String, dynamic>> matchedItemRows = _toRowMaps(
        await _getRows(
          '/rest/v1/product_order_items?select=order_id&product_id=in.(${_inFilterValues(productIds.toList(growable: false))})',
        ),
      );
      matchedOrderIds.addAll(
        matchedItemRows
            .map((Map<String, dynamic> row) => _readString(row['order_id']))
            .where((String id) => id.isNotEmpty),
      );
    }

    if (matchedOrderIds.isEmpty) {
      return const _SalonProductOrdersLoadResult(
        orders: <UserOrder>[],
        productRevenue: 0,
      );
    }

    final List<Map<String, dynamic>> filteredOrderRows = orderRows
        .where(
          (Map<String, dynamic> row) =>
              matchedOrderIds.contains(_readString(row['id'])),
        )
        .toList(growable: false);
    final List<String> orderIds = filteredOrderRows
        .map((Map<String, dynamic> row) => _readString(row['id']))
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    final List<Map<String, dynamic>> itemRows = orderIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _toRowMaps(
            await _getRows(
              '/rest/v1/product_order_items?select=order_id,product_id,product_name,product_name_ar,quantity,unit_price,line_total&order_id=in.(${_inFilterValues(orderIds)})',
            ),
          );
    final List<String> customerIds = filteredOrderRows
        .map((Map<String, dynamic> row) => _readString(row['customer_id']))
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final Map<String, Map<String, dynamic>> customersById = customerIds.isEmpty
        ? const <String, Map<String, dynamic>>{}
        : _toRowMaps(
            await _getRows(
              '/rest/v1/profiles?select=id,full_name,username,phone&id=in.(${_inFilterValues(customerIds)})',
            ),
          ).fold<Map<String, Map<String, dynamic>>>(
            <String, Map<String, dynamic>>{},
            (Map<String, Map<String, dynamic>> map, Map<String, dynamic> row) {
              final String id = _readString(row['id']);
              if (id.isNotEmpty) {
                map[id] = row;
              }
              return map;
            },
          );

    final Map<String, List<RatedOrderProductItem>> productItemsByOrderId =
        <String, List<RatedOrderProductItem>>{};
    for (final Map<String, dynamic> row in itemRows) {
      final String orderId = _readString(row['order_id']);
      if (orderId.isEmpty) {
        continue;
      }
      productItemsByOrderId
          .putIfAbsent(orderId, () => <RatedOrderProductItem>[])
          .add(
            RatedOrderProductItem(
              productId: _readString(row['product_id']),
              productName: _localizedProductNameFromRow(
                row,
                useArabic: useArabic,
              ),
              productNameAr: _nullableString(row['product_name_ar']),
              quantity: _readInt(row['quantity'], fallback: 1),
              unitPrice: _readDouble(row['unit_price']),
            ),
          );
    }

    final List<UserOrder> orders = filteredOrderRows
        .map((Map<String, dynamic> row) {
          final Map<String, dynamic> metadata = _decodeOrderMetadata(
            row['notes'],
          );
          final String orderId = _readString(row['id']);
          final String customerId = _readString(row['customer_id']);
          final Map<String, dynamic>? customer = customersById[customerId];
          final String assignedEmployeeId = _readString(
            metadata['assigned_employee_id'] ?? metadata['employee_key'],
          );
          final String fallbackStatus = switch (_readString(
            row['payment_status'],
            fallback: 'pending',
          ).trim().toLowerCase()) {
            'paid' => useArabic ? 'قيد التجهيز' : 'Preparing',
            'failed' => useArabic ? 'فشل الدفع' : 'Failed',
            'refunded' => useArabic ? 'تم الاسترجاع' : 'Refunded',
            _ => useArabic ? 'بانتظار المعالجة' : 'Pending',
          };
          return UserOrder(
            id: orderId,
            type: UserOrderType.productOrder,
            invoiceNumber: _nullableString(row['order_number']),
            salonId: salon.id,
            employeeId: assignedEmployeeId,
            salonName: _localizedMetadataValue(
              metadata,
              key: 'salon_name',
              useArabic: useArabic,
              fallback: useArabic
                  ? _readString(salon.nameAr, fallback: salon.name)
                  : salon.name,
            ),
            serviceName: _productSummaryFromMetadata(
              metadata,
              useArabic: useArabic,
            ),
            employeeName: useArabic
                ? _readString(
                    metadata['assigned_employee_name_ar'] ??
                        metadata['employee_name_ar'] ??
                        metadata['assigned_employee_name'] ??
                        metadata['employee_name'],
                    fallback: assignedEmployeeId.isEmpty
                        ? 'متاح للفريق'
                        : 'موظف الصالون',
                  )
                : _readString(
                    metadata['assigned_employee_name'] ??
                        metadata['employee_name'],
                    fallback: assignedEmployeeId.isEmpty
                        ? 'Available for team'
                        : 'Salon employee',
                  ),
            customerName: _readString(
              customer?['full_name'] ?? customer?['username'],
              fallback: 'Freshline Customer',
            ),
            customerPhone: _nullableString(customer?['phone']),
            visitMode: _localizedMetadataValue(
              metadata,
              key: 'visit_mode',
              useArabic: useArabic,
              fallback: useArabic ? 'توصيل منزلي' : 'Home delivery',
            ),
            scheduledAt: (_readDateTime(row['created_at']) ?? DateTime.now())
                .toLocal(),
            total: _readDouble(row['total_amount']),
            statusLabel: _localizedMetadataValue(
              metadata,
              key: 'status_label',
              useArabic: useArabic,
              fallback: fallbackStatus,
            ),
            loyaltyPointsGained: _readInt(metadata['loyalty_points_gained']),
            address: _readString(metadata['delivery_address']),
            addressDetails: _readString(metadata['delivery_location_label']),
            cardLabel: _readString(metadata['card_label']),
            productItems:
                productItemsByOrderId[orderId] ??
                const <RatedOrderProductItem>[],
          );
        })
        .toList(growable: false);
    final double productRevenue = filteredOrderRows.fold<double>(0, (
      double sum,
      Map<String, dynamic> row,
    ) {
      return _readString(
                row['payment_status'],
                fallback: 'pending',
              ).trim().toLowerCase() ==
              'paid'
          ? sum + _readDouble(row['total_amount'])
          : sum;
    });

    return _SalonProductOrdersLoadResult(
      orders: orders,
      productRevenue: productRevenue,
    );
  }

  Future<List<EmployeeSalaryPayment>> _loadEmployeeSalaryPaymentsForSalon({
    required String salonId,
    required List<Employee> employees,
  }) async {
    final Map<String, String> employeeNamesById = employees
        .fold<Map<String, String>>(<String, String>{}, (
          Map<String, String> map,
          Employee employee,
        ) {
          map[employee.id] = employee.name;
          return map;
        });
    try {
      final List<Map<String, dynamic>> rows = _toRowMaps(
        await _getRows(
          '/rest/v1/employee_salary_payments?select=*&salon_id=eq.$salonId&order=confirmed_at.desc',
        ),
      );
      if (rows.isNotEmpty) {
        return rows
            .map(
              (Map<String, dynamic> row) => EmployeeSalaryPayment.fromSupabase(
                row,
                employeeName:
                    employeeNamesById[_readString(row['employee_id'])] ??
                    'Salon employee',
              ),
            )
            .toList(growable: false);
      }
    } catch (error) {
      if (!_isMissingEmployeeSalaryPaymentsSchema(error)) {
        rethrow;
      }
    }

    return employees
        .where(
          (Employee employee) =>
              employee.salaryLastPaidAt != null &&
              employee.salaryPaidForMonth != null,
        )
        .map(
          (Employee employee) => EmployeeSalaryPayment(
            id: 'salary-${employee.id}-${employee.salaryPaidForMonth!.millisecondsSinceEpoch}',
            employeeId: employee.id,
            employeeName: employee.name,
            salonId: salonId,
            amount: employee.monthlySalary,
            salaryMonth: employee.salaryPaidForMonth!,
            confirmedAt: employee.salaryLastPaidAt!,
          ),
        )
        .toList(growable: false)
      ..sort(
        (EmployeeSalaryPayment a, EmployeeSalaryPayment b) =>
            b.confirmedAt.compareTo(a.confirmedAt),
      );
  }

  Future<_ResolvedSalonWorkspace> _resolveSalonWorkspace(AppUser user) async {
    final String userId = _requireProfileId(user);
    if (user.role == AppRole.salonOwner) {
      final List<Map<String, dynamic>> salonRows = _toRowMaps(
        await _getRows(
          '/rest/v1/salons?select=*&owner_id=eq.$userId&is_active=eq.true&order=created_at.desc&limit=1',
        ),
      );
      if (salonRows.isEmpty) {
        throw StateError(
          'Freshline could not find the approved salon for this owner.',
        );
      }
      final Map<String, dynamic> salonRow = salonRows.first;
      return _ResolvedSalonWorkspace(
        salon: Salon.fromSupabase(
          salonRow,
          fallbackImagePath: currentDefaultSalonImageUrl(),
        ),
        subscriptionStatus: _salonSubscriptionStatusFromJson(salonRow),
      );
    }

    if (user.role == AppRole.employee) {
      final List<Map<String, dynamic>> employeeRows = _toRowMaps(
        await _getRows(
          '/rest/v1/salon_employees?select=*&profile_id=eq.$userId&limit=1',
        ),
      );
      if (employeeRows.isEmpty) {
        throw StateError(
          'Freshline could not find the linked employee account.',
        );
      }
      final Map<String, dynamic> employeeRow = employeeRows.first;
      final String salonId = _readString(employeeRow['salon_id']);
      final List<Map<String, dynamic>> salonRows = _toRowMaps(
        await _getRows('/rest/v1/salons?select=*&id=eq.$salonId&limit=1'),
      );
      if (salonRows.isEmpty) {
        throw StateError('Freshline could not find the employee salon.');
      }
      final Map<String, dynamic> salonRow = salonRows.first;
      return _ResolvedSalonWorkspace(
        salon: Salon.fromSupabase(
          salonRow,
          fallbackImagePath: currentDefaultSalonImageUrl(),
        ),
        currentEmployee: Employee.fromSupabase(
          employeeRow,
          fallbackImagePath: currentDefaultProfileImageUrl(),
        ),
        subscriptionStatus: _salonSubscriptionStatusFromJson(salonRow),
      );
    }

    throw StateError(
      'Freshline could not open the salon workspace for this account.',
    );
  }

  Future<void> _refreshSalonReviewSummary({
    required String salonId,
    String? employeeId,
  }) async {
    final List<Map<String, dynamic>> reviewRows = _toRowMaps(
      await _getRows(
        '/rest/v1/salon_reviews?select=salon_rating,employee_rating,employee_id&salon_id=eq.$salonId',
      ),
    );
    final int reviewsCount = reviewRows.length;
    final double salonRating = reviewsCount == 0
        ? 0
        : reviewRows.fold<double>(
                0,
                (double sum, Map<String, dynamic> row) =>
                    sum + _readDouble(row['salon_rating']),
              ) /
              reviewsCount;
    await _patchRows(
      '/rest/v1/salons?id=eq.$salonId',
      body: <String, dynamic>{
        'rating': double.parse(salonRating.toStringAsFixed(1)),
        'reviews_count': reviewsCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the salon rating summary.',
    );

    final String normalizedEmployeeId = _readString(employeeId);
    if (normalizedEmployeeId.isEmpty) {
      return;
    }
    final List<Map<String, dynamic>> employeeReviews = reviewRows
        .where(
          (Map<String, dynamic> row) =>
              _readString(row['employee_id']) == normalizedEmployeeId,
        )
        .toList(growable: false);
    final int employeeReviewCount = employeeReviews.length;
    final double employeeRating = employeeReviewCount == 0
        ? 0
        : employeeReviews.fold<double>(
                0,
                (double sum, Map<String, dynamic> row) =>
                    sum + _readDouble(row['employee_rating']),
              ) /
              employeeReviewCount;
    await _patchRows(
      '/rest/v1/salon_employees?id=eq.$normalizedEmployeeId',
      body: <String, dynamic>{
        'rating': double.parse(employeeRating.toStringAsFixed(1)),
        'reviews_count': employeeReviewCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      prefer: 'return=minimal',
      fallback: 'Freshline could not update the employee rating summary.',
    );
  }

  Future<void> _refreshProductReviewSummary({required String productId}) async {
    final List<Map<String, dynamic>> reviewRows = _toRowMaps(
      await _getRows(
        '/rest/v1/product_reviews?select=rating&product_id=eq.$productId',
      ),
    );
    final int reviewsCount = reviewRows.length;
    final double productRating = reviewsCount == 0
        ? 0
        : reviewRows.fold<double>(
                0,
                (double sum, Map<String, dynamic> row) =>
                    sum + _readDouble(row['rating']),
              ) /
              reviewsCount;
    final Map<String, dynamic> body = <String, dynamic>{
      'rating': double.parse(productRating.toStringAsFixed(1)),
      'reviews_count': reviewsCount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await _patchRows(
        '/rest/v1/products?id=eq.$productId',
        body: body,
        prefer: 'return=minimal',
        fallback: 'Freshline could not update the product rating summary.',
      );
    } catch (error) {
      final String message = error.toString().toLowerCase();
      if (!message.contains('reviews_count')) {
        rethrow;
      }
      body.remove('reviews_count');
      await _patchRows(
        '/rest/v1/products?id=eq.$productId',
        body: body,
        prefer: 'return=minimal',
        fallback: 'Freshline could not update the product rating summary.',
      );
    }
  }

  String _inFilterValues(List<String> values) {
    return values
        .map((String value) => Uri.encodeQueryComponent(value))
        .join(',');
  }

  Future<List<dynamic>> _getRows(String path) async {
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.get(
        Uri.parse('$supabaseUrl$path'),
        headers: _supabaseHeaders(),
      ),
      fallback: 'Freshline could not load data from Supabase.',
    );

    if (response.statusCode == 404) {
      return const <dynamic>[];
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _supabaseWriteErrorMessage(
          response,
          fallback: 'Freshline could not load data from Supabase.',
        ),
      );
    }

    return _decodeRowList(response.body);
  }

  Future<List<dynamic>> _postRows(
    String path, {
    required Object body,
    required String prefer,
    required String fallback,
  }) async {
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.post(
        Uri.parse('$supabaseUrl$path'),
        headers: <String, String>{
          ..._supabaseHeaders(),
          'Content-Type': 'application/json',
          'Prefer': prefer,
        },
        body: jsonEncode(body),
      ),
      fallback: fallback,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _supabaseWriteErrorMessage(response, fallback: fallback),
      );
    }

    return _decodeRowList(response.body);
  }

  Future<List<dynamic>> _patchRows(
    String path, {
    required Map<String, dynamic> body,
    required String prefer,
    required String fallback,
  }) async {
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.patch(
        Uri.parse('$supabaseUrl$path'),
        headers: <String, String>{
          ..._supabaseHeaders(),
          'Content-Type': 'application/json',
          'Prefer': prefer,
        },
        body: jsonEncode(body),
      ),
      fallback: fallback,
    );

    if (response.statusCode == 404) {
      return const <dynamic>[];
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _supabaseWriteErrorMessage(response, fallback: fallback),
      );
    }

    return _decodeRowList(response.body);
  }

  Future<void> _deleteRows(
    String path, {
    String prefer = 'return=minimal',
    required String fallback,
  }) async {
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.delete(
        Uri.parse('$supabaseUrl$path'),
        headers: <String, String>{..._supabaseHeaders(), 'Prefer': prefer},
      ),
      fallback: fallback,
    );

    if (response.statusCode == 404) {
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _supabaseWriteErrorMessage(response, fallback: fallback),
      );
    }
  }

  AppUser _userFromProfile(Map<String, dynamic> row) {
    final AppRole role = appRoleFromValue(
      _readString(row['role'], fallback: AppRole.customer.value),
    );
    final String email = _readString(row['email']);
    return AppUser(
      profileId: _readString(row['id']),
      name: _readString(
        row['full_name'] ?? row['username'],
        fallback: 'Freshline User',
      ),
      email: email,
      phone: _readString(row['phone']),
      city: _readString(row['city'], fallback: 'Manama'),
      address: _readString(row['address']),
      role: role,
      avatarPath: normalizeProfileImageUrl(row['avatar_url']),
      isAdminOwner: role == AppRole.admin && _isAdminOwnerEmail(email),
      isEmailTwoFactorEnabled: false,
      isEmailVerified: _readDateTime(row['email_verified_at']) != null,
      preferredLanguage: 'EN',
    );
  }

  bool _profileRequiresEmailVerification(Map<String, dynamic> row) {
    return _readDateTime(row['email_verified_at']) == null;
  }

  bool _canReusePendingCustomerProfile(Map<String, dynamic> row) {
    return appRoleFromValue(
              _readString(row['role'], fallback: AppRole.customer.value),
            ) ==
            AppRole.customer &&
        _readString(row['auth_user_id']).isEmpty &&
        !_readBool(row['is_super_admin'], fallback: false);
  }

  AdminTeamMember _adminFromProfileRow(Map<String, dynamic> row) {
    final bool isOwner = _isAdminOwnerEmail(_readString(row['email']));
    final DateTime? lastLoginAt = _readDateTime(row['last_login_at']);
    final DateTime? updatedAt = _readDateTime(row['updated_at']);
    final DateTime? createdAt = _readDateTime(row['created_at']);
    final String accountKey = _readString(
      row['id'],
      fallback: _readString(row['email']),
    );
    final String lastAction;
    if (lastLoginAt != null) {
      lastAction = 'Last login ${formatNotificationTimestamp(lastLoginAt)}';
    } else if (updatedAt != null) {
      lastAction = 'Updated ${formatNotificationTimestamp(updatedAt)}';
    } else if (createdAt != null) {
      lastAction = 'Created ${formatNotificationTimestamp(createdAt)}';
    } else {
      lastAction = 'Admin account is ready';
    }
    return AdminTeamMember(
      id: _readString(row['id']),
      name: _readString(
        row['full_name'] ?? row['username'],
        fallback: 'Platform Admin',
      ),
      email: _readString(row['email']),
      phone: _readString(row['phone']),
      city: _readString(row['city'], fallback: 'Manama'),
      avatarPath: normalizeProfileImageUrl(row['avatar_url']),
      roleTitle: isOwner ? 'Admin Owner' : 'Platform Admin',
      storagePath: 'admins/${_safeKey(accountKey)}/profile.jpg',
      lastAction: lastAction,
      isActive: _readBool(row['is_active'], fallback: true),
      isOwner: isOwner,
    );
  }

  PaymentCardInfo _cardFromJson(Map<String, dynamic> row) {
    final int expiryMonth = _readInt(row['expiry_month']);
    final int expiryYear = _readInt(row['expiry_year']);
    final String yearLabel = expiryYear == 0
        ? '--'
        : expiryYear.toString().padLeft(4, '0').substring(2);

    return PaymentCardInfo(
      id: _readString(row['id']),
      holderName: _readString(
        row['cardholder_name'],
        fallback: 'Freshline Card',
      ),
      brand: _readString(row['brand'], fallback: 'Card'),
      last4: _readString(row['last4']),
      expiryLabel: '${expiryMonth.toString().padLeft(2, '0')}/$yearLabel',
    );
  }

  SavedCustomerAddress _savedAddressFromJson(Map<String, dynamic> row) {
    return SavedCustomerAddress(
      id: _readString(row['id']),
      label: _readString(row['label'], fallback: 'Saved Address'),
      addressLine: _readString(row['address_line']),
      location: DeliveryLocationSelection(
        latitude: _readDouble(row['latitude']),
        longitude: _readDouble(row['longitude']),
      ),
      isDefault: _readBool(row['is_default']),
    );
  }

  CustomerSubscriptionStatus? _customerSubscriptionFromJson(
    Map<String, dynamic> row,
  ) {
    final SubscriptionPlan? plan = subscriptionPlanById(
      _readString(row['plan_id']),
    );
    if (plan == null) {
      return null;
    }
    final DateTime? startsAt =
        _readDateTime(row['starts_at']) ?? _readDateTime(row['created_at']);
    final DateTime? endsAt =
        _readDateTime(row['ends_at']) ??
        (startsAt == null
            ? null
            : DateTime(
                startsAt.year,
                startsAt.month + 1,
                startsAt.day,
                startsAt.hour,
                startsAt.minute,
                startsAt.second,
                startsAt.millisecond,
                startsAt.microsecond,
              ));
    return CustomerSubscriptionStatus(
      plan: plan,
      startsAt: startsAt,
      endsAt: endsAt,
      autoRenew: _readBool(row['auto_renew'], fallback: true),
    );
  }

  SalonSubscriptionStatus _salonSubscriptionStatusFromJson(
    Map<String, dynamic> row,
  ) {
    final SubscriptionCycleOption cycle = subscriptionCycleFromValue(
      _readString(row['subscription_cycle']),
    );
    final double? rawAmount = _readNullableDouble(
      row['subscription_amount_bhd'],
    );
    return SalonSubscriptionStatus(
      cycle: cycle,
      amount: _normalizedSalonSubscriptionAmount(
        cycle: cycle,
        rawAmount: rawAmount,
      ),
      expiresAt:
          _readDateTime(row['subscription_paid_until']) ??
          _readDateTime(row['subscription_paid_until_date']),
      autoRenew: _readBool(row['subscription_auto_renew']),
    );
  }

  PromoCouponRecord _promoCouponFromJson(Map<String, dynamic> row) {
    final double minOrderAmount = _readDouble(
      row['min_order_amount_bhd'],
      fallback: -1,
    );
    final double maxDiscountAmount = _readDouble(
      row['max_discount_amount'],
      fallback: -1,
    );
    return PromoCouponRecord(
      id: _nullableString(row['id']),
      code: _readString(row['code']).toUpperCase(),
      description: _nullableString(row['description']),
      descriptionAr: _nullableString(row['description_ar']),
      discountPercent: _readInt(row['discount_percent']),
      targetPlanId: _nullableString(row['applicable_plan_id']),
      minOrderAmountBhd: minOrderAmount <= 0 ? null : minOrderAmount,
      maxDiscountBhd: maxDiscountAmount <= 0 ? null : maxDiscountAmount,
      isActive: _readBool(row['is_active'], fallback: true),
      startsAt: _readDateTime(row['starts_at']),
      endsAt: _readDateTime(row['ends_at']),
      createdAt: _readDateTime(row['created_at']),
      updatedAt: _readDateTime(row['updated_at']),
      salonId: _nullableString(row['salon_id']),
    );
  }

  SalonRegistrationRequest _requestFromJson(Map<String, dynamic> row) {
    return SalonRegistrationRequest(
      id: _readString(row['id']),
      ownerId: _readString(row['owner_id']),
      salonName: _readString(row['salon_name'], fallback: 'Freshline Salon'),
      salonEmail: _readString(row['business_email']),
      salonPhone: _readString(row['phone']),
      city: _readString(row['city'], fallback: 'Manama'),
      address: _readString(row['address']),
      locationUrl: _readString(row['location_url']),
      websiteUrl: _nullableString(row['website_url']),
      salonImage: _nullableAsset(
        row['salon_image_url'],
        fallbackName: 'salon-image.jpg',
      ),
      commercialRegistration: _nullableAsset(
        row['commercial_registration_pdf_url'],
        fallbackName: 'commercial-registration.pdf',
        contentType: 'application/pdf',
      ),
      governmentLicense: _nullableAsset(
        row['government_license_pdf_url'],
        fallbackName: 'government-license.pdf',
        contentType: 'application/pdf',
      ),
      status: salonRequestStatusFromValue(
        _readString(row['status'], fallback: 'pending'),
      ),
      adminNote: _nullableString(row['admin_note']),
      createdAt: _readDateTime(row['created_at']),
      updatedAt: _readDateTime(row['updated_at']),
    );
  }

  UploadedSalonAsset? _nullableAsset(
    Object? value, {
    required String fallbackName,
    String contentType = 'application/octet-stream',
  }) {
    final String url = _readString(value);
    if (url.isEmpty) {
      return null;
    }

    return UploadedSalonAsset.fromPublicUrl(
      url,
      fallbackName: fallbackName,
      contentType: contentType,
    );
  }

  String _requireProfileId(AppUser user) {
    final String userId = user.profileId?.trim() ?? '';
    if (userId.isEmpty) {
      throw StateError('Freshline is missing the signed-in profile id.');
    }
    return userId;
  }

  String _readAuthError(http.Response response, {required String fallback}) {
    final String? transientMessage = freshlineTransientHttpErrorMessage(
      response.statusCode,
    );
    if (transientMessage != null) {
      return transientMessage;
    }
    final String body = response.body.trim();
    if (body.isEmpty) {
      return fallback;
    }
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final String message = _readString(
          decoded['msg'] ??
              decoded['error_description'] ??
              decoded['error'] ??
              decoded['message'],
        );
        if (message.isNotEmpty) {
          final String normalized = message.trim().toLowerCase();
          if (normalized.contains('database error saving new user')) {
            return '$message (This is a Supabase Auth trigger error. Temporary workaround: update `public.sync_auth_user_profile()` to fail-open so auth signup succeeds, then rely on the app to upsert `public.profiles`.)';
          }
          return message;
        }
      }
    } catch (_) {
      // Ignore malformed payloads and use the fallback message below.
    }
    return fallback;
  }

  bool _isMissingOtpFunctionError(
    String message, {
    required String functionName,
  }) {
    final String normalizedMessage = message.trim().toLowerCase();
    final String normalizedFunctionName = functionName.trim().toLowerCase();
    if (normalizedMessage.isEmpty || normalizedFunctionName.isEmpty) {
      return false;
    }
    return normalizedMessage.contains(
          'could not find the function public.$normalizedFunctionName',
        ) ||
        (normalizedMessage.contains(normalizedFunctionName) &&
            normalizedMessage.contains('schema cache')) ||
        normalizedMessage.contains('no function matches the given name');
  }

  bool _isMissingOtpEdgeFunctionError(String message) {
    final String normalizedMessage = message.trim().toLowerCase();
    if (normalizedMessage.isEmpty) {
      return false;
    }
    // Supabase Edge Functions return this when the function is not deployed.
    return normalizedMessage.contains('requested function was not found') ||
        normalizedMessage.contains('function was not found');
  }

  bool _isOtpRateLimitError(String message) {
    final String normalizedMessage = message.trim().toLowerCase();
    if (normalizedMessage.isEmpty) {
      return false;
    }
    return normalizedMessage.contains('too many otp requests') ||
        (normalizedMessage.contains('too many') &&
            normalizedMessage.contains('otp')) ||
        normalizedMessage.contains('rate limit') ||
        normalizedMessage.contains('rate-limit');
  }

  String _otpPolicyErrorMessage() => _otpPolicyMessage;

  String _otpRateLimitMessage() {
    return _otpRateLimitErrorCode;
  }

  bool _shouldUseLocalOtpFallback(
    String message, {
    required bool allowLocalFallback,
  }) {
    if (!allowLocalFallback) {
      return false;
    }
    final String normalizedMessage = message.trim().toLowerCase();
    if (normalizedMessage.isEmpty) {
      return false;
    }
    return normalizedMessage.contains('requested function was not found') ||
        normalizedMessage.contains('auth email delivery is not configured') ||
        normalizedMessage.contains('resend_api_key') ||
        normalizedMessage.contains('auth_email_from') ||
        (normalizedMessage.contains('function digest(') &&
            normalizedMessage.contains('does not exist')) ||
        _isMissingOtpFunctionError(
          normalizedMessage,
          functionName: 'create_auth_email_otp',
        ) ||
        _isMissingOtpFunctionError(
          normalizedMessage,
          functionName: 'verify_auth_email_otp',
        ) ||
        _isMissingOtpFunctionError(
          normalizedMessage,
          functionName: 'create_auth_phone_otp',
        ) ||
        _isMissingOtpFunctionError(
          normalizedMessage,
          functionName: 'verify_auth_phone_otp',
        );
  }

  bool _allowsLocalOtpFallbackForPurpose(String purpose) {
    final String normalizedPurpose = purpose.trim().toLowerCase();
    if (allowUnsafeLocalOtpBypass) {
      return true;
    }
    return normalizedPurpose == _passwordResetOtpPurpose &&
        allowPasswordResetLocalOtpFallback;
  }

  String _otpBackendSetupMessage({required String functionName}) {
    return _otpPolicyErrorMessage();
  }

  Future<String?> _pickAndUploadImageAsset({
    required String dialogTitle,
    required String folder,
    required String fallbackError,
  }) async {
    final PreparedUploadFile? uploadFile = await pickFreshlineImageUpload(
      dialogTitle: dialogTitle,
    );
    if (uploadFile == null) {
      return null;
    }
    final String safeName = _safeFileName(uploadFile.fileName);
    final String storagePath =
        '$folder/${DateTime.now().millisecondsSinceEpoch}-$safeName';
    final Uri uri = Uri.parse(
      '$supabaseUrl/storage/v1/object/$supabaseSalonMediaBucket/${_encodePath(storagePath)}',
    );
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.post(
        uri,
        headers: <String, String>{
          ..._supabaseHeaders(),
          'Content-Type': uploadFile.contentType,
          'x-upsert': 'true',
        },
        body: uploadFile.bytes,
      ),
      fallback: fallbackError,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        freshlineStorageUploadErrorMessage(
          response,
          fallback: fallbackError,
          oversizeMessage: freshlineImageOversizeErrorMessage,
          invalidTypeMessage: freshlineImageInvalidTypeMessage,
        ),
      );
    }

    return '$supabaseUrl/storage/v1/object/public/$supabaseSalonMediaBucket/${_encodePath(storagePath)}';
  }

  Map<String, String> _supabaseHeaders() {
    return <String, String>{
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $supabaseAnonKey',
    };
  }
}

String _bookingSlotKey({
  required String salonId,
  required String employeeId,
  required DateTime scheduledAt,
}) {
  return '$salonId|$employeeId|${scheduledAt.toIso8601String()}';
}

bool _sameLocation(DeliveryLocationSelection a, DeliveryLocationSelection b) {
  return (a.latitude - b.latitude).abs() < 0.000001 &&
      (a.longitude - b.longitude).abs() < 0.000001;
}

bool _isCompletedOrder(UserOrder order) {
  if (!order.isProductOrder) {
    return _isCompletedOrderStatus(order.statusLabel);
  }
  return _isCompletedOrderStatus(order.statusLabel);
}

bool _isCompletedOrderStatus(String statusLabel) {
  final String normalized = statusLabel.trim().toLowerCase();
  return normalized == 'completed' ||
      normalized == 'delivered' ||
      normalized == 'cancelled';
}

bool _isDuplicateInvoiceNumberError(Object error, String columnName) {
  final String message = error.toString().toLowerCase();
  return message.contains(columnName.toLowerCase()) &&
      (message.contains('duplicate') ||
          message.contains('unique') ||
          message.contains('already exists'));
}

bool _isBookingCompleted(String bookingStatus) {
  final String normalized = bookingStatus.trim().toLowerCase();
  return normalized == 'completed' || normalized == 'cancelled';
}

String _bookingStatusLabel(String bookingStatus) {
  switch (bookingStatus.trim().toLowerCase()) {
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'confirmed':
      return 'In order';
    case 'pending':
    default:
      return 'In order';
  }
}

bool _useArabicLanguage(String? languageCode) {
  return (languageCode ?? '').trim().toUpperCase() == 'AR';
}

bool _containsArabicText(String value) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(value);
}

String _bookingStatusLabelForLanguage(
  String bookingStatus, {
  required bool useArabic,
}) {
  if (!useArabic) {
    return _bookingStatusLabel(bookingStatus);
  }
  switch (bookingStatus.trim().toLowerCase()) {
    case 'completed':
      return 'مكتمل';
    case 'cancelled':
      return 'ملغي';
    case 'confirmed':
    case 'pending':
    default:
      return 'قيد التنفيذ';
  }
}

String _visitModeLabel(String rawValue, {String fallback = 'Go to saloon'}) {
  switch (rawValue.trim().toLowerCase()) {
    case 'home_service':
      return 'Come to you';
    case 'in_shop':
      return 'Go to saloon';
    default:
      return fallback.isEmpty ? 'Go to saloon' : fallback;
  }
}

String _visitModeLabelForLanguage(
  String rawValue, {
  required bool useArabic,
  String fallback = 'Go to saloon',
  String? fallbackArabic,
}) {
  if (useArabic) {
    final String explicitArabic = _readString(fallbackArabic);
    if (explicitArabic.isNotEmpty) {
      return explicitArabic;
    }
  }
  final String english = _visitModeLabel(rawValue, fallback: fallback);
  if (!useArabic) {
    return english;
  }
  switch (english.trim().toLowerCase()) {
    case 'come to you':
      return 'الخدمة المنزلية';
    case 'go to saloon':
      return 'الذهاب إلى الصالون';
    case 'home delivery':
      return 'توصيل منزلي';
    default:
      return english;
  }
}

String _bookingVisitModeValue(String visitModeLabel) {
  return visitModeLabel.trim().toLowerCase() == 'come to you'
      ? 'home_service'
      : 'in_shop';
}

String _gatewayNameFromCardLabel(String? cardLabel) {
  final String value = _readString(cardLabel);
  if (value.isEmpty) {
    return 'Card';
  }
  final List<String> segments = value.split('•');
  return segments.first.trim().isEmpty ? 'Card' : segments.first.trim();
}

Map<String, dynamic> _decodeOrderMetadata(Object? value) {
  final String raw = _readString(value);
  if (raw.isEmpty) {
    return <String, dynamic>{};
  }

  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // Ignore invalid JSON notes and treat them as legacy free text.
  }
  return <String, dynamic>{};
}

bool _isMissingEmployeeSalaryPaymentsSchema(Object error) {
  final String message = error.toString().toLowerCase();
  return message.contains('employee_salary_payments') ||
      message.contains('amount_bhd') ||
      message.contains('salary_month') ||
      message.contains('confirmed_by') ||
      message.contains('confirmed_at');
}

bool _isMissingProductStockReservationFunction(Object error) {
  final String message = error.toString().toLowerCase();
  return message.contains('reserve_product_order_stock') ||
      message.contains('restore_product_order_stock') ||
      message.contains('p_items');
}

String _formatRepositoryDateTime(DateTime value) {
  final DateTime local = value.toLocal();
  final int hour12 = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final String minute = local.minute.toString().padLeft(2, '0');
  final String meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '${formatCalendarDate(local)} $hour12:$minute $meridiem';
}

Map<String, int> _productOrderQuantitiesByProductId(
  List<ProductOrderLineItem> items,
) {
  final Map<String, int> quantitiesByProductId = <String, int>{};
  for (final ProductOrderLineItem item in items) {
    final String productId = item.productId.trim();
    if (productId.isEmpty || item.quantity <= 0) {
      continue;
    }
    quantitiesByProductId.update(
      productId,
      (int current) => current + item.quantity,
      ifAbsent: () => item.quantity,
    );
  }
  return quantitiesByProductId;
}

List<Map<String, dynamic>> _productStockReservationPayload(
  List<ProductOrderLineItem> items,
) {
  return _productOrderQuantitiesByProductId(items).entries
      .map(
        (MapEntry<String, int> entry) => <String, dynamic>{
          'product_id': entry.key,
          'quantity': entry.value,
        },
      )
      .toList(growable: false);
}

String _localizedMetadataValue(
  Map<String, dynamic> metadata, {
  required String key,
  required bool useArabic,
  String fallback = '',
}) {
  if (useArabic) {
    final String arabicValue = _readString(metadata['${key}_ar']);
    if (arabicValue.isNotEmpty) {
      return arabicValue;
    }
  }
  return _readString(metadata[key], fallback: fallback);
}

String _localizedProductNameFromRow(
  Map<String, dynamic> row, {
  required bool useArabic,
}) {
  if (useArabic) {
    final String arabicName = _readString(row['product_name_ar']);
    if (arabicName.isNotEmpty) {
      return arabicName;
    }
  }
  return _readString(row['product_name']);
}

String _productSummaryFromMetadata(
  Map<String, dynamic> metadata, {
  required bool useArabic,
}) {
  final Object? rawItems = metadata['items_summary'];
  if (rawItems is List) {
    final List<Map<String, dynamic>> items = rawItems
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    if (items.isNotEmpty) {
      final String firstName = _localizedMetadataValue(
        items.first,
        key: 'name',
        useArabic: useArabic,
        fallback: useArabic ? 'طلب منتجات' : 'Product order',
      );
      final int extraCount = items.fold<int>(
        0,
        (int sum, Map<String, dynamic> item) =>
            sum + math.max(0, _readInt(item['quantity']) - 1),
      );
      final int additionalItems = items.length - 1 + extraCount;
      if (additionalItems > 0) {
        return useArabic
            ? '$firstName + $additionalItems ${additionalItems == 1 ? 'منتج إضافي' : 'منتجات إضافية'}'
            : '$firstName + $additionalItems more item${additionalItems == 1 ? '' : 's'}';
      }
      return firstName;
    }
  }

  return _localizedMetadataValue(
    metadata,
    key: 'item_label',
    useArabic: useArabic,
    fallback: useArabic ? 'طلب منتجات' : 'Product order',
  );
}

int _fallbackLoyaltyBalance({
  required List<Map<String, dynamic>> productRows,
  required List<Map<String, dynamic>> bookingRows,
}) {
  final int productEarned = productRows.fold<int>(0, (
    int sum,
    Map<String, dynamic> row,
  ) {
    final Map<String, dynamic> metadata = _decodeOrderMetadata(row['notes']);
    return sum + _readInt(metadata['loyalty_points_gained']);
  });
  final int productRedeemed = productRows.fold<int>(0, (
    int sum,
    Map<String, dynamic> row,
  ) {
    final Map<String, dynamic> metadata = _decodeOrderMetadata(row['notes']);
    return sum + _readInt(metadata['loyalty_points_redeemed']);
  });
  final int bookingEarned = bookingRows.fold<int>(0, (
    int sum,
    Map<String, dynamic> row,
  ) {
    return sum + _readInt(row['loyalty_points_earned']);
  });

  return math.max(0, productEarned + bookingEarned - productRedeemed);
}

class _ExpiryPart {
  const _ExpiryPart(this.value);

  final int value;
}

(_ExpiryPart, _ExpiryPart) _parseExpiry(String expiryLabel) {
  final RegExpMatch? match = RegExp(
    r'^\s*(\d{2})\s*/\s*(\d{2,4})\s*$',
  ).firstMatch(expiryLabel);
  if (match == null) {
    return (const _ExpiryPart(0), const _ExpiryPart(0));
  }

  final int month = int.tryParse(match.group(1) ?? '') ?? 0;
  int year = int.tryParse(match.group(2) ?? '') ?? 0;
  if (year > 0 && year < 100) {
    year += 2000;
  }
  return (_ExpiryPart(month), _ExpiryPart(year));
}

List<Map<String, dynamic>> _toRowMaps(List<dynamic> rows) {
  return rows
      .whereType<Map<dynamic, dynamic>>()
      .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

List<dynamic> _decodeRowList(String responseBody) {
  if (responseBody.trim().isEmpty) {
    return const <dynamic>[];
  }

  final Object? decoded = jsonDecode(responseBody);
  if (decoded is List<dynamic>) {
    return decoded;
  }
  if (decoded is Map<String, dynamic>) {
    return <dynamic>[decoded];
  }
  return const <dynamic>[];
}

String _safeKey(String value) {
  final String collapsed = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return collapsed.isEmpty ? 'freshline' : collapsed;
}

String _safeFileName(String value) {
  final String sanitized = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), '-');
  return sanitized.isEmpty ? 'freshline-file' : sanitized;
}

String _encodePath(String path) {
  return path
      .split('/')
      .where((String segment) => segment.trim().isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
}

String? _nullableUuid(String? value) {
  final String trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final RegExp uuidExpression = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  return uuidExpression.hasMatch(trimmed) ? trimmed : null;
}

String _readString(Object? value, {String fallback = ''}) {
  final String text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final String text = _readString(value);
  return text.isEmpty ? null : text;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse((value ?? '').toString()) ?? fallback;
}

Duration? _durationFromMinutes(Object? value) {
  final int minutes = _readInt(value);
  return minutes > 0 ? Duration(minutes: minutes) : null;
}

double _readDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '').toString()) ?? fallback;
}

double? _readNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  final double parsed = _readDouble(value, fallback: double.nan);
  return parsed.isNaN ? null : parsed;
}

double _normalizedSalonSubscriptionAmount({
  required SubscriptionCycleOption cycle,
  required double? rawAmount,
}) {
  if (rawAmount == null || rawAmount <= 0) {
    return cycle.salonPrice;
  }
  if (rawAmount == 300) {
    return cycle == SubscriptionCycleOption.yearly
        ? salonYearlySubscriptionPrice
        : salonMonthlySubscriptionPrice;
  }
  return rawAmount;
}

bool _readBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final String normalized = (value ?? '').toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return fallback;
}

bool _isAdminOwnerEmail(String email) {
  return email.trim().toLowerCase() == adminOwnerEmail;
}

DateTime? _readDateTime(Object? value) {
  final String raw = _readString(value);
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

double _sumPaidTotals(List<Map<String, dynamic>> rows) {
  return rows.fold<double>(0, (double sum, Map<String, dynamic> row) {
    if (_readString(row['payment_status']).toLowerCase() != 'paid') {
      return sum;
    }
    return sum + _readDouble(row['total_amount']);
  });
}

double _sumPaidTotalsForUser({
  required List<Map<String, dynamic>> rows,
  required String userId,
}) {
  return rows.fold<double>(0, (double sum, Map<String, dynamic> row) {
    if (_readString(row['customer_id']) != userId ||
        _readString(row['payment_status']).toLowerCase() != 'paid') {
      return sum;
    }
    return sum + _readDouble(row['total_amount']);
  });
}

double _sumPaidTransactionsBySource({
  required List<Map<String, dynamic>> paymentRows,
  required String sourceTable,
}) {
  return paymentRows.fold<double>(0, (double sum, Map<String, dynamic> row) {
    if (_readString(row['source_table']) != sourceTable ||
        _readString(row['payment_status']).toLowerCase() != 'paid') {
      return sum;
    }
    return sum + _readDouble(row['amount']);
  });
}

String _supabaseWriteErrorMessage(
  http.Response response, {
  required String fallback,
}) {
  final String? transientMessage = freshlineTransientHttpErrorMessage(
    response.statusCode,
  );
  if (transientMessage != null) {
    return transientMessage;
  }

  final String body = response.body.trim();
  String? parsedMessage;

  if (body.isNotEmpty) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final String message = _readString(decoded['message']);
        final String details = _readString(decoded['details']);
        final String hint = _readString(decoded['hint']);
        final List<String> parts = <String>[
          if (message.trim().isNotEmpty) message.trim(),
          if (details.trim().isNotEmpty && details.trim() != message.trim())
            details.trim(),
          if (hint.trim().isNotEmpty) 'Hint: ${hint.trim()}',
        ];
        if (parts.isNotEmpty) {
          parsedMessage = parts.join(' • ');
        }
      } else if (decoded is String && decoded.trim().isNotEmpty) {
        parsedMessage = decoded.trim();
      }
    } catch (_) {
      // Ignore parse errors and use the fallback message.
    }
  }

  if (response.statusCode == 401 || response.statusCode == 403) {
    if ((parsedMessage ?? '').isNotEmpty) {
      return '$parsedMessage Re-run supabase/freshline_schema.sql, then try again.';
    }
    return 'Supabase blocked this request. Re-run supabase/freshline_schema.sql, then try again.';
  }

  if ((parsedMessage ?? '').isNotEmpty) {
    final String message = parsedMessage!;
    final String normalized = message.toLowerCase();
    if (normalized.contains('unsupported operation') &&
        normalized.contains('insert')) {
      return '$message Re-run `supabase/freshline_schema.sql` on your Supabase project (it may be missing the insertable table / policies), then try again.';
    }
    return message;
  }

  return fallback;
}

String _requestNotificationTitle(SalonRequestStatus status) {
  switch (status) {
    case SalonRequestStatus.approved:
      return 'Salon Request Approved';
    case SalonRequestStatus.rejected:
      return 'Salon Request Rejected';
    case SalonRequestStatus.needsInfo:
      return 'Salon Request Needs Info';
    case SalonRequestStatus.pending:
      return 'Salon Request Updated';
  }
}

String _requestNotificationBody(
  SalonRequestStatus status,
  Map<String, dynamic> requestRow,
) {
  final String salonName = _readString(
    requestRow['salon_name'],
    fallback: 'your salon',
  );
  switch (status) {
    case SalonRequestStatus.approved:
      return '$salonName was approved and is now visible for admin follow-up.';
    case SalonRequestStatus.rejected:
      return '$salonName was rejected. Review the admin note and submit again if needed.';
    case SalonRequestStatus.needsInfo:
      return '$salonName needs more information. Review the admin note and update the request.';
    case SalonRequestStatus.pending:
      return '$salonName request status was updated.';
  }
}

List<Employee> employeesForSalonFallback(String salonId) {
  switch (salonId) {
    case '1':
      return employees;
    case '2':
      return <Employee>[
        employees[0].copyWith(id: 'fallback-2-e1', name: 'Rami Ashraf'),
        employees[1].copyWith(id: 'fallback-2-e2', name: 'Nora Ali'),
      ];
    case '3':
      return <Employee>[
        employees[2].copyWith(id: 'fallback-3-e1', name: 'Omar Faisal'),
      ];
    default:
      return employees;
  }
}
