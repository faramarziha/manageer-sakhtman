import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/models.dart';
import 'billing_service.dart';
import 'payment_gateway.dart';

/// لایه داده اپلیکیشن — معماری ابری چندمستاجره (Multi-Tenant SaaS)
///
/// همه جداول با ستون `building_id` تفکیک می‌شوند تا داده هر ساختمان
/// کاملاً از ساختمان‌های دیگر جدا باشد (گام ۵ سند راهبردی).
///
/// ذخیره‌سازی فعلی Hive است و ساختار جداول عیناً منطبق بر اسکیمای
/// بک‌اند (buildings / units / unit_users / expenses / invoices /
/// subscriptions / amenity_bookings) طراحی شده تا مهاجرت به REST API
/// بدون تغییر در لایه UI انجام شود.
class AppStore extends ChangeNotifier {
  static const String _boxName = 'building_data_v4';

  // ---------------- ثابت‌ها ----------------

  static const List<String> requestCategories = [
    'تاسیسات', 'برق', 'آسانسور', 'نظافت', 'امنیت', 'سایر',
  ];

  static const List<String> iranianCities = [
    'تهران', 'مشهد', 'اصفهان', 'شیراز', 'تبریز', 'کرج', 'قم', 'اهواز',
    'کرمانشاه', 'ارومیه', 'رشت', 'زاهدان', 'همدان', 'کرمان', 'یزد',
    'اردبیل', 'بندرعباس', 'اراک', 'قزوین', 'زنجان', 'سنندج', 'گرگان',
    'ساری', 'خرم‌آباد', 'ایلام', 'بوشهر', 'یاسوج', 'شهرکرد', 'بجنورد',
    'سمنان', 'بیرجند',
  ];

  /// سقف واحد در طرح پایه رایگان — بند ۱ سند (رایگان دائمی تا ۶ واحد)
  static const int freeUnitLimit = 6;

  // ---------------- وضعیت (جداول) ----------------
  late Box _box;

  // جداول سراسری
  List<Building> buildings = [];
  List<User> users = [];
  List<Subscription> subscriptions = [];

  // جداول تفکیک‌شده با building_id
  List<Unit> units = [];
  List<UnitUser> unitUsers = [];
  List<Invoice> invoices = [];
  List<Expense> expenses = [];
  List<ChargeFormula> formulas = [];
  List<LegalCase> legalCases = [];
  List<InsurancePolicy> policies = [];
  List<AmenityBooking> amenityBookings = [];
  List<Poll> polls = [];
  List<Vote> votes = [];
  List<Notice> notices = [];
  List<MaintenanceRequest> requests = [];
  List<MembershipRequest> membershipRequests = [];

  // جلسه کاربر
  User? currentUser;
  String? activeBuildingId;

  /// واحد فعال کاربر — پشتیبانی از چندملکی (گام ۴ سند)
  String? activeUnitId;

