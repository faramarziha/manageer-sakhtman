/// نقش کاربر در سیستم
enum UserRole { manager, resident }

/// کاربر اپلیکیشن
class User {
  final String id;
  final String phone;        // شماره موبایل (شناسه ورود)
  final String fullName;
  final UserRole role;
  final String? buildingId;  // ساختمانی که به آن متصل است
  final String? unitId;      // واحد ساکن (فقط برای resident)
  final DateTime createdAt;

  const User({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
    this.buildingId,
    this.unitId,
    required this.createdAt,
  });

  User copyWith({String? buildingId, String? unitId}) => User(
        id: id,
        phone: phone,
        fullName: fullName,
        role: role,
        buildingId: buildingId ?? this.buildingId,
        unitId: unitId ?? this.unitId,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'phone': phone,
        'fullName': fullName,
        'role': role.index,
        'buildingId': buildingId,
        'unitId': unitId,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory User.fromMap(Map m) => User(
        id: m['id'],
        phone: m['phone'],
        fullName: m['fullName'],
        role: UserRole.values[m['role']],
        buildingId: m['buildingId'],
        unitId: m['unitId'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      );
}

/// نوع طرح اشتراک
enum PlanType { basic, pro, enterprise }

extension PlanTypeX on PlanType {
  String get sku => switch (this) {
        PlanType.basic => 'sub_basic_monthly',
        PlanType.pro => 'sub_pro_monthly',
        PlanType.enterprise => 'sub_enterprise_monthly',
      };

  String get name => switch (this) {
        PlanType.basic => 'پایه',
        PlanType.pro => 'حرفه‌ای',
        PlanType.enterprise => 'سازمانی',
      };

  String get tagline => switch (this) {
        PlanType.basic => 'برای ساختمان‌های کوچک',
        PlanType.pro => 'محبوب‌ترین - برای مجتمع‌های مسکونی',
        PlanType.enterprise => 'برای برج‌ها و مجموعه‌های بزرگ',
      };

  /// قیمت ماهانه (تومان)
  int get priceMonthly => switch (this) {
        PlanType.basic => 99000,
        PlanType.pro => 249000,
        PlanType.enterprise => 590000,
      };

  int get maxUnits => switch (this) {
        PlanType.basic => 10,
        PlanType.pro => 50,
        PlanType.enterprise => 9999,
      };

  List<String> get features => switch (this) {
        PlanType.basic => [
            'مدیریت تا ۱۰ واحد',
            'صدور و پیگیری شارژ ماهانه',
            'اعلانات ساختمان',
            'درخواست‌های تعمیرات',
            'پشتیبانی تیکتی',
          ],
        PlanType.pro => [
            'مدیریت تا ۵۰ واحد',
            'همه امکانات طرح پایه',
            'رزرو امکانات مشترک',
            'گزارش مالی پیشرفته',
            'اطلاع‌رسانی پیامکی (به‌زودی)',
            'پشتیبانی تلفنی',
          ],
        PlanType.enterprise => [
            'واحدهای نامحدود',
            'همه امکانات طرح حرفه‌ای',
            'چند مدیر هم‌زمان',
            'درگاه پرداخت اختصاصی',
            'API اتصال به نرم‌افزار حسابداری',
            'پشتیبانی اختصاصی ۲۴/۷',
          ],
      };
}

/// اشتراک فعال ساختمان
class Subscription {
  final String id;
  final String buildingId;
  final PlanType plan;
  final DateTime startedAt;
  final DateTime expiresAt;
  final bool isTrial;
  final String? purchaseToken; // توکن خرید بازار
  final bool autoRenew;

  const Subscription({
    required this.id,
    required this.buildingId,
    required this.plan,
    required this.startedAt,
    required this.expiresAt,
    this.isTrial = false,
    this.purchaseToken,
    this.autoRenew = true,
  });

  bool get isActive => DateTime.now().isBefore(expiresAt);

  int get daysLeft {
    final d = expiresAt.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'plan': plan.index,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'isTrial': isTrial,
        'purchaseToken': purchaseToken,
        'autoRenew': autoRenew,
      };

  factory Subscription.fromMap(Map m) => Subscription(
        id: m['id'],
        buildingId: m['buildingId'],
        plan: PlanType.values[m['plan']],
        startedAt: DateTime.fromMillisecondsSinceEpoch(m['startedAt']),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(m['expiresAt']),
        isTrial: m['isTrial'] ?? false,
        purchaseToken: m['purchaseToken'],
        autoRenew: m['autoRenew'] ?? true,
      );
}

/// ساختمان (تننت) در سیستم چندساختمانی
class Building {
  final String id;
  final String name;
  final String address;
  final String city;
  final int unitsCount;
  final String managerPhone;
  final String inviteCode;   // کد دعوت ساکنین
  final DateTime createdAt;

  const Building({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.unitsCount,
    required this.managerPhone,
    required this.inviteCode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'unitsCount': unitsCount,
        'managerPhone': managerPhone,
        'inviteCode': inviteCode,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Building.fromMap(Map m) => Building(
        id: m['id'],
        name: m['name'],
        address: m['address'],
        city: m['city'],
        unitsCount: m['unitsCount'],
        managerPhone: m['managerPhone'],
        inviteCode: m['inviteCode'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      );
}

/// مدل واحد ساختمان
class Unit {
  final String id;
  final String buildingId;
  final int number;        // شماره واحد
  final int floor;         // طبقه
  final String ownerName;  // نام مالک
  final String phone;      // شماره تماس
  final int residents;     // تعداد ساکنین
  final double area;       // متراژ (متر مربع)
  final bool isOccupied;   // سکونت‌دار
  final int monthlyCharge; // شارژ ماهانه (تومان)

  const Unit({
    required this.id,
    this.buildingId = '',
    required this.number,
    required this.floor,
    required this.ownerName,
    required this.phone,
    required this.residents,
    required this.area,
    required this.isOccupied,
    required this.monthlyCharge,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'number': number,
        'floor': floor,
        'ownerName': ownerName,
        'phone': phone,
        'residents': residents,
        'area': area,
        'isOccupied': isOccupied,
        'monthlyCharge': monthlyCharge,
      };

  factory Unit.fromMap(Map m) => Unit(
        id: m['id'],
        buildingId: m['buildingId'] ?? '',
        number: m['number'],
        floor: m['floor'],
        ownerName: m['ownerName'],
        phone: m['phone'],
        residents: m['residents'],
        area: (m['area'] as num).toDouble(),
        isOccupied: m['isOccupied'],
        monthlyCharge: m['monthlyCharge'],
      );
}

/// وضعیت پرداخت شارژ
enum ChargeStatus { paid, pending, overdue }

extension ChargeStatusX on ChargeStatus {
  String get label => switch (this) {
        ChargeStatus.paid => 'پرداخت شده',
        ChargeStatus.pending => 'در انتظار پرداخت',
        ChargeStatus.overdue => 'معوقه',
      };
}

/// رکورد شارژ ماهانه هر واحد
class Charge {
  final String id;
  final String unitId;
  final String month;      // مثلا «شهریور ۱۴۰۴»
  final int amount;
  final ChargeStatus status;
  final DateTime dueDate;
  final DateTime? paidAt;

  const Charge({
    required this.id,
    required this.unitId,
    required this.month,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.paidAt,
  });

  Charge copyWith({ChargeStatus? status, DateTime? paidAt}) => Charge(
        id: id,
        unitId: unitId,
        month: month,
        amount: amount,
        status: status ?? this.status,
        dueDate: dueDate,
        paidAt: paidAt ?? this.paidAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'unitId': unitId,
        'month': month,
        'amount': amount,
        'status': status.index,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'paidAt': paidAt?.millisecondsSinceEpoch,
      };

  factory Charge.fromMap(Map m) => Charge(
        id: m['id'],
        unitId: m['unitId'],
        month: m['month'],
        amount: m['amount'],
        status: ChargeStatus.values[m['status']],
        dueDate: DateTime.fromMillisecondsSinceEpoch(m['dueDate']),
        paidAt: m['paidAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['paidAt'])
            : null,
      );
}

/// اعلان ساختمان
class Notice {
  final String id;
  final String buildingId;
  final String title;
  final String body;
  final DateTime date;
  final bool isImportant;

  const Notice({
    required this.id,
    this.buildingId = '',
    required this.title,
    required this.body,
    required this.date,
    this.isImportant = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'title': title,
        'body': body,
        'date': date.millisecondsSinceEpoch,
        'isImportant': isImportant,
      };

  factory Notice.fromMap(Map m) => Notice(
        id: m['id'],
        buildingId: m['buildingId'] ?? '',
        title: m['title'],
        body: m['body'],
        date: DateTime.fromMillisecondsSinceEpoch(m['date']),
        isImportant: m['isImportant'] ?? false,
      );
}

/// وضعیت درخواست تعمیرات
enum RequestStatus { pending, inProgress, done }

extension RequestStatusX on RequestStatus {
  String get label => switch (this) {
        RequestStatus.pending => 'در انتظار بررسی',
        RequestStatus.inProgress => 'در حال انجام',
        RequestStatus.done => 'انجام شده',
      };
}

/// درخواست تعمیرات/خدمات
class MaintenanceRequest {
  final String id;
  final String unitId;
  final String buildingId;
  final String title;
  final String description;
  final String category; // تاسیسات، برق، آسانسور، نظافت، سایر
  final DateTime date;
  final RequestStatus status;

  const MaintenanceRequest({
    required this.id,
    required this.unitId,
    this.buildingId = '',
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.status,
  });

  MaintenanceRequest copyWith({RequestStatus? status}) => MaintenanceRequest(
        id: id,
        unitId: unitId,
        buildingId: buildingId,
        title: title,
        description: description,
        category: category,
        date: date,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'unitId': unitId,
        'buildingId': buildingId,
        'title': title,
        'description': description,
        'category': category,
        'date': date.millisecondsSinceEpoch,
        'status': status.index,
      };

  factory MaintenanceRequest.fromMap(Map m) => MaintenanceRequest(
        id: m['id'],
        unitId: m['unitId'],
        buildingId: m['buildingId'] ?? '',
        title: m['title'],
        description: m['description'],
        category: m['category'],
        date: DateTime.fromMillisecondsSinceEpoch(m['date']),
        status: RequestStatus.values[m['status']],
      );
}

/// امکانات مشترک قابل رزرو
class Facility {
  final String id;
  final String name;
  final String icon; // نام آیکون

  const Facility({required this.id, required this.name, required this.icon});
}

/// رزرو امکانات
class Booking {
  final String id;
  final String facilityId;
  final String unitId;
  final String buildingId;
  final DateTime date;
  final String timeSlot; // مثلا «۱۰ تا ۱۲»

  const Booking({
    required this.id,
    required this.facilityId,
    required this.unitId,
    this.buildingId = '',
    required this.date,
    required this.timeSlot,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'facilityId': facilityId,
        'unitId': unitId,
        'buildingId': buildingId,
        'date': date.millisecondsSinceEpoch,
        'timeSlot': timeSlot,
      };

  factory Booking.fromMap(Map m) => Booking(
        id: m['id'],
        facilityId: m['facilityId'],
        unitId: m['unitId'],
        buildingId: m['buildingId'] ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date']),
        timeSlot: m['timeSlot'],
      );
}
