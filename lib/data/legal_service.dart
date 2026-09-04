import '../models/models.dart';
import '../utils/persian.dart';

/// ---------------------------------------------------------------------------
/// سرویس تولید اسناد حقوقی استیفای مطالبات (ماده ۱۰ مکرر)
///
/// ماده ۱۰ مکرر قانون تملک آپارتمان‌ها:
///   «در صورت امتناع مالک یا استفاده‌کننده از پرداخت سهم خود از هزینه‌های
///   مشترک، مدیر یا هیئت‌مدیران به وسیله اظهارنامه با ذکر مبلغ بدهی و
///   صورت‌ریز آن، مطالبه می‌نماید. هرگاه مالک یا استفاده‌کننده ظرف ده روز
///   از تاریخ ابلاغ اظهارنامه سهم بدهی خود را نپردازد، مدیر یا هیئت‌مدیران
///   می‌توانند به تشخیص خود و با توجه به امکانات، از دادن خدمات مشترک از
///   قبیل شوفاژ، تعویض هوا، آب گرم، برق، گاز و غیره به او خودداری کنند.»
///
/// خروجی این سرویس، متن استاندارد اظهارنامه است که مدیر می‌تواند آن را
/// به دفاتر خدمات الکترونیک قضایی ارائه نماید.
/// ---------------------------------------------------------------------------
class LegalService {
  const LegalService._();

  /// مهلت قانونی اظهارنامه (روز)
  static const int graceDays = LegalCase.noticeGraceDays;

  // =========================================================================
  // بخش ۱ - تولید متن اظهارنامه رسمی قضایی
  // =========================================================================

  /// تولید متن استاندارد اظهارنامه ماده ۱۰ مکرر
  ///
  /// معادل اندپوینت:
  ///   GET /api/v1/manager/legal/article-10-notice/{unit_id}
  static String buildFormalNotice({
    required Building building,
    required Unit unit,
    required String debtorName,
    required List<Invoice> overdueInvoices,
    String? managerName,
    DateTime? issueDate,
  }) {
    final now = issueDate ?? DateTime.now();
    final deadline = now.add(const Duration(days: graceDays));
    final total = overdueInvoices.fold<int>(0, (s, i) => s + i.amount);
    final manager = (managerName ?? building.managerName).trim();

    final b = StringBuffer();

    b.writeln('اظهارنامه');
    b.writeln('موضوع: مطالبه سهم هزینه‌های مشترک ساختمان');
    b.writeln('مستند قانونی: ماده ۱۰ مکرر قانون تملک آپارتمان‌ها و '
        'ماده ۴ آیین‌نامه اجرایی آن');
    b.writeln();
    b.writeln('${_sep()}');
    b.writeln('مشخصات اظهارکننده (خواهان):');
    b.writeln('مدیر / هیئت‌مدیره ساختمان: ${building.name}');
    if (manager.isNotEmpty) {
      b.writeln('نام مدیر: $manager');
    }
    b.writeln('نشانی: ${building.city}، ${building.address}');
    b.writeln('شماره تماس: ${Persian.digits(building.managerPhone)}');
    b.writeln();
    b.writeln('${_sep()}');
    b.writeln('مشخصات مخاطب (خوانده):');
    b.writeln('نام و نام خانوادگی: $debtorName');
    b.writeln('واحد شماره: ${Persian.digits(unit.number)} - '
        'طبقه ${Persian.digits(unit.floor)}');
    b.writeln('متراژ اختصاصی: ${Persian.digits(unit.area.toStringAsFixed(0))} '
        'متر مربع');
    b.writeln('نشانی: ${building.address}، واحد ${Persian.digits(unit.number)}');
    b.writeln();
    b.writeln('${_sep()}');
    b.writeln('خلاصه اظهارات:');
    b.writeln();
    b.writeln('نظر به اینکه جنابعالی به عنوان مالک/استفاده‌کننده واحد شماره '
        '${Persian.digits(unit.number)} واقع در ساختمان ${building.name}، '
        'از پرداخت سهم خود از هزینه‌های مشترک ساختمان امتناع نموده‌اید و '
        'مراتب بدهی نیز پیش از این به صورت اخطاریه داخلی به اطلاع '
        'جنابعالی رسیده است، بدین‌وسیله به استناد ماده ۱۰ مکرر قانون تملک '
        'آپارتمان‌ها، صورت‌ریز بدهی به شرح ذیل ابلاغ می‌گردد:');
    b.writeln();
    b.writeln('${_sep()}');
    b.writeln('صورت‌ریز بدهی:');
    b.writeln();

    if (overdueInvoices.isEmpty) {
      b.writeln('— موردی ثبت نشده است —');
    } else {
      var row = 1;
      for (final inv in overdueInvoices) {
        b.writeln('${Persian.digits(row)}. ${inv.title}'
            ' | دوره: ${inv.period}'
            ' | مبلغ: ${Persian.toman(inv.amount)}'
            ' | مهلت پرداخت: ${Persian.numericDate(inv.dueDate)}'
            '${inv.daysOverdue > 0 ? ' | تاخیر: ${Persian.digits(inv.daysOverdue)} روز' : ''}');
        row++;
      }
    }

    b.writeln();
    b.writeln('جمع کل بدهی: ${Persian.toman(total)}');
    b.writeln('(${Persian.digits(_amountInWords(total))})');
    b.writeln();
    b.writeln('${_sep()}');
    b.writeln('تقاضا و اخطار قانونی:');
    b.writeln();
    b.writeln('بدین‌وسیله به جنابعالی اخطار می‌گردد که ظرف مهلت قانونی '
        '${Persian.digits(graceDays)} (ده) روز از تاریخ ابلاغ این اظهارنامه، '
        'یعنی حداکثر تا تاریخ ${Persian.fullDate(deadline)}، نسبت به تسویه '
        'کامل مبلغ فوق اقدام نمایید.');
    b.writeln();
    b.writeln('در صورت عدم پرداخت در مهلت مقرر، مدیر/هیئت‌مدیره ساختمان به '
        'استناد صریح ماده ۱۰ مکرر قانون تملک آپارتمان‌ها مجاز خواهد بود '
        'نسبت به قطع خدمات مشترک (از قبیل شوفاژ و موتورخانه، آب گرم، '
        'تعویض هوا و دسترسی به امکانات رفاهی مشترک) اقدام نموده و همچنین '
        'از طریق اجرای ثبت اسناد و املاک محل و مراجع قضایی صالح، نسبت به '
        'وصول مطالبات، خسارت تاخیر تادیه و هزینه‌های دادرسی اقدام قانونی '
        'به عمل آورد.');
    b.writeln();
    b.writeln('تبصره: چنانچه عدم پرداخت ناشی از اختلاف در محاسبه سهم '
        'هزینه‌ها است، مستند به ماده ۱۰ مکرر می‌توانید ظرف همان مهلت به '
        'دادگاه صالح مراجعه و دادخواست اعتراض تقدیم نمایید.');
    b.writeln();
    b.writeln('${_sep()}');
    b.writeln('تاریخ تنظیم: ${Persian.fullDate(now)}');
    b.writeln('پایان مهلت قانونی: ${Persian.fullDate(deadline)}');
    b.writeln();
    b.writeln('امضا و مهر مدیر / هیئت‌مدیره ساختمان ${building.name}');
    b.writeln();
    b.writeln('${_sep()}');
    b.writeln('راهنما: این متن جهت ثبت در سامانه ثنا و ارائه به دفاتر خدمات '
        'الکترونیک قضایی تنظیم شده است. پس از ثبت اظهارنامه، تاریخ ابلاغ '
        'رسمی را در برنامه ثبت نمایید تا مهلت ۱۰ روزه قانونی پایش شود.');

    return b.toString();
  }