  // ---------------- مقداردهی و پایداری ----------------

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    if (_box.get('initialized') == true) {
      _load();
    } else {
      _seed();
      await _save();
      await _box.put('initialized', true);
    }
  }

  void _load() {
    buildings = _readList('buildings', Building.fromMap);
    users = _readList('users', User.fromMap);
    subscriptions = _readList('subscriptions', Subscription.fromMap);
    units = _readList('units', Unit.fromMap);
    unitUsers = _readList('unitUsers', UnitUser.fromMap);
    invoices = _readList('invoices', Invoice.fromMap);
    expenses = _readList('expenses', Expense.fromMap);
    formulas = _readList('formulas', ChargeFormula.fromMap);
    legalCases = _readList('legalCases', LegalCase.fromMap);
    policies = _readList('policies', InsurancePolicy.fromMap);
    amenityBookings = _readList('amenityBookings', AmenityBooking.fromMap);
    polls = _readList('polls', Poll.fromMap);
    votes = _readList('votes', Vote.fromMap);
    notices = _readList('notices', Notice.fromMap);
    requests = _readList('requests', MaintenanceRequest.fromMap);
    membershipRequests =
        _readList('membershipRequests', MembershipRequest.fromMap);

    final uid = _box.get('currentUserId');
    if (uid != null) {
      currentUser = users.where((u) => u.id == uid).firstOrNull;
    }
    activeBuildingId = _box.get('activeBuildingId');
    activeUnitId = _box.get('activeUnitId');
  }

  List<T> _readList<T>(String key, T Function(Map) fromMap) {
    final raw = _box.get(key);
    if (raw == null) return [];
    return (raw as List)
        .map((e) => fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _save() async {
    await _box.putAll({
      'buildings': buildings.map((e) => e.toMap()).toList(),
      'users': users.map((e) => e.toMap()).toList(),
      'subscriptions': subscriptions.map((e) => e.toMap()).toList(),
      'units': units.map((e) => e.toMap()).toList(),
      'unitUsers': unitUsers.map((e) => e.toMap()).toList(),
      'invoices': invoices.map((e) => e.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'formulas': formulas.map((e) => e.toMap()).toList(),
      'legalCases': legalCases.map((e) => e.toMap()).toList(),
      'policies': policies.map((e) => e.toMap()).toList(),
      'amenityBookings': amenityBookings.map((e) => e.toMap()).toList(),
      'polls': polls.map((e) => e.toMap()).toList(),
      'votes': votes.map((e) => e.toMap()).toList(),
      'notices': notices.map((e) => e.toMap()).toList(),
      'requests': requests.map((e) => e.toMap()).toList(),
      'membershipRequests':
          membershipRequests.map((e) => e.toMap()).toList(),
      'currentUserId': currentUser?.id,
      'activeBuildingId': activeBuildingId,
      'activeUnitId': activeUnitId,
    });
  }

  Future<void> resetData() async {
    final keepUser = currentUser;
    final keepBuilding = activeBuildingId;
    final keepUnit = activeUnitId;
    _seed();
    currentUser = keepUser;
    activeBuildingId = keepBuilding;
    activeUnitId = keepUnit;
    await _save();
    notifyListeners();
  }

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  // =========================================================================
  // داده نمونه (Seed) — دو ساختمان برای نمایش قابلیت چندملکی
  // =========================================================================

  void _seed() {
    final now = DateTime.now();
    const bMain = 'b_mehr';
    const bSecond = 'b_arghavan';

    // ---------- ساختمان‌ها ----------
    buildings = [
      Building(
        id: bMain,
        name: 'برج مهر سعادت‌آباد',
        address: 'بلوار دریا، برج مهر',
        city: 'تهران',
        unitsCount: 10,
        managerPhone: '09121234567',
        managerName: 'مهندس بهنام شریفی',
        inviteCode: 'MEHR24',
        totalArea: 1031,
        currentBalance: 12_400_000,
        reserveBalance: 8_600_000,
        iban: 'IR520630144905901219088001',
        cardNumber: '6104337912345678',
        cardHolder: 'بهنام شریفی',
        planType: PlanType.economy,
        maxAllowedUnits: PlanType.economy.maxUnits,
        subscriptionExpiry: now.add(const Duration(days: 26)),
        smsCredit: 0,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
      Building(
        id: bSecond,
        name: 'مجتمع ارغوان',
        address: 'خیابان ولیعصر، کوچه ارغوان',
        city: 'تهران',
        unitsCount: 4,
        managerPhone: '09351112233',
        managerName: 'آقای کامران راد',
        inviteCode: 'ARGH11',
        totalArea: 312,
        currentBalance: 3_100_000,
        iban: '',
        planType: PlanType.free,
        maxAllowedUnits: PlanType.free.maxUnits,
        createdAt: now.subtract(const Duration(days: 40)),
      ),
    ];

    // ---------- کاربران ----------
    users = [
      User(
        id: 'usr_manager',
        phone: '09121234567',
        fullName: 'مهندس بهنام شریفی',
        role: UserRole.manager,
        buildingId: bMain,
        membershipStatus: MembershipStatus.active,
        unitRole: UnitRole.owner,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
      User(
        id: 'usr_resident',
        phone: '09129876543',
        fullName: 'خانم زهرا حسینی',
        role: UserRole.resident,
        buildingId: bMain,
        unitId: 'u_102',
        membershipStatus: MembershipStatus.active,
        unitRole: UnitRole.tenant,
        createdAt: now.subtract(const Duration(days: 80)),
      ),
    ];

    // ---------- اشتراک‌ها ----------
    subscriptions = [
      Subscription(
        id: 'sub_mehr',
        buildingId: bMain,
        plan: PlanType.economy,
        startedAt: now.subtract(const Duration(days: 4)),
        expiresAt: now.add(const Duration(days: 26)),
        maxUnits: PlanType.economy.maxUnits,
        paidAmount: PlanType.economy.priceMonthly,
        paymentRef: '۱۴۰۴۰۶۰۱۹۹۸۸',
      ),
      Subscription.freeForBuilding(bSecond,
          now: now.subtract(const Duration(days: 40))),
    ];

    // ---------- واحدها ----------
    units = const [
      Unit(id: 'u_101', buildingId: bMain, number: 101, floor: 1, ownerName: 'آقای محمد رضایی', phone: '09121234567', area: 95, residentCount: 3, parkingCount: 1, monthlyCharge: 850000, meterNumber: '۳۳۱۰۴۵'),
      Unit(id: 'u_102', buildingId: bMain, number: 102, floor: 1, ownerName: 'خانم زهرا حسینی', phone: '09129876543', area: 88, residentCount: 2, parkingCount: 1, monthlyCharge: 850000, meterNumber: '۳۳۱۰۴۶'),
      Unit(id: 'u_201', buildingId: bMain, number: 201, floor: 2, ownerName: 'آقای علی کریمی', phone: '09121112233', area: 110, residentCount: 4, parkingCount: 2, monthlyCharge: 950000, meterNumber: '۳۳۱۰۴۷'),
      Unit(id: 'u_202', buildingId: bMain, number: 202, floor: 2, ownerName: 'خانم مریم احمدی', phone: '09124445566', area: 92, residentCount: 2, parkingCount: 1, monthlyCharge: 850000, meterNumber: '۳۳۱۰۴۸'),
      Unit(id: 'u_301', buildingId: bMain, number: 301, floor: 3, ownerName: 'آقای حسن موسوی', phone: '09127778899', area: 105, residentCount: 3, parkingCount: 1, monthlyCharge: 950000, meterNumber: '۳۳۱۰۴۹'),
      Unit(id: 'u_302', buildingId: bMain, number: 302, floor: 3, ownerName: 'آقای رضا صادقی', phone: '09123334455', area: 98, residentCount: 0, parkingCount: 1, isVacant: true, monthlyCharge: 850000, meterNumber: '۳۳۱۰۵۰'),
      Unit(id: 'u_401', buildingId: bMain, number: 401, floor: 4, ownerName: 'خانم فاطمه نجفی', phone: '09126667788', area: 120, residentCount: 5, parkingCount: 2, monthlyCharge: 1100000, meterNumber: '۳۳۱۰۵۱'),
      Unit(id: 'u_402', buildingId: bMain, number: 402, floor: 4, ownerName: 'آقای مهدی جعفری', phone: '09129990011', area: 100, residentCount: 3, parkingCount: 1, monthlyCharge: 950000, meterNumber: '۳۳۱۰۵۲'),
      Unit(id: 'u_501', buildingId: bMain, number: 501, floor: 5, ownerName: 'خانم سارا محمدی', phone: '09122223344', area: 115, residentCount: 2, parkingCount: 2, monthlyCharge: 1100000, meterNumber: '۳۳۱۰۵۳'),
      Unit(id: 'u_502', buildingId: bMain, number: 502, floor: 5, ownerName: 'آقای امیر عزیزی', phone: '09125556677', area: 108, residentCount: 4, parkingCount: 1, monthlyCharge: 950000, meterNumber: '۳۳۱۰۵۴'),
      // ساختمان دوم — همان کاربر ساکن، مالک واحد ۲ است (نمایش چندملکی)
      Unit(id: 'a_1', buildingId: bSecond, number: 1, floor: 1, ownerName: 'آقای کامران راد', phone: '09351112233', area: 76, residentCount: 2, parkingCount: 1, monthlyCharge: 600000),
      Unit(id: 'a_2', buildingId: bSecond, number: 2, floor: 1, ownerName: 'خانم زهرا حسینی', phone: '09129876543', area: 82, residentCount: 0, parkingCount: 1, isVacant: true, monthlyCharge: 600000),
      Unit(id: 'a_3', buildingId: bSecond, number: 3, floor: 2, ownerName: 'آقای نوید فرهادی', phone: '09361234567', area: 76, residentCount: 3, parkingCount: 1, monthlyCharge: 600000),
      Unit(id: 'a_4', buildingId: bSecond, number: 4, floor: 2, ownerName: 'خانم لیلا کاویانی', phone: '09371234567', area: 78, residentCount: 2, parkingCount: 0, monthlyCharge: 600000),
    ];

    // ---------- ارتباط کاربر ↔ واحد (جدول unit_users) ----------
    unitUsers = [
      UnitUser(
        id: 'uu_1',
        unitId: 'u_102',
        buildingId: bMain,
        userId: 'usr_resident',
        role: UnitRole.tenant,
        startDate: now.subtract(const Duration(days: 80)),
      ),
      UnitUser(
        id: 'uu_2',
        unitId: 'a_2',
        buildingId: bSecond,
        userId: 'usr_resident',
        role: UnitRole.owner,
        startDate: now.subtract(const Duration(days: 35)),
      ),
      UnitUser(
        id: 'uu_3',
        unitId: 'u_101',
        buildingId: bMain,
        userId: 'usr_manager',
        role: UnitRole.owner,
        startDate: now.subtract(const Duration(days: 90)),
      ),
    ];

    // ---------- فرمول شارژ (ماده ۴) ----------
    formulas = [
      ChargeFormula.defaults(bMain),
      ChargeFormula.defaults(bSecond),
    ];

    // ---------- صورتحساب‌ها ----------
    invoices = [];
    final period = currentPeriod;
    final formula = ChargeFormula.defaults(bMain);
    final mainUnits = units.where((u) => u.buildingId == bMain).toList();
    const seedStatuses = [
      InvoiceStatus.paid, InvoiceStatus.unpaid, InvoiceStatus.paid,
      InvoiceStatus.overdue, InvoiceStatus.paid, InvoiceStatus.overdue,
      InvoiceStatus.paid, InvoiceStatus.awaitingApproval, InvoiceStatus.paid,
      InvoiceStatus.unpaid,
    ];

    for (var i = 0; i < mainUnits.length; i++) {
      final u = mainUnits[i];
      final st = seedStatuses[i % seedStatuses.length];
      final bd = BillingEngine.calculateUnit(u, formula);
      invoices.add(Invoice(
        id: 'inv_charge_$i',
        buildingId: bMain,
        unitId: u.id,
        recipientRole: u.isVacant ? UnitRole.owner : UnitRole.tenant,
        kind: InvoiceKind.charge,
        title: 'شارژ ماهانه $period',
        period: period,
        amount: bd.total,
        status: st,
        method: st == InvoiceStatus.paid
            ? (i.isEven ? PayMethod.shaparak : PayMethod.cardToCard)
            : (st == InvoiceStatus.awaitingApproval
                ? PayMethod.cardToCard
                : PayMethod.none),
        billId: BillIdentifier.generateBillId(
            buildingId: bMain, unitNumber: u.number),
        paymentId: BillIdentifier.generatePaymentId(
            amount: bd.total, dueDate: now.add(const Duration(days: 10))),
        rrn: st == InvoiceStatus.paid && i.isEven ? '۹۰۲۳۴۵۶۷۸۹۰$i' : null,
        cardLast4:
            st == InvoiceStatus.awaitingApproval ? '۵۶۷۸' : null,
        receiptNote: st == InvoiceStatus.awaitingApproval
            ? 'کارت به کارت ساعت ۱۴:۳۰ انجام شد'
            : null,
        breakdown: bd.toBreakdownMap(),
        dueDate: now.add(const Duration(days: 10)),
        paidAt: st == InvoiceStatus.paid
            ? now.subtract(Duration(days: i + 2))
            : null,
        createdAt: now.subtract(const Duration(days: 5)),
      ));

      // صورتحساب آب (مصرفی → مستاجر)
      final wSt = i % 3 == 0 ? InvoiceStatus.paid : InvoiceStatus.unpaid;
      invoices.add(Invoice(
        id: 'inv_water_$i',
        buildingId: bMain,
        unitId: u.id,
        recipientRole: u.isVacant ? UnitRole.owner : UnitRole.tenant,
        kind: InvoiceKind.water,
        title: 'قبض آب $period',
        period: period,
        amount: 120000 + (i % 4) * 35000,
        status: wSt,
        method: wSt == InvoiceStatus.paid ? PayMethod.shaparak : PayMethod.none,
        billId: BillIdentifier.generateBillId(
            buildingId: bMain, unitNumber: u.number),
        paymentId: BillIdentifier.generatePaymentId(
            amount: 120000, dueDate: now.add(const Duration(days: 8))),
        dueDate: now.add(const Duration(days: 8)),
        paidAt: wSt == InvoiceStatus.paid
            ? now.subtract(Duration(days: i + 3))
            : null,
        createdAt: now.subtract(const Duration(days: 4)),
      ));

      // سهم تعمیر اساسی آسانسور (عمرانی → مالک)
      final rSt = i % 4 == 1 ? InvoiceStatus.unpaid : InvoiceStatus.paid;
      invoices.add(Invoice(
        id: 'inv_repair_$i',
        buildingId: bMain,
        unitId: u.id,
        recipientRole: UnitRole.owner,
        kind: InvoiceKind.repair,
        title: 'سهم تعمیر اساسی آسانسور',
        period: period,
        amount: 250000,
        status: rSt,
        method: rSt == InvoiceStatus.paid ? PayMethod.shaparak : PayMethod.none,
        billId: BillIdentifier.generateBillId(
            buildingId: bMain, unitNumber: u.number),
        paymentId: BillIdentifier.generatePaymentId(
            amount: 250000, dueDate: now.add(const Duration(days: 12))),
        dueDate: now.add(const Duration(days: 12)),
        paidAt: rSt == InvoiceStatus.paid
            ? now.subtract(Duration(days: i + 1))
            : null,
        createdAt: now.subtract(const Duration(days: 3)),
      ));
    }

    // صورتحساب ساختمان دوم برای واحد چندملکی
    invoices.add(Invoice(
      id: 'inv_argh_1',
      buildingId: bSecond,
      unitId: 'a_2',
      recipientRole: UnitRole.owner,
      kind: InvoiceKind.charge,
      title: 'شارژ ماهانه $period',
      period: period,
      amount: 480000,
      status: InvoiceStatus.unpaid,
      billId:
          BillIdentifier.generateBillId(buildingId: bSecond, unitNumber: 2),
      paymentId: BillIdentifier.generatePaymentId(
          amount: 480000, dueDate: now.add(const Duration(days: 7))),
      breakdown: const {'ثابت': 150000, 'متراژ': 328000, 'نفرات': 0},
      dueDate: now.add(const Duration(days: 7)),
      createdAt: now.subtract(const Duration(days: 2)),
    ));

    // ---------- هزینه‌های ثبت‌شده (Dual-Billing) ----------
    expenses = [
      Expense(
        id: 'exp_1',
        buildingId: bMain,
        title: 'تعویض گیربکس آسانسور',
        amount: 24_000_000,
        expenseType: ExpenseType.capital,
        category: ExpenseCategory.elevator,
        invoiceUrl: 'seed://invoice_elevator.webp',
        invoiceSizeBytes: 78 * 1024,
        date: now.subtract(const Duration(days: 12)),
        note: 'مصوبه مجمع عمومی — برداشت از صندوق ذخیره',
        isAllocated: true,
      ),
      Expense(
        id: 'exp_2',
        buildingId: bMain,
        title: 'قبض برق مشاعات',
        amount: 3_850_000,
        expenseType: ExpenseType.consumable,
        category: ExpenseCategory.utilities,
        invoiceUrl: 'seed://invoice_power.webp',
        invoiceSizeBytes: 64 * 1024,
        date: now.subtract(const Duration(days: 9)),
      ),
      Expense(
        id: 'exp_3',
        buildingId: bMain,
        title: 'حقوق نیروی خدماتی',
        amount: 9_200_000,
        expenseType: ExpenseType.consumable,
        category: ExpenseCategory.salary,
        date: now.subtract(const Duration(days: 7)),
      ),
      Expense(
        id: 'exp_4',
        buildingId: bMain,
        title: 'حق بیمه آتش‌سوزی سالانه',
        amount: 6_400_000,
        expenseType: ExpenseType.capital,
        category: ExpenseCategory.insurance,
        date: now.subtract(const Duration(days: 30)),
        note: 'الزام ماده ۱۴ قانون تملک آپارتمان‌ها',
      ),
      Expense(
        id: 'exp_5',
        buildingId: bSecond,
        title: 'نظافت ماهانه راه‌پله',
        amount: 1_200_000,
        expenseType: ExpenseType.consumable,
        category: ExpenseCategory.cleaning,
        date: now.subtract(const Duration(days: 5)),
      ),
    ];

    // ---------- بیمه‌نامه‌ها (ماده ۱۴) ----------
    policies = [
      InsurancePolicy(
        id: 'pol_1',
        buildingId: bMain,
        type: InsuranceType.fire,
        insurer: 'بیمه ایران',
        policyNumber: '۹۹۱۲۳۴۵۶۷',
        premium: 6_400_000,
        coverageAmount: 40_000_000_000,
        startDate: now.subtract(const Duration(days: 340)),
        endDate: now.add(const Duration(days: 25)),
        isAllocated: true,
        createdAt: now.subtract(const Duration(days: 340)),
      ),
      InsurancePolicy(
        id: 'pol_2',
        buildingId: bMain,
        type: InsuranceType.elevator,
        insurer: 'بیمه پاسارگاد',
        policyNumber: '۸۸۷۷۶۶۵۵',
        premium: 2_100_000,
        coverageAmount: 5_000_000_000,
        startDate: now.subtract(const Duration(days: 200)),
        endDate: now.add(const Duration(days: 165)),
        createdAt: now.subtract(const Duration(days: 200)),
      ),
    ];

    // ---------- پرونده‌های ماده ۱۰ مکرر ----------
    legalCases = [
      LegalCase(
        id: 'lc_1',
        buildingId: bMain,
        unitId: 'u_302',
        debtAmount: 3_600_000,
        invoiceIds: const ['inv_charge_5'],
        stage: LegalStage.internalWarning,
        warningServedAt: now.subtract(const Duration(days: 6)),
        note: 'اخطار داخلی از طریق اپلیکیشن ابلاغ شد',
        createdAt: now.subtract(const Duration(days: 8)),
      ),
      LegalCase(
        id: 'lc_2',
        buildingId: bMain,
        unitId: 'u_202',
        debtAmount: 5_150_000,
        invoiceIds: const ['inv_charge_3'],
        stage: LegalStage.formalNotice,
        warningServedAt: now.subtract(const Duration(days: 24)),
        noticeIssuedAt: now.subtract(const Duration(days: 13)),
        createdAt: now.subtract(const Duration(days: 26)),
      ),
    ];

    // ---------- رزرو مشاعات ----------
    amenityBookings = [
      AmenityBooking(
        id: 'ab_1',
        buildingId: bMain,
        unitId: 'u_401',
        amenityId: 'f_hall',
        amenityName: 'سالن اجتماعات',
        startTime: DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 3, hours: 18)),
        endTime: DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 3, hours: 22)),
        depositAmount: 500000,
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      AmenityBooking(
        id: 'ab_2',
        buildingId: bMain,
        unitId: 'u_201',
        amenityId: 'f_guest',
        amenityName: 'سوئیت مهمان',
        startTime: DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 6, hours: 14)),
        endTime: DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 7, hours: 12)),
        depositAmount: 800000,
        status: BookingStatus.pendingDeposit,
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
    ];

    // ---------- رأی‌گیری رسمی ----------
    polls = [
      Poll(
        id: 'poll_1',
        buildingId: bMain,
        title: 'نقاشی و بازسازی نمای ساختمان',
        description:
            'با توجه به فرسودگی نما، اجرای پروژه بازسازی با برآورد ۴۲۰ میلیون تومان از محل صندوق ذخیره پیشنهاد می‌شود.',
        method: VotingMethod.weighted,
        options: const [
          PollOption(id: 'o1', title: 'موافق اجرای پروژه'),
          PollOption(id: 'o2', title: 'مخالف اجرای پروژه'),
          PollOption(id: 'o3', title: 'موکول به مجمع بعدی'),
        ],
        status: PollStatus.active,
        ownersOnly: true,
        startsAt: now.subtract(const Duration(days: 2)),
        endsAt: now.add(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Poll(
        id: 'poll_2',
        buildingId: bMain,
        title: 'ساعت خاموشی روشنایی حیاط',
        description: 'انتخاب ساعت خاموش شدن چراغ‌های محوطه',
        method: VotingMethod.simple,
        options: const [
          PollOption(id: 'p2o1', title: 'ساعت ۲۳'),
          PollOption(id: 'p2o2', title: 'ساعت ۲۴'),
          PollOption(id: 'p2o3', title: 'تا صبح روشن بماند'),
        ],
        status: PollStatus.active,
        startsAt: now.subtract(const Duration(days: 1)),
        endsAt: now.add(const Duration(days: 9)),
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    votes = [
      Vote(id: 'v_1', pollId: 'poll_1', unitId: 'u_101', userId: 'usr_manager', optionId: 'o1', weight: 95, castAt: now.subtract(const Duration(days: 1))),
      Vote(id: 'v_2', pollId: 'poll_1', unitId: 'u_201', userId: 'usr_x1', optionId: 'o1', weight: 110, castAt: now.subtract(const Duration(days: 1))),
      Vote(id: 'v_3', pollId: 'poll_1', unitId: 'u_401', userId: 'usr_x2', optionId: 'o2', weight: 120, castAt: now.subtract(const Duration(hours: 20))),
      Vote(id: 'v_4', pollId: 'poll_2', unitId: 'u_102', userId: 'usr_resident', optionId: 'p2o2', weight: 1, castAt: now.subtract(const Duration(hours: 10))),
    ];

    // ---------- درخواست عضویت ----------
    membershipRequests = [
      MembershipRequest(
        id: 'mr_1',
        userId: 'usr_pending_1',
        userName: 'آقای سعید کاظمی',
        userPhone: '09135557788',
        buildingId: bMain,
        unitNumber: 302,
        requestedRole: UnitRole.owner,
        status: MembershipStatus.pending,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      MembershipRequest(
        id: 'mr_2',
        userId: 'usr_pending_2',
        userName: 'خانم نگار مرادی',
        userPhone: '09186664422',
        buildingId: bMain,
        unitNumber: 502,
        requestedRole: UnitRole.tenant,
        status: MembershipStatus.pending,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    // ---------- اطلاعیه‌ها ----------
    notices = [
      Notice(id: 'n_1', buildingId: bMain, title: 'جلسه مجمع عمومی ساختمان', body: 'جلسه مجمع عمومی سالانه روز جمعه ساعت ۱۷ در سالن اجتماعات برگزار می‌شود. حضور کلیه مالکین الزامی است. دستور جلسه: بررسی بیلان مالی، تصویب فرمول شارژ و تصمیم‌گیری درباره نمای ساختمان.', date: now.subtract(const Duration(hours: 5)), isImportant: true),
      Notice(id: 'n_2', buildingId: bMain, title: 'سرویس دوره‌ای آسانسور', body: 'سرویس و بازدید فنی آسانسورها روز شنبه از ساعت ۹ تا ۱۲ انجام می‌شود.', date: now.subtract(const Duration(days: 1))),
      Notice(id: 'n_3', buildingId: bMain, title: 'قطعی موقت آب ساختمان', body: 'به علت شستشوی مخزن، روز سه‌شنبه از ساعت ۱۰ تا ۱۳ آب ساختمان قطع خواهد بود.', date: now.subtract(const Duration(days: 2)), isImportant: true),
      Notice(id: 'n_4', buildingId: bMain, title: 'یادآوری پرداخت شارژ ماهانه', body: 'ساکنین محترم، صورتحساب ماه جاری از طریق اپلیکیشن قابل پرداخت است. امکان دریافت صورتحساب از طریق ایتا، بله، روبیکا و واتساپ فراهم شده است.', date: now.subtract(const Duration(days: 4))),
      Notice(id: 'n_5', buildingId: bSecond, title: 'نظافت هفتگی مشاعات', body: 'نظافت راه‌پله‌ها هر هفته شنبه و چهارشنبه انجام می‌شود.', date: now.subtract(const Duration(days: 6))),
    ];

    // ---------- درخواست تعمیرات ----------
    requests = [
      MaintenanceRequest(id: 'r_1', unitId: 'u_102', buildingId: bMain, title: 'نشتی آب از سقف سرویس بهداشتی', description: 'از دیروز آب از سقف سرویس بهداشتی چکه می‌کند.', category: 'تاسیسات', date: now.subtract(const Duration(hours: 8)), status: RequestStatus.pending),
      MaintenanceRequest(id: 'r_2', unitId: 'u_301', buildingId: bMain, title: 'خرابی چراغ راه‌پله طبقه سوم', description: 'چراغ راه‌پله سوخته و شب‌ها تاریک است.', category: 'برق', date: now.subtract(const Duration(days: 1)), status: RequestStatus.inProgress),
      MaintenanceRequest(id: 'r_3', unitId: 'u_401', buildingId: bMain, title: 'صدای غیرعادی آسانسور', description: 'آسانسور شماره ۱ هنگام حرکت صدای غیرعادی می‌دهد.', category: 'آسانسور', date: now.subtract(const Duration(days: 3)), status: RequestStatus.done),
      MaintenanceRequest(id: 'r_4', unitId: 'a_2', buildingId: bSecond, title: 'تنظیم درب پارکینگ', description: 'ریموت درب پارکینگ ضعیف عمل می‌کند.', category: 'تاسیسات', date: now.subtract(const Duration(days: 4)), status: RequestStatus.pending),
    ];
  }

  // =========================================================================
  // احراز هویت و جلسه (ورود صرفاً با شماره موبایل)
  // =========================================================================

  bool get isLoggedIn => currentUser != null;

  User? findUserByPhone(String phone) {
    final normalized = normalizePhone(phone);
    return users.where((u) => u.phone == normalized).firstOrNull;
  }

  /// نرمال‌سازی شماره موبایل (ارقام فارسی، +۹۸، ۹۸)
  String normalizePhone(String phone) {
    var p = phone.trim();
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (var i = 0; i < 10; i++) {
      p = p.replaceAll(fa[i], en[i]).replaceAll(ar[i], en[i]);
    }
    p = p.replaceAll(RegExp(r'[\s\-()]'), '');
    if (p.startsWith('+98')) p = '0${p.substring(3)}';
    if (p.startsWith('0098')) p = '0${p.substring(4)}';
    if (p.startsWith('98') && p.length == 12) p = '0${p.substring(2)}';
    if (p.length == 10 && p.startsWith('9')) p = '0$p';
    return p;
  }

  Future<void> signIn(User user) async {
    currentUser = user;
    activeBuildingId = user.buildingId;
    activeUnitId = user.unitId ?? myProperties.firstOrNull?.unitId;
    if (activeUnitId != null) {
      activeBuildingId =
          unitById(activeUnitId!)?.buildingId ?? activeBuildingId;
    }
    await _save();
    notifyListeners();
  }

  Future<void> signOut() async {
    currentUser = null;
    activeBuildingId = null;
    activeUnitId = null;
    await _save();
    notifyListeners();
  }

  // =========================================================================
  // ساختمان (تننت فعال)
  // =========================================================================

  Building? get currentBuilding => activeBuildingId == null
      ? null
      : buildings.where((b) => b.id == activeBuildingId).firstOrNull;

  Building? buildingById(String id) =>
      buildings.where((b) => b.id == id).firstOrNull;

  Building? findBuildingByInviteCode(String code) => buildings
      .where((b) => b.inviteCode.toUpperCase() == code.trim().toUpperCase())
      .firstOrNull;

  String _genInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// ثبت‌نام مدیر + ایجاد ساختمان + فعال‌سازی طرح
  ///
  /// اگر تعداد واحدها ≤ ۶ باشد طرح پایه رایگان دائمی فعال می‌شود و
  /// هیچ درخواست پرداختی به مدیر نمایش داده نمی‌شود (بند ۱ سند).
  Future<Building> registerManagerAndBuilding({
    required String managerName,
    required String phone,
    required String buildingName,
    required String city,
    required String address,
    required int unitsCount,
    PlanType? plan,
  }) async {
    final now = DateTime.now();
    final bId = 'b_${now.millisecondsSinceEpoch}';
    final resolvedPlan = plan ?? PlanTypeX.suggestFor(unitsCount);
    final normalized = normalizePhone(phone);

    final building = Building(
      id: bId,
      name: buildingName,
      address: address,
      city: city,
      unitsCount: unitsCount,
      managerPhone: normalized,
      managerName: managerName,
      inviteCode: _genInviteCode(),
      planType: resolvedPlan,
      maxAllowedUnits: resolvedPlan.maxUnits,
      subscriptionExpiry: resolvedPlan.isFree
          ? null
          : now.add(Duration(days: BillingCycle.monthly.days)),
      createdAt: now,
    );
    buildings.add(building);

    final user = User(
      id: 'usr_${now.millisecondsSinceEpoch}',
      phone: normalized,
      fullName: managerName,
      role: UserRole.manager,
      buildingId: bId,
      membershipStatus: MembershipStatus.active,
      unitRole: UnitRole.owner,
      createdAt: now,
    );
    users.add(user);

    subscriptions.add(resolvedPlan.isFree
        ? Subscription.freeForBuilding(bId, now: now)
        : Subscription(
            id: 'sub_${now.millisecondsSinceEpoch}',
            buildingId: bId,
            plan: resolvedPlan,
            startedAt: now,
            expiresAt: now.add(Duration(days: BillingCycle.monthly.days)),
            maxUnits: resolvedPlan.maxUnits,
          ));

    formulas.add(ChargeFormula.defaults(bId));

    // ساخت واحدهای اولیه خالی
    final floors = (unitsCount / 4).ceil().clamp(1, 50);
    var n = 0;
    for (var f = 1; f <= floors && n < unitsCount; f++) {
      for (var k = 1; k <= 4 && n < unitsCount; k++) {
        final num = f * 100 + k;
        units.add(Unit(
          id: '${bId}_u_$num',
          buildingId: bId,
          number: num,
          floor: f,
          ownerName: 'واحد $num',
          area: 0,
          isVacant: true,
        ));
        n++;
      }
    }

    currentUser = user;
    activeBuildingId = bId;
    activeUnitId = null;
    await _save();
    notifyListeners();
    return building;
  }

  /// ثبت اطلاعات پایه ساختمان توسط مدیر
  Future<void> updateBuildingInfo({
    String? name,
    String? address,
    String? city,
    String? managerName,
    String? iban,
    double? totalArea,
  }) async {
    final i = buildings.indexWhere((b) => b.id == activeBuildingId);
    if (i < 0) return;
    buildings[i] = buildings[i].copyWith(
      name: name,
      address: address,
      city: city,
      managerName: managerName,
      iban: iban,
      totalArea: totalArea,
    );
    await _save();
    notifyListeners();
  }

  /// ثبت/ویرایش اطلاعات کارت مقصد (کارت به کارت)
  Future<void> updateCardInfo(String cardNumber, String cardHolder) async {
    final i = buildings.indexWhere((b) => b.id == activeBuildingId);
    if (i < 0) return;
    buildings[i] = buildings[i].copyWith(
      cardNumber: cardNumber.trim(),
      cardHolder: cardHolder.trim(),
    );
    await _save();
    notifyListeners();
  }

  /// ثبت شبای مدیر برای تسویه مستقیم (Split Payment)
  Future<void> updateIban(String iban) async {
    final i = buildings.indexWhere((b) => b.id == activeBuildingId);
    if (i < 0) return;
    buildings[i] =
        buildings[i].copyWith(iban: iban.replaceAll(' ', '').toUpperCase());
    await _save();
    notifyListeners();
  }

  // =========================================================================
  // چندملکی — تعویض واحد/ساختمان فعال (گام ۴ سند)
  // =========================================================================

  /// همه واحدهایی که کاربر جاری در آن‌ها مالک یا مستاجر فعال است
  List<UnitUser> get myProperties {
    final u = currentUser;
    if (u == null) return [];
    final list = unitUsers
        .where((x) => x.userId == u.id && x.isActive && !x.isExpired)
        .toList();
    // اطمینان از حضور واحد اصلی پروفایل در فهرست
    if (u.unitId != null && !list.any((x) => x.unitId == u.unitId)) {
      final unit = unitById(u.unitId!);
      if (unit != null) {
        list.add(UnitUser(
          id: 'virtual_${unit.id}',
          unitId: unit.id,
          buildingId: unit.buildingId,
          userId: u.id,
          role: u.unitRole,
          startDate: u.createdAt,
        ));
      }
    }
    return list;
  }

  /// کاربر بیش از یک ملک دارد؟ (نمایش منوی تعویض ملک)
  bool get hasMultipleProperties => myProperties.length > 1;

  /// واحد فعال کاربر
  Unit? get currentUnit {
    if (activeUnitId != null) {
      final u = unitById(activeUnitId!);
      if (u != null) return u;
    }
    final first = myProperties.firstOrNull;
    if (first != null) return unitById(first.unitId);
    final uid = currentUser?.unitId;
    return uid == null ? null : unitById(uid);
  }

  /// نقش کاربر جاری در واحد فعال (مالک/مستاجر)
  UnitRole get currentUnitRole {
    final unit = currentUnit;
    if (unit == null) return currentUser?.unitRole ?? UnitRole.tenant;
    final link = myProperties.where((x) => x.unitId == unit.id).firstOrNull;
    return link?.role ?? currentUser?.unitRole ?? UnitRole.tenant;
  }

  /// تعویض ملک فعال — ساختمان فعال نیز همگام می‌شود
  Future<void> switchProperty(String unitId) async {
    final unit = unitById(unitId);
    if (unit == null) return;
    activeUnitId = unit.id;
    activeBuildingId = unit.buildingId;
    await _save();
    notifyListeners();
  }

  /// افزودن ملک جدید به کاربر جاری (مثلاً واحد در ساختمان دیگر)
  Future<bool> attachProperty({
    required String inviteCode,
    required int unitNumber,
    required UnitRole role,
  }) async {
    final user = currentUser;
    if (user == null) return false;
    final building = findBuildingByInviteCode(inviteCode);
    if (building == null) return false;
    final unit = units
        .where((u) => u.buildingId == building.id && u.number == unitNumber)
        .firstOrNull;
    if (unit == null) return false;
    if (unitUsers.any((x) => x.userId == user.id && x.unitId == unit.id)) {
      return false;
    }
    unitUsers.add(UnitUser(
      id: _id('uu'),
      unitId: unit.id,
      buildingId: building.id,
      userId: user.id,
      role: role,
      startDate: DateTime.now(),
    ));
    await _save();
    notifyListeners();
    return true;
  }

  // =========================================================================
  // عضویت ساکنین (درخواست → تایید مدیر)
  // =========================================================================

  Future<MembershipRequest?> submitMembershipRequest({
    required String name,
    required String phone,
    required String inviteCode,
    required int unitNumber,
    required UnitRole requestedRole,
  }) async {
    final building = findBuildingByInviteCode(inviteCode);
    if (building == null) return null;

    final unit = units
        .where((u) => u.buildingId == building.id && u.number == unitNumber)
        .firstOrNull;
    if (unit == null) return null;

    final now = DateTime.now();
    final normalized = normalizePhone(phone);

    var user = findUserByPhone(normalized);
    if (user == null) {
      user = User(
        id: 'usr_${now.millisecondsSinceEpoch}',
        phone: normalized,
        fullName: name,
        role: UserRole.resident,
        buildingId: building.id,
        membershipStatus: MembershipStatus.pending,
        unitRole: requestedRole,
        createdAt: now,
      );
      users.add(user);
    }

    final request = MembershipRequest(
      id: 'mr_${now.millisecondsSinceEpoch}',
      userId: user.id,
      userName: name,
      userPhone: normalized,
      buildingId: building.id,
      unitNumber: unit.number,
      requestedRole: requestedRole,
      status: MembershipStatus.pending,
      createdAt: now,
    );
    membershipRequests.insert(0, request);

    currentUser = user;
    activeBuildingId = building.id;
    await _save();
    notifyListeners();
    return request;
  }

  List<MembershipRequest> get buildingMembershipRequests => membershipRequests
      .where((r) => r.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get pendingMembershipCount => buildingMembershipRequests
      .where((r) => r.status == MembershipStatus.pending)
      .length;

  MembershipRequest? get myMembershipRequest {
    final u = currentUser;
    if (u == null) return null;
    final list = membershipRequests.where((r) => r.userId == u.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.firstOrNull;
  }

  /// تایید عضویت — رکورد unit_users ساخته می‌شود (نقش مالک/مستاجر)
  Future<void> approveMembership(String requestId) async {
    final i = membershipRequests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    final req = membershipRequests[i];

    final unit = units
        .where((u) =>
            u.buildingId == req.buildingId && u.number == req.unitNumber)
        .firstOrNull;
    if (unit == null) return;

    final now = DateTime.now();
    membershipRequests[i] = req.copyWith(
      status: MembershipStatus.active,
      resolvedAt: now,
    );

    if (!unitUsers.any(
        (x) => x.userId == req.userId && x.unitId == unit.id && x.isActive)) {
      unitUsers.add(UnitUser(
        id: _id('uu'),
        unitId: unit.id,
        buildingId: req.buildingId,
        userId: req.userId,
        role: req.requestedRole,
        startDate: now,
      ));
    }

    final ui = users.indexWhere((u) => u.id == req.userId);
    if (ui >= 0) {
      users[ui] = users[ui].copyWith(
        buildingId: req.buildingId,
        unitId: unit.id,
        membershipStatus: MembershipStatus.active,
        unitRole: req.requestedRole,
      );
      if (currentUser?.id == req.userId) {
        currentUser = users[ui];
        activeUnitId = unit.id;
      }
    }

    // واحد از حالت خالی خارج می‌شود
    final unitIdx = units.indexWhere((u) => u.id == unit.id);
    if (unitIdx >= 0 && units[unitIdx].isVacant) {
      units[unitIdx] = units[unitIdx].copyWith(
        isVacant: false,
        residentCount: units[unitIdx].residentCount == 0
            ? 1
            : units[unitIdx].residentCount,
      );
    }

    await _save();
    notifyListeners();
  }

  Future<void> rejectMembership(String requestId) async {
    final i = membershipRequests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    membershipRequests[i] = membershipRequests[i].copyWith(
      status: MembershipStatus.rejected,
      resolvedAt: DateTime.now(),
    );
    final ui = users.indexWhere((u) => u.id == membershipRequests[i].userId);
    if (ui >= 0) {
      users[ui] =
          users[ui].copyWith(membershipStatus: MembershipStatus.rejected);
      if (currentUser?.id == users[ui].id) currentUser = users[ui];
    }
    await _save();
    notifyListeners();
  }

  /// حذف اتصال کاربر از واحد
  Future<void> detachUserFromUnit(String userId, {String? unitId}) async {
    unitUsers.removeWhere((x) =>
        x.userId == userId && (unitId == null || x.unitId == unitId));
    final ui = users.indexWhere((u) => u.id == userId);
    if (ui >= 0) {
      users[ui] = users[ui].copyWith(
        clearUnit: true,
        membershipStatus: MembershipStatus.none,
      );
      if (currentUser?.id == userId) {
        currentUser = users[ui];
        activeUnitId = null;
      }
    }
    await _save();
    notifyListeners();
  }

  /// اعضای فعال هر واحد
  List<User> usersOfUnit(String unitId) {
    final ids = unitUsers
        .where((x) => x.unitId == unitId && x.isActive && !x.isExpired)
        .map((x) => x.userId)
        .toSet();
    final list = users.where((u) => ids.contains(u.id)).toList();
    for (final u in users) {
      if (u.unitId == unitId &&
          u.membershipStatus == MembershipStatus.active &&
          !list.any((x) => x.id == u.id)) {
        list.add(u);
      }
    }
    return list;
  }

  /// نقش یک کاربر در یک واحد
  UnitRole roleOfUserInUnit(String userId, String unitId) =>
      unitUsers
          .where((x) => x.userId == userId && x.unitId == unitId)
          .firstOrNull
          ?.role ??
      users.where((u) => u.id == userId).firstOrNull?.unitRole ??
      UnitRole.tenant;

  /// واحد مستاجر دارد؟ (مبنای Dual-Billing)
  bool unitHasTenant(String unitId) => unitUsers.any((x) =>
      x.unitId == unitId &&
      x.role == UnitRole.tenant &&
      x.isActive &&
      !x.isExpired);

  // =========================================================================
  // مدیریت واحدها + سقف طرح رایگان (بند ۱ سند)
  // =========================================================================

  List<Unit> get buildingUnits => units
      .where((u) => u.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => a.number.compareTo(b.number));

  Unit? unitById(String id) => units.where((u) => u.id == id).firstOrNull;

  int get totalUnits => buildingUnits.length;
  int get occupiedUnits => buildingUnits.where((u) => !u.isVacant).length;
  int get vacantUnits => buildingUnits.where((u) => u.isVacant).length;

  double get buildingTotalArea {
    final b = currentBuilding;
    final sum = buildingUnits.fold<double>(0, (s, u) => s + u.area);
    if (sum > 0) return sum;
    return b?.totalArea ?? 0;
  }

  /// سقف واحد طرح فعال ساختمان جاری
  int get unitLimit =>
      currentSubscription?.plan.maxUnits ??
      currentBuilding?.maxAllowedUnits ??
      freeUnitLimit;

  /// افزودن واحد جدید مجاز است؟ (اگر false باشد باید دیالوگ ارتقا نمایش شود)
  bool get canAddUnit => totalUnits < unitLimit;

  /// طرحی که برای تعداد واحد فعلی + یکی لازم است
  PlanType get requiredPlanForNextUnit =>
      PlanTypeX.suggestFor(totalUnits + 1);

  /// افزودن واحد — در صورت عبور از سقف طرح، null برمی‌گرداند
  /// تا UI دیالوگ «ارتقا به طرح اقتصادی» را نمایش دهد (گام ۷ سند).
  Future<Unit?> addUnit({
    required int number,
    required int floor,
    required String ownerName,
    String phone = '',
    double area = 0,
    int residentCount = 0,
    int parkingCount = 0,
    bool isVacant = false,
    String meterNumber = '',
    int fixedExtra = 0,
  }) async {
    if (!canAddUnit) return null;
    final bId = activeBuildingId;
    if (bId == null) return null;
    if (buildingUnits.any((u) => u.number == number)) return null;

    final unit = Unit(
      id: _id('unit'),
      buildingId: bId,
      number: number,
      floor: floor,
      ownerName: ownerName,
      phone: normalizePhone(phone),
      area: area,
      residentCount: residentCount,
      parkingCount: parkingCount,
      isVacant: isVacant || residentCount == 0,
      meterNumber: meterNumber,
      fixedExtra: fixedExtra,
    );
    units.add(unit);
    await _syncBuildingUnitStats();
    await _save();
    notifyListeners();
    return unit;
  }

  /// ویرایش مشخصات واحد (متراژ، نفرات، پارکینگ، خالی بودن)
  Future<void> updateUnit(
    String unitId, {
    String? ownerName,
    String? phone,
    double? area,
    int? residentCount,
    int? parkingCount,
    bool? isVacant,
    int? monthlyCharge,
    String? meterNumber,
    int? fixedExtra,
  }) async {
    final i = units.indexWhere((u) => u.id == unitId);
    if (i < 0) return;
    units[i] = units[i].copyWith(
      ownerName: ownerName,
      phone: phone == null ? null : normalizePhone(phone),
      area: area,
      residentCount: residentCount,
      parkingCount: parkingCount,
      isVacant: isVacant,
      monthlyCharge: monthlyCharge,
      meterNumber: meterNumber,
      fixedExtra: fixedExtra,
    );
    await _syncBuildingUnitStats();
    await _save();
    notifyListeners();
  }

  Future<void> deleteUnit(String unitId) async {
    units.removeWhere((u) => u.id == unitId);
    unitUsers.removeWhere((x) => x.unitId == unitId);
    invoices.removeWhere((i) => i.unitId == unitId);
    await _syncBuildingUnitStats();
    await _save();
    notifyListeners();
  }

  Future<void> _syncBuildingUnitStats() async {
    final i = buildings.indexWhere((b) => b.id == activeBuildingId);
    if (i < 0) return;
    final list = units.where((u) => u.buildingId == activeBuildingId);
    buildings[i] = buildings[i].copyWith(
      unitsCount: list.length,
      totalArea: list.fold<double>(0, (s, u) => s + u.area),
    );
  }

  // =========================================================================
  // اشتراک و طرح‌ها (Freemium)
  // =========================================================================

  Subscription? get currentSubscription {
    final bId = activeBuildingId;
    if (bId == null) return null;
    final list = subscriptions.where((s) => s.buildingId == bId).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list.firstOrNull;
  }

  PlanType get currentPlan =>
      currentSubscription?.plan ?? currentBuilding?.planType ?? PlanType.free;

  /// در طرح رایگان هیچ درخواست پرداختی نمایش داده نمی‌شود
  bool get isFreePlan => currentPlan.isFree;

  /// اشتراک منقضی شده و نیاز به تمدید دارد؟
  bool get subscriptionExpired {
    final s = currentSubscription;
    if (s == null) return false;
    return !s.isActive;
  }

  /// فعال‌سازی/ارتقای اشتراک پس از پرداخت موفق
  Future<Subscription> activateSubscription(
    PlanType plan, {
    BillingCycle cycle = BillingCycle.monthly,
    String? paymentRef,
  }) async {
    final bId = activeBuildingId!;
    final now = DateTime.now();
    final expiry = plan.isFree
        ? now.add(const Duration(days: 36500))
        : now.add(Duration(days: cycle.days));

    final sub = Subscription(
      id: _id('sub'),
      buildingId: bId,
      plan: plan,
      startedAt: now,
      expiresAt: expiry,
      cycle: cycle,
      maxUnits: plan.maxUnits,
      paidAmount: plan.priceFor(cycle),
      paymentRef: paymentRef,
    );
    subscriptions.add(sub);

    final i = buildings.indexWhere((b) => b.id == bId);
    if (i >= 0) {
      buildings[i] = buildings[i].copyWith(
        planType: plan,
        maxAllowedUnits: plan.maxUnits,
        subscriptionExpiry: plan.isFree ? null : expiry,
      );
    }
    await _save();
    notifyListeners();
    return sub;
  }

  /// خرید بسته پیامک — تنها حالتی که هزینه پیامک وجود دارد
  /// (ساختمان‌هایی که بر ارسال پیامک سیستمی اصرار دارند)
  Future<void> addSmsCredit(int count) async {
    final i = buildings.indexWhere((b) => b.id == activeBuildingId);
    if (i < 0) return;
    buildings[i] =
        buildings[i].copyWith(smsCredit: buildings[i].smsCredit + count);
    await _save();
    notifyListeners();
  }

  // =========================================================================
  // فرمول شارژ (ماده ۴) و صدور دسته‌ای صورتحساب
  // =========================================================================

  ChargeFormula get currentFormula {
    final bId = activeBuildingId ?? '';
    return formulas.where((f) => f.buildingId == bId).firstOrNull ??
        ChargeFormula.defaults(bId);
  }

  Future<void> saveFormula(ChargeFormula formula) async {
    final i = formulas.indexWhere((f) => f.buildingId == formula.buildingId);
    if (i >= 0) {
      formulas[i] = formula;
    } else {
      formulas.add(formula);
    }
    await _save();
    notifyListeners();
  }

  /// پیش‌نمایش محاسبه شارژ همه واحدها بدون ذخیره
  ///
  /// معادل: POST /api/v1/manager/charge/batch-calculate
  BatchChargeResult previewBatchCharge({ChargeFormula? formula}) =>
      BillingEngine.calculateBatch(
        buildingId: activeBuildingId ?? '',
        period: currentPeriod,
        units: buildingUnits,
        formula: formula ?? currentFormula,
      );

  /// محاسبه شارژ یک واحد با تفکیک اجزا
  ChargeBreakdown breakdownOf(Unit unit, {ChargeFormula? formula}) =>
      BillingEngine.calculateUnit(unit, formula ?? currentFormula);

  /// صدور دسته‌ای صورتحساب شارژ ماهانه برای همه واحدها
  Future<List<Invoice>> issueMonthlyCharges({
    String? period,
    DateTime? dueDate,
    ChargeFormula? formula,
    List<String>? onlyUnitIds,
  }) async {
    final bId = activeBuildingId;
    if (bId == null) return [];
    final f = formula ?? currentFormula;
    final p = period ?? currentPeriod;
    final due = dueDate ?? DateTime.now().add(const Duration(days: 10));
    final now = DateTime.now();

    final targets = buildingUnits
        .where((u) => onlyUnitIds == null || onlyUnitIds.contains(u.id))
        .toList();

    final created = <Invoice>[];
    for (final u in targets) {
      // جلوگیری از صدور تکراری برای همان دوره
      final exists = invoices.any((i) =>
          i.unitId == u.id &&
          i.kind == InvoiceKind.charge &&
          i.period == p);
      if (exists) continue;

      final bd = BillingEngine.calculateUnit(u, f);
      if (bd.total <= 0) continue;

      final inv = Invoice(
        id: _id('inv'),
        buildingId: bId,
        unitId: u.id,
        recipientRole: BillingEngine.resolveChargeRecipient(
          unit: u,
          unitHasTenant: unitHasTenant(u.id),
        ),
        kind: InvoiceKind.charge,
        title: 'شارژ ماهانه $p',
        period: p,
        amount: bd.total,
        status: InvoiceStatus.unpaid,
        billId: BillIdentifier.generateBillId(
            buildingId: bId, unitNumber: u.number),
        paymentId:
            BillIdentifier.generatePaymentId(amount: bd.total, dueDate: due),
        breakdown: bd.toBreakdownMap(),
        dueDate: due,
        createdAt: now,
      );
      invoices.add(inv);
      created.add(inv);
    }
    await _save();
    notifyListeners();
    return created;
  }

  /// صدور صورتحساب دلخواه برای واحدهای انتخاب‌شده
  Future<List<Invoice>> createInvoices({
    required InvoiceKind kind,
    required String title,
    required int amount,
    required List<String> unitIds,
    UnitRole? recipientRole,
    String? period,
    DateTime? dueDate,
    Map<String, int> breakdown = const {},
  }) async {
    final bId = activeBuildingId;
    if (bId == null) return [];
    final now = DateTime.now();
    final due = dueDate ?? now.add(const Duration(days: 10));
    final p = period ?? currentPeriod;

    final created = <Invoice>[];
    for (final uid in unitIds) {
      final unit = unitById(uid);
      if (unit == null) continue;
      final inv = Invoice(
        id: _id('inv_$uid'),
        buildingId: bId,
        unitId: uid,
        recipientRole: recipientRole ??
            BillingEngine.resolveChargeRecipient(
              unit: unit,
              unitHasTenant: unitHasTenant(uid),
            ),
        kind: kind,
        title: title,
        period: p,
        amount: amount,
        status: InvoiceStatus.unpaid,
        billId: BillIdentifier.generateBillId(
            buildingId: bId, unitNumber: unit.number),
        paymentId:
            BillIdentifier.generatePaymentId(amount: amount, dueDate: due),
        breakdown: breakdown,
        dueDate: due,
        createdAt: now,
      );
      invoices.add(inv);
      created.add(inv);
    }
    await _save();
    notifyListeners();
    return created;
  }

  Future<void> deleteInvoice(String id) async {
    invoices.removeWhere((i) => i.id == id);
    await _save();
    notifyListeners();
  }

  // =========================================================================
  // هزینه‌ها و سرشکن (Dual-Billing)
  // =========================================================================

  List<Expense> get buildingExpenses => expenses
      .where((e) => e.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  List<Expense> expensesOfType(ExpenseType type) =>
      buildingExpenses.where((e) => e.expenseType == type).toList();

  /// ثبت هزینه جدید — تصویر فاکتور از قبل در سمت کلاینت فشرده شده است
  Future<Expense?> addExpense({
    required String title,
    required int amount,
    required ExpenseType expenseType,
    ExpenseCategory category = ExpenseCategory.other,
    String? invoiceUrl,
    int? invoiceSizeBytes,
    DateTime? date,
    String? note,
  }) async {
    final bId = activeBuildingId;
    if (bId == null) return null;
    final exp = Expense(
      id: _id('exp'),
      buildingId: bId,
      title: title,
      amount: amount,
      expenseType: expenseType,
      category: category,
      invoiceUrl: invoiceUrl,
      invoiceSizeBytes: invoiceSizeBytes,
      date: date ?? DateTime.now(),
      note: note,
    );
    expenses.add(exp);
    await _save();
    notifyListeners();
    return exp;
  }

  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  /// سرشکن یک هزینه بین واحدها و صدور صورتحساب مطابق ماهیت هزینه
  ///
  /// • CAPITAL (عمرانی)  → به نسبت متراژ، به نام مالک
  /// • CONSUMABLE (مصرفی) → به نسبت نفرات، به نام مستاجر
  Future<List<Invoice>> allocateExpenseToUnits(
    String expenseId, {
    DateTime? dueDate,
  }) async {
    final exp = expenses.where((e) => e.id == expenseId).firstOrNull;
    if (exp == null || exp.isAllocated) return [];

    final shares = BillingEngine.allocateExpense(
      expense: exp,
      units: buildingUnits,
    );
    if (shares.isEmpty) return [];

    final now = DateTime.now();
    final due = dueDate ?? now.add(const Duration(days: 15));
    final kind = exp.category == ExpenseCategory.insurance
        ? InvoiceKind.insurance
        : (exp.expenseType == ExpenseType.capital
            ? InvoiceKind.repair
            : InvoiceKind.other);

    final created = <Invoice>[];
    shares.forEach((unitId, amount) {
      if (amount <= 0) return;
      final unit = unitById(unitId);
      if (unit == null) return;
      final role = BillingEngine.resolveRecipient(
        expenseType: exp.expenseType,
        unitHasTenant: unitHasTenant(unitId),
      );
      final inv = Invoice(
        id: _id('inv_alloc_$unitId'),
        buildingId: exp.buildingId,
        unitId: unitId,
        recipientRole: role,
        kind: kind,
        title: 'سهم ${exp.title}',
        period: currentPeriod,
        amount: amount,
        status: InvoiceStatus.unpaid,
        billId: BillIdentifier.generateBillId(
            buildingId: exp.buildingId, unitNumber: unit.number),
        paymentId:
            BillIdentifier.generatePaymentId(amount: amount, dueDate: due),
        breakdown: {exp.expenseType.shortLabel: amount},
        dueDate: due,
        createdAt: now,
      );
      invoices.add(inv);
      created.add(inv);
    });

    final ei = expenses.indexWhere((e) => e.id == expenseId);
    if (ei >= 0) expenses[ei] = expenses[ei].copyWith(isAllocated: true);

    await _save();
    notifyListeners();
    return created;
  }

  // =========================================================================
  // صورتحساب‌ها — کوئری‌های اسکوپ‌شده
  // =========================================================================

  List<Invoice> get buildingInvoices => invoices
      .where((i) => i.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Invoice> invoicesOfUnit(String unitId) => invoices
      .where((i) => i.unitId == unitId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Invoice> currentPeriodInvoicesOfUnit(String unitId) => invoices
      .where((i) => i.unitId == unitId && i.period == currentPeriod)
      .toList()
    ..sort((a, b) => a.kind.index.compareTo(b.kind.index));

  /// صورتحساب‌های قابل پرداخت واحد فعال کاربر با توجه به نقش او
  ///
  /// مستاجر فقط صورتحساب مصرفی و مالک فقط صورتحساب عمرانی خود را
  /// می‌بیند (تفکیک تعهدات مالک و مستاجر).
  List<Invoice> get myInvoices {
    final unit = currentUnit;
    if (unit == null) return [];
    final role = currentUnitRole;
    return invoicesOfUnit(unit.id)
        .where((i) => i.recipientRole == role)
        .toList();
  }

  List<Invoice> get myCurrentPeriodInvoices {
    final unit = currentUnit;
    if (unit == null) return [];
    final role = currentUnitRole;
    return currentPeriodInvoicesOfUnit(unit.id)
        .where((i) => i.recipientRole == role)
        .toList();
  }

  Invoice? invoiceById(String id) =>
      invoices.where((i) => i.id == id).firstOrNull;

  List<Invoice> get awaitingApprovalInvoices => buildingInvoices
      .where((i) => i.status == InvoiceStatus.awaitingApproval)
      .toList();

  int get awaitingApprovalCount => awaitingApprovalInvoices.length;

  List<Invoice> get currentPeriodInvoices =>
      buildingInvoices.where((i) => i.period == currentPeriod).toList();

  /// بدهی معوق واحد (مبنای پرونده ماده ۱۰ مکرر)
  int debtOfUnit(String unitId) =>
      BillingEngine.outstandingDebt(unitId, invoices);

  int get myDebt {
    final unit = currentUnit;
    if (unit == null) return 0;
    return BillingEngine.outstandingDebtForRole(
      unitId: unit.id,
      role: currentUnitRole,
      invoices: invoices,
    );
  }

  // =========================================================================
  // پرداخت — درگاه شاپرک و کارت به کارت (گام ۲ سند)
  // بدون هیچ سازوکار برداشت خودکار
  // =========================================================================

  /// شروع پرداخت آنلاین از طریق درگاه شاپرک
  ///
  /// کارمزد درگاه بر عهده پرداخت‌کننده است یا از تسویه مدیر کسر می‌شود؛
  /// در هیچ حالتی بر عهده مالک نرم‌افزار نیست.
  Future<GatewayResult> startOnlinePayment(
    String invoiceId, {
    FeePayer feePayer = FeePayer.payer,
  }) async {
    final inv = invoiceById(invoiceId);
    final building = inv == null ? null : buildingById(inv.buildingId);
    if (inv == null || building == null) {
      return const GatewayResult(
          success: false, message: 'صورتحساب یافت نشد');
    }
    return PaymentGateway.instance.initiate(
      invoice: inv,
      iban: building.iban,
      feePayer: feePayer,
    );
  }

  /// تایید نهایی پرداخت پس از بازگشت از درگاه (Verify)
  ///
  /// در صورت موفقیت وضعیت PAID و شماره پیگیری (RRN) ذخیره می‌شود.
  Future<GatewayResult> verifyOnlinePayment({
    required String invoiceId,
    required String authority,
  }) async {
    final inv = invoiceById(invoiceId);
    if (inv == null) {
      return const GatewayResult(
          success: false, message: 'صورتحساب یافت نشد');
    }
    final result = await PaymentGateway.instance.verify(
      invoice: inv,
      authority: authority,
    );
    if (result.success) {
      final i = invoices.indexWhere((x) => x.id == invoiceId);
      if (i >= 0) {
        invoices[i] = invoices[i].copyWith(
          status: InvoiceStatus.paid,
          method: PayMethod.shaparak,
          rrn: result.rrn,
          cardLast4: result.cardLast4,
          paidAt: DateTime.now(),
          clearRejection: true,
        );
      }
      await _creditFund(inv.amount);
      await _resolveLegalCaseIfSettled(inv.unitId);
      await _save();
      notifyListeners();
    }
    return result;
  }

  /// ثبت رسید کارت به کارت / نقدی توسط ساکن → در انتظار تایید مدیر
  Future<void> submitOfflineReceipt({
    required String invoiceId,
    required String cardLast4,
    String? receiptUrl,
    String? note,
    PayMethod method = PayMethod.cardToCard,
  }) async {
    final i = invoices.indexWhere((x) => x.id == invoiceId);
    if (i < 0) return;
    invoices[i] = invoices[i].copyWith(
      status: InvoiceStatus.awaitingApproval,
      method: method,
      cardLast4: cardLast4.trim(),
      receiptUrl: receiptUrl,
      receiptNote: note?.trim(),
      clearRejection: true,
    );
    await _save();
    notifyListeners();
  }

  /// تایید یک‌کلیکی رسید توسط مدیر
  Future<void> approveInvoice(String invoiceId) async {
    final i = invoices.indexWhere((x) => x.id == invoiceId);
    if (i < 0) return;
    invoices[i] = invoices[i].copyWith(
      status: InvoiceStatus.paid,
      paidAt: DateTime.now(),
      clearRejection: true,
    );
    await _creditFund(invoices[i].amount);
    await _resolveLegalCaseIfSettled(invoices[i].unitId);
    await _save();
    notifyListeners();
  }

  /// رد رسید توسط مدیر با ذکر دلیل
  Future<void> rejectInvoice(String invoiceId, String reason) async {
    final i = invoices.indexWhere((x) => x.id == invoiceId);
    if (i < 0) return;
    invoices[i] = invoices[i].copyWith(
      status: InvoiceStatus.rejected,
      rejectionReason: reason.trim(),
    );
    await _save();
    notifyListeners();
  }

  /// واریز مبلغ وصول‌شده به صندوق‌ها بر اساس درصد مصوب ذخیره
  Future<void> _creditFund(int amount) async {
    final i = buildings.indexWhere((b) => b.id == activeBuildingId);
    if (i < 0) return;
    final pct = currentFormula.reserveFundPercent.clamp(0, 100);
    final reserve = (amount * pct / 100).round();
    buildings[i] = buildings[i].copyWith(
      currentBalance: buildings[i].currentBalance + (amount - reserve),
      reserveBalance: buildings[i].reserveBalance + reserve,
    );
  }

  // =========================================================================
  // ماده ۱۰ مکرر — وصول مطالبات و قطع خدمات مشترک
  // =========================================================================

  List<LegalCase> get buildingLegalCases => legalCases
      .where((c) => c.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<LegalCase> get openLegalCases =>
      buildingLegalCases.where((c) => !c.isResolved).toList();

  LegalCase? legalCaseOfUnit(String unitId) => legalCases
      .where((c) => c.unitId == unitId && !c.isResolved)
      .firstOrNull;

  /// واحدهای بدهکار که واجد شرایط تشکیل پرونده هستند
  List<Unit> get delinquentUnits => buildingUnits
      .where((u) => debtOfUnit(u.id) > 0)
      .toList()
    ..sort((a, b) => debtOfUnit(b.id).compareTo(debtOfUnit(a.id)));

  /// تشکیل پرونده مطالبات برای واحد بدهکار
  Future<LegalCase?> openLegalCase(String unitId) async {
    final bId = activeBuildingId;
    if (bId == null) return null;
    final existing = legalCaseOfUnit(unitId);
    if (existing != null) return existing;

    final debt = debtOfUnit(unitId);
    if (debt <= 0) return null;

    final c = LegalCase(
      id: _id('lc'),
      buildingId: bId,
      unitId: unitId,
      debtAmount: debt,
      invoiceIds: invoices
          .where((i) => i.unitId == unitId && i.status.isDebt)
          .map((i) => i.id)
          .toList(),
      stage: LegalStage.none,
      createdAt: DateTime.now(),
    );
    legalCases.add(c);
    await _save();
    notifyListeners();
    return c;
  }

  /// ثبت ابلاغ اخطار داخلی در اپلیکیشن (تاریخ ابلاغ ذخیره می‌شود)
  Future<void> serveInternalWarning(String caseId) async {
    final i = legalCases.indexWhere((c) => c.id == caseId);
    if (i < 0) return;
    legalCases[i] = legalCases[i].copyWith(
      stage: LegalStage.internalWarning,
      warningServedAt: DateTime.now(),
    );
    await _save();
    notifyListeners();
  }

  /// صدور اظهارنامه رسمی ۱۰ روزه (شروع مهلت قانونی)
  Future<void> issueFormalNotice(String caseId) async {
    final i = legalCases.indexWhere((c) => c.id == caseId);
    if (i < 0) return;
    legalCases[i] = legalCases[i].copyWith(
      stage: LegalStage.formalNotice,
      noticeIssuedAt: DateTime.now(),
    );
    await _save();
    notifyListeners();
  }

  /// ثبت قطع خدمات مشترک — تنها پس از انقضای مهلت ۱۰ روزه مجاز است
  Future<bool> recordServiceCutoff({
    required String caseId,
    required List<SharedService> services,
    List<String> documentUrls = const [],
    String? note,
  }) async {
    final i = legalCases.indexWhere((c) => c.id == caseId);
    if (i < 0) return false;
    if (!legalCases[i].canCutServices) return false;

    legalCases[i] = legalCases[i].copyWith(
      stage: LegalStage.serviceCutoff,
      cutoffAt: DateTime.now(),
      cutServices: services,
      documentUrls: [...legalCases[i].documentUrls, ...documentUrls],
      note: note,
    );
    await _save();
    notifyListeners();
    return true;
  }

  /// ارجاع پرونده به مراجع قضایی
  Future<void> escalateToJudicial(String caseId,
      {List<String> documentUrls = const []}) async {
    final i = legalCases.indexWhere((c) => c.id == caseId);
    if (i < 0) return;
    legalCases[i] = legalCases[i].copyWith(
      stage: LegalStage.judicial,
      documentUrls: [...legalCases[i].documentUrls, ...documentUrls],
    );
    await _save();
    notifyListeners();
  }

  /// افزودن مستند به پرونده (تصویر اظهارنامه، صورتجلسه قطع خدمات، ...)
  Future<void> attachLegalDocument(String caseId, String url) async {
    final i = legalCases.indexWhere((c) => c.id == caseId);
    if (i < 0) return;
    legalCases[i] = legalCases[i]
        .copyWith(documentUrls: [...legalCases[i].documentUrls, url]);
    await _save();
    notifyListeners();
  }

  Future<void> resolveLegalCase(String caseId) async {
    final i = legalCases.indexWhere((c) => c.id == caseId);
    if (i < 0) return;
    legalCases[i] = legalCases[i].copyWith(isResolved: true);
    await _save();
    notifyListeners();
  }

  /// اگر بدهی واحد صفر شد پرونده به‌صورت خودکار مختومه می‌شود
  Future<void> _resolveLegalCaseIfSettled(String unitId) async {
    if (debtOfUnit(unitId) > 0) return;
    for (var i = 0; i < legalCases.length; i++) {
      if (legalCases[i].unitId == unitId && !legalCases[i].isResolved) {
        legalCases[i] = legalCases[i].copyWith(isResolved: true);
      }
    }
  }

  // =========================================================================
  // ماده ۱۴ — بیمه اجباری ساختمان
  // =========================================================================

  List<InsurancePolicy> get buildingPolicies => policies
      .where((p) => p.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => a.endDate.compareTo(b.endDate));

  /// بیمه‌نامه‌هایی که در آستانه انقضا هستند (هشدار ۳۰ و ۱۵ روزه)
  List<InsurancePolicy> get expiringPolicies => buildingPolicies
      .where((p) => p.isExpiringSoon || p.isExpired)
      .toList();

  bool get hasMandatoryFireInsurance => buildingPolicies.any(
      (p) => p.type == InsuranceType.fire && !p.isExpired);

  Future<InsurancePolicy?> addPolicy({
    required InsuranceType type,
    required String insurer,
    required String policyNumber,
    required int premium,
    required int coverageAmount,
    required DateTime startDate,
    required DateTime endDate,
    String? documentUrl,
    String? note,
  }) async {
    final bId = activeBuildingId;
    if (bId == null) return null;
    final p = InsurancePolicy(
      id: _id('pol'),
      buildingId: bId,
      type: type,
      insurer: insurer,
      policyNumber: policyNumber,
      premium: premium,
      coverageAmount: coverageAmount,
      startDate: startDate,
      endDate: endDate,
      documentUrl: documentUrl,
      note: note,
      createdAt: DateTime.now(),
    );
    policies.add(p);
    await _save();
    notifyListeners();
    return p;
  }

  Future<void> deletePolicy(String id) async {
    policies.removeWhere((p) => p.id == id);
    await _save();
    notifyListeners();
  }

  /// سهم حق بیمه هر واحد به نسبت متراژ (ماده ۱۴)
  Map<String, int> premiumSharesOf(InsurancePolicy policy) =>
      BillingEngine.allocateInsurancePremium(
        policy: policy,
        units: buildingUnits,
      );

  /// سرشکن حق بیمه و صدور صورتحساب به نام مالکین
  Future<List<Invoice>> allocatePremium(String policyId) async {
    final policy = policies.where((p) => p.id == policyId).firstOrNull;
    if (policy == null || policy.isAllocated) return [];

    final shares = premiumSharesOf(policy);
    final now = DateTime.now();
    final due = now.add(const Duration(days: 20));
    final created = <Invoice>[];

    shares.forEach((unitId, amount) {
      if (amount <= 0) return;
      final unit = unitById(unitId);
      if (unit == null) return;
      final inv = Invoice(
        id: _id('inv_ins_$unitId'),
        buildingId: policy.buildingId,
        unitId: unitId,
        recipientRole: UnitRole.owner,
        kind: InvoiceKind.insurance,
        title: 'سهم حق بیمه ${policy.type.label}',
        period: currentPeriod,
        amount: amount,
        status: InvoiceStatus.unpaid,
        billId: BillIdentifier.generateBillId(
            buildingId: policy.buildingId, unitNumber: unit.number),
        paymentId:
            BillIdentifier.generatePaymentId(amount: amount, dueDate: due),
        breakdown: {'سهم متراژی حق بیمه': amount},
        dueDate: due,
        createdAt: now,
      );
      invoices.add(inv);
      created.add(inv);
    });

    final i = policies.indexWhere((p) => p.id == policyId);
    if (i >= 0) policies[i] = policies[i].copyWith(isAllocated: true);

    await _save();
    notifyListeners();
    return created;
  }

  // =========================================================================
  // رزرو مشاعات (با ودیعه آنلاین)
  // =========================================================================

  List<Amenity> get amenities => Amenity.defaults;

  List<AmenityBooking> get buildingBookings => amenityBookings
      .where((b) => b.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  List<AmenityBooking> get myBookings {
    final unit = currentUnit;
    if (unit == null) return [];
    return amenityBookings.where((b) => b.unitId == unit.id).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<AmenityBooking> bookingsOn(String amenityId, DateTime day) =>
      amenityBookings
          .where((b) =>
              b.buildingId == activeBuildingId &&
              b.amenityId == amenityId &&
              b.status.isBlocking &&
              b.startTime.year == day.year &&
              b.startTime.month == day.month &&
              b.startTime.day == day.day)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  /// بازه زمانی آزاد است؟
  bool isSlotAvailable({
    required String amenityId,
    required DateTime start,
    required DateTime end,
  }) =>
      !amenityBookings.any((b) =>
          b.buildingId == activeBuildingId &&
          b.amenityId == amenityId &&
          b.status.isBlocking &&
          b.overlaps(start, end));

  /// ثبت رزرو — در صورت نیاز به ودیعه، صورتحساب ودیعه صادر می‌شود
  Future<AmenityBooking?> createBooking({
    required String amenityId,
    required DateTime start,
    required DateTime end,
    String? note,
  }) async {
    final bId = activeBuildingId;
    final unit = currentUnit;
    if (bId == null || unit == null) return null;
    if (!isSlotAvailable(amenityId: amenityId, start: start, end: end)) {
      return null;
    }
    final amenity = Amenity.byId(amenityId);
    if (amenity == null) return null;

    final now = DateTime.now();
    final deposit = amenity.defaultDeposit;

    String? depositInvoiceId;
    if (deposit > 0) {
      final inv = Invoice(
        id: _id('inv_dep'),
        buildingId: bId,
        unitId: unit.id,
        recipientRole: currentUnitRole,
        kind: InvoiceKind.deposit,
        title: 'ودیعه رزرو ${amenity.name}',
        period: currentPeriod,
        amount: deposit,
        status: InvoiceStatus.unpaid,
        billId: BillIdentifier.generateBillId(
            buildingId: bId, unitNumber: unit.number),
        paymentId: BillIdentifier.generatePaymentId(
            amount: deposit, dueDate: start),
        breakdown: {'ودیعه رزرو': deposit},
        dueDate: start,
        createdAt: now,
      );
      invoices.add(inv);
      depositInvoiceId = inv.id;
    }

    final booking = AmenityBooking(
      id: _id('ab'),
      buildingId: bId,
      unitId: unit.id,
      amenityId: amenityId,
      amenityName: amenity.name,
      startTime: start,
      endTime: end,
      depositAmount: deposit,
      depositInvoiceId: depositInvoiceId,
      status:
          deposit > 0 ? BookingStatus.pendingDeposit : BookingStatus.confirmed,
      note: note,
      createdAt: now,
    );
    amenityBookings.add(booking);
    await _save();
    notifyListeners();
    return booking;
  }

  /// قطعی‌سازی رزرو پس از پرداخت ودیعه
  Future<void> confirmBookingAfterDeposit(String bookingId) async {
    final i = amenityBookings.indexWhere((b) => b.id == bookingId);
    if (i < 0) return;
    amenityBookings[i] =
        amenityBookings[i].copyWith(status: BookingStatus.confirmed);
    await _save();
    notifyListeners();
  }

  Future<void> cancelBooking(String bookingId) async {
    final i = amenityBookings.indexWhere((b) => b.id == bookingId);
    if (i < 0) return;
    final depId = amenityBookings[i].depositInvoiceId;
    amenityBookings[i] =
        amenityBookings[i].copyWith(status: BookingStatus.cancelled);
    if (depId != null) {
      final inv = invoiceById(depId);
      if (inv != null && inv.status != InvoiceStatus.paid) {
        invoices.removeWhere((x) => x.id == depId);
      }
    }
    await _save();
    notifyListeners();
  }

  // =========================================================================
  // رأی‌گیری رسمی (ساده / وزنی بر مبنای متراژ سند)
  // =========================================================================

  List<Poll> get buildingPolls => polls
      .where((p) => p.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Poll> get activePolls => buildingPolls.where((p) => p.isOpen).toList();

  Poll? pollById(String id) => polls.where((p) => p.id == id).firstOrNull;

  List<Vote> votesOf(String pollId) =>
      votes.where((v) => v.pollId == pollId).toList();

  Future<Poll?> createPoll({
    required String title,
    required String description,
    required List<String> optionTitles,
    required VotingMethod method,
    bool ownersOnly = false,
    DateTime? endsAt,
  }) async {
    final bId = activeBuildingId;
    if (bId == null || optionTitles.length < 2) return null;
    final now = DateTime.now();
    final poll = Poll(
      id: _id('poll'),
      buildingId: bId,
      title: title,
      description: description,
      method: method,
      options: [
        for (var i = 0; i < optionTitles.length; i++)
          PollOption(id: 'o${i + 1}', title: optionTitles[i]),
      ],
      status: PollStatus.active,
      ownersOnly: ownersOnly,
      startsAt: now,
      endsAt: endsAt ?? now.add(const Duration(days: 7)),
      createdAt: now,
    );
    polls.insert(0, poll);
    await _save();
    notifyListeners();
    return poll;
  }

  Future<void> closePoll(String pollId) async {
    final i = polls.indexWhere((p) => p.id == pollId);
    if (i < 0) return;
    polls[i] = polls[i].copyWith(status: PollStatus.closed);
    await _save();
    notifyListeners();
  }

  /// رأی کاربر جاری در یک نظرسنجی
  Vote? myVote(String pollId) {
    final unit = currentUnit;
    if (unit == null) return null;
    return votes
        .where((v) => v.pollId == pollId && v.unitId == unit.id)
        .firstOrNull;
  }

  bool canVoteIn(Poll poll) {
    final unit = currentUnit;
    if (unit == null || !poll.isOpen) return false;
    if (poll.ownersOnly && currentUnitRole != UnitRole.owner) return false;
    return myVote(poll.id) == null;
  }

  /// ثبت رأی — در روش وزنی، وزن رأی برابر متراژ سند واحد است
  Future<bool> castVote({
    required String pollId,
    required String optionId,
  }) async {
    final poll = pollById(pollId);
    final unit = currentUnit;
    final user = currentUser;
    if (poll == null || unit == null || user == null) return false;
    if (!canVoteIn(poll)) return false;

    votes.add(Vote(
      id: _id('vote'),
      pollId: pollId,
      unitId: unit.id,
      userId: user.id,
      optionId: optionId,
      weight: poll.method == VotingMethod.weighted ? unit.area : 1,
      castAt: DateTime.now(),
    ));
    await _save();
    notifyListeners();
    return true;
  }

  /// شمارش آرا با اعمال روش رأی‌گیری و بررسی حد نصاب قانونی
  PollResult resultOf(String pollId) {
    final poll = pollById(pollId)!;
    final list = votesOf(pollId);
    final eligible = buildingUnits;

    final tally = <String, double>{};
    for (final o in poll.options) {
      tally[o.id] = 0;
    }
    for (final v in list) {
      tally[v.optionId] = (tally[v.optionId] ?? 0) + v.weight;
    }

    final weighted = poll.method == VotingMethod.weighted;
    return PollResult(
      poll: poll,
      tally: tally,
      participantUnits: list.map((v) => v.unitId).toSet().length,
      eligibleUnits: eligible.length,
      totalWeight: list.fold<double>(0, (s, v) => s + v.weight),
      eligibleWeight: weighted
          ? eligible.fold<double>(0, (s, u) => s + u.area)
          : eligible.length.toDouble(),
    );
  }

  // =========================================================================
  // اطلاعیه و درخواست تعمیرات
  // =========================================================================

  List<Notice> get buildingNotices => notices
      .where((n) => n.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> addNotice(String title, String body, bool important) async {
    notices.insert(
      0,
      Notice(
        id: _id('n'),
        buildingId: activeBuildingId ?? '',
        title: title,
        body: body,
        date: DateTime.now(),
        isImportant: important,
      ),
    );
    await _save();
    notifyListeners();
  }

  Future<void> deleteNotice(String id) async {
    notices.removeWhere((n) => n.id == id);
    await _save();
    notifyListeners();
  }

  List<MaintenanceRequest> get buildingRequests => requests
      .where((r) => r.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> addRequest({
    required String unitId,
    required String title,
    required String description,
    required String category,
  }) async {
    requests.insert(
      0,
      MaintenanceRequest(
        id: _id('r'),
        unitId: unitId,
        buildingId: activeBuildingId ?? '',
        title: title,
        description: description,
        category: category,
        date: DateTime.now(),
        status: RequestStatus.pending,
      ),
    );
    await _save();
    notifyListeners();
  }

  Future<void> setRequestStatus(String id, RequestStatus status) async {
    final i = requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    requests[i] = requests[i].copyWith(status: status);
    await _save();
    notifyListeners();
  }

  int get openRequestsCount =>
      buildingRequests.where((r) => r.status != RequestStatus.done).length;

  // =========================================================================
  // آمار و تراز مالی (GET /api/v1/manager/reports/balance)
  // =========================================================================

  FundBalance get fundBalance => BillingEngine.calculateBalance(
        invoices: buildingInvoices,
        expenses: buildingExpenses,
        reserveFundPercent: currentFormula.reserveFundPercent,
      );

  int get collectedThisPeriod => currentPeriodInvoices
      .where((i) => i.status == InvoiceStatus.paid)
      .fold(0, (s, i) => s + i.amount);

  int get pendingThisPeriod => currentPeriodInvoices
      .where((i) => i.status.isDebt)
      .fold(0, (s, i) => s + i.amount);

  int get overdueCount =>
      currentPeriodInvoices.where((i) => i.isOverdue).length;

  double get collectionProgress {
    final total = currentPeriodInvoices.fold(0, (s, i) => s + i.amount);
    if (total == 0) return 0;
    return collectedThisPeriod / total;
  }

  /// تفکیک هزینه‌ها بر اساس سرفصل برای نمودار شفافیت مالی (گام ۴)
  Map<ExpenseCategory, int> get expenseByCategory {
    final map = <ExpenseCategory, int>{};
    for (final e in buildingExpenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  int get totalExpenseThisPeriod =>
      buildingExpenses.fold(0, (s, e) => s + e.amount);

  // =========================================================================
  // تاریخ شمسی
  // =========================================================================

  /// دوره جاری شمسی، مثلاً «شهریور ۱۴۰۴»
  String get currentPeriod {
    final j = Jalali.now();
    return '${monthName(j.month)} ${j.year}';
  }

  String get previousPeriod {
    final j = Jalali.now();
    var m = j.month - 1;
    var y = j.year;
    if (m == 0) {
      m = 12;
      y -= 1;
    }
    return '${monthName(m)} $y';
  }

  static String monthName(int m) => const [
        'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
        'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
      ][m - 1];
}
