/// ---------------------------------------------------------------------------
/// مدل پلن‌های اشتراک (استراتژی Freemium)
///
/// ماتریس تعرفه‌گذاری مصوب سند راهبردی:
///  • پلن پایه   : تا ۶ واحد   → کاملاً رایگان و همیشگی (ابزار جذب کاربر)
///  • پلن اقتصادی: ۷ تا ۲۰ واحد → ۳۹ هزار تومان ماهانه / ۳۹۰ هزار سالانه
///  • پلن جامع   : بالای ۲۰ واحد → ۸۹ هزار تومان ماهانه / ۸۹۰ هزار سالانه
/// ---------------------------------------------------------------------------

/// دوره پرداخت اشتراک
enum BillingCycle { monthly, yearly }

extension BillingCycleX on BillingCycle {
  String get label => switch (this) {
        BillingCycle.monthly => 'ماهانه',
        BillingCycle.yearly => 'سالانه',
      };

  int get days => switch (this) {
        BillingCycle.monthly => 30,
        BillingCycle.yearly => 365,
      };
}

/// نوع پلن اشتراک ساختمان
enum PlanType { free, economy, comprehensive }

extension PlanTypeX on PlanType {
  /// شناسه فنی پلن (برای بک‌اند و درگاه پرداخت شرکتی)
  String get code => switch (this) {
        PlanType.free => 'plan_free_basic',
        PlanType.economy => 'plan_economy',
        PlanType.comprehensive => 'plan_comprehensive',
      };

  String get name => switch (this) {
        PlanType.free => 'پایه (همیشگی)',
        PlanType.economy => 'اقتصادی',
        PlanType.comprehensive => 'جامع',
      };

  String get shortName => switch (this) {
        PlanType.free => 'پایه',
        PlanType.economy => 'اقتصادی',
        PlanType.comprehensive => 'جامع',
      };

  String get tagline => switch (this) {
        PlanType.free => 'تا ۶ واحد - کاملاً رایگان و بدون محدودیت زمانی',
        PlanType.economy => 'ساختمان‌های ۷ تا ۲۰ واحدی',
        PlanType.comprehensive => 'برج‌ها و مجتمع‌های بالای ۲۰ واحد',
      };

  bool get isFree => this == PlanType.free;

  /// حداکثر واحد مجاز در این پلن
  int get maxUnits => switch (this) {
        PlanType.free => 6,
        PlanType.economy => 20,
        PlanType.comprehensive => 99999,
      };

  /// حداقل واحد لازم برای این پلن (برای پیشنهاد خودکار پلن)
  int get minUnits => switch (this) {
        PlanType.free => 1,
        PlanType.economy => 7,
        PlanType.comprehensive => 21,
      };

  /// قیمت ماهانه (تومان)
  int get priceMonthly => switch (this) {
        PlanType.free => 0,
        PlanType.economy => 39000,
        PlanType.comprehensive => 89000,
      };

  /// قیمت سالانه (تومان) - معادل ۱۰ ماه، دو ماه هدیه
  int get priceYearly => switch (this) {
        PlanType.free => 0,
        PlanType.economy => 390000,
        PlanType.comprehensive => 890000,
      };

  int priceFor(BillingCycle cycle) =>
      cycle == BillingCycle.monthly ? priceMonthly : priceYearly;

  /// درصد تخفیف پرداخت سالانه نسبت به ماهانه
  int get yearlyDiscountPercent {
    if (isFree) return 0;
    final monthlyTotal = priceMonthly * 12;
    if (monthlyTotal == 0) return 0;
    return (((monthlyTotal - priceYearly) / monthlyTotal) * 100).round();
  }

  /// امکانات هر پلن (نمایش در صفحه اشتراک)
  List<String> get features => switch (this) {
        PlanType.free => [
            'مدیریت تا ۶ واحد',
            'فرمول‌ساز قانونی ماده ۴ (متراژ + نفرات + ثابت)',
            'صدور خودکار صورتحساب و فاکتور',
            'تابلوی اعلانات ساختمان',
            'اشتراک‌گذاری رایگان قبوض در پیام‌رسان‌ها',
            'ثبت و تایید کارت‌به‌کارت',
          ],
        PlanType.economy => [
            'مدیریت تا ۲۰ واحد',
            'همه امکانات پلن پایه',
            'بیلان‌گیری کامل با خروجی PDF و اکسل',
            'درگاه پرداخت اینترنتی شاپرک',
            'تفکیک قانونی هزینه مالک و مستاجر',
            'ماژول پایش بیمه ساختمان (ماده ۱۴)',
            'اظهارنامه قانونی ماده ۱۰ مکرر',
          ],
        PlanType.comprehensive => [
            'واحدهای نامحدود',
            'همه امکانات پلن اقتصادی',
            'رزرواسیون تقویمی مشاعات با ودیعه آنلاین',
            'رأی‌گیری وزنی مجمع بر پایه متراژ سندی',
            'صندوق تفکیک‌شده جاری و عمرانی',
            'گزارش‌های تحلیلی و نمودار هزینه‌کرد',
            'پشتیبانی اختصاصی',
          ],
      };

