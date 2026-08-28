import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/models.dart';

/// لایه داده اپلیکیشن - ذخیره‌سازی محلی با Hive + داده‌های نمونه ایرانی
class AppStore extends ChangeNotifier {
  static const String _boxName = 'building_data';

  static const String buildingName = 'برج مهر سعادت‌آباد';
  static const String buildingAddress = 'تهران، سعادت‌آباد، بلوار دریا، برج مهر';

  late Box _box;

  List<Unit> units = [];
  List<Charge> charges = [];
  List<Notice> notices = [];
  List<MaintenanceRequest> requests = [];
  List<Booking> bookings = [];

  /// واحد جاری ساکن لاگین‌شده (واحد ۱۰۲)
  static const String currentResidentUnitId = 'u_102';

  static const List<Facility> facilities = [
    Facility(id: 'f_hall', name: 'سالن اجتماعات', icon: 'hall'),
    Facility(id: 'f_pool', name: 'استخر و سونا', icon: 'pool'),
    Facility(id: 'f_gym', name: 'سالن ورزشی', icon: 'gym'),
    Facility(id: 'f_guest', name: 'سوئیت مهمان', icon: 'guest'),
    Facility(id: 'f_roof', name: 'روف‌گاردن', icon: 'roof'),
  ];

  static const List<String> timeSlots = [
    '۸ تا ۱۰',
    '۱۰ تا ۱۲',
    '۱۲ تا ۱۴',
    '۱۴ تا ۱۶',
    '۱۶ تا ۱۸',
    '۱۸ تا ۲۰',
    '۲۰ تا ۲۲',
  ];

