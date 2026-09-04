import '../models/models.dart';

/// ---------------------------------------------------------------------------
/// نتیجه محاسبه شارژ یک واحد (خروجی BillingEngine)
///
/// این کلاس تفکیک کامل اجزای فرمول ماده ۴ را نگه می‌دارد تا صورتحساب
/// صادره برای ساکن شفاف و قابل راستی‌آزمایی باشد.
/// ---------------------------------------------------------------------------
class ChargeBreakdown {
  final String unitId;
  final int unitNumber;

  /// هزینه ثابت پایه واحد (C_Fixed)
  final int fixedPart;

  /// سهم متراژی: Area × R_Area
  final int areaPart;

  /// سهم نفراتی: Persons × R_Person (برای واحد خالی صفر است)
  final int personPart;

  /// هزینه پارکینگ مازاد: Parking × C_Parking
  final int parkingPart;

  /// هزینه کنتور مجزا (C_Meter)
  final int meterPart;

  /// مبلغ ثابت اختصاصی واحد (توافق مجمع)
  final int extraPart;

  /// واحد در زمان محاسبه خالی بوده است؟
  final bool wasVacant;

  /// معافیت نفراتی به دلیل خالی بودن واحد اعمال شد؟
  final bool personRateWaived;

  const ChargeBreakdown({
    required this.unitId,
    required this.unitNumber,
    this.fixedPart = 0,
    this.areaPart = 0,
    this.personPart = 0,
    this.parkingPart = 0,
    this.meterPart = 0,
    this.extraPart = 0,
    this.wasVacant = false,
    this.personRateWaived = false,
  });

  /// مبلغ کل شارژ واحد (تومان)
  int get total =>
      fixedPart + areaPart + personPart + parkingPart + meterPart + extraPart;

  /// اجزای غیرصفر برای ذخیره در صورتحساب و نمایش به ساکن
  Map<String, int> toBreakdownMap() {
    final m = <String, int>{};
    if (fixedPart > 0) m['هزینه ثابت واحد'] = fixedPart;
    if (areaPart > 0) m['سهم متراژی'] = areaPart;
    if (personPart > 0) m['سهم نفرات'] = personPart;
    if (parkingPart > 0) m['پارکینگ'] = parkingPart;
    if (meterPart > 0) m['کنتور مجزا'] = meterPart;
    if (extraPart > 0) m['مبلغ اختصاصی'] = extraPart;
    return m;
  }

  /// توضیح قانونی محاسبه (نمایش در جزئیات صورتحساب)
  String get legalExplanation {
    if (personRateWaived) {
      return 'واحد خالی: طبق ماده ۴ قانون تملک آپارتمان‌ها، این واحد از سهم '
          'هزینه‌های مصرفی (نفراتی) معاف است اما مکلف به پرداخت هزینه‌های '
          'حفظ و نگهداری بنا شامل سهم متراژی، هزینه ثابت و پارکینگ است.';
    }
    return 'محاسبه بر مبنای فرمول ترکیبی ماده ۴ قانون تملک آپارتمان‌ها: '
        'هزینه ثابت + سهم متراژ اختصاصی + سهم نفرات ساکن + پارکینگ مازاد.';
  }
}

/// ---------------------------------------------------------------------------
/// نتیجه محاسبه دسته‌جمعی شارژ کلیه واحدهای ساختمان
/// ---------------------------------------------------------------------------
class BatchChargeResult {
  final String buildingId;
  final String period;
  final List<ChargeBreakdown> breakdowns;

  /// درصد اختصاص‌یافته به صندوق عمرانی
  final int reserveFundPercent;

  const BatchChargeResult({
    required this.buildingId,
    required this.period,
    required this.breakdowns,
    this.reserveFundPercent = 0,
  });

  /// مجموع کل شارژ صادره در این دوره
  int get totalAmount => breakdowns.fold(0, (s, b) => s + b.total);