  /// قابلیت‌های قفل‌شده در پلن (برای کنترل دسترسی در UI)
  bool get hasOnlineGateway => this != PlanType.free;
  bool get hasBalanceExport => this != PlanType.free;
  bool get hasDualBilling => this != PlanType.free;
  bool get hasInsuranceModule => this != PlanType.free;
  bool get hasLegalNotice => this != PlanType.free;
  bool get hasAmenityBooking => this == PlanType.comprehensive;
  bool get hasWeightedVoting => this == PlanType.comprehensive;

  /// پلن پیشنهادی بر اساس تعداد واحد ساختمان
  static PlanType suggestFor(int unitCount) {
    if (unitCount <= PlanType.free.maxUnits) return PlanType.free;
    if (unitCount <= PlanType.economy.maxUnits) return PlanType.economy;
    return PlanType.comprehensive;
  }
}

/// اشتراک فعال ساختمان
class Subscription {
  final String id;
  final String buildingId;
  final PlanType plan;
  final DateTime startedAt;
  final DateTime expiresAt;
  final BillingCycle cycle;
  final bool autoRenew;
  final int maxUnits; // سقف واحد ثبت‌شده در زمان خرید
  final int paidAmount; // مبلغ پرداخت‌شده (تومان)
  final String? paymentRef; // شماره مرجع پرداخت اشتراک

  const Subscription({
    required this.id,
    required this.buildingId,
    required this.plan,
    required this.startedAt,
    required this.expiresAt,
    this.cycle = BillingCycle.monthly,
    this.autoRenew = false,
    this.maxUnits = 6,
    this.paidAmount = 0,
    this.paymentRef,
  });

  /// پلن رایگان ابدی است؛ سایر پلن‌ها تا تاریخ انقضا فعال‌اند
  bool get isPerpetual => plan.isFree;

  bool get isActive => isPerpetual || DateTime.now().isBefore(expiresAt);

  int get daysLeft {
    if (isPerpetual) return -1; // بی‌نهایت
    final d = expiresAt.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  /// هشدار تمدید (کمتر از ۷ روز مانده)
  bool get isExpiringSoon => !isPerpetual && isActive && daysLeft <= 7;

  /// اشتراک رایگان همیشگی برای ساختمان تازه‌ساز
  factory Subscription.freeForBuilding(String buildingId, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return Subscription(
      id: 'sub_free_${t.millisecondsSinceEpoch}',
      buildingId: buildingId,
      plan: PlanType.free,
      startedAt: t,
      // تاریخ انقضای نمادین (منطق isActive آن را نادیده می‌گیرد)
      expiresAt: t.add(const Duration(days: 36500)),
      maxUnits: PlanType.free.maxUnits,
    );
  }

  Subscription copyWith({
    PlanType? plan,
    DateTime? expiresAt,
    BillingCycle? cycle,
    bool? autoRenew,
    int? maxUnits,
    int? paidAmount,
    String? paymentRef,
  }) =>
      Subscription(
        id: id,
        buildingId: buildingId,
        plan: plan ?? this.plan,
        startedAt: startedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        cycle: cycle ?? this.cycle,
        autoRenew: autoRenew ?? this.autoRenew,
        maxUnits: maxUnits ?? this.maxUnits,
        paidAmount: paidAmount ?? this.paidAmount,
        paymentRef: paymentRef ?? this.paymentRef,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'plan': plan.index,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'cycle': cycle.index,
        'autoRenew': autoRenew,
        'maxUnits': maxUnits,
        'paidAmount': paidAmount,
        'paymentRef': paymentRef,
      };

  factory Subscription.fromMap(Map m) => Subscription(
        id: m['id'],
        buildingId: m['buildingId'],
        plan: PlanType.values[m['plan'] ?? 0],
        startedAt: DateTime.fromMillisecondsSinceEpoch(m['startedAt']),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(m['expiresAt']),
        cycle: BillingCycle.values[m['cycle'] ?? 0],
        autoRenew: m['autoRenew'] ?? false,
        maxUnits: m['maxUnits'] ?? 6,
        paidAmount: m['paidAmount'] ?? 0,
        paymentRef: m['paymentRef'],
      );
}

/// ---------------------------------------------------------------------------
/// بسته اعتبار پیامک (منبع درآمد نقدی مکمل سازنده)
///
/// سیاست پیش‌فرض سیستم، اشتراک‌گذاری رایگان قبوض با Share Intent است و
/// هیچ هزینه مخابراتی به سازنده تحمیل نمی‌شود. ساختمان‌هایی که اصرار به
/// ارسال پیامک سیستمی دارند، باید اعتبار پیامک پیش‌خرید کنند.
/// ---------------------------------------------------------------------------
class SmsCreditPack {
  final String id;
  final String title;
  final int smsCount;
  final int price; // تومان

  const SmsCreditPack({
    required this.id,
    required this.title,
    required this.smsCount,
    required this.price,
  });

  /// قیمت هر پیامک (تومان)
  double get pricePerSms => smsCount == 0 ? 0 : price / smsCount;

  static const List<SmsCreditPack> packs = [
    SmsCreditPack(
        id: 'sms_500', title: 'بسته برنزی', smsCount: 500, price: 90000),
    SmsCreditPack(
        id: 'sms_2000', title: 'بسته نقره‌ای', smsCount: 2000, price: 320000),
    SmsCreditPack(
        id: 'sms_10000', title: 'بسته طلایی', smsCount: 10000, price: 1400000),
  ];
}
