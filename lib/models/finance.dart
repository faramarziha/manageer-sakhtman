import 'building.dart';

/// ---------------------------------------------------------------------------
/// سرفصل قانونی هزینه (تفکیک تعهدات مالک و مستاجر)
///
/// طبق قانون مدنی و روابط موجر و مستاجر:
///   • CAPITAL    : هزینه‌های اساسی/عمرانی → تعهد مالک
///                  (تعمیرات اساسی آسانسور، ایزوگام، نمای ساختمان، موتورخانه)
///   • CONSUMABLE : هزینه‌های مصرفی/جاری → تعهد مستاجر (متصرف)
///                  (نظافت، آب، برق مشاعات، سرویس دوره‌ای، نگهبانی)
/// ---------------------------------------------------------------------------
enum ExpenseType { capital, consumable }

extension ExpenseTypeX on ExpenseType {
  String get code => switch (this) {
        ExpenseType.capital => 'CAPITAL',
        ExpenseType.consumable => 'CONSUMABLE',
      };

  String get label => switch (this) {
        ExpenseType.capital => 'عمرانی / اساسی',
        ExpenseType.consumable => 'مصرفی / جاری',
      };

  String get shortLabel => switch (this) {
        ExpenseType.capital => 'عمرانی',
        ExpenseType.consumable => 'جاری',
      };

  /// تعهد قانونی این سرفصل بر عهده کدام طرف است؟
  UnitRole get liableRole => switch (this) {
        ExpenseType.capital => UnitRole.owner,
        ExpenseType.consumable => UnitRole.tenant,
      };

  String get description => switch (this) {
        ExpenseType.capital =>
          'هزینه‌های اساسی و عمرانی بنا؛ طبق قانون بر عهده مالک واحد است و از صندوق عمرانی تامین می‌شود.',
        ExpenseType.consumable =>
          'هزینه‌های مصرفی و روزمره؛ بر عهده متصرف (مستاجر) است و از صندوق جاری تامین می‌شود.',
      };

  /// آیکون نمایشی
  String get emoji => switch (this) {
        ExpenseType.capital => '🏗️',
        ExpenseType.consumable => '🧾',
      };
}

/// دسته‌بندی موضوعی هزینه (برای نمودار دایره‌ای شفافیت مالی)
enum ExpenseCategory {
  elevator,
  cleaning,
  utilities,
  security,
  repairs,
  insurance,
  greenSpace,
  salary,
  other,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.elevator => 'آسانسور',
        ExpenseCategory.cleaning => 'نظافت',
        ExpenseCategory.utilities => 'آب، برق و گاز مشاعات',
        ExpenseCategory.security => 'نگهبانی و امنیت',
        ExpenseCategory.repairs => 'تعمیرات',
        ExpenseCategory.insurance => 'بیمه ساختمان',
        ExpenseCategory.greenSpace => 'فضای سبز',
        ExpenseCategory.salary => 'حقوق سرایدار',
        ExpenseCategory.other => 'متفرقه',
      };

  String get emoji => switch (this) {
        ExpenseCategory.elevator => '🛗',
        ExpenseCategory.cleaning => '🧹',
        ExpenseCategory.utilities => '💡',
        ExpenseCategory.security => '🛡️',
        ExpenseCategory.repairs => '🔧',
        ExpenseCategory.insurance => '📜',
        ExpenseCategory.greenSpace => '🌿',
        ExpenseCategory.salary => '👷',
        ExpenseCategory.other => '📋',
      };

  /// سرفصل قانونی پیشنهادی برای این دسته
  ExpenseType get suggestedType => switch (this) {
        ExpenseCategory.elevator => ExpenseType.capital,
        ExpenseCategory.insurance => ExpenseType.capital,
        ExpenseCategory.repairs => ExpenseType.capital,
        _ => ExpenseType.consumable,
      };
}

/// ---------------------------------------------------------------------------
/// فاکتور هزینه ثبت‌شده توسط مدیر (جدول expenses)
///
/// تصویر فاکتور پیش از بارگذاری، در کلاینت فلاتر فشرده و به WebP زیر
/// ۱۰۰ کیلوبایت تبدیل می‌شود (استراتژی Zero-Cost Architecture).
/// ---------------------------------------------------------------------------
class Expense {
  final String id;
  final String buildingId;
  final String title;
  final int amount;
  final ExpenseType expenseType;
  final ExpenseCategory category;

