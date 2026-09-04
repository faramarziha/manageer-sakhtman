import 'plan.dart';

/// ---------------------------------------------------------------------------
/// موجودیت ساختمان (تننت اصلی در معماری چندمستاجره)
///
/// هر ساختمان یک تننت مستقل است و کلیه رکوردهای وابسته با ستون
/// building_id تفکیک می‌شوند. صندوق ساختمان به دو بخش قانونی تقسیم شده است:
///   • صندوق جاری (current_balance)   : هزینه‌های مصرفی و روزمره
///   • صندوق عمرانی (reserve_balance) : هزینه‌های اساسی و ذخیره تعمیرات
/// ---------------------------------------------------------------------------
class Building {
  final String id;
  final String name;
  final String address;
  final String city;
  final int unitsCount;
  final String managerPhone;
  final String managerName;
  final String inviteCode;

  /// مساحت کل بنا (مجموع متراژ اختصاصی واحدها) - مبنای محاسبه سهم بیمه ماده ۱۴
  final double totalArea;

  /// موجودی صندوق جاری (هزینه‌های مصرفی) - تومان
  final int currentBalance;

  /// موجودی صندوق عمرانی/ذخیره (هزینه‌های اساسی) - تومان
  final int reserveBalance;

  /// شماره شبای مدیر برای تسهیم خودکار درگاه شاپرک (Split Payment)
  final String iban;

  /// شماره کارت مقصد برای پرداخت کارت‌به‌کارت آفلاین
  final String cardNumber;
  final String cardHolder;

  /// پلن اشتراک جاری و سقف واحد مجاز
  final PlanType planType;
  final int maxAllowedUnits;
  final DateTime? subscriptionExpiry;

  /// اعتبار پیامک پیش‌خریدشده (پیش‌فرض صفر - اشتراک‌گذاری رایگان فعال است)
  final int smsCredit;

  final DateTime createdAt;

  const Building({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.unitsCount,
    required this.managerPhone,
    this.managerName = '',
    required this.inviteCode,
    this.totalArea = 0,
    this.currentBalance = 0,
    this.reserveBalance = 0,
    this.iban = '',
    this.cardNumber = '',
    this.cardHolder = '',
    this.planType = PlanType.free,
    this.maxAllowedUnits = 6,
    this.subscriptionExpiry,
    this.smsCredit = 0,
    required this.createdAt,
  });

  bool get hasCardInfo => cardNumber.isNotEmpty && cardHolder.isNotEmpty;

  /// شبا برای تسهیم آنلاین ثبت شده است؟
  bool get hasIban => iban.trim().length >= 24;

  /// موجودی کل صندوق (جاری + عمرانی)
  int get totalBalance => currentBalance + reserveBalance;

  /// ساختمان در پلن رایگان است؟
  bool get isFreePlan => planType.isFree;

  /// آیا ظرفیت پلن برای افزودن واحد جدید تکمیل شده است؟
  bool get isAtUnitLimit => unitsCount >= maxAllowedUnits;

  /// آیا افزودن واحد بعدی نیازمند ارتقای پلن است؟
  bool needsUpgradeForUnits(int newUnitCount) => newUnitCount > maxAllowedUnits;