  /// سهم صندوق عمرانی از کل مبلغ وصولی
  int get reserveShare =>
      ((totalAmount * reserveFundPercent) / 100).round();

  /// سهم صندوق جاری
  int get currentShare => totalAmount - reserveShare;

  int get unitCount => breakdowns.length;

  /// تعداد واحدهای خالی که معافیت نفراتی گرفتند
  int get vacantCount => breakdowns.where((b) => b.wasVacant).length;

  /// میانگین شارژ هر واحد
  int get averageCharge =>
      unitCount == 0 ? 0 : (totalAmount / unitCount).round();
}

/// ---------------------------------------------------------------------------
/// موتور محاسبه شارژ ساختمان بر پایه قوانین آمره مسکن ایران
///
/// فرمول جامع محاسبه شارژ (ماده ۴ قانون تملک آپارتمان‌ها):
///
///   Charge_Total = C_Fixed + (Area × R_Area) + (Persons × R_Person)
///                  + C_Parking + C_Meter
///
/// احکام قانونی پیاده‌سازی‌شده:
///
///  ۱. ماده ۴ (سهم هزینه‌های مشترک): مبنای اصلی سرشکن هزینه‌های مربوط به
///     حفظ و نگهداری بنا، نسبت مساحت اختصاصی هر واحد است. هزینه‌هایی که
///     ارتباطی به متراژ ندارند (مصرف آب، نظافت، سرویس‌های روزمره) طبق
///     مصوبه مجمع می‌توانند به تناسب نفرات سرشکن شوند.
///
///  ۲. منطق واحدهای خالی: واحد خالی مکلف به پرداخت هزینه‌های حفظ و
///     نگهداری بنا است، اما از سهم هزینه‌های مصرفی معاف می‌شود. لذا در
///     صورت isVacant == true، ضریب نفراتی (R_Person) صفر منظور می‌گردد و
///     تنها هزینه‌های متراژی، پارکینگ و ثابت محاسبه می‌شود.
///
///  ۳. تفکیک تعهدات مالک و مستاجر (Dual-Billing): هزینه‌های با سرفصل
///     CAPITAL (عمرانی/اساسی) به مالک و هزینه‌های CONSUMABLE (مصرفی/جاری)
///     به مستاجر منتسب می‌شوند.
///
///  ۴. ماده ۱۴ (بیمه بنا): سهم حق بیمه آتش‌سوزی صرفاً بر اساس نسبت متراژ
///     اختصاصی به متراژ کل بنا محاسبه می‌شود.
/// ---------------------------------------------------------------------------
class BillingEngine {
  const BillingEngine._();

  // =========================================================================
  // بخش ۱ - محاسبه شارژ بر مبنای فرمول ترکیبی ماده ۴
  // =========================================================================

  /// محاسبه سهم متراژی واحد: Area × R_Area
  ///
  /// این جزء، هزینه‌های حفظ و نگهداری بنا را پوشش می‌دهد و طبق ماده ۴
  /// برای واحدهای خالی نیز لازم‌الاجراست.
  static int areaComponent(Unit unit, ChargeFormula formula) {
    if (formula.ratePerSquareMeter <= 0 || unit.area <= 0) return 0;
    // واحد خالی هم سهم متراژی می‌پردازد (پیش‌فرض قانونی)
    if (unit.isVacant && !formula.chargeVacantAreaRate) return 0;
    return (unit.area * formula.ratePerSquareMeter).round();
  }

  /// محاسبه سهم نفراتی واحد: Persons × R_Person
  ///
  /// طبق منطق ماده ۴، واحد خالی از این جزء معاف است زیرا هزینه‌های
  /// مصرفی برای آن ایجاد نمی‌شود.
  static int personComponent(Unit unit, ChargeFormula formula) {
    if (formula.ratePerPerson <= 0) return 0;
    // معافیت قانونی واحد خالی از هزینه‌های مصرفی
    if (unit.isVacant && formula.exemptVacantFromPersonRate) return 0;
    if (unit.residentCount <= 0) return 0;
    return unit.residentCount * formula.ratePerPerson;
  }