  /// آدرس تصویر فشرده فاکتور (WebP زیر ۱۰۰ کیلوبایت)
  final String? invoiceUrl;

  /// حجم نهایی تصویر پس از فشرده‌سازی (بایت) - برای پایش مصرف ترافیک
  final int? invoiceSizeBytes;

  final DateTime date;
  final String? note;

  /// آیا این هزینه بین واحدها سرشکن شده است؟
  final bool isAllocated;

  const Expense({
    required this.id,
    required this.buildingId,
    required this.title,
    required this.amount,
    required this.expenseType,
    this.category = ExpenseCategory.other,
    this.invoiceUrl,
    this.invoiceSizeBytes,
    required this.date,
    this.note,
    this.isAllocated = false,
  });

  bool get hasInvoiceImage => invoiceUrl != null && invoiceUrl!.isNotEmpty;

  /// این هزینه از کدام صندوق برداشت می‌شود؟
  bool get fromReserveFund => expenseType == ExpenseType.capital;

  Expense copyWith({
    String? title,
    int? amount,
    ExpenseType? expenseType,
    ExpenseCategory? category,
    String? invoiceUrl,
    int? invoiceSizeBytes,
    String? note,
    bool? isAllocated,
  }) =>
      Expense(
        id: id,
        buildingId: buildingId,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        expenseType: expenseType ?? this.expenseType,
        category: category ?? this.category,
        invoiceUrl: invoiceUrl ?? this.invoiceUrl,
        invoiceSizeBytes: invoiceSizeBytes ?? this.invoiceSizeBytes,
        date: date,
        note: note ?? this.note,
        isAllocated: isAllocated ?? this.isAllocated,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'title': title,
        'amount': amount,
        'expenseType': expenseType.index,
        'category': category.index,
        'invoiceUrl': invoiceUrl,
        'invoiceSizeBytes': invoiceSizeBytes,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'isAllocated': isAllocated,
      };

  factory Expense.fromMap(Map m) => Expense(
        id: m['id'],
        buildingId: m['buildingId'],
        title: m['title'],
        amount: m['amount'],
        expenseType: ExpenseType.values[m['expenseType'] ?? 1],
        category: ExpenseCategory.values[m['category'] ?? 8],
        invoiceUrl: m['invoiceUrl'],
        invoiceSizeBytes: m['invoiceSizeBytes'],
        date: DateTime.fromMillisecondsSinceEpoch(m['date']),
        note: m['note'],
        isAllocated: m['isAllocated'] ?? false,
      );
}

/// وضعیت صورتحساب
enum InvoiceStatus { unpaid, awaitingApproval, paid, rejected, overdue }

extension InvoiceStatusX on InvoiceStatus {
  String get code => switch (this) {
        InvoiceStatus.unpaid => 'UNPAID',
        InvoiceStatus.awaitingApproval => 'AWAITING_APPROVAL',
        InvoiceStatus.paid => 'PAID',
        InvoiceStatus.rejected => 'REJECTED',
        InvoiceStatus.overdue => 'OVERDUE',
      };

  String get label => switch (this) {
        InvoiceStatus.unpaid => 'پرداخت نشده',
        InvoiceStatus.awaitingApproval => 'در انتظار تایید مدیر',
        InvoiceStatus.paid => 'پرداخت شده',
        InvoiceStatus.rejected => 'رسید رد شده',
        InvoiceStatus.overdue => 'معوقه',
      };

  bool get isSettled => this == InvoiceStatus.paid;

  /// بدهی محسوب می‌شود؟ (مبنای ماده ۱۰ مکرر)
  bool get isDebt =>
      this == InvoiceStatus.unpaid ||
      this == InvoiceStatus.rejected ||
      this == InvoiceStatus.overdue;
}

/// روش پرداخت
enum PayMethod { none, shaparak, cardToCard, cash }

extension PayMethodX on PayMethod {
  String get label => switch (this) {
        PayMethod.none => '-',
        PayMethod.shaparak => 'درگاه اینترنتی شاپرک',
        PayMethod.cardToCard => 'کارت به کارت',
        PayMethod.cash => 'نقدی',
      };

  String get shortLabel => switch (this) {
        PayMethod.none => '-',
        PayMethod.shaparak => 'آنلاین',
        PayMethod.cardToCard => 'کارت به کارت',
        PayMethod.cash => 'نقدی',
      };