  static const List<String> requestCategories = [
    'تاسیسات',
    'برق',
    'آسانسور',
    'نظافت',
    'امنیت',
    'سایر',
  ];

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
    units = (_box.get('units') as List)
        .map((e) => Unit.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    charges = (_box.get('charges') as List)
        .map((e) => Charge.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    notices = (_box.get('notices') as List)
        .map((e) => Notice.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    requests = (_box.get('requests') as List)
        .map((e) => MaintenanceRequest.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    bookings = (_box.get('bookings') as List)
        .map((e) => Booking.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _save() async {
    await _box.put('units', units.map((e) => e.toMap()).toList());
    await _box.put('charges', charges.map((e) => e.toMap()).toList());
    await _box.put('notices', notices.map((e) => e.toMap()).toList());
    await _box.put('requests', requests.map((e) => e.toMap()).toList());
    await _box.put('bookings', bookings.map((e) => e.toMap()).toList());
  }

  Future<void> resetData() async {
    _seed();
    await _save();
    notifyListeners();
  }

  // ---------------- داده‌های نمونه ایرانی ----------------
  void _seed() {
    final now = DateTime.now();
    final currentMonth = _currentJalaliMonth();
    final previousMonth = _previousJalaliMonth();

    units = const [
      Unit(id: 'u_101', number: 101, floor: 1, ownerName: 'آقای محمد رضایی', phone: '09121234567', residents: 3, area: 95, isOccupied: true, monthlyCharge: 850000),
      Unit(id: 'u_102', number: 102, floor: 1, ownerName: 'خانم زهرا حسینی', phone: '09129876543', residents: 2, area: 88, isOccupied: true, monthlyCharge: 850000),
      Unit(id: 'u_201', number: 201, floor: 2, ownerName: 'آقای علی کریمی', phone: '09121112233', residents: 4, area: 110, isOccupied: true, monthlyCharge: 950000),
      Unit(id: 'u_202', number: 202, floor: 2, ownerName: 'خانم مریم احمدی', phone: '09124445566', residents: 2, area: 92, isOccupied: true, monthlyCharge: 850000),
      Unit(id: 'u_301', number: 301, floor: 3, ownerName: 'آقای حسن موسوی', phone: '09127778899', residents: 3, area: 105, isOccupied: true, monthlyCharge: 950000),
      Unit(id: 'u_302', number: 302, floor: 3, ownerName: 'آقای رضا صادقی', phone: '09123334455', residents: 0, area: 98, isOccupied: false, monthlyCharge: 850000),
      Unit(id: 'u_401', number: 401, floor: 4, ownerName: 'خانم فاطمه نجفی', phone: '09126667788', residents: 5, area: 120, isOccupied: true, monthlyCharge: 1100000),
      Unit(id: 'u_402', number: 402, floor: 4, ownerName: 'آقای مهدی جعفری', phone: '09129990011', residents: 3, area: 100, isOccupied: true, monthlyCharge: 950000),
      Unit(id: 'u_501', number: 501, floor: 5, ownerName: 'خانم سارا محمدی', phone: '09122223344', residents: 2, area: 115, isOccupied: true, monthlyCharge: 1100000),
      Unit(id: 'u_502', number: 502, floor: 5, ownerName: 'آقای امیر عزیزی', phone: '09125556677', residents: 4, area: 108, isOccupied: true, monthlyCharge: 950000),
    ];

    // شارژ ماه جاری + ماه قبل
    charges = [];
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      // ماه قبل: همه پرداخت شده
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
    // ماه جاری: ترکیب وضعیت‌ها
    const currentStatuses = [
      ChargeStatus.paid,      // 101
      ChargeStatus.pending,   // 102 (ساکن فعلی - قابل پرداخت در دمو)
      ChargeStatus.paid,      // 201
      ChargeStatus.overdue,   // 202
      ChargeStatus.paid,      // 301
      ChargeStatus.overdue,   // 302
      ChargeStatus.paid,      // 401
      ChargeStatus.pending,   // 402
      ChargeStatus.paid,      // 501
      ChargeStatus.pending,   // 502
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
        paidAt: st == ChargeStatus.paid
            ? now.subtract(Duration(days: i + 2))
            : null,
      ));
    }

    notices = [
      Notice(
        id: 'n_1',
        title: 'جلسه مجمع عمومی ساختمان',
        body: 'جلسه مجمع عمومی سالانه روز جمعه ساعت ۱۷ در سالن اجتماعات برگزار می‌شود. حضور کلیه مالکین الزامی است. دستور جلسه: بررسی صورت‌های مالی، انتخاب مدیر جدید و تصمیم‌گیری درباره نقاشی نمای ساختمان.',
        date: now.subtract(const Duration(hours: 5)),
        isImportant: true,
      ),
      Notice(
        id: 'n_2',
        title: 'سرویس دوره‌ای آسانسور',
        body: 'سرویس و بازدید فنی آسانسورها روز شنبه از ساعت ۹ تا ۱۲ انجام می‌شود. در این بازه زمانی آسانسور شماره ۲ خارج از سرویس خواهد بود.',
        date: now.subtract(const Duration(days: 1)),
      ),
      Notice(
        id: 'n_3',
        title: 'قطعی موقت آب ساختمان',
        body: 'به علت شستشوی مخزن آب، روز سه‌شنبه از ساعت ۱۰ تا ۱۳ آب ساختمان قطع خواهد بود. لطفاً هماهنگی لازم را انجام دهید.',
        date: now.subtract(const Duration(days: 2)),
        isImportant: true,
      ),
      Notice(
        id: 'n_4',
        title: 'یادآوری پرداخت شارژ ماهانه',
        body: 'ساکنین محترم، خواهشمند است شارژ ماه جاری را حداکثر تا پایان ماه از طریق اپلیکیشن یا به شماره کارت مدیر ساختمان پرداخت نمایید.',
        date: now.subtract(const Duration(days: 4)),
      ),
      Notice(
        id: 'n_5',
        title: 'نظافت هفتگی مشاعات',
        body: 'نظافت راه‌پله‌ها و لابی هر هفته روزهای شنبه و چهارشنبه انجام می‌شود. از قرار دادن اشیا در راه‌پله و پارکینگ خودداری فرمایید.',
        date: now.subtract(const Duration(days: 6)),
      ),
    ];

    requests = [
      MaintenanceRequest(
        id: 'r_1',
        unitId: 'u_102',
        title: 'نشتی آب از سقف سرویس بهداشتی',
        description: 'از دیروز آب از سقف سرویس بهداشتی چکه می‌کند. احتمالاً از لوله‌های واحد بالایی است. لطفاً هرچه سریع‌تر رسیدگی شود.',
        category: 'تاسیسات',
        date: now.subtract(const Duration(hours: 8)),
        status: RequestStatus.pending,
      ),
      MaintenanceRequest(
        id: 'r_2',
        unitId: 'u_301',
        title: 'خرابی چراغ راه‌پله طبقه سوم',
        description: 'چراغ راه‌پله طبقه سوم سوخته و شب‌ها تاریک است.',
        category: 'برق',
        date: now.subtract(const Duration(days: 1)),
        status: RequestStatus.inProgress,
      ),
      MaintenanceRequest(
        id: 'r_3',
        unitId: 'u_401',
        title: 'صدای غیرعادی آسانسور',
        description: 'آسانسور شماره ۱ هنگام حرکت صدای غیرعادی می‌دهد.',
        category: 'آسانسور',
        date: now.subtract(const Duration(days: 3)),
        status: RequestStatus.done,
      ),
      MaintenanceRequest(
        id: 'r_4',
        unitId: 'u_201',
        title: 'کثیفی پارکینگ عمومی',
        description: 'پارکینگ نیاز به نظافت اساسی دارد.',
        category: 'نظافت',
        date: now.subtract(const Duration(days: 5)),
        status: RequestStatus.done,
      ),
    ];

    bookings = [
      Booking(
        id: 'b_1',
        facilityId: 'f_hall',
        unitId: 'u_401',
        date: now.add(const Duration(days: 3)),
        timeSlot: '۱۸ تا ۲۰',
      ),
      Booking(
        id: 'b_2',
        facilityId: 'f_guest',
        unitId: 'u_201',
        date: now.add(const Duration(days: 6)),
        timeSlot: '۱۴ تا ۱۶',
      ),
    ];
  }

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

  // ---------------- کوئری‌ها و اکشن‌ها ----------------

  Unit? unitById(String id) {
    try {
      return units.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  Unit? get currentUnit => unitById(currentResidentUnitId);

  List<Charge> chargesOfUnit(String unitId) =>
      charges.where((c) => c.unitId == unitId).toList()
        ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

  Charge? currentChargeOfUnit(String unitId) {
    final list = charges.where((c) => c.unitId == unitId).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return list.first;
  }

  List<Charge> get currentMonthCharges =>
      charges.where((c) => c.month == _currentJalaliMonth()).toList();

  int get totalUnits => units.length;
  int get occupiedUnits => units.where((u) => u.isOccupied).length;

  int get collectedThisMonth => currentMonthCharges
      .where((c) => c.status == ChargeStatus.paid)
      .fold(0, (s, c) => s + c.amount);

  int get pendingThisMonth => currentMonthCharges
      .where((c) => c.status != ChargeStatus.paid)
      .fold(0, (s, c) => s + c.amount);

  int get overdueCount =>
      currentMonthCharges.where((c) => c.status == ChargeStatus.overdue).length;

  int get openRequestsCount => requests
      .where((r) => r.status != RequestStatus.done)
      .length;

  double get collectionProgress {
    final total = currentMonthCharges.fold(0, (s, c) => s + c.amount);
    if (total == 0) return 0;
    return collectedThisMonth / total;
  }

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
}