  /// محاسبه هزینه پارکینگ مازاد سندی: Parking × C_Parking
  static int parkingComponent(Unit unit, ChargeFormula formula) {
    if (formula.ratePerParking <= 0 || unit.parkingCount <= 0) return 0;
    return unit.parkingCount * formula.ratePerParking;
  }

  /// محاسبه هزینه ثابت کنتور مجزا (C_Meter)
  static int meterComponent(Unit unit, ChargeFormula formula) {
    if (formula.meterFixed <= 0) return 0;
    // هزینه کنتور تنها برای واحدهای دارای کنتور مجزا اعمال می‌شود
    if (unit.meterNumber.trim().isEmpty) return 0;
    return formula.meterFixed;
  }

  /// محاسبه کامل و تفکیک‌شده شارژ یک واحد طبق فرمول ماده ۴
  static ChargeBreakdown calculateUnit(Unit unit, ChargeFormula formula) {
    final personPart = personComponent(unit, formula);
    final waived = unit.isVacant &&
        formula.exemptVacantFromPersonRate &&
        formula.ratePerPerson > 0;

    return ChargeBreakdown(
      unitId: unit.id,
      unitNumber: unit.number,
      fixedPart: formula.fixedPerUnit,
      areaPart: areaComponent(unit, formula),
      personPart: personPart,
      parkingPart: parkingComponent(unit, formula),
      meterPart: meterComponent(unit, formula),
      extraPart: unit.fixedExtra,
      wasVacant: unit.isVacant,
      personRateWaived: waived,
    );
  }

  /// مبلغ نهایی شارژ یک واحد (میان‌بر محاسبه سریع)
  static int calculateCharge(Unit unit, ChargeFormula formula) =>
      calculateUnit(unit, formula).total;

