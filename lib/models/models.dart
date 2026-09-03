/// نقش کاربر در سیستم
enum UserRole { manager, resident }

/// وضعیت عضویت کاربر در واحد
enum MembershipStatus { none, pending, active, rejected }

extension MembershipStatusX on MembershipStatus {
  String get label => switch (this) {
        MembershipStatus.none => 'بدون عضویت',
        MembershipStatus.pending => 'در انتظار تایید مدیر',
        MembershipStatus.active => 'عضو فعال',
        MembershipStatus.rejected => 'رد شده',
      };
}

/// کاربر اپلیکیشن
class User {
  final String id;
  final String phone;        // شماره موبایل (شناسه ورود)
  final String fullName;
  final UserRole role;
  final String? buildingId;  // ساختمانی که به آن متصل است
  final String? unitId;      // واحد ساکن (فقط برای resident)
  final MembershipStatus membershipStatus;
  final bool isOwner;        // مالک یا مستاجر
  final DateTime createdAt;

  const User({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
    this.buildingId,
    this.unitId,
    this.membershipStatus = MembershipStatus.none,
    this.isOwner = false,
    required this.createdAt,
  });

  User copyWith({
    String? buildingId,
    String? unitId,
    MembershipStatus? membershipStatus,
  }) =>
      User(
        id: id,
        phone: phone,
        fullName: fullName,
        role: role,
        buildingId: buildingId ?? this.buildingId,
        unitId: unitId ?? this.unitId,
        membershipStatus: membershipStatus ?? this.membershipStatus,
        isOwner: isOwner,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'phone': phone,
        'fullName': fullName,
        'role': role.index,
        'buildingId': buildingId,
        'unitId': unitId,
        'membershipStatus': membershipStatus.index,
        'isOwner': isOwner,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory User.fromMap(Map m) => User(
        id: m['id'],
        phone: m['phone'],
        fullName: m['fullName'],
        role: UserRole.values[m['role']],
        buildingId: m['buildingId'],
        unitId: m['unitId'],
        membershipStatus: MembershipStatus.values[m['membershipStatus'] ?? 2],
        isOwner: m['isOwner'] ?? false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      );
}

/// درخواست عضویت ساکن در واحد (مالک یا مستاجر)
class MembershipRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String buildingId;
  final int unitNumber;
  final bool isOwner; // true = مالک، false = مستاجر
  final MembershipStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const MembershipRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.buildingId,
    required this.unitNumber,
    required this.isOwner,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  MembershipRequest copyWith({MembershipStatus? status, DateTime? resolvedAt}) =>
      MembershipRequest(
        id: id,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        buildingId: buildingId,
        unitNumber: unitNumber,
        isOwner: isOwner,
        status: status ?? this.status,
        createdAt: createdAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'buildingId': buildingId,
        'unitNumber': unitNumber,
        'isOwner': isOwner,
        'status': status.index,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
      };

