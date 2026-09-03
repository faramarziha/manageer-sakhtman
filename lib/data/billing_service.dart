import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// نتیجه خرید اشتراک
class PurchaseResult {
  final bool success;
  final String? purchaseToken;
  final String? message;

  const PurchaseResult({
    required this.success,
    this.purchaseToken,
    this.message,
  });
}

/// وضعیت اتصال به سرویس پرداخت
enum BillingState { disconnected, connecting, connected, failed }

/// سرویس پرداخت درون‌برنامه‌ای - اسکلت آماده برای کافه‌بازار (Poolakey)
///
/// نحوه اتصال در نسخه انتشار اندروید:
/// 1. افزودن پکیج poolakey به pubspec.yaml
/// 2. دریافت RSA Public Key از پنل توسعه‌دهندگان بازار
/// 3. جایگذاری کلید در ثابت [_bazaarRsaKey]
/// 4. پیاده‌سازی متدهای مشخص‌شده با [TODO_BAZAAR]
///
/// در نسخه وب/توسعه، خرید به‌صورت شبیه‌سازی‌شده انجام می‌شود.
class BillingService extends ChangeNotifier {
  BillingService._();
  static final BillingService instance = BillingService._();

  /// TODO_BAZAAR: کلید RSA از پنل بازار اینجا قرار می‌گیرد
  /// دریافت از: https://pishkhan.cafebazaar.ir → برنامه‌ها → پرداخت درون‌برنامه‌ای
  static const String _bazaarRsaKey = 'PUT_BAZAAR_RSA_KEY_HERE';

  BillingState state = BillingState.disconnected;
  String? lastError;

  /// SKUهای مجاز اشتراک - باید در پنل بازار تعریف شوند
  static const List<String> subscriptionSkus = [
    'sub_basic_monthly',    // طرح پایه
    'sub_pro_monthly',      // طرح حرفه‌ای
    'sub_enterprise_monthly', // طرح سازمانی
  ];

  bool get isConnected =>
      state == BillingState.connected ||
      state == BillingState.failed; // در حالت شبیه‌سازی هم ادامه می‌دهیم

  /// اتصال به سرویس پرداخت بازار
  Future<void> connect() async {
    if (state == BillingState.connecting) return;
    state = BillingState.connecting;
    notifyListeners();

    // TODO_BAZAAR: کد واقعی اتصال به بازار:
    // await Payment.init(_bazaarRsaKey);
    // final connected = await Payment.connect();
    // state = connected ? BillingState.connected : BillingState.failed;

    await Future.delayed(const Duration(milliseconds: 600));
    // در محیط وب/توسعه همیشه به حالت شبیه‌سازی می‌رویم
    state = kIsWeb ? BillingState.failed : BillingState.connected;
    if (_bazaarRsaKey == 'PUT_BAZAAR_RSA_KEY_HERE') {
      lastError = 'کلید بازار تنظیم نشده - حالت شبیه‌سازی فعال است';
    }
    notifyListeners();
  }

  /// خرید اشتراک - در حالت فعلی شبیه‌سازی می‌شود
  Future<PurchaseResult> purchaseSubscription(PlanType plan) async {
    if (state == BillingState.disconnected) {
      await connect();
    }

    // TODO_BAZAAR: کد واقعی خرید از بازار:
    // final purchaseResult = await Payment.purchase(plan.sku);
    // final token = purchaseResult.purchaseToken;
    // final verified = await _verifyWithBackend(token);
    // if (verified) await Payment.consume(token);
    // return PurchaseResult(success: verified, purchaseToken: token);

    // شبیه‌سازی فرایند خرید
    await Future.delayed(const Duration(seconds: 2));
    final token = 'SIM_${plan.sku}_${DateTime.now().millisecondsSinceEpoch}';
    return PurchaseResult(
      success: true,
      purchaseToken: token,
      message: 'خرید شبیه‌سازی‌شده با موفقیت انجام شد',
    );
  }

  /// بررسی اشتراک‌های فعال کاربر در بازار (بازیابی خرید)
  Future<List<String>> queryActiveSubscriptions() async {
    // TODO_BAZAAR: بازیابی اشتراک‌های فعال از بازار:
    // final purchases = await Payment.getSubscribedProducts();
    // return purchases.map((p) => p.productId).toList();
    return [];
  }

  /// قطع اتصال
  Future<void> disconnect() async {
    // TODO_BAZAAR: await Payment.disconnect();
    state = BillingState.disconnected;
    notifyListeners();
  }
}