  /// محاسبه دسته‌جمعی شارژ کلیه واحدهای ساختمان
  ///
  /// معادل اندپوینت: POST /api/v1/manager/charge/batch-calculate
  static BatchChargeResult calculateBatch({
    required String buildingId,
    required String period,
    required List<Unit> units,
    required ChargeFormula formula,
  }) {
    final list = units
        .where((u) => u.buildingId == buildingId || u.buildingId.isEmpty)
        .map((u) => calculateUnit(u, formula))
        .toList()
      ..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));

    return BatchChargeResult(
      buildingId: buildingId,
      period: period,
      breakdowns: list,
      reserveFundPercent: formula.reserveFundPercent,
    );
  }

  // =========================================================================
  // بخش ۲ - سرشکن هزینه‌های ثبت‌شده بین واحدها
  // =========================================================================

  /// سرشکن یک فاکتور هزینه بین واحدها بر مبنای نسبت متراژ اختصاصی
  ///
  /// این روش، مبنای قانونی ماده ۴ برای هزینه‌های مرتبط با حفظ و نگهداری
  /// بنا (و همچنین حق بیمه ماده ۱۴) است.
  static Map<String, int> allocateByArea({
    required int amount,
    required List<Unit> units,
  }) {
    final totalArea = units.fold<double>(0, (s, u) => s + u.area);
    if (totalArea <= 0 || units.isEmpty) return {};

    final result = <String, int>{};
    var allocated = 0;
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      if (i == units.length - 1) {
        // آخرین واحد باقیمانده را می‌گیرد تا مجموع دقیقاً برابر مبلغ کل شود
        result[u.id] = amount - allocated;
      } else {
        final share = ((u.area / totalArea) * amount).round();
        result[u.id] = share;
        allocated += share;
      }
    }
    return result;
  }

  /// سرشکن هزینه بر مبنای تعداد نفرات ساکن (هزینه‌های مصرفی)
  ///
  /// واحدهای خالی از این سرشکن حذف می‌شوند.
  static Map<String, int> allocateByResidents({
    required int amount,
    required List<Unit> units,
  }) {
    final active = units.where((u) => !u.isVacant && u.residentCount > 0).toList();
    final totalPersons = active.fold<int>(0, (s, u) => s + u.residentCount);
    if (totalPersons <= 0 || active.isEmpty) return {};

    final result = <String, int>{};
    var allocated = 0;
    for (var i = 0; i < active.length; i++) {
      final u = active[i];
      if (i == active.length - 1) {
        result[u.id] = amount - allocated;
      } else {
        final share = ((u.residentCount / totalPersons) * amount).round();
        result[u.id] = share;
        allocated += share;
      }
    }
    return result;
  }

  /// سرشکن مساوی هزینه بین تمام واحدها
  static Map<String, int> allocateEqually({
    required int amount,
    required List<Unit> units,
  }) {
    if (units.isEmpty) return {};
    final base = amount ~/ units.length;
    final remainder = amount - (base * units.length);

    final result = <String, int>{};
    for (var i = 0; i < units.length; i++) {
      result[units[i].id] = base + (i == 0 ? remainder : 0);
    }
    return result;
  }

  /// سرشکن خودکار یک فاکتور هزینه بر اساس سرفصل قانونی آن
  ///
  /// هزینه‌های عمرانی/اساسی به تناسب متراژ (تعهد مالک) و هزینه‌های
  /// مصرفی به تناسب نفرات (تعهد مستاجر) سرشکن می‌شوند.
  static Map<String, int> allocateExpense({
    required Expense expense,
    required List<Unit> units,
  }) {
    if (expense.expenseType == ExpenseType.capital) {
      return allocateByArea(amount: expense.amount, units: units);
    }
    // برای هزینه مصرفی: اگر هیچ واحد ساکنی نبود، مساوی سرشکن می‌شود
    final byResidents =
        allocateByResidents(amount: expense.amount, units: units);
    if (byResidents.isEmpty) {
      return allocateEqually(amount: expense.amount, units: units);
    }
    return byResidents;
  }

  // =========================================================================
  // بخش ۳ - تفکیک تعهدات مالک و مستاجر (Dual-Billing)
  // =========================================================================

  /// تعیین گیرنده قانونی صورتحساب بر اساس سرفصل هزینه
  ///
  /// • هزینه عمرانی/اساسی (CAPITAL)    → مالک واحد
  /// • هزینه مصرفی/جاری (CONSUMABLE)   → مستاجر (متصرف)
  ///
  /// نکته: اگر واحد مستاجر ندارد (مالک ساکن است یا واحد خالی است)،
  /// صورتحساب در هر صورت به مالک صادر می‌شود.
  static UnitRole resolveRecipient({
    required ExpenseType expenseType,
    required bool unitHasTenant,
  }) {
    if (expenseType == ExpenseType.capital) return UnitRole.owner;
    return unitHasTenant ? UnitRole.tenant : UnitRole.owner;
  }

  /// تعیین گیرنده صورتحساب شارژ ماهانه
  ///
  /// شارژ ماهانه ماهیت مصرفی دارد؛ لذا در صورت وجود مستاجر به او و در
  /// غیر این صورت به مالک صادر می‌شود. واحد خالی همیشه به نام مالک است.
  static UnitRole resolveChargeRecipient({
    required Unit unit,
    required bool unitHasTenant,
  }) {
    if (unit.isVacant) return UnitRole.owner;
    return unitHasTenant ? UnitRole.tenant : UnitRole.owner;
  }

  // =========================================================================
  // بخش ۴ - سهم بیمه ساختمان (ماده ۱۴)
  // =========================================================================

  /// محاسبه سهم حق بیمه هر واحد بر اساس نسبت متراژ اختصاصی
  ///
  /// طبق ماده ۱۴ قانون تملک آپارتمان‌ها، مبنای تقسیم حق بیمه آتش‌سوزی
  /// صرفاً نسبت مساحت اختصاصی واحد به مجموع مساحت‌های اختصاصی بناست.
  /// این هزینه ماهیت اساسی دارد و بر عهده مالک است.
  static Map<String, int> allocateInsurancePremium({
    required InsurancePolicy policy,
    required List<Unit> units,
  }) =>
      allocateByArea(amount: policy.premium, units: units);

  // =========================================================================
  // بخش ۵ - محاسبات بدهی و تراز صندوق
  // =========================================================================

  /// مجموع بدهی معوق یک واحد (مبنای پرونده ماده ۱۰ مکرر)
  static int outstandingDebt(String unitId, List<Invoice> invoices) => invoices
      .where((i) => i.unitId == unitId && i.status.isDebt)
      .fold(0, (s, i) => s + i.amount);

  /// مجموع بدهی معوق واحد به تفکیک نقش (مالک/مستاجر)
  static int outstandingDebtForRole({
    required String unitId,
    required UnitRole role,
    required List<Invoice> invoices,
  }) =>
      invoices
          .where((i) =>
              i.unitId == unitId &&
              i.recipientRole == role &&
              i.status.isDebt)
          .fold(0, (s, i) => s + i.amount);

  /// تراز صندوق ساختمان بر اساس وصولی‌ها و هزینه‌های ثبت‌شده
  ///
  /// معادل اندپوینت: GET /api/v1/manager/reports/balance
  static FundBalance calculateBalance({
    required List<Invoice> invoices,
    required List<Expense> expenses,
    required int reserveFundPercent,
  }) {
    final collected = invoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold(0, (s, i) => s + i.amount);

    final receivable = invoices
        .where((i) => i.status.isDebt)
        .fold(0, (s, i) => s + i.amount);

    final capitalSpent = expenses
        .where((e) => e.expenseType == ExpenseType.capital)
        .fold(0, (s, e) => s + e.amount);

    final consumableSpent = expenses
        .where((e) => e.expenseType == ExpenseType.consumable)
        .fold(0, (s, e) => s + e.amount);

    // تقسیم وصولی بین دو صندوق طبق درصد مصوب مجمع
    final toReserve = ((collected * reserveFundPercent) / 100).round();
    final toCurrent = collected - toReserve;

    return FundBalance(
      totalCollected: collected,
      totalReceivable: receivable,
      currentFundIncome: toCurrent,
      reserveFundIncome: toReserve,
      currentFundExpense: consumableSpent,
      reserveFundExpense: capitalSpent,
    );
  }
}

