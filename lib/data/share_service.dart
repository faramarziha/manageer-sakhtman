import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../utils/persian.dart';

/// ---------------------------------------------------------------------------
/// سرویس اشتراک‌گذاری رایگان صورتحساب‌ها (Share Intent بومی)
///
/// استراتژی حذف کامل هزینه مخابراتی پیامک:
///
///   به جای ارسال پیامک‌های پرهزینه از پنل پیامکی شرکت، از قابلیت
///   اشتراک‌گذاری سیستم‌عامل استفاده می‌شود. مدیر با زدن یک کلید، متن
///   صورتحساب، شناسه قبض و لینک پرداخت را به صورت کاملاً رایگان در
///   پیام‌رسان مورد استفاده ساکن (ایتا، بله، روبیکا، واتساپ، تلگرام یا
///   SMS شخصی) ارسال می‌کند.
///
///   نتیجه: هزینه اطلاع‌رسانی برای سازنده صفر است. ساختمان‌هایی که اصرار
///   بر ارسال پیامک سیستمی دارند، باید اعتبار پیامک پیش‌خرید کنند که
///   خود منبع درآمد نقدی مکمل برای سازنده است.
/// ---------------------------------------------------------------------------
class ShareService {
  const ShareService._();

  // =========================================================================
  // بخش ۱ - متن استاندارد صورتحساب
  // =========================================================================

  /// ساخت متن استاندارد و خوانای صورتحساب برای اشتراک‌گذاری
  ///
  /// متن شامل: مشخصات واحد، نام ساختمان، مبلغ، مهلت پرداخت،
  /// شناسه قبض/پرداخت و لینک مستقیم درگاه پرداخت است.
  static String buildInvoiceMessage({
    required Building building,
    required Unit unit,
    required Invoice invoice,
    String? payLink,
    String? recipientName,
  }) {
    final b = StringBuffer();

    b.writeln('${invoice.kind.emoji} صورتحساب ${invoice.title}');
    b.writeln('🏢 ${building.name}');
    b.writeln('──────────────────');

    if (recipientName != null && recipientName.trim().isNotEmpty) {
      b.writeln('👤 $recipientName');
    }
    b.writeln('🚪 واحد ${Persian.digits(unit.number)}'
        ' (طبقه ${Persian.digits(unit.floor)})');
    b.writeln('📅 دوره: ${invoice.period}');

    // نمایش نقش گیرنده در صورت تفکیک مالک/مستاجر
    b.writeln('📌 گیرنده: ${invoice.recipientRole.label}');

    b.writeln('──────────────────');

    // ریز اجزای فرمول ماده ۴ برای شفافیت کامل
    if (invoice.breakdown.isNotEmpty) {
      b.writeln('🧮 ریز محاسبه:');
      invoice.breakdown.forEach((key, value) {
        b.writeln('   • $key: ${Persian.toman(value)}');
      });
      b.writeln('──────────────────');
    }

    b.writeln('💰 مبلغ قابل پرداخت: ${Persian.toman(invoice.amount)}');
    b.writeln('⏰ مهلت پرداخت: ${Persian.shortDate(invoice.dueDate)}');

    if (invoice.isOverdue) {
      b.writeln('⚠️ این صورتحساب ${Persian.digits(invoice.daysOverdue)} '
          'روز معوق شده است.');
    }

    b.writeln('──────────────────');
    b.writeln('🧾 شناسه قبض: ${Persian.digits(invoice.billId)}');
    b.writeln('🔢 شناسه پرداخت: ${Persian.digits(invoice.paymentId)}');

    // روش پرداخت آنلاین
    if (payLink != null && payLink.trim().isNotEmpty) {
      b.writeln();
      b.writeln('🔗 پرداخت آنلاین (شاپرک):');
      b.writeln(payLink);
    }

    // روش پرداخت کارت به کارت
    if (building.hasCardInfo) {
      b.writeln();
      b.writeln('💳 کارت به کارت:');
      b.writeln('${Persian.digits(_groupCard(building.cardNumber))}');
      b.writeln('به نام ${building.cardHolder}');
      b.writeln('(پس از واریز، رسید را در برنامه ثبت کنید)');
    }

    b.writeln();
    b.writeln('با تشکر - مدیریت ${building.name}');

    return b.toString();
  }

