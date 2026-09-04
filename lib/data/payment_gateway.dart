import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// ---------------------------------------------------------------------------
/// نتیجه فراخوانی درگاه پرداخت
/// ---------------------------------------------------------------------------
class GatewayResult {
  final bool success;

  /// توکن/اتوریتی پرداخت دریافتی از پرداخت‌یار
  final String? authority;

  /// آدرس صفحه پرداخت شاپرک برای انتقال کاربر
  final String? redirectUrl;

  /// شماره مرجع بانکی تراکنش موفق (Reference Retrieval Number)
  final String? rrn;

  /// چهار رقم آخر کارت پرداخت‌کننده
  final String? cardLast4;

  /// کارمزد کسر‌شده از پرداخت‌کننده (تومان)
  final int feeAmount;

  final String? message;
  final String? errorCode;

  const GatewayResult({
    required this.success,
    this.authority,
    this.redirectUrl,
    this.rrn,
    this.cardLast4,
    this.feeAmount = 0,
    this.message,
    this.errorCode,
  });

  factory GatewayResult.failure(String message, {String? code}) =>
      GatewayResult(success: false, message: message, errorCode: code);
}

/// چه کسی کارمزد تراکنش شاپرک را می‌پردازد؟
///
/// طبق ساختار شرکت‌های پرداخت‌یار رسمی شاپرک، کارمزد خدمات پرداخت
/// می‌تواند بر عهده پرداخت‌کننده قرار گیرد یا از مبلغ واریزی به حساب
/// مدیر کسر شود. در هر دو حالت، مالک نرم‌افزار هیچ کارمزدی نمی‌پردازد.
enum FeePayer {
  /// کارمزد به مبلغ قبض اضافه و از ساکن دریافت می‌شود (پیش‌فرض)
  payer,

  /// کارمزد از مبلغ واریزی به صندوق مجتمع کسر می‌شود
  buildingFund,
}

extension FeePayerX on FeePayer {
  String get label => switch (this) {
        FeePayer.payer => 'کارمزد بر عهده پرداخت‌کننده',
        FeePayer.buildingFund => 'کسر کارمزد از صندوق ساختمان',
      };

  String get description => switch (this) {
        FeePayer.payer =>
          'کارمزد خدمات پرداخت به مبلغ قبض افزوده می‌شود و توسط ساکن پرداخت می‌گردد.',
        FeePayer.buildingFund =>
          'کارمزد از مبلغ واریزی به حساب مدیر کسر می‌شود و مبلغ خالص به صندوق واریز می‌گردد.',
      };
}

/// ---------------------------------------------------------------------------
/// سرویس درگاه پرداخت اینترنتی شاپرک (پرداخت‌یار: زرین‌پال / وندار)
///
/// معماری اقتصادی (Zero-Cost Architecture):
///
///  ۱. کارمزد تراکنش (۱٪ تا سقف مصوب بانک مرکزی) طبق ساختار پرداخت‌یاری
///     شاپرک مستقیماً بر عهده پرداخت‌کننده (ساکن) قرار می‌گیرد یا از
///     مانده واریزی به حساب مدیر کسر می‌شود؛ مالک نرم‌افزار هیچ
///     کارمزدی نمی‌پردازد.
///
///  ۲. تسهیم خودکار بانکی (Split Payment): مبالغ شارژ بدون واریز به حساب
///     شرکت، مستقیماً از طریق سیکل‌های پایا به شماره شبای مدیر ساختمان
///     واریز می‌شود؛ لذا شرکت مالک نرم‌افزار درگیر مباحث مالیاتی وجوه
///     شارژ ساکنین نمی‌گردد.
///
///  ۳. قابلیت برداشت خودکار بانکی (Direct Debit) به طور کامل از دستور
///     کار خارج است و پیاده‌سازی نشده است.
///
/// نکته پیاده‌سازی: کلید API و مرچنت‌کد هرگز در کلاینت قرار نمی‌گیرد.
/// کلاینت تنها با بک‌اند خودمان صحبت می‌کند و بک‌اند مسئول امضای
/// درخواست به پرداخت‌یار است.
/// ---------------------------------------------------------------------------
class PaymentGateway extends ChangeNotifier {
  PaymentGateway._();
  static final PaymentGateway instance = PaymentGateway._();

  /// آدرس پایه بک‌اند (در محیط تولید از طریق پیکربندی تزریق می‌شود)
  static String apiBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// حالت شبیه‌سازی: تا زمانی که بک‌اند واقعی متصل نشده، جریان پرداخت
  /// به صورت محلی شبیه‌سازی می‌شود تا توسعه UI متوقف نگردد.
  static bool get isSimulated => apiBaseUrl.trim().isEmpty;

  /// نرخ کارمزد پرداخت‌یاری شاپرک (۱ درصد)
  static const double feeRate = 0.01;

  /// سقف کارمزد هر تراکنش طبق مصوبه بانک مرکزی (تومان)
  static const int feeCap = 5000;

