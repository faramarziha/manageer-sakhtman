import 'package:persian_tools/persian_tools.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// ابزارهای کمکی فارسی‌سازی: اعداد، مبالغ و تاریخ شمسی
class Persian {
  Persian._();

  /// تبدیل ارقام انگلیسی به فارسی
  static String digits(Object? value) {
    if (value == null) return '';
    final s = value.toString();
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var out = s;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(en[i], fa[i]);
    }
    return out;
  }

  /// تبدیل ارقام فارسی/عربی به انگلیسی (برای پارس ورودی کاربر)
  static String toEnglishDigits(String input) {
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var out = input;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    return out.replaceAll(',', '').replaceAll('،', '').trim();
  }

  /// پارس عدد صحیح از ورودی فارسی
  static int? parseInt(String input) =>
      int.tryParse(toEnglishDigits(input));

  /// پارس عدد اعشاری از ورودی فارسی
  static double? parseDouble(String input) =>
      double.tryParse(toEnglishDigits(input));

  /// قالب‌بندی مبلغ به تومان با جداکننده هزارگان و ارقام فارسی
  static String toman(num amount) {
    final formatted = addCommas(amount.round());
    return '${digits(formatted)} تومان';
  }

  /// فقط عدد با جداکننده (بدون کلمه تومان)
  static String money(num amount) => digits(addCommas(amount.round()));

  /// تاریخ شمسی کامل: «پنجشنبه ۷ شهریور ۱۴۰۴»
  static String fullDate(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final f = j.formatter;
    return '${f.wN} ${digits('${j.day}')} ${f.mN} ${digits('${j.year}')}';
  }

  /// تاریخ شمسی کوتاه: «۷ شهریور ۱۴۰۴»
  static String shortDate(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final f = j.formatter;
    return '${digits('${j.day}')} ${f.mN} ${digits('${j.year}')}';
  }

  /// تاریخ عددی: «۱۴۰۴/۰۶/۰۷»
  static String numericDate(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final m = j.month.toString().padLeft(2, '0');
    final d = j.day.toString().padLeft(2, '0');
    return digits('${j.year}/$m/$d');
  }

  /// نام ماه شمسی جاری
  static String currentMonthName() {
    final j = Jalali.now();
    return '${j.formatter.mN} ${digits('${j.year}')}';
  }

  /// زمان گذشته به فارسی
  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'همین حالا';
    if (diff.inMinutes < 60) return '${digits(diff.inMinutes)} دقیقه پیش';
    if (diff.inHours < 24) return '${digits(diff.inHours)} ساعت پیش';
    if (diff.inDays < 7) return '${digits(diff.inDays)} روز پیش';
    return shortDate(date);
  }
}