  /// متن خلاصه چند صورتحساب یک واحد (صورتحساب تجمیعی ماه)
  static String buildUnitStatementMessage({
    required Building building,
    required Unit unit,
    required List<Invoice> invoices,
    String? payLink,
    String? recipientName,
  }) {
    final unpaid = invoices.where((i) => i.status.isDebt).toList();
    final total = unpaid.fold<int>(0, (s, i) => s + i.amount);

    final b = StringBuffer();
    b.writeln('🧾 صورتحساب واحد ${Persian.digits(unit.number)}');
    b.writeln('🏢 ${building.name}');
    b.writeln('──────────────────');
    if (recipientName != null && recipientName.trim().isNotEmpty) {
      b.writeln('👤 $recipientName');
    }
    b.writeln();

    if (unpaid.isEmpty) {
      b.writeln('✅ بدهی پرداخت‌نشده‌ای برای این واحد ثبت نیست.');
      b.writeln('از همکاری شما سپاسگزاریم.');
      b.writeln();
      b.writeln('مدیریت ${building.name}');
      return b.toString();
    }

    b.writeln('📋 اقلام پرداخت‌نشده:');
    for (final inv in unpaid) {
      final overdue =
          inv.isOverdue ? ' ⚠️ (${Persian.digits(inv.daysOverdue)} روز تاخیر)' : '';
      b.writeln('• ${inv.title} — ${Persian.toman(inv.amount)}'
          ' | مهلت: ${Persian.shortDate(inv.dueDate)}$overdue');
    }

    b.writeln('──────────────────');
    b.writeln('💰 جمع کل بدهی: ${Persian.toman(total)}');

    if (payLink != null && payLink.trim().isNotEmpty) {
      b.writeln();
      b.writeln('🔗 پرداخت آنلاین:');
      b.writeln(payLink);
    }

    if (building.hasCardInfo) {
      b.writeln();
      b.writeln('💳 کارت به کارت: '
          '${Persian.digits(_groupCard(building.cardNumber))}');
      b.writeln('به نام ${building.cardHolder}');
    }

    b.writeln();
    b.writeln('مدیریت ${building.name}');
    return b.toString();
  }

  /// متن اعلان عمومی ساختمان برای اشتراک‌گذاری گروهی
  static String buildNoticeMessage({
    required Building building,
    required Notice notice,
  }) {
    final b = StringBuffer();
    b.writeln(notice.isImportant ? '📢 اعلان مهم' : '📌 اعلان ساختمان');
    b.writeln('🏢 ${building.name}');
    b.writeln('──────────────────');
    b.writeln('📝 ${notice.title}');
    b.writeln();
    b.writeln(notice.body);
    b.writeln('──────────────────');
    b.writeln('📅 ${Persian.fullDate(notice.date)}');
    b.writeln('مدیریت ${building.name}');
    return b.toString();
  }

  /// متن دعوت ساکنین به نصب برنامه و اتصال به ساختمان
  static String buildInviteMessage({
    required Building building,
    String? appLink,
  }) {
    final b = StringBuffer();
    b.writeln('🏢 دعوت به سامانه مدیریت ${building.name}');
    b.writeln('──────────────────');
    b.writeln('ساکن محترم، از این پس صورتحساب شارژ، اعلانات و درخواست‌های '
        'ساختمان از طریق اپلیکیشن مدیریت ساختمان در دسترس شماست.');
    b.writeln();
    b.writeln('🔑 کد دعوت ساختمان: ${building.inviteCode}');
    b.writeln();
    b.writeln('مراحل عضویت:');
    b.writeln('۱. نصب برنامه');
    b.writeln('۲. ورود با شماره موبایل');
    b.writeln('۳. وارد کردن کد دعوت و شماره واحد');
    b.writeln('۴. تایید عضویت توسط مدیر');
    if (appLink != null && appLink.trim().isNotEmpty) {
      b.writeln();
      b.writeln('📲 لینک نصب: $appLink');
    }
    b.writeln();
    b.writeln('مدیریت ${building.name}');
    return b.toString();
  }