  Building copyWith({
    String? name,
    String? address,
    String? city,
    int? unitsCount,
    String? managerName,
    double? totalArea,
    int? currentBalance,
    int? reserveBalance,
    String? iban,
    String? cardNumber,
    String? cardHolder,
    PlanType? planType,
    int? maxAllowedUnits,
    DateTime? subscriptionExpiry,
    int? smsCredit,
  }) =>
      Building(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        city: city ?? this.city,
        unitsCount: unitsCount ?? this.unitsCount,
        managerPhone: managerPhone,
        managerName: managerName ?? this.managerName,
        inviteCode: inviteCode,
        totalArea: totalArea ?? this.totalArea,
        currentBalance: currentBalance ?? this.currentBalance,
        reserveBalance: reserveBalance ?? this.reserveBalance,
        iban: iban ?? this.iban,
        cardNumber: cardNumber ?? this.cardNumber,
        cardHolder: cardHolder ?? this.cardHolder,
        planType: planType ?? this.planType,
        maxAllowedUnits: maxAllowedUnits ?? this.maxAllowedUnits,
        subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
        smsCredit: smsCredit ?? this.smsCredit,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'unitsCount': unitsCount,
        'managerPhone': managerPhone,
        'managerName': managerName,
        'inviteCode': inviteCode,
        'totalArea': totalArea,
        'currentBalance': currentBalance,
        'reserveBalance': reserveBalance,
        'iban': iban,
        'cardNumber': cardNumber,
        'cardHolder': cardHolder,
        'planType': planType.index,
        'maxAllowedUnits': maxAllowedUnits,
        'subscriptionExpiry': subscriptionExpiry?.millisecondsSinceEpoch,
        'smsCredit': smsCredit,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Building.fromMap(Map m) => Building(
        id: m['id'],
        name: m['name'],
        address: m['address'],
        city: m['city'],
        unitsCount: m['unitsCount'],
        managerPhone: m['managerPhone'],
        managerName: m['managerName'] ?? '',
        inviteCode: m['inviteCode'],
        totalArea: (m['totalArea'] as num?)?.toDouble() ?? 0,
        currentBalance: m['currentBalance'] ?? 0,
        reserveBalance: m['reserveBalance'] ?? 0,
        iban: m['iban'] ?? '',
        cardNumber: m['cardNumber'] ?? '',
        cardHolder: m['cardHolder'] ?? '',
        planType: PlanType.values[m['planType'] ?? 0],
        maxAllowedUnits: m['maxAllowedUnits'] ?? 6,
        subscriptionExpiry: m['subscriptionExpiry'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['subscriptionExpiry'])
            : null,
        smsCredit: m['smsCredit'] ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      );
}

/// ---------------------------------------------------------------------------
/// موجودیت واحد آپارتمان
///
/// متغیرهای الزامی فرمول ماده ۴ قانون تملک آپارتمان‌ها:
///   • area          : متراژ اختصاصی واحد (مبنای هزینه‌های حفظ و نگهداری بنا)
///   • residentCount : تعداد ساکنین فعال (مبنای هزینه‌های مصرفی)
///   • parkingCount  : تعداد پارکینگ مازاد سندی
///   • isVacant      : فلگ خالی بودن واحد (ضریب نفراتی صفر می‌شود)
/// ---------------------------------------------------------------------------
class Unit {
  final String id;
  final String buildingId;
  final int number;
  final int floor;

  /// نام مالک سندی واحد
  final String ownerName;
  final String phone;

  /// متراژ اختصاصی واحد (متر مربع) - مبنای سهم متراژی و بیمه ماده ۱۴
  final double area;

  /// تعداد ساکنین فعال - مبنای سهم نفراتی هزینه‌های مصرفی
  final int residentCount;

  /// تعداد پارکینگ سندی/مازاد واحد
  final int parkingCount;

  /// واحد خالی است؟ طبق ماده ۴ فقط مکلف به هزینه حفظ و نگهداری بنا است
  final bool isVacant;

  /// شارژ محاسبه‌شده آخرین دوره (تومان) - خروجی BillingEngine
  final int monthlyCharge;

  /// شماره کنتور مجزا (آب/گاز/برق) برای هزینه‌های کنتوری
  final String meterNumber;

  /// مبلغ ثابت اختصاصی واحد (مثلاً توافق مجمع برای واحد تجاری)
  final int fixedExtra;

  const Unit({
    required this.id,
    this.buildingId = '',
    required this.number,
    required this.floor,
    required this.ownerName,
    this.phone = '',
    required this.area,
    this.residentCount = 0,
    this.parkingCount = 0,
    this.isVacant = false,
    this.monthlyCharge = 0,
    this.meterNumber = '',
    this.fixedExtra = 0,
  });

  /// واحد سکونت‌دار (معکوس فلگ خالی) - برای سازگاری با UI موجود
  bool get isOccupied => !isVacant;

  /// عنوان نمایشی واحد
  String get displayTitle => 'واحد $number';

  /// سهم متراژی واحد از کل بنا (برای بیمه و رأی‌گیری وزنی)
  double areaShareOf(double buildingTotalArea) {
    if (buildingTotalArea <= 0) return 0;
    return area / buildingTotalArea;
  }

