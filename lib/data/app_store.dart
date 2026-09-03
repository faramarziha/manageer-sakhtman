import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/models.dart';

/// لایه داده اپلیکیشن - معماری چندساختمانی (Multi-Tenant)
/// ذخیره‌سازی محلی با Hive - آماده اتصال به بک‌اند ابری در آینده
class AppStore extends ChangeNotifier {
  static const String _boxName = 'building_data_v3';

  // ---------------- ثابت‌ها ----------------
  static const List<Facility> facilities = [
    Facility(id: 'f_hall', name: 'سالن اجتماعات', icon: 'hall'),
    Facility(id: 'f_pool', name: 'استخر و سونا', icon: 'pool'),
    Facility(id: 'f_gym', name: 'سالن ورزشی', icon: 'gym'),
    Facility(id: 'f_guest', name: 'سوئیت مهمان', icon: 'guest'),
    Facility(id: 'f_roof', name: 'روف‌گاردن', icon: 'roof'),
  ];

  static const List<String> timeSlots = [
    '۸ تا ۱۰', '۱۰ تا ۱۲', '۱۲ تا ۱۴', '۱۴ تا ۱۶', '۱۶ تا ۱۸', '۱۸ تا ۲۰', '۲۰ تا ۲۲',
  ];

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

  /// مدت دوره آزمایشی رایگان
  static const int trialDays = 14;

  // ---------------- وضعیت ----------------
  late Box _box;

  // داده‌های سراسری
  List<Building> buildings = [];
  List<User> users = [];
  List<Subscription> subscriptions = [];

  // داده‌های ساختمان جاری (تننت فعال)
  List<Unit> units = [];
  List<Charge> charges = [];
  List<Notice> notices = [];
  List<MaintenanceRequest> requests = [];
  List<Booking> bookings = [];
  List<Payment> payments = [];
  List<MembershipRequest> membershipRequests = [];

  // جلسه کاربر
  User? currentUser;
  String? activeBuildingId;

  // ---------------- مقداردهی ----------------
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
    charges = _readList('charges', Charge.fromMap);
    notices = _readList('notices', Notice.fromMap);
    requests = _readList('requests', MaintenanceRequest.fromMap);
    bookings = _readList('bookings', Booking.fromMap);
    payments = _readList('payments', Payment.fromMap);
    membershipRequests =
        _readList('membershipRequests', MembershipRequest.fromMap);

