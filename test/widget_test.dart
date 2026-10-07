import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshline_tt/src/app.dart';
import 'package:freshline_tt/src/config/app_config.dart' show supabaseUrl;
import 'package:freshline_tt/src/data/app_data.dart';
import 'package:freshline_tt/src/services/catalog_service.dart';
import 'package:freshline_tt/src/services/notifications_service.dart';
import 'package:freshline_tt/src/services/platform_repository.dart';
import 'package:freshline_tt/src/services/salon_owner_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('splash, onboarding, and auth flow lead to the home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      FreshlineApp(
        catalogService: MemoryCatalogService(),
        notificationsService: MemoryNotificationsService(),
        platformRepository: MemoryPlatformRepository(),
        salonOwnerRepository: MemorySalonOwnerRepository(),
      ),
    );
    expect(find.text('FreshLine'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Book your salon faster'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Get Start'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsAtLeastNWidgets(1));

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alex@freshline.app');
    await tester.enterText(fields.at(1), 'freshline123');
    final Finder signInButton = find.widgetWithText(
      FilledButton,
      'Sign In As Customer',
    );
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Barber Salons'), findsOneWidget);
    expect(find.text('Most Purchased Products'), findsOneWidget);
  });

  testWidgets('contact us route shows support details without errors', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            const ContactUsScreen(),
                      ),
                    );
                  },
                  child: const Text('Open Contact'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open Contact'));
    await tester.pumpAndSettle();

    expect(find.text('Freshline Support'), findsOneWidget);
    expect(find.text('Phone Support'), findsOneWidget);
    expect(find.text('Email Support'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications switch to Arabic when locale is Arabic', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: NotificationsScreen(
          notifications: <AppNotificationItem>[
            AppNotificationItem(
              title: 'Appointment Confirmed',
              titleAr: 'تم تأكيد الموعد',
              message: 'Your appointment is confirmed.',
              messageAr: 'تم تأكيد موعدك.',
              icon: 'calendar',
              unread: true,
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.text('تم تأكيد الموعد'), findsOneWidget);
    expect(find.text('تم تأكيد موعدك.'), findsOneWidget);
    expect(find.text('الآن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('legacy catalog image URLs normalize to salon and product defaults', () {
    final Salon salon = Salon.fromSupabase(<String, dynamic>{
      'id': 'salon-1',
      'name': 'Legacy Salon',
      'image_url':
          '$supabaseUrl/storage/v1/object/public/All/dd.png',
    }, fallbackImagePath: defaultSalonImageUrl);

    final Product product = Product.fromSupabase(<String, dynamic>{
      'id': 'product-1',
      'name': 'Legacy Product',
      'image_url':
          '$supabaseUrl/storage/v1/object/public/All/defaultimage.jpeg',
    }, fallbackImagePath: defaultProductImageUrl);

    expect(salon.imagePath, startsWith(defaultSalonImageUrl));
    expect(product.imagePath, startsWith(defaultProductImageUrl));
    expect(
      defaultSalonImageUrl,
      '$supabaseUrl/storage/v1/object/public/All/FrslineS.png',
    );
    expect(
      defaultProductImageUrl,
      '$supabaseUrl/storage/v1/object/public/All/FrslineP.png',
    );
  });

  test('platform media defaults resolve and write default selections safely', () {
    applyPlatformMediaDefaults(
      const PlatformMediaDefaults(
        profileImageUrl: 'https://example.com/profile.png',
        salonImageUrl: 'https://example.com/salon.png',
        productImageUrl: 'https://example.com/product.png',
        profileRevision: 'profile-rev',
        salonRevision: 'salon-rev',
        productRevision: 'product-rev',
      ),
    );
    addTearDown(
      () => applyPlatformMediaDefaults(const PlatformMediaDefaults()),
    );

    expect(
      normalizeProfileImageUrl(null),
      startsWith('https://example.com/profile.png'),
    );
    expect(
      normalizeCatalogImageUrl('', fallback: defaultSalonImageUrl),
      startsWith('https://example.com/salon.png'),
    );
    expect(
      normalizeCatalogImageUrl(
        '$supabaseUrl/storage/v1/object/public/All/defaultimage.jpeg',
        fallback: defaultProductImageUrl,
      ),
      startsWith('https://example.com/product.png'),
    );
    expect(
      canonicalProfileImageForWrite(currentDefaultProfileImageUrl()),
      isNull,
    );
    expect(canonicalSalonImageForWrite(currentDefaultSalonImageUrl()), isNull);
    expect(
      canonicalProductImageForWrite(currentDefaultProductImageUrl()),
      isNull,
    );
  });

  testWidgets('salon registration opens and submits to owner dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FreshlineApp(
        catalogService: MemoryCatalogService(),
        notificationsService: MemoryNotificationsService(),
        platformRepository: MemoryPlatformRepository(),
        salonOwnerRepository: MemorySalonOwnerRepository(),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Get Start'));
    await tester.pumpAndSettle();

    final Finder registerSalonButton = find.widgetWithText(
      OutlinedButton,
      'Register Your Salon',
    );
    await tester.ensureVisible(registerSalonButton);
    await tester.tap(registerSalonButton);
    await tester.pumpAndSettle();

    expect(find.text('Create Owner Account'), findsOneWidget);

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Salman Owner');
    await tester.enterText(fields.at(1), 'owner@salon.app');
    await tester.enterText(fields.at(2), 'owner123');

    final Finder createOwnerButton = find.widgetWithText(
      FilledButton,
      'Create Owner Account',
    );
    await tester.ensureVisible(createOwnerButton);
    await tester.tap(createOwnerButton);
    await tester.pumpAndSettle();

    expect(find.text('Add a New Request'), findsAtLeastNWidgets(1));

    final Finder addRequestButton = find.widgetWithText(
      FilledButton,
      'Add a New Request',
    );
    await tester.ensureVisible(addRequestButton.first);
    await tester.tap(addRequestButton.first);
    await tester.pumpAndSettle();

    final Finder requestFields = find.byType(TextFormField);
    await tester.enterText(requestFields.at(0), 'Freshline Test Salon');
    await tester.enterText(requestFields.at(1), 'hello@freshline-salon.app');
    await tester.enterText(requestFields.at(2), '+973 3777 1111');
    await tester.enterText(requestFields.at(3), 'Road 2819, Seef District');
    await tester.enterText(
      requestFields.at(4),
      'https://maps.google.com/?q=26.2,50.5',
    );

    for (int index = 0; index < 3; index++) {
      final Finder currentUploadButton = find
          .widgetWithText(OutlinedButton, 'Upload File')
          .first;
      await tester.ensureVisible(currentUploadButton);
      await tester.tap(currentUploadButton, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    final Finder submitRequestButton = find.widgetWithText(
      FilledButton,
      'Submit Request',
    );
    await tester.ensureVisible(submitRequestButton);
    await tester.tap(submitRequestButton);
    await tester.pumpAndSettle();

    expect(find.text('Freshline Test Salon'), findsOneWidget);
    expect(find.text('Pending Review'), findsOneWidget);
  });

  testWidgets('customer registration adds a welcome notification', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FreshlineApp(
        catalogService: MemoryCatalogService(),
        notificationsService: MemoryNotificationsService(),
        platformRepository: MemoryPlatformRepository(),
        salonOwnerRepository: MemorySalonOwnerRepository(),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Get Start'));
    await tester.pumpAndSettle();

    final Finder registerLink = find.widgetWithText(
      TextButton,
      "I don't have an account",
    );
    await tester.ensureVisible(registerLink);
    await tester.tap(registerLink);
    await tester.pumpAndSettle();

    final Finder registerFieldsStepOne = find.byType(TextFormField);
    await tester.enterText(registerFieldsStepOne.at(0), 'new@freshline.app');
    await tester.enterText(registerFieldsStepOne.at(1), 'New User');
    await tester.enterText(registerFieldsStepOne.at(2), 'freshline123');
    await tester.enterText(registerFieldsStepOne.at(3), 'freshline123');

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    final Finder registerFieldsStepTwo = find.byType(TextFormField);
    await tester.enterText(registerFieldsStepTwo.at(0), '+973 3000 0000');

    final Finder createAccountButton = find.widgetWithText(
      FilledButton,
      'Create Account',
    );
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    final Finder notificationsButton = find.byIcon(
      Icons.notifications_none_rounded,
    );
    await tester.tap(notificationsButton.first);
    await tester.pumpAndSettle();

    expect(find.text('Welcome to FreshLine'), findsOneWidget);
  });

  testWidgets('saved session restores signed-in customer after restart', (
    WidgetTester tester,
  ) async {
    const AppUser savedUser = AppUser(
      profileId: 'usr-restore-1',
      name: 'Alex Freshline',
      email: 'alex@freshline.app',
      phone: '+973 3000 0000',
      city: 'Manama',
      role: AppRole.customer,
      preferredLanguage: 'AR',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'freshline.session_user': jsonEncode(savedUser.toJson()),
      'freshline.language_code': 'AR',
      'freshline.onboarding_completed': true,
    });

    await tester.pumpWidget(
      FreshlineApp(
        catalogService: MemoryCatalogService(),
        notificationsService: MemoryNotificationsService(),
        platformRepository: MemoryPlatformRepository(),
        salonOwnerRepository: MemorySalonOwnerRepository(),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Alex Freshline'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('available coupons screen renders without crashing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: AvailableCouponsScreen(
          coupons: <PromoCouponRecord>[
            PromoCouponRecord(
              code: 'FRESH20',
              description: '20% welcome discount for the first order only.',
              discountPercent: 20,
              isActive: true,
            ),
          ],
          customerOrderCount: 0,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Available Coupons'), findsOneWidget);
    expect(find.text('FRESH20'), findsOneWidget);
    expect(find.textContaining('20% off'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('available coupons screen stays stable on narrow layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(280, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: AvailableCouponsScreen(
          coupons: <PromoCouponRecord>[
            PromoCouponRecord(
              code: 'FRESH20',
              description: '20% welcome discount for the first order only.',
              discountPercent: 20,
              isActive: true,
            ),
          ],
          customerOrderCount: 0,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Available Coupons'), findsOneWidget);
    expect(find.text('FRESH20'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer can open available coupons from settings', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            user: const AppUser(
              name: 'Test User',
              email: 'test@freshline.app',
              phone: '+973 3000 0000',
              city: 'Manama',
            ),
            onLogout: () {},
            currentPlan: null,
            subscriptionStatus: null,
            customerOrderCount: 0,
            availableCoupons: const <PromoCouponRecord>[
              PromoCouponRecord(
                code: 'FRESH20',
                description: '20% welcome discount for the first order only.',
                discountPercent: 20,
                isActive: true,
              ),
              PromoCouponRecord(
                code: 'SAVE15',
                description: '15% off selected customer orders.',
                discountPercent: 15,
                isActive: true,
              ),
            ],
            savedCards: const <PaymentCardInfo>[],
            platformRepository: MemoryPlatformRepository(),
            onAddCard: (_) async => null,
            onRemoveCard: (_) async {},
            onUserChanged: (_) {},
            onOpenNotifications: () {},
            onOpenPlans: () {},
            isDarkMode: false,
            onThemeChanged: (_) {},
            isHighContrast: false,
            onHighContrastChanged: (_) {},
            textScaleFactor: 1.0,
            onTextScaleChanged: (_) {},
            selectedLanguage: 'EN',
            onLanguageChanged: (_) {},
            isBiometricLockEnabled: false,
            onBiometricLockChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder couponsItem = find.text('Available Coupons');
    await tester.scrollUntilVisible(
      couponsItem,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(couponsItem), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(couponsItem);
    await tester.pumpAndSettle();

    expect(find.text('Available Coupons'), findsOneWidget);
    expect(find.text('SAVE15'), findsOneWidget);
    expect(find.text('FRESH20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer can open available coupons from settings with mouse', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            user: const AppUser(
              name: 'Test User',
              email: 'test@freshline.app',
              phone: '+973 3000 0000',
              city: 'Manama',
            ),
            onLogout: () {},
            currentPlan: null,
            subscriptionStatus: null,
            customerOrderCount: 0,
            availableCoupons: const <PromoCouponRecord>[
              PromoCouponRecord(
                code: 'FRESH20',
                description: '20% welcome discount for the first order only.',
                discountPercent: 20,
                isActive: true,
              ),
            ],
            savedCards: const <PaymentCardInfo>[],
            platformRepository: MemoryPlatformRepository(),
            onAddCard: (_) async => null,
            onRemoveCard: (_) async {},
            onUserChanged: (_) {},
            onOpenNotifications: () {},
            onOpenPlans: () {},
            isDarkMode: false,
            onThemeChanged: (_) {},
            isHighContrast: false,
            onHighContrastChanged: (_) {},
            textScaleFactor: 1.0,
            onTextScaleChanged: (_) {},
            selectedLanguage: 'EN',
            onLanguageChanged: (_) {},
            isBiometricLockEnabled: false,
            onBiometricLockChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder couponsItem = find.text('Available Coupons');
    await tester.scrollUntilVisible(
      couponsItem,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(couponsItem), alignment: 0.5);
    await tester.pumpAndSettle();

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(mouse.removePointer);

    final Offset target = tester.getCenter(couponsItem);
    await mouse.addPointer(location: target);
    await tester.pump();
    await mouse.moveTo(target);
    await tester.pump();
    await mouse.down(target);
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();

    expect(find.text('Available Coupons'), findsOneWidget);
    expect(find.text('FRESH20'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ai stylist shows the voice input button next to the text field',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AiStylistScreen(role: AppRole.customer)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Voice Actions'), findsNothing);
      expect(find.text('الأوامر الصوتية'), findsNothing);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.textContaining('FreshLine AI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('admin product orders screen shows customer orders', (
    WidgetTester tester,
  ) async {
    final MemoryPlatformRepository repository = MemoryPlatformRepository();
    const AppUser customer = AppUser(
      profileId: 'usr-001',
      name: 'Alex Freshline',
      email: 'alex@freshline.app',
      phone: '+973 3000 0000',
      city: 'Manama',
      role: AppRole.customer,
    );
    const AppUser admin = AppUser(
      profileId: 'admin-001',
      name: 'Freshline Admin Owner',
      email: 'admin.com',
      phone: '+973 3000 0000',
      city: 'Manama',
      role: AppRole.admin,
      isAdminOwner: true,
    );

    await repository.placeProductOrder(
      user: customer,
      order: UserOrder(
        id: 'order-voice-1',
        type: UserOrderType.productOrder,
        invoiceNumber: 'FRH00000001',
        salonName: 'Freshline Orders',
        serviceName: products.first.name,
        employeeName: 'Freshline Delivery',
        visitMode: 'Home delivery',
        scheduledAt: DateTime(2026, 4, 4, 10, 30),
        total: products.first.price,
        statusLabel: 'Preparing',
        loyaltyPointsGained: 0,
        address: 'Road 1, Manama',
        cardLabel: 'Visa •••• 4242',
      ),
      items: <ProductOrderLineItem>[
        ProductOrderLineItem(
          productId: 'global-p1',
          productName: products.first.name,
          quantity: 1,
          unitPrice: products.first.price,
        ),
      ],
      location: const DeliveryLocationSelection(
        latitude: 26.2235,
        longitude: 50.5876,
      ),
      addressDetails: 'Road 1, Building 10',
      couponCode: null,
      couponDiscount: 0,
      loyaltyPointsRedeemed: 0,
      loyaltyDiscount: 0,
      taxAmount: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminProductOrdersScreen(
          actor: admin,
          platformRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customer Product Orders'), findsOneWidget);
    expect(find.text(products.first.name), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Take order'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin sign-in opens dashboard without widget exceptions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FreshlineApp(
        catalogService: MemoryCatalogService(),
        notificationsService: MemoryNotificationsService(),
        platformRepository: MemoryPlatformRepository(),
        salonOwnerRepository: MemorySalonOwnerRepository(),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Get Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Admin'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin.com');
    await tester.enterText(fields.at(1), 'freshline123');

    final Finder signInButton = find.widgetWithText(
      FilledButton,
      'Open Admin Dashboard',
    );
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin dashboard opens admin team management screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FreshlineApp(
        catalogService: MemoryCatalogService(),
        notificationsService: MemoryNotificationsService(),
        platformRepository: MemoryPlatformRepository(),
        salonOwnerRepository: MemorySalonOwnerRepository(),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Get Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Admin'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin.com');
    await tester.enterText(fields.at(1), 'freshline123');

    final Finder signInButton = find.widgetWithText(
      FilledButton,
      'Open Admin Dashboard',
    );
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Admins').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Admin Team'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add Admin'), findsOneWidget);
    expect(find.text('Storage'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin users screen shows customer-only multi-field search', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FreshlineApp(
        catalogService: MemoryCatalogService(),
        notificationsService: MemoryNotificationsService(),
        platformRepository: MemoryPlatformRepository(),
        salonOwnerRepository: MemorySalonOwnerRepository(),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Get Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Admin'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin.com');
    await tester.enterText(fields.at(1), 'freshline123');

    final Finder signInButton = find.widgetWithText(
      FilledButton,
      'Open Admin Dashboard',
    );
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Users').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Customers'), findsWidgets);
    expect(find.text('Search name, phone, or email'), findsOneWidget);
    expect(find.text('Alex Freshline'), findsOneWidget);
    expect(find.text('Freshline Admin Owner'), findsNothing);
    expect(find.text('Salon Owners'), findsNothing);

    await tester.enterText(find.byType(TextField), 'alex');
    await tester.pumpAndSettle();

    expect(find.text('Alex Freshline'), findsOneWidget);
    expect(find.text('Freshline Admin Owner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin sign-in with mouse stays stable', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FreshlineApp(
        catalogService: MemoryCatalogService(),
        notificationsService: MemoryNotificationsService(),
        platformRepository: MemoryPlatformRepository(),
        salonOwnerRepository: MemorySalonOwnerRepository(),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Get Start'));
    await tester.pumpAndSettle();

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(mouse.removePointer);

    final Finder adminChip = find.widgetWithText(ChoiceChip, 'Admin');
    Offset target = tester.getCenter(adminChip);
    await mouse.addPointer(location: target);
    await tester.pump();
    await mouse.moveTo(target);
    await tester.pump();
    await mouse.down(target);
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin.com');
    await tester.enterText(fields.at(1), 'freshline123');

    final Finder signInButton = find.widgetWithText(
      FilledButton,
      'Open Admin Dashboard',
    );
    await tester.ensureVisible(signInButton);
    target = tester.getCenter(signInButton);
    await mouse.moveTo(target);
    await tester.pump();
    await mouse.down(target);
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