/// ---------------------------------------------------------------------------
/// ترازنامه مالی صندوق ساختمان (تفکیک صندوق جاری و عمرانی)
/// ---------------------------------------------------------------------------
class FundBalance {
  /// مجموع وصولی‌های تایید‌شده
  final int totalCollected;

  /// مجموع مطالبات وصول‌نشده
  final int totalReceivable;

  final int currentFundIncome;
  final int reserveFundIncome;
  final int currentFundExpense;
  final int reserveFundExpense;

  const FundBalance({
    this.totalCollected = 0,
    this.totalReceivable = 0,
    this.currentFundIncome = 0,
    this.reserveFundIncome = 0,
    this.currentFundExpense = 0,
    this.reserveFundExpense = 0,
  });

  /// مانده صندوق جاری (هزینه‌های مصرفی)
  int get currentBalance => currentFundIncome - currentFundExpense;

  /// مانده صندوق عمرانی (هزینه‌های اساسی)
  int get reserveBalance => reserveFundIncome - reserveFundExpense;

  /// مانده کل صندوق
  int get totalBalance => currentBalance + reserveBalance;

  /// مجموع هزینه‌های دوره
  int get totalExpense => currentFundExpense + reserveFundExpense;

  /// درصد وصول مطالبات
  double get collectionRate {
    final total = totalCollected + totalReceivable;
    if (total == 0) return 0;
    return totalCollected / total;
  }

  /// صندوق جاری کسری دارد؟
  bool get hasCurrentDeficit => currentBalance < 0;

  /// صندوق عمرانی کسری دارد؟
  bool get hasReserveDeficit => reserveBalance < 0;
}