  /// پرداخت آفلاین نیازمند تایید مدیر است
  bool get needsManagerApproval =>
      this == PayMethod.cardToCard || this == PayMethod.cash;
}

/// دسته‌بندی صورتحساب
enum InvoiceKind { charge, water, electricity, gas, repair, insurance, deposit, other }

extension InvoiceKindX on InvoiceKind {
  String get label => switch (this) {
        InvoiceKind.charge => 'شارژ ساختمان',
        InvoiceKind.water => 'آب',
        InvoiceKind.electricity => 'برق',
        InvoiceKind.gas => 'گاز',
        InvoiceKind.repair => 'تعمیرات',
        InvoiceKind.insurance => 'سهم بیمه',
        InvoiceKind.deposit => 'ودیعه رزرو مشاعات',
        InvoiceKind.other => 'هزینه متفرقه',
      };

  String get emoji => switch (this) {
        InvoiceKind.charge => '🏢',
        InvoiceKind.water => '💧',
        InvoiceKind.electricity => '⚡',
        InvoiceKind.gas => '🔥',
        InvoiceKind.repair => '🔧',
        InvoiceKind.insurance => '📜',
        InvoiceKind.deposit => '📅',
        InvoiceKind.other => '📋',
      };
}

/// ---------------------------------------------------------------------------
/// صورتحساب صادره برای واحد (جدول invoices)
///
/// هر صورتحساب دارای شناسه قبض یکتا (billId) و شناسه پرداخت (paymentId)
/// است تا با استانداردهای درگاه پرداخت شاپرک سازگار باشد. پس از تایید
/// تراکنش، شماره مرجع بانکی (RRN) ذخیره و رسید الکترونیکی صادر می‌شود.
///
/// فیلد recipientRole مشخص می‌کند این صورتحساب طبق تفکیک قانونی هزینه‌ها
/// برای مالک صادر شده یا مستاجر.
/// ---------------------------------------------------------------------------
class Invoice {
  final String id;
  final String buildingId;
  final String unitId;

  /// این صورتحساب برای مالک صادر شده یا مستاجر؟
  final UnitRole recipientRole;

  final InvoiceKind kind;
  final String title;
  final String period; // دوره شمسی، مثلاً «شهریور ۱۴۰۴»
  final int amount;
  final InvoiceStatus status;
  final PayMethod method;

  /// شناسه قبض یکتا (استاندارد شاپرک)
  final String billId;

  /// شناسه پرداخت (استاندارد شاپرک)
  final String paymentId;

  /// شماره مرجع بانکی تراکنش موفق
  final String? rrn;

  /// چهار رقم آخر کارت پرداخت‌کننده (کارت‌به‌کارت)
  final String? cardLast4;

  /// آدرس تصویر فشرده فیش واریزی
  final String? receiptUrl;
  final String? receiptNote;
  final String? rejectionReason;

  /// تفکیک اجزای فرمول ماده ۴ (برای شفافیت در صورتحساب)
  final Map<String, int> breakdown;

  final DateTime dueDate;
  final DateTime? paidAt;
  final DateTime createdAt;

  const Invoice({
    required this.id,
    required this.buildingId,
    required this.unitId,
    this.recipientRole = UnitRole.tenant,
    required this.kind,
    required this.title,
    required this.period,
    required this.amount,
    required this.status,
    this.method = PayMethod.none,
    required this.billId,
    required this.paymentId,
    this.rrn,
    this.cardLast4,
    this.receiptUrl,
    this.receiptNote,
    this.rejectionReason,
    this.breakdown = const {},
    required this.dueDate,
    this.paidAt,
    required this.createdAt,
  });

  /// صورتحساب معوقه است؟ (مهلت گذشته و پرداخت نشده)
  bool get isOverdue =>
      status.isDebt && DateTime.now().isAfter(dueDate);

  /// تعداد روز تاخیر در پرداخت (مبنای اخطاریه ماده ۱۰ مکرر)
  int get daysOverdue {
    if (!isOverdue) return 0;
    return DateTime.now().difference(dueDate).inDays;
  }

  bool get hasReceipt => receiptUrl != null && receiptUrl!.isNotEmpty;

  /// رسید الکترونیکی صادر شده است؟
  bool get hasElectronicReceipt =>
      status == InvoiceStatus.paid && rrn != null && rrn!.isNotEmpty;

