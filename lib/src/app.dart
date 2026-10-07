import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'config/app_config.dart';
import 'data/app_data.dart';
import 'services/appointment_reminder_service.dart';
import 'services/biometric_auth_service.dart';
import 'services/catalog_service.dart';
import 'services/groq_service.dart';
import 'services/notifications_service.dart';
import 'services/platform_uri_service.dart';
import 'services/platform_repository.dart';
import 'services/push_notifications_service.dart';
import 'services/salon_owner_service.dart';
import 'theme/app_theme.dart';
import 'utils/bahrain_locations.dart';
import 'utils/bahrain_phone.dart';

part 'management_shells.dart';

const String _prefsLanguageCodeKey = 'freshline.language_code';
const String _prefsSessionUserKey = 'freshline.session_user';
const String _prefsOnboardingCompletedKey = 'freshline.onboarding_completed';
const String _prefsBiometricEnabledPrefix = 'freshline.biometric_enabled.';
const String _prefsThemeModeKey = 'freshline.theme_mode';
const String _prefsHighContrastKey = 'freshline.high_contrast';
const String _prefsTextScaleFactorKey = 'freshline.text_scale_factor';

typedef AsyncBoolCallback = Future<void> Function(bool value);

bool _isArabicLanguageCode(String languageCode) {
  return languageCode.trim().toUpperCase() == 'AR';
}

Locale _localeForLanguageCode(String languageCode) {
  return Locale(_isArabicLanguageCode(languageCode) ? 'ar' : 'en');
}

String? _otpDispatchMessage(
  BuildContext context,
  AuthOtpDispatchResult? result,
) {
  if (result == null || !result.usedLocalFallback) {
    return null;
  }
  final String previewCode = (result.previewCode ?? '').trim();
  if (previewCode.isEmpty) {
    return _tr(
      context,
      'Email delivery is not configured on this build yet, so FreshLine switched to local OTP fallback for this session.',
      'إرسال البريد غير مفعّل في هذه النسخة حالياً، لذلك حوّل فريش لاين التحقق إلى رمز محلي مؤقت لهذه الجلسة.',
    );
  }
  return _tr(
    context,
    'Email delivery is not configured on this build yet. Use this local test code for now: $previewCode',
    'إرسال البريد غير مفعّل في هذه النسخة حالياً. استخدم رمز الاختبار المحلي مؤقتاً: $previewCode',
  );
}

Widget _otpDispatchBanner(BuildContext context, AuthOtpDispatchResult? result) {
  final String message = _otpDispatchMessage(context, result) ?? '';
  if (message.isEmpty) {
    return const SizedBox.shrink();
  }
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppPalette.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppPalette.primary.withValues(alpha: 0.18)),
    ),
    child: Text(
      message,
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: AppPalette.mutedForeground,
      ),
    ),
  );
}

bool _isOtpRateLimitMessage(String message) {
  final String normalized = message.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return normalized.contains('otp_rate_limit') ||
      normalized.contains('too many otp requests') ||
      (normalized.contains('too many') && normalized.contains('otp')) ||
      normalized.contains('for security purposes') ||
      normalized.contains('rate limit') ||
      normalized.contains('rate-limit') ||
      normalized.contains('429');
}

bool _isEmailRateLimitMessage(String message) {
  final String normalized = message.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  if (!(normalized.contains('rate limit') ||
      normalized.contains('rate-limit') ||
      normalized.contains('too many') ||
      normalized.contains('429'))) {
    return false;
  }
  return normalized.contains('email') ||
      normalized.contains('signup') ||
      normalized.contains('sign up') ||
      normalized.contains('confirmation') ||
      normalized.contains('verify');
}

bool _isOtpBackendNotSetupMessage(String message) {
  final String normalized = message.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return normalized.contains('otp_backend_not_setup') ||
      normalized.contains('requested function was not found') ||
      normalized.contains('function was not found') ||
      normalized.contains('requested function') ||
      normalized.contains('create_auth_email_otp') ||
      normalized.contains('verify_auth_email_otp');
}

String _presentableOtpError(BuildContext context, Object error) {
  final String message =
      error.toString().replaceFirst('Bad state: ', '').trim();
  if (_isOtpRateLimitMessage(message)) {
    return _tr(
      context,
      'Please try again in an hour.',
      'يرجى المحاولة بعد ساعة.',
    );
  }
  if (_isOtpBackendNotSetupMessage(message)) {
    return _tr(
      context,
      'OTP is not set up on this Supabase project yet. Run the SQL in `supabase/freshline_schema.sql` and deploy the Edge Functions `send-auth-otp` + `verify-auth-otp`, then try again.',
      'التحقق بالرمز (OTP) غير مُعدّ في مشروع Supabase بعد. شغّل ملف SQL الموجود في `supabase/freshline_schema.sql` ثم انشر دوال Edge `send-auth-otp` و `verify-auth-otp` وبعدها جرّب مرة أخرى.',
    );
  }
  return message;
}

String _presentableAuthError(BuildContext context, Object error) {
  final String message =
      error.toString().replaceFirst('Bad state: ', '').trim();
  if (_isOtpRateLimitMessage(message)) {
    return _presentableOtpError(context, error);
  }
  if (_isEmailRateLimitMessage(message)) {
    return _tr(
      context,
      'Email sending is temporarily rate limited. Please try again in an hour.',
      'تم تقييد إرسال البريد مؤقتاً. يرجى المحاولة بعد ساعة.',
    );
  }
  return message;
}

String _deviceLanguageCode() {
  final String code =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return _isArabicLanguageCode(code) ? 'AR' : 'EN';
}

bool _isArabicContext(BuildContext context) {
  return Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
}

String _tr(BuildContext context, String english, String arabic) {
  return _isArabicContext(context) ? arabic : english;
}

String _trForLanguage(String languageCode, String english, String arabic) {
  return _isArabicLanguageCode(languageCode) ? arabic : english;
}

const Map<String, String> _arabicDisplayTranslations = <String, String>{
  'Fresh Look, Fresh Start': 'إطلالة جديدة وبداية جديدة',
  '20% off your first visit': 'خصم 20٪ على أول زيارة',
  'Premium Salon Experience': 'تجربة صالون فاخرة',
  'Book now & save': 'احجز الآن ووفر',
  'Freshline Signature Lounge': 'فريش لاين سيغنتشر لاونج',
  'Trim & Tone Studio': 'استوديو تريم آند تون',
  'Royal Blade House': 'رويال بليد هاوس',
  'Premium Hair Kit': 'مجموعة الشعر الفاخرة',
  'Styling Cream': 'كريم التصفيف',
  'Argan Hair Serum': 'سيروم الأرغان للشعر',
  'Beard Care Balm': 'بلسم العناية باللحية',
  'Hair Care': 'العناية بالشعر',
  'Styling': 'التصفيف',
  'Treatment': 'العلاج',
  'Beard Care': 'العناية باللحية',
  'General': 'عام',
  'Luxury grooming lounge with express appointments, premium beard care, and home-service specialists.':
      'صالة عناية فاخرة بمواعيد سريعة وخدمة لحية مميزة ومتخصصين في الخدمة المنزلية.',
  'Modern barber and styling studio focused on fades, color refresh, and quick booking slots.':
      'استوديو حلاقة وتصفيف عصري يركز على تدريجات الشعر وتجديد اللون والمواعيد السريعة.',
  'High-end barber house with package bundles, grooming treatments, and aftercare products.':
      'بيت حلاقة فاخر يقدم باقات متكاملة وعلاجات عناية ومنتجات ما بعد الخدمة.',
  'A salon-style hair kit with cleansing, treatment, and finishing essentials for daily use.':
      'مجموعة شعر بأسلوب الصالونات تضم أساسيات التنظيف والعلاج واللمسة النهائية للاستخدام اليومي.',
  'A lightweight styling cream that adds hold, texture, and a clean finish without stiffness.':
      'كريم تصفيف خفيف يمنح ثباتاً وملمساً ولمسة نهائية نظيفة من دون قساوة.',
  'A nourishing argan serum made to smooth frizz, add shine, and support dry hair recovery.':
      'سيروم أرغان مغذٍ لتنعيم الهيشان وإضافة اللمعان ودعم تعافي الشعر الجاف.',
  'Softening beard balm designed for everyday grooming and shine.':
      'بلسم ملطف للحية مصمم للعناية اليومية وإضافة اللمعان.',
  'A FreshLine salon with appointment booking, service packages, and product recommendations.':
      'صالون من فريش لاين يوفّر الحجز والباقات وتوصيات المنتجات.',
  'A FreshLine product selected to support hair care, styling, and salon aftercare.':
      'منتج من فريش لاين تم اختياره لدعم العناية بالشعر والتصفيف وما بعد الخدمة.',
  'Seef': 'السيف',
  'Adliya': 'العدلية',
  'Juffair': 'الجفير',
  'Manama': 'المنامة',
  'Nearby': 'قريب',
  'Road 2819, Seef District, Manama': 'طريق 2819، منطقة السيف، المنامة',
  'Road 3801, Adliya, Manama': 'طريق 3801، العدلية، المنامة',
  'Al Shabab Ave, Juffair, Manama': 'شارع الشباب، الجفير، المنامة',
  'Luxury grooming lounge with premium cuts, beard care, and home-service appointments.':
      'صالة عناية راقية تقدم قصات مميزة وخدمة لحية ومواعيد منزلية.',
  'Modern barber studio focused on fades, styling, and quick appointment slots.':
      'استوديو حلاقة حديث يركز على التدريجات والتصفيف والمواعيد السريعة.',
  'High-end barber house with treatment bundles and aftercare recommendations.':
      'بيت حلاقة فاخر يقدم باقات علاجية وتوصيات للعناية اللاحقة.',
  'A complete daily hair-care kit for wash, treatment, and finish.':
      'مجموعة يومية متكاملة للعناية بالشعر تشمل الغسل والعلاج واللمسة النهائية.',
  'Lightweight styling cream with clean hold and natural texture.':
      'كريم تصفيف خفيف بثبات نظيف وملمس طبيعي.',
  'Nourishing serum that smooths frizz and supports dry hair recovery.':
      'سيروم مغذٍ ينعّم الهيشان ويدعم تعافي الشعر الجاف.',
  'Basic Cut': 'قص أساسي',
  'Premium Styling': 'تصفيف فاخر',
  'VIP Package': 'باقة كبار الشخصيات',
  'Professional haircut with wash': 'قص شعر احترافي مع غسيل',
  'Cut, wash, style & finish': 'قص وغسيل وتصفيف ولمسة نهائية',
  'Full service: cut, color, style, beard': 'خدمة كاملة: قص ولون وتصفيف ولحية',
  'Haircut': 'قص شعر',
  'Beard Trim': 'تشذيب اللحية',
  'Hair Color': 'صبغة شعر',
  'Hot Towel Shave': 'حلاقة بمنشفة ساخنة',
  'Deep Conditioning': 'ترطيب عميق',
  'Home Visit': 'زيارة منزلية',
  'Kids Cut': 'قص أطفال',
  'Full Service': 'خدمة كاملة',
  'Spa Treatment': 'علاج سبا',
  '30 min': '30 دقيقة',
  '60 min': '60 دقيقة',
  '90 min': '90 دقيقة',
  '25 min': '25 دقيقة',
  '20 min': '20 دقيقة',
  '40 min': '40 دقيقة',
  'All Products': 'كل المنتجات',
  'Search products': 'ابحث عن المنتجات',
  'Filter': 'التصفية',
  'All': 'الكل',
  'Top Rated': 'الأعلى تقييماً',
  'No products found': 'لا توجد منتجات',
  'Try another search term or change the filter to see more products.':
      'جرّب كلمة بحث أخرى أو غيّر التصفية لعرض المزيد من المنتجات.',
  'Clear Search': 'مسح البحث',
  'Price': 'السعر',
  'Rating': 'التقييم',
  'Stock': 'المخزون',
  'Out of stock': 'نفد المخزون',
  'Out Of Stock': 'نفد المخزون',
  'Add To Cart': 'أضف إلى السلة',
  'Cart': 'السلة',
  'Products only. Cart items must come from one salon at a time, and salon bookings continue in their own checkout flow.':
      'هذه السلة للمنتجات فقط. يجب أن تكون المنتجات من صالون واحد في كل مرة، بينما تبقى حجوزات الصالون في مسار دفع منفصل.',
  'Your cart is empty': 'سلتك فارغة',
  'Add products from the marketplace, then come back here to review them.':
      'أضف منتجات من المتجر ثم عد إلى هنا لمراجعتها.',
  'Continue Shopping': 'متابعة التسوق',
  'All Salons': 'كل الصالونات',
  'Search salons': 'ابحث عن الصالونات',
  'Closest to Me': 'الأقرب إلي',
  'Highest Rated': 'الأعلى تقييماً',
  'Lower Price': 'السعر الأقل',
  'No salons found': 'لا توجد صالونات',
  'Try another search or switch the drop-down filter.':
      'جرّب بحثاً آخر أو غيّر خيار التصفية.',
  'Salon Details': 'تفاصيل الصالون',
  'Near You': 'قريب منك',
  'A bit farther': 'أبعد قليلاً',
  'Home Service': 'خدمة منزلية',
  'Call': 'اتصال',
  'Open Map': 'افتح الخريطة',
  'Packages': 'الباقات',
  'Services': 'الخدمات',
  'This salon has no active packages yet.':
      'لا توجد باقات مفعلة لهذا الصالون حالياً.',
  'This salon has no active services yet.':
      'لا توجد خدمات مفعلة لهذا الصالون حالياً.',
  'Next': 'التالي',
  'Products from this salon': 'منتجات هذا الصالون',
  'Products are added to cart separately from salon bookings, and each cart can only contain products from one salon at a time.':
      'تُضاف المنتجات إلى السلة بشكل منفصل عن حجوزات الصالون، ويمكن أن تحتوي كل سلة على منتجات من صالون واحد فقط في كل مرة.',
  'This salon has no active products yet.':
      'لا توجد منتجات مفعلة لهذا الصالون حالياً.',
  'About this salon': 'عن هذا الصالون',
  'In Cart': 'في السلة',
  'Available in the product catalog': 'متوفر في كتالوج المنتجات',
  'Out of stock for customers': 'غير متوفر حالياً للعملاء',
  'Platform product': 'منتج المنصة',
  'Platform products': 'منتجات المنصة',
  'Salon product': 'منتج صالون',
  'Visible to customers': 'ظاهر للعملاء',
  'Active': 'نشط',
  'Inactive': 'غير نشط',
  'Live': 'ظاهر',
  'Out': 'نفد',
  'Hidden': 'مخفي',
  'Open Salon': 'افتح الصالون',
  'No matches found': 'لا توجد نتائج',
  'No salons yet': 'لا توجد صالونات بعد',
  'Try another salon, owner, phone number, or email.':
      'جرّب البحث باسم صالون آخر أو المالك أو رقم الهاتف أو البريد الإلكتروني.',
  'Approved salons will appear here once applications are completed.':
      'ستظهر الصالونات المعتمدة هنا بعد اكتمال الطلبات.',
  'Owner': 'المالك',
  'Owner Email': 'بريد المالك',
  'Owner Phone': 'هاتف المالك',
  'Salon Phone': 'هاتف الصالون',
  'City': 'المدينة',
  'Address': 'العنوان',
  'Price Tier': 'فئة السعر',
  'Supported': 'مدعوم',
  'No': 'لا',
  'Status': 'الحالة',
  'Subscription': 'الاشتراك',
  'This salon does not have an active subscription record yet.':
      'لا يوجد سجل اشتراك فعال لهذا الصالون بعد.',
  'Plan': 'الخطة',
  'Amount': 'المبلغ',
  'Expires': 'ينتهي في',
  'Auto Renew': 'التجديد التلقائي',
  'On': 'مفعل',
  'Off': 'موقوف',
  'About': 'نبذة',
  'Navigate': 'تنقل',
  'Add More': 'أضف المزيد',
  'No subscription': 'لا يوجد اشتراك',
  'Not available': 'غير متوفر',
  'Not set': 'غير محدد',
  '20% welcome discount for the first order only.':
      'خصم ترحيبي 20٪ للطلب الأول فقط.',
  'Salon Products': 'منتجات الصالون',
  'FreshLine Salon': 'صالون فريش لاين',
  'FreshLine Product': 'منتج فريش لاين',
  'Seef District, Manama, Bahrain': 'منطقة السيف، المنامة، البحرين',
  'Daily · 9:00 AM to 10:00 PM': 'يومياً · 9:00 ص إلى 10:00 م',
  'No saved cards yet. Add a new card to continue.':
      'لا توجد بطاقات محفوظة بعد. أضف بطاقة جديدة للمتابعة.',
  'Account Protection': 'حماية الحساب',
  'Keep your email, password, and saved account details secure and update them only from trusted devices.':
      'حافظ على أمان بريدك الإلكتروني وكلمة المرور وبيانات حسابك المحفوظة، وحدّثها فقط من أجهزة موثوقة.',
  'Saved Cards & Payments': 'البطاقات المحفوظة والمدفوعات',
  'Only payment-related card details should appear in your account, and payment confirmations should match your booking or order history.':
      'يجب أن تظهر في حسابك فقط تفاصيل البطاقات المرتبطة بالدفع، وأن تتطابق تأكيدات الدفع مع سجل حجوزاتك أو طلباتك.',
  'Location Access': 'الوصول إلى الموقع',
  'Location is used to show nearby salons, route navigation, and whether a barber is close to you.':
      'يُستخدم الموقع لإظهار الصالونات القريبة والتنقل ومعرفة ما إذا كان الحلاق قريباً منك.',
  'AI & Support Usage': 'استخدام الذكاء الاصطناعي والدعم',
  'AI answers should stay related to the app and barber services, while support links should open official Freshline channels only.':
      'يجب أن تبقى إجابات الذكاء الاصطناعي مرتبطة بالتطبيق وخدمات الحلاقة، بينما تفتح روابط الدعم قنوات فريش لاين الرسمية فقط.',
  'In order': 'قيد التنفيذ',
  'Preparing': 'قيد التجهيز',
  'Delivered': 'تم التسليم',
  'Completed': 'مكتمل',
  'Confirmed': 'مؤكد',
  'Cancelled': 'ملغي',
  'Go to saloon': 'الذهاب إلى الصالون',
  'Come to you': 'نأتي إليك',
  'Home delivery': 'توصيل منزلي',
  'Freshline Delivery': 'توصيل فريش لاين',
  'Freshline Employee': 'موظف فريش لاين',
};

String _localizedDisplayText(BuildContext context, String value) {
  return _localizedDisplayTextForLanguage(
    _isArabicContext(context) ? 'AR' : 'EN',
    value,
  );
}

String _localizedDisplayTextForLanguage(String languageCode, String value) {
  if (!_isArabicLanguageCode(languageCode)) {
    return value;
  }
  final String trimmedValue = value.trim();
  if (trimmedValue.isEmpty) {
    return value;
  }
  return _arabicDisplayTranslations[trimmedValue] ?? value;
}

extension _LocalizedSalonText on Salon {
  String localizedName(BuildContext context) =>
      localizedNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (nameAr ?? '').trim().isNotEmpty) {
      return nameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, name);
  }

  String localizedLocation(BuildContext context) =>
      localizedLocationForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedLocationForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (locationAr ?? '').trim().isNotEmpty) {
      return locationAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, location);
  }

  String localizedDescription(BuildContext context) =>
      localizedDescriptionForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedDescriptionForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (descriptionAr ?? '').trim().isNotEmpty) {
      return descriptionAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, description);
  }

  String localizedAddress(BuildContext context) =>
      localizedAddressForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedAddressForLanguage(String languageCode) {
    final String rawAddress = (address ?? '').trim();
    if (_isArabicLanguageCode(languageCode) &&
        (addressAr ?? '').trim().isNotEmpty) {
      return addressAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, rawAddress);
  }
}

extension _LocalizedProductText on Product {
  String localizedName(BuildContext context) =>
      localizedNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (nameAr ?? '').trim().isNotEmpty) {
      return nameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, name);
  }

  String localizedCategory(BuildContext context) =>
      localizedCategoryForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedCategoryForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (categoryAr ?? '').trim().isNotEmpty) {
      return categoryAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, category);
  }

  String localizedDescription(BuildContext context) =>
      localizedDescriptionForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedDescriptionForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (descriptionAr ?? '').trim().isNotEmpty) {
      return descriptionAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, description);
  }
}

extension _LocalizedServicePackageText on ServicePackage {
  String localizedName(BuildContext context) =>
      localizedNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (nameAr ?? '').trim().isNotEmpty) {
      return nameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, name);
  }

  String localizedDescription(BuildContext context) =>
      localizedDescriptionForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedDescriptionForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (descriptionAr ?? '').trim().isNotEmpty) {
      return descriptionAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, description);
  }

  String localizedDuration(BuildContext context) =>
      _localizedDisplayText(context, duration);
}

extension _LocalizedServiceItemText on ServiceItem {
  String localizedName(BuildContext context) =>
      localizedNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (nameAr ?? '').trim().isNotEmpty) {
      return nameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, name);
  }

  String localizedDescription(BuildContext context) =>
      localizedDescriptionForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedDescriptionForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (descriptionAr ?? '').trim().isNotEmpty) {
      return descriptionAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, description);
  }

  String localizedDuration(BuildContext context) =>
      _localizedDisplayText(context, duration);
}

extension _LocalizedSubscriptionPlanText on SubscriptionPlan {
  String localizedName(BuildContext context) =>
      localizedNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (nameAr ?? '').trim().isNotEmpty) {
      return nameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, name);
  }

  List<String> localizedFeatures(BuildContext context) =>
      localizedFeaturesForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  List<String> localizedFeaturesForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) && featuresAr.isNotEmpty) {
      return featuresAr;
    }
    return features
        .map(
          (String feature) =>
              _localizedDisplayTextForLanguage(languageCode, feature),
        )
        .toList(growable: false);
  }
}

extension _LocalizedPromoCouponText on PromoCouponRecord {
  String? localizedDescription(BuildContext context) =>
      localizedDescriptionForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String? localizedDescriptionForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (descriptionAr ?? '').trim().isNotEmpty) {
      return descriptionAr!.trim();
    }
    final String text = (description ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    return _localizedDisplayTextForLanguage(languageCode, text);
  }
}

extension _LocalizedAppRoleText on AppRole {
  String localizedLabel(BuildContext context) {
    switch (this) {
      case AppRole.customer:
        return _tr(context, 'Customer', 'عميل');
      case AppRole.salonOwner:
        return _tr(context, 'Salon Owner', 'مالك صالون');
      case AppRole.employee:
        return _tr(context, 'Employee', 'موظف');
      case AppRole.admin:
        return _tr(context, 'Admin', 'مشرف');
    }
  }
}

extension _LocalizedSalonRequestStatusText on SalonRequestStatus {
  String localizedLabel(BuildContext context) {
    switch (this) {
      case SalonRequestStatus.pending:
        return _tr(context, 'Pending Review', 'قيد المراجعة');
      case SalonRequestStatus.approved:
        return _tr(context, 'Approved', 'موافق عليه');
      case SalonRequestStatus.rejected:
        return _tr(context, 'Rejected', 'مرفوض');
      case SalonRequestStatus.needsInfo:
        return _tr(context, 'Needs Info', 'بحاجة إلى معلومات');
    }
  }
}

extension _LocalizedSubscriptionCycleOptionText on SubscriptionCycleOption {
  String localizedLabel(BuildContext context) {
    switch (this) {
      case SubscriptionCycleOption.monthly:
        return _tr(context, 'Monthly', 'شهري');
      case SubscriptionCycleOption.yearly:
        return _tr(context, 'Yearly', 'سنوي');
    }
  }
}

extension _LocalizedBookingSelectionText on BookingSelection {
  String localizedServiceName(BuildContext context) =>
      localizedServiceNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedServiceNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (serviceNameAr ?? '').trim().isNotEmpty) {
      return serviceNameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, serviceName);
  }

  String localizedSalonName(BuildContext context) =>
      localizedSalonNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedSalonNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (salonNameAr ?? '').trim().isNotEmpty) {
      return salonNameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, salonName);
  }
}

extension _LocalizedUserOrderText on UserOrder {
  String localizedSalonName(BuildContext context) =>
      localizedSalonNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedSalonNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (salonNameAr ?? '').trim().isNotEmpty) {
      return salonNameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, salonName);
  }

  String localizedServiceName(BuildContext context) =>
      localizedServiceNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedServiceNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (serviceNameAr ?? '').trim().isNotEmpty) {
      return serviceNameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, serviceName);
  }

  String localizedEmployeeName(BuildContext context) =>
      localizedEmployeeNameForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedEmployeeNameForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (employeeNameAr ?? '').trim().isNotEmpty) {
      return employeeNameAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, employeeName);
  }

  String localizedVisitMode(BuildContext context) =>
      localizedVisitModeForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedVisitModeForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (visitModeAr ?? '').trim().isNotEmpty) {
      return visitModeAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, visitMode);
  }

  String localizedStatusLabel(BuildContext context) =>
      localizedStatusLabelForLanguage(_isArabicContext(context) ? 'AR' : 'EN');

  String localizedStatusLabelForLanguage(String languageCode) {
    if (_isArabicLanguageCode(languageCode) &&
        (statusLabelAr ?? '').trim().isNotEmpty) {
      return statusLabelAr!.trim();
    }
    return _localizedDisplayTextForLanguage(languageCode, statusLabel);
  }
}

class FreshlineApp extends StatefulWidget {
  const FreshlineApp({
    super.key,
    this.catalogService,
    this.notificationsService,
    this.platformRepository,
    this.salonOwnerRepository,
    this.biometricAuthService,
    this.pushNotificationsService,
  });

  final CatalogService? catalogService;
  final NotificationsService? notificationsService;
  final PlatformRepository? platformRepository;
  final SalonOwnerRepository? salonOwnerRepository;
  final BiometricAuthService? biometricAuthService;
  final PushNotificationsService? pushNotificationsService;

  @override
  State<FreshlineApp> createState() => _FreshlineAppState();
}

class _FreshlineAppState extends State<FreshlineApp>
    with WidgetsBindingObserver {
  bool _showSplash = true;
  bool _showOnboarding = true;
  AppUser? _currentUser;
  SalonRegistrationRequest? _salonOwnerRequest;
  ThemeMode _themeMode = ThemeMode.light;
  bool _highContrastEnabled = false;
  double _textScaleFactor = 1.0;
  String _languageCode = 'EN';
  bool _biometricLockEnabled = false;
  bool _biometricUnlocked = true;
  bool _isAuthenticatingBiometric = false;
  Timer? _timer;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final CatalogService _catalogService =
      widget.catalogService ?? SupabaseCatalogService();
  late final NotificationsService _notificationsService =
      widget.notificationsService ?? SupabaseNotificationsService();
  late final PlatformRepository _platformRepository =
      widget.platformRepository ?? SupabasePlatformRepository();
  late final SalonOwnerRepository _salonOwnerRepository =
      widget.salonOwnerRepository ?? SupabaseSalonOwnerRepository();
  late final BiometricAuthService _biometricAuthService =
      widget.biometricAuthService ?? DeviceBiometricAuthService();
  late final PushNotificationsService _pushNotificationsService =
      widget.pushNotificationsService ?? const NoopPushNotificationsService();
  List<AppNotificationItem> _sessionNotifications = <AppNotificationItem>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_hydratePlatformMediaDefaults());
    unawaited(_restoreAppState());
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_catalogService case final SupabaseCatalogService service) {
      service.dispose();
    }
    _notificationsService.dispose();
    _platformRepository.dispose();
    if (_salonOwnerRepository case final SupabaseSalonOwnerRepository service) {
      service.dispose();
    }
    _pushNotificationsService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentUser == null || !_biometricLockEnabled) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (mounted) {
        setState(() => _biometricUnlocked = false);
      }
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_requestBiometricUnlock());
    }
  }

  void _handleSignedIn(AppUser user) {
    final AppUser localizedUser = _applyLocalLanguageToUser(user);
    setState(() {
      _currentUser = localizedUser;
      _showOnboarding = false;
      _sessionNotifications = <AppNotificationItem>[];
      _biometricUnlocked = true;
      if (localizedUser.role != AppRole.salonOwner) {
        _salonOwnerRequest = null;
      }
    });
    unawaited(
      _refreshBiometricPreferenceForUser(localizedUser, unlockSession: true),
    );
    unawaited(_persistSession(localizedUser));
    unawaited(_persistLanguagePreference(_languageCode));
    unawaited(_persistOnboardingCompleted());
    unawaited(_configurePushNotificationsForUser(localizedUser));
    if (localizedUser.role == AppRole.salonOwner) {
      unawaited(_restoreSalonOwnerRequest(localizedUser));
    }
  }

  void _handleRegistered(AppUser user) {
    final AppUser localizedUser = _applyLocalLanguageToUser(user);
    setState(() {
      _currentUser = localizedUser;
      _showOnboarding = false;
      _salonOwnerRequest = null;
      _biometricLockEnabled = false;
      _biometricUnlocked = true;
      _sessionNotifications = <AppNotificationItem>[
        AppNotificationItem(
          title: 'Welcome to FreshLine',
          titleAr: 'مرحباً بك في فريش لاين',
          message: user.isEmailVerified
              ? 'Thanks for signing up. Your account is ready for bookings and product orders.'
              : 'Thanks for signing up. Your account is ready now, and you can verify your email later from Account Details.',
          messageAr: user.isEmailVerified
              ? 'شكراً لتسجيلك. أصبح حسابك جاهزاً للحجوزات وطلبات المنتجات.'
              : 'شكراً لتسجيلك. أصبح حسابك جاهزاً الآن ويمكنك التحقق من بريدك لاحقاً من تفاصيل الحساب.',
          icon: 'sparkles',
          unread: true,
        ),
      ];
    });
    unawaited(_persistSession(localizedUser));
    unawaited(_persistLanguagePreference(_languageCode));
    unawaited(_persistOnboardingCompleted());
    unawaited(_configurePushNotificationsForUser(localizedUser));
  }

  Future<void> _signIn({
    required AppRole role,
    required String email,
    required String password,
  }) async {
    if (role == AppRole.salonOwner) {
      try {
        final AppUser employeeUser = await _completeSignInFlow(
          role: AppRole.employee,
          email: email,
          password: password,
        );
        if (!mounted) {
          return;
        }
        _handleSignedIn(employeeUser);
        return;
      } catch (employeeError) {
        if (!_shouldTrySalonOwnerFallback(employeeError)) {
          rethrow;
        }
      }

      try {
        final AppUser ownerUser = await _completeSignInFlow(
          role: AppRole.salonOwner,
          email: email,
          password: password,
        );
        if (!mounted) {
          return;
        }
        _handleSignedIn(ownerUser);
        return;
      } catch (ownerError) {
        if (_signInErrorMessage(
          ownerError,
        ).toLowerCase().contains('not found')) {
          throw StateError('Salon account was not found.');
        }
        rethrow;
      }
    }

    final AppUser user = await _completeSignInFlow(
      role: role,
      email: email,
      password: password,
    );
    if (!mounted) {
      return;
    }
    _handleSignedIn(user);
  }

  Future<AppUser> _completeSignInFlow({
    required AppRole role,
    required String email,
    required String password,
  }) async {
    final SignInAttempt attempt = await _platformRepository.beginSignIn(
      role: role,
      email: email,
      password: password,
    );
    if (!attempt.requiresEmailOtp) {
      return attempt.user!;
    }

    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      throw StateError('Freshline could not open the verification screen.');
    }

    final AppUser? verifiedUser = await navigator.push<AppUser>(
      MaterialPageRoute<AppUser>(
        builder: (BuildContext context) => OtpChallengeScreen<AppUser>(
          email: attempt.challengeEmail!,
          title: _tr(context, 'Verify Your Sign In', 'تحقق من تسجيل الدخول'),
          subtitle: _tr(
            context,
            'Enter the 6-digit code we sent to ${_maskEmailAddress(attempt.challengeEmail!)} to finish signing in.',
            'أدخل رمز التحقق المكوّن من 6 أرقام الذي أرسلناه إلى ${_maskEmailAddress(attempt.challengeEmail!)} لإكمال تسجيل الدخول.',
          ),
          primaryActionLabel: _tr(context, 'Verify And Continue', 'تحقق وتابع'),
          resendSuccessMessage: _tr(
            context,
            'A fresh sign-in code was sent to your email.',
            'تم إرسال رمز تسجيل دخول جديد إلى بريدك الإلكتروني.',
          ),
          onVerify: (String code) {
            return _platformRepository.completeTwoFactorSignIn(
              email: attempt.challengeEmail!,
              profileId: attempt.challengeProfileId!,
              code: code,
            );
          },
          onResend: () async {
            await _platformRepository.beginSignIn(
              role: role,
              email: email,
              password: password,
            );
            return null;
          },
        ),
      ),
    );

    if (verifiedUser == null) {
      throw StateError('Sign in was cancelled before email verification.');
    }
    return verifiedUser;
  }

  bool _shouldTrySalonOwnerFallback(Object error) {
    final String message = _signInErrorMessage(error).toLowerCase();
    return message.contains('different role') || message.contains('not found');
  }

  String _signInErrorMessage(Object error) {
    return error.toString().replaceFirst('Bad state: ', '').trim();
  }

  Future<void> _registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String password,
    String? avatarPath,
  }) async {
    final AppUser user = await _platformRepository.registerCustomer(
      name: name,
      email: email,
      phone: phone,
      city: city,
      password: password,
      avatarPath: avatarPath,
    );
    if (!mounted) {
      return;
    }
    _handleRegistered(user);
  }

  Future<AuthOtpDispatchResult> _sendPasswordResetCode({
    required String email,
  }) {
    return _platformRepository.sendPasswordResetCode(email: email);
  }

  Future<String> _verifyPasswordResetCode({
    required String email,
    required String code,
  }) {
    return _platformRepository.verifyPasswordResetCode(
      email: email,
      code: code,
    );
  }

  Future<void> _completePasswordReset({
    required String email,
    required String verificationToken,
    required String newPassword,
  }) {
    return _platformRepository.completePasswordReset(
      email: email,
      verificationToken: verificationToken,
      newPassword: newPassword,
    );
  }

  Future<String?> _pickProfileImage({required String profileKey}) {
    return _platformRepository.pickAndUploadProfileImage(
      profileKey: profileKey,
    );
  }

  Future<void> _openSalonRegistration() async {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    final SalonOwnerSession? session = await navigator.push<SalonOwnerSession>(
      MaterialPageRoute<SalonOwnerSession>(
        builder: (BuildContext context) =>
            SalonOwnerOnboardingScreen(repository: _salonOwnerRepository),
      ),
    );

    if (session != null && mounted) {
      final AppUser sessionUser = _applyLocalLanguageToUser(session.user);
      setState(() {
        _showOnboarding = false;
        _currentUser = sessionUser;
        _salonOwnerRequest = session.request;
      });
      unawaited(_persistSession(sessionUser));
      unawaited(_persistLanguagePreference(_languageCode));
      unawaited(_persistOnboardingCompleted());
    }
  }

  void _completeOnboarding() {
    setState(() => _showOnboarding = false);
    unawaited(_persistOnboardingCompleted());
  }

  void _handleLogout() {
    final AppUser? previousUser = _currentUser;
    setState(() {
      _currentUser = null;
      _salonOwnerRequest = null;
      _sessionNotifications = <AppNotificationItem>[];
      _biometricLockEnabled = false;
      _biometricUnlocked = true;
      _isAuthenticatingBiometric = false;
    });
    if (previousUser != null) {
      unawaited(_removePushNotificationsForUser(previousUser));
    }
    unawaited(_clearSession(previousUser));
  }

  void _handleSalonRequestChanged(SalonRegistrationRequest? request) {
    setState(() => _salonOwnerRequest = request);
  }

  void _handleUserUpdated(AppUser user) {
    final AppUser localizedUser = _applyLocalLanguageToUser(user);
    setState(() {
      _currentUser = localizedUser;
    });
    unawaited(
      _refreshBiometricPreferenceForUser(localizedUser, unlockSession: true),
    );
    unawaited(_persistSession(localizedUser));
    unawaited(_persistLanguagePreference(_languageCode));
    unawaited(_configurePushNotificationsForUser(localizedUser));
  }

  void _handleThemeChanged(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
    unawaited(_persistThemePreference(_themeMode));
  }

  void _handleHighContrastChanged(bool isEnabled) {
    setState(() => _highContrastEnabled = isEnabled);
    unawaited(_persistHighContrastPreference(isEnabled));
  }

  void _handleTextScaleChanged(double value) {
    final double normalizedValue = _normalizeTextScaleFactor(value);
    setState(() => _textScaleFactor = normalizedValue);
    unawaited(_persistTextScalePreference(normalizedValue));
  }

  void _handleLanguageChanged(String languageCode) {
    final String normalizedLanguage = _normalizeLanguageCode(languageCode);
    final AppUser? currentUser = _currentUser;
    if (currentUser != null) {
      final AppUser localizedUser = _applyLocalLanguageToUser(
        currentUser,
        languageCode: normalizedLanguage,
      );
      setState(() {
        _languageCode = normalizedLanguage;
        _currentUser = localizedUser;
      });
      unawaited(_persistSession(localizedUser));
    } else {
      setState(() => _languageCode = normalizedLanguage);
    }
    unawaited(_persistLanguagePreference(normalizedLanguage));
  }

  String _normalizeLanguageCode(String languageCode) {
    return _isArabicLanguageCode(languageCode) ? 'AR' : 'EN';
  }

  AppUser _applyLocalLanguageToUser(AppUser user, {String? languageCode}) {
    return user.copyWith(
      preferredLanguage: _normalizeLanguageCode(languageCode ?? _languageCode),
      isEmailTwoFactorEnabled: false,
    );
  }

  String _biometricPreferenceKeyForUser(AppUser user) {
    final String identity = (user.profileId ?? user.email)
        .trim()
        .toLowerCase()
        .replaceAll(' ', '');
    return '$_prefsBiometricEnabledPrefix$identity';
  }

  Future<bool> _loadBiometricPreference(AppUser user) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      return preferences.getBool(_biometricPreferenceKeyForUser(user)) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistBiometricPreference(AppUser user, bool enabled) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setBool(_biometricPreferenceKeyForUser(user), enabled);
    } catch (_) {
      // Ignore local preference persistence failures.
    }
  }

  Future<void> _refreshBiometricPreferenceForUser(
    AppUser user, {
    required bool unlockSession,
  }) async {
    final bool enabled = await _loadBiometricPreference(user);
    if (!mounted || _currentUser?.profileId != user.profileId) {
      return;
    }
    setState(() {
      _biometricLockEnabled = enabled;
      _biometricUnlocked = !enabled || unlockSession;
    });
    if (enabled && !unlockSession) {
      unawaited(_requestBiometricUnlock());
    }
  }

  Future<void> _requestBiometricUnlock() async {
    final AppUser? user = _currentUser;
    if (user == null ||
        !_biometricLockEnabled ||
        _biometricUnlocked ||
        _isAuthenticatingBiometric) {
      return;
    }

    final bool supported = await _biometricAuthService.canAuthenticate();
    if (!supported) {
      if (!mounted) {
        return;
      }
      setState(() {
        _biometricLockEnabled = false;
        _biometricUnlocked = true;
      });
      await _persistBiometricPreference(user, false);
      return;
    }

    if (mounted) {
      setState(() => _isAuthenticatingBiometric = true);
    }
    final bool success = await _biometricAuthService.authenticate(
      reason: _trForLanguage(
        _languageCode,
        'Unlock Freshline with your device biometrics.',
        'افتح فريش لاين باستخدام بصمة الجهاز أو التحقق الحيوي.',
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isAuthenticatingBiometric = false;
      _biometricUnlocked = success;
    });
  }

  Future<void> _handleBiometricLockChanged(bool enabled) async {
    final AppUser? user = _currentUser;
    if (user == null) {
      return;
    }

    final BuildContext? context = _navigatorKey.currentContext;
    if (!enabled) {
      await _biometricAuthService.stopAuthentication();
      if (!mounted) {
        return;
      }
      setState(() {
        _biometricLockEnabled = false;
        _biometricUnlocked = true;
      });
      await _persistBiometricPreference(user, false);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                context,
                'Biometric lock was turned off.',
                'تم إيقاف قفل البصمة.',
              ),
            ),
          ),
        );
      }
      return;
    }

    final bool supported = await _biometricAuthService.canAuthenticate();
    if (!supported) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                context,
                'Biometric authentication is not available on this device.',
                'المصادقة بالبصمة غير متاحة على هذا الجهاز.',
              ),
            ),
          ),
        );
      }
      return;
    }

    final bool success = await _biometricAuthService.authenticate(
      reason: _trForLanguage(
        _languageCode,
        'Confirm your identity to enable biometric lock.',
        'أكد هويتك لتفعيل قفل البصمة.',
      ),
    );
    if (!success) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                context,
                'Biometric verification was not completed.',
                'لم تكتمل المصادقة بالبصمة.',
              ),
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _biometricLockEnabled = true;
      _biometricUnlocked = true;
    });
    await _persistBiometricPreference(user, true);
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Biometric lock is enabled for this device.',
              'تم تفعيل قفل البصمة لهذا الجهاز.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _restoreAppState() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String savedLanguage = _normalizeLanguageCode(
        preferences.getString(_prefsLanguageCodeKey) ?? _deviceLanguageCode(),
      );
      final String savedThemeMode =
          preferences.getString(_prefsThemeModeKey) ?? 'light';
      final bool savedHighContrast =
          preferences.getBool(_prefsHighContrastKey) ?? false;
      final double savedTextScale = _normalizeTextScaleFactor(
        preferences.getDouble(_prefsTextScaleFactorKey) ?? 1.0,
      );
      final bool onboardingCompleted =
          preferences.getBool(_prefsOnboardingCompletedKey) ?? false;
      final String rawUser = preferences.getString(_prefsSessionUserKey) ?? '';
      AppUser? restoredUser;
      if (rawUser.trim().isNotEmpty) {
        try {
          restoredUser = AppUser.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(rawUser) as Map<dynamic, dynamic>,
            ),
          );
        } catch (_) {
          restoredUser = null;
        }
      }

      if (!mounted) {
        return;
      }

      final AppUser? localizedRestoredUser = restoredUser == null
          ? null
          : _applyLocalLanguageToUser(
              restoredUser,
              languageCode: savedLanguage,
            );

      setState(() {
        _languageCode = savedLanguage;
        _themeMode = savedThemeMode == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light;
        _highContrastEnabled = savedHighContrast;
        _textScaleFactor = savedTextScale;
        _showOnboarding = !onboardingCompleted;
        _biometricLockEnabled = false;
        _biometricUnlocked = localizedRestoredUser == null;
        if (localizedRestoredUser != null) {
          _currentUser = localizedRestoredUser;
          _showOnboarding = false;
          if (localizedRestoredUser.role != AppRole.salonOwner) {
            _salonOwnerRequest = null;
          }
        }
      });

      if (localizedRestoredUser?.role == AppRole.salonOwner) {
        unawaited(_restoreSalonOwnerRequest(localizedRestoredUser!));
      }
      if (localizedRestoredUser != null) {
        unawaited(_validateRestoredSession(localizedRestoredUser));
        unawaited(
          _refreshBiometricPreferenceForUser(
            localizedRestoredUser,
            unlockSession: false,
          ),
        );
        unawaited(_configurePushNotificationsForUser(localizedRestoredUser));
      }
    } catch (_) {
      // Keep boot resilient if local preferences are unavailable.
    }
  }

  Future<void> _validateRestoredSession(AppUser restoredUser) async {
    try {
      final AppUser refreshed = await _platformRepository.refreshUser(
        user: restoredUser,
      );
      if (!mounted || _currentUser?.profileId != restoredUser.profileId) {
        return;
      }
      setState(() => _currentUser = refreshed.copyWith(
        preferredLanguage: restoredUser.preferredLanguage,
        isEmailTwoFactorEnabled: restoredUser.isEmailTwoFactorEnabled,
      ));
    } catch (_) {
      if (!mounted || _currentUser?.profileId != restoredUser.profileId) {
        return;
      }
      await _clearSession(restoredUser);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUser = null;
        _salonOwnerRequest = null;
        _biometricLockEnabled = false;
        _biometricUnlocked = true;
      });
    }
  }

  Future<void> _hydratePlatformMediaDefaults() async {
    try {
      await _platformRepository.loadPlatformMediaDefaults();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Keep default fallback images if Supabase defaults are not reachable.
    }
  }

  Future<void> _configurePushNotificationsForUser(AppUser user) async {
    final String profileId = user.profileId?.trim() ?? '';
    if (profileId.isEmpty) {
      return;
    }

    await _pushNotificationsService.configureForUser(
      user: user,
      onTokenSync: (String token) {
        return _platformRepository.syncDevicePushToken(
          user: user,
          token: token,
        );
      },
      onForegroundMessage: (RemoteMessage message) {
        final String messageTitle = message.notification?.title?.trim() ?? '';
        final String title = messageTitle.isNotEmpty
            ? messageTitle
            : _trForLanguage(
                user.preferredLanguage,
                'New notification',
                'إشعار جديد',
              );
        final String body = message.notification?.body?.trim() ?? '';
        if (!mounted) {
          return;
        }
        setState(() {
          _sessionNotifications.insert(
            0,
            AppNotificationItem(
              title: title,
              titleAr: title,
              message: body,
              messageAr: body,
              icon: 'sparkles',
              unread: true,
            ),
          );
        });
      },
      onMessageOpenedApp: (RemoteMessage _) {
        // The app already opens normally; inbox data is still loaded from Supabase.
      },
    );
  }

  Future<void> _removePushNotificationsForUser(AppUser user) async {
    final String profileId = user.profileId?.trim() ?? '';
    if (profileId.isEmpty) {
      return;
    }

    await _pushNotificationsService.removeCurrentToken(
      user: user,
      onTokenRemove: (String token) {
        return _platformRepository.removeDevicePushToken(
          user: user,
          token: token,
        );
      },
    );
  }

  Future<void> _restoreSalonOwnerRequest(AppUser user) async {
    try {
      final SalonRegistrationRequest? request = await _salonOwnerRepository
          .loadLatestRequest(owner: user);
      if (!mounted || _currentUser?.profileId != user.profileId) {
        return;
      }
      setState(() => _salonOwnerRequest = request);
    } catch (_) {
      // Session restore should not fail because request sync failed.
    }
  }

  Future<void> _persistSession(AppUser user) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setString(
        _prefsSessionUserKey,
        jsonEncode(user.toJson()),
      );
    } catch (_) {
      // Local caching should not block user flows.
    }
  }

  Future<void> _clearSession([AppUser? previousUser]) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.remove(_prefsSessionUserKey);
      if (previousUser != null) {
        await preferences.remove(_biometricPreferenceKeyForUser(previousUser));
      }
    } catch (_) {
      // Ignore cache cleanup failures.
    }
  }

  Future<void> _persistLanguagePreference(String languageCode) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setString(
        _prefsLanguageCodeKey,
        _normalizeLanguageCode(languageCode),
      );
    } catch (_) {
      // Ignore local preference persistence failures.
    }
  }

  Future<void> _persistThemePreference(ThemeMode themeMode) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setString(
        _prefsThemeModeKey,
        themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // Ignore local preference persistence failures.
    }
  }

  Future<void> _persistHighContrastPreference(bool isEnabled) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setBool(_prefsHighContrastKey, isEnabled);
    } catch (_) {
      // Ignore local preference persistence failures.
    }
  }

  Future<void> _persistTextScalePreference(double value) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setDouble(
        _prefsTextScaleFactorKey,
        _normalizeTextScaleFactor(value),
      );
    } catch (_) {
      // Ignore local preference persistence failures.
    }
  }

  Future<void> _persistOnboardingCompleted() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setBool(_prefsOnboardingCompletedKey, true);
    } catch (_) {
      // Ignore local preference persistence failures.
    }
  }

  Widget _buildSignedInShell() {
    final AppUser user = _currentUser!;
    switch (user.role) {
      case AppRole.customer:
        return RootShell(
          user: user,
          onLogout: _handleLogout,
          catalogService: _catalogService,
          notificationsService: _notificationsService,
          platformRepository: _platformRepository,
          initialNotifications: _sessionNotifications,
          onUserChanged: _handleUserUpdated,
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _handleThemeChanged,
          isHighContrast: _highContrastEnabled,
          onHighContrastChanged: _handleHighContrastChanged,
          textScaleFactor: _textScaleFactor,
          onTextScaleChanged: _handleTextScaleChanged,
          selectedLanguage: _languageCode,
          onLanguageChanged: _handleLanguageChanged,
          isBiometricLockEnabled: _biometricLockEnabled,
          onBiometricLockChanged: _handleBiometricLockChanged,
        );
      case AppRole.salonOwner:
        return SalonOwnerShell(
          user: user,
          onLogout: _handleLogout,
          repository: _salonOwnerRepository,
          platformRepository: _platformRepository,
          notificationsService: _notificationsService,
          initialRequest: _salonOwnerRequest,
          onRequestChanged: _handleSalonRequestChanged,
          onUserChanged: _handleUserUpdated,
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _handleThemeChanged,
          isHighContrast: _highContrastEnabled,
          onHighContrastChanged: _handleHighContrastChanged,
          textScaleFactor: _textScaleFactor,
          onTextScaleChanged: _handleTextScaleChanged,
          selectedLanguage: _languageCode,
          onLanguageChanged: _handleLanguageChanged,
          isBiometricLockEnabled: _biometricLockEnabled,
          onBiometricLockChanged: _handleBiometricLockChanged,
        );
      case AppRole.employee:
        return EmployeeShell(
          user: user,
          onLogout: _handleLogout,
          platformRepository: _platformRepository,
          notificationsService: _notificationsService,
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _handleThemeChanged,
          isHighContrast: _highContrastEnabled,
          onHighContrastChanged: _handleHighContrastChanged,
          textScaleFactor: _textScaleFactor,
          onTextScaleChanged: _handleTextScaleChanged,
          selectedLanguage: _languageCode,
          onLanguageChanged: _handleLanguageChanged,
          onUserChanged: _handleUserUpdated,
          isBiometricLockEnabled: _biometricLockEnabled,
          onBiometricLockChanged: _handleBiometricLockChanged,
        );
      case AppRole.admin:
        return AdminShell(
          user: user,
          onLogout: _handleLogout,
          platformRepository: _platformRepository,
          onUserChanged: _handleUserUpdated,
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _handleThemeChanged,
          isHighContrast: _highContrastEnabled,
          onHighContrastChanged: _handleHighContrastChanged,
          textScaleFactor: _textScaleFactor,
          onTextScaleChanged: _handleTextScaleChanged,
          selectedLanguage: _languageCode,
          onLanguageChanged: _handleLanguageChanged,
          isBiometricLockEnabled: _biometricLockEnabled,
          onBiometricLockChanged: _handleBiometricLockChanged,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _trForLanguage(_languageCode, 'Freshline', 'فريش لاين'),
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      locale: _localeForLanguageCode(_languageCode),
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildAppTheme(
        brightness: _themeMode == ThemeMode.dark
            ? Brightness.dark
            : Brightness.light,
        highContrast: _highContrastEnabled,
      ),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(_textScaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _showSplash
            ? const SplashScreen()
            : _showOnboarding
            ? OnboardingScreen(onGetStarted: _completeOnboarding)
            : _currentUser == null
            ? AuthScreen(
                onSignIn: _signIn,
                onRegisterCustomer: _registerCustomer,
                onSendPasswordResetCode: _sendPasswordResetCode,
                onVerifyPasswordResetCode: _verifyPasswordResetCode,
                onCompletePasswordReset: _completePasswordReset,
                onPickProfileImage: _pickProfileImage,
                onOpenSalonRegistration: _openSalonRegistration,
              )
            : _biometricLockEnabled && !_biometricUnlocked
            ? BiometricUnlockScreen(
                isUnlocking: _isAuthenticatingBiometric,
                onUnlock: _requestBiometricUnlock,
                onLogout: _handleLogout,
              )
            : _buildSignedInShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.user,
    required this.onLogout,
    required this.catalogService,
    required this.notificationsService,
    required this.platformRepository,
    required this.initialNotifications,
    required this.onUserChanged,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isHighContrast,
    required this.onHighContrastChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isBiometricLockEnabled,
    required this.onBiometricLockChanged,
  });

  final AppUser user;
  final VoidCallback onLogout;
  final CatalogService catalogService;
  final NotificationsService notificationsService;
  final PlatformRepository platformRepository;
  final List<AppNotificationItem> initialNotifications;
  final ValueChanged<AppUser> onUserChanged;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final bool isBiometricLockEnabled;
  final AsyncBoolCallback onBiometricLockChanged;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;
  bool _isCatalogLoading = true;
  bool _isCommerceLoading = true;
  bool _isSubmittingProductOrder = false;
  late AppUser _user;
  List<Salon> _salons = <Salon>[];
  List<Product> _products = <Product>[];
  final Set<String> _cart = <String>{};
  final Map<String, int> _cartQuantities = <String, int>{};
  final List<PaymentCardInfo> _savedCards = <PaymentCardInfo>[];
  final List<SavedCustomerAddress> _savedAddresses = <SavedCustomerAddress>[];
  final List<PromoCouponRecord> _availablePromoCoupons = <PromoCouponRecord>[];
  final List<UserOrder> _activeOrders = <UserOrder>[];
  final List<UserOrder> _completedOrders = <UserOrder>[];
  late List<AppNotificationItem> _localNotifications;
  List<AppNotificationItem> _remoteNotifications = <AppNotificationItem>[];
  SubscriptionPlan? _selectedPlan;
  CustomerSubscriptionStatus? _customerSubscription;
  int _loyaltyPoints = 0;
  bool _isNotificationsLoading = false;
  DeliveryLocationSelection? _savedDeliveryLocation;
  String _savedAddressDetails = '';
  final Set<String> _bookedSalonSlotKeys = <String>{};

  Future<Set<String>> _refreshBookedSlots() async {
    try {
      final CustomerCommerceSnapshot snapshot =
          await widget.platformRepository.loadCustomerCommerce(user: _user);
      if (!mounted) {
        return _bookedSalonSlotKeys;
      }
      setState(() {
        _bookedSalonSlotKeys
          ..clear()
          ..addAll(snapshot.bookedSlotKeys);
      });
    } catch (_) {
      // Ignore refresh failures and keep the previous slot cache.
    }
    return _bookedSalonSlotKeys;
  }

  static String _notificationFingerprint(AppNotificationItem item) {
    final String title = item.title.trim().toLowerCase();
    final String titleAr = (item.titleAr ?? '').trim().toLowerCase();
    final String message = item.message.trim().toLowerCase();
    final String messageAr = (item.messageAr ?? '').trim().toLowerCase();
    final String icon = item.icon.trim().toLowerCase();
    return '$title|$titleAr|$message|$messageAr|$icon';
  }

  static List<AppNotificationItem> _dedupeNotifications(
    List<AppNotificationItem> items,
  ) {
    final Map<String, AppNotificationItem> byKey =
        <String, AppNotificationItem>{};
    for (final AppNotificationItem item in items) {
      final String key = _notificationFingerprint(item);
      final AppNotificationItem? existing = byKey[key];
      if (existing == null || item.createdAt.isAfter(existing.createdAt)) {
        byKey[key] = item;
      }
    }
    final List<AppNotificationItem> unique = byKey.values.toList(growable: false);
    unique.sort(
      (AppNotificationItem a, AppNotificationItem b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return unique;
  }

  int get _cartItemsCount =>
      _cartQuantities.values.fold<int>(0, (int sum, int qty) => sum + qty);

  int get _customerOrderCount => _activeOrders.length + _completedOrders.length;

  List<PromoCouponRecord> get _customerVisibleCoupons {
    return List<PromoCouponRecord>.from(
      _availablePromoCoupons,
      growable: false,
    );
  }

  void _saveCustomerAddress(String address) {
    final String normalizedAddress = address.trim();
    if (normalizedAddress.isEmpty || normalizedAddress == _user.address) {
      return;
    }

    final AppUser updatedUser = _user.copyWith(address: normalizedAddress);
    setState(() => _user = updatedUser);
    widget.onUserChanged(updatedUser);
  }

  void _saveDeliveryLocation(DeliveryLocationSelection location) {
    setState(() => _savedDeliveryLocation = location);
  }

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _localNotifications = List<AppNotificationItem>.from(
      widget.initialNotifications,
    );
    _loadCatalog();
    _loadAccountState();
    _loadCustomerCommerceState();
    _loadNotifications(showLoading: false);
  }

  @override
  void didUpdateWidget(covariant RootShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _user = widget.user;
    if (widget.selectedLanguage != oldWidget.selectedLanguage ||
        widget.user.preferredLanguage != oldWidget.user.preferredLanguage ||
        widget.user.profileId != oldWidget.user.profileId) {
      unawaited(_loadAccountState());
      unawaited(_loadCustomerCommerceState());
      unawaited(_loadNotifications(showLoading: false));
    }
  }

  Future<void> _loadAccountState() async {
    try {
      final List<dynamic> results = await Future.wait<dynamic>(
        <Future<dynamic>>[
          widget.platformRepository.loadSavedCards(user: _user),
          widget.platformRepository.loadSavedAddresses(user: _user),
          widget.platformRepository.loadCustomerSubscriptionStatus(user: _user),
          widget.platformRepository.loadPromoCoupons(activeOnly: true),
        ],
      );
      if (!mounted) {
        return;
      }
      AppUser? updatedUser;
      setState(() {
        _savedCards
          ..clear()
          ..addAll(results[0] as List<PaymentCardInfo>);
        _savedAddresses
          ..clear()
          ..addAll(results[1] as List<SavedCustomerAddress>);
        _availablePromoCoupons
          ..clear()
          ..addAll(results[3] as List<PromoCouponRecord>);
        final SavedCustomerAddress? preferredAddress =
            _savedAddresses
                .where((SavedCustomerAddress item) => item.isDefault)
                .firstOrNull ??
            _savedAddresses.firstOrNull;
        if (preferredAddress != null) {
          _savedDeliveryLocation = preferredAddress.location;
          _savedAddressDetails = preferredAddress.addressLine;
          _user = _user.copyWith(address: preferredAddress.addressLine);
          updatedUser = _user;
        }
        _customerSubscription = results[2] as CustomerSubscriptionStatus?;
        _selectedPlan = _customerSubscription?.plan;
      });
      if (updatedUser != null) {
        widget.onUserChanged(updatedUser!);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }
  }

  bool _shouldAutoCompleteCustomerOrder(UserOrder order, DateTime now) {
    if (order.isProductOrder) {
      if (order.statusLabel != 'Preparing') {
        return false;
      }
      return now.isAfter(order.scheduledAt.add(const Duration(days: 2)));
    }

    if (order.statusLabel != 'In order') {
      return false;
    }
    final Duration appointmentDuration =
        order.appointmentDuration ?? const Duration(minutes: 0);
    final DateTime appointmentEnd = order.scheduledAt.add(appointmentDuration);
    return now.isAfter(appointmentEnd.add(const Duration(minutes: 30)));
  }

  Future<bool> _autoCompleteCustomerOrdersIfNeeded(
    List<UserOrder> activeOrders,
  ) async {
    final DateTime now = DateTime.now();
    final List<UserOrder> eligible = activeOrders
        .where((UserOrder order) => _shouldAutoCompleteCustomerOrder(order, now))
        .toList(growable: false);
    if (eligible.isEmpty) {
      return false;
    }

    bool changed = false;
    for (final UserOrder order in eligible) {
      try {
        await widget.platformRepository.completeOrder(user: _user, order: order);
        changed = true;
      } catch (_) {
        // Best-effort: keep the UI responsive even if one update fails.
      }
    }
    return changed;
  }

  Future<void> _loadCustomerCommerceState({bool showError = false}) async {
    if (mounted) {
      setState(() => _isCommerceLoading = true);
    }

    try {
      CustomerCommerceSnapshot snapshot = await widget.platformRepository
          .loadCustomerCommerce(user: _user);
      final bool didAutoComplete = await _autoCompleteCustomerOrdersIfNeeded(
        snapshot.activeOrders,
      );
      if (didAutoComplete) {
        snapshot = await widget.platformRepository.loadCustomerCommerce(
          user: _user,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _activeOrders
          ..clear()
          ..addAll(snapshot.activeOrders);
        _completedOrders
          ..clear()
          ..addAll(snapshot.completedOrders);
        _bookedSalonSlotKeys
          ..clear()
          ..addAll(snapshot.bookedSlotKeys);
        _loyaltyPoints = snapshot.loyaltyPoints;
        _isCommerceLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isCommerceLoading = false);
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _loadCatalog() async {
    final bool shouldShowNetworkError = _salons.isEmpty && _products.isEmpty;
    try {
      final CatalogData data = await widget.catalogService.loadCatalog();
      if (!mounted) {
        return;
      }
      setState(() {
        _salons = data.salons;
        _products = data.products;
        _isCatalogLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isCatalogLoading = false);
      if (!shouldShowNetworkError) {
        return;
      }
      final String message = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .trim();
      if (message.isEmpty) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openSalonsList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            SalonsListScreen(salons: _salons, onOpenSalon: _openSalonDetail),
      ),
    );
  }

  void _openProductsList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProductsListScreen(
          products: _products,
          cartIds: _cart,
          onOpenProduct: _openProductDetail,
          onAddToCart: _addToCart,
        ),
      ),
    );
  }

  void _openSalonDetail(Salon salon) {
    final List<Product> salonProducts = _products
        .where(
          (Product product) => product.isActive && product.salonId == salon.id,
        )
        .toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SalonDetailScreen(
          salon: salon,
          products: salonProducts,
          cartIds: _cart,
          platformRepository: widget.platformRepository,
          customerAddress: _user.address,
          initialAddressLocation: _savedDeliveryLocation,
          savedAddresses: _savedAddresses,
          bookedSlotKeys: _bookedSalonSlotKeys,
          savedCards: _savedCards,
          onRefreshBookedSlots: _refreshBookedSlots,
          onOpenProduct: _openProductDetail,
          onAddToCart: _addToCart,
          onAddCard: _openAddCardScreen,
          onAddressSaved: _saveCustomerAddress,
          onLocationSaved: _saveDeliveryLocation,
          onBookingConfirmed: _handleBookingConfirmed,
        ),
      ),
    );
  }

  void _openProductDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProductDetailScreen(
          product: product,
          onAddToCart: () => _addToCart(product.id),
        ),
      ),
    );
  }

  List<AppNotificationItem> get _notifications {
    final List<AppNotificationItem> items = <AppNotificationItem>[
      ..._localNotifications,
      ..._remoteNotifications,
    ];
    return _dedupeNotifications(items);
  }

  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isNotificationsLoading = true);
    }

    try {
      final List<AppNotificationItem> items = await widget.notificationsService
          .loadNotifications(user: _user);
      if (!mounted) {
        return;
      }
      setState(() => _remoteNotifications = items);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (showLoading) {
        final String message = error
            .toString()
            .replaceFirst('Bad state: ', '')
            .trim();
        if (message.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isNotificationsLoading = false);
      }
    }
  }

  Future<void> _openNotifications() async {
    await _loadNotifications();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => NotificationsScreen(
          notifications: _notifications,
          isLoading: _isNotificationsLoading,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _localNotifications = _localNotifications
          .map(
            (AppNotificationItem item) =>
                item.unread ? item.copyWith(unread: false) : item,
          )
          .toList(growable: false);
      _remoteNotifications = _remoteNotifications
          .map(
            (AppNotificationItem item) =>
                item.unread ? item.copyWith(unread: false) : item,
          )
          .toList(growable: false);
    });
  }

  void _pushLocalNotification({
    required String title,
    required String message,
    required String icon,
    String? titleAr,
    String? messageAr,
  }) {
    final String normalizedFingerprint = _notificationFingerprint(
      AppNotificationItem(
        title: title,
        message: message,
        icon: icon,
        titleAr: titleAr,
        messageAr: messageAr,
      ),
    );
    setState(() {
      final bool alreadyExists = _dedupeNotifications(<AppNotificationItem>[
        ..._localNotifications,
        ..._remoteNotifications,
      ]).any(
        (AppNotificationItem item) =>
            _notificationFingerprint(item) == normalizedFingerprint,
      );
      if (alreadyExists) {
        return;
      }
      _localNotifications.insert(
        0,
        AppNotificationItem(
          title: title,
          message: message,
          icon: icon,
          titleAr: titleAr,
          messageAr: messageAr,
          unread: true,
        ),
      );
    });
  }

  void _addToCart(String productId) async {
    final Product? product = _productById(productId);
    if (product == null) {
      return;
    }
    final String productName = product.localizedNameForLanguage(
      widget.selectedLanguage,
    );

    if (!product.isActive) {
      _showTopToast(
        context,
        title: _trForLanguage(
          widget.selectedLanguage,
          'Unavailable product',
          'منتج غير متاح',
        ),
        message: _trForLanguage(
          widget.selectedLanguage,
          '$productName is not available right now.',
          '$productName غير متاح حالياً.',
        ),
        icon: Icons.inventory_2_outlined,
      );
      return;
    }

    if (product.stock <= 0) {
      _showTopToast(
        context,
        title: _trForLanguage(
          widget.selectedLanguage,
          'Out of stock',
          'نفد المخزون',
        ),
        message: _trForLanguage(
          widget.selectedLanguage,
          '$productName is currently out of stock. Please try another product.',
          '$productName غير متوفر حالياً. جرّب منتجاً آخر.',
        ),
        icon: Icons.remove_shopping_cart_rounded,
      );
      return;
    }

    final int currentQuantity = _cartQuantities[productId] ?? 0;
    if (currentQuantity >= product.stock) {
      _showTopToast(
        context,
        title: _trForLanguage(
          widget.selectedLanguage,
          'Stock limit reached',
          'تم بلوغ حد المخزون',
        ),
        message: _trForLanguage(
          widget.selectedLanguage,
          'Only ${product.stock} item${product.stock == 1 ? '' : 's'} available for $productName.',
          'المتوفر فقط ${product.stock} قطعة من $productName.',
        ),
        icon: Icons.inventory_2_outlined,
      );
      return;
    }

    final Product? currentCartProduct = _cartQuantities.keys
        .map(_productById)
        .whereType<Product>()
        .firstOrNull;
    final String currentCartSalonId = (currentCartProduct?.salonId ?? '')
        .trim();
    final String nextSalonId = (product.salonId ?? '').trim();
    if (_cartItemsCount > 0 &&
        currentCartProduct != null &&
        currentCartSalonId.isNotEmpty &&
        nextSalonId.isNotEmpty &&
        currentCartSalonId != nextSalonId) {
      final bool shouldSwitchCart = await _confirmSalonCartSwitch(
        currentProduct: currentCartProduct,
        nextProduct: product,
      );
      if (!mounted || !shouldSwitchCart) {
        return;
      }
      setState(() {
        _cart.clear();
        _cartQuantities.clear();
      });
    }

    final bool wasEmpty = _cartItemsCount == 0;
    final bool alreadyAdded = _cartQuantities.containsKey(productId);
    setState(() {
      _cart.add(productId);
      _cartQuantities.update(
        productId,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
    });
    final String message = !alreadyAdded && wasEmpty
        ? _trForLanguage(
            widget.selectedLanguage,
            '$productName was added. Open Cart from the bottom bar whenever you are ready.',
            'تمت إضافة $productName. افتح السلة من الشريط السفلي عندما تكون جاهزاً.',
          )
        : _trForLanguage(
            widget.selectedLanguage,
            '$productName was added. Cart now has $_cartItemsCount item${_cartItemsCount == 1 ? '' : 's'}.',
            'تمت إضافة $productName. تحتوي السلة الآن على $_cartItemsCount عنصر.',
          );
    _showTopToast(
      context,
      title: _trForLanguage(
        widget.selectedLanguage,
        'Added to cart',
        'تمت الإضافة إلى السلة',
      ),
      message: message,
      icon: Icons.shopping_cart_checkout_rounded,
    );
  }

  void _increaseCartQuantity(String productId) {
    _addToCart(productId);
  }

  void _decreaseCartQuantity(String productId) {
    final int quantity = _cartQuantities[productId] ?? 0;
    if (quantity <= 1) {
      return;
    }

    setState(() => _cartQuantities[productId] = quantity - 1);
  }

  Future<void> _confirmRemoveFromCart(String productId) async {
    final Product? product = _productById(productId);
    final String productName =
        product?.localizedNameForLanguage(widget.selectedLanguage) ?? '';
    final bool shouldRemove =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(
                _trForLanguage(
                  widget.selectedLanguage,
                  'Remove Product',
                  'إزالة المنتج',
                ),
              ),
              content: Text(
                product == null
                    ? _trForLanguage(
                        widget.selectedLanguage,
                        'Are you sure you want to remove this item from the cart?',
                        'هل أنت متأكد أنك تريد إزالة هذا العنصر من السلة؟',
                      )
                    : _trForLanguage(
                        widget.selectedLanguage,
                        'Are you sure you want to remove $productName from the cart?',
                        'هل أنت متأكد أنك تريد إزالة $productName من السلة؟',
                      ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    _trForLanguage(widget.selectedLanguage, 'Cancel', 'إلغاء'),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    _trForLanguage(widget.selectedLanguage, 'Remove', 'إزالة'),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldRemove) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _cart.remove(productId);
      _cartQuantities.remove(productId);
    });

    _showTopToast(
      context,
      title: _trForLanguage(
        widget.selectedLanguage,
        'Removed from cart',
        'تمت الإزالة من السلة',
      ),
      message: product == null
          ? _trForLanguage(
              widget.selectedLanguage,
              'The item was removed from your cart.',
              'تمت إزالة العنصر من السلة.',
            )
          : _trForLanguage(
              widget.selectedLanguage,
              '$productName was removed from your cart.',
              'تمت إزالة $productName من السلة.',
            ),
      icon: Icons.delete_outline_rounded,
    );
  }

  Future<void> _openProductCheckout() async {
    if (_isSubmittingProductOrder) {
      return;
    }

    final List<Product> cartProducts = _products
        .where((Product product) => _cartQuantities.containsKey(product.id))
        .toList(growable: false);
    if (cartProducts.isEmpty) {
      return;
    }

    Product? invalidStockProduct;
    for (final Product product in cartProducts) {
      final int requestedQuantity = _cartQuantities[product.id] ?? 0;
      if (!product.isActive ||
          product.stock <= 0 ||
          requestedQuantity > product.stock) {
        invalidStockProduct = product;
        break;
      }
    }
    if (invalidStockProduct != null) {
      final int availableStock = math.max(0, invalidStockProduct.stock);
      final String productName = invalidStockProduct.localizedName(context);
      _showTopToast(
        context,
        title: _tr(context, 'Stock changed', 'تم تحديث المخزون'),
        message: availableStock == 0
            ? _tr(
                context,
                '$productName is no longer in stock.',
                '$productName لم يعد متوفراً في المخزون.',
              )
            : _tr(
                context,
                '$productName now has only $availableStock item${availableStock == 1 ? '' : 's'} left.',
                'المتبقي من $productName هو $availableStock ${availableStock == 1 ? 'قطعة فقط' : 'قطع فقط'}.',
              ),
        icon: Icons.inventory_2_outlined,
      );
      return;
    }

    try {
      final List<PromoCouponRecord> latestCoupons = await widget
          .platformRepository
          .loadPromoCoupons(activeOnly: true);
      if (mounted) {
        setState(() {
          _availablePromoCoupons
            ..clear()
            ..addAll(latestCoupons);
        });
      }
    } catch (_) {
      // Coupon refresh should not block checkout.
    }

    if (!mounted) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final _ProductCheckoutResult? checkoutResult = await navigator
        .push<_ProductCheckoutResult>(
          MaterialPageRoute<_ProductCheckoutResult>(
            builder: (BuildContext context) => _ProductCheckoutScreen(
              user: _user,
              products: cartProducts,
              cartQuantities: Map<String, int>.from(_cartQuantities),
              availableLoyaltyPoints: _loyaltyPoints,
              customerOrderCount: _customerOrderCount,
              currentPlan: _selectedPlan,
              initialLocation: _savedDeliveryLocation,
              initialAddressDetails: _savedAddressDetails,
              savedAddresses: _savedAddresses,
              availableCoupons: List<PromoCouponRecord>.from(
                _availablePromoCoupons,
              ),
              savedCards: _savedCards,
              onAddCard: _openAddCardScreen,
            ),
          ),
        );
    if (!mounted || checkoutResult == null) {
      return;
    }

    final List<ProductOrderLineItem> orderItems = cartProducts
        .map(
          (Product product) => ProductOrderLineItem(
            productId: product.id,
            productName: product.name,
            productNameAr: product.localizedNameForLanguage('AR'),
            quantity: _cartQuantities[product.id] ?? 1,
            unitPrice: product.price,
          ),
        )
        .toList(growable: false);
    final int gainedPoints = _calculateLoyaltyPoints(checkoutResult.totalPaid);
    final Product firstProduct = cartProducts.first;
    final Salon? orderSalon = _salonById((firstProduct.salonId ?? '').trim());
    final int remainingCount = _cartItemsCount - 1;
    final String itemLabelEn = remainingCount > 0
        ? '${firstProduct.localizedNameForLanguage('EN')} + $remainingCount more item${remainingCount == 1 ? '' : 's'}'
        : firstProduct.localizedNameForLanguage('EN');
    final String itemLabelAr = remainingCount > 0
        ? '${firstProduct.localizedNameForLanguage('AR')} + $remainingCount ${remainingCount == 1 ? 'منتج إضافي' : 'منتجات إضافية'}'
        : firstProduct.localizedNameForLanguage('AR');
    final String itemLabel = _trForLanguage(
      widget.selectedLanguage,
      itemLabelEn,
      itemLabelAr,
    );
    final String deliveryAddress =
        '${checkoutResult.addressDetails}, ${checkoutResult.location.fullLabel}';
    final int remainingLoyaltyPoints =
        _loyaltyPoints - checkoutResult.loyaltyPointsRedeemed;
    final String discountMessage = checkoutResult.totalDiscount > 0
        ? ' ${formatBhd(checkoutResult.totalDiscount)} discount applied.'
        : '';
    final UserOrder productOrder = UserOrder(
      id: 'product-${DateTime.now().millisecondsSinceEpoch}',
      type: UserOrderType.productOrder,
      invoiceNumber: generateFreshlineInvoiceNumber(),
      salonName: orderSalon?.name ?? 'Salon Products',
      salonNameAr:
          orderSalon?.localizedNameForLanguage('AR') ?? 'منتجات الصالون',
      serviceName: itemLabelEn,
      serviceNameAr: itemLabelAr,
      employeeName: 'Freshline Delivery',
      employeeNameAr: 'توصيل فريش لاين',
      visitMode: 'Home delivery',
      visitModeAr: 'توصيل منزلي',
      scheduledAt: DateTime.now(),
      total: checkoutResult.totalPaid,
      statusLabel: 'Preparing',
      statusLabelAr: 'قيد التجهيز',
      loyaltyPointsGained: gainedPoints,
      salonId: orderSalon?.id ?? firstProduct.salonId,
      address: deliveryAddress,
      cardLabel: checkoutResult.card.displayLabel,
    );

    try {
      setState(() => _isSubmittingProductOrder = true);

      await widget.platformRepository.placeProductOrder(
        user: _user,
        order: productOrder,
        items: orderItems,
        location: checkoutResult.location,
        addressDetails: checkoutResult.addressDetails,
        couponCode: checkoutResult.couponCode,
        couponDiscount: checkoutResult.couponDiscount,
        loyaltyPointsRedeemed: checkoutResult.loyaltyPointsRedeemed,
        loyaltyDiscount: checkoutResult.loyaltyDiscount,
        taxAmount: checkoutResult.taxAmount,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmittingProductOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _cart.clear();
      _cartQuantities.clear();
      final Map<String, int> orderedQuantities = <String, int>{
        for (final ProductOrderLineItem item in orderItems)
          item.productId: item.quantity,
      };
      _products = _products
          .map((Product product) {
            final int orderedQuantity = orderedQuantities[product.id] ?? 0;
            if (orderedQuantity <= 0) {
              return product;
            }
            return product.copyWith(
              stock: math.max(0, product.stock - orderedQuantity),
            );
          })
          .toList(growable: false);
      _loyaltyPoints =
          (remainingLoyaltyPoints < 0 ? 0 : remainingLoyaltyPoints) +
          gainedPoints;
      _savedDeliveryLocation = checkoutResult.location;
      _savedAddressDetails = checkoutResult.addressDetails;
      _activeOrders.removeWhere((UserOrder item) => item.id == productOrder.id);
      _activeOrders.insert(0, productOrder);
      _currentIndex = 1;
      _isSubmittingProductOrder = false;
    });
    _saveCustomerAddress(checkoutResult.addressDetails);

    _pushLocalNotification(
      title: 'Product Order Placed',
      titleAr: 'تم إنشاء طلب المنتج',
      message:
          'Your order for $itemLabel was placed successfully and is now preparing for delivery to ${checkoutResult.addressDetails}.',
      messageAr:
          'تم إنشاء طلبك الخاص بـ $itemLabel بنجاح، ويجري الآن تجهيزه للتوصيل إلى ${checkoutResult.addressDetails}.',
      icon: 'cart',
    );
    _showTopToast(
      context,
      title: 'Payment successful',
      message:
          'Order confirmed to ${checkoutResult.addressDetails}, ${checkoutResult.location.shortLabel}.$discountMessage You gained $gainedPoints points.',
      icon: Icons.check_circle_rounded,
    );
    unawaited(_refreshAfterSuccessfulProductOrder());
  }

  Future<void> _refreshAfterSuccessfulProductOrder() async {
    try {
      await Future.wait<void>(<Future<void>>[
        _loadAccountState(),
        _loadCustomerCommerceState(),
      ]);
    } catch (_) {
      // Local success state is already shown to the customer.
    }
  }

  Product? _productById(String productId) {
    return _products
        .where((Product product) => product.id == productId)
        .firstOrNull;
  }

  Salon? _salonById(String salonId) {
    return _salons.where((Salon salon) => salon.id == salonId).firstOrNull;
  }

  Future<bool> _confirmSalonCartSwitch({
    required Product currentProduct,
    required Product nextProduct,
  }) async {
    final String currentSalonName =
        _salonById(
          (currentProduct.salonId ?? '').trim(),
        )?.localizedNameForLanguage(widget.selectedLanguage) ??
        _trForLanguage(
          widget.selectedLanguage,
          'your current salon',
          'الصالون الحالي',
        );
    final String nextSalonName =
        _salonById(
          (nextProduct.salonId ?? '').trim(),
        )?.localizedNameForLanguage(widget.selectedLanguage) ??
        _trForLanguage(widget.selectedLanguage, 'this salon', 'هذا الصالون');
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(
                _tr(context, 'Switch Cart Salon?', 'تغيير صالون السلة؟'),
              ),
              content: Text(
                _tr(
                  context,
                  'Your cart already has products from $currentSalonName. Freshline keeps one salon per cart, so clear the current items and add ${nextProduct.localizedNameForLanguage('EN')} from $nextSalonName instead?',
                  'السلة الحالية فيها منتجات من $currentSalonName. فريش لاين يسمح بسلة من صالون واحد فقط، هل تريد مسح المنتجات الحالية وإضافة ${nextProduct.localizedNameForLanguage('AR')} من $nextSalonName بدلاً منها؟',
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    _tr(
                      context,
                      'Keep Current Cart',
                      'الاحتفاظ بالسلة الحالية',
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_tr(context, 'Clear & Add', 'مسح وإضافة')),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _openMapExplorer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MapTabScreen(salons: _salons),
      ),
    );
  }

  void _openCartTab() {
    setState(() => _currentIndex = 2);
  }

  Future<PaymentCardInfo?> _openAddCardScreen(String title) async {
    final PaymentCardInfo? card = await Navigator.of(context)
        .push<PaymentCardInfo>(
          MaterialPageRoute<PaymentCardInfo>(
            builder: (BuildContext context) => AddCardScreen(title: title),
          ),
        );

    if (card != null) {
      try {
        final PaymentCardInfo savedCard = await widget.platformRepository
            .saveCard(user: _user, card: card);
        if (!mounted) {
          return null;
        }
        setState(() {
          _savedCards.removeWhere(
            (PaymentCardInfo item) => item.id == savedCard.id,
          );
          _savedCards.insert(0, savedCard);
        });
        return savedCard;
      } catch (error) {
        if (!mounted) {
          return null;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
        return null;
      }
    }

    return card;
  }

  Future<void> _removeSavedCard(PaymentCardInfo card) async {
    await widget.platformRepository.removeSavedCard(user: _user, card: card);
    if (!mounted) {
      return;
    }
    setState(() {
      _savedCards.removeWhere((PaymentCardInfo item) => item.id == card.id);
    });
  }

  Future<void> _openPlans() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PlansScreen(
          subscriptionStatus: _customerSubscription,
          savedCards: _savedCards,
          user: _user,
          platformRepository: widget.platformRepository,
          onAddCard: _openAddCardScreen,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadAccountState();
  }

  Future<void> _handleBookingConfirmed(UserOrder order) async {
    final int gainedPoints = _calculateLoyaltyPoints(order.total);
    final UserOrder storedOrder = order.copyWith(
      loyaltyPointsGained: gainedPoints,
      statusLabel: 'In order',
      statusLabelAr: 'قيد التنفيذ',
    );

    await widget.platformRepository.placeSalonBooking(
      user: _user,
      order: storedOrder,
    );
    if (!mounted) {
      return;
    }

    setState(() => _currentIndex = 1);
    await _loadAccountState();
    await _loadCustomerCommerceState();
    if (!mounted) {
      return;
    }

    _pushLocalNotification(
      title: 'Salon Booking Confirmed',
      titleAr: 'تم تأكيد حجز الصالون',
      message:
          '${storedOrder.localizedServiceNameForLanguage('EN')} with ${storedOrder.localizedEmployeeNameForLanguage('EN')} is booked for ${_formatBookingDateTime(storedOrder.scheduledAt)}.',
      messageAr:
          'تم حجز ${storedOrder.localizedServiceNameForLanguage('AR')} مع ${storedOrder.localizedEmployeeNameForLanguage('AR')} بتاريخ ${_formatBookingDateTime(storedOrder.scheduledAt)}.',
      icon: 'calendar',
    );
    _showTopToast(
      context,
      title: _tr(context, 'Booking confirmed', 'تم تأكيد الحجز'),
      message: _tr(
        context,
        '${storedOrder.localizedServiceName(context)} is booked for ${_formatBookingDateTime(storedOrder.scheduledAt)}. You gained $gainedPoints points.',
        'تم حجز ${storedOrder.localizedServiceName(context)} بتاريخ ${_formatBookingDateTime(storedOrder.scheduledAt)}. حصلت على $gainedPoints نقطة.',
      ),
      icon: Icons.check_circle_rounded,
    );
  }

  int _calculateLoyaltyPoints(num total) {
    final int basePoints = total.round();
    final int bonusPercent = _selectedPlan?.rewardPercent ?? 0;
    return basePoints + ((basePoints * bonusPercent) / 100).round();
  }

  Future<void> _addReminder(UserOrder order) async {
    if (order.isProductOrder) {
      return;
    }

    final String reminderText = _tr(
      context,
      'FreshLine Appointment\n'
          'Service: ${order.localizedServiceName(context)}\n'
          'Employee: ${order.localizedEmployeeName(context)}\n'
          'Time: ${_formatBookingDateTime(order.scheduledAt)}\n'
          'Location: ${order.address ?? order.localizedSalonName(context)}',
      'موعد فريش لاين\n'
          'الخدمة: ${order.localizedServiceName(context)}\n'
          'الموظف: ${order.localizedEmployeeName(context)}\n'
          'الوقت: ${_formatBookingDateTime(order.scheduledAt)}\n'
          'الموقع: ${order.address ?? order.localizedSalonName(context)}',
    );

    final bool reminderOpened = await openAppointmentReminder(order);

    if (!mounted) {
      return;
    }

    if (!reminderOpened) {
      await _copyToClipboard(
        context,
        reminderText,
        _tr(
          context,
          'We could not open your calendar, so the appointment details were copied to the clipboard.',
          'تعذر فتح التقويم، لذلك تم نسخ تفاصيل الموعد إلى الحافظة.',
        ),
      );
      return;
    }

    setState(() {
      final int index = _activeOrders.indexWhere(
        (UserOrder item) => item.id == order.id,
      );
      if (index >= 0) {
        _activeOrders[index] = _activeOrders[index].copyWith(
          reminderAdded: true,
        );
      }
    });

    _pushLocalNotification(
      title: 'Calendar Opened',
      titleAr: 'تم فتح التقويم',
      message:
          'Your ${order.localizedServiceNameForLanguage('EN')} appointment was opened in your calendar. Save it there to finish adding the reminder.',
      messageAr:
          'تم فتح موعد ${order.localizedServiceNameForLanguage('AR')} في التقويم. احفظه هناك لإكمال إضافة التذكير.',
      icon: 'calendar',
    );
    _showTopToast(
      context,
      title: _tr(context, 'Calendar opened', 'تم فتح التقويم'),
      message: _tr(
        context,
        'Save the appointment in your calendar to finish adding the reminder.',
        'احفظ الموعد في التقويم لإكمال إضافة التذكير.',
      ),
      icon: Icons.calendar_month_rounded,
    );
  }

  Future<void> _completeOrder(UserOrder order) async {
    try {
      await widget.platformRepository.completeOrder(user: _user, order: order);
      await _loadCustomerCommerceState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _rateSalonOrder(UserOrder order) async {
    final _SalonReviewSubmission? submission =
        await showDialog<_SalonReviewSubmission>(
          context: context,
          builder: (BuildContext dialogContext) =>
              _SalonReviewDialog(order: order),
        );
    if (submission == null) {
      return;
    }

    try {
      final String combinedComment = jsonEncode(<String, String>{
        'salon': submission.salonComment.trim(),
        'employee': submission.employeeComment.trim(),
      });
      await widget.platformRepository.submitSalonReview(
        user: _user,
        order: order,
        salonRating: submission.salonRating,
        employeeRating: submission.employeeRating,
        comment: combinedComment,
      );
      await Future.wait<void>(<Future<void>>[
        _loadCustomerCommerceState(),
        _loadCatalog(),
      ]);
      if (!mounted) {
        return;
      }

      _pushLocalNotification(
        title: 'Review Submitted',
        titleAr: 'تم إرسال التقييم',
        message:
            'Thanks for rating ${order.localizedSalonNameForLanguage('EN')} and ${order.localizedEmployeeNameForLanguage('EN')}.',
        messageAr:
            'شكراً لتقييمك ${order.localizedSalonNameForLanguage('AR')} و${order.localizedEmployeeNameForLanguage('AR')}.',
        icon: 'sparkles',
      );
      _showTopToast(
        context,
        title: _tr(context, 'Thanks for your review', 'شكراً على تقييمك'),
        message: _tr(
          context,
          'Your salon and employee ratings were saved successfully.',
          'تم حفظ تقييم الصالون والموظف بنجاح.',
        ),
        icon: Icons.star_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _rateProductOrder(UserOrder order) async {
    final List<RatedOrderProductItem> pendingItems = order.productItems
        .where((RatedOrderProductItem item) => !item.reviewSubmitted)
        .toList(growable: false);
    if (pendingItems.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All products in this order are rated.')),
      );
      return;
    }

    int submittedCount = 0;
    try {
      for (final RatedOrderProductItem item in pendingItems) {
        if (!mounted) {
          return;
        }
        final _SingleRatingSubmission? submission =
            await showDialog<_SingleRatingSubmission>(
              context: context,
              builder: (BuildContext dialogContext) =>
                  _ProductReviewDialog(item: item),
            );
        if (submission == null) {
          break;
        }

        await widget.platformRepository.submitProductReview(
          user: _user,
          order: order,
          productId: item.productId,
          rating: submission.rating,
          comment: submission.comment,
        );
        submittedCount += 1;
      }

      if (submittedCount == 0) {
        return;
      }

      await Future.wait<void>(<Future<void>>[
        _loadCustomerCommerceState(),
        _loadCatalog(),
      ]);
      if (!mounted) {
        return;
      }

      _pushLocalNotification(
        title: 'Product Review Saved',
        titleAr: 'تم حفظ تقييم المنتجات',
        message:
            '$submittedCount product review${submittedCount == 1 ? '' : 's'} were added from your order.',
        messageAr: submittedCount == 1
            ? 'تمت إضافة تقييم منتج واحد من طلبك.'
            : 'تمت إضافة $submittedCount تقييمات منتجات من طلبك.',
        icon: 'sparkles',
      );
      _showTopToast(
        context,
        title: 'Reviews submitted',
        message:
            'Your product ratings were saved and the product scores were updated.',
        icon: Icons.star_rounded,
      );
    } catch (error) {
      if (submittedCount > 0) {
        await Future.wait<void>(<Future<void>>[
          _loadCustomerCommerceState(),
          _loadCatalog(),
        ]);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_NavItem> tabs = <_NavItem>[
      _NavItem(Icons.home_rounded, _tr(context, 'Home', 'الرئيسية')),
      _NavItem(Icons.shopping_bag_rounded, _tr(context, 'Order', 'الطلبات')),
      _NavItem(
        Icons.shopping_cart_checkout_rounded,
        _tr(context, 'Cart', 'السلة'),
      ),
      _NavItem(Icons.auto_awesome_rounded, _tr(context, 'AI', 'الذكاء')),
      _NavItem(Icons.settings_rounded, _tr(context, 'Settings', 'الإعدادات')),
    ];
    final List<Widget> pages = <Widget>[
      HomeScreen(
        user: _user,
        salons: _salons,
        products: _products,
        cartIds: _cart,
        selectedPlan: _selectedPlan,
        subscriptionStatus: _customerSubscription,
        loyaltyPoints: _loyaltyPoints,
        isCatalogLoading: _isCatalogLoading,
        onOpenAllSalons: _openSalonsList,
        onOpenSalon: _openSalonDetail,
        onOpenNotifications: _openNotifications,
        onOpenAllProducts: _openProductsList,
        onOpenProduct: _openProductDetail,
        onOpenPlans: _openPlans,
        onAddToCart: _addToCart,
        onOpenMap: _openMapExplorer,
        onOpenCart: _openCartTab,
        cartCount: _cartItemsCount,
      ),
      OrdersScreen(
        activeOrders: _activeOrders,
        completedOrders: _completedOrders,
        isLoading: _isCommerceLoading,
        onAddReminder: _addReminder,
        onCompleteOrder: _completeOrder,
        onRateSalonOrder: _rateSalonOrder,
        onRateProductOrder: _rateProductOrder,
      ),
      CartScreen(
        products: _products,
        cartQuantities: _cartQuantities,
        onOpenProduct: _openProductDetail,
        onContinueShopping: _openProductsList,
        onCheckout: _openProductCheckout,
        onIncreaseQuantity: _increaseCartQuantity,
        onDecreaseQuantity: _decreaseCartQuantity,
        onRemoveFromCart: _confirmRemoveFromCart,
      ),
      AiStylistScreen(
        role: AppRole.customer,
        selectedLanguage: widget.selectedLanguage,
      ),
      SettingsScreen(
        user: _user,
        onLogout: widget.onLogout,
        currentPlan: _selectedPlan,
        subscriptionStatus: _customerSubscription,
        customerOrderCount: _customerOrderCount,
        availableCoupons: _customerVisibleCoupons,
        savedCards: _savedCards,
        platformRepository: widget.platformRepository,
        onAddCard: _openAddCardScreen,
        onRemoveCard: _removeSavedCard,
        onUserChanged: (AppUser updatedUser) {
          setState(() => _user = updatedUser);
          widget.onUserChanged(updatedUser);
        },
        onOpenNotifications: _openNotifications,
        onOpenPlans: _openPlans,
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
        isHighContrast: widget.isHighContrast,
        onHighContrastChanged: widget.onHighContrastChanged,
        textScaleFactor: widget.textScaleFactor,
        onTextScaleChanged: widget.onTextScaleChanged,
        selectedLanguage: widget.selectedLanguage,
        onLanguageChanged: widget.onLanguageChanged,
        isBiometricLockEnabled: widget.isBiometricLockEnabled,
        onBiometricLockChanged: widget.onBiometricLockChanged,
      ),
    ];

    return AppViewport(
      child: Stack(
        children: <Widget>[
          Scaffold(
            body: IndexedStack(index: _currentIndex, children: pages),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppPalette.card.withValues(alpha: 0.97),
                border: Border(top: BorderSide(color: AppPalette.border)),
              ),
              padding: EdgeInsets.fromLTRB(
                8,
                8,
                8,
                MediaQuery.viewPaddingOf(context).bottom + 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List<Widget>.generate(tabs.length, (int index) {
                  final bool active = _currentIndex == index;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => _currentIndex = index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Icon(
                                  tabs[index].icon,
                                  size: 22,
                                  color: active
                                      ? AppPalette.primary
                                      : AppPalette.mutedForeground,
                                ),
                                if (index == 2 && _cartItemsCount > 0)
                                  Positioned(
                                    top: -8,
                                    right: -10,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.primary,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: AppPalette.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$_cartItemsCount',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tabs[index].label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? AppPalette.primary
                                    : AppPalette.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          if (_isSubmittingProductOrder)
            Positioned.fill(
              child: ColoredBox(
                color: AppPalette.black.withValues(alpha: 0.28),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.all(20),
                    decoration: appCardDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _tr(
                            context,
                            'Processing your order',
                            'جاري معالجة طلبك',
                          ),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tr(
                            context,
                            'Please wait while Freshline confirms payment and moves you to Orders.',
                            'يرجى الانتظار بينما يؤكد فريش لاين الدفع وينقلك إلى الطلبات.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppPalette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPalette.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: child,
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.salons,
    required this.products,
    required this.cartIds,
    required this.selectedPlan,
    required this.subscriptionStatus,
    required this.loyaltyPoints,
    required this.isCatalogLoading,
    required this.onOpenAllSalons,
    required this.onOpenSalon,
    required this.onOpenNotifications,
    required this.onOpenAllProducts,
    required this.onOpenProduct,
    required this.onOpenPlans,
    required this.onAddToCart,
    required this.onOpenMap,
    required this.onOpenCart,
    required this.cartCount,
  });

  final AppUser user;
  final List<Salon> salons;
  final List<Product> products;
  final Set<String> cartIds;
  final SubscriptionPlan? selectedPlan;
  final CustomerSubscriptionStatus? subscriptionStatus;
  final int loyaltyPoints;
  final bool isCatalogLoading;
  final VoidCallback onOpenAllSalons;
  final ValueChanged<Salon> onOpenSalon;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenAllProducts;
  final ValueChanged<Product> onOpenProduct;
  final VoidCallback onOpenPlans;
  final ValueChanged<String> onAddToCart;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenCart;
  final int cartCount;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _bannerController = PageController(
    viewportFraction: 0.86,
  );

  String _subscriptionSummaryText() {
    final CustomerSubscriptionStatus? subscription = widget.subscriptionStatus;
    if (widget.selectedPlan == null || subscription == null) {
      return _tr(
        context,
        'Choose Bronze, Silver, or Gold to unlock more loyalty points after every order.',
        'اختر البرونزية أو الفضية أو الذهبية لفتح نقاط ولاء إضافية بعد كل طلب.',
      );
    }
    final String expiryText = subscription.endsAt == null
        ? _tr(
            context,
            'Expiry date will appear after activation.',
            'سيظهر تاريخ الانتهاء بعد التفعيل.',
          )
        : _tr(
            context,
            'Expires on ${formatCalendarDate(subscription.endsAt!)}.',
            'ينتهي في ${formatCalendarDate(subscription.endsAt!)}.',
          );
    final String renewText = subscription.autoRenew
        ? _tr(context, 'Auto-renew is on.', 'التجديد التلقائي مفعل.')
        : _tr(context, 'Auto-renew is off.', 'التجديد التلقائي موقوف.');
    return _tr(
      context,
      '$expiryText $renewText ${widget.selectedPlan!.rewardPercent}% bonus loyalty points stay active while the plan is live.',
      '$expiryText $renewText تبقى نسبة ${widget.selectedPlan!.rewardPercent}% كنقاط ولاء إضافية طوال فترة تفعيل الباقة.',
    );
  }

  String _loyaltyBoostText() {
    final CustomerSubscriptionStatus? subscription = widget.subscriptionStatus;
    if (widget.selectedPlan == null || subscription == null) {
      return _tr(
        context,
        'Subscribe to boost every booking with bonus points.',
        'اشترك لتعزيز كل حجز بنقاط إضافية.',
      );
    }
    final String expiryText = subscription.endsAt == null
        ? _tr(context, 'Expiry date pending.', 'تاريخ الانتهاء قيد التحديد.')
        : _tr(
            context,
            'Expires ${formatCalendarDate(subscription.endsAt!)}.',
            'ينتهي ${formatCalendarDate(subscription.endsAt!)}.',
          );
    return _tr(
      context,
      '${widget.selectedPlan!.localizedName(context)} adds ${widget.selectedPlan!.rewardPercent}% bonus to each order. $expiryText',
      'تضيف باقة ${widget.selectedPlan!.localizedName(context)} نسبة ${widget.selectedPlan!.rewardPercent}% لكل طلب. $expiryText',
    );
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Salon> featuredSalons =
        (List<Salon>.from(widget.salons)
              ..sort((Salon a, Salon b) => b.rating.compareTo(a.rating)))
            .take(5)
            .toList(growable: false);
    final List<Product> featuredProducts =
        (List<Product>.from(widget.products)
              ..sort((Product a, Product b) => b.rating.compareTo(a.rating)))
            .take(5)
            .toList(growable: false);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppPalette.primary.withValues(alpha: 0.30),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _AppImage(
                        imagePath: widget.user.avatarPath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Freshline',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppPalette.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.user.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tr(
                            context,
                            'Salon booking, products, subscriptions, and loyalty',
                            'الحجوزات والمنتجات والاشتراكات والولاء',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppPalette.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: widget.onOpenNotifications,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppPalette.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          const Center(
                            child: Icon(
                              Icons.notifications_none_rounded,
                              size: 22,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppPalette.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 198,
              child: PageView.builder(
                controller: _bannerController,
                itemCount: banners.length,
                itemBuilder: (BuildContext context, int index) {
                  final PromoBanner banner = banners[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 20 : 8,
                      right: index == banners.length - 1 ? 20 : 8,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.asset(banner.imagePath, fit: BoxFit.cover),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: <Color>[
                                  AppPalette.foreground.withValues(alpha: 0.62),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  banner.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  banner.subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tr(
                              context,
                              'Choose your barber first',
                              'اختر صالونك أولاً',
                            ),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _tr(
                              context,
                              'Swipe through salons below. Search and filters are inside View All only.',
                              'تصفح الصالونات بالأسفل. البحث والفلاتر موجودة داخل عرض الكل فقط.',
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: FilledButton(
                        onPressed: widget.onOpenMap,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(56, 56),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            if (widget.isCatalogLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: appCardDecoration(),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            if (!widget.isCatalogLoading &&
                featuredSalons.isNotEmpty) ...<Widget>[
              _SectionHeader(
                title: _tr(context, 'Barber Salons', 'الصالونات'),
                onTap: widget.onOpenAllSalons,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 242,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemBuilder: (BuildContext context, int index) {
                    final Salon salon = featuredSalons[index];
                    return SizedBox(
                      width: 200,
                      child: _SalonCard(
                        salon: salon,
                        onTap: () => widget.onOpenSalon(salon),
                      ),
                    );
                  },
                  separatorBuilder: (BuildContext _, int index) =>
                      const SizedBox(width: 16),
                  itemCount: featuredSalons.length,
                ),
              ),
              const SizedBox(height: 28),
            ],
            if (!widget.isCatalogLoading && featuredSalons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: appCardDecoration(),
                  child: Text(
                    _tr(
                      context,
                      'No salons are available right now. Try the map or check again later.',
                      'لا توجد صالونات متاحة حالياً. جرّب الخريطة أو عد لاحقاً.',
                    ),
                    style: TextStyle(color: AppPalette.mutedForeground),
                  ),
                ),
              ),
            if (!widget.isCatalogLoading &&
                featuredProducts.isNotEmpty) ...<Widget>[
              _SectionHeader(
                title: _tr(
                  context,
                  'Most Purchased Products',
                  'المنتجات الأكثر شراءً',
                ),
                onTap: widget.onOpenAllProducts,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 254,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemBuilder: (BuildContext context, int index) {
                    final Product product = featuredProducts[index];
                    return SizedBox(
                      width: 164,
                      child: _ProductCard(
                        product: product,
                        onTap: () => widget.onOpenProduct(product),
                        onCartTap: () => widget.onAddToCart(product.id),
                      ),
                    );
                  },
                  separatorBuilder: (BuildContext _, int index) =>
                      const SizedBox(width: 16),
                  itemCount: featuredProducts.length,
                ),
              ),
              const SizedBox(height: 24),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.selectedPlan == null
                          ? _tr(context, 'Subscribe now', 'اشترك الآن')
                          : _tr(
                              context,
                              '${widget.selectedPlan!.localizedName(context)} plan active',
                              'باقة ${widget.selectedPlan!.localizedName(context)} مفعلة',
                            ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subscriptionSummaryText(),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.onOpenPlans,
                        child: Text(
                          widget.selectedPlan == null
                              ? _tr(context, 'Subscribe Now', 'اشترك الآن')
                              : _tr(
                                  context,
                                  'View Active Subscription',
                                  'عرض الاشتراك الحالي',
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tr(context, 'Loyalty Points', 'نقاط الولاء'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${widget.loyaltyPoints} pts',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _loyaltyBoostText(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppPalette.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.activeOrders,
    required this.completedOrders,
    required this.isLoading,
    required this.onAddReminder,
    required this.onCompleteOrder,
    required this.onRateSalonOrder,
    required this.onRateProductOrder,
  });

  final List<UserOrder> activeOrders;
  final List<UserOrder> completedOrders;
  final bool isLoading;
  final ValueChanged<UserOrder> onAddReminder;
  final Future<void> Function(UserOrder order) onCompleteOrder;
  final Future<void> Function(UserOrder order) onRateSalonOrder;
  final Future<void> Function(UserOrder order) onRateProductOrder;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _showActive = true;

  Future<void> _openOrderDetails(UserOrder order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CustomerOrderDetailsScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<UserOrder> orders = _showActive
        ? widget.activeOrders
        : widget.completedOrders;

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tr(context, 'My Orders', 'طلباتي'),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppPalette.secondary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _SegmentButton(
                          label: _tr(context, 'In Order', 'الطلبات النشطة'),
                          active: _showActive,
                          onTap: () => setState(() => _showActive = true),
                        ),
                      ),
                      Expanded(
                        child: _SegmentButton(
                          label: _tr(context, 'History', 'السجل'),
                          active: !_showActive,
                          onTap: () => setState(() => _showActive = false),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.isLoading && orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: appCardDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppPalette.primary.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _showActive
                                  ? Icons.shopping_bag_outlined
                                  : Icons.history_rounded,
                              size: 38,
                              color: AppPalette.primary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _showActive
                                ? _tr(
                                    context,
                                    'No active orders yet',
                                    'لا توجد طلبات نشطة بعد',
                                  )
                                : _tr(
                                    context,
                                    'No finished orders yet',
                                    'لا توجد طلبات مكتملة بعد',
                                  ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _showActive
                                ? _tr(
                                    context,
                                    'Your salon bookings and product orders will appear here.',
                                    'ستظهر هنا حجوزات الصالون وطلبات المنتجات الخاصة بك.',
                                  )
                                : _tr(
                                    context,
                                    'Completed bookings and delivered product orders will move here automatically.',
                                    'ستنتقل إلى هنا الحجوزات المكتملة وطلبات المنتجات التي تم تسليمها تلقائياً.',
                                  ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    itemCount: orders.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (BuildContext context, int index) {
                      final UserOrder order = orders[index];
                      final String secondaryLabel = order.isProductOrder
                          ? _tr(context, 'Delivery', 'التوصيل')
                          : _tr(context, 'Employee', 'الموظف');
                      final String modeLabel = order.isProductOrder
                          ? _tr(context, 'Fulfillment', 'طريقة التنفيذ')
                          : _tr(context, 'Visit mode', 'نوع الزيارة');
                      final String timeLabel = order.isProductOrder
                          ? _tr(context, 'Ordered at', 'تاريخ الطلب')
                          : _tr(context, 'Time', 'الوقت');
                      final bool canRateSalon =
                          !order.isProductOrder &&
                          (!order.salonReviewSubmitted ||
                              !order.employeeReviewSubmitted);
                      final bool canRateProducts =
                          order.isProductOrder &&
                          order.hasPendingProductReviews;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => unawaited(_openOrderDetails(order)),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: appCardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        order.localizedServiceName(context),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        order.localizedStatusLabel(context),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppPalette.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  order.localizedSalonName(context),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppPalette.mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _SummaryRow(
                                  label: _tr(context, 'Invoice', 'الفاتورة'),
                                  value: order.displayInvoiceNumber,
                                ),
                                _SummaryRow(
                                  label: secondaryLabel,
                                  value: order.localizedEmployeeName(context),
                                ),
                                _SummaryRow(
                                  label: modeLabel,
                                  value: order.localizedVisitMode(context),
                                ),
                                if (order.address != null)
                                  _SummaryRow(
                                    label: _tr(context, 'Address', 'العنوان'),
                                    value: order.address!,
                                  ),
                                _SummaryRow(
                                  label: timeLabel,
                                  value: _formatBookingDateTime(
                                    order.scheduledAt,
                                  ),
                                ),
                                _SummaryRow(
                                  label: _tr(context, 'Payment', 'الدفع'),
                                  value:
                                      order.cardLabel ??
                                      _tr(context, 'Card', 'بطاقة'),
                                ),
                                _SummaryRow(
                                  label: _tr(
                                    context,
                                    'Points gained',
                                    'النقاط المكتسبة',
                                  ),
                                  value: _tr(
                                    context,
                                    '${order.loyaltyPointsGained} pts',
                                    '${order.loyaltyPointsGained} نقطة',
                                  ),
                                ),
                                _SummaryRow(
                                  label: _tr(context, 'Total', 'الإجمالي'),
                                  value: formatBhd(order.total),
                                  prominent: true,
                                ),
                                if (!_showActive &&
                                    order.isProductOrder &&
                                    order.productItems.isNotEmpty) ...<Widget>[
                                  const Divider(height: 24),
                                  ...order.productItems.map((
                                    RatedOrderProductItem item,
                                  ) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _AccountInfoRow(
                                        label:
                                            _isArabicContext(context) &&
                                                (item.productNameAr ?? '')
                                                    .trim()
                                                    .isNotEmpty
                                            ? item.productNameAr!.trim()
                                            : item.productName,
                                        value: _tr(
                                          context,
                                          'x${item.quantity} · ${item.reviewSubmitted ? 'Rated' : 'Waiting for rating'}',
                                          'x${item.quantity} · ${item.reviewSubmitted ? 'تم التقييم' : 'بانتظار التقييم'}',
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                const Divider(height: 24),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _tr(
                                      context,
                                      'Open details',
                                      'عرض التفاصيل',
                                    ),
                                    style: TextStyle(
                                      color: AppPalette.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (_showActive) ...<Widget>[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      if (!order.isProductOrder) ...<Widget>[
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                widget.onAddReminder(order),
                                            child: Text(
                                              order.reminderAdded
                                                  ? _tr(
                                                      context,
                                                      'Open Again',
                                                      'افتح مرة أخرى',
                                                    )
                                                  : _tr(
                                                      context,
                                                      'Add Reminder',
                                                      'أضف تذكيراً',
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () async {
                                            await widget.onCompleteOrder(order);
                                          },
                                          child: Text(
                                            order.isProductOrder
                                                ? _tr(
                                                    context,
                                                    'Mark Delivered',
                                                    'تأكيد التسليم',
                                                  )
                                                : _tr(
                                                    context,
                                                    'Mark Finished',
                                                    'تأكيد الاكتمال',
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...<Widget>[
                                  const SizedBox(height: 12),
                                  if (canRateSalon)
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: () async {
                                          await widget.onRateSalonOrder(order);
                                        },
                                        child: Text(
                                          _tr(
                                            context,
                                            'Rate Salon & Employee',
                                            'قيّم الصالون والموظف',
                                          ),
                                        ),
                                      ),
                                    )
                                  else if (!order.isProductOrder)
                                    _HistoryStatusBadge(
                                      label: _tr(
                                        context,
                                        'Salon and employee rated',
                                        'تم تقييم الصالون والموظف',
                                      ),
                                    ),
                                  if (canRateProducts) ...<Widget>[
                                    if (!canRateSalon)
                                      const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: () async {
                                          await widget.onRateProductOrder(
                                            order,
                                          );
                                        },
                                        child: Text(
                                          order.productItems.length == 1
                                              ? _tr(
                                                  context,
                                                  'Rate Product',
                                                  'قيّم المنتج',
                                                )
                                              : _tr(
                                                  context,
                                                  'Rate Products',
                                                  'قيّم المنتجات',
                                                ),
                                        ),
                                      ),
                                    ),
                                  ] else if (order.isProductOrder) ...<Widget>[
                                    if (!canRateSalon)
                                      const SizedBox(height: 12),
                                    _HistoryStatusBadge(
                                      label: order.productItems.isEmpty
                                          ? _tr(
                                              context,
                                              'No saved product items for rating',
                                              'لا توجد منتجات محفوظة للتقييم',
                                            )
                                          : _tr(
                                              context,
                                              'All products rated',
                                              'تم تقييم جميع المنتجات',
                                            ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStatusBadge extends StatelessWidget {
  const _HistoryStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.secondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class CustomerOrderDetailsScreen extends StatelessWidget {
  const CustomerOrderDetailsScreen({super.key, required this.order});

  final UserOrder order;

  @override
  Widget build(BuildContext context) {
    final bool isProductOrder = order.isProductOrder;
    final String title = isProductOrder
        ? 'Order Details'
        : 'Appointment Details';
    final String timeLabel = isProductOrder ? 'Ordered at' : 'Appointment';
    final String secondaryLabel = isProductOrder ? 'Assigned to' : 'Employee';

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          order.localizedServiceName(context),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          order.localizedStatusLabel(context),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.localizedSalonName(context),
                    style: TextStyle(
                      fontSize: 15,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SummaryRow(
                    label: _tr(context, 'Invoice', 'الفاتورة'),
                    value: order.displayInvoiceNumber,
                  ),
                  _SummaryRow(
                    label: secondaryLabel,
                    value: order.localizedEmployeeName(context),
                  ),
                  _SummaryRow(
                    label: _tr(context, 'Mode', 'الطريقة'),
                    value: order.localizedVisitMode(context),
                  ),
                  _SummaryRow(
                    label: timeLabel,
                    value: _formatBookingDateTime(order.scheduledAt),
                  ),
                  if (order.appointmentDuration != null)
                    _SummaryRow(
                      label: _tr(context, 'Duration', 'المدة'),
                      value: _tr(
                        context,
                        '${order.appointmentDuration!.inMinutes} min',
                        '${order.appointmentDuration!.inMinutes} دقيقة',
                      ),
                    ),
                  if ((order.address ?? '').trim().isNotEmpty)
                    _SummaryRow(
                      label: _tr(context, 'Address', 'العنوان'),
                      value: order.address!,
                    ),
                  if ((order.addressDetails ?? '').trim().isNotEmpty)
                    _SummaryRow(
                      label: _tr(context, 'Location details', 'تفاصيل الموقع'),
                      value: order.addressDetails!,
                    ),
                  _SummaryRow(
                    label: _tr(context, 'Payment', 'الدفع'),
                    value:
                        order.cardLabel ??
                        _tr(context, 'Saved card', 'بطاقة محفوظة'),
                  ),
                  _SummaryRow(
                    label: _tr(context, 'Points gained', 'النقاط المكتسبة'),
                    value: _tr(
                      context,
                      '${order.loyaltyPointsGained} pts',
                      '${order.loyaltyPointsGained} نقطة',
                    ),
                  ),
                  _SummaryRow(
                    label: _tr(context, 'Total', 'الإجمالي'),
                    value: formatBhd(order.total),
                    prominent: true,
                  ),
                ],
              ),
            ),
            if (isProductOrder && order.productItems.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...order.productItems.map((RatedOrderProductItem item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AccountInfoRow(
                          label:
                              '${_isArabicContext(context) && (item.productNameAr ?? '').trim().isNotEmpty ? item.productNameAr!.trim() : item.productName} x${item.quantity}',
                          value: formatBhd(item.quantity * item.unitPrice),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SalonReviewSubmission {
  const _SalonReviewSubmission({
    required this.salonRating,
    required this.employeeRating,
    required this.salonComment,
    required this.employeeComment,
  });

  final int salonRating;
  final int employeeRating;
  final String salonComment;
  final String employeeComment;
}

class _SingleRatingSubmission {
  const _SingleRatingSubmission({required this.rating, required this.comment});

  final int rating;
  final String comment;
}

class _SalonReviewDialog extends StatefulWidget {
  const _SalonReviewDialog({required this.order});

  final UserOrder order;

  @override
  State<_SalonReviewDialog> createState() => _SalonReviewDialogState();
}

class _SalonReviewDialogState extends State<_SalonReviewDialog> {
  final TextEditingController _salonCommentController = TextEditingController();
  final TextEditingController _employeeCommentController =
      TextEditingController();
  int _salonRating = 5;
  int _employeeRating = 5;

  @override
  void dispose() {
    _salonCommentController.dispose();
    _employeeCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tr(context, 'Rate Your Appointment', 'قيّم موعدك')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.order.localizedServiceName(context),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _tr(
                context,
                '${widget.order.localizedSalonName(context)} with ${widget.order.localizedEmployeeName(context)}',
                '${widget.order.localizedSalonName(context)} مع ${widget.order.localizedEmployeeName(context)}',
              ),
              style: TextStyle(color: AppPalette.mutedForeground),
            ),
            const SizedBox(height: 18),
            _RatingPickerRow(
              label: _tr(context, 'Salon rating', 'تقييم الصالون'),
              helper: _tr(
                context,
                'How was the full salon experience?',
                'كيف كانت تجربة الصالون بشكل عام؟',
              ),
              value: _salonRating,
              onChanged: (int value) {
                setState(() => _salonRating = value);
              },
            ),
            const SizedBox(height: 18),
            _RatingPickerRow(
              label: _tr(context, 'Employee rating', 'تقييم الموظف'),
              helper: _tr(
                context,
                'How was ${widget.order.localizedEmployeeName(context)}?',
                'كيف كان ${widget.order.localizedEmployeeName(context)}؟',
              ),
              value: _employeeRating,
              onChanged: (int value) {
                setState(() => _employeeRating = value);
              },
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _salonCommentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _tr(context, 'Salon comment', 'تعليق عن الصالون'),
                hintText: _tr(
                  context,
                  'Optional notes about the salon',
                  'ملاحظات اختيارية عن الصالون',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _employeeCommentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _tr(
                  context,
                  'Employee comment',
                  'تعليق عن الموظف',
                ),
                hintText: _tr(
                  context,
                  'Optional notes about the employee',
                  'ملاحظات اختيارية عن الموظف',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tr(context, 'Cancel', 'إلغاء')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _SalonReviewSubmission(
                salonRating: _salonRating,
                employeeRating: _employeeRating,
                salonComment: _salonCommentController.text.trim(),
                employeeComment: _employeeCommentController.text.trim(),
              ),
            );
          },
          child: Text(_tr(context, 'Submit', 'إرسال')),
        ),
      ],
    );
  }
}

class _ProductReviewDialog extends StatefulWidget {
  const _ProductReviewDialog({required this.item});

  final RatedOrderProductItem item;

  @override
  State<_ProductReviewDialog> createState() => _ProductReviewDialogState();
}

class _ProductReviewDialogState extends State<_ProductReviewDialog> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tr(context, 'Rate Product', 'قيّم المنتج')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _isArabicContext(context) &&
                      (widget.item.productNameAr ?? '').trim().isNotEmpty
                  ? widget.item.productNameAr!.trim()
                  : widget.item.productName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _tr(
                context,
                'Quantity: ${widget.item.quantity}',
                'الكمية: ${widget.item.quantity}',
              ),
              style: TextStyle(color: AppPalette.mutedForeground),
            ),
            const SizedBox(height: 18),
            _RatingPickerRow(
              label: _tr(context, 'Product rating', 'تقييم المنتج'),
              helper: _tr(
                context,
                'How was this product after delivery?',
                'كيف كان هذا المنتج بعد التسليم؟',
              ),
              value: _rating,
              onChanged: (int value) {
                setState(() => _rating = value);
              },
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _tr(context, 'Comment', 'التعليق'),
                hintText: _tr(
                  context,
                  'Optional notes for this product',
                  'ملاحظات اختيارية على هذا المنتج',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tr(context, 'Skip', 'تخطي')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _SingleRatingSubmission(
                rating: _rating,
                comment: _commentController.text.trim(),
              ),
            );
          },
          child: Text(_tr(context, 'Save Rating', 'حفظ التقييم')),
        ),
      ],
    );
  }
}

class _RatingPickerRow extends StatelessWidget {
  const _RatingPickerRow({
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String helper;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(helper, style: TextStyle(color: AppPalette.mutedForeground)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: List<Widget>.generate(5, (int index) {
            final int starValue = index + 1;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(starValue),
              child: Icon(
                starValue <= value ? Icons.star_rounded : Icons.star_outline,
                color: AppPalette.primary,
                size: 30,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppPalette.background,
                AppPalette.secondary,
                AppPalette.background,
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: appCardDecoration(
                  color: AppPalette.card,
                  radius: 32,
                  border: Border.all(
                    color: AppPalette.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image.asset(
                      splashGifAssetPath,
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return const Icon(
                              Icons.content_cut_rounded,
                              size: 96,
                            );
                          },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'FreshLine',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _tr(
                        context,
                        'Salon booking, map access, AI help, and support in one app.',
                        'حجز الصالونات والخرائط والمساعدة الذكية والدعم في تطبيق واحد.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_currentPage == onboardingSlides.length - 1) {
      widget.onGetStarted();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: onboardingSlides.length,
                    onPageChanged: (int index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final OnboardingSlide baseSlide = onboardingSlides[index];
                      final String title = switch (index) {
                        0 => _tr(
                          context,
                          'Book your salon faster',
                          'احجز صالونك بشكل أسرع',
                        ),
                        1 => _tr(
                          context,
                          'Choose visit or home service',
                          'اختر الزيارة أو الخدمة المنزلية',
                        ),
                        _ => _tr(
                          context,
                          'Shop, subscribe, and earn',
                          'تسوق واشترك واكسب',
                        ),
                      };
                      final String subtitle = switch (index) {
                        0 => _tr(
                          context,
                          'Find salons, compare services, and move from browsing to booking in a few taps.',
                          'ابحث عن الصالونات وقارن الخدمات وانتقل من التصفح إلى الحجز خلال خطوات بسيطة.',
                        ),
                        1 => _tr(
                          context,
                          'Pick whether you go to the salon or the stylist comes to your location.',
                          'اختر إذا كنت تذهب إلى الصالون أو يزورك مقدم الخدمة في موقعك.',
                        ),
                        _ => _tr(
                          context,
                          'Discover products, subscribe to a plan, and collect loyalty points after each order.',
                          'اكتشف المنتجات واشترك في باقة واجمع نقاط الولاء بعد كل طلب.',
                        ),
                      };
                      return LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final double imageHeight =
                                  constraints.maxHeight > 0
                                  ? constraints.maxHeight * 0.58
                                  : 320;
                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: Image.asset(
                                        baseSlide.imagePath,
                                        height: imageHeight,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        height: 1.05,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.5,
                                        color: AppPalette.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                      );
                    },
                  ),
                ),
                Row(
                  children: <Widget>[
                    Row(
                      children: List<Widget>.generate(onboardingSlides.length, (
                        int index,
                      ) {
                        final bool active = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: EdgeInsets.only(
                            right: index == onboardingSlides.length - 1 ? 0 : 8,
                          ),
                          width: active ? 24 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: active
                                ? AppPalette.primary
                                : AppPalette.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 150,
                      child: FilledButton(
                        onPressed: _goNext,
                        child: Text(
                          _currentPage == onboardingSlides.length - 1
                              ? _tr(context, 'Get Start', 'ابدأ')
                              : _tr(context, 'Next', 'التالي'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onSignIn,
    required this.onRegisterCustomer,
    required this.onSendPasswordResetCode,
    required this.onVerifyPasswordResetCode,
    required this.onCompletePasswordReset,
    required this.onPickProfileImage,
    required this.onOpenSalonRegistration,
  });

  final Future<void> Function({
    required AppRole role,
    required String email,
    required String password,
  })
  onSignIn;
  final Future<void> Function({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String password,
    String? avatarPath,
  })
  onRegisterCustomer;
  final Future<AuthOtpDispatchResult> Function({required String email})
  onSendPasswordResetCode;
  final Future<String> Function({required String email, required String code})
  onVerifyPasswordResetCode;
  final Future<void> Function({
    required String email,
    required String verificationToken,
    required String newPassword,
  })
  onCompletePasswordReset;
  final Future<String?> Function({required String profileKey})
  onPickProfileImage;
  final Future<void> Function() onOpenSalonRegistration;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const List<AppRole> _signInRoles = <AppRole>[
    AppRole.customer,
    AppRole.salonOwner,
    AppRole.admin,
  ];

  final GlobalKey<FormState> _signInKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  AppRole _role = AppRole.customer;
  bool _hidePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_signInKey.currentState?.validate() ?? false)) {
      return;
    }

    final String email = _emailController.text.trim();
    setState(() => _isSubmitting = true);
    try {
      await widget.onSignIn(
        role: email == 'admin.com' ? AppRole.admin : _role,
        email: email,
        password: _passwordController.text.trim(),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_presentableOtpError(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RegisterScreen(
          onRegisterCustomer: widget.onRegisterCustomer,
          onPickProfileImage: widget.onPickProfileImage,
        ),
      ),
    );
  }

  Future<void> _openForgotPassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ForgotPasswordScreen(
          initialEmail: _emailController.text.trim(),
          onSendCode: widget.onSendPasswordResetCode,
          onVerifyCode: widget.onVerifyPasswordResetCode,
          onCompletePasswordReset: widget.onCompletePasswordReset,
        ),
      ),
    );
  }

  String _roleChoiceLabel(AppRole role) {
    switch (role) {
      case AppRole.customer:
        return _tr(context, 'Customer', 'عميل');
      case AppRole.salonOwner:
        return _tr(context, 'Salon', 'صالون');
      case AppRole.employee:
        return _tr(context, 'Employee', 'موظف');
      case AppRole.admin:
        return _tr(context, 'Admin', 'إدارة');
    }
  }

  String _roleDescription(AppRole role) {
    switch (role) {
      case AppRole.customer:
        return _tr(
          context,
          'Browse salons, book services, shop products, and manage your account.',
          'تصفح الصالونات واحجز الخدمات وتسوق المنتجات وأدر حسابك.',
        );
      case AppRole.salonOwner:
        return _tr(
          context,
          'Use salon sign in for both salon owners and salon employees. Owners open the owner dashboard and employees open their staff workspace automatically.',
          'استخدم دخول الصالون لمالكي الصالونات والموظفين. يتم فتح لوحة المالك أو مساحة الموظف تلقائياً حسب الحساب.',
        );
      case AppRole.employee:
        return _tr(
          context,
          'See your assigned bookings, manage your profile, and follow your salon schedule.',
          'اعرض حجوزاتك المعينة وأدر ملفك وتابع جدول عملك.',
        );
      case AppRole.admin:
        return _tr(
          context,
          'Review salons, monitor the platform, payments, admins, and notifications.',
          'راجع الصالونات وراقب المنصة والمدفوعات والمدراء والإشعارات.',
        );
    }
  }

  String _submitLabel(AppRole role) {
    switch (role) {
      case AppRole.customer:
        return _tr(context, 'Sign In As Customer', 'دخول كعميل');
      case AppRole.salonOwner:
        return _tr(context, 'Sign In To Salon', 'دخول الصالون');
      case AppRole.employee:
        return _tr(context, 'Sign In As Employee', 'دخول كموظف');
      case AppRole.admin:
        return _tr(context, 'Open Admin Dashboard', 'فتح لوحة الإدارة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String subtitle = _role == AppRole.customer
        ? _tr(
            context,
            'Sign in to discover top-rated salons, products, bookings, AI, and loyalty rewards.',
            'سجّل الدخول لاكتشاف أفضل الصالونات والمنتجات والحجوزات ومزايا الذكاء ونقاط الولاء.',
          )
        : _role == AppRole.salonOwner
        ? _tr(
            context,
            'Sign in to open your salon workspace. Freshline will send owners to the owner dashboard and employees to the employee dashboard automatically.',
            'سجّل الدخول لفتح مساحة الصالون. سيحوّل فريش لاين المالك أو الموظف إلى الواجهة المناسبة تلقائياً.',
          )
        : _role == AppRole.employee
        ? _tr(
            context,
            'Sign in to see your assigned bookings, profile, and salon updates.',
            'سجّل الدخول لعرض حجوزاتك وملفك وتحديثات الصالون.',
          )
        : _tr(
            context,
            'Sign in to review requests, payments, users, admins, and platform activity.',
            'سجّل الدخول لمراجعة الطلبات والمدفوعات والمستخدمين والمدراء ونشاط المنصة.',
          );

    return AppViewport(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AuthBrandHeader(subtitle: subtitle),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: appCardDecoration(),
                  child: Form(
                    key: _signInKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _tr(context, 'Sign In', 'تسجيل الدخول'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tr(
                            context,
                            'Choose your access type first.',
                            'اختر نوع الدخول أولاً.',
                          ),
                          style: TextStyle(color: AppPalette.mutedForeground),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _signInRoles
                              .map((AppRole role) {
                                return ChoiceChip(
                                  label: Text(_roleChoiceLabel(role)),
                                  selected: _role == role,
                                  onSelected: (_) {
                                    setState(() {
                                      _role = role;
                                    });
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: appCardDecoration(
                            color: AppPalette.secondary,
                            radius: 20,
                          ),
                          child: Text(
                            _roleDescription(_role) +
                                (_role == AppRole.admin
                                    ? _tr(
                                        context,
                                        ' Demo admin email: admin.com',
                                        ' بريد الإدارة التجريبي: admin.com',
                                      )
                                    : ''),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AuthTextField(
                          controller: _emailController,
                          label: _tr(context, 'Email', 'البريد الإلكتروني'),
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const <String>[],
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _passwordController,
                          label: _tr(context, 'Password', 'كلمة المرور'),
                          obscureText: _hidePassword,
                          validator: _validatePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const <String>[],
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(_passwordVisibilityIcon(_hidePassword)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: Text(_submitLabel(_role)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : _openForgotPassword,
                            child: Text(
                              _tr(
                                context,
                                'Forgot password?',
                                'نسيت كلمة المرور؟',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: _openRegister,
                            child: Text(
                              _tr(
                                context,
                                "I don't have an account",
                                'ليس لدي حساب',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: appCardDecoration(
                            color: AppPalette.background,
                            radius: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _tr(
                                  context,
                                  'Need a salon account?',
                                  'تحتاج حساب صالون؟',
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _tr(
                                  context,
                                  'Create the salon owner account first, then open Add a New Request and upload the salon image and required files.',
                                  'أنشئ حساب مالك الصالون أولاً ثم افتح إضافة طلب جديد وارفع صورة الصالون والملفات المطلوبة.',
                                ),
                                style: TextStyle(
                                  color: AppPalette.mutedForeground,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: widget.onOpenSalonRegistration,
                                  child: Text(
                                    _tr(
                                      context,
                                      'Register Your Salon',
                                      'سجل صالونك',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty || (!text.contains('@') && text != 'admin.com')) {
      return _tr(
        context,
        'Enter a valid email.',
        'أدخل بريداً إلكترونياً صحيحاً.',
      );
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').trim().length < 6) {
      return _tr(
        context,
        'Use at least 6 characters.',
        'استخدم 6 أحرف على الأقل.',
      );
    }
    return null;
  }
}

String _maskEmailAddress(String email) {
  final String normalized = email.trim();
  final int atIndex = normalized.indexOf('@');
  if (atIndex <= 1 || atIndex == normalized.length - 1) {
    return normalized;
  }
  final String localPart = normalized.substring(0, atIndex);
  final String domainPart = normalized.substring(atIndex);
  if (localPart.length <= 2) {
    return '${localPart[0]}*$domainPart';
  }
  final String maskedMiddle = List<String>.filled(
    localPart.length - 2,
    '*',
  ).join();
  return '${localPart[0]}$maskedMiddle${localPart[localPart.length - 1]}$domainPart';
}

String _maskPersonName(String name) {
  final String normalized = name.trim();
  if (normalized.length <= 2) {
    return normalized;
  }
  final String maskedMiddle = List<String>.filled(
    normalized.length - 2,
    '*',
  ).join();
  return '${normalized[0]}$maskedMiddle${normalized[normalized.length - 1]}';
}

IconData _passwordVisibilityIcon(bool isHidden) {
  return isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined;
}

class OtpChallengeScreen<T> extends StatefulWidget {
  const OtpChallengeScreen({
    super.key,
    required this.email,
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.onVerify,
    this.initialDispatchResult,
    this.onResend,
    this.resendSuccessMessage,
    this.resendCooldownSeconds = 3600,
  });

  final String email;
  final String title;
  final String subtitle;
  final String primaryActionLabel;
  final Future<T> Function(String code) onVerify;
  final AuthOtpDispatchResult? initialDispatchResult;
  final Future<AuthOtpDispatchResult?> Function()? onResend;
  final String? resendSuccessMessage;
  final int resendCooldownSeconds;

  @override
  State<OtpChallengeScreen<T>> createState() => _OtpChallengeScreenState<T>();
}

class _OtpChallengeScreenState<T> extends State<OtpChallengeScreen<T>> {
  final GlobalKey<_OtpCodeInputState> _otpInputKey =
      GlobalKey<_OtpCodeInputState>();
  Timer? _resendTimer;
  String _code = '';
  String? _codeErrorText;
  AuthOtpDispatchResult? _latestDispatchResult;
  bool _isVerifying = false;
  bool _isResending = false;
  int _remainingResendSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.onResend != null) {
      _startResendCountdown(widget.resendCooldownSeconds);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    _remainingResendSeconds = seconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingResendSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingResendSeconds = 0);
        return;
      }
      setState(() => _remainingResendSeconds -= 1);
    });
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() {
        _codeErrorText = _tr(
          context,
          'Enter the 6-digit code.',
          'أدخل الرمز المكوّن من 6 أرقام.',
        );
      });
      return;
    }
    setState(() {
      _isVerifying = true;
      _codeErrorText = null;
    });
    try {
      final T result = await widget.onVerify(_code);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<T>(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_presentableOtpError(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resend() async {
    if (widget.onResend == null ||
        _remainingResendSeconds > 0 ||
        _isResending) {
      return;
    }
    setState(() => _isResending = true);
    try {
      final AuthOtpDispatchResult? result = await widget.onResend!();
      if (!mounted) {
        return;
      }
      _otpInputKey.currentState?.clear();
      setState(() {
        _code = '';
        _codeErrorText = null;
        _latestDispatchResult = result;
      });
      _startResendCountdown(widget.resendCooldownSeconds);
      final String? dispatchMessage = _otpDispatchMessage(context, result);
      if ((dispatchMessage ?? '').trim().isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(dispatchMessage!)));
      } else if ((widget.resendSuccessMessage ?? '').trim().isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(widget.resendSuccessMessage!)));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String rawMessage =
          error.toString().replaceFirst('Bad state: ', '').trim();
      final String message = _presentableOtpError(context, error);
      if (_isOtpRateLimitMessage(rawMessage)) {
        _startResendCountdown(widget.resendCooldownSeconds);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthOtpDispatchResult? dispatchResult =
        _latestDispatchResult ?? widget.initialDispatchResult;
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: AppPalette.mutedForeground,
                      height: 1.45,
                    ),
                  ),
                  if ((_otpDispatchMessage(context, dispatchResult) ?? '')
                      .trim()
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _otpDispatchBanner(context, dispatchResult),
                  ],
                  const SizedBox(height: 18),
                  _AccountInfoRow(
                    label: _tr(context, 'Email', 'البريد الإلكتروني'),
                    value: widget.email,
                  ),
                  const SizedBox(height: 18),
                  _OtpCodeInput(
                    key: _otpInputKey,
                    enabled: !_isVerifying && !_isResending,
                    errorText: _codeErrorText,
                    onChanged: (String value) {
                      if (_codeErrorText != null && value.length <= 6) {
                        setState(() => _codeErrorText = null);
                      }
                      _code = value;
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isVerifying || _isResending ? null : _verify,
                      child: Text(
                        _isVerifying
                            ? _tr(context, 'Verifying...', 'جارٍ التحقق...')
                            : widget.primaryActionLabel,
                      ),
                    ),
                  ),
                  if (widget.onResend != null) ...<Widget>[
                    const SizedBox(height: 14),
                    if (_remainingResendSeconds > 0)
                      Text(
                        _tr(
                          context,
                          'You can resend a new code in ${_remainingResendSeconds}s.',
                          'يمكنك إعادة إرسال رمز جديد بعد $_remainingResendSeconds ثانية.',
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.mutedForeground,
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isResending ? null : _resend,
                          child: Text(
                            _isResending
                                ? _tr(
                                    context,
                                    'Resending Code...',
                                    'جارٍ إعادة إرسال الرمز...',
                                  )
                                : _tr(
                                    context,
                                    'Resend Code To Email',
                                    'إعادة إرسال الرمز إلى البريد',
                                  ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpCodeInput extends StatefulWidget {
  const _OtpCodeInput({
    super.key,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? errorText;

  @override
  State<_OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<_OtpCodeInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isApplyingNormalization = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void clear() {
    _controller.clear();
    widget.onChanged('');
    _focusNode.requestFocus();
    setState(() {});
  }

  String _normalizeOtp(String input) {
    final String digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length <= 6) {
      return digitsOnly;
    }
    return digitsOnly.substring(0, 6);
  }

  void _handleChanged(String value) {
    if (_isApplyingNormalization) {
      return;
    }
    final String normalized = _normalizeOtp(value);
    if (normalized != value) {
      _isApplyingNormalization = true;
      _controller.text = normalized;
      _controller.selection = TextSelection.collapsed(offset: normalized.length);
      _isApplyingNormalization = false;
    }
    widget.onChanged(normalized);
    if (normalized.length == 6) {
      _focusNode.unfocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final String code = _normalizeOtp(_controller.text);
    final bool hasFocus = _focusNode.hasFocus;
    final int activeIndex = (code.length.clamp(0, 5) as num).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[
              Opacity(
                opacity: 0.01,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.oneTimeCode],
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _handleChanged,
                  ),
                ),
              ),
              Row(
                children: List<Widget>.generate(6, (int index) {
                  final String digit = index < code.length ? code[index] : '';
                  final bool isActive = hasFocus && index == activeIndex;
                  final Color borderColor =
                      isActive ? AppPalette.primary : AppPalette.border;
                  return Expanded(
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.only(end: index == 5 ? 0 : 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppPalette.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: borderColor,
                            width: isActive ? 1.4 : 1,
                          ),
                        ),
                        child: Text(
                          digit,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        if ((widget.errorText ?? '').trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onCompletePasswordReset,
    this.initialEmail = '',
  });

  final Future<AuthOtpDispatchResult> Function({required String email})
  onSendCode;
  final Future<String> Function({required String email, required String code})
  onVerifyCode;
  final Future<void> Function({
    required String email,
    required String verificationToken,
    required String newPassword,
  })
  onCompletePasswordReset;
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _sendCodeFormKey = GlobalKey<FormState>();
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  bool _isSendingCode = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_sendCodeFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final String email = _emailController.text.trim();
    setState(() => _isSendingCode = true);
    try {
      AuthOtpDispatchResult dispatchResult = const AuthOtpDispatchResult();
      int resendCooldownSeconds = 300;
      Object? dispatchError;
      try {
        dispatchResult = await widget.onSendCode(email: email);
      } catch (error) {
        final String rawMessage =
            error.toString().replaceFirst('Bad state: ', '').trim();
        if (_isOtpRateLimitMessage(rawMessage)) {
          dispatchError = error;
          resendCooldownSeconds = 3600;
        } else {
          rethrow;
        }
      }
      if (!mounted) {
        return;
      }
      if (dispatchError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_presentableOtpError(context, dispatchError))),
        );
      }
      final String?
      verificationToken = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (BuildContext context) => OtpChallengeScreen<String>(
            email: email,
            initialDispatchResult: dispatchResult,
            title: _tr(
              context,
              'Verify Reset Code',
              'تحقق من رمز إعادة التعيين',
            ),
            subtitle: _tr(
              context,
              'Enter the 6-digit password reset code sent to ${_maskEmailAddress(email)}.',
              'أدخل رمز إعادة التعيين المكوّن من 6 أرقام المرسل إلى ${_maskEmailAddress(email)}.',
            ),
            primaryActionLabel: _tr(context, 'Verify Code', 'تحقق من الرمز'),
            resendSuccessMessage: _tr(
              context,
              'A new reset code was sent to your email.',
              'تم إرسال رمز إعادة تعيين جديد إلى بريدك الإلكتروني.',
            ),
            resendCooldownSeconds: resendCooldownSeconds,
            onVerify: (String code) {
              return widget.onVerifyCode(email: email, code: code);
            },
            onResend: () => widget.onSendCode(email: email),
          ),
        ),
      );
      if (!mounted || verificationToken == null) {
        return;
      }
      final bool? passwordResetCompleted = await Navigator.of(context)
          .push<bool>(
            MaterialPageRoute<bool>(
              builder: (BuildContext context) => ResetPasswordNewPasswordScreen(
                email: email,
                verificationToken: verificationToken,
                onCompletePasswordReset: widget.onCompletePasswordReset,
              ),
            ),
          );
      if (!mounted || passwordResetCompleted != true) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_presentableOtpError(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Forgot Password', 'نسيت كلمة المرور')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Form(
                key: _sendCodeFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tr(
                        context,
                        'Reset Your Password',
                        'إعادة تعيين كلمة المرور',
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _tr(
                        context,
                        'Enter your sign-in email and we will send a 6-digit code. After you verify it, you will choose a new password on the next screen.',
                        'أدخل بريد تسجيل الدخول وسنرسل رمزاً من 6 أرقام. بعد التحقق منه ستختار كلمة مرور جديدة في الشاشة التالية.',
                      ),
                      style: TextStyle(
                        color: AppPalette.mutedForeground,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AuthTextField(
                      controller: _emailController,
                      label: _tr(context, 'Email', 'البريد الإلكتروني'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (String? value) {
                        final String text = (value ?? '').trim();
                        if (text.isEmpty ||
                            (!text.contains('@') && text != 'admin.com')) {
                          return _tr(
                            context,
                            'Enter a valid email.',
                            'أدخل بريداً إلكترونياً صحيحاً.',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _isSendingCode ? null : _sendCode,
                        child: Text(
                          _isSendingCode
                              ? _tr(
                                  context,
                                  'Sending Code...',
                                  'جارٍ إرسال الرمز...',
                                )
                              : _tr(
                                  context,
                                  'Send Reset Code',
                                  'إرسال رمز إعادة التعيين',
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordNewPasswordScreen extends StatefulWidget {
  const ResetPasswordNewPasswordScreen({
    super.key,
    required this.email,
    required this.verificationToken,
    required this.onCompletePasswordReset,
  });

  final String email;
  final String verificationToken;
  final Future<void> Function({
    required String email,
    required String verificationToken,
    required String newPassword,
  })
  onCompletePasswordReset;

  @override
  State<ResetPasswordNewPasswordScreen> createState() =>
      _ResetPasswordNewPasswordScreenState();
}

class _ResetPasswordNewPasswordScreenState
    extends State<ResetPasswordNewPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;
  bool _isResettingPassword = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _completeReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isResettingPassword = true);
    try {
      await widget.onCompletePasswordReset(
        email: widget.email,
        verificationToken: widget.verificationToken,
        newPassword: _newPasswordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Password reset successfully. You can sign in now.',
              'تمت إعادة تعيين كلمة المرور بنجاح. يمكنك تسجيل الدخول الآن.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResettingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'New Password', 'كلمة مرور جديدة')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tr(
                        context,
                        'Choose A New Password',
                        'اختر كلمة مرور جديدة',
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _tr(
                        context,
                        'The reset code for ${_maskEmailAddress(widget.email)} was verified. Set your new password below.',
                        'تم التحقق من رمز إعادة التعيين للحساب ${_maskEmailAddress(widget.email)}. عيّن كلمة المرور الجديدة أدناه.',
                      ),
                      style: TextStyle(
                        color: AppPalette.mutedForeground,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AuthTextField(
                      controller: _newPasswordController,
                      label: _tr(
                        context,
                        'New Password',
                        'كلمة المرور الجديدة',
                      ),
                      obscureText: _hideNewPassword,
                      validator: (String? value) {
                        if ((value ?? '').trim().length < 6) {
                          return _tr(
                            context,
                            'Use at least 6 characters.',
                            'استخدم 6 أحرف على الأقل.',
                          );
                        }
                        return null;
                      },
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _hideNewPassword = !_hideNewPassword);
                        },
                        icon: Icon(_passwordVisibilityIcon(_hideNewPassword)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _confirmPasswordController,
                      label: _tr(
                        context,
                        'Confirm New Password',
                        'تأكيد كلمة المرور الجديدة',
                      ),
                      obscureText: _hideConfirmPassword,
                      validator: (String? value) {
                        if ((value ?? '').trim().isEmpty) {
                          return _tr(
                            context,
                            'This field is required.',
                            'هذا الحقل مطلوب.',
                          );
                        }
                        if (value != _newPasswordController.text) {
                          return _tr(
                            context,
                            'Passwords do not match.',
                            'كلمتا المرور غير متطابقتين.',
                          );
                        }
                        return null;
                      },
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(
                            () => _hideConfirmPassword = !_hideConfirmPassword,
                          );
                        },
                        icon: Icon(
                          _passwordVisibilityIcon(_hideConfirmPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isResettingPassword ? null : _completeReset,
                        child: Text(
                          _isResettingPassword
                              ? _tr(
                                  context,
                                  'Updating Password...',
                                  'جارٍ تحديث كلمة المرور...',
                                )
                              : _tr(
                                  context,
                                  'Save New Password',
                                  'حفظ كلمة المرور الجديدة',
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.onRegisterCustomer,
    required this.onPickProfileImage,
  });

  final Future<void> Function({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String password,
    String? avatarPath,
  })
  onRegisterCustomer;
  final Future<String?> Function({required String profileKey})
  onPickProfileImage;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _registerKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isContinuing = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _continueToProfile() async {
    if (!(_registerKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isContinuing = true);
    try {
      final bool? created = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (BuildContext context) => RegisterProfileDetailsScreen(
            username: _titleCase(_usernameController.text.trim()),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            onRegisterCustomer: widget.onRegisterCustomer,
            onPickProfileImage: widget.onPickProfileImage,
          ),
        ),
      );
      if (created == true && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isContinuing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Create Account', 'إنشاء حساب')),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AuthBrandHeader(
                  subtitle: _tr(
                    context,
                    'Step 1 of 2. Start with your email, username, and password.',
                    'الخطوة 1 من 2. ابدأ بالبريد واسم المستخدم وكلمة المرور.',
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: appCardDecoration(),
                  child: Form(
                    key: _registerKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _tr(context, 'Register', 'التسجيل'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tr(
                            context,
                            'We will ask for your phone, city, and profile image on the next screen.',
                            'سنطلب منك رقم الهاتف والمدينة وصورة الحساب في الشاشة التالية.',
                          ),
                          style: TextStyle(color: AppPalette.mutedForeground),
                        ),
                        const SizedBox(height: 18),
                        _AuthTextField(
                          controller: _emailController,
                          label: _tr(context, 'Email', 'البريد الإلكتروني'),
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _usernameController,
                          label: _tr(context, 'Username', 'اسم المستخدم'),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _passwordController,
                          label: _tr(context, 'Password', 'كلمة المرور'),
                          obscureText: _hidePassword,
                          validator: _validatePassword,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(_passwordVisibilityIcon(_hidePassword)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _confirmController,
                          label: _tr(
                            context,
                            'Confirm Password',
                            'تأكيد كلمة المرور',
                          ),
                          obscureText: _hideConfirmPassword,
                          validator: (String? value) {
                            if ((value ?? '').trim().isEmpty) {
                              return _tr(
                                context,
                                'This field is required.',
                                'هذا الحقل مطلوب.',
                              );
                            }
                            if (value != _passwordController.text) {
                              return _tr(
                                context,
                                'Passwords do not match.',
                                'كلمتا المرور غير متطابقتين.',
                              );
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _hideConfirmPassword =
                                    !_hideConfirmPassword,
                              );
                            },
                            icon: Icon(
                              _passwordVisibilityIcon(_hideConfirmPassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isContinuing
                                ? null
                                : _continueToProfile,
                            child: Text(
                              _isContinuing
                                  ? _tr(
                                      context,
                                      'Opening Next Step...',
                                      'جاري فتح الخطوة التالية...',
                                    )
                                  : _tr(context, 'Next', 'التالي'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateRequired(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return _tr(context, 'This field is required.', 'هذا الحقل مطلوب.');
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty || !text.contains('@')) {
      return _tr(
        context,
        'Enter a valid email.',
        'أدخل بريداً إلكترونياً صحيحاً.',
      );
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').trim().length < 6) {
      return _tr(
        context,
        'Use at least 6 characters.',
        'استخدم 6 أحرف على الأقل.',
      );
    }
    return null;
  }
}

class RegisterProfileDetailsScreen extends StatefulWidget {
  const RegisterProfileDetailsScreen({
    super.key,
    required this.username,
    required this.email,
    required this.password,
    required this.onRegisterCustomer,
    required this.onPickProfileImage,
  });

  final String username;
  final String email;
  final String password;
  final Future<void> Function({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String password,
    String? avatarPath,
  })
  onRegisterCustomer;
  final Future<String?> Function({required String profileKey})
  onPickProfileImage;

  @override
  State<RegisterProfileDetailsScreen> createState() =>
      _RegisterProfileDetailsScreenState();
}

class _RegisterProfileDetailsScreenState
    extends State<RegisterProfileDetailsScreen> {
  final GlobalKey<FormState> _detailsKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController(
    text: defaultBahrainLocation,
  );
  String _avatarPath = currentDefaultProfileImageUrl();
  bool _isUploadingImage = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
    setState(() => _isUploadingImage = true);
    try {
      final String? uploadedPath = await widget.onPickProfileImage(
        profileKey: widget.email,
      );
      if (!mounted || uploadedPath == null || uploadedPath.trim().isEmpty) {
        return;
      }
      setState(() => _avatarPath = uploadedPath);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!(_detailsKey.currentState?.validate() ?? false)) {
      return;
    }

    final String normalizedPhone = normalizeBahrainPhoneOrThrow(
      _phoneController.text,
    );
    setState(() => _isSubmitting = true);
    try {
      await widget.onRegisterCustomer(
        name: widget.username,
        email: widget.email,
        phone: normalizedPhone,
        city: normalizeBahrainLocation(_cityController.text),
        password: widget.password,
        avatarPath: _avatarPath,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_presentableAuthError(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Create Account', 'إنشاء حساب')),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AuthBrandHeader(
                  subtitle: _tr(
                    context,
                    'Step 2 of 2. Finish your profile details before creating the account.',
                    'الخطوة 2 من 2. أكمل بيانات الملف قبل إنشاء الحساب.',
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: appCardDecoration(),
                  child: Form(
                    key: _detailsKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _tr(
                            context,
                            'Complete Profile',
                            'إكمال الملف الشخصي',
                          ),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tr(
                            context,
                            'Add your profile image and personal contact details. If you skip the image, Freshline keeps the default one.',
                            'أضف صورة الحساب وبيانات التواصل. إذا تخطيت الصورة فسيتم استخدام الافتراضية.',
                          ),
                          style: TextStyle(color: AppPalette.mutedForeground),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppPalette.primary.withValues(
                                    alpha: 0.22,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: _AppImage(
                                  imagePath: _avatarPath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    widget.username,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.email,
                                    style: TextStyle(
                                      color: AppPalette.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _isUploadingImage
                                        ? null
                                        : _uploadImage,
                                    icon: Icon(
                                      _isUploadingImage
                                          ? Icons.hourglass_top_rounded
                                          : Icons.upload_outlined,
                                    ),
                                    label: Text(
                                      _isUploadingImage
                                          ? _tr(
                                              context,
                                              'Uploading...',
                                              'جاري الرفع...',
                                            )
                                          : _tr(
                                              context,
                                              'Upload Photo',
                                              'رفع صورة',
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppPalette.background,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppPalette.border),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.info_outline,
                                color: AppPalette.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _tr(
                                    context,
                                    'No uploaded photo? Freshline will use the default profile image automatically.',
                                    'لا توجد صورة مرفوعة؟ سيستخدم فريش لاين الصورة الافتراضية تلقائياً.',
                                  ),
                                  style: TextStyle(
                                    color: AppPalette.mutedForeground,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _phoneController,
                          label: _tr(context, 'Phone', 'الهاتف'),
                          keyboardType: TextInputType.phone,
                          validator: validateRequiredBahrainPhone,
                          inputFormatters: bahrainPhoneInputFormatters,
                        ),
                        const SizedBox(height: 14),
                        _BahrainLocationDropdownField(
                          controller: _cityController,
                          label: _tr(context, 'City', 'المدينة'),
                          validator: _requiredField,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: Text(
                              _isSubmitting
                                  ? _tr(
                                      context,
                                      'Creating Account...',
                                      'جاري إنشاء الحساب...',
                                    )
                                  : _tr(
                                      context,
                                      'Create Account',
                                      'إنشاء الحساب',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredField(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return _tr(context, 'This field is required.', 'هذا الحقل مطلوب.');
    }
    return null;
  }
}

class EmailVerificationPendingScreen extends StatefulWidget {
  const EmailVerificationPendingScreen({
    super.key,
    required this.email,
    required this.onVerifyCode,
    required this.onContinue,
    this.initialDispatchResult,
  });

  final String email;
  final Future<void> Function(String code) onVerifyCode;
  final Future<AppUser> Function() onContinue;
  final AuthOtpDispatchResult? initialDispatchResult;

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  final GlobalKey<FormState> _verifyCodeFormKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  bool _isVerifyingCode = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCodeAndContinue() async {
    if (!(_verifyCodeFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isVerifyingCode = true);
    try {
      await widget.onVerifyCode(_codeController.text.trim());
      final AppUser user = await widget.onContinue();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(user);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_presentableOtpError(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifyingCode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Verify Email', 'تحقق من البريد')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tr(context, 'One more step', 'تبقى خطوة أخيرة'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _tr(
                      context,
                      'Enter the 6-digit verification code sent to ${_maskEmailAddress(widget.email)}.',
                      'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى ${_maskEmailAddress(widget.email)}.',
                    ),
                    style: TextStyle(
                      color: AppPalette.mutedForeground,
                      height: 1.45,
                    ),
                  ),
                  if ((_otpDispatchMessage(
                        context,
                        widget.initialDispatchResult,
                      ) ??
                      '')
                      .trim()
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _otpDispatchBanner(context, widget.initialDispatchResult),
                  ],
                  const SizedBox(height: 18),
                  _AccountInfoRow(
                    label: _tr(context, 'Email', 'البريد الإلكتروني'),
                    value: widget.email,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _tr(
                      context,
                      'If you do not see the email, check your spam or junk folder. You can also go back and send a new code from Account Details.',
                      'إذا لم تجد الرسالة، فتحقّق من مجلد الرسائل غير المرغوبة أو البريد العشوائي. يمكنك أيضاً الرجوع وإرسال رمز جديد من تفاصيل الحساب.',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _verifyCodeFormKey,
                    child: Column(
                      children: <Widget>[
                        _AuthTextField(
                          controller: _codeController,
                          label: _tr(context, '6-Digit Code', 'رمز من 6 أرقام'),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (String? value) {
                            if ((value ?? '').trim().length != 6) {
                              return _tr(
                                context,
                                'Enter the 6-digit code.',
                                'أدخل الرمز المكوّن من 6 أرقام.',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                _isVerifyingCode ? null : _verifyCodeAndContinue,
                            child: Text(
                              _isVerifyingCode
                                  ? _tr(
                                      context,
                                      'Verifying Code...',
                                      'جارٍ التحقق من الرمز...',
                                    )
                                  : _tr(
                                      context,
                                      'Verify Code And Continue',
                                      'تحقق من الرمز وأكمل',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isVerifyingCode
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        _tr(context, 'Back To Sign In', 'العودة لتسجيل الدخول'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppPalette.card,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppPalette.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Image.asset(
            appIconAssetPath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'FreshLine',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppPalette.mutedForeground,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.validator,
    this.suffixIcon,
    this.onChanged,
    this.inputFormatters,
    this.autofillHints,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppPalette.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppPalette.primary),
        ),
      ),
    );
  }
}

class _BahrainLocationDropdownField extends StatelessWidget {
  const _BahrainLocationDropdownField({
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? child) {
        final String selectedLocation = normalizeBahrainLocation(value.text);
        if (selectedLocation != value.text) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (controller.text != selectedLocation) {
              controller.text = selectedLocation;
            }
          });
        }

        return DropdownButtonFormField<String>(
          key: ValueKey<String>(selectedLocation),
          initialValue: selectedLocation,
          isExpanded: true,
          menuMaxHeight: 420,
          validator: validator,
          items: bahrainLocations
              .map(
                (String location) => DropdownMenuItem<String>(
                  value: location,
                  child: Text(location),
                ),
              )
              .toList(growable: false),
          onChanged: (String? newValue) {
            if (newValue != null) {
              controller.text = newValue;
            }
          },
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppPalette.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppPalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppPalette.primary),
            ),
          ),
        );
      },
    );
  }
}

class RegisterSalonPlaceholderScreen extends StatelessWidget {
  const RegisterSalonPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Register Your Salon', 'سجل صالونك')),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _EmptyStateCard(
              icon: Icons.storefront_outlined,
              title: _tr(
                context,
                'Open salon registration from sign in',
                'افتح تسجيل الصالون من شاشة الدخول',
              ),
              message: _tr(
                context,
                'Use the Register Your Salon button on the sign-in screen to create the owner account first, then add the salon request.',
                'استخدم زر سجل صالونك من شاشة الدخول لإنشاء حساب المالك أولاً ثم أضف طلب الصالون.',
              ),
              actionLabel: _tr(context, 'Go Back', 'رجوع'),
              onAction: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class MapTabScreen extends StatefulWidget {
  const MapTabScreen({super.key, required this.salons});

  final List<Salon> salons;

  @override
  State<MapTabScreen> createState() => _MapTabScreenState();
}

class _MapTabScreenState extends State<MapTabScreen> {
  String _selectedSalonId = '';

  @override
  Widget build(BuildContext context) {
    if (widget.salons.isEmpty) {
      return AppViewport(
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _TopBar(
                  title: _tr(context, 'Salon Map', 'خريطة الصالون'),
                  onBack: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    child: _EmptyStateCard(
                      icon: Icons.map_outlined,
                      title: 'No salons on the map yet',
                      message:
                          'When salon data is available from Supabase, map markers and navigation will appear here.',
                      actionLabel: 'Go Back',
                      onAction: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final String activeSalonId =
        widget.salons.any((Salon salon) => salon.id == _selectedSalonId)
        ? _selectedSalonId
        : widget.salons.first.id;
    final Salon selectedSalon = widget.salons.firstWhere(
      (Salon salon) => salon.id == activeSalonId,
    );
    final SalonMapInfo fallbackMapInfo = mapInfoForSalon(selectedSalon.id);
    final SalonMapInfo selectedMapInfo = SalonMapInfo(
      salonId: selectedSalon.id,
      address: selectedSalon.address ?? fallbackMapInfo.address,
      city: selectedSalon.location,
      latitude: selectedSalon.latitude ?? fallbackMapInfo.latitude,
      longitude: selectedSalon.longitude ?? fallbackMapInfo.longitude,
    );
    final Employee selectedEmployee = _employeeForSalon(selectedSalon.id);

    return AppViewport(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TopBar(
                title: _tr(context, 'Salon Map', 'خريطة الصالون'),
                subtitle: selectedSalon.localizedName(context),
                onBack: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: appCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Map API',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: goMapsApiKey,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'GoMaps API',
                          suffixIcon: IconButton(
                            onPressed: () => _copyToClipboard(
                              context,
                              goMapsApiKey,
                              'GoMaps API copied',
                            ),
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: <Widget>[
                        FlutterMap(
                          key: ValueKey<String>(activeSalonId),
                          options: MapOptions(
                            initialCenter: LatLng(
                              selectedMapInfo.latitude,
                              selectedMapInfo.longitude,
                            ),
                            initialZoom: 13.5,
                          ),
                          children: <Widget>[
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'freshline_tt',
                            ),
                            MarkerLayer(
                              markers: widget.salons
                                  .map((Salon salon) {
                                    final SalonMapInfo fallbackInfo =
                                        mapInfoForSalon(salon.id);
                                    final SalonMapInfo info = SalonMapInfo(
                                      salonId: salon.id,
                                      address:
                                          salon.address ?? fallbackInfo.address,
                                      city: salon.location,
                                      latitude:
                                          salon.latitude ??
                                          fallbackInfo.latitude,
                                      longitude:
                                          salon.longitude ??
                                          fallbackInfo.longitude,
                                    );
                                    return Marker(
                                      point: LatLng(
                                        info.latitude,
                                        info.longitude,
                                      ),
                                      width: 54,
                                      height: 54,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(
                                            () => _selectedSalonId = salon.id,
                                          );
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: salon.id == activeSalonId
                                                ? AppPalette.primary
                                                : AppPalette.card,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppPalette.white,
                                              width: 3,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.location_on_rounded,
                                            color: salon.id == activeSalonId
                                                ? Colors.white
                                                : AppPalette.primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: appCardDecoration(
                              color: AppPalette.card.withValues(alpha: 0.96),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  selectedSalon.localizedName(context),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_localizedDisplayText(context, selectedMapInfo.address)} · ${_localizedDisplayText(context, selectedMapInfo.city)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppPalette.mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: <Widget>[
                                    ClipOval(
                                      child: _AppImage(
                                        imagePath: selectedEmployee.imagePath,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            _tr(
                                              context,
                                              '${selectedEmployee.name} available',
                                              '${selectedEmployee.name} متاح',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            _localizedDisplayText(
                                              context,
                                              selectedEmployee.role,
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppPalette.mutedForeground,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () => _openNavigation(
                                        context,
                                        selectedMapInfo,
                                      ),
                                      child: Text(
                                        _localizedDisplayText(
                                          context,
                                          'Navigate',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 52,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: widget.salons.length,
                                    separatorBuilder:
                                        (BuildContext context, int index) =>
                                            const SizedBox(width: 10),
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final Salon salon =
                                              widget.salons[index];
                                          final bool active =
                                              salon.id == activeSalonId;
                                          return ChoiceChip(
                                            label: Text(
                                              salon.localizedName(context),
                                            ),
                                            selected: active,
                                            selectedColor: AppPalette.primary
                                                .withValues(alpha: 0.16),
                                            backgroundColor: AppPalette.card,
                                            side: BorderSide(
                                              color: active
                                                  ? AppPalette.primary
                                                  : AppPalette.border,
                                            ),
                                            onSelected: (_) {
                                              setState(
                                                () =>
                                                    _selectedSalonId = salon.id,
                                              );
                                            },
                                          );
                                        },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AiStylistScreen extends StatefulWidget {
  const AiStylistScreen({
    super.key,
    required this.role,
    this.selectedLanguage = 'EN',
  });

  final AppRole role;
  final String selectedLanguage;

  @override
  State<AiStylistScreen> createState() => _AiStylistScreenState();
}

class _AiStylistScreenState extends State<AiStylistScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final GroqService _groqService;
  late final stt.SpeechToText _speechToText;
  final List<_AiChatMessage> _messages = <_AiChatMessage>[];
  bool _isSending = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _voiceDraftPrefix = '';

  @override
  void initState() {
    super.initState();
    _groqService = GroqService();
    _speechToText = stt.SpeechToText();
    _messages.add(
      _AiChatMessage(
        role: 'assistant',
        text: _welcomeMessageForRole(widget.role, widget.selectedLanguage),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AiStylistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String oldWelcome = _welcomeMessageForRole(
      oldWidget.role,
      oldWidget.selectedLanguage,
    );
    final String newWelcome = _welcomeMessageForRole(
      widget.role,
      widget.selectedLanguage,
    );
    if (_messages.length == 1 &&
        _messages.first.role == 'assistant' &&
        _messages.first.text == oldWelcome &&
        oldWelcome != newWelcome) {
      _messages[0] = _AiChatMessage(role: 'assistant', text: newWelcome);
    }
  }

  @override
  void dispose() {
    unawaited(_speechToText.cancel());
    _controller.dispose();
    _scrollController.dispose();
    _groqService.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? preset]) async {
    if (_isSending) {
      return;
    }

    if (_isListening) {
      await _stopVoiceInput();
    }

    final String text = (preset ?? _controller.text).trim();
    if (text.isEmpty) {
      return;
    }

    final String language = _detectLanguage(text);
    final String systemLanguageCode = language == 'Arabic' ? 'AR' : 'EN';
    _controller.clear();

    setState(() {
      _isSending = true;
      _messages.add(_AiChatMessage(role: 'user', text: text));
    });
    _jumpToBottom();

    try {
      final String reply = await _groqService.chat(
        languageHint: language,
        systemPrompt: _systemPromptForRole(
          widget.role,
          systemLanguageCode,
        ),
        history: _messages
            .map(
              (_AiChatMessage message) =>
                  GroqMessage(role: message.role, content: message.text),
            )
            .toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_AiChatMessage(role: 'assistant', text: reply));
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _AiChatMessage(
            role: 'assistant',
            text: _trForLanguage(
              systemLanguageCode,
              'FreshLine AI is unavailable right now. Please try again in a moment.',
              'مساعد فريش لاين غير متاح حالياً. حاول مرة أخرى بعد قليل.',
            ),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _jumpToBottom();
      }
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isSending) {
      return;
    }
    if (_isListening) {
      await _stopVoiceInput();
      return;
    }

    final bool available = _speechAvailable
        ? true
        : await _speechToText.initialize(
            onStatus: _handleSpeechStatus,
            onError: _handleSpeechError,
          );
    if (!mounted) {
      return;
    }
    if (!available) {
      setState(() => _speechAvailable = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Voice input is not available on this device right now.',
              'الإدخال الصوتي غير متاح على هذا الجهاز حالياً.',
            ),
          ),
        ),
      );
      return;
    }

    final String localeId = await _preferredSpeechLocaleId();
    _voiceDraftPrefix = _controller.text.trim();
    setState(() {
      _speechAvailable = true;
      _isListening = true;
    });

    await _speechToText.listen(
      onResult: _handleSpeechResult,
      localeId: localeId.isEmpty ? null : localeId,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<void> _stopVoiceInput() async {
    await _speechToText.stop();
    if (!mounted) {
      return;
    }
    setState(() => _isListening = false);
  }

  Future<String> _preferredSpeechLocaleId() async {
    final List<stt.LocaleName> locales = await _speechToText.locales();
    if (locales.isEmpty) {
      return '';
    }
    final String prefix = _isArabicLanguageCode(widget.selectedLanguage)
        ? 'ar'
        : 'en';
    for (final stt.LocaleName locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(prefix)) {
        return locale.localeId;
      }
    }
    return locales.first.localeId;
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }
    final String recognizedWords = result.recognizedWords.trim();
    final String composedText = recognizedWords.isEmpty
        ? _voiceDraftPrefix
        : _voiceDraftPrefix.isEmpty
        ? recognizedWords
        : '$_voiceDraftPrefix $recognizedWords';
    _controller.value = TextEditingValue(
      text: composedText,
      selection: TextSelection.collapsed(offset: composedText.length),
    );
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }
    final String normalized = status.trim().toLowerCase();
    if (normalized == 'notlistening' || normalized == 'done') {
      setState(() => _isListening = false);
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) {
      return;
    }
    setState(() => _isListening = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            context,
            'FreshLine could not start voice input right now.',
            'تعذر على فريش لاين تشغيل الإدخال الصوتي حالياً.',
          ),
        ),
      ),
    );
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> quickPrompts = _quickPromptsForRole(
      widget.role,
      widget.selectedLanguage,
    );
    final String title = widget.role == AppRole.customer
        ? _trForLanguage(widget.selectedLanguage, 'AI Stylist', 'المساعد الذكي')
        : widget.role == AppRole.salonOwner
        ? _trForLanguage(
            widget.selectedLanguage,
            'Salon AI Assistant',
            'مساعد الصالون الذكي',
          )
        : widget.role == AppRole.employee
        ? _trForLanguage(
            widget.selectedLanguage,
            'Employee AI Assistant',
            'مساعد الموظف الذكي',
          )
        : _trForLanguage(
            widget.selectedLanguage,
            'Admin AI Assistant',
            'مساعد الإدارة الذكي',
          );
    final String inputHint = widget.role == AppRole.customer
        ? _trForLanguage(
            widget.selectedLanguage,
            'Ask the AI stylist...',
            'اكتب سؤالك للمساعد...',
          )
        : widget.role == AppRole.salonOwner
        ? _trForLanguage(
            widget.selectedLanguage,
            'Ask about operations, services, or customers...',
            'اسأل عن التشغيل أو الخدمات أو العملاء...',
          )
        : widget.role == AppRole.employee
        ? _trForLanguage(
            widget.selectedLanguage,
            'Ask about your bookings or service day...',
            'اسأل عن حجوزاتك أو يوم العمل...',
          )
        : _trForLanguage(
            widget.selectedLanguage,
            'Ask about dashboards, admins, or notifications...',
            'اسأل عن لوحة التحكم أو المدراء أو الإشعارات...',
          );
    final bool useArabicPrompts = _isArabicLanguageCode(
      widget.selectedLanguage,
    );
    final double availablePromptWidth = MediaQuery.of(context).size.width - 56;

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: appCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tr(context, 'Model', 'النموذج'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        groqModel,
                        style: TextStyle(color: AppPalette.mutedForeground),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tr(context, 'Suggested prompts', 'أسئلة مقترحة'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: quickPrompts
                            .map((String prompt) {
                              final double chipWidth =
                                  useArabicPrompts || availablePromptWidth < 420
                                  ? availablePromptWidth
                                  : (availablePromptWidth - 8) / 2;
                              return SizedBox(
                                width: chipWidth,
                                child: FilledButton.tonal(
                                  onPressed: () => _sendMessage(prompt),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    alignment: useArabicPrompts
                                        ? Alignment.centerRight
                                        : Alignment.center,
                                  ),
                                  child: Directionality(
                                    textDirection: useArabicPrompts
                                        ? TextDirection.rtl
                                        : TextDirection.ltr,
                                    child: Text(
                                      prompt,
                                      textAlign: useArabicPrompts
                                          ? TextAlign.right
                                          : TextAlign.center,
                                      style: const TextStyle(
                                        height: 1.45,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ..._messages.map(_buildMessageBubble),
                if (_isSending)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: appCardDecoration(),
                        child: Text(
                          _tr(context, 'Typing...', 'جاري الكتابة...'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                decoration: appCardDecoration(),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: inputHint,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: _isListening
                            ? AppPalette.success
                            : AppPalette.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isListening
                              ? AppPalette.success
                              : AppPalette.border,
                        ),
                      ),
                      child: IconButton(
                        onPressed: _isSending ? null : _toggleVoiceInput,
                        tooltip: _tr(
                          context,
                          _isListening
                              ? 'Stop voice input'
                              : 'Start voice input',
                          _isListening
                              ? 'إيقاف الإدخال الصوتي'
                              : 'بدء الإدخال الصوتي',
                        ),
                        icon: Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _isListening
                              ? Colors.white
                              : AppPalette.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppPalette.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _isSending ? null : _sendMessage,
                        icon: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_AiChatMessage message) {
    final bool isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: appCardDecoration(
            color: isUser ? AppPalette.primary : AppPalette.card,
            border: Border.all(
              color: isUser ? AppPalette.primary : AppPalette.border,
            ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: isUser ? Colors.white : AppPalette.foreground,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

String _welcomeMessageForRole(AppRole role, String languageCode) {
  switch (role) {
    case AppRole.customer:
      return _trForLanguage(
        languageCode,
        'Hi, I am FreshLine AI. Ask me about haircut ideas, beard styles, products, or booking help.',
        'هلا، أنا مساعد فريش لاين الذكي. اسألني عن أفكار القصات، العناية باللحية، المنتجات، أو المساعدة في الحجز.',
      );
    case AppRole.salonOwner:
      return _trForLanguage(
        languageCode,
        'Hi, I am your FreshLine salon assistant. Ask me about pricing, staffing, packages, customer support, or monthly growth ideas.',
        'هلا، أنا مساعد الصالون في فريش لاين. اسألني عن التسعير والموظفين والباقات وخدمة العملاء وأفكار النمو الشهري.',
      );
    case AppRole.employee:
      return _trForLanguage(
        languageCode,
        'Hi, I am your FreshLine employee assistant. Ask me about bookings, customer service wording, daily planning, or grooming tips.',
        'هلا، أنا مساعد الموظف في فريش لاين. اسألني عن الحجوزات، وصياغة رسائل العملاء، وتنظيم يوم العمل، ونصائح العناية.',
      );
    case AppRole.admin:
      return _trForLanguage(
        languageCode,
        'Hi, I am the FreshLine admin assistant. Ask me about platform KPIs, pending salon requests, payment review, support workflows, or notification drafts.',
        'هلا، أنا مساعد الإدارة في فريش لاين. اسألني عن مؤشرات المنصة، وطلبات الصالونات المعلقة، ومراجعة الدفعات، وسير الدعم، وصياغة الإشعارات.',
      );
  }
}

List<String> _quickPromptsForRole(AppRole role, String languageCode) {
  switch (role) {
    case AppRole.customer:
      return _isArabicLanguageCode(languageCode)
          ? const <String>[
              'اقترح لي قصة شعر مناسبة حسب شكل الوجه',
              'رشّح لي أفضل منتج للشعر الجاف أو المتضرر',
              'ابحث عن صالون قريب وحدد لي أفضل موعد',
            ]
          : aiQuickPrompts;
    case AppRole.salonOwner:
      return _isArabicLanguageCode(languageCode)
          ? const <String>[
              'اعطني تسعيرة مناسبة للخدمة المنزلية',
              'اقترح باقة جديدة تجذب العملاء الجدد',
              'كيف أزيد حجوزات الصالون هذا الأسبوع؟',
            ]
          : const <String>[
              'How should I price home service?',
              'Give me a package idea for new clients',
              'How can I increase salon bookings this week?',
            ];
    case AppRole.employee:
      return _isArabicLanguageCode(languageCode)
          ? const <String>[
              'رتب لي أولويات حجوزات اليوم',
              'اكتب رسالة اعتذار مهذبة لعميل متأخر',
              'ما الخدمة الإضافية المناسبة بعد الحلاقة؟',
            ]
          : const <String>[
              'How should I prepare for today bookings?',
              'Give me a polite message for a delayed customer',
              'What add-on service fits a haircut client?',
            ];
    case AppRole.admin:
      return _isArabicLanguageCode(languageCode)
          ? const <String>[
              'لخّص أهم أرقام المنصة اليوم',
              'اكتب إشعاراً للصالونات التي تمت الموافقة عليها',
              'اكتب رسالة دعم للعملاء المتأخرين في الدفع',
            ]
          : const <String>[
              'Summarize the most important admin metrics',
              'Draft a notification for approved salons',
              'Write a support message for overdue customers',
            ];
  }
}

String _systemPromptForRole(AppRole role, String languageCode) {
  switch (role) {
    case AppRole.customer:
      return _trForLanguage(
        languageCode,
        'You are the FreshLine customer assistant. Help with salon booking, services, products, subscriptions, loyalty points, payments, and app settings.',
        'أنت مساعد العملاء في فريش لاين. ساعد في حجز الصالونات والخدمات والمنتجات والاشتراكات ونقاط الولاء والدفع وإعدادات التطبيق.',
      );
    case AppRole.salonOwner:
      return _trForLanguage(
        languageCode,
        'You are the FreshLine salon-owner assistant. Help with salon registration, services, packages, employees, bookings, revenue, and subscription billing.',
        'أنت مساعد مالك الصالون في فريش لاين. ساعد في تسجيل الصالون والخدمات والباقات والموظفين والحجوزات والإيرادات وفواتير الاشتراك.',
      );
    case AppRole.employee:
      return _trForLanguage(
        languageCode,
        'You are the FreshLine employee assistant. Help salon employees with daily bookings, service preparation, customer communication, and workday organization. Never discuss private salon profits or team-management permissions.',
        'أنت مساعد الموظف في فريش لاين. ساعد موظفي الصالون في الحجوزات اليومية، وتجهيز الخدمات، والتواصل مع العملاء، وتنظيم يوم العمل. لا تناقش أرباح الصالون الخاصة أو صلاحيات إدارة الفريق.',
      );
    case AppRole.admin:
      return _trForLanguage(
        languageCode,
        'You are the FreshLine admin assistant. Help with admin dashboards, salon approval workflows, notifications, user support, payments, and audit logs.',
        'أنت مساعد الإدارة في فريش لاين. ساعد في لوحات التحكم، واعتماد الصالونات، والإشعارات، ودعم المستخدمين، والدفعات، وسجلات التدقيق.',
      );
  }
}

String _helpSupportIntroForRole(BuildContext context, AppRole role) {
  switch (role) {
    case AppRole.customer:
      return _tr(
        context,
        'Open the FAQ, contact support, or reach us on social channels.',
        'افتح الأسئلة الشائعة أو تواصل مع الدعم أو استخدم قنواتنا الاجتماعية.',
      );
    case AppRole.salonOwner:
      return _tr(
        context,
        'Open salon-owner help topics, review support answers, or contact Freshline for subscription and workspace support.',
        'افتح مواضيع المساعدة الخاصة بمالك الصالون، وراجع الإجابات، أو تواصل مع فريش لاين بخصوص الاشتراك ومساحة العمل.',
      );
    case AppRole.employee:
      return _tr(
        context,
        'Open employee help topics, review support answers, or contact Freshline for schedule, account, or technical support.',
        'افتح مواضيع المساعدة الخاصة بالموظف، وراجع الإجابات، أو تواصل مع فريش لاين بشأن الجدول أو الحساب أو الدعم التقني.',
      );
    case AppRole.admin:
      return _tr(
        context,
        'Open admin FAQ topics, review platform guidance, or contact Freshline for escalations and operational support.',
        'افتح مواضيع الأسئلة الشائعة للإدارة، وراجع إرشادات المنصة، أو تواصل مع فريش لاين للتصعيدات والدعم التشغيلي.',
      );
  }
}

String _faqSubtitleForRole(BuildContext context, AppRole role) {
  switch (role) {
    case AppRole.customer:
      return _tr(
        context,
        'Tap questions and read answers separately',
        'اضغط على السؤال لعرض الإجابة',
      );
    case AppRole.salonOwner:
      return _tr(
        context,
        'Salon approvals, catalog, team, and subscription answers',
        'إجابات حول الاعتماد والكتالوج والفريق والاشتراك',
      );
    case AppRole.employee:
      return _tr(
        context,
        'Bookings, profile, permissions, and support answers',
        'إجابات حول الحجوزات والملف الشخصي والصلاحيات والدعم',
      );
    case AppRole.admin:
      return _tr(
        context,
        'Dashboard, requests, notifications, and admin-access answers',
        'إجابات حول اللوحة والطلبات والإشعارات وصلاحيات الإدارة',
      );
  }
}

String _contactUsHeaderForRole(BuildContext context, AppRole role) {
  switch (role) {
    case AppRole.customer:
      return _tr(context, 'Freshline Support', 'دعم فريش لاين');
    case AppRole.salonOwner:
      return _tr(context, 'Freshline Owner Support', 'دعم مالك الصالون');
    case AppRole.employee:
      return _tr(context, 'Freshline Employee Support', 'دعم الموظف');
    case AppRole.admin:
      return _tr(context, 'Freshline Admin Support', 'دعم الإدارة');
  }
}

String _contactUsDescriptionForRole(BuildContext context, AppRole role) {
  switch (role) {
    case AppRole.customer:
      return _tr(
        context,
        'Reach our team for booking help, payments, salon support, account updates, and technical issues.',
        'تواصل مع فريقنا للحصول على المساعدة في الحجز والدفع ودعم الصالونات وتحديثات الحساب والمشكلات التقنية.',
      );
    case AppRole.salonOwner:
      return _tr(
        context,
        'Reach our team for salon approvals, subscription questions, catalog issues, team access, and operational support.',
        'تواصل مع فريقنا بخصوص اعتماد الصالون وأسئلة الاشتراك ومشكلات الكتالوج وصلاحيات الفريق والدعم التشغيلي.',
      );
    case AppRole.employee:
      return _tr(
        context,
        'Reach our team for employee access issues, booking questions, account help, and technical support.',
        'تواصل مع فريقنا بخصوص مشكلات وصول الموظف وأسئلة الحجوزات ومساعدة الحساب والدعم التقني.',
      );
    case AppRole.admin:
      return _tr(
        context,
        'Reach our team for admin access, escalations, payment review support, notification issues, and platform incidents.',
        'تواصل مع فريقنا بخصوص صلاحيات الإدارة والتصعيدات ودعم مراجعة المدفوعات ومشكلات الإشعارات وحوادث المنصة.',
      );
  }
}

List<SupportTopic> _localizedSupportTopics(BuildContext context, AppRole role) {
  if (!_isArabicContext(context)) {
    return supportTopicsForRole(role);
  }

  switch (role) {
    case AppRole.customer:
      return const <SupportTopic>[
        SupportTopic(
          question: 'كيف أحجز صالون حلاقة؟',
          answer:
              'افتح الصالون، واختر الباقة أو الخدمة، ثم حدد نوع الزيارة، واختر الموظف والوقت المتاحين، وبعدها أكمل العنوان والدفع.',
        ),
        SupportTopic(
          question: 'كيف تعمل طلبات المنتجات؟',
          answer:
              'المنتجات لها سلة ومسار دفع منفصل عن حجوزات الصالون، لذلك يمكنك متابعة التسوق للمنتجات بشكل مستقل.',
        ),
        SupportTopic(
          question: 'متى أستلم الإشعارات؟',
          answer:
              'تصلك الإشعارات عند نشر الإعلانات من الإدارة، وعند تغير حالة طلب المنتج، وعند تأكيد الموعد أو اقتراب وقته.',
        ),
        SupportTopic(
          question: 'كيف أنشئ حساب عميل؟',
          answer:
              'ابدأ بإدخال البريد الإلكتروني واسم المستخدم وكلمة المرور، ثم انتقل إلى الشاشة الثانية لإضافة رقم الهاتف والمدينة وصورة الملف الشخصي قبل إنهاء الحساب.',
        ),
        SupportTopic(
          question: 'هل أستطيع تغيير اسم المستخدم وصورة الملف لاحقاً؟',
          answer:
              'نعم. افتح الإعدادات ثم تفاصيل الحساب وقم بتحديث اسم المستخدم أو الصورة أو رقم الهاتف أو المدينة أو العنوان في أي وقت.',
        ),
        SupportTopic(
          question: 'ماذا يحدث إذا لم أرفع صورة للملف الشخصي؟',
          answer:
              'سيبقي فريش لاين الصورة الافتراضية لحسابك إلى أن تقرر رفع صورة جديدة.',
        ),
        SupportTopic(
          question: 'كيف أضيف بطاقة دفع؟',
          answer:
              'يمكنك إضافة بطاقة من الإعدادات ضمن البطاقات المحفوظة، أو أثناء الدفع عند حجز خدمة أو الاشتراك في خطة.',
        ),
        SupportTopic(
          question: 'هل يمكنني حفظ أكثر من بطاقة؟',
          answer:
              'نعم. يمكنك حفظ عدة بطاقات واستخدام الأنسب منها عند دفع الحجوزات أو الاشتراكات أو الطلبات المستقبلية.',
        ),
        SupportTopic(
          question: 'كيف أشترك في خطة عضوية؟',
          answer:
              'افتح الاشتراك من الإعدادات أو الصفحة الرئيسية، ثم اختر الخطة وأكد الدفع بإحدى بطاقاتك المحفوظة، وسيتم تفعيل الخطة مباشرة بعد الدفع.',
        ),
        SupportTopic(
          question: 'ما فائدة نقاط الولاء؟',
          answer:
              'تكسب نقاط ولاء من الطلبات والحجوزات المؤهلة، ويمكن للخطط النشطة زيادة نسبة المكافأة، كما يمكن استبدال النقاط المتاحة بخصم أثناء دفع المنتجات.',
        ),
        SupportTopic(
          question: 'كيف تعمل الخدمة المنزلية؟',
          answer:
              'إذا كان الصالون يدعم الخدمة المنزلية، اختر هذا النوع أثناء الحجز ثم أكد العنوان ليصل الموظف إلى موقعك.',
        ),
        SupportTopic(
          question: 'هل أستطيع متابعة التسوق بعد إضافة منتج إلى السلة؟',
          answer:
              'نعم. يعرض فريش لاين تأكيداً مختصراً أعلى الشاشة، ويمكنك فتح السلة في أي وقت من شريط التنقل عندما تكون جاهزاً.',
        ),
        SupportTopic(
          question: 'ما العملة المستخدمة في فريش لاين؟',
          answer:
              'جميع الأسعار والمدفوعات الظاهرة في تجربة العميل تكون بالدينار البحريني (BHD).',
        ),
        SupportTopic(
          question: 'كيف ألغي أو أعيد جدولة الحجز؟',
          answer:
              'افتح طلباتك أو تفاصيل الحجز واتبع الإجراءات المتاحة. إذا لم يعد بالإمكان تعديل الحجز، تواصل مع الدعم للمساعدة.',
        ),
        SupportTopic(
          question: 'لماذا لا تتم عملية دفع البطاقة؟',
          answer:
              'يرجى التأكد من رقم البطاقة وتاريخ الانتهاء ورمز CVV ثم المحاولة مرة أخرى. وإذا استمرت المشكلة فاستخدم بطاقة محفوظة أخرى أو تواصل مع البنك.',
        ),
        SupportTopic(
          question: 'كيف تظهر تحديثات توصيل المنتجات؟',
          answer:
              'يرسل فريش لاين إشعارات عند استلام طلب المنتج وكلما تغيرت حالة الدفع أو الطلب.',
        ),
        SupportTopic(
          question: 'كيف أتواصل مع الدعم بسرعة؟',
          answer:
              'يمكنك فتح صفحة تواصل معنا من الإعدادات والوصول إلى فريش لاين عبر الهاتف أو البريد أو واتساب أو القنوات الاجتماعية المدرجة.',
        ),
      ];
    case AppRole.salonOwner:
      return const <SupportTopic>[
        SupportTopic(
          question: 'كيف أرسل أو أعدل طلب الصالون؟',
          answer:
              'افتح مركز الطلبات، وأدخل تفاصيل الصالون، وارفع الملفات المطلوبة، ثم أرسل الطلب. ويمكنك تحديثه ما دام لم تتم الموافقة عليه.',
        ),
        SupportTopic(
          question: 'كيف أدير الباقات والخدمات والمنتجات؟',
          answer:
              'افتح الكتالوج من مساحة عمل المالك لإضافة أو تعديل أو إيقاف الباقات والخدمات والمنتجات التي تظهر في تجربة الصالون.',
        ),
        SupportTopic(
          question: 'كيف تعمل إشعارات الصالون؟',
          answer:
              'يرسل فريش لاين إشعارات للحجوزات الجديدة وتحديثات الإدارة وإعلانات المنصة مباشرة إلى صندوق إشعارات مساحة عمل الصالون.',
        ),
        SupportTopic(
          question: 'كيف أضيف الموظفين وأمنحهم صلاحية الدخول؟',
          answer:
              'افتح الفريق، وأضف ملف الموظف، ثم حدد ما إذا كان يستطيع تسجيل الدخول وما إذا كان يدعم الزيارة داخل الصالون أو الخدمة المنزلية أو كليهما.',
        ),
        SupportTopic(
          question: 'كيف تعمل مدفوعات اشتراك الصالون؟',
          answer:
              'تعرض شاشة اشتراك الصالون الدورة النشطة والمبلغ وحالة التجديد وتاريخ الانتهاء حتى تتمكن من إبقاء مساحة العمل فعالة.',
        ),
        SupportTopic(
          question: 'أين أراجع الإيرادات والأرباح؟',
          answer:
              'افتح الإيرادات والأرباح من إعدادات المالك لمراجعة الإيرادات وتكلفة الرواتب وتكلفة الاشتراك وصافي الربح التشغيلي الحالي.',
        ),
        SupportTopic(
          question: 'كيف أتواصل مع الدعم بخصوص مشاكل الصالون؟',
          answer:
              'افتح المساعدة والدعم من إعدادات المالك واستخدم قنوات دعم فريش لاين لمشاكل الاشتراك أو أسئلة الاعتماد أو المشكلات التشغيلية.',
        ),
      ];
    case AppRole.employee:
      return const <SupportTopic>[
        SupportTopic(
          question: 'كيف أرى الحجوزات المعينة لي؟',
          answer:
              'افتح شاشة حجوزات الموظف لمراجعة المواعيد المعينة لك ومهام المنتجات والأوقات القادمة خلال يوم عملك.',
        ),
        SupportTopic(
          question: 'هل أستطيع تعديل تفاصيل حسابي؟',
          answer:
              'نعم. افتح تفاصيل الحساب من إعدادات الموظف لتحديث صورة الملف الشخصي ورقم الهاتف والمدينة والعنوان وكلمة المرور.',
        ),
        SupportTopic(
          question: 'هل سأستلم إشعارات الصالون؟',
          answer:
              'نعم. يمكن للموظفين استلام إشعارات مباشرة مرتبطة بملفهم الشخصي بالإضافة إلى إشعارات الصالون العامة المرسلة إلى الصالون التابعين له.',
        ),
        SupportTopic(
          question: 'هل أستطيع إدارة الموظفين الآخرين أو الأسعار؟',
          answer:
              'لا. صلاحيات الموظف تقتصر على الحجوزات المعينة وإدارة الملف الشخصي وأدوات يوم العمل. إدارة الفريق والأسعار تبقى مع مالك الصالون.',
        ),
        SupportTopic(
          question: 'كيف أحصل على المساعدة بسرعة؟',
          answer:
              'افتح المساعدة والدعم من إعدادات الموظف لاستخدام نفس قنوات دعم فريش لاين لأسئلة الجدول أو مشاكل الوصول أو الدعم التقني.',
        ),
      ];
    case AppRole.admin:
      return const <SupportTopic>[
        SupportTopic(
          question: 'ماذا يمكنني أن أفعل من لوحة الإدارة؟',
          answer:
              'تعرض اللوحة للإداريين نظرة سريعة على الإيرادات والمستخدمين والصالونات والطلبات والكوبونات وآخر نشاط إداري عبر المنصة.',
        ),
        SupportTopic(
          question: 'كيف تتم مراجعة طلبات الصالونات؟',
          answer:
              'افتح تبويب الطلبات، وافحص تفاصيل الطلب، ثم وافق أو ارفض أو اطلب معلومات إضافية. وسيتلقى المالك النتيجة كإشعار.',
        ),
        SupportTopic(
          question: 'كيف تعمل إشعارات الإدارة؟',
          answer:
              'استخدم تبويب الإشعارات لاختيار الجمهور المستهدف، ويمكنك تحديد مستخدم أو صالون معين، ثم إرسال إشعار داخل التطبيق مباشرة إلى صندوق الوارد الخاص بهم.',
        ),
        SupportTopic(
          question: 'من يمكنه إنشاء أو إدارة المدراء الآخرين؟',
          answer:
              'فقط مالك الإدارة يستطيع إنشاء حسابات إدارية جديدة أو تعديل المدراء الحاليين أو تعطيل حسابات الإدارة في المنصة.',
        ),
        SupportTopic(
          question: 'كيف أتعامل مع مشاكل الدعم أو المدفوعات؟',
          answer:
              'استخدم أدوات الإدارة لمراجعة تفاصيل المستخدم وحالة الطلبات والإشعارات وسياق الدفع، ثم تواصل مع دعم فريش لاين عندما تحتاج الحالة إلى تصعيد.',
        ),
        SupportTopic(
          question: 'هل يستطيع المدير تحديث ملفه الشخصي؟',
          answer:
              'نعم. يمكن تحديث تفاصيل حساب الإدارة من إعدادات الإدارة، بما في ذلك صورة الملف الشخصي ورقم الهاتف والمدينة والعنوان وكلمة المرور.',
        ),
      ];
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.notifications,
    this.isLoading = false,
  });

  final List<AppNotificationItem> notifications;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final String languageCode = _isArabicContext(context) ? 'AR' : 'EN';
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(_tr(context, 'Notifications', 'الإشعارات'))),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: _EmptyStateCard(
                  icon: Icons.notifications_none_rounded,
                  title: _tr(
                    context,
                    'No notifications yet',
                    'لا توجد إشعارات حتى الآن',
                  ),
                  message: _tr(
                    context,
                    'New account welcomes, product orders, appointments, and admin updates will appear here.',
                    'ستظهر هنا رسائل الترحيب بالحسابات الجديدة وطلبات المنتجات والمواعيد وتحديثات الإدارة.',
                  ),
                  actionLabel: _tr(context, 'Go Back', 'رجوع'),
                  onAction: () => Navigator.of(context).pop(),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: notifications.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 14),
                itemBuilder: (BuildContext context, int index) {
                  final AppNotificationItem item = notifications[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: appCardDecoration(
                      color: item.unread
                          ? AppPalette.primary.withValues(alpha: 0.06)
                          : AppPalette.card,
                      border: Border.all(
                        color: item.unread
                            ? AppPalette.primary.withValues(alpha: 0.22)
                            : AppPalette.border,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppPalette.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_notificationIcon(item.icon)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.localizedTitleForLanguage(languageCode),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.localizedMessageForLanguage(languageCode),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AppPalette.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.localizedTimeLabelForLanguage(
                                  languageCode,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AiChatMessage {
  const _AiChatMessage({required this.role, required this.text});

  final String role;
  final String text;
}

class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({
    super.key,
    required this.products,
    required this.cartIds,
    required this.onOpenProduct,
    required this.onAddToCart,
  });

  final List<Product> products;
  final Set<String> cartIds;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<String> onAddToCart;

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> filters = <String>{
      'All',
      'Top Rated',
      ...widget.products.map((Product product) => product.category),
    }.toList(growable: false);
    final String query = _searchController.text.trim().toLowerCase();
    final List<Product> filteredProducts = widget.products
        .where((Product product) {
          final bool matchesQuery =
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.localizedName(context).toLowerCase().contains(query) ||
              product.category.toLowerCase().contains(query) ||
              product.localizedCategory(context).toLowerCase().contains(query);
          final bool matchesFilter =
              _filter == 'All' ||
              (_filter == 'Top Rated'
                  ? product.rating >= 4.7
                  : product.category == _filter);
          return matchesQuery && matchesFilter;
        })
        .toList(growable: false);

    return AppViewport(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _TopBar(
                title: _localizedDisplayText(context, 'All Products'),
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: _localizedDisplayText(
                            context,
                            'Search products',
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue: _filter,
                        decoration: InputDecoration(
                          labelText: _localizedDisplayText(context, 'Filter'),
                        ),
                        items: filters
                            .map(
                              (String item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(
                                  _localizedDisplayText(context, item),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() => _filter = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredProducts.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        child: _EmptyStateCard(
                          icon: Icons.inventory_2_outlined,
                          title: _localizedDisplayText(
                            context,
                            'No products found',
                          ),
                          message: _localizedDisplayText(
                            context,
                            'Try another search term or change the filter to see more products.',
                          ),
                          actionLabel: _localizedDisplayText(
                            context,
                            'Clear Search',
                          ),
                          onAction: () {
                            setState(() {
                              _searchController.clear();
                              _filter = 'All';
                            });
                          },
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.67,
                            ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Product product = filteredProducts[index];
                          return _ProductCard(
                            product: product,
                            onTap: () => widget.onOpenProduct(product),
                            onCartTap: () => widget.onAddToCart(product.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  final Product product;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final bool outOfStock = product.stock <= 0 || !product.isActive;
    return AppViewport(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              Stack(
                children: <Widget>[
                  _AppImage(
                    imagePath: product.imagePath,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 12,
                    left: 20,
                    child: _RoundIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                      translucent: true,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.localizedName(context),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.localizedCategory(context),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      product.localizedDescription(context),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: appCardDecoration(),
                      child: Column(
                        children: <Widget>[
                          _SummaryRow(
                            label: _localizedDisplayText(context, 'Price'),
                            value: formatBhd(product.price),
                          ),
                          _SummaryRow(
                            label: _localizedDisplayText(context, 'Rating'),
                            value:
                                '${product.rating.toStringAsFixed(1)} (${product.reviewsCount})',
                          ),
                          _SummaryRow(
                            label: _localizedDisplayText(context, 'Stock'),
                            value: outOfStock
                                ? _localizedDisplayText(context, 'Out of stock')
                                : _tr(
                                    context,
                                    '${product.stock} available',
                                    '${product.stock} متوفر',
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: outOfStock ? null : onAddToCart,
                        child: Text(
                          outOfStock
                              ? _localizedDisplayText(context, 'Out Of Stock')
                              : _localizedDisplayText(context, 'Add To Cart'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({
    super.key,
    required this.products,
    required this.cartQuantities,
    required this.onOpenProduct,
    required this.onContinueShopping,
    required this.onCheckout,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
    required this.onRemoveFromCart,
  });

  final List<Product> products;
  final Map<String, int> cartQuantities;
  final ValueChanged<Product> onOpenProduct;
  final VoidCallback onContinueShopping;
  final Future<void> Function() onCheckout;
  final ValueChanged<String> onIncreaseQuantity;
  final ValueChanged<String> onDecreaseQuantity;
  final Future<void> Function(String productId) onRemoveFromCart;

  @override
  Widget build(BuildContext context) {
    final List<Product> cartProducts = products
        .where((Product product) => cartQuantities.containsKey(product.id))
        .toList(growable: false);
    final num subtotal = cartProducts.fold<num>(
      0,
      (num total, Product product) =>
          total + product.price * (cartQuantities[product.id] ?? 1),
    );
    final int totalItems = cartQuantities.values.fold<int>(
      0,
      (int sum, int qty) => sum + qty,
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Text(
            _localizedDisplayText(context, 'Cart'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _localizedDisplayText(
              context,
              'Products only. Cart items must come from one salon at a time, and salon bookings continue in their own checkout flow.',
            ),
            style: TextStyle(color: AppPalette.mutedForeground),
          ),
          const SizedBox(height: 20),
          if (cartProducts.isEmpty)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _localizedDisplayText(context, 'Your cart is empty'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _localizedDisplayText(
                      context,
                      'Add products from the marketplace, then come back here to review them.',
                    ),
                    style: TextStyle(
                      color: AppPalette.mutedForeground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onContinueShopping,
                      child: Text(
                        _localizedDisplayText(context, 'Continue Shopping'),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...<Widget>[
            ...cartProducts.map((Product product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  onTap: () => onOpenProduct(product),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: appCardDecoration(),
                    child: Row(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _AppImage(
                            imagePath: product.imagePath,
                            width: 82,
                            height: 82,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                product.localizedName(context),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.localizedCategory(context),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                formatBhd(product.price),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: <Widget>[
                                  _CartQuantityButton(
                                    icon: Icons.remove_rounded,
                                    onTap: cartQuantities[product.id] == 1
                                        ? null
                                        : () => onDecreaseQuantity(product.id),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      '${cartQuantities[product.id] ?? 1}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _CartQuantityButton(
                                    icon: Icons.add_rounded,
                                    onTap:
                                        (cartQuantities[product.id] ?? 0) >=
                                            product.stock
                                        ? null
                                        : () => onIncreaseQuantity(product.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            onRemoveFromCart(product.id);
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _SummaryRow(label: 'Items', value: '$totalItems'),
                  _SummaryRow(label: 'Subtotal', value: formatBhd(subtotal)),
                  _SummaryRow(label: 'Delivery', value: 'Set in checkout'),
                  const SizedBox(height: 4),
                  Text(
                    'Discounts and loyalty points can be reviewed during checkout.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const Divider(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        onCheckout();
                      },
                      child: const Text('Proceed To Checkout'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onContinueShopping,
                      child: const Text('Continue Shopping'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartQuantityButton extends StatelessWidget {
  const _CartQuantityButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppPalette.border.withValues(alpha: 0.45)
              : AppPalette.secondary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppPalette.foreground),
      ),
    );
  }
}

class _ProductCheckoutScreen extends StatefulWidget {
  const _ProductCheckoutScreen({
    required this.user,
    required this.products,
    required this.cartQuantities,
    required this.availableLoyaltyPoints,
    required this.customerOrderCount,
    required this.currentPlan,
    this.initialLocation,
    this.initialAddressDetails = '',
    required this.savedAddresses,
    required this.availableCoupons,
    required this.savedCards,
    required this.onAddCard,
  });

  final AppUser user;
  final List<Product> products;
  final Map<String, int> cartQuantities;
  final int availableLoyaltyPoints;
  final int customerOrderCount;
  final SubscriptionPlan? currentPlan;
  final DeliveryLocationSelection? initialLocation;
  final String initialAddressDetails;
  final List<SavedCustomerAddress> savedAddresses;
  final List<PromoCouponRecord> availableCoupons;
  final List<PaymentCardInfo> savedCards;
  final Future<PaymentCardInfo?> Function(String title) onAddCard;

  @override
  State<_ProductCheckoutScreen> createState() => _ProductCheckoutScreenState();
}

class _ProductCheckoutScreenState extends State<_ProductCheckoutScreen> {
  static const int _loyaltyPointsPerBhd = 100;
  static const int _taxPercent = 10;
  static const PromoCouponRecord _fallbackWelcomeCoupon = PromoCouponRecord(
    code: 'FRESH20',
    description: '20% welcome discount for the first order only.',
    discountPercent: 20,
    isActive: true,
  );

  final TextEditingController _addressDetailsController =
      TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  DeliveryLocationSelection? _selectedLocation;
  String? _selectedSavedAddressId;
  String? _selectedCardId;
  PromoCouponRecord? _appliedCoupon;
  bool _useLoyaltyPoints = false;

  @override
  void initState() {
    super.initState();
    _selectedCardId = widget.savedCards.firstOrNull?.id;
    _selectedLocation = widget.initialLocation;
    _addressDetailsController.text = widget.initialAddressDetails.isNotEmpty
        ? widget.initialAddressDetails
        : widget.user.address;
    _selectedSavedAddressId = _matchingSavedAddress?.id;
  }

  @override
  void dispose() {
    _addressDetailsController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  num get _cartSubtotal => widget.products.fold<num>(
    0,
    (num sum, Product product) =>
        sum + product.price * (widget.cartQuantities[product.id] ?? 1),
  );

  num _roundCurrency(num value) {
    return (value * 100).round() / 100;
  }

  String _formatCouponDate(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  PromoCouponRecord get _welcomeCoupon => _fallbackWelcomeCoupon;

  String? _couponValidationMessage(PromoCouponRecord coupon, {num? subtotal}) {
    final num orderSubtotal = subtotal ?? _cartSubtotal;
    final DateTime now = DateTime.now();
    if (!coupon.isActive) {
      return _tr(context, 'This coupon is inactive.', 'هذا الكوبون غير مفعل.');
    }
    if (coupon.isWelcomeFirstOrderCoupon && widget.customerOrderCount > 0) {
      return _tr(
        context,
        'Fresh20% welcome coupon has ended because this account already has orders.',
        'انتهت أهلية كوبون FRESH20 الترحيبي لأن هذا الحساب لديه طلبات سابقة.',
      );
    }
    if (!coupon.matchesPlan(widget.currentPlan)) {
      final String planName =
          coupon.targetPlan?.localizedName(context) ??
          _tr(context, 'selected', 'المحددة');
      return _tr(
        context,
        'This coupon is only for $planName plan subscribers.',
        'هذا الكوبون مخصص فقط لمشتركي باقة $planName.',
      );
    }
    if (!coupon.isAvailableAt(now)) {
      if (coupon.startsAt != null && now.isBefore(coupon.startsAt!)) {
        return _tr(
          context,
          'This coupon starts on ${_formatCouponDate(coupon.startsAt!)}.',
          'يبدأ هذا الكوبون في ${_formatCouponDate(coupon.startsAt!)}.',
        );
      }
      if (coupon.endsAt != null && now.isAfter(coupon.endsAt!)) {
        return _tr(
          context,
          'This coupon expired on ${_formatCouponDate(coupon.endsAt!)}.',
          'انتهت صلاحية هذا الكوبون في ${_formatCouponDate(coupon.endsAt!)}.',
        );
      }
    }
    if (!coupon.meetsMinimumOrder(orderSubtotal)) {
      return _tr(
        context,
        'This coupon requires a minimum order of ${formatBhd(coupon.minOrderAmountBhd!)}.',
        'يتطلب هذا الكوبون حداً أدنى للطلب بقيمة ${formatBhd(coupon.minOrderAmountBhd!)}.',
      );
    }
    return null;
  }

  _CheckoutPricing _buildPricing(num subtotal) {
    final PromoCouponRecord? applicableCoupon =
        _appliedCoupon != null &&
            _couponValidationMessage(_appliedCoupon!, subtotal: subtotal) ==
                null
        ? _appliedCoupon
        : null;
    num couponDiscount = 0;
    if (applicableCoupon != null) {
      couponDiscount = _roundCurrency(
        (subtotal * applicableCoupon.discountPercent) / 100,
      );
      final double? maxDiscountBhd = applicableCoupon.maxDiscountBhd;
      if (maxDiscountBhd != null && maxDiscountBhd > 0) {
        couponDiscount = math.min<num>(couponDiscount, maxDiscountBhd);
      }
      couponDiscount = _roundCurrency(math.min<num>(couponDiscount, subtotal));
    }
    final num afterCoupon = _roundCurrency(subtotal - couponDiscount);
    final int maxRedeemablePoints = math.min<int>(
      widget.availableLoyaltyPoints,
      (afterCoupon * _loyaltyPointsPerBhd).floor(),
    );
    final int loyaltyPointsRedeemed = _useLoyaltyPoints
        ? maxRedeemablePoints
        : 0;
    final num loyaltyDiscount = _roundCurrency(
      loyaltyPointsRedeemed / _loyaltyPointsPerBhd,
    );
    final num subtotalAfterDiscounts = _roundCurrency(
      afterCoupon - loyaltyDiscount,
    );
    final num taxAmount = _roundCurrency(
      (subtotalAfterDiscounts * _taxPercent) / 100,
    );
    final num totalDue = _roundCurrency(subtotalAfterDiscounts + taxAmount);

    return _CheckoutPricing(
      subtotal: subtotal,
      couponCode: applicableCoupon?.normalizedCode,
      couponDiscount: couponDiscount,
      loyaltyPointsRedeemed: loyaltyPointsRedeemed,
      loyaltyDiscount: loyaltyDiscount,
      taxAmount: taxAmount < 0 ? 0 : taxAmount,
      totalDue: totalDue < 0 ? 0 : totalDue,
    );
  }

  void _applyCoupon() {
    final String normalizedCode = _couponController.text.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a coupon code.')));
      return;
    }
    final PromoCouponRecord? matchedCoupon = widget.availableCoupons
        .where(
          (PromoCouponRecord coupon) =>
              coupon.isActive && coupon.normalizedCode == normalizedCode,
        )
        .firstOrNull;
    final PromoCouponRecord? couponToApply =
        matchedCoupon ??
        (normalizedCode == _welcomeCoupon.normalizedCode
            ? _welcomeCoupon
            : null);
    if (couponToApply == null) {
      if (normalizedCode == _welcomeCoupon.normalizedCode &&
          widget.customerOrderCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fresh20% welcome coupon has ended because this account already has orders.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid coupon code.')));
      return;
    }
    final String? validationMessage = _couponValidationMessage(couponToApply);
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() {
      _appliedCoupon = couponToApply;
      _couponController.text = couponToApply.normalizedCode;
    });
    _showTopToast(
      context,
      title: 'Coupon applied',
      message: 'Coupon applied successfully.',
      icon: Icons.local_offer_outlined,
    );
  }

  String get _couponHintText {
    if (_appliedCoupon != null) {
      return 'Coupon applied successfully to this checkout.';
    }
    final bool hasReadyAdminCoupons = widget.availableCoupons.any(
      (PromoCouponRecord coupon) => _couponValidationMessage(coupon) == null,
    );
    return hasReadyAdminCoupons
        ? 'Add one of your available coupon codes at checkout.'
        : 'Add a coupon only if you have one.';
  }

  void _removeCoupon() {
    if (_appliedCoupon == null) {
      return;
    }

    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
    });
  }

  Future<void> _pickLocation() async {
    final DeliveryLocationSelection? result = await Navigator.of(context)
        .push<DeliveryLocationSelection>(
          MaterialPageRoute<DeliveryLocationSelection>(
            builder: (BuildContext context) => _DeliveryLocationPickerScreen(
              initialLocation: _selectedLocation,
            ),
          ),
        );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _selectedLocation = result;
      _selectedSavedAddressId = _matchingSavedAddress?.id;
    });
  }

  SavedCustomerAddress? get _matchingSavedAddress {
    return widget.savedAddresses
        .where(
          (SavedCustomerAddress item) =>
              item.addressLine.trim().toLowerCase() ==
                  _addressDetailsController.text.trim().toLowerCase() &&
              _sameDeliveryLocation(item.location, _selectedLocation),
        )
        .firstOrNull;
  }

  void _applySavedAddress(SavedCustomerAddress address) {
    setState(() {
      _selectedSavedAddressId = address.id;
      _selectedLocation = address.location;
      _addressDetailsController.text = address.addressLine;
    });
  }

  Future<void> _addCard() async {
    final PaymentCardInfo? card = await widget.onAddCard(
      _tr(context, 'Add New Card', 'أضف بطاقة جديدة'),
    );
    if (!mounted || card == null) {
      return;
    }
    setState(() => _selectedCardId = card.id);
  }

  void _confirm() {
    final String? couponValidation = _appliedCoupon == null
        ? null
        : _couponValidationMessage(_appliedCoupon!);
    final PaymentCardInfo? selectedCard = widget.savedCards
        .where((PaymentCardInfo card) => card.id == _selectedCardId)
        .firstOrNull;
    final _CheckoutPricing pricing = _buildPricing(_cartSubtotal);

    if (couponValidation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(couponValidation)));
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select your delivery location on the map.'),
        ),
      );
      return;
    }
    if (_addressDetailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Enter your delivery address details.',
              'أدخل تفاصيل عنوان التوصيل.',
            ),
          ),
        ),
      );
      return;
    }
    if (selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Choose a saved card or add a new one.',
              'اختر بطاقة محفوظة أو أضف بطاقة جديدة.',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _ProductCheckoutResult(
        card: selectedCard,
        location: _selectedLocation!,
        addressDetails: _addressDetailsController.text.trim(),
        subtotal: pricing.subtotal,
        couponCode: pricing.couponCode,
        couponDiscount: pricing.couponDiscount,
        loyaltyPointsRedeemed: pricing.loyaltyPointsRedeemed,
        loyaltyDiscount: pricing.loyaltyDiscount,
        taxAmount: pricing.taxAmount,
        totalPaid: pricing.totalDue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_CartCheckoutLine> lines = widget.products
        .map(
          (Product product) => _CartCheckoutLine(
            product: product,
            quantity: widget.cartQuantities[product.id] ?? 1,
          ),
        )
        .toList(growable: false);
    final int totalItems = lines.fold<int>(
      0,
      (int sum, _CartCheckoutLine item) => sum + item.quantity,
    );
    final num subtotal = lines.fold<num>(
      0,
      (num sum, _CartCheckoutLine item) => sum + item.lineTotal,
    );
    final _CheckoutPricing pricing = _buildPricing(subtotal);

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Product Checkout')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Delivery Address',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (widget.savedAddresses.isNotEmpty) ...<Widget>[
                    const Text(
                      'Saved Addresses',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...widget.savedAddresses.map((
                      SavedCustomerAddress address,
                    ) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SelectableCard(
                          selected: _selectedSavedAddressId == address.id,
                          icon: address.isDefault
                              ? Icons.home_rounded
                              : Icons.location_on_outlined,
                          title: address.label,
                          subtitle: address.subtitle,
                          onTap: () => _applySavedAddress(address),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: Text(
                      _selectedLocation == null
                          ? _tr(
                              context,
                              'No map location selected yet.',
                              'لم يتم تحديد موقع من الخريطة بعد.',
                            )
                          : _selectedLocation!.fullLabel,
                      style: TextStyle(
                        height: 1.4,
                        color: _selectedLocation == null
                            ? AppPalette.mutedForeground
                            : AppPalette.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        _selectedLocation == null
                            ? _tr(context, 'Choose From Map', 'اختر من الخريطة')
                            : _tr(
                                context,
                                'Change Map Location',
                                'تغيير موقع الخريطة',
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AuthTextField(
                    controller: _addressDetailsController,
                    label: _tr(context, 'Address Details', 'تفاصيل العنوان'),
                    keyboardType: TextInputType.text,
                    maxLines: 3,
                    onChanged: (_) {
                      setState(
                        () =>
                            _selectedSavedAddressId = _matchingSavedAddress?.id,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Discounts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _AuthTextField(
                          controller: _couponController,
                          label: 'Coupon Code',
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(12),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 112,
                        child: _appliedCoupon == null
                            ? FilledButton(
                                onPressed: _applyCoupon,
                                child: const Text('Apply'),
                              )
                            : OutlinedButton(
                                onPressed: _removeCoupon,
                                child: const Text('Remove'),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _couponHintText,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: appCardDecoration(
                      color: AppPalette.background,
                      radius: 20,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Use Loyalty Balance',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.availableLoyaltyPoints == 0
                                    ? 'No loyalty points available yet.'
                                    : _useLoyaltyPoints
                                    ? 'Using ${pricing.loyaltyPointsRedeemed} pts for ${formatBhd(pricing.loyaltyDiscount)} off.'
                                    : 'Available: ${widget.availableLoyaltyPoints} pts. Every 100 pts = BHD 1 discount.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppPalette.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch.adaptive(
                          value: _useLoyaltyPoints,
                          onChanged: widget.availableLoyaltyPoints == 0
                              ? null
                              : (bool value) {
                                  setState(() => _useLoyaltyPoints = value);
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Payment Card',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (widget.savedCards.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: appCardDecoration(
                        color: AppPalette.background,
                      ),
                      child: Text(
                        _tr(
                          context,
                          'No saved cards yet. Add a new card to continue.',
                          'لا توجد بطاقات محفوظة بعد. أضف بطاقة جديدة للمتابعة.',
                        ),
                        style: TextStyle(color: AppPalette.mutedForeground),
                      ),
                    )
                  else
                    ...widget.savedCards.map((PaymentCardInfo card) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SelectableCard(
                          selected: card.id == _selectedCardId,
                          icon: Icons.credit_card_rounded,
                          title: card.displayLabel,
                          subtitle: '${card.holderName} · ${card.expiryLabel}',
                          onTap: () =>
                              setState(() => _selectedCardId = card.id),
                        ),
                      );
                    }),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _addCard,
                      child: Text(
                        _tr(context, 'Add New Card', 'أضف بطاقة جديدة'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tr(context, 'Order Summary', 'ملخص الطلب'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  ...lines.map(
                    (_CartCheckoutLine item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SummaryRow(
                        label:
                            '${item.product.localizedName(context)} x${item.quantity}',
                        value: formatBhd(item.lineTotal),
                      ),
                    ),
                  ),
                  const Divider(height: 22),
                  _SummaryRow(label: 'Items', value: '$totalItems'),
                  _SummaryRow(label: 'Subtotal', value: formatBhd(subtotal)),
                  if (pricing.couponDiscount > 0)
                    _SummaryRow(
                      label: 'Coupon (${pricing.couponCode})',
                      value: '- ${formatBhd(pricing.couponDiscount)}',
                    ),
                  if (pricing.loyaltyDiscount > 0)
                    _SummaryRow(
                      label: 'Loyalty (${pricing.loyaltyPointsRedeemed} pts)',
                      value: '- ${formatBhd(pricing.loyaltyDiscount)}',
                    ),
                  _SummaryRow(
                    label: 'Tax (10%)',
                    value: formatBhd(pricing.taxAmount),
                  ),
                  _SummaryRow(
                    label: 'Total Due',
                    value: formatBhd(pricing.totalDue),
                    prominent: true,
                  ),
                  if (pricing.totalDiscount > 0) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'You saved ${formatBhd(pricing.totalDiscount)} on this order.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppPalette.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.lock_rounded),
                label: Text('Pay ${formatBhd(pricing.totalDue)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryLocationPickerScreen extends StatefulWidget {
  const _DeliveryLocationPickerScreen({this.initialLocation});

  final DeliveryLocationSelection? initialLocation;

  @override
  State<_DeliveryLocationPickerScreen> createState() =>
      _DeliveryLocationPickerScreenState();
}

class _DeliveryLocationPickerScreenState
    extends State<_DeliveryLocationPickerScreen> {
  static const LatLng _bahrainCenter = LatLng(26.2235, 50.5876);
  final MapController _mapController = MapController();
  LatLng? _selectedPoint;
  bool _isResolvingCurrentLocation = false;
  String? _locationStatusMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedPoint = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnCurrentLocation();
      });
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_isResolvingCurrentLocation) {
      return;
    }

    setState(() {
      _isResolvingCurrentLocation = true;
      _locationStatusMessage = null;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _locationStatusMessage =
              'Location service is off. You can enable it or pick manually from the map.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        setState(() {
          _locationStatusMessage =
              'Location permission was not granted. You can still choose your pin manually.';
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) {
        return;
      }

      final LatLng currentPoint = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPoint = currentPoint;
        _locationStatusMessage =
            'Current location loaded. You can still tap another place on the map.';
      });
      _mapController.move(currentPoint, 15.5);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationStatusMessage =
            'Freshline could not read your current location right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isResolvingCurrentLocation = false);
      }
    }
  }

  void _confirm() {
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap the map to choose a delivery location.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      DeliveryLocationSelection(
        latitude: _selectedPoint!.latitude,
        longitude: _selectedPoint!.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = _selectedPoint ?? _bahrainCenter;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Choose Delivery Location')),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13.5,
                      onTap: (_, LatLng point) {
                        setState(() => _selectedPoint = point);
                      },
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'freshline_tt',
                      ),
                      MarkerLayer(
                        markers: _selectedPoint == null
                            ? const <Marker>[]
                            : <Marker>[
                                Marker(
                                  point: _selectedPoint!,
                                  width: 52,
                                  height: 52,
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: AppPalette.primary,
                                    size: 40,
                                  ),
                                ),
                              ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Selected Pin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedPoint == null
                          ? 'Tap anywhere on the map to drop your delivery pin.'
                          : DeliveryLocationSelection(
                              latitude: _selectedPoint!.latitude,
                              longitude: _selectedPoint!.longitude,
                            ).fullLabel,
                      style: TextStyle(
                        height: 1.4,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                    if (_locationStatusMessage != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        _locationStatusMessage!,
                        style: TextStyle(
                          height: 1.4,
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isResolvingCurrentLocation
                            ? null
                            : _centerOnCurrentLocation,
                        icon: const Icon(Icons.my_location_rounded),
                        label: Text(
                          _isResolvingCurrentLocation
                              ? 'Finding Current Location...'
                              : 'Use Current Location',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirm,
                        child: const Text('Use This Location'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartCheckoutLine {
  const _CartCheckoutLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  num get lineTotal => product.price * quantity;
}

class _CheckoutPricing {
  const _CheckoutPricing({
    required this.subtotal,
    required this.couponCode,
    required this.couponDiscount,
    required this.loyaltyPointsRedeemed,
    required this.loyaltyDiscount,
    required this.taxAmount,
    required this.totalDue,
  });

  final num subtotal;
  final String? couponCode;
  final num couponDiscount;
  final int loyaltyPointsRedeemed;
  final num loyaltyDiscount;
  final num taxAmount;
  final num totalDue;

  num get totalDiscount => couponDiscount + loyaltyDiscount;
}

class _ProductCheckoutResult {
  const _ProductCheckoutResult({
    required this.card,
    required this.location,
    required this.addressDetails,
    required this.subtotal,
    required this.couponCode,
    required this.couponDiscount,
    required this.loyaltyPointsRedeemed,
    required this.loyaltyDiscount,
    required this.taxAmount,
    required this.totalPaid,
  });

  final PaymentCardInfo card;
  final DeliveryLocationSelection location;
  final String addressDetails;
  final num subtotal;
  final String? couponCode;
  final num couponDiscount;
  final int loyaltyPointsRedeemed;
  final num loyaltyDiscount;
  final num taxAmount;
  final num totalPaid;

  num get totalDiscount => couponDiscount + loyaltyDiscount;
}

class PlansScreen extends StatefulWidget {
  const PlansScreen({
    super.key,
    required this.user,
    required this.platformRepository,
    required this.subscriptionStatus,
    required this.savedCards,
    required this.onAddCard,
  });

  final AppUser user;
  final PlatformRepository platformRepository;
  final CustomerSubscriptionStatus? subscriptionStatus;
  final List<PaymentCardInfo> savedCards;
  final Future<PaymentCardInfo?> Function(String title) onAddCard;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late CustomerSubscriptionStatus? _subscriptionStatus =
      widget.subscriptionStatus;
  bool _isUpdatingAutoRenew = false;

  String _activeSubscriptionLabel() {
    final CustomerSubscriptionStatus? subscription = _subscriptionStatus;
    if (subscription == null) {
      return _tr(
        context,
        'No active plan right now.',
        'لا توجد باقة مفعلة حالياً.',
      );
    }
    if (subscription.endsAt == null) {
      return _tr(
        context,
        '${subscription.plan.localizedName(context)} is active. Expiry date will appear after activation.',
        'باقة ${subscription.plan.localizedName(context)} مفعلة. سيظهر تاريخ الانتهاء بعد التفعيل.',
      );
    }
    return _tr(
      context,
      '${subscription.plan.localizedName(context)} is active until ${formatCalendarDate(subscription.endsAt!)}.',
      'باقة ${subscription.plan.localizedName(context)} مفعلة حتى ${formatCalendarDate(subscription.endsAt!)}.',
    );
  }

  String _autoRenewLabel(bool autoRenew) {
    return autoRenew
        ? 'Auto-renew is enabled. Freshline will renew this plan automatically when the current period ends.'
        : 'Auto-renew is disabled. The plan will stop at the expiry date unless you subscribe again.';
  }

  Future<void> _subscribe(BuildContext context, SubscriptionPlan plan) async {
    if (_subscriptionStatus != null) {
      _showTopToast(
        context,
        title: 'Subscription locked',
        message: _tr(
          context,
          '${_subscriptionStatus!.plan.localizedName(context)} is already active. Plan changes and cancellation are disabled right now.',
          'باقة ${_subscriptionStatus!.plan.localizedName(context)} مفعلة بالفعل حالياً. لا يمكن تغيير الباقة أو إلغاؤها الآن.',
        ),
        icon: Icons.workspace_premium_rounded,
      );
      return;
    }

    final PaymentCardInfo? card = await Navigator.of(context)
        .push<PaymentCardInfo>(
          MaterialPageRoute<PaymentCardInfo>(
            builder: (BuildContext context) => PlanCheckoutScreen(
              plan: plan,
              savedCards: widget.savedCards,
              onAddCard: widget.onAddCard,
            ),
          ),
        );
    if (!context.mounted || card == null) {
      return;
    }

    try {
      await widget.platformRepository.subscribeToPlan(
        user: widget.user,
        plan: plan,
        card: card,
      );
      if (!context.mounted) {
        return;
      }
      final CustomerSubscriptionStatus refreshed =
          await widget.platformRepository.loadCustomerSubscriptionStatus(
            user: widget.user,
          ) ??
          CustomerSubscriptionStatus(
            plan: plan,
            startsAt: DateTime.now(),
            endsAt: DateTime.now().add(const Duration(days: 30)),
            autoRenew: true,
          );
      if (!mounted || !context.mounted) {
        return;
      }
      final String localizedPlanName = plan.localizedName(context);
      final String expiryLabel = refreshed.endsAt == null
          ? _tr(context, 'the saved renewal date', 'تاريخ التجديد المحفوظ')
          : formatCalendarDate(refreshed.endsAt!);
      final String successMessage = _tr(
        context,
        '$localizedPlanName was subscribed successfully with ${card.displayLabel}. It expires on $expiryLabel.',
        'تم الاشتراك في باقة $localizedPlanName بنجاح باستخدام ${card.displayLabel}. ينتهي الاشتراك في $expiryLabel.',
      );
      setState(() => _subscriptionStatus = refreshed);
      _showTopToast(
        this.context,
        title: 'Subscription active',
        message: successMessage,
        icon: Icons.workspace_premium_rounded,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) {
        return;
      }
      if (Navigator.of(this.context).canPop()) {
        Navigator.of(this.context).pop();
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _toggleAutoRenew(bool autoRenew) async {
    final CustomerSubscriptionStatus? current = _subscriptionStatus;
    if (current == null || _isUpdatingAutoRenew) {
      return;
    }

    setState(() => _isUpdatingAutoRenew = true);
    try {
      final CustomerSubscriptionStatus updated =
          await widget.platformRepository.updateCustomerSubscriptionAutoRenew(
            user: widget.user,
            autoRenew: autoRenew,
          ) ??
          current.copyWith(autoRenew: autoRenew);
      if (!mounted) {
        return;
      }
      setState(() => _subscriptionStatus = updated);
      _showTopToast(
        context,
        title: autoRenew ? 'Auto-renew enabled' : 'Auto-renew disabled',
        message: _autoRenewLabel(autoRenew),
        icon: Icons.workspace_premium_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAutoRenew = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionPlan? selectedPlan = _subscriptionStatus?.plan;
    final bool hasActiveSubscription = selectedPlan != null;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Subscribe')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            if (hasActiveSubscription) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.06),
                  border: Border.all(
                    color: AppPalette.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Already Subscribed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_activeSubscriptionLabel()} Other plans are locked, and plan changes or cancellation are disabled right now.',
                      style: TextStyle(
                        height: 1.45,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      value: _subscriptionStatus!.autoRenew,
                      onChanged: _isUpdatingAutoRenew ? null : _toggleAutoRenew,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-renew'),
                      subtitle: Text(
                        _autoRenewLabel(_subscriptionStatus!.autoRenew),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            ...subscriptionPlans.asMap().entries.map((
              MapEntry<int, SubscriptionPlan> entry,
            ) {
              final SubscriptionPlan plan = entry.value;
              final bool active = selectedPlan?.id == plan.id;
              final bool locked = hasActiveSubscription && !active;
              final VoidCallback? onTap = hasActiveSubscription
                  ? null
                  : () => _subscribe(context, plan);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onTap,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: locked ? 0.56 : 1,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: appCardDecoration(
                        border: Border.all(
                          color: active
                              ? AppPalette.primary
                              : AppPalette.border,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  plan.localizedName(context),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                formatBhd(plan.price),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _tr(
                              context,
                              '${plan.rewardPercent}% loyalty bonus on every order',
                              'مكافأة ولاء ${plan.rewardPercent}٪ على كل طلب',
                            ),
                            style: TextStyle(color: AppPalette.mutedForeground),
                          ),
                          const SizedBox(height: 14),
                          ...plan
                              .localizedFeatures(context)
                              .map(
                                (String feature) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: AppPalette.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(feature)),
                                    ],
                                  ),
                                ),
                              ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: onTap,
                              child: Text(
                                active
                                    ? 'Already Subscribed'
                                    : locked
                                    ? 'Locked'
                                    : 'Choose Plan',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class PlanCheckoutScreen extends StatefulWidget {
  const PlanCheckoutScreen({
    super.key,
    required this.plan,
    required this.savedCards,
    required this.onAddCard,
  });

  final SubscriptionPlan plan;
  final List<PaymentCardInfo> savedCards;
  final Future<PaymentCardInfo?> Function(String title) onAddCard;

  @override
  State<PlanCheckoutScreen> createState() => _PlanCheckoutScreenState();
}

class _PlanCheckoutScreenState extends State<PlanCheckoutScreen> {
  String? _selectedCardId;

  Future<void> _addCard() async {
    final PaymentCardInfo? card = await widget.onAddCard(
      _tr(context, 'Add New Card', 'أضف بطاقة جديدة'),
    );
    if (card == null || !mounted) {
      return;
    }
    setState(() => _selectedCardId = card.id);
  }

  void _confirm() {
    final PaymentCardInfo? selectedCard = widget.savedCards
        .where((PaymentCardInfo card) => card.id == _selectedCardId)
        .firstOrNull;
    if (selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Choose a saved card or add a new one.',
              'اختر بطاقة محفوظة أو أضف بطاقة جديدة.',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(selectedCard);
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Subscription Checkout', 'دفع الاشتراك')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.plan.localizedName(context),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr(
                      context,
                      '${widget.plan.rewardPercent}% loyalty bonus on every order',
                      'مكافأة ولاء ${widget.plan.rewardPercent}٪ على كل طلب',
                    ),
                    style: TextStyle(color: AppPalette.mutedForeground),
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Plan Total',
                    value: 'BHD ${formatPrice(widget.plan.price)}',
                    prominent: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Choose Card',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  if (widget.savedCards.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: appCardDecoration(
                        color: AppPalette.background,
                      ),
                      child: Text(
                        _tr(
                          context,
                          'No saved cards yet. Add a new card to continue.',
                          'لا توجد بطاقات محفوظة بعد. أضف بطاقة جديدة للمتابعة.',
                        ),
                        style: TextStyle(color: AppPalette.mutedForeground),
                      ),
                    ),
                  ...widget.savedCards.map((PaymentCardInfo card) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SelectableCard(
                        selected: card.id == _selectedCardId,
                        icon: Icons.credit_card_rounded,
                        title: card.displayLabel,
                        subtitle: '${card.holderName} · ${card.expiryLabel}',
                        onTap: () => setState(() => _selectedCardId = card.id),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _addCard,
                      child: Text(
                        _tr(context, 'Add New Card', 'أضف بطاقة جديدة'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _confirm,
                child: Text(
                  _tr(context, 'Process To Checkout', 'المتابعة إلى الدفع'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key, required this.title});

  final String title;

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _holderController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final _CardNumberFormatter _cardNumberFormatter = _CardNumberFormatter();
  final _ExpiryDateFormatter _expiryDateFormatter = _ExpiryDateFormatter();

  @override
  void dispose() {
    _holderController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String digits = _numberController.text.replaceAll(RegExp(r'\D'), '');
    final String brand = digits.startsWith('4')
        ? 'Visa'
        : digits.startsWith('5')
        ? 'Mastercard'
        : 'Card';

    Navigator.of(context).pop(
      PaymentCardInfo(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        holderName: _holderController.text.trim(),
        brand: brand,
        last4: digits.substring(digits.length - 4),
        expiryLabel: _expiryController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: appCardDecoration(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tr(context, 'Add New Card', 'أضف بطاقة جديدة'),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr(
                      context,
                      'Complete your subscription or booking payment with card details.',
                      'أكمل دفع الاشتراك أو الحجز باستخدام بيانات البطاقة.',
                    ),
                    style: TextStyle(color: AppPalette.mutedForeground),
                  ),
                  const SizedBox(height: 18),
                  _AuthTextField(
                    controller: _holderController,
                    label: _tr(context, 'Card holder name', 'اسم حامل البطاقة'),
                    validator: _requiredField,
                  ),
                  const SizedBox(height: 14),
                  _AuthTextField(
                    controller: _numberController,
                    label: _tr(context, 'Card number', 'رقم البطاقة'),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[_cardNumberFormatter],
                    validator: _validateCardNumber,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _AuthTextField(
                          controller: _expiryController,
                          label: _tr(context, 'Expiry', 'تاريخ الانتهاء'),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            _expiryDateFormatter,
                          ],
                          validator: _validateExpiry,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AuthTextField(
                          controller: _cvvController,
                          label: 'CVV',
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: _validateCvv,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: Text(_tr(context, 'Save Card', 'حفظ البطاقة')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredField(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return _tr(context, 'This field is required.', 'هذا الحقل مطلوب.');
    }
    return null;
  }

  String? _validateCardNumber(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 16) {
      return _tr(
        context,
        'Card number must be 16 digits.',
        'يجب أن يتكون رقم البطاقة من 16 رقماً.',
      );
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    final String text = (value ?? '').trim();
    final RegExpMatch? match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(text);
    if (match == null) {
      return _tr(context, 'Use MM/YY.', 'استخدم MM/YY.');
    }

    final int month = int.tryParse(match.group(1) ?? '') ?? 0;
    final int shortYear = int.tryParse(match.group(2) ?? '') ?? 0;
    if (month < 1 || month > 12) {
      return _tr(context, 'Enter a valid month.', 'أدخل شهراً صحيحاً.');
    }

    final int year = 2000 + shortYear;
    final DateTime entered = DateTime(year, month);
    final DateTime minimum = _minimumAcceptedCardExpiry();
    if (entered.isBefore(minimum)) {
      return _tr(
        context,
        'Expiry must be ${_formatExpiryMonthYear(minimum)} or later.',
        'يجب أن يكون تاريخ الانتهاء ${_formatExpiryMonthYear(minimum)} أو بعده.',
      );
    }

    return null;
  }

  String? _validateCvv(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 3) {
      return _tr(
        context,
        'CVV must be 3 digits.',
        'يجب أن يتكون CVV من 3 أرقام.',
      );
    }
    return null;
  }

  DateTime _minimumAcceptedCardExpiry() {
    final DateTime now = DateTime.now();
    final DateTime currentMonth = DateTime(now.year, now.month);
    final DateTime requestedMinimum = DateTime(2026, 5);
    return currentMonth.isAfter(requestedMinimum)
        ? currentMonth
        : requestedMinimum;
  }

  String _formatExpiryMonthYear(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String year = (value.year % 100).toString().padLeft(2, '0');
    return '$month/$year';
  }
}

class SalonsListScreen extends StatefulWidget {
  const SalonsListScreen({
    super.key,
    required this.salons,
    required this.onOpenSalon,
  });

  final List<Salon> salons;
  final ValueChanged<Salon> onOpenSalon;

  @override
  State<SalonsListScreen> createState() => _SalonsListScreenState();
}

class _SalonsListScreenState extends State<SalonsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final List<Salon> filteredSalons = widget.salons
        .where((Salon salon) {
          final bool matchesQuery =
              query.isEmpty ||
              salon.name.toLowerCase().contains(query) ||
              salon.localizedName(context).toLowerCase().contains(query) ||
              salon.location.toLowerCase().contains(query) ||
              salon.localizedLocation(context).toLowerCase().contains(query) ||
              salon.services.any(
                (String service) =>
                    service.toLowerCase().contains(query) ||
                    _localizedDisplayText(
                      context,
                      service,
                    ).toLowerCase().contains(query),
              );
          final bool matchesFilter = switch (_filter) {
            'Highest Rated' => salon.rating >= 4.7,
            'Closest to Me' => _distanceValue(salon.distance) <= 3.0,
            'Home Service' => salon.homeServiceAvailable,
            'Lower Price' => _priceTierValue(salon.priceLabel) <= 2,
            _ => true,
          };
          return matchesQuery && matchesFilter;
        })
        .toList(growable: false);
    if (_filter == 'Highest Rated') {
      filteredSalons.sort((Salon a, Salon b) => b.rating.compareTo(a.rating));
    } else if (_filter == 'Closest to Me') {
      filteredSalons.sort(
        (Salon a, Salon b) =>
            _distanceValue(a.distance).compareTo(_distanceValue(b.distance)),
      );
    } else if (_filter == 'Lower Price') {
      filteredSalons.sort(
        (Salon a, Salon b) => _priceTierValue(
          a.priceLabel,
        ).compareTo(_priceTierValue(b.priceLabel)),
      );
    }

    return AppViewport(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _TopBar(
                title: _localizedDisplayText(context, 'All Salons'),
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: _localizedDisplayText(
                            context,
                            'Search salons',
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        initialValue: _filter,
                        decoration: InputDecoration(
                          labelText: _localizedDisplayText(context, 'Filter'),
                        ),
                        items:
                            const <String>[
                                  'All',
                                  'Closest to Me',
                                  'Highest Rated',
                                  'Lower Price',
                                  'Home Service',
                                ]
                                .map(
                                  (String value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      _localizedDisplayText(context, value),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() => _filter = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredSalons.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        child: _EmptyStateCard(
                          icon: Icons.storefront_outlined,
                          title: _localizedDisplayText(
                            context,
                            'No salons found',
                          ),
                          message: _localizedDisplayText(
                            context,
                            'Try another search or switch the drop-down filter.',
                          ),
                          actionLabel: _localizedDisplayText(
                            context,
                            'Clear Search',
                          ),
                          onAction: () {
                            setState(() {
                              _searchController.clear();
                              _filter = 'All';
                            });
                          },
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemBuilder: (BuildContext context, int index) {
                          final Salon salon = filteredSalons[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => widget.onOpenSalon(salon),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: appCardDecoration(),
                              child: Row(
                                children: <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: _AppImage(
                                      imagePath: salon.imagePath,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          salon.localizedName(context),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: <Widget>[
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 15,
                                              color: AppPalette.mutedForeground,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${salon.localizedLocation(context)} · ${salon.distance}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppPalette
                                                      .mutedForeground,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: <Widget>[
                                            Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: AppPalette.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${salon.rating}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '(${salon.reviews})',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    AppPalette.mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (BuildContext _, int index) =>
                            const SizedBox(height: 16),
                        itemCount: filteredSalons.length,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SalonDetailScreen extends StatefulWidget {
  const SalonDetailScreen({
    super.key,
    required this.salon,
    required this.products,
    required this.cartIds,
    required this.platformRepository,
    required this.customerAddress,
    required this.initialAddressLocation,
    required this.savedAddresses,
    required this.bookedSlotKeys,
    required this.savedCards,
    this.onRefreshBookedSlots,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onAddCard,
    required this.onAddressSaved,
    required this.onLocationSaved,
    required this.onBookingConfirmed,
  });

  final Salon salon;
  final List<Product> products;
  final Set<String> cartIds;
  final PlatformRepository platformRepository;
  final String customerAddress;
  final DeliveryLocationSelection? initialAddressLocation;
  final List<SavedCustomerAddress> savedAddresses;
  final Set<String> bookedSlotKeys;
  final List<PaymentCardInfo> savedCards;
  final Future<Set<String>> Function()? onRefreshBookedSlots;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<String> onAddToCart;
  final Future<PaymentCardInfo?> Function(String title) onAddCard;
  final ValueChanged<String> onAddressSaved;
  final ValueChanged<DeliveryLocationSelection> onLocationSaved;
  final Future<void> Function(UserOrder order) onBookingConfirmed;

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen> {
  bool _showPackages = true;
  BookingSelection? _selectedBooking;

  Future<void> _openSalonReviews() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CustomerReviewsScreen(
          title: _tr(context, 'Salon Reviews', 'تقييمات الصالون'),
          subtitle: _tr(
            context,
            'What customers said about this salon.',
            'آراء العملاء حول هذا الصالون.',
          ),
          reviewsFuture: widget.platformRepository.loadSalonReviews(
            salonId: widget.salon.id,
          ),
        ),
      ),
    );
  }

  Future<void> _openBooking() async {
    if (_selectedBooking == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => BookingFlowScreen(
          salon: widget.salon,
          platformRepository: widget.platformRepository,
          selection: _selectedBooking!,
          initialCustomerAddress: widget.customerAddress,
          initialAddressLocation: widget.initialAddressLocation,
          savedAddresses: widget.savedAddresses,
          bookedSlotKeys: widget.bookedSlotKeys,
          savedCards: widget.savedCards,
          onAddCard: widget.onAddCard,
          onAddressSaved: widget.onAddressSaved,
          onLocationSaved: widget.onLocationSaved,
          onBookingConfirmed: widget.onBookingConfirmed,
          onRefreshBookedSlots: widget.onRefreshBookedSlots,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SalonMapInfo mapInfo = mapInfoForSalon(widget.salon.id);
    final List<ServicePackage> packages = widget.salon.packages
        .where((ServicePackage item) => item.isActive)
        .toList(growable: false);
    final List<ServiceItem> services = widget.salon.serviceItems
        .where((ServiceItem item) => item.isActive)
        .toList(growable: false);
    final List<Product> salonProducts = widget.products
        .where((Product product) => product.isActive)
        .toList(growable: false);
    final List<_SalonServiceOption> options =
        (_showPackages
                ? packages.map(
                    (ServicePackage item) => _SalonServiceOption(
                      id: item.id,
                      title: item.localizedName(context),
                      titleEn: item.localizedNameForLanguage('EN'),
                      titleAr: item.localizedNameForLanguage('AR'),
                      subtitle: item.localizedDescription(context),
                      duration: item.localizedDuration(context),
                      price: item.price,
                    ),
                  )
                : services.map(
                    (ServiceItem item) => _SalonServiceOption(
                      id: item.id,
                      title: item.localizedName(context),
                      titleEn: item.localizedNameForLanguage('EN'),
                      titleAr: item.localizedNameForLanguage('AR'),
                      subtitle: item.description.trim().isEmpty
                          ? null
                          : item.localizedDescription(context),
                      duration: item.localizedDuration(context),
                      price: item.price,
                    ),
                  ))
            .toList(growable: false);

    return AppViewport(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 280,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _AppImage(
                      imagePath: widget.salon.imagePath,
                      fit: BoxFit.cover,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            AppPalette.foreground.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _RoundIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.of(context).pop(),
                              translucent: true,
                            ),
                            const Spacer(),
                            Text(
                              widget.salon.localizedName(context),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 14,
                              runSpacing: 8,
                              children: <Widget>[
                                _HeroMeta(
                                  icon: Icons.location_on_rounded,
                                  text: (widget.salon.distance.trim().isEmpty)
                                      ? widget.salon.localizedLocation(context)
                                      : '${widget.salon.localizedLocation(context)} · ${widget.salon.distance}',
                                ),
                                _HeroMeta(
                                  icon: Icons.star_rounded,
                                  text:
                                      '${widget.salon.rating} (${widget.salon.reviews})',
                                  onTap: _openSalonReviews,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: appCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _localizedDisplayText(context, 'Salon Details'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              if (widget.salon.localizedLocation(context)
                                  .trim()
                                  .isNotEmpty)
                                _TagCard(
                                  label:
                                      widget.salon.localizedLocation(context),
                                ),
                              if (widget.salon.distance.trim().isNotEmpty)
                                _TagCard(label: widget.salon.distance.trim()),
                              if (widget.salon.homeServiceAvailable)
                                _TagCard(
                                  label: _localizedDisplayText(
                                    context,
                                    'Home Service',
                                  ),
                                ),
                            ],
                          ),
                          if (widget.salon.phone.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 16),
                            Text(
                              widget.salon.phone.trim(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (mapInfo.address.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              mapInfo.address.trim(),
                              style: TextStyle(
                                height: 1.45,
                                color: AppPalette.mutedForeground,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: widget.salon.phone.trim().isEmpty
                                      ? null
                                      : () => _launchUri(
                                            context,
                                            Uri(
                                              scheme: 'tel',
                                              path: widget.salon.phone.trim(),
                                            ),
                                            'Unable to call this salon right now.',
                                            fallbackClipboardValue:
                                                widget.salon.phone.trim(),
                                            fallbackConfirmation:
                                                'Salon phone copied to clipboard.',
                                          ),
                                  icon: const Icon(Icons.call_outlined),
                                  label: Text(
                                    _localizedDisplayText(context, 'Call'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _mapUriForSalon(widget.salon) ==
                                          null
                                      ? null
                                      : () => _launchUri(
                                            context,
                                            _mapUriForSalon(widget.salon)!,
                                            'Unable to open salon location.',
                                            fallbackClipboardValue:
                                                widget.salon.address?.trim(),
                                            fallbackConfirmation:
                                                'Salon address copied to clipboard.',
                                          ),
                                  icon: const Icon(Icons.map_outlined),
                                  label: Text(
                                    _localizedDisplayText(context, 'Open Map'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppPalette.secondary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _SegmentButton(
                              label: _localizedDisplayText(context, 'Packages'),
                              active: _showPackages,
                              onTap: () {
                                setState(() {
                                  _showPackages = true;
                                  _selectedBooking = null;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: _SegmentButton(
                              label: _localizedDisplayText(context, 'Services'),
                              active: !_showPackages,
                              onTap: () {
                                setState(() {
                                  _showPackages = false;
                                  _selectedBooking = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (options.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: appCardDecoration(),
                        child: Text(
                          _localizedDisplayText(
                            context,
                            _showPackages
                                ? 'This salon has no active packages yet.'
                                : 'This salon has no active services yet.',
                          ),
                          style: TextStyle(color: AppPalette.mutedForeground),
                        ),
                      )
                    else
                      ...options.map((_SalonServiceOption item) {
                        final bool selected =
                            _selectedBooking?.serviceId == item.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _BookingCard(
                            title: item.title,
                            subtitle: item.subtitle,
                            duration: item.duration,
                            price: item.price,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                _selectedBooking = BookingSelection(
                                  serviceId: item.id,
                                  serviceName: item.titleEn,
                                  serviceNameAr: item.titleAr,
                                  price: item.price,
                                  salonName: widget.salon.name,
                                  salonNameAr: widget.salon
                                      .localizedNameForLanguage('AR'),
                                  appointmentDuration: _durationFromLabel(
                                    item.duration,
                                  ),
                                );
                              });
                            },
                          ),
                        );
                      }),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _selectedBooking == null
                            ? null
                            : _openBooking,
                        child: Text(_localizedDisplayText(context, 'Next')),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _localizedDisplayText(
                        context,
                        'Products from this salon',
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _localizedDisplayText(
                        context,
                        'Products are added to cart separately from salon bookings, and each cart can only contain products from one salon at a time.',
                      ),
                      style: TextStyle(
                        height: 1.45,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (salonProducts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: appCardDecoration(),
                        child: Text(
                          _localizedDisplayText(
                            context,
                            'This salon has no active products yet.',
                          ),
                          style: TextStyle(color: AppPalette.mutedForeground),
                        ),
                      )
                    else
                      ...salonProducts.map((Product product) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _SalonProductRowCard(
                            product: product,
                            inCart: widget.cartIds.contains(product.id),
                            onTap: () => widget.onOpenProduct(product),
                            onAddToCart: () => widget.onAddToCart(product.id),
                          ),
                        );
                      }),
                    const SizedBox(height: 18),
                    Text(
                      _localizedDisplayText(context, 'About this salon'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: appCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.salon.localizedDescription(context),
                            style: TextStyle(
                              height: 1.5,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppPalette.secondary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Price ${widget.salon.priceLabel}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.salon.homeServiceAvailable
                                      ? AppPalette.primary.withValues(
                                          alpha: 0.16,
                                        )
                                      : AppPalette.secondary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  widget.salon.homeServiceAvailable
                                      ? 'Home service available'
                                      : 'In-salon only',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: widget.salon.homeServiceAvailable
                                        ? AppPalette.primary
                                        : AppPalette.foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'What this salon offers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.salon.services
                          .map(
                            (String service) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.secondary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                service,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({
    super.key,
    required this.salon,
    required this.platformRepository,
    required this.selection,
    required this.initialCustomerAddress,
    required this.initialAddressLocation,
    required this.savedAddresses,
    required this.bookedSlotKeys,
    required this.savedCards,
    required this.onAddCard,
    required this.onAddressSaved,
    required this.onLocationSaved,
    required this.onBookingConfirmed,
    this.onRefreshBookedSlots,
  });

  final Salon salon;
  final PlatformRepository platformRepository;
  final BookingSelection selection;
  final String initialCustomerAddress;
  final DeliveryLocationSelection? initialAddressLocation;
  final List<SavedCustomerAddress> savedAddresses;
  final Set<String> bookedSlotKeys;
  final List<PaymentCardInfo> savedCards;
  final Future<PaymentCardInfo?> Function(String title) onAddCard;
  final ValueChanged<String> onAddressSaved;
  final ValueChanged<DeliveryLocationSelection> onLocationSaved;
  final Future<void> Function(UserOrder order) onBookingConfirmed;
  final Future<Set<String>> Function()? onRefreshBookedSlots;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  final TextEditingController _addressController = TextEditingController();
  int _step = 0;
  String? _visitMode;
  String? _selectedEmployeeId;
  String? _selectedTime;
  late DateTime _selectedBookingDate;
  String? _selectedCardId;
  DeliveryLocationSelection? _selectedHomeLocation;
  String? _selectedSavedAddressId;
  bool _isSubmittingBooking = false;
  bool _isRefreshingBookedSlots = false;
  bool _isLoadingEmployees = true;
  List<Employee> _salonEmployees = <Employee>[];
  Map<String, List<EmployeeScheduleEntry>> _employeeSchedulesById =
      <String, List<EmployeeScheduleEntry>>{};
  late Set<String> _liveBookedSlotKeys;
  Timer? _bookedSlotsRefreshTimer;

  DateTime get _todayDate {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _maxBookingDate => _todayDate.add(const Duration(days: 2));

  bool _isSameCalendarDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isDateWithinWindow(DateTime date) {
    final DateTime normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(_todayDate) && !normalized.isAfter(_maxBookingDate);
  }

  int _scheduleWeekday(DateTime date) => date.weekday % 7;

  EmployeeScheduleEntry? _scheduleForEmployeeOnDate(
    String employeeId,
    DateTime date,
  ) {
    final List<EmployeeScheduleEntry> entries =
        _employeeSchedulesById[employeeId] ?? const <EmployeeScheduleEntry>[];
    if (entries.isEmpty) {
      return null;
    }
    final int weekday = _scheduleWeekday(date);
    final List<EmployeeScheduleEntry> candidates = entries
        .where((EmployeeScheduleEntry entry) => entry.weekday == weekday)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.firstWhere(
      (EmployeeScheduleEntry entry) => entry.isAvailable,
      orElse: () => candidates.first,
    );
  }

  bool _employeeIsAvailableForDate(Employee employee, DateTime date) {
    final EmployeeScheduleEntry? schedule =
        _scheduleForEmployeeOnDate(employee.id, date);
    if (schedule == null) {
      return true;
    }
    if (!schedule.isAvailable) {
      return false;
    }
    if (_visitMode == 'Come to you') {
      return schedule.supportsHomeService;
    }
    return schedule.supportsInShop;
  }

  int _employeeWorkStartMinutesForDate(Employee employee, DateTime date) {
    final EmployeeScheduleEntry? schedule =
        _scheduleForEmployeeOnDate(employee.id, date);
    if (schedule != null) {
      return schedule.startMinutes;
    }
    return employee.workStartMinutes ?? 9 * 60;
  }

  int _employeeWorkEndMinutesForDate(Employee employee, DateTime date) {
    final EmployeeScheduleEntry? schedule =
        _scheduleForEmployeeOnDate(employee.id, date);
    if (schedule != null) {
      return schedule.endMinutes;
    }
    return employee.workEndMinutes ?? 22 * 60;
  }

  String _formatSlotLabelFromMinutes(int minutesSinceMidnight) {
    final int total =
        (minutesSinceMidnight.clamp(0, 24 * 60) as num).toInt();
    final int hour24 = total ~/ 60;
    final int minute = total % 60;
    final String meridiem = hour24 >= 12 ? 'PM' : 'AM';
    final int hour12 = ((hour24 + 11) % 12) + 1;
    return '$hour12:${minute.toString().padLeft(2, '0')} $meridiem';
  }

  List<String> _generateSlotsForEmployee(Employee employee, DateTime date) {
    final int workStart = _employeeWorkStartMinutesForDate(employee, date);
    final int workEnd = _employeeWorkEndMinutesForDate(employee, date);
    if (workEnd <= workStart) {
      return const <String>[];
    }

    final int durationMinutes =
        widget.selection.appointmentDuration?.inMinutes ?? 30;
    final int stepMinutes = 30;
    final int latestStart = workEnd - durationMinutes;
    final List<String> slots = <String>[];
    for (int minutes = workStart; minutes <= latestStart; minutes += stepMinutes) {
      slots.add(_formatSlotLabelFromMinutes(minutes));
    }
    return slots;
  }

  DateTime _bookingDateTimeForSlot(String slot, {DateTime? bookingDate}) {
    final DateTime resolvedDate = bookingDate ?? _selectedBookingDate;
    final RegExp expression = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$');
    final RegExpMatch? match = expression.firstMatch(slot.toUpperCase());
    if (match == null) {
      return DateTime(
        resolvedDate.year,
        resolvedDate.month,
        resolvedDate.day,
        12,
      );
    }

    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    final String meridiem = match.group(3)!;

    if (meridiem == 'PM' && hour != 12) {
      hour += 12;
    } else if (meridiem == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(
      resolvedDate.year,
      resolvedDate.month,
      resolvedDate.day,
      hour,
      minute,
    );
  }

  Future<void> _refreshBookedSlots() async {
    final Future<Set<String>> Function()? refresh = widget.onRefreshBookedSlots;
    if (refresh == null || _isRefreshingBookedSlots) {
      return;
    }
    setState(() => _isRefreshingBookedSlots = true);
    try {
      final Set<String> keys = await refresh();
      if (!mounted) {
        return;
      }
      setState(() => _liveBookedSlotKeys = Set<String>.from(keys));
    } catch (_) {
      // Ignore refresh failures.
    } finally {
      if (mounted) {
        setState(() => _isRefreshingBookedSlots = false);
      }
    }
  }

  void _startAutoBookedSlotsRefresh() {
    if (widget.onRefreshBookedSlots == null) {
      return;
    }
    _bookedSlotsRefreshTimer?.cancel();
    _bookedSlotsRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_refreshBookedSlots()),
    );
  }

  void _stopAutoBookedSlotsRefresh() {
    _bookedSlotsRefreshTimer?.cancel();
    _bookedSlotsRefreshTimer = null;
  }

  Future<void> _openEmployeeReviews(Employee employee) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CustomerReviewsScreen(
          title: _tr(context, 'Employee Reviews', 'تقييمات الموظف'),
          subtitle: _tr(
            context,
            'What customers said about ${employee.name}.',
            'آراء العملاء حول ${employee.name}.',
          ),
          reviewsFuture: widget.platformRepository.loadEmployeeReviews(
            employeeId: employee.id,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialCustomerAddress;
    _selectedHomeLocation = widget.initialAddressLocation;
    _selectedCardId = widget.savedCards.firstOrNull?.id;
    _selectedSavedAddressId = _matchingSavedAddress?.id;
    _selectedBookingDate = _todayDate;
    _liveBookedSlotKeys = Set<String>.from(widget.bookedSlotKeys);
    unawaited(_loadSalonEmployees());
  }

  @override
  void dispose() {
    _stopAutoBookedSlotsRefresh();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_step == 0 && _visitMode == null) {
      return _showBookingError();
    }
    if (_step == 1 && _selectedEmployeeId == null) {
      return _showBookingError();
    }
    if (_step == 2 && _selectedTime == null) {
      return _showBookingError();
    }
    if (_step == 3 &&
        _visitMode == 'Come to you' &&
        (_selectedHomeLocation == null ||
            _addressController.text.trim().isEmpty)) {
      return _showBookingError();
    }
    if (_step == 4 && _selectedCardId == null) {
      return _showBookingError();
    }
    if (_step == 4) {
      await _confirmBooking();
      return;
    }

    final int nextStep = _step + 1;
    setState(() => _step = nextStep);
    if (_step == 2) {
      _startAutoBookedSlotsRefresh();
      unawaited(_refreshBookedSlots());
    } else {
      _stopAutoBookedSlotsRefresh();
    }
  }

  void _showBookingError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            context,
            'Please complete this step first.',
            'يرجى إكمال هذه الخطوة أولاً.',
          ),
        ),
      ),
    );
  }

  Future<void> _loadSalonEmployees() async {
    if (mounted) {
      setState(() => _isLoadingEmployees = true);
    }
    try {
      final List<Employee> employees = await widget.platformRepository
          .loadSalonEmployees(salonId: widget.salon.id);
      if (!mounted) {
        return;
      }
      final Map<String, List<EmployeeScheduleEntry>> schedules =
          await widget.platformRepository.loadEmployeeSchedules(
        employeeIds: employees.map((Employee employee) => employee.id).toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _salonEmployees = employees;
        _employeeSchedulesById = schedules;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  Future<void> _addNewCard() async {
    final PaymentCardInfo? card = await widget.onAddCard(
      _tr(context, 'Add New Card', 'أضف بطاقة جديدة'),
    );
    if (card == null || !mounted) {
      return;
    }
    setState(() => _selectedCardId = card.id);
  }

  String _slotKeyFor(
    String employeeId,
    String slot, {
    DateTime? bookingDate,
  }) {
    return '${widget.salon.id}|$employeeId|${_bookingDateTimeForSlot(slot, bookingDate: bookingDate).toIso8601String()}';
  }

  bool _isSlotBooked(
    String employeeId,
    String slot, {
    DateTime? bookingDate,
  }) {
    return _liveBookedSlotKeys.contains(
      _slotKeyFor(employeeId, slot, bookingDate: bookingDate),
    );
  }

  Future<void> _pickHomeLocation() async {
    final DeliveryLocationSelection? result = await Navigator.of(context)
        .push<DeliveryLocationSelection>(
          MaterialPageRoute<DeliveryLocationSelection>(
            builder: (BuildContext context) => _DeliveryLocationPickerScreen(
              initialLocation: _selectedHomeLocation,
            ),
          ),
        );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _selectedHomeLocation = result;
      _selectedSavedAddressId = _matchingSavedAddress?.id;
    });
  }

  SavedCustomerAddress? get _matchingSavedAddress {
    return widget.savedAddresses
        .where(
          (SavedCustomerAddress item) =>
              item.addressLine.trim().toLowerCase() ==
                  _addressController.text.trim().toLowerCase() &&
              _sameDeliveryLocation(item.location, _selectedHomeLocation),
        )
        .firstOrNull;
  }

  void _applySavedAddress(SavedCustomerAddress address) {
    setState(() {
      _selectedSavedAddressId = address.id;
      _selectedHomeLocation = address.location;
      _addressController.text = address.addressLine;
    });
  }

  Future<void> _confirmBooking() async {
    if (_isSubmittingBooking) {
      return;
    }

    final List<Employee> availableEmployees = _availableEmployees();
    if (availableEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'No employees are available for this booking yet.',
              'لا يوجد موظفون متاحون لهذا الحجز حالياً.',
            ),
          ),
        ),
      );
      return;
    }
    final Employee selectedEmployee = availableEmployees.firstWhere(
      (Employee employee) => employee.id == _selectedEmployeeId,
      orElse: () => availableEmployees.first,
    );
    final PaymentCardInfo? selectedCard = widget.savedCards
        .where((PaymentCardInfo card) => card.id == _selectedCardId)
        .firstOrNull;
    if (!_isDateWithinWindow(_selectedBookingDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'You can only book within the next 3 days.',
              'يمكنك الحجز بحد أقصى خلال 3 أيام.',
            ),
          ),
        ),
      );
      return;
    }
    final DateTime scheduledAt = _bookingDateTimeForSlot(_selectedTime!);
    if (_isSameCalendarDate(_selectedBookingDate, _todayDate) &&
        !scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Choose a future time slot.',
              'اختر وقتاً قادماً.',
            ),
          ),
        ),
      );
      return;
    }
    if (selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Choose a payment card first.',
              'اختر بطاقة دفع أولاً.',
            ),
          ),
        ),
      );
      return;
    }
    await _refreshBookedSlots();
    if (!mounted) {
      return;
    }
    if (_selectedTime != null &&
        _isSlotBooked(selectedEmployee.id, _selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'This time was just booked. Please choose another slot.',
              'تم حجز هذا الوقت الآن. اختر وقتاً آخر.',
            ),
          ),
        ),
      );
      return;
    }
    if (_visitMode == 'Come to you' && _selectedHomeLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Choose your home-service location from the map.',
              'اختر موقع الخدمة المنزلية من الخريطة.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmittingBooking = true);

    final UserOrder order = UserOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: UserOrderType.salonBooking,
      invoiceNumber: generateFreshlineInvoiceNumber(),
      salonId: widget.salon.id,
      employeeId: selectedEmployee.id,
      salonName: widget.salon.name,
      salonNameAr: widget.salon.localizedNameForLanguage('AR'),
      serviceName: widget.selection.serviceName,
      serviceNameAr: widget.selection.serviceNameAr,
      employeeName: selectedEmployee.name,
      employeeNameAr: _localizedDisplayTextForLanguage(
        'AR',
        selectedEmployee.name,
      ),
      visitMode:
          _visitMode ?? _tr(context, 'Go to saloon', 'الذهاب إلى الصالون'),
      visitModeAr: _visitMode == 'Come to you'
          ? 'الخدمة المنزلية'
          : 'الذهاب إلى الصالون',
      scheduledAt: scheduledAt,
      total: widget.selection.price,
      statusLabel: 'In order',
      statusLabelAr: 'قيد التنفيذ',
      loyaltyPointsGained: 0,
      appointmentDuration: widget.selection.appointmentDuration,
      addressDetails: _visitMode == 'Come to you'
          ? _addressController.text.trim()
          : null,
      location: _visitMode == 'Come to you' ? _selectedHomeLocation : null,
      address: _visitMode == 'Come to you'
          ? '${_addressController.text.trim()}, ${_selectedHomeLocation!.fullLabel}'
          : (widget.salon.address?.trim().isNotEmpty ?? false)
              ? widget.salon.address!.trim()
              : null,
      cardLabel: selectedCard.displayLabel,
    );

    try {
      if (_visitMode == 'Come to you' &&
          _addressController.text.trim().isNotEmpty) {
        widget.onAddressSaved(_addressController.text.trim());
      }
      if (_selectedHomeLocation != null) {
        widget.onLocationSaved(_selectedHomeLocation!);
      }

      await widget.onBookingConfirmed(order);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(_tr(context, 'Booking confirmed', 'تم تأكيد الحجز')),
          content: Text(
            _tr(
              context,
              'Your booking was confirmed successfully. You can view it now in My Orders.',
              'تم تأكيد الحجز بنجاح. يمكنك مشاهدة الحجز الآن في شاشة طلباتي.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tr(context, 'Go to My Orders', 'اذهب إلى طلباتي')),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((Route<dynamic> route) => route.isFirst);
    } catch (error, stackTrace) {
      debugPrint('Booking confirmation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _isSubmittingBooking = false);
      final String message = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty
                ? _tr(
                    context,
                    'Could not confirm the booking. Please try again.',
                    'تعذر تأكيد الحجز. حاول مرة أخرى.',
                  )
                : message,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Employee> availableEmployees = _availableEmployees();
    final Employee? selectedEmployee = availableEmployees
        .where((Employee employee) => employee.id == _selectedEmployeeId)
        .firstOrNull;
    final PaymentCardInfo? selectedCard = widget.savedCards
        .where((PaymentCardInfo card) => card.id == _selectedCardId)
        .firstOrNull;
    final String selectionServiceName = widget.selection.localizedServiceName(
      context,
    );
    final String selectionSalonName = widget.selection.localizedSalonName(
      context,
    );
    final String selectedEmployeeName = selectedEmployee == null
        ? _tr(context, 'Not selected', 'غير محدد')
        : _localizedDisplayText(context, selectedEmployee.name);
    final String visitModeLabel = _visitMode == null
        ? _tr(context, 'Not selected', 'غير محدد')
        : _visitMode == 'Come to you'
        ? _tr(context, 'Come to you', 'نأتي إليك')
        : _tr(context, 'Go to saloon', 'الذهاب إلى الصالون');
    final List<String> steps = <String>[
      _tr(context, 'Visit', 'الزيارة'),
      _tr(context, 'Employee', 'الموظف'),
      _tr(context, 'Time', 'الوقت'),
      _tr(context, 'Address', 'العنوان'),
      _tr(context, 'Payment', 'الدفع'),
    ];

    return AppViewport(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _TopBar(
                title: _tr(context, 'Book Appointment', 'حجز موعد'),
                subtitle: selectionServiceName,
                onBack: () {
                  if (!_isSubmittingBooking) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: appCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tr(
                              context,
                              'Step ${_step + 1} of ${steps.length}',
                              'الخطوة ${_step + 1} من ${steps.length}',
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            steps[_step],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _BookingStepContainer(
                      title: _step == 0
                          ? _tr(
                              context,
                              'Do you go to the saloon or should we come to you?',
                              'هل ستذهب إلى الصالون أم نأتي إليك؟',
                            )
                          : _step == 1
                          ? _tr(
                              context,
                              'Select an available employee',
                              'اختر موظفاً متاحاً',
                            )
                          : _step == 2
                          ? _tr(
                              context,
                              'Choose an available time',
                              'اختر وقتاً متاحاً',
                            )
                          : _step == 3
                          ? (_visitMode == 'Come to you'
                                ? _tr(
                                    context,
                                    'Enter your address',
                                    'أدخل عنوانك',
                                  )
                                : _tr(
                                    context,
                                    'Salon visit summary',
                                    'ملخص زيارة الصالون',
                                  ))
                          : _tr(context, 'Pay with card', 'ادفع بالبطاقة'),
                      child: _buildBookingStep(selectedCard),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: appCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tr(context, 'Booking Summary', 'ملخص الحجز'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SummaryRow(
                            label: _tr(context, 'Salon', 'الصالون'),
                            value: selectionSalonName,
                          ),
                          _SummaryRow(
                            label: _tr(context, 'Service', 'الخدمة'),
                            value: selectionServiceName,
                          ),
                          _SummaryRow(
                            label: _tr(context, 'Visit', 'الزيارة'),
                            value: visitModeLabel,
                          ),
                          _SummaryRow(
                            label: _tr(context, 'Stylist', 'الموظف'),
                            value: selectedEmployeeName,
                          ),
                          if (_visitMode == 'Come to you')
                            _SummaryRow(
                              label: _tr(context, 'Address', 'العنوان'),
                              value: _addressController.text.trim().isEmpty
                                  ? _tr(context, 'Not selected', 'غير محدد')
                                  : _addressController.text.trim(),
                            ),
                          if (_visitMode == 'Come to you')
                            _SummaryRow(
                              label: _tr(
                                context,
                                'Pinned location',
                                'الموقع المحدد',
                              ),
                              value:
                                  _selectedHomeLocation?.shortLabel ??
                                  _tr(context, 'Not selected', 'غير محدد'),
                            ),
                          _SummaryRow(
                            label: _tr(context, 'Time', 'الوقت'),
                            value:
                                _selectedTime ??
                                _tr(context, 'Not selected', 'غير محدد'),
                          ),
                          _SummaryRow(
                            label: _tr(context, 'Payment', 'الدفع'),
                            value:
                                selectedCard?.displayLabel ??
                                _tr(context, 'Not selected', 'غير محدد'),
                          ),
                          const Divider(height: 26),
                          _SummaryRow(
                            label: _tr(context, 'Total', 'الإجمالي'),
                            value: formatBhd(widget.selection.price),
                            prominent: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmittingBooking ? null : _continue,
                        child: _isSubmittingBooking
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _tr(
                                      context,
                                      'Confirming...',
                                      'جارٍ التأكيد...',
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _step == steps.length - 1
                                    ? _tr(
                                        context,
                                        'Confirm Booking',
                                        'تأكيد الحجز',
                                      )
                                    : _tr(context, 'Next', 'التالي'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingStep(PaymentCardInfo? selectedCard) {
    switch (_step) {
      case 0:
        return Column(
          children: <Widget>[
            _SelectableCard(
              selected: _visitMode == 'Go to saloon',
              icon: Icons.storefront_rounded,
              title: _tr(context, 'Go to saloon', 'الذهاب إلى الصالون'),
              subtitle: widget.salon.localizedAddress(context).trim().isEmpty
                  ? _tr(
                      context,
                      'Address not provided by this salon yet.',
                      'العنوان غير متوفر لهذا الصالون حالياً.',
                    )
                  : widget.salon.localizedAddress(context),
              onTap: () {
                setState(() {
                  _visitMode = 'Go to saloon';
                  _selectedEmployeeId = null;
                  _selectedTime = null;
                });
              },
            ),
            const SizedBox(height: 14),
            _SelectableCard(
              selected: _visitMode == 'Come to you',
              icon: Icons.home_work_outlined,
              title: _tr(context, 'Come to you', 'نأتي إليك'),
              subtitle: _tr(
                context,
                'Home service with address confirmation',
                'خدمة منزلية مع تأكيد العنوان',
              ),
              onTap: () {
                setState(() {
                  _visitMode = 'Come to you';
                  _selectedEmployeeId = null;
                  _selectedTime = null;
                });
              },
            ),
          ],
        );
      case 1:
        if (_isLoadingEmployees && _salonEmployees.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Employee> availableEmployees = _availableEmployees();
        if (availableEmployees.isEmpty) {
          return _EmptyStateCard(
            icon: Icons.group_off_rounded,
            title: _tr(
              context,
              'No matching employees',
              'لا يوجد موظفون مناسبون',
            ),
            message: _visitMode == 'Come to you'
                ? _tr(
                    context,
                    'This salon does not have a home-service employee available right now.',
                    'لا يوجد في هذا الصالون موظف متاح للخدمة المنزلية حالياً.',
                  )
                : _tr(
                    context,
                    'This salon does not have an in-salon employee available right now.',
                    'لا يوجد في هذا الصالون موظف متاح داخل الصالون حالياً.',
                  ),
          );
        }
        return Column(
          children: availableEmployees
              .map((Employee employee) {
                final bool selected = employee.id == _selectedEmployeeId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _EmployeeCard(
                    employee: employee,
                    selected: selected,
                    onTap: () {
                      setState(() {
                        _selectedEmployeeId = employee.id;
                        _selectedTime = null;
                      });
                      unawaited(_refreshBookedSlots());
                    },
                    onTapReviews: () => _openEmployeeReviews(employee),
                  ),
                );
              })
              .toList(growable: false),
        );
      case 2:
        final List<DateTime> availableDates = <DateTime>[
          _todayDate,
          _todayDate.add(const Duration(days: 1)),
          _todayDate.add(const Duration(days: 2)),
        ];
        final List<String> availableSlots = _availableTimeSlots();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _tr(context, 'Choose a date', 'اختر التاريخ'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: availableDates.map((DateTime date) {
                final bool selected = _isSameCalendarDate(date, _selectedBookingDate);
                final String label = _isSameCalendarDate(date, _todayDate)
                    ? _tr(context, 'Today', 'اليوم')
                    : _isSameCalendarDate(date, _todayDate.add(const Duration(days: 1)))
                        ? _tr(context, 'Tomorrow', 'بكرة')
                        : _tr(context, 'Day after', 'بعد بكرة');
                return ChoiceChip(
                  label: Text('$label · ${formatCalendarDate(date)}'),
                  selected: selected,
                  selectedColor: AppPalette.primary.withValues(alpha: 0.16),
                  backgroundColor: AppPalette.card,
                  side: BorderSide(
                    color: selected ? AppPalette.primary : AppPalette.border,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedBookingDate = date;
                      _selectedTime = null;
                    });
                    unawaited(_refreshBookedSlots());
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Text(
                  _tr(context, 'Choose an available time', 'اختر وقتاً متاحاً'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (widget.onRefreshBookedSlots != null)
                  TextButton.icon(
                    onPressed: _isRefreshingBookedSlots ? null : _refreshBookedSlots,
                    icon: _isRefreshingBookedSlots
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(_tr(context, 'Refresh', 'تحديث')),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (availableSlots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: appCardDecoration(color: AppPalette.background),
                child: Text(
                  _tr(
                    context,
                    'No available times for this date. Choose another day or employee.',
                    'لا توجد أوقات متاحة لهذا التاريخ. اختر يوماً أو موظفاً آخر.',
                  ),
                  style: TextStyle(
                    color: AppPalette.mutedForeground,
                    height: 1.45,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availableSlots
                    .map((String slot) {
                      final bool selected = slot == _selectedTime;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: selected,
                        selectedColor:
                            AppPalette.primary.withValues(alpha: 0.16),
                        backgroundColor: AppPalette.card,
                        side: BorderSide(
                          color:
                              selected ? AppPalette.primary : AppPalette.border,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedTime = slot),
                      );
                    })
                    .toList(growable: false),
              ),
          ],
        );
      case 3:
        if (_visitMode == 'Come to you') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.savedAddresses.isNotEmpty) ...<Widget>[
                Text(
                  _tr(context, 'Saved Addresses', 'العناوين المحفوظة'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...widget.savedAddresses.map((SavedCustomerAddress address) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SelectableCard(
                      selected: _selectedSavedAddressId == address.id,
                      icon: address.isDefault
                          ? Icons.home_rounded
                          : Icons.location_on_outlined,
                      title: address.label,
                      subtitle: address.subtitle,
                      onTap: () => _applySavedAddress(address),
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Text(
                  _selectedHomeLocation == null
                      ? _tr(
                          context,
                          'No map location selected yet.',
                          'لم يتم تحديد موقع من الخريطة بعد.',
                        )
                      : _selectedHomeLocation!.fullLabel,
                  style: TextStyle(
                    height: 1.4,
                    color: _selectedHomeLocation == null
                        ? AppPalette.mutedForeground
                        : AppPalette.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickHomeLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    _selectedHomeLocation == null
                        ? _tr(context, 'Choose From Map', 'اختر من الخريطة')
                        : _tr(
                            context,
                            'Change Map Location',
                            'تغيير موقع الخريطة',
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                maxLines: 3,
                onChanged: (_) {
                  setState(
                    () => _selectedSavedAddressId = _matchingSavedAddress?.id,
                  );
                },
                decoration: InputDecoration(
                  labelText: _tr(context, 'Address details', 'تفاصيل العنوان'),
                  hintText: _tr(
                    context,
                    'Block, road, building, apartment, notes',
                    'المجمع، الطريق، المبنى، الشقة، ملاحظات',
                  ),
                ),
              ),
            ],
          );
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: appCardDecoration(color: AppPalette.background),
          child: Text(
            widget.salon.localizedAddress(context).trim().isEmpty
                ? _tr(
                    context,
                    'Address not provided by this salon yet.',
                    'العنوان غير متوفر لهذا الصالون حالياً.',
                  )
                : widget.salon.localizedAddress(context),
            style: TextStyle(color: AppPalette.mutedForeground),
          ),
        );
      default:
        return Column(
          children: <Widget>[
            if (widget.savedCards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: appCardDecoration(color: AppPalette.background),
                child: Text(
                  _tr(
                    context,
                    'No saved cards yet. Add a new card to continue.',
                    'لا توجد بطاقات محفوظة بعد. أضف بطاقة جديدة للمتابعة.',
                  ),
                  style: TextStyle(color: AppPalette.mutedForeground),
                ),
              ),
            ...widget.savedCards.map(
              (PaymentCardInfo card) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _SelectableCard(
                  selected: card.id == _selectedCardId,
                  icon: Icons.credit_card_rounded,
                  title: card.displayLabel,
                  subtitle: '${card.holderName} · ${card.expiryLabel}',
                  onTap: () => setState(() => _selectedCardId = card.id),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _addNewCard,
                child: Text(
                  selectedCard == null
                      ? _tr(context, 'Add New Card', 'أضف بطاقة جديدة')
                      : _tr(context, 'Use Another Card', 'استخدم بطاقة أخرى'),
                ),
              ),
            ),
          ],
        );
    }
  }

  List<Employee> _availableEmployees() {
    final List<Employee> employeesForSalon = _salonEmployees.isEmpty
        ? employeesForSalonFallback(widget.salon.id)
        : _salonEmployees;
    final List<Employee> employees = _visitMode == 'Come to you'
        ? employeesForSalon
            .where((Employee employee) => employee.supportsHomeService)
            .toList(growable: false)
        : employeesForSalon
            .where((Employee employee) => employee.supportsInShop)
            .toList(growable: false);

    return employees
        .where(
          (Employee employee) => _step <= 1
              ? _employeeHasAnyAvailableSlot(
                  employee,
                  considerBookingWindow: true,
                )
              : _employeeHasAnyAvailableSlot(employee),
        )
        .toList(growable: false);
  }

  bool _employeeHasAnyAvailableSlot(
    Employee employee, {
    bool considerBookingWindow = false,
  }) {
    final DateTime now = DateTime.now();
    final int durationMinutes =
        widget.selection.appointmentDuration?.inMinutes ?? 30;

    final List<DateTime> bookingDates = considerBookingWindow
        ? <DateTime>[
            _todayDate,
            _todayDate.add(const Duration(days: 1)),
            _todayDate.add(const Duration(days: 2)),
          ]
        : <DateTime>[_selectedBookingDate];

    for (final DateTime bookingDate in bookingDates) {
      if (!_isDateWithinWindow(bookingDate)) {
        continue;
      }
      if (!_employeeIsAvailableForDate(employee, bookingDate)) {
        continue;
      }
      final bool isToday = _isSameCalendarDate(bookingDate, _todayDate);
      for (final String slot in _generateSlotsForEmployee(employee, bookingDate)) {
        final DateTime slotTime =
            _bookingDateTimeForSlot(slot, bookingDate: bookingDate);
        if (isToday && !slotTime.isAfter(now)) {
          continue;
        }
        if (_isSlotBooked(employee.id, slot, bookingDate: bookingDate)) {
          continue;
        }
        if (!_slotWithinEmployeeSchedule(
          employee: employee,
          slotStartMinutes: (slotTime.hour * 60) + slotTime.minute,
          durationMinutes: durationMinutes,
          bookingDate: bookingDate,
        )) {
          continue;
        }
        return true;
      }
    }

    return false;
  }

  bool _slotWithinEmployeeSchedule({
    required Employee employee,
    required int slotStartMinutes,
    required int durationMinutes,
    required DateTime bookingDate,
  }) {
    if (!_employeeIsAvailableForDate(employee, bookingDate)) {
      return false;
    }
    final int workStart = _employeeWorkStartMinutesForDate(employee, bookingDate);
    final int workEnd = _employeeWorkEndMinutesForDate(employee, bookingDate);

    final int slotEndMinutes = slotStartMinutes + durationMinutes;
    if (slotStartMinutes < workStart || slotEndMinutes > workEnd) {
      return false;
    }

    final int? breakStart = employee.breakStartMinutes;
    final int? breakEnd = employee.breakEndMinutes;
    if (breakStart == null || breakEnd == null) {
      return true;
    }

    final bool overlapsBreak =
        slotStartMinutes < breakEnd && slotEndMinutes > breakStart;
    return !overlapsBreak;
  }

  List<String> _availableTimeSlots() {
    if (!_isDateWithinWindow(_selectedBookingDate)) {
      return const <String>[];
    }
    final DateTime now = DateTime.now();
    final bool isToday = _isSameCalendarDate(_selectedBookingDate, _todayDate);
    final List<Employee> availableEmployees = _availableEmployees();
    final int durationMinutes =
        widget.selection.appointmentDuration?.inMinutes ?? 30;
    if (_selectedEmployeeId == null) {
      // No employee selected yet: return a small sample of future slots.
      final List<Employee> employees = availableEmployees;
      if (employees.isEmpty) {
        return const <String>[];
      }
      final List<String> rawSlots =
          _generateSlotsForEmployee(employees.first, _selectedBookingDate);
      return rawSlots
          .where((String slot) => !isToday || _bookingDateTimeForSlot(slot).isAfter(now))
          .take(8)
          .toList(growable: false);
    }

    final Employee? selectedEmployee = availableEmployees
        .where((Employee employee) => employee.id == _selectedEmployeeId)
        .firstOrNull;

    final List<String> rawSlots = selectedEmployee == null
        ? const <String>[]
        : _generateSlotsForEmployee(selectedEmployee, _selectedBookingDate);

    return rawSlots
        .where((String slot) => !_isSlotBooked(_selectedEmployeeId!, slot))
        .where((String slot) {
          if (selectedEmployee == null) {
            return true;
          }
          final DateTime slotTime = _bookingDateTimeForSlot(slot);
          return _slotWithinEmployeeSchedule(
            employee: selectedEmployee,
            slotStartMinutes: (slotTime.hour * 60) + slotTime.minute,
            durationMinutes: durationMinutes,
            bookingDate: _selectedBookingDate,
          );
        })
        .where((String slot) {
          if (!isToday) {
            return true;
          }
          return _bookingDateTimeForSlot(slot).isAfter(now);
        })
        .toList(growable: false);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.currentPlan,
    required this.subscriptionStatus,
    required this.customerOrderCount,
    required this.availableCoupons,
    required this.savedCards,
    required this.platformRepository,
    required this.onAddCard,
    required this.onRemoveCard,
    required this.onUserChanged,
    required this.onOpenNotifications,
    required this.onOpenPlans,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isHighContrast,
    required this.onHighContrastChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isBiometricLockEnabled,
    required this.onBiometricLockChanged,
  });

  final AppUser user;
  final VoidCallback onLogout;
  final SubscriptionPlan? currentPlan;
  final CustomerSubscriptionStatus? subscriptionStatus;
  final int customerOrderCount;
  final List<PromoCouponRecord> availableCoupons;
  final List<PaymentCardInfo> savedCards;
  final PlatformRepository platformRepository;
  final Future<PaymentCardInfo?> Function(String title) onAddCard;
  final Future<void> Function(PaymentCardInfo card) onRemoveCard;
  final ValueChanged<AppUser> onUserChanged;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenPlans;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final bool isBiometricLockEnabled;
  final AsyncBoolCallback onBiometricLockChanged;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String subscriptionTileSubtitle = currentPlan == null
        ? _tr(context, 'No plan active yet', 'لا توجد باقة مفعلة حالياً')
        : subscriptionStatus?.endsAt == null
        ? _tr(
            context,
            '${currentPlan!.localizedName(context)} plan active · expiry pending',
            'باقة ${currentPlan!.localizedName(context)} مفعلة · تاريخ الانتهاء غير محدد',
          )
        : _tr(
            context,
            '${currentPlan!.localizedName(context)} plan active · expires ${formatCalendarDate(subscriptionStatus!.endsAt!)} · auto-renew ${subscriptionStatus!.autoRenew ? 'on' : 'off'}',
            'باقة ${currentPlan!.localizedName(context)} مفعلة · تنتهي ${formatCalendarDate(subscriptionStatus!.endsAt!)} · التجديد التلقائي ${subscriptionStatus!.autoRenew ? 'مفعل' : 'موقوف'}',
          );
    final String userStatusText = currentPlan == null
        ? _tr(context, 'No subscription active', 'لا يوجد اشتراك مفعل')
        : subscriptionStatus?.endsAt == null
        ? _tr(
            context,
            '${currentPlan!.localizedName(context)} plan active · expiry pending',
            'باقة ${currentPlan!.localizedName(context)} مفعلة · تاريخ الانتهاء غير محدد',
          )
        : _tr(
            context,
            '${currentPlan!.localizedName(context)} plan active until ${formatCalendarDate(subscriptionStatus!.endsAt!)} · auto-renew ${subscriptionStatus!.autoRenew ? 'on' : 'off'}',
            'باقة ${currentPlan!.localizedName(context)} مفعلة حتى ${formatCalendarDate(subscriptionStatus!.endsAt!)} · التجديد التلقائي ${subscriptionStatus!.autoRenew ? 'مفعل' : 'موقوف'}',
          );
    final List<PromoCouponRecord> customerCoupons = availableCoupons
        .where(
          (PromoCouponRecord coupon) =>
              coupon.isActive && coupon.matchesPlan(currentPlan),
        )
        .toList();
    final int readyCouponsCount = customerCoupons
        .where(
          (PromoCouponRecord coupon) =>
              coupon.isAvailableAt(now) &&
              coupon.isEligibleForOrderCount(customerOrderCount),
        )
        .length;
    final List<_SettingsItem> items = <_SettingsItem>[
      _SettingsItem(
        icon: Icons.person_outline_rounded,
        label: _tr(context, 'Account Details', 'تفاصيل الحساب'),
        subtitle: _tr(
          context,
          'Email, phone, city, and profile summary',
          'البريد والهاتف والمدينة وملخص الحساب',
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => AccountDetailsScreen(
                user: user,
                platformRepository: platformRepository,
                onUserChanged: onUserChanged,
              ),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.notifications_none_rounded,
        label: _tr(context, 'Notifications', 'الإشعارات'),
        subtitle: _tr(
          context,
          'Open your latest booking and AI updates',
          'اعرض آخر تحديثات الحجوزات والذكاء',
        ),
        onTap: onOpenNotifications,
      ),
      _SettingsItem(
        icon: Icons.help_outline_rounded,
        label: _tr(context, 'Help & Support', 'المساعدة والدعم'),
        subtitle: _tr(
          context,
          'Support hub, FAQ, and contact channels',
          'مركز الدعم والأسئلة الشائعة ووسائل التواصل',
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  HelpSupportScreen(role: user.role),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.workspace_premium_outlined,
        label: _tr(context, 'Subscription', 'الاشتراك'),
        subtitle: subscriptionTileSubtitle,
        onTap: () {
          onOpenPlans();
        },
      ),
      _SettingsItem(
        icon: Icons.palette_outlined,
        label: _tr(context, 'Appearance & Language', 'المظهر واللغة'),
        subtitle: _tr(
          context,
          'Theme, contrast, font size, and language',
          'الثيم والتباين وحجم الخط واللغة',
        ),
        onTap: () {
          showAppearanceSettingsSheet(
            context: context,
            isDarkMode: isDarkMode,
            onThemeChanged: onThemeChanged,
            isHighContrast: isHighContrast,
            onHighContrastChanged: onHighContrastChanged,
            textScaleFactor: textScaleFactor,
            onTextScaleChanged: onTextScaleChanged,
            selectedLanguage: selectedLanguage,
            onLanguageChanged: onLanguageChanged,
            subtitle: _tr(
              context,
              'Control contrast, font size, theme, and language for your account.',
              'تحكم في التباين وحجم الخط والثيم واللغة لحسابك.',
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.fingerprint_rounded,
        label: _tr(context, 'Biometric Lock', 'قفل البصمة'),
        subtitle: isBiometricLockEnabled
            ? _tr(
                context,
                'Enabled on this device for your saved session',
                'مفعل على هذا الجهاز لجلسة الدخول المحفوظة',
              )
            : _tr(
                context,
                'Use fingerprint or device biometrics before opening the app',
                'استخدم البصمة أو التحقق الحيوي قبل فتح التطبيق',
              ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => BiometricLockScreen(
                isEnabled: isBiometricLockEnabled,
                onChanged: onBiometricLockChanged,
              ),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.local_offer_outlined,
        label: _tr(context, 'Available Coupons', 'الكوبونات المتاحة'),
        subtitle: customerCoupons.isEmpty
            ? _tr(
                context,
                'No active coupons available right now',
                'لا توجد كوبونات مفعلة حالياً',
              )
            : readyCouponsCount > 0
            ? _tr(
                context,
                '$readyCouponsCount coupon(s) ready to use',
                '$readyCouponsCount كوبون جاهز للاستخدام',
              )
            : _tr(
                context,
                '${customerCoupons.length} coupon(s) listed · check eligibility inside',
                '${customerCoupons.length} كوبون متاح · تحقق من الأهلية بالداخل',
              ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => AvailableCouponsScreen(
                coupons: customerCoupons,
                customerOrderCount: customerOrderCount,
                currentPlan: currentPlan,
              ),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.credit_card_rounded,
        label: _tr(context, 'Saved Cards', 'البطاقات المحفوظة'),
        subtitle: savedCards.isEmpty
            ? _tr(
                context,
                'Tap to add your first card',
                'اضغط لإضافة أول بطاقة',
              )
            : _tr(
                context,
                '${savedCards.length} card(s) saved',
                '${savedCards.length} بطاقة محفوظة',
              ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => SavedCardsScreen(
                savedCards: savedCards,
                onAddCard: onAddCard,
                onRemoveCard: onRemoveCard,
              ),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.shield_outlined,
        label: _tr(context, 'Privacy & Security', 'الخصوصية والأمان'),
        subtitle: _tr(
          context,
          'Basic guidance for account and AI usage',
          'إرشادات أساسية للحساب واستخدام الذكاء',
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const PrivacySecurityScreen(),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.logout_rounded,
        label: _tr(context, 'Log Out', 'تسجيل الخروج'),
        subtitle: _tr(context, 'Return to sign in', 'العودة إلى تسجيل الدخول'),
        danger: true,
        onTap: () {
          unawaited(_confirmLogoutRequested(context, onLogout));
        },
      ),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Text(
            _tr(context, 'Settings', 'الإعدادات'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppPalette.primary.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _AppImage(
                      imagePath: user.avatarPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: AppPalette.mutedForeground),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user.city} · ${user.phone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget statusSummary = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'User Side Status',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      userStatusText,
                      style: TextStyle(color: AppPalette.mutedForeground),
                    ),
                  ],
                );
                final Widget savedCardsBadge = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.secondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${savedCards.length} card(s)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                );

                if (constraints.maxWidth < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      statusSummary,
                      const SizedBox(height: 12),
                      savedCardsBadge,
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    Expanded(child: statusSummary),
                    const SizedBox(width: 12),
                    savedCardsBadge,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 18),
          for (final _SettingsItem item in items) ...<Widget>[
            _SettingsTile(item: item),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class AvailableCouponsScreen extends StatelessWidget {
  const AvailableCouponsScreen({
    super.key,
    required this.coupons,
    required this.customerOrderCount,
    this.currentPlan,
  });

  final List<PromoCouponRecord> coupons;
  final int customerOrderCount;
  final SubscriptionPlan? currentPlan;

  String _formatCouponDate(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  String _discountLabel(BuildContext context, PromoCouponRecord coupon) {
    final List<String> parts = <String>[
      _tr(
        context,
        '${coupon.discountPercent}% off',
        'خصم ${coupon.discountPercent}%',
      ),
    ];
    if (coupon.hasMinimumOrder) {
      parts.add(
        _tr(
          context,
          'Min order ${formatBhd(coupon.minOrderAmountBhd!)}',
          'الحد الأدنى ${formatBhd(coupon.minOrderAmountBhd!)}',
        ),
      );
    }
    if (coupon.hasMaxDiscount) {
      parts.add(
        _tr(
          context,
          'Max ${formatBhd(coupon.maxDiscountBhd!)}',
          'الحد الأقصى ${formatBhd(coupon.maxDiscountBhd!)}',
        ),
      );
    }
    return parts.join(' · ');
  }

  String _planLabel(BuildContext context, PromoCouponRecord coupon) {
    if (coupon.appliesToAllPlans) {
      return _tr(
        context,
        'All users can use this code.',
        'هذا الكود متاح لجميع المستخدمين.',
      );
    }
    final String planName =
        coupon.targetPlan?.localizedName(context) ?? coupon.targetPlanId ?? '';
    return _tr(
      context,
      '$planName plan subscribers only.',
      'هذا الكود مخصص فقط لمشتركي باقة $planName.',
    );
  }

  String _scheduleLabel(BuildContext context, PromoCouponRecord coupon) {
    if (!coupon.hasSchedule) {
      return _tr(
        context,
        'Available now until the admin disables it.',
        'متاح الآن حتى يقوم المشرف بإيقافه.',
      );
    }
    if (coupon.startsAt != null && coupon.endsAt != null) {
      return '${_formatCouponDate(coupon.startsAt!)} to ${_formatCouponDate(coupon.endsAt!)}';
    }
    if (coupon.startsAt != null) {
      return _tr(
        context,
        'Starts on ${_formatCouponDate(coupon.startsAt!)}',
        'يبدأ في ${_formatCouponDate(coupon.startsAt!)}',
      );
    }
    return _tr(
      context,
      'Ends on ${_formatCouponDate(coupon.endsAt!)}',
      'ينتهي في ${_formatCouponDate(coupon.endsAt!)}',
    );
  }

  bool _isCouponReady(PromoCouponRecord coupon) {
    return coupon.isEligibleForOrderCount(customerOrderCount);
  }

  String _statusLabel(BuildContext context, PromoCouponRecord coupon) {
    return _isCouponReady(coupon)
        ? _tr(context, 'Available', 'متاح')
        : _tr(context, 'Ended', 'منتهي');
  }

  Color _statusBackground(PromoCouponRecord coupon) {
    return _isCouponReady(coupon)
        ? AppPalette.success.withValues(alpha: 0.18)
        : AppPalette.border;
  }

  Color _statusForeground(PromoCouponRecord coupon) {
    return _isCouponReady(coupon)
        ? AppPalette.success
        : AppPalette.mutedForeground;
  }

  String _usageLabel(BuildContext context, PromoCouponRecord coupon) {
    if (coupon.isWelcomeFirstOrderCoupon && customerOrderCount > 0) {
      return _tr(
        context,
        'Fresh20% welcome coupon has ended because this account already has orders.',
        'انتهت أهلية كوبون FRESH20 الترحيبي لأن هذا الحساب لديه طلبات سابقة.',
      );
    }
    return _tr(
      context,
      'Apply this code during checkout to receive the discount.',
      'استخدم هذا الكود أثناء الدفع للحصول على الخصم.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PromoCouponRecord> visibleCoupons =
        List<PromoCouponRecord>.from(coupons)
          ..sort((PromoCouponRecord a, PromoCouponRecord b) {
            final DateTime aDate =
                a.endsAt ?? a.updatedAt ?? a.createdAt ?? DateTime(9999);
            final DateTime bDate =
                b.endsAt ?? b.updatedAt ?? b.createdAt ?? DateTime(9999);
            return aDate.compareTo(bDate);
          });
    final int readyCouponsCount = visibleCoupons
        .where((PromoCouponRecord coupon) => _isCouponReady(coupon))
        .length;

    return AppViewport(
      child: SizedBox.expand(
        child: Scaffold(
          appBar: AppBar(
            title: Text(_tr(context, 'Available Coupons', 'الكوبونات المتاحة')),
          ),
          body: visibleCoupons.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: _EmptyStateCard(
                    icon: Icons.local_offer_outlined,
                    title: _tr(
                      context,
                      'No coupons available',
                      'لا توجد كوبونات متاحة',
                    ),
                    message: _tr(
                      context,
                      'Active coupons added by the admin will appear here when they match your account and are ready to use.',
                      'ستظهر هنا الكوبونات المفعلة من الإدارة عندما تطابق حسابك وتكون جاهزة للاستخدام.',
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: appCardDecoration(),
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final Widget summaryText = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _tr(
                                  context,
                                  'Coupons Ready For You',
                                  'كوبونات جاهزة لك',
                                ),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                readyCouponsCount > 0
                                    ? currentPlan == null
                                          ? _tr(
                                              context,
                                              'Showing active offers available for all users.',
                                              'نعرض العروض المفعلة المتاحة لجميع المستخدمين.',
                                            )
                                          : _tr(
                                              context,
                                              'Showing active offers for all users and the ${currentPlan!.localizedName(context)} plan.',
                                              'نعرض العروض المفعلة لجميع المستخدمين ولمشتركي باقة ${currentPlan!.localizedName(context)}.',
                                            )
                                    : _tr(
                                        context,
                                        'The coupons below may still depend on account eligibility, timing, or order conditions.',
                                        'قد تعتمد الكوبونات بالأسفل على أهلية الحساب أو التوقيت أو شروط الطلب.',
                                      ),
                                style: TextStyle(
                                  color: AppPalette.mutedForeground,
                                ),
                              ),
                            ],
                          );
                          final Widget readyBadge = Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.secondary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _tr(
                                  context,
                                  '$readyCouponsCount ready',
                                  '$readyCouponsCount جاهز',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );

                          if (constraints.maxWidth < 360) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                summaryText,
                                const SizedBox(height: 12),
                                readyBadge,
                              ],
                            );
                          }

                          return Row(
                            children: <Widget>[
                              Expanded(child: summaryText),
                              const SizedBox(width: 12),
                              readyBadge,
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final PromoCouponRecord coupon
                        in visibleCoupons) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: appCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            LayoutBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    BoxConstraints constraints,
                                  ) {
                                    final Widget couponSummary = Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          coupon.normalizedCode,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _discountLabel(context, coupon),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppPalette.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    );
                                    final Widget statusChip = Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusBackground(coupon),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        _statusLabel(context, coupon),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _statusForeground(coupon),
                                        ),
                                      ),
                                    );
                                    final Widget
                                    copyButton = OutlinedButton.icon(
                                      onPressed: _isCouponReady(coupon)
                                          ? () => _copyToClipboard(
                                              context,
                                              coupon.normalizedCode,
                                              _tr(
                                                context,
                                                '${coupon.normalizedCode} copied to clipboard.',
                                                'تم نسخ ${coupon.normalizedCode} إلى الحافظة.',
                                              ),
                                            )
                                          : null,
                                      icon: const Icon(
                                        Icons.copy_all_rounded,
                                        size: 18,
                                      ),
                                      label: Text(_tr(context, 'Copy', 'نسخ')),
                                    );

                                    if (constraints.maxWidth < 360) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          couponSummary,
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: <Widget>[
                                              statusChip,
                                              copyButton,
                                            ],
                                          ),
                                        ],
                                      );
                                    }

                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Expanded(child: couponSummary),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: <Widget>[
                                            statusChip,
                                            const SizedBox(height: 10),
                                            copyButton,
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                            ),
                            if ((coupon.localizedDescription(context) ?? '')
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                coupon.localizedDescription(context)!.trim(),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AppPalette.mutedForeground,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            _AccountInfoRow(
                              label: _tr(context, 'Who', 'لمن'),
                              value: _planLabel(context, coupon),
                            ),
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: _tr(context, 'When', 'متى'),
                              value: _scheduleLabel(context, coupon),
                            ),
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: _tr(context, 'Use', 'الاستخدام'),
                              value: _usageLabel(context, coupon),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({
    super.key,
    required this.user,
    required this.platformRepository,
    required this.onUserChanged,
    this.autoStartEmailVerification = false,
  });

  final AppUser user;
  final PlatformRepository platformRepository;
  final ValueChanged<AppUser> onUserChanged;
  final bool autoStartEmailVerification;

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();
  late AppUser _currentUser = widget.user;
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user.name,
  );
  late final TextEditingController _phoneController = TextEditingController(
    text:
        normalizeBahrainPhone(widget.user.phone, allowEmpty: true) ??
        widget.user.phone.trim(),
  );
  late final TextEditingController _cityController = TextEditingController(
    text: normalizeBahrainLocation(widget.user.city),
  );
  late final TextEditingController _addressController = TextEditingController(
    text: widget.user.address,
  );
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  late String _avatarPath = widget.user.avatarPath;
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  bool _isChangingPassword = false;
  bool _isSendingEmailVerificationCode = false;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartEmailVerification && !_currentUser.isEmailVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _currentUser.isEmailVerified) {
          return;
        }
        _startEmailVerificationFlow();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    setState(() => _isUploadingAvatar = true);
    try {
      final String? avatarPath = await widget.platformRepository
          .pickAndUploadProfileImage(
            profileKey: _currentUser.profileId ?? _currentUser.email,
          );
      if (!mounted || avatarPath == null || avatarPath.trim().isEmpty) {
        return;
      }
      setState(() => _avatarPath = avatarPath);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(
      _phoneController.text,
    );
    setState(() => _isSavingProfile = true);
    try {
      final AppUser updated = await widget.platformRepository.updateProfile(
        user: _currentUser,
        name: _nameController.text.trim(),
        phone: normalizedPhone,
        city: normalizeBahrainLocation(_cityController.text),
        address: _addressController.text.trim(),
        avatarPath: _avatarPath,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUser = updated;
        _avatarPath = updated.avatarPath;
        _nameController.text = updated.name;
        _phoneController.text =
            normalizeBahrainPhone(updated.phone, allowEmpty: true) ??
            updated.phone;
        _cityController.text = normalizeBahrainLocation(updated.city);
        _addressController.text = updated.address;
      });
      widget.onUserChanged(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account details updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isChangingPassword = true);
    try {
      await widget.platformRepository.changePassword(
        user: _currentUser,
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  Future<void> _startEmailVerificationFlow() async {
    setState(() => _isSendingEmailVerificationCode = true);
    try {
      AuthOtpDispatchResult dispatchResult = const AuthOtpDispatchResult();
      Object? dispatchError;
      try {
        dispatchResult = await widget.platformRepository.sendEmailVerificationCode(
          email: _currentUser.email,
        );
      } catch (error) {
        final String rawMessage =
            error.toString().replaceFirst('Bad state: ', '').trim();
        if (_isOtpRateLimitMessage(rawMessage)) {
          dispatchError = error;
        } else {
          rethrow;
        }
      }
      if (!mounted) {
        return;
      }
      if (dispatchError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_presentableOtpError(context, dispatchError))),
        );
        return;
      }

      final AppUser? verifiedUser = await Navigator.of(context).push<AppUser>(
        MaterialPageRoute<AppUser>(
          builder: (BuildContext context) => EmailVerificationPendingScreen(
            email: _currentUser.email,
            initialDispatchResult: dispatchResult,
            onVerifyCode: (String code) {
              return widget.platformRepository.verifyEmailAddressCode(
                email: _currentUser.email,
                code: code,
              );
            },
            onContinue: () {
              return widget.platformRepository.refreshUser(user: _currentUser);
            },
          ),
        ),
      );
      if (!mounted || verifiedUser == null) {
        return;
      }

      if (!verifiedUser.isEmailVerified) {
        throw StateError(
          _tr(
            context,
            'Freshline has not confirmed your email yet. Open the email link or enter the 6-digit code, then try again.',
            'لم يؤكد فريش لاين بريدك الإلكتروني بعد. افتح رابط البريد أو أدخل الرمز المكوّن من 6 أرقام ثم حاول مرة أخرى.',
          ),
        );
      }

      final AppUser updatedUser = verifiedUser.copyWith(
        preferredLanguage: _currentUser.preferredLanguage,
        isEmailTwoFactorEnabled: _currentUser.isEmailTwoFactorEnabled,
      );
      setState(() => _currentUser = updatedUser);
      widget.onUserChanged(updatedUser);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Your email was verified successfully.',
              'تم التحقق من بريدك الإلكتروني بنجاح.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingEmailVerificationCode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Account Details')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Stack(
                    children: <Widget>[
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppPalette.primary.withValues(alpha: 0.22),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _AppImage(
                            imagePath: _avatarPath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: _isUploadingAvatar ? null : _changeAvatar,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppPalette.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppPalette.white),
                              ),
                              child: Icon(
                                _isUploadingAvatar
                                    ? Icons.hourglass_top_rounded
                                    : Icons.edit_rounded,
                                size: 16,
                                color: AppPalette.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _nameController.text.trim().isEmpty
                              ? _tr(
                                  context,
                                  'FreshLine User',
                                  'مستخدم فريش لاين',
                                )
                              : _nameController.text.trim(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _currentUser.email,
                          style: TextStyle(color: AppPalette.mutedForeground),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isUploadingAvatar ? null : _changeAvatar,
                          icon: Icon(
                            _isUploadingAvatar
                                ? Icons.hourglass_top_rounded
                                : Icons.upload_outlined,
                          ),
                          label: Text(
                            _isUploadingAvatar
                                ? _tr(context, 'Uploading...', 'جارٍ الرفع...')
                                : _tr(context, 'Change Photo', 'تغيير الصورة'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isUploadingAvatar
                              ? null
                              : () {
                                  setState(
                                    () => _avatarPath =
                                        currentDefaultProfileImageUrl(),
                                  );
                                },
                          child: Text(
                            _tr(
                              context,
                              'Use Default Photo',
                              'استخدام الصورة الافتراضية',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Text(
                _tr(
                  context,
                  'You can update your username, phone number, city, address, and profile photo here. Email stays locked to your account.',
                  'يمكنك تحديث اسم المستخدم ورقم الهاتف والمدينة والعنوان وصورة الملف الشخصي من هنا. يبقى البريد الإلكتروني مرتبطاً بحسابك ولا يتغير.',
                ),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppPalette.mutedForeground,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tr(
                      context,
                      'Email Verification',
                      'تأكيد البريد الإلكتروني',
                    ),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentUser.isEmailVerified
                        ? _tr(
                            context,
                            'Your account email is already confirmed.',
                            'تم تأكيد البريد الإلكتروني لهذا الحساب بالفعل.',
                          )
                        : _tr(
                            context,
                            'Your account is already active. When you are ready, we will send a 6-digit code to ${_maskEmailAddress(_currentUser.email)} so you can confirm the email later.',
                            'حسابك نشط بالفعل. عندما تكون جاهزاً سنرسل رمزاً من 6 أرقام إلى ${_maskEmailAddress(_currentUser.email)} حتى تتمكن من تأكيد البريد لاحقاً.',
                          ),
                    style: TextStyle(
                      color: AppPalette.mutedForeground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AccountInfoRow(
                    label: _tr(context, 'Status', 'الحالة'),
                    value: _currentUser.isEmailVerified
                        ? _tr(context, 'Verified', 'تم التحقق')
                        : _tr(
                            context,
                            'Pending Verification',
                            'بانتظار التحقق',
                          ),
                  ),
                  if (!_currentUser.isEmailVerified) ...<Widget>[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSendingEmailVerificationCode
                            ? null
                            : _startEmailVerificationFlow,
                        child: Text(
                          _isSendingEmailVerificationCode
                              ? _tr(
                                  context,
                                  'Sending Verification Code...',
                                  'جارٍ إرسال رمز التحقق...',
                                )
                              : _tr(
                                  context,
                                  'Verify Email With Code',
                                  'تحقق من البريد بالرمز',
                                ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Form(
                key: _profileFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tr(context, 'Profile Details', 'تفاصيل الملف الشخصي'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _nameController,
                      label: _tr(context, 'Username', 'اسم المستخدم'),
                      validator: _requiredField,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _AccountInfoRow(
                      label: _tr(context, 'Email', 'البريد الإلكتروني'),
                      value: _currentUser.email,
                    ),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _phoneController,
                      label: _tr(context, 'Phone', 'الهاتف'),
                      keyboardType: TextInputType.phone,
                      validator: validateRequiredBahrainPhone,
                      inputFormatters: bahrainPhoneInputFormatters,
                    ),
                    const SizedBox(height: 14),
                    _BahrainLocationDropdownField(
                      controller: _cityController,
                      label: _tr(context, 'City', 'المدينة'),
                      validator: _requiredField,
                    ),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _addressController,
                      label: _tr(context, 'Address', 'العنوان'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSavingProfile ? null : _saveProfile,
                        child: Text(
                          _isSavingProfile
                              ? _tr(
                                  context,
                                  'Saving Changes...',
                                  'جارٍ حفظ التغييرات...',
                                )
                              : _tr(context, 'Save Changes', 'حفظ التغييرات'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tr(context, 'Change Password', 'تغيير كلمة المرور'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _currentPasswordController,
                      label: _tr(
                        context,
                        'Current Password',
                        'كلمة المرور الحالية',
                      ),
                      obscureText: _hideCurrentPassword,
                      validator: _passwordValidator,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(
                            () => _hideCurrentPassword = !_hideCurrentPassword,
                          );
                        },
                        icon: Icon(
                          _passwordVisibilityIcon(_hideCurrentPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _newPasswordController,
                      label: _tr(
                        context,
                        'New Password',
                        'كلمة المرور الجديدة',
                      ),
                      obscureText: _hideNewPassword,
                      validator: _passwordValidator,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _hideNewPassword = !_hideNewPassword);
                        },
                        icon: Icon(_passwordVisibilityIcon(_hideNewPassword)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _confirmPasswordController,
                      label: _tr(
                        context,
                        'Confirm New Password',
                        'تأكيد كلمة المرور الجديدة',
                      ),
                      obscureText: _hideConfirmPassword,
                      validator: (String? value) {
                        if ((value ?? '').trim().isEmpty) {
                          return _tr(
                            context,
                            'This field is required.',
                            'هذا الحقل مطلوب.',
                          );
                        }
                        if (value != _newPasswordController.text) {
                          return _tr(
                            context,
                            'Passwords do not match.',
                            'كلمتا المرور غير متطابقتين.',
                          );
                        }
                        return null;
                      },
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(
                            () => _hideConfirmPassword = !_hideConfirmPassword,
                          );
                        },
                        icon: Icon(
                          _passwordVisibilityIcon(_hideConfirmPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isChangingPassword ? null : _changePassword,
                        child: Text(
                          _isChangingPassword
                              ? _tr(
                                  context,
                                  'Updating Password...',
                                  'جارٍ تحديث كلمة المرور...',
                                )
                              : _tr(
                                  context,
                                  'Change Password',
                                  'تغيير كلمة المرور',
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredField(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return _tr(context, 'This field is required.', 'هذا الحقل مطلوب.');
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if ((value ?? '').trim().length < 6) {
      return _tr(
        context,
        'Use at least 6 characters.',
        'استخدم 6 أحرف على الأقل.',
      );
    }
    return null;
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key, this.role = AppRole.customer});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Help & Support', 'المساعدة والدعم')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tr(context, 'Need help?', 'تحتاج مساعدة؟'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _helpSupportIntroForRole(context, role),
                    style: TextStyle(color: AppPalette.mutedForeground),
                  ),
                  const SizedBox(height: 18),
                  _SettingsTile(
                    item: _SettingsItem(
                      icon: Icons.question_answer_outlined,
                      label: _tr(context, 'FAQ', 'الأسئلة الشائعة'),
                      subtitle: _faqSubtitleForRole(context, role),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                FaqScreen(role: role),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    item: _SettingsItem(
                      icon: Icons.alternate_email_rounded,
                      label: _tr(context, 'Contact Us', 'تواصل معنا'),
                      subtitle: _tr(
                        context,
                        'Phone, email, WhatsApp, and social media',
                        'الهاتف والبريد وواتساب ووسائل التواصل الاجتماعي',
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                ContactUsScreen(role: role),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmailTwoFactorScreen extends StatefulWidget {
  const EmailTwoFactorScreen({
    super.key,
    required this.user,
    required this.platformRepository,
  });

  final AppUser user;
  final PlatformRepository platformRepository;

  @override
  State<EmailTwoFactorScreen> createState() => _EmailTwoFactorScreenState();
}

class _EmailTwoFactorScreenState extends State<EmailTwoFactorScreen> {
  late AppUser _currentUser = widget.user;
  bool _isSendingCode = false;
  bool _isUpdating = false;

  Future<void> _startEnableFlow() async {
    setState(() => _isSendingCode = true);
    try {
      final AuthOtpDispatchResult dispatchResult =
          await widget.platformRepository.sendEmailTwoFactorSetupCode(
        user: _currentUser,
      );
      if (!mounted) {
        return;
      }
      final AppUser? updatedUser = await Navigator.of(context).push<AppUser>(
        MaterialPageRoute<AppUser>(
          builder: (BuildContext context) => OtpChallengeScreen<AppUser>(
            email: _currentUser.email,
            initialDispatchResult: dispatchResult,
            title: _tr(context, 'Enable Email 2FA', 'تفعيل التحقق بخطوتين'),
            subtitle: _tr(
              context,
              'Enter the 6-digit code sent to ${_maskEmailAddress(_currentUser.email)}. Once verified, email 2FA will be enabled for future sign-ins.',
              'أدخل الرمز المكوّن من 6 أرقام المرسل إلى ${_maskEmailAddress(_currentUser.email)}. بعد التحقق سيتم تفعيل التحقق بخطوتين لعمليات الدخول القادمة.',
            ),
            primaryActionLabel: _tr(
              context,
              'Verify And Enable 2FA',
              'تحقق وفعّل التحقق بخطوتين',
            ),
            resendSuccessMessage: _tr(
              context,
              'A new 2FA setup code was sent to your email.',
              'تم إرسال رمز إعداد جديد للتحقق بخطوتين إلى بريدك الإلكتروني.',
            ),
            onVerify: (String code) {
              return widget.platformRepository.enableEmailTwoFactor(
                user: _currentUser,
                code: code,
              );
            },
            onResend: () {
              return widget.platformRepository.sendEmailTwoFactorSetupCode(
                user: _currentUser,
              );
            },
          ),
        ),
      );
      if (!mounted || updatedUser == null) {
        return;
      }
      setState(() => _currentUser = updatedUser);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Email two-factor authentication is now enabled.',
              'تم تفعيل التحقق بخطوتين عبر البريد الإلكتروني.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  Future<void> _disableEmailTwoFactor() async {
    setState(() => _isUpdating = true);
    try {
      final AppUser updated = await widget.platformRepository
          .disableEmailTwoFactor(user: _currentUser);
      if (!mounted) {
        return;
      }
      setState(() => _currentUser = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Email two-factor authentication was turned off.',
              'تم إيقاف التحقق بخطوتين عبر البريد الإلكتروني.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Email 2FA', 'التحقق بخطوتين عبر البريد')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _currentUser.isEmailTwoFactorEnabled
                        ? _tr(context, '2FA Is Active', 'التحقق بخطوتين مفعّل')
                        : _tr(
                            context,
                            'Protect Your Sign-In',
                            'احمِ تسجيل الدخول',
                          ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _currentUser.isEmailTwoFactorEnabled
                        ? _tr(
                            context,
                            'Freshline currently requires a 6-digit email code every time this account signs in.',
                            'يتطلب فريش لاين حالياً رمز بريد إلكتروني من 6 أرقام في كل مرة يسجل فيها هذا الحساب الدخول.',
                          )
                        : _tr(
                            context,
                            'We will send a 6-digit code to ${_maskEmailAddress(_currentUser.email)}. After you verify it on the next screen, email 2FA will be enabled.',
                            'سنرسل رمزاً من 6 أرقام إلى ${_maskEmailAddress(_currentUser.email)}. بعد التحقق منه في الشاشة التالية سيتم تفعيل التحقق بخطوتين.',
                          ),
                    style: TextStyle(
                      color: AppPalette.mutedForeground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AccountInfoRow(
                    label: _tr(context, 'Email', 'البريد الإلكتروني'),
                    value: _currentUser.email,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: _currentUser.isEmailTwoFactorEnabled
                        ? OutlinedButton(
                            onPressed: _isUpdating
                                ? null
                                : _disableEmailTwoFactor,
                            child: Text(
                              _isUpdating
                                  ? _tr(
                                      context,
                                      'Updating Security...',
                                      'جارٍ تحديث الأمان...',
                                    )
                                  : _tr(
                                      context,
                                      'Turn Off Email 2FA',
                                      'إيقاف التحقق بخطوتين',
                                    ),
                            ),
                          )
                        : FilledButton(
                            onPressed: _isSendingCode ? null : _startEnableFlow,
                            child: Text(
                              _isSendingCode
                                  ? _tr(
                                      context,
                                      'Sending Verification Code...',
                                      'جارٍ إرسال رمز التحقق...',
                                    )
                                  : _tr(
                                      context,
                                      'Send Code And Continue',
                                      'أرسل الرمز وتابع',
                                    ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({
    super.key,
    required this.savedCards,
    required this.onAddCard,
    required this.onRemoveCard,
  });

  final List<PaymentCardInfo> savedCards;
  final Future<PaymentCardInfo?> Function(String title) onAddCard;
  final Future<void> Function(PaymentCardInfo card) onRemoveCard;

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  late final List<PaymentCardInfo> _cards;
  final Set<String> _removingCardIds = <String>{};

  @override
  void initState() {
    super.initState();
    _cards = List<PaymentCardInfo>.from(widget.savedCards);
  }

  Future<void> _addCard() async {
    final PaymentCardInfo? card = await widget.onAddCard(
      _tr(context, 'Add New Card', 'أضف بطاقة جديدة'),
    );
    if (!mounted || card == null) {
      return;
    }

    setState(() {
      _cards.removeWhere((PaymentCardInfo item) => item.id == card.id);
      _cards.insert(0, card);
    });
  }

  Future<void> _removeCard(PaymentCardInfo card) async {
    final bool shouldDelete = await _showActionConfirmationDialog(
      context: context,
      title: _tr(context, 'Delete Saved Card', 'حذف البطاقة المحفوظة'),
      message: _tr(
        context,
        'Are you sure you want to delete this card?',
        'هل أنت متأكد أنك تريد حذف هذه البطاقة؟',
      ),
      confirmLabel: _tr(context, 'Delete', 'حذف'),
      isDestructive: true,
    );
    if (!shouldDelete || !mounted) {
      return;
    }

    setState(() => _removingCardIds.add(card.id));
    try {
      await widget.onRemoveCard(card);
      if (!mounted) {
        return;
      }
      setState(() {
        _cards.removeWhere((PaymentCardInfo item) => item.id == card.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              '${card.displayLabel} was deleted.',
              'تم حذف ${card.displayLabel}.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _removingCardIds.remove(card.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Saved Cards', 'البطاقات المحفوظة')),
          actions: <Widget>[
            IconButton(
              onPressed: _addCard,
              icon: const Icon(Icons.add_card_rounded),
              tooltip: _tr(context, 'Add Card', 'أضف بطاقة'),
            ),
          ],
        ),
        body: _cards.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _EmptyStateCard(
                  icon: Icons.credit_card_off_outlined,
                  title: _tr(
                    context,
                    'No saved cards yet',
                    'لا توجد بطاقات محفوظة بعد',
                  ),
                  message: _tr(
                    context,
                    'Add your first payment card from here and use it later for subscriptions or bookings.',
                    'أضف أول بطاقة دفع من هنا واستخدمها لاحقاً للاشتراكات أو الحجوزات.',
                  ),
                  actionLabel: _tr(context, 'Add Card', 'أضف بطاقة'),
                  onAction: _addCard,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addCard,
                      icon: const Icon(Icons.add_card_rounded),
                      label: Text(
                        _tr(context, 'Add Another Card', 'أضف بطاقة أخرى'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._cards.asMap().entries.map((
                    MapEntry<int, PaymentCardInfo> entry,
                  ) {
                    final PaymentCardInfo card = entry.value;
                    final bool isPrimary = entry.key == 0;
                    final bool isRemoving = _removingCardIds.contains(card.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: appCardDecoration(),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppPalette.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.credit_card_rounded,
                                color: AppPalette.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          card.displayLabel,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (isPrimary)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppPalette.secondary,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            _tr(context, 'Default', 'افتراضي'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${card.holderName} · ${card.expiryLabel}',
                                    style: TextStyle(
                                      color: AppPalette.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: isRemoving
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : IconButton(
                                      onPressed: () => _removeCard(card),
                                      tooltip: _tr(
                                        context,
                                        'Delete Card',
                                        'حذف البطاقة',
                                      ),
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red.shade600,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key, this.role = AppRole.customer});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final List<SupportTopic> topics = _localizedSupportTopics(context, role);
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(_tr(context, 'FAQ', 'الأسئلة الشائعة'))),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: topics.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int index) {
            final SupportTopic topic = topics[index];
            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: AppPalette.card,
              collapsedBackgroundColor: AppPalette.card,
              title: Text(
                topic.question,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              children: <Widget>[
                Align(
                  alignment: _isArabicContext(context)
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    topic.answer,
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key, this.role = AppRole.customer});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(_tr(context, 'Contact Us', 'تواصل معنا'))),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: appCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _contactUsHeaderForRole(context, role),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _contactUsDescriptionForRole(context, role),
                        style: TextStyle(
                          height: 1.45,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AccountInfoRow(
                        label: _tr(context, 'Hours', 'ساعات العمل'),
                        value: _localizedDisplayText(context, supportHours),
                      ),
                      const SizedBox(height: 12),
                      _AccountInfoRow(
                        label: _tr(context, 'Address', 'العنوان'),
                        value: _localizedDisplayText(context, supportAddress),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _launchUri(
                            context,
                            Uri.parse(supportWhatsAppUrl),
                            _tr(
                              context,
                              'Could not open WhatsApp.',
                              'تعذر فتح واتساب.',
                            ),
                            fallbackClipboardValue: supportWhatsAppUrl,
                            fallbackConfirmation: _tr(
                              context,
                              'WhatsApp link copied to clipboard.',
                              'تم نسخ رابط واتساب إلى الحافظة.',
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: Text(
                            _tr(context, 'Open WhatsApp', 'افتح واتساب'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            context,
                            _localizedDisplayText(context, supportAddress),
                            _tr(
                              context,
                              'Support address copied to clipboard.',
                              'تم نسخ عنوان الدعم إلى الحافظة.',
                            ),
                          ),
                          icon: const Icon(Icons.copy_rounded),
                          label: Text(
                            _tr(context, 'Copy Address', 'انسخ العنوان'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ContactActionPanel(
                  icon: Icons.call_rounded,
                  title: _tr(context, 'Phone Support', 'الدعم الهاتفي'),
                  value: supportPhoneDisplay,
                  actionLabel: _tr(context, 'Call Now', 'اتصل الآن'),
                  onAction: () => _launchUri(
                    context,
                    Uri(scheme: 'tel', path: supportPhoneUri),
                    _tr(
                      context,
                      'Could not open the phone app.',
                      'تعذر فتح تطبيق الهاتف.',
                    ),
                    fallbackClipboardValue: supportPhoneDisplay,
                    fallbackConfirmation: _tr(
                      context,
                      'Phone number copied to clipboard.',
                      'تم نسخ رقم الهاتف إلى الحافظة.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ContactActionPanel(
                  icon: Icons.email_outlined,
                  title: _tr(context, 'Email Support', 'الدعم عبر البريد'),
                  value: supportEmail,
                  actionLabel: _tr(context, 'Send Email', 'أرسل بريدًا'),
                  onAction: () => _launchUri(
                    context,
                    Uri(scheme: 'mailto', path: supportEmail),
                    _tr(
                      context,
                      'Could not open the mail app.',
                      'تعذر فتح تطبيق البريد.',
                    ),
                    fallbackClipboardValue: supportEmail,
                    fallbackConfirmation: _tr(
                      context,
                      'Email copied to clipboard.',
                      'تم نسخ البريد الإلكتروني إلى الحافظة.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _tr(context, 'Social Media', 'وسائل التواصل الاجتماعي'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _tr(
                    context,
                    'Instagram, TikTok, X, and YouTube open directly from here.',
                    'يمكنك فتح إنستغرام وتيك توك وX ويوتيوب مباشرة من هنا.',
                  ),
                  style: TextStyle(color: AppPalette.mutedForeground),
                ),
                const SizedBox(height: 12),
                if (socialContacts.isEmpty)
                  _EmptyStateCard(
                    icon: Icons.alternate_email_rounded,
                    title: _tr(
                      context,
                      'No social channels yet',
                      'لا توجد قنوات اجتماعية بعد',
                    ),
                    message: _tr(
                      context,
                      'Freshline support details will appear here once contact channels are added.',
                      'ستظهر بيانات دعم فريش لاين هنا عند إضافة قنوات التواصل.',
                    ),
                    actionLabel: _tr(context, 'Copy Email', 'انسخ البريد'),
                    onAction: () => _copyToClipboard(
                      context,
                      supportEmail,
                      _tr(
                        context,
                        'Email copied to clipboard.',
                        'تم نسخ البريد الإلكتروني إلى الحافظة.',
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: socialContacts
                        .where(
                          (SocialContact contact) =>
                              contact.label.toLowerCase() != 'whatsapp',
                        )
                        .map(
                          (SocialContact contact) =>
                              _SocialIconLink(contact: contact),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const List<_PrivacyPoint> items = <_PrivacyPoint>[
      _PrivacyPoint(
        icon: Icons.lock_outline_rounded,
        title: 'Account Protection',
        description:
            'Keep your email, password, and saved account details secure and update them only from trusted devices.',
      ),
      _PrivacyPoint(
        icon: Icons.credit_card_outlined,
        title: 'Saved Cards & Payments',
        description:
            'Only payment-related card details should appear in your account, and payment confirmations should match your booking or order history.',
      ),
      _PrivacyPoint(
        icon: Icons.location_on_outlined,
        title: 'Location Access',
        description:
            'Location is used to show nearby salons, route navigation, and whether a barber is close to you.',
      ),
      _PrivacyPoint(
        icon: Icons.auto_awesome_outlined,
        title: 'AI & Support Usage',
        description:
            'AI answers should stay related to the app and barber services, while support links should open official Freshline channels only.',
      ),
    ];

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Privacy & Security', 'الخصوصية والأمان')),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: items.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int index) {
            final _PrivacyPoint item = items[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: appCardDecoration(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppPalette.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: AppPalette.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _localizedDisplayText(context, item.title),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _localizedDisplayText(context, item.description),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppPalette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({
    super.key,
    required this.isEnabled,
    required this.onChanged,
  });

  final bool isEnabled;
  final AsyncBoolCallback onChanged;

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  late bool _isEnabled = widget.isEnabled;
  bool _isSaving = false;

  Future<void> _toggle(bool value) async {
    setState(() => _isSaving = true);
    await widget.onChanged(value);
    if (!mounted) {
      return;
    }
    setState(() {
      _isEnabled = value;
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr(context, 'Biometric Lock', 'قفل البصمة')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tr(
                      context,
                      'Protect your saved session',
                      'احمِ جلستك المحفوظة',
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr(
                      context,
                      'When this option is enabled, Freshline asks for your fingerprint or device biometrics before opening your saved account on this device.',
                      'عند تفعيل هذا الخيار سيطلب فريش لاين بصمة الإصبع أو التحقق الحيوي للجهاز قبل فتح حسابك المحفوظ على هذا الجهاز.',
                    ),
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile.adaptive(
                    value: _isEnabled,
                    onChanged: _isSaving ? null : _toggle,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _tr(context, 'Enable biometric lock', 'تفعيل قفل البصمة'),
                    ),
                    subtitle: Text(
                      _isEnabled
                          ? _tr(
                              context,
                              'Biometric protection is on for this device.',
                              'الحماية بالبصمة مفعلة لهذا الجهاز.',
                            )
                          : _tr(
                              context,
                              'Your saved session opens without biometric confirmation.',
                              'جلسة الدخول المحفوظة تفتح حالياً بدون تحقق بالبصمة.',
                            ),
                    ),
                  ),
                  if (_isSaving) ...<Widget>[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BiometricUnlockScreen extends StatelessWidget {
  const BiometricUnlockScreen({
    super.key,
    required this.isUnlocking,
    required this.onUnlock,
    required this.onLogout,
  });

  final bool isUnlocking;
  final Future<void> Function() onUnlock;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: appCardDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppPalette.primary.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          size: 42,
                          color: AppPalette.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _tr(context, 'Unlock Freshline', 'افتح فريش لاين'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tr(
                          context,
                          'Use your fingerprint or device biometrics to continue to your saved session.',
                          'استخدم البصمة أو التحقق الحيوي للجهاز للمتابعة إلى جلستك المحفوظة.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1.45,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isUnlocking ? null : onUnlock,
                          icon: const Icon(Icons.lock_open_rounded),
                          label: Text(
                            _tr(
                              context,
                              'Unlock with biometrics',
                              'افتح بالبصمة',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isUnlocking ? null : onLogout,
                          child: Text(_tr(context, 'Log Out', 'تسجيل الخروج')),
                        ),
                      ),
                      if (isUnlocking) ...<Widget>[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _localizedDisplayText(context, title),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              child: Text(
                _tr(context, 'See all', 'عرض الكل'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: appCardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppPalette.primary),
          ),
          const SizedBox(height: 16),
          Text(
            _localizedDisplayText(context, title),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _localizedDisplayText(context, message),
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: AppPalette.mutedForeground),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAction,
                child: Text(_localizedDisplayText(context, actionLabel!)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppImage extends StatelessWidget {
  const _AppImage({
    required this.imagePath,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  final String imagePath;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: _appImageProvider(imagePath),
      height: height,
      width: width,
      fit: fit,
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return Image.asset(
              'assets/images/banner-1.jpg',
              height: height,
              width: width,
              fit: fit,
            );
          },
    );
  }
}

ImageProvider<Object> _appImageProvider(String imagePath) {
  if (imagePath.startsWith('data:')) {
    final Uint8List bytes = Uint8List.fromList(
      Uri.parse(imagePath).data?.contentAsBytes() ?? const <int>[],
    );
    if (bytes.isNotEmpty) {
      return MemoryImage(bytes);
    }
  }

  return imagePath.startsWith('http')
      ? NetworkImage(imagePath)
      : AssetImage(imagePath);
}

Future<bool> _showActionConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  bool isDestructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      ) ??
      false;
}

Future<void> _confirmLogoutRequested(
  BuildContext context,
  VoidCallback onLogout,
) async {
  final bool shouldLogout = await _showActionConfirmationDialog(
    context: context,
    title: 'Log Out',
    message: 'Are you sure you want to log out?',
    confirmLabel: 'Log Out',
  );
  if (!shouldLogout || !context.mounted) {
    return;
  }
  onLogout();
}

class _SalonCard extends StatelessWidget {
  const _SalonCard({required this.salon, required this.onTap});

  final Salon salon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: appCardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _AppImage(
              imagePath: salon.imagePath,
              height: 126,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    salon.localizedName(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${salon.localizedLocation(context)} · ${salon.distance}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: AppPalette.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${salon.rating}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${salon.reviews})',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onCartTap,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    final bool outOfStock = product.stock <= 0 || !product.isActive;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: appCardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _AppImage(
              imagePath: product.imagePath,
              height: 128,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.localizedName(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            product.localizedCategory(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppPalette.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '(${product.reviewsCount})',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppPalette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            formatBhd(product.price),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: outOfStock ? null : onCartTap,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: outOfStock
                                  ? AppPalette.mutedForeground
                                  : AppPalette.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_cart_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack, this.subtitle});

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: <Widget>[
          _RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _localizedDisplayText(context, title),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    _localizedDisplayText(context, subtitle!),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.translucent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: translucent
              ? AppPalette.background.withValues(alpha: 0.82)
              : AppPalette.secondary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, size: 18, color: AppPalette.foreground),
        ),
      ),
    );
  }
}

class CustomerReviewsScreen extends StatelessWidget {
  const CustomerReviewsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.reviewsFuture,
  });

  final String title;
  final String subtitle;
  final Future<List<CustomerRatingReview>> reviewsFuture;

  String _formatDate(DateTime date) {
    final DateTime local = date.toLocal();
    final String y = local.year.toString().padLeft(4, '0');
    final String m = local.month.toString().padLeft(2, '0');
    final String d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: FutureBuilder<List<CustomerRatingReview>>(
          future: reviewsFuture,
          builder: (BuildContext context,
              AsyncSnapshot<List<CustomerRatingReview>> snapshot) {
            final List<CustomerRatingReview> reviews = snapshot.data ?? const [];
            if (snapshot.connectionState == ConnectionState.waiting &&
                reviews.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.error.toString().replaceFirst('Bad state: ', ''),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (reviews.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _tr(
                      context,
                      'No reviews yet.',
                      'لا توجد تقييمات بعد.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppPalette.mutedForeground),
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: appCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppPalette.mutedForeground,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...reviews.map((CustomerRatingReview review) {
                  final String maskedName = _maskPersonName(review.reviewerName);
                  final String comment = review.comment.trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: appCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  maskedName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDate(review.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: List<Widget>.generate(5, (int index) {
                              final int starValue = index + 1;
                              return Icon(
                                starValue <= review.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline,
                                size: 18,
                                color: AppPalette.primary,
                              );
                            }),
                          ),
                          if (comment.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            Text(
                              comment,
                              style: TextStyle(height: 1.45),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: AppPalette.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: onTap == null ? null : TextDecoration.underline,
            decorationColor: Colors.white.withValues(alpha: 0.7),
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
    final VoidCallback? handler = onTap;
    if (handler == null) {
      return content;
    }
    return InkWell(
      onTap: handler,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: content,
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppPalette.card : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.shadow,
                    blurRadius: 16,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? AppPalette.primary : AppPalette.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.price,
    this.selected = false,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final String duration;
  final num price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: appCardDecoration(
          border: Border.all(
            color: selected ? AppPalette.primary : AppPalette.border,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? AppPalette.primary.withValues(alpha: 0.04)
              : AppPalette.card,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _localizedDisplayText(context, title),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      _localizedDisplayText(context, subtitle!),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AppPalette.mutedForeground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _localizedDisplayText(context, duration),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  formatBhd(price),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  size: 22,
                  color: selected
                      ? AppPalette.primary
                      : AppPalette.mutedForeground,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonProductRowCard extends StatelessWidget {
  const _SalonProductRowCard({
    required this.product,
    required this.inCart,
    required this.onTap,
    required this.onAddToCart,
  });

  final Product product;
  final bool inCart;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final bool outOfStock = product.stock <= 0;
    final String description = product.localizedDescription(context).trim();

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: appCardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _AppImage(
                imagePath: product.imagePath,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          product.localizedName(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (inCart)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _localizedDisplayText(context, 'In Cart'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.localizedCategory(context),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.primary,
                    ),
                  ),
                  if (description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _ProductStatPill(
                        icon: Icons.sell_outlined,
                        label: formatBhd(product.price),
                        emphasize: true,
                      ),
                      _ProductStatPill(
                        icon: outOfStock
                            ? Icons.block_rounded
                            : Icons.inventory_2_outlined,
                        label: outOfStock
                            ? _localizedDisplayText(context, 'Out of stock')
                            : _tr(
                                context,
                                'Stock ${product.stock}',
                                'المخزون ${product.stock}',
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: outOfStock ? null : onAddToCart,
                      icon: Icon(
                        outOfStock
                            ? Icons.remove_shopping_cart_rounded
                            : Icons.shopping_cart_outlined,
                      ),
                      label: Text(
                        outOfStock
                            ? _localizedDisplayText(context, 'Out Of Stock')
                            : _localizedDisplayText(
                                context,
                                inCart ? 'Add More' : 'Add To Cart',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductStatPill extends StatelessWidget {
  const _ProductStatPill({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final Color background = emphasize
        ? AppPalette.primary.withValues(alpha: 0.12)
        : AppPalette.secondary;
    final Color foreground = emphasize
        ? AppPalette.primary
        : AppPalette.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonServiceOption {
  const _SalonServiceOption({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.titleAr,
    required this.subtitle,
    required this.duration,
    required this.price,
  });

  final String id;
  final String title;
  final String titleEn;
  final String titleAr;
  final String? subtitle;
  final String duration;
  final num price;
}

class _BookingStepContainer extends StatelessWidget {
  const _BookingStepContainer({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: appCardDecoration(
          color: selected
              ? AppPalette.primary.withValues(alpha: 0.05)
              : AppPalette.card,
          border: Border.all(
            color: selected ? AppPalette.primary : AppPalette.border,
            width: 2,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppPalette.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.selected,
    required this.onTap,
    this.onTapReviews,
  });

  final Employee employee;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onTapReviews;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: appCardDecoration(
          color: selected
              ? AppPalette.primary.withValues(alpha: 0.05)
              : AppPalette.card,
          border: Border.all(
            color: selected ? AppPalette.primary : AppPalette.border,
            width: 2,
          ),
        ),
        child: Row(
          children: <Widget>[
            ClipOval(
              child: _AppImage(
                imagePath: employee.imagePath,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee.role,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee.availabilityLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onTapReviews,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '★ ${employee.rating.toStringAsFixed(1)} (${employee.reviewsCount})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary,
                          decoration: onTapReviews == null
                              ? null
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: prominent ? 18 : 14,
      fontWeight: prominent ? FontWeight.w700 : FontWeight.w500,
      color: prominent ? AppPalette.foreground : AppPalette.mutedForeground,
    );
    final TextStyle valueStyle = TextStyle(
      fontSize: prominent ? 18 : 14,
      fontWeight: FontWeight.w700,
      color: prominent ? AppPalette.primary : AppPalette.foreground,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _localizedDisplayText(context, label),
              style: labelStyle,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.item});

  final _SettingsItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: appCardDecoration(),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.danger
                    ? Colors.red.withValues(alpha: 0.08)
                    : AppPalette.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: item.danger ? Colors.red.shade600 : AppPalette.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: item.danger ? Colors.red.shade700 : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedForeground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppPalette.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final String limited = digits.length > 16
        ? digits.substring(0, 16)
        : digits;
    final List<String> groups = <String>[];

    for (int index = 0; index < limited.length; index += 4) {
      final int end = index + 4 > limited.length ? limited.length : index + 4;
      groups.add(limited.substring(index, end));
    }

    final String formatted = groups.join(' ');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final String limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    String formatted = limited;

    if (limited.length > 2) {
      formatted = '${limited.substring(0, 2)}/${limited.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 86,
          child: Text(
            _localizedDisplayText(context, label),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppPalette.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _localizedDisplayText(context, value),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ContactActionPanel extends StatelessWidget {
  const _ContactActionPanel({
    required this.icon,
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String value;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(
        color: AppPalette.card,
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppPalette.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _localizedDisplayText(context, title),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppPalette.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(_localizedDisplayText(context, actionLabel)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialIconLink extends StatelessWidget {
  const _SocialIconLink({required this.contact});

  final SocialContact contact;

  String get _displayLink {
    final String uri = (contact.uri ?? '').trim();
    return uri.isNotEmpty ? uri : contact.value;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        if (contact.uri != null) {
          _launchUri(
            context,
            Uri.parse(contact.uri!),
            _tr(
              context,
              'Could not open ${contact.label}.',
              'تعذر فتح ${contact.label}.',
            ),
            fallbackClipboardValue: contact.uri!,
            fallbackConfirmation: _tr(
              context,
              '${contact.label} link copied to clipboard.',
              'تم نسخ رابط ${contact.label} إلى الحافظة.',
            ),
          );
        } else {
          _copyToClipboard(
            context,
            contact.value,
            _tr(
              context,
              '${contact.label} copied to clipboard.',
              'تم نسخ ${contact.label} إلى الحافظة.',
            ),
          );
        }
      },
      child: Container(
        width: 156,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: appCardDecoration(
          color: AppPalette.card,
          border: Border.all(color: AppPalette.border),
          radius: 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppPalette.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _socialIcon(contact.label),
                color: AppPalette.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              contact.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                _displayLink,
                style: TextStyle(
                  fontSize: 11,
                  color: AppPalette.mutedForeground,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyPoint {
  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

String _titleCase(String value) {
  final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return 'FreshLine User';
  }

  return normalized
      .split(' ')
      .map((String word) {
        if (word.isEmpty) {
          return word;
        }
        final String first = word.substring(0, 1).toUpperCase();
        final String rest = word.length > 1
            ? word.substring(1).toLowerCase()
            : '';
        return '$first$rest';
      })
      .join(' ');
}

String _detectLanguage(String text) {
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) {
    return 'Arabic';
  }
  if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
    return 'Hindi';
  }
  if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(text)) {
    return 'Chinese';
  }
  if (RegExp(r'[\u0400-\u04FF]').hasMatch(text)) {
    return 'Russian';
  }
  return 'English';
}

Employee _employeeForSalon(String salonId) {
  final int salonIndex = salons.indexWhere(
    (Salon salon) => salon.id == salonId,
  );
  if (salonIndex < 0) {
    return employees.first;
  }
  return employees[salonIndex % employees.length];
}

Future<void> _openNavigation(BuildContext context, SalonMapInfo info) async {
  final Uri uri = Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'destination': '${info.latitude},${info.longitude}',
  });

  await _launchUri(
    context,
    uri,
    'Could not open navigation.',
    fallbackClipboardValue: '${info.latitude},${info.longitude}',
    fallbackConfirmation: 'Coordinates copied to clipboard.',
  );
}

Future<void> _copyToClipboard(
  BuildContext context,
  String value,
  String confirmation,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(confirmation)));
}

IconData _notificationIcon(String icon) {
  switch (icon) {
    case 'calendar':
      return Icons.calendar_month_rounded;
    case 'cart':
      return Icons.shopping_bag_outlined;
    case 'map':
      return Icons.location_on_rounded;
    case 'sparkles':
      return Icons.auto_awesome_rounded;
    default:
      return Icons.notifications_none_rounded;
  }
}

IconData _socialIcon(String label) {
  switch (label.toLowerCase()) {
    case 'whatsapp':
      return Icons.chat_bubble_outline_rounded;
    case 'instagram':
      return Icons.photo_camera_outlined;
    case 'tiktok':
      return Icons.music_note_rounded;
    case 'x':
    case 'twitter':
      return Icons.alternate_email_rounded;
    case 'youtube':
      return Icons.play_circle_outline_rounded;
    default:
      return Icons.alternate_email_rounded;
  }
}

Future<void> _launchUri(
  BuildContext context,
  Uri uri,
  String failureMessage, {
  String? fallbackClipboardValue,
  String? fallbackConfirmation,
}) async {
  bool launched = false;

  try {
    launched = await launchExternalUri(uri);
  } catch (_) {
    launched = false;
  }

  if (!launched && fallbackClipboardValue != null) {
    if (!context.mounted) {
      return;
    }
    await _copyToClipboard(
      context,
      fallbackClipboardValue,
      fallbackConfirmation ?? 'Copied to clipboard.',
    );
    return;
  }

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}

Uri? _mapUriForSalon(Salon salon) {
  final double? latitude = salon.latitude;
  final double? longitude = salon.longitude;
  if (latitude != null && longitude != null) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
  }

  final String address = salon.address?.trim() ?? '';
  if (address.isNotEmpty) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeQueryComponent(address)}',
    );
  }

  return null;
}

double _distanceValue(String distance) {
  return double.tryParse(distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 999;
}

bool _sameDeliveryLocation(
  DeliveryLocationSelection a,
  DeliveryLocationSelection? b,
) {
  if (b == null) {
    return false;
  }
  return (a.latitude - b.latitude).abs() < 0.000001 &&
      (a.longitude - b.longitude).abs() < 0.000001;
}

int _priceTierValue(String label) {
  final int count = '\$'.allMatches(label).length;
  return count == 0 ? 1 : count;
}

String _formatBookingDateTime(DateTime value) {
  final int hour12 = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final String minute = value.minute.toString().padLeft(2, '0');
  final String meridiem = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.day}/${value.month}/${value.year} $hour12:$minute $meridiem';
}

bool _isManagementOrderCompleted(UserOrder order) {
  final String status = order.statusLabel.trim().toLowerCase();
  return status.contains('completed') ||
      status.contains('complete') ||
      status.contains('delivered') ||
      status.contains('finished');
}

String formatPrice(num price) {
  if (price is int) {
    return price.toString();
  }

  final String value = price.toStringAsFixed(2);
  return value.replaceFirst(RegExp(r'\.?0+$'), '');
}

String formatBhd(num price) {
  return 'BHD ${formatPrice(price)}';
}

Duration? _durationFromLabel(String? value) {
  final String normalized = (value ?? '').trim().toLowerCase();
  final Match? match = RegExp(r'(\d+)').firstMatch(normalized);
  if (match == null) {
    return null;
  }

  final int? amount = int.tryParse(match.group(1)!);
  if (amount == null || amount <= 0) {
    return null;
  }

  if (normalized.contains('hour') || normalized.contains('hr')) {
    return Duration(hours: amount);
  }

  return Duration(minutes: amount);
}

void _showTopToast(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline_rounded,
}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$title\n$message')));
    return;
  }

  late OverlayEntry entry;
  bool removed = false;

  void removeEntry() {
    if (removed) {
      return;
    }
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (BuildContext context) => _TopToastOverlay(
      title: title,
      message: message,
      icon: icon,
      onDismissed: removeEntry,
    ),
  );

  overlay.insert(entry);
}

class _TopToastOverlay extends StatefulWidget {
  const _TopToastOverlay({
    required this.title,
    required this.message,
    required this.icon,
    required this.onDismissed,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onDismissed;

  @override
  State<_TopToastOverlay> createState() => _TopToastOverlayState();
}

class _TopToastOverlayState extends State<_TopToastOverlay> {
  bool _visible = false;
  Timer? _hideTimer;
  Timer? _removeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
    _hideTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
    _removeTimer = Timer(
      const Duration(milliseconds: 3200),
      widget.onDismissed,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, -0.22),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: appCardDecoration(
                        color: AppPalette.card,
                        radius: 22,
                        border: Border.all(
                          color: AppPalette.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppPalette.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.icon,
                              color: AppPalette.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.35,
                                    color: AppPalette.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