  bool busy = false;
  String? lastError;

  // =========================================================================
  // محاسبه کارمزد
  // =========================================================================

  /// محاسبه کارمزد تراکنش شاپرک (۱٪ تا سقف مصوب بانک مرکزی)
  static int calculateFee(int amount) {
    final fee = (amount * feeRate).round();
    return fee > feeCap ? feeCap : fee;
  }

  /// مبلغ نهایی قابل پرداخت توسط ساکن
  ///
  /// در حالت FeePayer.payer کارمزد به مبلغ قبض افزوده می‌شود.
  static int payableAmount(int amount, FeePayer payer) =>
      payer == FeePayer.payer ? amount + calculateFee(amount) : amount;

  /// مبلغ خالص واریزی به شبای مدیر ساختمان پس از تسهیم
  static int netSettlement(int amount, FeePayer payer) =>
      payer == FeePayer.payer ? amount : amount - calculateFee(amount);

  // =========================================================================
  // گام ۱ - آغاز تراکنش (initiate)
  // =========================================================================

  /// ارسال پارامترهای فاکتور به درگاه پرداخت شاپرک جهت دریافت توکن پرداخت
  ///
  /// معادل اندپوینت: POST /api/v1/payments/initiate
  ///
  /// پارامتر [iban] شبای مدیر ساختمان است که مبلغ از طریق تسهیم
  /// خودکار پرداخت‌یار مستقیماً به آن واریز می‌شود.
  Future<GatewayResult> initiate({
    required Invoice invoice,
    required String iban,
    FeePayer feePayer = FeePayer.payer,
    String? callbackUrl,
  }) async {
    busy = true;
    lastError = null;
    notifyListeners();

    try {
      final payable = payableAmount(invoice.amount, feePayer);
      final fee = calculateFee(invoice.amount);

      if (isSimulated) {
        // ---------- حالت شبیه‌سازی (بک‌اند متصل نیست) ----------
        await Future.delayed(const Duration(milliseconds: 800));
        final authority = _fakeAuthority();
        return GatewayResult(
          success: true,
          authority: authority,
          redirectUrl: 'https://simulated.gateway/pay/$authority',
          feeAmount: feePayer == FeePayer.payer ? fee : 0,
          message: 'تراکنش شبیه‌سازی‌شده ایجاد شد',
        );
      }

      // ---------- حالت واقعی: فراخوانی بک‌اند ----------
      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/v1/payments/initiate'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'building_id': invoice.buildingId,
          'unit_id': invoice.unitId,
          'invoice_id': invoice.id,
          'bill_id': invoice.billId,
          'payment_id': invoice.paymentId,
          'amount': payable,
          'base_amount': invoice.amount,
          'fee_amount': feePayer == FeePayer.payer ? fee : 0,
          'fee_payer': feePayer.name,
          // شبای مدیر برای تسهیم خودکار (Split Payment)
          'settlement_iban': iban,
          'description': '${invoice.title} - دوره ${invoice.period}',
          'callback_url': callbackUrl,
        }),
      ).timeout(const Duration(seconds: 25));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return GatewayResult(
          success: true,
          authority: body['authority'] as String?,
          redirectUrl: body['redirect_url'] as String?,
          feeAmount: (body['fee_amount'] as num?)?.toInt() ?? 0,
        );
      }
      lastError = body['message'] as String? ?? 'خطا در ایجاد تراکنش';
      return GatewayResult.failure(lastError!, code: body['code'] as String?);
    } on TimeoutException {
      lastError = 'اتصال به درگاه پرداخت با تاخیر مواجه شد. دوباره تلاش کنید.';
      return GatewayResult.failure(lastError!);
    } catch (e) {
      lastError = 'خطا در اتصال به درگاه پرداخت';
      return GatewayResult.failure(lastError!);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // گام ۲ - اعتبارسنجی تراکنش (verify)
  // =========================================================================

  /// اعتبارسنجی تراکنش، تخصیص شماره مرجع بانکی (RRN) و تسویه شبا به مدیر
  ///
  /// معادل اندپوینت: POST /api/v1/payments/verify
  ///
  /// با دریافت کال‌بک موفقیت‌آمیز، وضعیت صورتحساب به PAID تغییر می‌کند،
  /// شماره مرجع بانکی ذخیره و رسید الکترونیکی صادر می‌شود.
  Future<GatewayResult> verify({
    required String authority,
    required Invoice invoice,
  }) async {
    busy = true;
    notifyListeners();

    try {
      if (isSimulated) {
        await Future.delayed(const Duration(milliseconds: 900));
        return GatewayResult(
          success: true,
          authority: authority,
          rrn: _fakeRrn(),
          cardLast4: _fakeCardLast4(),
          message: 'تراکنش شبیه‌سازی‌شده با موفقیت تایید شد',
        );
      }

      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/v1/payments/verify'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'authority': authority,
          'invoice_id': invoice.id,
          'payment_id': invoice.paymentId,
          'amount': invoice.amount,
        }),
      ).timeout(const Duration(seconds: 25));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return GatewayResult(
          success: true,
          authority: authority,
          rrn: body['rrn'] as String?,
          cardLast4: body['card_last4'] as String?,
          feeAmount: (body['fee_amount'] as num?)?.toInt() ?? 0,
        );
      }
      lastError = body['message'] as String? ?? 'تراکنش تایید نشد';
      return GatewayResult.failure(lastError!, code: body['code'] as String?);
    } on TimeoutException {
      lastError = 'اعتبارسنجی تراکنش با تاخیر مواجه شد.';
      return GatewayResult.failure(lastError!);
    } catch (e) {
      lastError = 'خطا در اعتبارسنجی تراکنش';
      return GatewayResult.failure(lastError!);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // خرید اشتراک از درگاه شرکتی صاحب برنامه
  // =========================================================================

  /// ارتقای پلن اشتراک ساختمان از طریق درگاه شرکتی مالک نرم‌افزار
  ///
  /// معادل اندپوینت: POST /api/v1/subscriptions/purchase
  ///
  /// این تراکنش مستقیماً به حساب شرکت واریز می‌شود (۱۰۰٪ سود اشتراک)
  /// و از جریان تسهیم شارژ ساکنین کاملاً مجزاست.
  Future<GatewayResult> purchaseSubscription({
    required String buildingId,
    required PlanType plan,
    required BillingCycle cycle,
  }) async {
    busy = true;
    notifyListeners();

    try {
      final amount = plan.priceFor(cycle);

      if (isSimulated) {
        await Future.delayed(const Duration(milliseconds: 1200));
        return GatewayResult(
          success: true,
          rrn: _fakeRrn(),
          message: 'خرید شبیه‌سازی‌شده پلن ${plan.name} انجام شد',
        );
      }

      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/v1/subscriptions/purchase'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'building_id': buildingId,
          'plan_code': plan.code,
          'cycle': cycle.name,
          'amount': amount,
          'max_units': plan.maxUnits,
        }),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        return GatewayResult(
          success: true,
          authority: body['authority'] as String?,
          redirectUrl: body['redirect_url'] as String?,
          rrn: body['rrn'] as String?,
        );
      }
      lastError = body['message'] as String? ?? 'خرید اشتراک انجام نشد';
      return GatewayResult.failure(lastError!);
    } catch (e) {
      lastError = 'خطا در اتصال به درگاه اشتراک';
      return GatewayResult.failure(lastError!);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // ابزارهای شبیه‌سازی
  // =========================================================================

  static final Random _rnd = Random.secure();

  static String _fakeAuthority() {
    const chars = 'ABCDEF0123456789';
    return 'A${List.generate(35, (_) => chars[_rnd.nextInt(chars.length)]).join()}';
  }

  /// تولید شماره مرجع بانکی ۱۲ رقمی (فرمت استاندارد RRN شتاب)
  static String _fakeRrn() =>
      List.generate(12, (_) => _rnd.nextInt(10)).join();

  static String _fakeCardLast4() =>
      List.generate(4, (_) => _rnd.nextInt(10)).join();
}