  // =========================================================================
  // بخش ۲ - تولید متن اخطاریه داخلی درون‌برنامه‌ای
  // =========================================================================

  /// اخطاریه داخلی (مرحله پیش از اظهارنامه رسمی)
  ///
  /// این متن از طریق Share Intent و بدون هیچ هزینه پیامکی برای سازنده
  /// در پیام‌رسان‌های ساکن ارسال می‌شود.
  static String buildInternalWarning({
    required Building building,
    required Unit unit,
    required String debtorName,
    required List<Invoice> overdueInvoices,
    int replyDays = 7,
  }) {
    final total = overdueInvoices.fold<int>(0, (s, i) => s + i.amount);
    final deadline = DateTime.now().add(Duration(days: replyDays));

    final b = StringBuffer();
    b.writeln('🔔 اخطاریه پرداخت هزینه‌های مشترک');
    b.writeln('ساختمان ${building.name}');
    b.writeln('${_sep()}');
    b.writeln('جناب/سرکار $debtorName');
    b.writeln('واحد شماره ${Persian.digits(unit.number)}');
    b.writeln();
    b.writeln('بدینوسیله به اطلاع می‌رساند مبلغ ${Persian.toman(total)} '
        'از سهم هزینه‌های مشترک ساختمان تا این تاریخ پرداخت نشده است.');
    b.writeln();
    b.writeln('ریز بدهی:');
    for (final inv in overdueInvoices) {
      b.writeln('• ${inv.title} (${inv.period}): ${Persian.toman(inv.amount)}');
    }
    b.writeln();
    b.writeln('خواهشمند است حداکثر تا ${Persian.shortDate(deadline)} '
        'نسبت به تسویه اقدام فرمایید.');
    b.writeln();
    b.writeln('⚠️ در صورت عدم پرداخت، طبق ماده ۱۰ مکرر قانون تملک '
        'آپارتمان‌ها اظهارنامه رسمی قضایی صادر و پس از مهلت ۱۰ روزه '
        'قانونی، خدمات مشترک قطع خواهد شد.');
    b.writeln();
    b.writeln('مدیریت ساختمان ${building.name}');
    return b.toString();
  }

