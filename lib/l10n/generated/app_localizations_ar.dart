// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'روت نوت';

  @override
  String get placesTitle => 'أماكني';

  @override
  String get searchHint => 'ابحث بالاسم أو الملاحظات';

  @override
  String get addPlace => 'احفظ الموقع الحالي';

  @override
  String get addPlaceTitle => 'حفظ موقع';

  @override
  String get editPlaceTitle => 'تعديل الموقع';

  @override
  String get fieldName => 'الاسم';

  @override
  String get fieldNameHint => 'مثال: منزل أحمد';

  @override
  String get fieldNotes => 'ملاحظات';

  @override
  String get fieldNotesHint => 'مثال: البوابة ٣، الدور الثاني';

  @override
  String get locationCoordinates => 'الإحداثيات';

  @override
  String get latitude => 'خط العرض';

  @override
  String get longitude => 'خط الطول';

  @override
  String get currentLocation => 'الموقع الحالي';

  @override
  String get fetchingLocation => 'جارٍ تحديد موقعك…';

  @override
  String get nameRequired => 'الرجاء إدخال اسم';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get ok => 'حسنًا';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get navigate => 'التنقل';

  @override
  String get openInGoogleMaps => 'افتح في خرائط جوجل';

  @override
  String get openInWaze => 'افتح في Waze';

  @override
  String get copyCoordinates => 'نسخ الإحداثيات';

  @override
  String get coordinatesCopied => 'تم نسخ الإحداثيات';

  @override
  String get placeSaved => 'تم حفظ الموقع';

  @override
  String get placeDeleted => 'تم حذف الموقع';

  @override
  String get placeDetailsTitle => 'تفاصيل المكان';

  @override
  String get deletePlaceTitle => 'حذف المكان؟';

  @override
  String deletePlaceMessage(String name) {
    return 'سيتم إزالة \"$name\" من هذا الجهاز ومن النسخة الاحتياطية القادمة.';
  }

  @override
  String createdAt(String date) {
    return 'حُفظ بتاريخ $date';
  }

  @override
  String get emptyPlacesTitle => 'لا توجد أماكن محفوظة بعد';

  @override
  String get emptyPlacesMessage => 'اضغط الزر بالأسفل لحفظ موقعك الحالي.';

  @override
  String get noSearchResults => 'لا توجد أماكن مطابقة لبحثك.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get sectionLanguage => 'اللغة';

  @override
  String get languageSystem => 'حسب النظام';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get sectionAccount => 'حساب جوجل';

  @override
  String get signInWithGoogle => 'تسجيل الدخول بجوجل';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String signedInAs(String email) {
    return 'مسجّل الدخول باسم $email';
  }

  @override
  String get notSignedIn => 'لم تسجّل الدخول';

  @override
  String get syncSignInRequired => 'سجّل الدخول بجوجل للمزامنة';

  @override
  String get sectionSync => 'النسخ الاحتياطي والمزامنة';

  @override
  String get syncNow => 'مزامنة الآن';

  @override
  String get syncInProgress => 'جارٍ المزامنة…';

  @override
  String get syncComplete => 'تمت المزامنة';

  @override
  String get syncSkipped => 'سجّل الدخول للمزامنة';

  @override
  String syncFailed(String error) {
    return 'فشلت المزامنة: $error';
  }

  @override
  String lastSynced(String date) {
    return 'آخر مزامنة: $date';
  }

  @override
  String get neverSynced => 'لم تتم المزامنة بعد';

  @override
  String get localOverridesCloud =>
      'بيانات جهازك تتجاوز دائمًا النسخة الاحتياطية على جوجل درايف.';

  @override
  String get restoreFromDrive => 'الاستعادة من جوجل درايف';

  @override
  String get restoreConfirmTitle => 'الاستعادة من جوجل درايف؟';

  @override
  String get restoreConfirmMessage =>
      'سيؤدي هذا إلى استبدال جميع الأماكن على هذا الجهاز بالنسخة الاحتياطية من جوجل درايف.';

  @override
  String get restoreComplete => 'تمت الاستعادة';

  @override
  String restoreFailed(String error) {
    return 'فشلت الاستعادة: $error';
  }

  @override
  String get locationPermissionTitle => 'مطلوب إذن الموقع';

  @override
  String get locationPermissionMessage =>
      'يحتاج روت نوت إلى الوصول لموقعك لحفظ الأماكن.';

  @override
  String get locationServicesDisabled => 'يرجى تفعيل خدمات الموقع على جهازك.';

  @override
  String get locationUnavailable => 'تعذّر تحديد موقعك. حاول مرة أخرى.';

  @override
  String get openAppSettings => 'افتح الإعدادات';

  @override
  String get errorGeneric => 'حدث خطأ ما';

  @override
  String get about => 'حول';

  @override
  String get aboutDescription =>
      'يحفظ روت نوت أماكنك المفضلة دون اتصال ويزامنها إلى جوجل درايف الخاص بك. يتم فتح التنقل في تطبيق الخرائط الذي تستخدمه بالفعل.';
}