  Invoice copyWith({
    InvoiceStatus? status,
    PayMethod? method,
    String? rrn,
    String? cardLast4,
    String? receiptUrl,
    String? receiptNote,
    String? rejectionReason,
    DateTime? paidAt,
    DateTime? dueDate,
    bool clearRejection = false,
  }) =>
      Invoice(
        id: id,
        buildingId: buildingId,
        unitId: unitId,
        recipientRole: recipientRole,
        kind: kind,
        title: title,
        period: period,
        amount: amount,
        status: status ?? this.status,
        method: method ?? this.method,
        billId: billId,
        paymentId: paymentId,
        rrn: rrn ?? this.rrn,
        cardLast4: cardLast4 ?? this.cardLast4,
        receiptUrl: receiptUrl ?? this.receiptUrl,
        receiptNote: receiptNote ?? this.receiptNote,
        rejectionReason:
            clearRejection ? null : (rejectionReason ?? this.rejectionReason),
        breakdown: breakdown,
        dueDate: dueDate ?? this.dueDate,
        paidAt: paidAt ?? this.paidAt,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'unitId': unitId,
        'recipientRole': recipientRole.index,
        'kind': kind.index,
        'title': title,
        'period': period,
        'amount': amount,
        'status': status.index,
        'method': method.index,
        'billId': billId,
        'paymentId': paymentId,
        'rrn': rrn,
        'cardLast4': cardLast4,
        'receiptUrl': receiptUrl,
        'receiptNote': receiptNote,
        'rejectionReason': rejectionReason,
        'breakdown': breakdown,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'paidAt': paidAt?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Invoice.fromMap(Map m) => Invoice(
        id: m['id'],
        buildingId: m['buildingId'] ?? '',
        unitId: m['unitId'],
        recipientRole: UnitRole.values[m['recipientRole'] ?? 1],
        kind: InvoiceKind.values[m['kind'] ?? 0],
        title: m['title'],
        period: m['period'] ?? '',
        amount: m['amount'],
        status: InvoiceStatus.values[m['status'] ?? 0],
        method: PayMethod.values[m['method'] ?? 0],
        billId: m['billId'] ?? '',
        paymentId: m['paymentId'] ?? '',
        rrn: m['rrn'],
        cardLast4: m['cardLast4'],
        receiptUrl: m['receiptUrl'],
        receiptNote: m['receiptNote'],
        rejectionReason: m['rejectionReason'],
        breakdown: Map<String, int>.from(m['breakdown'] ?? const {}),
        dueDate: DateTime.fromMillisecondsSinceEpoch(m['dueDate']),
        paidAt: m['paidAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['paidAt'])
            : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      );
}

/// ---------------------------------------------------------------------------
/// تنظیمات فرمول شارژ ساختمان (فرمول‌ساز ترکیبی ماده ۴)
///
/// فرمول جامع محاسبه شارژ:
///   Charge = C_Fixed + (Area × R_Area) + (Persons × R_Person)
///            + C_Parking + C_Meter
///
/// طبق ماده ۴ قانون تملک آپارتمان‌ها، سهم هزینه‌های مشترک بر مبنای
/// نسبت مساحت اختصاصی تعیین می‌شود، مگر آنکه مجمع عمومی به اتفاق آرا
/// ترتیب دیگری (مانند سرشکن نفراتی هزینه‌های مصرفی) مقرر کند.
/// ---------------------------------------------------------------------------
class ChargeFormula {
  final String buildingId;

  /// هزینه ثابت پایه هر واحد (C_Fixed) - تومان
  final int fixedPerUnit;

  /// نرخ هر متر مربع (R_Area) - تومان
  final int ratePerSquareMeter;

  /// نرخ هر نفر ساکن (R_Person) - تومان
  final int ratePerPerson;

  /// هزینه هر پارکینگ مازاد (C_Parking) - تومان
  final int ratePerParking;

  /// هزینه ثابت کنتور مجزا (C_Meter) - تومان
  final int meterFixed;

  /// درصد اختصاص‌یافته به صندوق عمرانی/ذخیره از هر شارژ (۰ تا ۱۰۰)
  final int reserveFundPercent;

  /// طبق ماده ۴، واحد خالی از سهم نفراتی معاف است اما هزینه حفظ و
  /// نگهداری بنا (سهم متراژی، ثابت و پارکینگ) را می‌پردازد.
  final bool exemptVacantFromPersonRate;

  /// آیا سهم متراژی برای واحد خالی هم اعمال شود؟ (طبق قانون: بله)
  final bool chargeVacantAreaRate;

  const ChargeFormula({
    required this.buildingId,
    this.fixedPerUnit = 0,
    this.ratePerSquareMeter = 0,
    this.ratePerPerson = 0,
    this.ratePerParking = 0,
    this.meterFixed = 0,
    this.reserveFundPercent = 10,
    this.exemptVacantFromPersonRate = true,
    this.chargeVacantAreaRate = true,
  });

  /// فرمول پیش‌فرض پیشنهادی برای ساختمان تازه‌ثبت‌شده
  factory ChargeFormula.defaults(String buildingId) => ChargeFormula(
        buildingId: buildingId,
        fixedPerUnit: 150000,
        ratePerSquareMeter: 4000,
        ratePerPerson: 80000,
        ratePerParking: 50000,
        meterFixed: 0,
        reserveFundPercent: 10,
      );

  /// فرمول معتبر است؟ (حداقل یکی از ضرایب باید مقدار داشته باشد)
  bool get isConfigured =>
      fixedPerUnit > 0 ||
      ratePerSquareMeter > 0 ||
      ratePerPerson > 0 ||
      ratePerParking > 0 ||
      meterFixed > 0;

  /// توضیح خوانای فرمول برای نمایش به مدیر
  String get humanReadable {
    final parts = <String>[];
    if (fixedPerUnit > 0) parts.add('ثابت هر واحد');
    if (ratePerSquareMeter > 0) parts.add('متراژ × نرخ');
    if (ratePerPerson > 0) parts.add('نفرات × نرخ');
    if (ratePerParking > 0) parts.add('پارکینگ');
    if (meterFixed > 0) parts.add('کنتور');
    return parts.isEmpty ? 'تنظیم نشده' : parts.join(' + ');
  }

  ChargeFormula copyWith({
    int? fixedPerUnit,
    int? ratePerSquareMeter,
    int? ratePerPerson,
    int? ratePerParking,
    int? meterFixed,
    int? reserveFundPercent,
    bool? exemptVacantFromPersonRate,
    bool? chargeVacantAreaRate,
  }) =>
      ChargeFormula(
        buildingId: buildingId,
        fixedPerUnit: fixedPerUnit ?? this.fixedPerUnit,
        ratePerSquareMeter: ratePerSquareMeter ?? this.ratePerSquareMeter,
        ratePerPerson: ratePerPerson ?? this.ratePerPerson,
        ratePerParking: ratePerParking ?? this.ratePerParking,
        meterFixed: meterFixed ?? this.meterFixed,
        reserveFundPercent: reserveFundPercent ?? this.reserveFundPercent,
        exemptVacantFromPersonRate:
            exemptVacantFromPersonRate ?? this.exemptVacantFromPersonRate,
        chargeVacantAreaRate:
            chargeVacantAreaRate ?? this.chargeVacantAreaRate,
      );

  Map<String, dynamic> toMap() => {
        'buildingId': buildingId,
        'fixedPerUnit': fixedPerUnit,
        'ratePerSquareMeter': ratePerSquareMeter,
        'ratePerPerson': ratePerPerson,
        'ratePerParking': ratePerParking,
        'meterFixed': meterFixed,
        'reserveFundPercent': reserveFundPercent,
        'exemptVacantFromPersonRate': exemptVacantFromPersonRate,
        'chargeVacantAreaRate': chargeVacantAreaRate,
      };

  factory ChargeFormula.fromMap(Map m) => ChargeFormula(
        buildingId: m['buildingId'],
        fixedPerUnit: m['fixedPerUnit'] ?? 0,
        ratePerSquareMeter: m['ratePerSquareMeter'] ?? 0,
        ratePerPerson: m['ratePerPerson'] ?? 0,
        ratePerParking: m['ratePerParking'] ?? 0,
        meterFixed: m['meterFixed'] ?? 0,
        reserveFundPercent: m['reserveFundPercent'] ?? 10,
        exemptVacantFromPersonRate: m['exemptVacantFromPersonRate'] ?? true,
        chargeVacantAreaRate: m['chargeVacantAreaRate'] ?? true,
      );
}