  factory MembershipRequest.fromMap(Map m) => MembershipRequest(
        id: m['id'],
        userId: m['userId'],
        userName: m['userName'],
        userPhone: m['userPhone'],
        buildingId: m['buildingId'],
        unitNumber: m['unitNumber'],
        isOwner: m['isOwner'],
        status: MembershipStatus.values[m['status']],
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
        resolvedAt: m['resolvedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['resolvedAt'])
            : null,
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
  final String cardNumber;   // شماره کارت مقصد برای کارت به کارت
  final String cardHolder;   // نام صاحب کارت
  final DateTime createdAt;

  const Building({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.unitsCount,
    required this.managerPhone,
    required this.inviteCode,
    this.cardNumber = '',
    this.cardHolder = '',
    required this.createdAt,
  });

  bool get hasCardInfo => cardNumber.isNotEmpty && cardHolder.isNotEmpty;

  Building copyWith({String? cardNumber, String? cardHolder}) => Building(
        id: id,
        name: name,
        address: address,
        city: city,
        unitsCount: unitsCount,
        managerPhone: managerPhone,
        inviteCode: inviteCode,
        cardNumber: cardNumber ?? this.cardNumber,
        cardHolder: cardHolder ?? this.cardHolder,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'unitsCount': unitsCount,
        'managerPhone': managerPhone,
        'inviteCode': inviteCode,
        'cardNumber': cardNumber,
        'cardHolder': cardHolder,
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
        cardNumber: m['cardNumber'] ?? '',
        cardHolder: m['cardHolder'] ?? '',
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

/// دسته‌بندی پرداخت
enum PaymentCategory { charge, water, repair, other }

extension PaymentCategoryX on PaymentCategory {
  String get label => switch (this) {
        PaymentCategory.charge => 'شارژ ساختمان',
        PaymentCategory.water => 'آب',
        PaymentCategory.repair => 'تعمیرات',
        PaymentCategory.other => 'هزینه متفرقه',
      };

  String get emoji => switch (this) {
        PaymentCategory.charge => '🏢',
        PaymentCategory.water => '💧',
        PaymentCategory.repair => '🔧',
        PaymentCategory.other => '📋',
      };
}

/// وضعیت پرداخت
enum PaymentStatus { unpaid, awaitingApproval, paid, rejected }

extension PaymentStatusX on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.unpaid => 'پرداخت نشده',
        PaymentStatus.awaitingApproval => 'در انتظار تایید مدیر',
        PaymentStatus.paid => 'تایید شده',
        PaymentStatus.rejected => 'رد شده',
      };
}

/// روش پرداخت
enum PaymentMethod { none, online, cardToCard }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.none => '-',
        PaymentMethod.online => 'پرداخت آنلاین',
        PaymentMethod.cardToCard => 'کارت به کارت',
      };
}

/// یک پرداخت مستقل (شارژ، آب، تعمیرات و...)
class Payment {
  final String id;
  final String buildingId;
  final String unitId;
  final PaymentCategory category;
  final String title;        // عنوان پرداخت (مثلا «شارژ شهریور»)
  final String month;        // دوره/ماه شمسی
  final int amount;
  final PaymentStatus status;
  final PaymentMethod method;
  final String? receiptNote; // توضیح رسید ارسالی ساکن
  final String? rejectionReason; // دلیل رد توسط مدیر
  final DateTime dueDate;
  final DateTime? paidAt;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.buildingId,
    required this.unitId,
    required this.category,
    required this.title,
    required this.month,
    required this.amount,
    required this.status,
    this.method = PaymentMethod.none,
    this.receiptNote,
    this.rejectionReason,
    required this.dueDate,
    this.paidAt,
    required this.createdAt,
  });

  Payment copyWith({
    PaymentStatus? status,
    PaymentMethod? method,
    String? receiptNote,
    String? rejectionReason,
    DateTime? paidAt,
    bool clearRejection = false,
  }) =>
      Payment(
        id: id,
        buildingId: buildingId,
        unitId: unitId,
        category: category,
        title: title,
        month: month,
        amount: amount,
        status: status ?? this.status,
        method: method ?? this.method,
        receiptNote: receiptNote ?? this.receiptNote,
        rejectionReason:
            clearRejection ? null : (rejectionReason ?? this.rejectionReason),
        dueDate: dueDate,
        paidAt: paidAt ?? this.paidAt,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'unitId': unitId,
        'category': category.index,
        'title': title,
        'month': month,
        'amount': amount,
        'status': status.index,
        'method': method.index,
        'receiptNote': receiptNote,
        'rejectionReason': rejectionReason,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'paidAt': paidAt?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Payment.fromMap(Map m) => Payment(
        id: m['id'],
        buildingId: m['buildingId'] ?? '',
        unitId: m['unitId'],
        category: PaymentCategory.values[m['category']],
        title: m['title'],
        month: m['month'],
        amount: m['amount'],
        status: PaymentStatus.values[m['status']],
        method: PaymentMethod.values[m['method'] ?? 0],
        receiptNote: m['receiptNote'],
        rejectionReason: m['rejectionReason'],
        dueDate: DateTime.fromMillisecondsSinceEpoch(m['dueDate']),
        paidAt: m['paidAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['paidAt'])
            : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
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