  // =========================================================================
  // بخش ۳ - صورتجلسه قطع خدمات مشترک
  // =========================================================================

  /// تولید صورتجلسه قطع خدمات مشترک (سند اثباتی برای مراجع قضایی)
  static String buildServiceCutoffMinutes({
    required Building building,
    required Unit unit,
    required String debtorName,
    required LegalCase legalCase,
    required List<SharedService> services,
    DateTime? cutoffDate,
  }) {
    final now = cutoffDate ?? DateTime.now();
    final b = StringBuffer();

    b.writeln('صورتجلسه قطع خدمات مشترک');
    b.writeln('مستند: ماده ۱۰ مکرر قانون تملک آپارتمان‌ها');
    b.writeln('${_sep()}');
    b.writeln('ساختمان: ${building.name}');
    b.writeln('نشانی: ${building.city}، ${building.address}');
    b.writeln('واحد: ${Persian.digits(unit.number)} - $debtorName');
    b.writeln('مبلغ بدهی: ${Persian.toman(legalCase.debtAmount)}');
    b.writeln();
    b.writeln('سابقه اقدامات قانونی:');
    if (legalCase.warningServedAt != null) {
      b.writeln('• ابلاغ اخطاریه داخلی: '
          '${Persian.fullDate(legalCase.warningServedAt!)}');
    }
    if (legalCase.noticeIssuedAt != null) {
      b.writeln('• صدور اظهارنامه رسمی: '
          '${Persian.fullDate(legalCase.noticeIssuedAt!)}');
      b.writeln('• پایان مهلت ۱۰ روزه قانونی: '
          '${Persian.fullDate(legalCase.noticeDeadline!)}');
    }
    b.writeln();
    b.writeln('خدمات قطع‌شده در تاریخ ${Persian.fullDate(now)}:');
    for (final s in services) {
      b.writeln('• ${s.label}');
    }
    b.writeln();
    b.writeln('توضیح: با عنایت به انقضای مهلت قانونی ۱۰ روزه مقرر در '
        'اظهارنامه ابلاغ‌شده و عدم تسویه بدهی از سوی مالک/استفاده‌کننده، '
        'خدمات مشترک فوق به تشخیص هیئت‌مدیره و با رعایت شرط عدم ایجاد '
        'خطر برای ساکنین قطع گردید. خدمات پس از تسویه کامل بدهی و '
        'هزینه وصل مجدد، برقرار خواهد شد.');
    b.writeln();
    b.writeln('امضای اعضای هیئت‌مدیره ساختمان ${building.name}');
    return b.toString();
  }

  // =========================================================================
  // بخش ۴ - اعتبارسنجی گردش کار قانونی
  // =========================================================================

  /// آیا مدیر مجاز به صدور اظهارنامه رسمی برای این پرونده است؟
  ///
  /// شرط قانونی: پیش از اظهارنامه باید اخطاریه داخلی ابلاغ شده باشد.
  static bool canIssueFormalNotice(LegalCase c) =>
      !c.isResolved &&
      c.warningServedAt != null &&
      c.noticeIssuedAt == null;

  /// آیا قطع خدمات مشترک قانوناً مجاز است؟
  ///
  /// شرط قانونی: اظهارنامه صادر و مهلت ۱۰ روزه منقضی شده باشد.
  static bool canCutServices(LegalCase c) => c.canCutServices;

  /// دلیل عدم امکان قطع خدمات (پیام راهنما برای مدیر)
  static String? cutoffBlockReason(LegalCase c) {
    if (c.isResolved) return 'این پرونده تسویه شده است.';
    if (c.noticeIssuedAt == null) {
      return 'ابتدا باید اظهارنامه رسمی ماده ۱۰ مکرر صادر و ابلاغ شود.';
    }
    if (!c.isGracePeriodOver) {
      return 'مهلت قانونی ۱۰ روزه اظهارنامه هنوز سپری نشده است؛ '
          '${Persian.digits(c.graceDaysLeft)} روز باقی مانده.';
    }
    return null;
  }

  // =========================================================================
  // ابزارهای کمکی
  // =========================================================================

  static String _sep() => '──────────────────────────────';

  /// تبدیل مبلغ به حروف (نمایش در اظهارنامه رسمی)
  static String _amountInWords(int amount) {
    if (amount <= 0) return 'صفر تومان';
    final millions = amount ~/ 1000000;
    final thousands = (amount % 1000000) ~/ 1000;
    final rest = amount % 1000;

    final parts = <String>[];
    if (millions > 0) parts.add('$millions میلیون');
    if (thousands > 0) parts.add('$thousands هزار');
    if (rest > 0) parts.add('$rest');
    return '${parts.join(' و ')} تومان';
  }
}