/// ---------------------------------------------------------------------------
/// تولید شناسه قبض و شناسه پرداخت استاندارد
///
/// ساختار شناسه‌ها با الگوی قبوض خدماتی ایران سازگار است تا امکان
/// پرداخت از طریق سایر درگاه‌ها و اپلیکیشن‌های بانکی نیز فراهم باشد.
/// ---------------------------------------------------------------------------
class BillIdentifier {
  const BillIdentifier._();

  static final Random _rnd = Random();

  /// شناسه قبض یکتا (۱۳ رقم): کد ساختمان + شماره واحد + سری تصادفی
  static String generateBillId({
    required String buildingId,
    required int unitNumber,
  }) {
    final bCode = _hashToDigits(buildingId, 5);
    final uCode = unitNumber.toString().padLeft(4, '0');
    final serial = _rnd.nextInt(10000).toString().padLeft(4, '0');
    return '$bCode$uCode$serial';
  }

  /// شناسه پرداخت یکتا (۱۲ رقم): مبلغ + دوره + سری
  static String generatePaymentId({
    required int amount,
    required DateTime dueDate,
  }) {
    final amountCode = (amount ~/ 1000).toString().padLeft(6, '0');
    final dateCode =
        '${dueDate.month.toString().padLeft(2, '0')}${dueDate.day.toString().padLeft(2, '0')}';
    final serial = _rnd.nextInt(10000).toString().padLeft(4, '0');
    return '$amountCode$dateCode$serial';
  }

  /// تبدیل رشته به کد عددی با طول ثابت
  static String _hashToDigits(String input, int length) {
    var hash = 0;
    for (final code in input.codeUnits) {
      hash = (hash * 31 + code) & 0x7FFFFFFF;
    }
    return hash.toString().padLeft(length, '0').substring(0, length);
  }
}