  // =========================================================================
  // بخش ۲ - فراخوانی پنجره اشتراک‌گذاری سیستم‌عامل
  // =========================================================================

  /// باز کردن پنجره اشتراک‌گذاری پیش‌فرض سیستم‌عامل
  ///
  /// کاربر می‌تواند مقصد را از میان ایتا، بله، روبیکا، واتساپ، تلگرام
  /// یا پیامک شخصی انتخاب کند. هیچ هزینه‌ای برای سازنده ایجاد نمی‌شود.
  static Future<bool> shareText({
    required String text,
    String? subject,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (_) {
      // در صورت عدم پشتیبانی پلتفرم (مثلاً وب دسکتاپ)، به کلیپ‌بورد می‌رویم
      await copyToClipboard(text);
      return false;
    }
  }

  /// اشتراک‌گذاری صورتحساب یک واحد
  static Future<bool> shareInvoice({
    required Building building,
    required Unit unit,
    required Invoice invoice,
    String? payLink,
    String? recipientName,
  }) =>
      shareText(
        text: buildInvoiceMessage(
          building: building,
          unit: unit,
          invoice: invoice,
          payLink: payLink,
          recipientName: recipientName,
        ),
        subject: '${invoice.title} - واحد ${unit.number}',
      );

  /// اشتراک‌گذاری صورتحساب تجمیعی واحد
  static Future<bool> shareUnitStatement({
    required Building building,
    required Unit unit,
    required List<Invoice> invoices,
    String? payLink,
    String? recipientName,
  }) =>
      shareText(
        text: buildUnitStatementMessage(
          building: building,
          unit: unit,
          invoices: invoices,
          payLink: payLink,
          recipientName: recipientName,
        ),
        subject: 'صورتحساب واحد ${unit.number}',
      );

  /// اشتراک‌گذاری اعلان ساختمان
  static Future<bool> shareNotice({
    required Building building,
    required Notice notice,
  }) =>
      shareText(
        text: buildNoticeMessage(building: building, notice: notice),
        subject: notice.title,
      );

  /// اشتراک‌گذاری کد دعوت ساختمان
  static Future<bool> shareInvite({
    required Building building,
    String? appLink,
  }) =>
      shareText(
        text: buildInviteMessage(building: building, appLink: appLink),
        subject: 'دعوت به سامانه ${building.name}',
      );

  /// اشتراک‌گذاری فایل (خروجی بیلان PDF/Excel)
  static Future<bool> shareFile({
    required String filePath,
    required String fileName,
    String? text,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, name: fileName)],
          text: text,
        ),
      );
      return result.status == ShareResultStatus.success;
    } catch (_) {
      return false;
    }
  }

  /// اشتراک‌گذاری داده خام فایل (برای پلتفرم وب که مسیر فایل ندارد)
  static Future<bool> shareBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              name: fileName,
              mimeType: mimeType,
            ),
          ],
          fileNameOverrides: [fileName],
          text: text,
        ),
      );
      return result.status == ShareResultStatus.success;
    } catch (_) {
      return false;
    }
  }

  // =========================================================================
  // بخش ۳ - کلیپ‌بورد (روش جایگزین)
  // =========================================================================

  /// کپی متن در کلیپ‌بورد سیستم
  static Future<void> copyToClipboard(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  // =========================================================================
  // ابزارهای کمکی
  // =========================================================================

  /// گروه‌بندی چهار رقمی شماره کارت برای خوانایی
  static String _groupCard(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) b.write('-');
      b.write(digits[i]);
    }
    return b.toString();
  }
}