    final uid = _box.get('currentUserId');
    if (uid != null) {
      try {
        currentUser = users.firstWhere((u) => u.id == uid);
      } catch (_) {}
    }
    activeBuildingId = _box.get('activeBuildingId');
  }

  List<T> _readList<T>(String key, T Function(Map) fromMap) {
    final raw = _box.get(key);
    if (raw == null) return [];
    return (raw as List)
        .map((e) => fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _save() async {
    await _box.put('buildings', buildings.map((e) => e.toMap()).toList());
    await _box.put('users', users.map((e) => e.toMap()).toList());
    await _box.put('subscriptions', subscriptions.map((e) => e.toMap()).toList());
    await _box.put('units', units.map((e) => e.toMap()).toList());
    await _box.put('charges', charges.map((e) => e.toMap()).toList());
    await _box.put('notices', notices.map((e) => e.toMap()).toList());
    await _box.put('requests', requests.map((e) => e.toMap()).toList());
    await _box.put('bookings', bookings.map((e) => e.toMap()).toList());
    await _box.put('payments', payments.map((e) => e.toMap()).toList());
    await _box.put('membershipRequests',
        membershipRequests.map((e) => e.toMap()).toList());
    await _box.put('currentUserId', currentUser?.id);
    await _box.put('activeBuildingId', activeBuildingId);
  }

  Future<void> resetData() async {
    final keepUser = currentUser;
    final keepBuilding = activeBuildingId;
    _seed();
    currentUser = keepUser;
    activeBuildingId = keepBuilding;
    await _save();
    notifyListeners();
  }

  // ---------------- داده‌های نمونه ----------------
  void _seed() {
    final now = DateTime.now();
    const bId = 'b_mehr';

    buildings = [
      Building(
        id: bId,
        name: 'برج مهر سعادت‌آباد',
        address: 'بلوار دریا، برج مهر',
        city: 'تهران',
        unitsCount: 10,
        managerPhone: '09121234567',
        inviteCode: 'MEHR24',
        cardNumber: '6104337912345678',
        cardHolder: 'بهنام شریفی',
        createdAt: now.subtract(const Duration(days: 90)),
      ),
    ];

    users = [
      User(
        id: 'usr_manager',
        phone: '09121234567',
        fullName: 'مهندس بهنام شریفی',
        role: UserRole.manager,
        buildingId: bId,
        membershipStatus: MembershipStatus.active,
        isOwner: true,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
      User(
        id: 'usr_resident',
        phone: '09129876543',
        fullName: 'خانم زهرا حسینی',
        role: UserRole.resident,
        buildingId: bId,
        unitId: 'u_102',
        membershipStatus: MembershipStatus.active,
        isOwner: false,
        createdAt: now.subtract(const Duration(days: 80)),
      ),
    ];

    subscriptions = [
      Subscription(
        id: 'sub_demo',
        buildingId: bId,
        plan: PlanType.pro,
        startedAt: now.subtract(const Duration(days: 4)),
        expiresAt: now.add(const Duration(days: trialDays - 4)),
        isTrial: true,
      ),
    ];

    units = const [
      Unit(id: 'u_101', buildingId: bId, number: 101, floor: 1, ownerName: 'آقای محمد رضایی', phone: '09121234567', residents: 3, area: 95, isOccupied: true, monthlyCharge: 850000),
      Unit(id: 'u_102', buildingId: bId, number: 102, floor: 1, ownerName: 'خانم زهرا حسینی', phone: '09129876543', residents: 2, area: 88, isOccupied: true, monthlyCharge: 850000),
      Unit(id: 'u_201', buildingId: bId, number: 201, floor: 2, ownerName: 'آقای علی کریمی', phone: '09121112233', residents: 4, area: 110, isOccupied: true, monthlyCharge: 950000),
      Unit(id: 'u_202', buildingId: bId, number: 202, floor: 2, ownerName: 'خانم مریم احمدی', phone: '09124445566', residents: 2, area: 92, isOccupied: true, monthlyCharge: 850000),
      Unit(id: 'u_301', buildingId: bId, number: 301, floor: 3, ownerName: 'آقای حسن موسوی', phone: '09127778899', residents: 3, area: 105, isOccupied: true, monthlyCharge: 950000),
      Unit(id: 'u_302', buildingId: bId, number: 302, floor: 3, ownerName: 'آقای رضا صادقی', phone: '09123334455', residents: 0, area: 98, isOccupied: false, monthlyCharge: 850000),
      Unit(id: 'u_401', buildingId: bId, number: 401, floor: 4, ownerName: 'خانم فاطمه نجفی', phone: '09126667788', residents: 5, area: 120, isOccupied: true, monthlyCharge: 1100000),
      Unit(id: 'u_402', buildingId: bId, number: 402, floor: 4, ownerName: 'آقای مهدی جعفری', phone: '09129990011', residents: 3, area: 100, isOccupied: true, monthlyCharge: 950000),
      Unit(id: 'u_501', buildingId: bId, number: 501, floor: 5, ownerName: 'خانم سارا محمدی', phone: '09122223344', residents: 2, area: 115, isOccupied: true, monthlyCharge: 1100000),
      Unit(id: 'u_502', buildingId: bId, number: 502, floor: 5, ownerName: 'آقای امیر عزیزی', phone: '09125556677', residents: 4, area: 108, isOccupied: true, monthlyCharge: 950000),
    ];

    final currentMonth = _currentJalaliMonth();
    final previousMonth = _previousJalaliMonth();

    charges = [];
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      charges.add(Charge(
        id: 'c_prev_$i',
        unitId: u.id,
        month: previousMonth,
        amount: u.monthlyCharge,
        status: ChargeStatus.paid,
        dueDate: now.subtract(const Duration(days: 35)),
        paidAt: now.subtract(Duration(days: 38 + i)),
      ));
    }
    const currentStatuses = [
      ChargeStatus.paid, ChargeStatus.pending, ChargeStatus.paid,
      ChargeStatus.overdue, ChargeStatus.paid, ChargeStatus.overdue,
      ChargeStatus.paid, ChargeStatus.pending, ChargeStatus.paid,
      ChargeStatus.pending,
    ];
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      final st = currentStatuses[i];
      charges.add(Charge(
        id: 'c_cur_$i',
        unitId: u.id,
        month: currentMonth,
        amount: u.monthlyCharge,
        status: st,
        dueDate: now.add(const Duration(days: 10)),
        paidAt: st == ChargeStatus.paid ? now.subtract(Duration(days: i + 2)) : null,
      ));
    }

    // ---------- پرداخت‌های مستقل ماه جاری (شارژ/آب/تعمیرات) ----------
    payments = [];
    const chargeStatuses = [
      PaymentStatus.paid, PaymentStatus.unpaid, PaymentStatus.paid,
      PaymentStatus.unpaid, PaymentStatus.paid, PaymentStatus.rejected,
      PaymentStatus.paid, PaymentStatus.unpaid, PaymentStatus.paid,
      PaymentStatus.awaitingApproval,
    ];
    const waterStatuses = [
      PaymentStatus.paid, PaymentStatus.unpaid, PaymentStatus.awaitingApproval,
      PaymentStatus.unpaid, PaymentStatus.paid, PaymentStatus.unpaid,
      PaymentStatus.paid, PaymentStatus.paid, PaymentStatus.paid,
      PaymentStatus.unpaid,
    ];
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      final cs = chargeStatuses[i];
      payments.add(Payment(
        id: 'p_charge_$i',
        buildingId: bId,
        unitId: u.id,
        category: PaymentCategory.charge,
        title: 'شارژ $currentMonth',
        month: currentMonth,
        amount: u.monthlyCharge,
        status: cs,
        method: cs == PaymentStatus.unpaid
            ? PaymentMethod.none
            : (i.isEven ? PaymentMethod.online : PaymentMethod.cardToCard),
        receiptNote: cs == PaymentStatus.awaitingApproval
            ? 'رسید کارت به کارت - ساعت ۱۴:۳۰'
            : null,
        rejectionReason: cs == PaymentStatus.rejected
            ? 'مبلغ رسید با مبلغ شارژ مطابقت ندارد'
            : null,
        dueDate: now.add(const Duration(days: 10)),
        paidAt: cs == PaymentStatus.paid
            ? now.subtract(Duration(days: i + 2))
            : null,
        createdAt: now.subtract(const Duration(days: 5)),
      ));
      final ws = waterStatuses[i];
      payments.add(Payment(
        id: 'p_water_$i',
        buildingId: bId,
        unitId: u.id,
        category: PaymentCategory.water,
        title: 'قبض آب $currentMonth',
        month: currentMonth,
        amount: 120000 + (i % 4) * 35000,
        status: ws,
        method: ws == PaymentStatus.unpaid
            ? PaymentMethod.none
            : PaymentMethod.cardToCard,
        receiptNote: ws == PaymentStatus.awaitingApproval
            ? 'کارت به کارت انجام شد'
            : null,
        dueDate: now.add(const Duration(days: 8)),
        paidAt:
            ws == PaymentStatus.paid ? now.subtract(Duration(days: i + 3)) : null,
        createdAt: now.subtract(const Duration(days: 4)),
      ));
    }
    // هزینه تعمیرات آسانسور برای تمام واحدها
    const repairStatuses = [
      PaymentStatus.paid, PaymentStatus.unpaid, PaymentStatus.paid,
      PaymentStatus.paid, PaymentStatus.unpaid, PaymentStatus.unpaid,
      PaymentStatus.paid, PaymentStatus.paid, PaymentStatus.paid,
      PaymentStatus.unpaid,
    ];
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      final rs = repairStatuses[i];
      payments.add(Payment(
        id: 'p_repair_$i',
        buildingId: bId,
        unitId: u.id,
        category: PaymentCategory.repair,
        title: 'سهم تعمیر آسانسور $currentMonth',
        month: currentMonth,
        amount: 250000,
        status: rs,
        method: rs == PaymentStatus.unpaid
            ? PaymentMethod.none
            : PaymentMethod.online,
        dueDate: now.add(const Duration(days: 12)),
        paidAt:
            rs == PaymentStatus.paid ? now.subtract(Duration(days: i + 1)) : null,
        createdAt: now.subtract(const Duration(days: 3)),
      ));
    }

    // ---------- درخواست‌های عضویت نمونه ----------
    membershipRequests = [
      MembershipRequest(
        id: 'mr_1',
        userId: 'usr_pending_1',
        userName: 'آقای سعید کاظمی',
        userPhone: '09135557788',
        buildingId: bId,
        unitNumber: 302,
        isOwner: true,
        status: MembershipStatus.pending,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      MembershipRequest(
        id: 'mr_2',
        userId: 'usr_pending_2',
        userName: 'خانم نگار مرادی',
        userPhone: '09186664422',
        buildingId: bId,
        unitNumber: 502,
        isOwner: false,
        status: MembershipStatus.pending,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    notices = [
      Notice(id: 'n_1', buildingId: bId, title: 'جلسه مجمع عمومی ساختمان', body: 'جلسه مجمع عمومی سالانه روز جمعه ساعت ۱۷ در سالن اجتماعات برگزار می‌شود. حضور کلیه مالکین الزامی است. دستور جلسه: بررسی صورت‌های مالی، انتخاب مدیر جدید و تصمیم‌گیری درباره نقاشی نمای ساختمان.', date: now.subtract(const Duration(hours: 5)), isImportant: true),
      Notice(id: 'n_2', buildingId: bId, title: 'سرویس دوره‌ای آسانسور', body: 'سرویس و بازدید فنی آسانسورها روز شنبه از ساعت ۹ تا ۱۲ انجام می‌شود. در این بازه زمانی آسانسور شماره ۲ خارج از سرویس خواهد بود.', date: now.subtract(const Duration(days: 1))),
      Notice(id: 'n_3', buildingId: bId, title: 'قطعی موقت آب ساختمان', body: 'به علت شستشوی مخزن آب، روز سه‌شنبه از ساعت ۱۰ تا ۱۳ آب ساختمان قطع خواهد بود. لطفاً هماهنگی لازم را انجام دهید.', date: now.subtract(const Duration(days: 2)), isImportant: true),
      Notice(id: 'n_4', buildingId: bId, title: 'یادآوری پرداخت شارژ ماهانه', body: 'ساکنین محترم، خواهشمند است شارژ ماه جاری را حداکثر تا پایان ماه از طریق اپلیکیشن یا به شماره کارت مدیر ساختمان پرداخت نمایید.', date: now.subtract(const Duration(days: 4))),
      Notice(id: 'n_5', buildingId: bId, title: 'نظافت هفتگی مشاعات', body: 'نظافت راه‌پله‌ها و لابی هر هفته روزهای شنبه و چهارشنبه انجام می‌شود. از قرار دادن اشیا در راه‌پله و پارکینگ خودداری فرمایید.', date: now.subtract(const Duration(days: 6))),
    ];

    requests = [
      MaintenanceRequest(id: 'r_1', unitId: 'u_102', buildingId: bId, title: 'نشتی آب از سقف سرویس بهداشتی', description: 'از دیروز آب از سقف سرویس بهداشتی چکه می‌کند. احتمالاً از لوله‌های واحد بالایی است. لطفاً هرچه سریع‌تر رسیدگی شود.', category: 'تاسیسات', date: now.subtract(const Duration(hours: 8)), status: RequestStatus.pending),
      MaintenanceRequest(id: 'r_2', unitId: 'u_301', buildingId: bId, title: 'خرابی چراغ راه‌پله طبقه سوم', description: 'چراغ راه‌پله طبقه سوم سوخته و شب‌ها تاریک است.', category: 'برق', date: now.subtract(const Duration(days: 1)), status: RequestStatus.inProgress),
      MaintenanceRequest(id: 'r_3', unitId: 'u_401', buildingId: bId, title: 'صدای غیرعادی آسانسور', description: 'آسانسور شماره ۱ هنگام حرکت صدای غیرعادی می‌دهد.', category: 'آسانسور', date: now.subtract(const Duration(days: 3)), status: RequestStatus.done),
      MaintenanceRequest(id: 'r_4', unitId: 'u_201', buildingId: bId, title: 'کثیفی پارکینگ عمومی', description: 'پارکینگ نیاز به نظافت اساسی دارد.', category: 'نظافت', date: now.subtract(const Duration(days: 5)), status: RequestStatus.done),
    ];

    bookings = [
      Booking(id: 'b_1', facilityId: 'f_hall', unitId: 'u_401', buildingId: bId, date: now.add(const Duration(days: 3)), timeSlot: '۱۸ تا ۲۰'),
      Booking(id: 'b_2', facilityId: 'f_guest', unitId: 'u_201', buildingId: bId, date: now.add(const Duration(days: 6)), timeSlot: '۱۴ تا ۱۶'),
    ];
  }

  // ---------------- احراز هویت و جلسه ----------------

  bool get isLoggedIn => currentUser != null;

  User? findUserByPhone(String phone) {
    final normalized = _normalizePhone(phone);
    try {
      return users.firstWhere((u) => u.phone == normalized);
    } catch (_) {
      return null;
    }
  }

  String _normalizePhone(String phone) {
    var p = phone.trim();
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (var i = 0; i < 10; i++) {
      p = p.replaceAll(fa[i], en[i]);
    }
    if (p.startsWith('+98')) p = '0${p.substring(3)}';
    if (p.startsWith('98')) p = '0${p.substring(2)}';
    return p;
  }

  Future<void> signIn(User user) async {
    currentUser = user;
    activeBuildingId = user.buildingId;
    await _save();
    notifyListeners();
  }

  Future<void> signOut() async {
    currentUser = null;
    activeBuildingId = null;
    await _save();
    notifyListeners();
  }

  // ---------------- ساختمان (تننت) ----------------

  Building? get currentBuilding {
    if (activeBuildingId == null) return null;
    try {
      return buildings.firstWhere((b) => b.id == activeBuildingId);
    } catch (_) {
      return null;
    }
  }

  Building? findBuildingByInviteCode(String code) {
    try {
      return buildings.firstWhere(
          (b) => b.inviteCode.toUpperCase() == code.trim().toUpperCase());
    } catch (_) {
      return null;
    }
  }

  String _genInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// ثبت‌نام مدیر + ایجاد ساختمان جدید + فعال‌سازی دوره آزمایشی
  Future<Building> registerManagerAndBuilding({
    required String managerName,
    required String phone,
    required String buildingName,
    required String city,
    required String address,
    required int unitsCount,
    required PlanType plan,
  }) async {
    final now = DateTime.now();
    final bId = 'b_${now.millisecondsSinceEpoch}';

    final building = Building(
      id: bId,
      name: buildingName,
      address: address,
      city: city,
      unitsCount: unitsCount,
      managerPhone: _normalizePhone(phone),
      inviteCode: _genInviteCode(),
      createdAt: now,
    );
    buildings.add(building);

    final user = User(
      id: 'usr_${now.millisecondsSinceEpoch}',
      phone: _normalizePhone(phone),
      fullName: managerName,
      role: UserRole.manager,
      buildingId: bId,
      createdAt: now,
    );
    users.add(user);

    subscriptions.add(Subscription(
      id: 'sub_${now.millisecondsSinceEpoch}',
      buildingId: bId,
      plan: plan,
      startedAt: now,
      expiresAt: now.add(Duration(days: trialDays)),
      isTrial: true,
    ));

    // ساخت واحدهای خالی اولیه بر اساس تعداد
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
          phone: '',
          residents: 0,
          area: 0,
          isOccupied: false,
          monthlyCharge: 0,
        ));
        n++;
      }
    }

    currentUser = user;
    activeBuildingId = bId;
    await _save();
    notifyListeners();
    return building;
  }

  /// اتصال ساکن به ساختمان با کد دعوت
  Future<Unit?> joinBuildingAsResident({
    required String name,
    required String phone,
    required String inviteCode,
    required int unitNumber,
  }) async {
    final building = findBuildingByInviteCode(inviteCode);
    if (building == null) return null;

    Unit? unit;
    try {
      unit = units.firstWhere(
          (u) => u.buildingId == building.id && u.number == unitNumber);
    } catch (_) {
      return null;
    }

    final now = DateTime.now();
    final user = User(
      id: 'usr_${now.millisecondsSinceEpoch}',
      phone: _normalizePhone(phone),
      fullName: name,
      role: UserRole.resident,
      buildingId: building.id,
      unitId: unit.id,
      createdAt: now,
    );
    users.add(user);
    currentUser = user;
    activeBuildingId = building.id;
    await _save();
    notifyListeners();
    return unit;
  }

  // ---------------- عضویت ساکنین (درخواست → تایید مدیر) ----------------

  /// درخواست عضویت جدید - کاربر تا تایید مدیر فعال نمی‌شود
  Future<MembershipRequest?> submitMembershipRequest({
    required String name,
    required String phone,
    required String inviteCode,
    required int unitNumber,
    required bool isOwner,
  }) async {
    final building = findBuildingByInviteCode(inviteCode);
    if (building == null) return null;

    // واحد باید در ساختمان وجود داشته باشد
    Unit? unit;
    try {
      unit = units.firstWhere(
          (u) => u.buildingId == building.id && u.number == unitNumber);
    } catch (_) {
      return null;
    }

    final now = DateTime.now();
    // کاربر با وضعیت pending ساخته می‌شود (بدون اتصال به واحد)
    final user = User(
      id: 'usr_${now.millisecondsSinceEpoch}',
      phone: _normalizePhone(phone),
      fullName: name,
      role: UserRole.resident,
      buildingId: building.id,
      membershipStatus: MembershipStatus.pending,
      isOwner: isOwner,
      createdAt: now,
    );
    users.add(user);

    final request = MembershipRequest(
      id: 'mr_${now.millisecondsSinceEpoch}',
      userId: user.id,
      userName: name,
      userPhone: _normalizePhone(phone),
      buildingId: building.id,
      unitNumber: unit.number,
      isOwner: isOwner,
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

  /// درخواست‌های عضویت ساختمان جاری
  List<MembershipRequest> get buildingMembershipRequests => membershipRequests
      .where((r) => r.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get pendingMembershipCount => buildingMembershipRequests
      .where((r) => r.status == MembershipStatus.pending)
      .length;

  /// آخرین درخواست عضویت کاربر جاری
  MembershipRequest? get myMembershipRequest {
    final u = currentUser;
    if (u == null) return null;
    final list = membershipRequests.where((r) => r.userId == u.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.isEmpty ? null : list.first;
  }

  /// تایید درخواست عضویت توسط مدیر - اتصال کاربر به واحد
  Future<void> approveMembership(String requestId) async {
    final i = membershipRequests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    final req = membershipRequests[i];

    Unit? unit;
    try {
      unit = units.firstWhere((u) =>
          u.buildingId == req.buildingId && u.number == req.unitNumber);
    } catch (_) {
      return;
    }

    membershipRequests[i] = req.copyWith(
      status: MembershipStatus.active,
      resolvedAt: DateTime.now(),
    );

    final ui = users.indexWhere((u) => u.id == req.userId);
    if (ui >= 0) {
      users[ui] = users[ui].copyWith(
        buildingId: req.buildingId,
        unitId: unit.id,
        membershipStatus: MembershipStatus.active,
      );
      if (currentUser?.id == req.userId) currentUser = users[ui];
    }
    await _save();
    notifyListeners();
  }

  /// رد درخواست عضویت
  Future<void> rejectMembership(String requestId) async {
    final i = membershipRequests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    membershipRequests[i] = membershipRequests[i].copyWith(
      status: MembershipStatus.rejected,
      resolvedAt: DateTime.now(),
    );
    final ui =
        users.indexWhere((u) => u.id == membershipRequests[i].userId);
    if (ui >= 0) {
      users[ui] = users[ui].copyWith(
        membershipStatus: MembershipStatus.rejected,
      );
      if (currentUser?.id == users[ui].id) currentUser = users[ui];
    }
    await _save();
    notifyListeners();
  }

  /// حذف اتصال کاربر از واحد (مدیریت ارتباط کاربر-واحد)
  Future<void> detachUserFromUnit(String userId) async {
    final ui = users.indexWhere((u) => u.id == userId);
    if (ui < 0) return;
    final u = users[ui];
    users[ui] = User(
      id: u.id,
      phone: u.phone,
      fullName: u.fullName,
      role: u.role,
      buildingId: u.buildingId,
      unitId: null,
      membershipStatus: MembershipStatus.none,
      isOwner: u.isOwner,
      createdAt: u.createdAt,
    );
    if (currentUser?.id == userId) currentUser = users[ui];
    await _save();
    notifyListeners();
  }

  /// اعضای فعال هر واحد
  List<User> usersOfUnit(String unitId) => users
      .where((u) =>
          u.unitId == unitId && u.membershipStatus == MembershipStatus.active)
      .toList();

  // ---------------- کارت مقصد (کارت به کارت) ----------------

  /// ثبت/ویرایش اطلاعات کارت مقصد توسط مدیر
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

  // ---------------- پرداخت‌های مستقل (شارژ/آب/تعمیرات/متفرقه) ----------------

  /// پرداخت‌های ساختمان جاری
  List<Payment> get buildingPayments => payments
      .where((p) => p.buildingId == activeBuildingId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// پرداخت‌های یک واحد (جدیدترین اول)
  List<Payment> paymentsOfUnit(String unitId) => payments
      .where((p) => p.unitId == unitId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// پرداخت‌های ماه جاری یک واحد
  List<Payment> currentMonthPaymentsOfUnit(String unitId) => payments
      .where((p) =>
          p.unitId == unitId && p.month == _currentJalaliMonth())
      .toList()
    ..sort((a, b) => a.category.index.compareTo(b.category.index));

  /// پرداخت‌های در انتظار تایید مدیر (صف بررسی رسیدها)
  List<Payment> get awaitingApprovalPayments => buildingPayments
      .where((p) => p.status == PaymentStatus.awaitingApproval)
      .toList();

  /// ایجاد پرداخت جدید برای واحدهای انتخاب‌شده
  Future<void> createPayments({
    required PaymentCategory category,
    required String title,
    required int amount,
    required List<String> unitIds,
    String? month,
    DateTime? dueDate,
  }) async {
    final now = DateTime.now();
    final m = month ?? _currentJalaliMonth();
    for (final uid in unitIds) {
      payments.add(Payment(
        id: 'p_${now.millisecondsSinceEpoch}_$uid',
        buildingId: activeBuildingId ?? '',
        unitId: uid,
        category: category,
        title: title,
        month: m,
        amount: amount,
        status: PaymentStatus.unpaid,
        dueDate: dueDate ?? now.add(const Duration(days: 10)),
        createdAt: now,
      ));
    }
    await _save();
    notifyListeners();
  }

  /// حذف پرداخت
  Future<void> deletePayment(String id) async {
    payments.removeWhere((p) => p.id == id);
    await _save();
    notifyListeners();
  }

  /// پرداخت آنلاین (شبیه‌سازی درگاه) - مستقیم تایید می‌شود
  Future<void> payOnline(String paymentId) async {
    final i = payments.indexWhere((p) => p.id == paymentId);
    if (i < 0) return;
    payments[i] = payments[i].copyWith(
      status: PaymentStatus.paid,
      method: PaymentMethod.online,
      paidAt: DateTime.now(),
      clearRejection: true,
    );
    await _save();
    notifyListeners();
  }

  /// ارسال رسید کارت به کارت توسط ساکن → در انتظار تایید مدیر
  Future<void> submitCardToCardReceipt(String paymentId, String note) async {
    final i = payments.indexWhere((p) => p.id == paymentId);
    if (i < 0) return;
    payments[i] = payments[i].copyWith(
      status: PaymentStatus.awaitingApproval,
      method: PaymentMethod.cardToCard,
      receiptNote: note.trim(),
      clearRejection: true,
    );
    await _save();
    notifyListeners();
  }

  /// تایید رسید توسط مدیر → پرداخت شده
  Future<void> approvePayment(String paymentId) async {
    final i = payments.indexWhere((p) => p.id == paymentId);
    if (i < 0) return;
    payments[i] = payments[i].copyWith(
      status: PaymentStatus.paid,
      paidAt: DateTime.now(),
      clearRejection: true,
    );
    await _save();
    notifyListeners();
  }

  /// رد رسید توسط مدیر با دلیل → رد شده
  Future<void> rejectPayment(String paymentId, String reason) async {
    final i = payments.indexWhere((p) => p.id == paymentId);
    if (i < 0) return;
    payments[i] = payments[i].copyWith(
      status: PaymentStatus.rejected,
      rejectionReason: reason.trim(),
    );
    await _save();
    notifyListeners();
  }

  // ---------------- اشتراک ----------------

  Subscription? get currentSubscription {
    final bId = activeBuildingId;
    if (bId == null) return null;
    final list = subscriptions.where((s) => s.buildingId == bId).toList()
      ..sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
    return list.isEmpty ? null : list.first;
  }

  Future<void> activateSubscription(PlanType plan, {String? purchaseToken}) async {
    final bId = activeBuildingId;
    if (bId == null) return;
    final now = DateTime.now();
    subscriptions.add(Subscription(
      id: 'sub_${now.millisecondsSinceEpoch}',
      buildingId: bId,
      plan: plan,
      startedAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      isTrial: false,
      purchaseToken: purchaseToken,
    ));
    await _save();
    notifyListeners();
  }

  // ---------------- کوئری‌های واحد/شارژ (اسکوپ‌شده به ساختمان) ----------------

  List<Unit> get buildingUnits =>
      units.where((u) => u.buildingId == activeBuildingId).toList();

  List<Charge> get buildingCharges {
    final unitIds = buildingUnits.map((u) => u.id).toSet();
    return charges.where((c) => unitIds.contains(c.unitId)).toList();
  }

  List<Notice> get buildingNotices =>
      notices.where((n) => n.buildingId == activeBuildingId).toList();

  List<MaintenanceRequest> get buildingRequests =>
      requests.where((r) => r.buildingId == activeBuildingId).toList();

  List<Booking> get buildingBookings =>
      bookings.where((b) => b.buildingId == activeBuildingId).toList();

  Unit? unitById(String id) {
    try {
      return units.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  /// واحد جاری ساکن لاگین‌شده
  Unit? get currentUnit =>
      currentUser?.unitId != null ? unitById(currentUser!.unitId!) : null;

  List<Charge> chargesOfUnit(String unitId) =>
      charges.where((c) => c.unitId == unitId).toList()
        ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

  Charge? currentChargeOfUnit(String unitId) {
    final list = charges.where((c) => c.unitId == unitId).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return list.first;
  }

  List<Charge> get currentMonthCharges => buildingCharges
      .where((c) => c.month == _currentJalaliMonth())
      .toList();

  int get totalUnits => buildingUnits.length;
  int get occupiedUnits => buildingUnits.where((u) => u.isOccupied).length;

  int get collectedThisMonth => currentMonthCharges
      .where((c) => c.status == ChargeStatus.paid)
      .fold(0, (s, c) => s + c.amount);

  int get pendingThisMonth => currentMonthCharges
      .where((c) => c.status != ChargeStatus.paid)
      .fold(0, (s, c) => s + c.amount);

  int get overdueCount =>
      currentMonthCharges.where((c) => c.status == ChargeStatus.overdue).length;

  int get openRequestsCount =>
      buildingRequests.where((r) => r.status != RequestStatus.done).length;

  double get collectionProgress {
    final total = currentMonthCharges.fold(0, (s, c) => s + c.amount);
    if (total == 0) return 0;
    return collectedThisMonth / total;
  }

  // آمار پرداخت‌های مستقل (مدل Payment)
  List<Payment> get currentMonthPayments => buildingPayments
      .where((p) => p.month == _currentJalaliMonth())
      .toList();

  int get paidPaymentsSum => currentMonthPayments
      .where((p) => p.status == PaymentStatus.paid)
      .fold(0, (s, p) => s + p.amount);

  int get unpaidPaymentsSum => currentMonthPayments
      .where((p) =>
          p.status == PaymentStatus.unpaid ||
          p.status == PaymentStatus.rejected)
      .fold(0, (s, p) => s + p.amount);

  double get paymentCollectionProgress {
    final total = currentMonthPayments.fold(0, (s, p) => s + p.amount);
    if (total == 0) return 0;
    return paidPaymentsSum / total;
  }

  // ---------------- اکشن‌ها ----------------

  Future<void> payCharge(String chargeId) async {
    final i = charges.indexWhere((c) => c.id == chargeId);
    if (i < 0) return;
    charges[i] = charges[i].copyWith(
      status: ChargeStatus.paid,
      paidAt: DateTime.now(),
    );
    await _save();
    notifyListeners();
  }

  Future<void> addNotice(String title, String body, bool important) async {
    notices.insert(
      0,
      Notice(
        id: 'n_${DateTime.now().millisecondsSinceEpoch}',
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

  Future<void> addRequest({
    required String unitId,
    required String title,
    required String description,
    required String category,
  }) async {
    requests.insert(
      0,
      MaintenanceRequest(
        id: 'r_${DateTime.now().millisecondsSinceEpoch}',
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

  Future<void> addBooking({
    required String facilityId,
    required String unitId,
    required DateTime date,
    required String timeSlot,
  }) async {
    bookings.add(Booking(
      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
      facilityId: facilityId,
      unitId: unitId,
      buildingId: activeBuildingId ?? '',
      date: date,
      timeSlot: timeSlot,
    ));
    await _save();
    notifyListeners();
  }

  Future<void> cancelBooking(String id) async {
    bookings.removeWhere((b) => b.id == id);
    await _save();
    notifyListeners();
  }

  bool isSlotTaken(String facilityId, DateTime date, String slot) {
    return bookings.any((b) =>
        b.facilityId == facilityId &&
        b.timeSlot == slot &&
        b.date.year == date.year &&
        b.date.month == date.month &&
        b.date.day == date.day);
  }

  // ---------------- تاریخ شمسی ----------------

  String _currentJalaliMonth() {
    final j = Jalali.now();
    return '${_monthName(j.month)} ${j.year}';
  }

  String _previousJalaliMonth() {
    final j = Jalali.now();
    var m = j.month - 1;
    var y = j.year;
    if (m == 0) {
      m = 12;
      y -= 1;
    }
    return '${_monthName(m)} $y';
  }

  String _monthName(int m) => const [
        'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
        'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
      ][m - 1];
}