  Unit copyWith({
    int? number,
    int? floor,
    String? ownerName,
    String? phone,
    double? area,
    int? residentCount,
    int? parkingCount,
    bool? isVacant,
    int? monthlyCharge,
    String? meterNumber,
    int? fixedExtra,
  }) =>
      Unit(
        id: id,
        buildingId: buildingId,
        number: number ?? this.number,
        floor: floor ?? this.floor,
        ownerName: ownerName ?? this.ownerName,
        phone: phone ?? this.phone,
        area: area ?? this.area,
        residentCount: residentCount ?? this.residentCount,
        parkingCount: parkingCount ?? this.parkingCount,
        isVacant: isVacant ?? this.isVacant,
        monthlyCharge: monthlyCharge ?? this.monthlyCharge,
        meterNumber: meterNumber ?? this.meterNumber,
        fixedExtra: fixedExtra ?? this.fixedExtra,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'number': number,
        'floor': floor,
        'ownerName': ownerName,
        'phone': phone,
        'area': area,
        'residentCount': residentCount,
        'parkingCount': parkingCount,
        'isVacant': isVacant,
        'monthlyCharge': monthlyCharge,
        'meterNumber': meterNumber,
        'fixedExtra': fixedExtra,
      };

  factory Unit.fromMap(Map m) => Unit(
        id: m['id'],
        buildingId: m['buildingId'] ?? '',
        number: m['number'],
        floor: m['floor'],
        ownerName: m['ownerName'],
        phone: m['phone'] ?? '',
        area: (m['area'] as num?)?.toDouble() ?? 0,
        // سازگاری با نسخه قدیمی: residents → residentCount
        residentCount: m['residentCount'] ?? m['residents'] ?? 0,
        parkingCount: m['parkingCount'] ?? 0,
        // سازگاری با نسخه قدیمی: isOccupied → isVacant
        isVacant: m['isVacant'] ?? (m['isOccupied'] == null ? false : !m['isOccupied']),
        monthlyCharge: m['monthlyCharge'] ?? 0,
        meterNumber: m['meterNumber'] ?? '',
        fixedExtra: m['fixedExtra'] ?? 0,
      );
}

/// نقش قانونی کاربر در واحد
enum UnitRole { owner, tenant }

extension UnitRoleX on UnitRole {
  String get label => switch (this) {
        UnitRole.owner => 'مالک',
        UnitRole.tenant => 'مستاجر',
      };

  String get code => switch (this) {
        UnitRole.owner => 'OWNER',
        UnitRole.tenant => 'TENANT',
      };
}

/// ---------------------------------------------------------------------------
/// رابطه کاربر با واحد (جدول unit_users)
///
/// این موجودیت پشتیبانی از دو نیاز کلیدی سند را فراهم می‌کند:
///   ۱. تفکیک تعهدات مالک و مستاجر (Dual-Billing)
///   ۲. ورود چندملکیتی؛ یک شماره موبایل می‌تواند در چند واحد و چند
///      ساختمان همزمان نقش داشته باشد.
/// ---------------------------------------------------------------------------
class UnitUser {
  final String id;
  final String unitId;
  final String buildingId;
  final String userId;
  final UnitRole role;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;

  const UnitUser({
    required this.id,
    required this.unitId,
    required this.buildingId,
    required this.userId,
    required this.role,
    this.isActive = true,
    required this.startDate,
    this.endDate,
  });

  bool get isOwner => role == UnitRole.owner;
  bool get isTenant => role == UnitRole.tenant;

  /// بازه سکونت به پایان رسیده است؟
  bool get isExpired =>
      endDate != null && DateTime.now().isAfter(endDate!);

  UnitUser copyWith({
    UnitRole? role,
    bool? isActive,
    DateTime? endDate,
  }) =>
      UnitUser(
        id: id,
        unitId: unitId,
        buildingId: buildingId,
        userId: userId,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        startDate: startDate,
        endDate: endDate ?? this.endDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'unitId': unitId,
        'buildingId': buildingId,
        'userId': userId,
        'role': role.index,
        'isActive': isActive,
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate?.millisecondsSinceEpoch,
      };

  factory UnitUser.fromMap(Map m) => UnitUser(
        id: m['id'],
        unitId: m['unitId'],
        buildingId: m['buildingId'],
        userId: m['userId'],
        role: UnitRole.values[m['role'] ?? 0],
        isActive: m['isActive'] ?? true,
        startDate: DateTime.fromMillisecondsSinceEpoch(m['startDate']),
        endDate: m['endDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['endDate'])
            : null,
      );
}
