import 'building.dart';

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

/// ---------------------------------------------------------------------------
/// کاربر اپلیکیشن
///
/// احراز هویت صرفاً با شماره تلفن همراه انجام می‌شود. ارتباط کاربر با
/// واحدها از طریق جدول unit_users مدیریت می‌شود تا ورود چندملکیتی
/// (یک شماره موبایل، چند واحد در چند ساختمان) پشتیبانی گردد.
/// ---------------------------------------------------------------------------
class User {
  final String id;
  final String phone;
  final String fullName;
  final UserRole role;

  /// ساختمان فعال جاری کاربر (قابل سوییچ در حالت چندملکیتی)
  final String? buildingId;

  /// واحد فعال جاری کاربر
  final String? unitId;

  final MembershipStatus membershipStatus;

  /// نقش قانونی در واحد فعال (مالک/مستاجر)
  final UnitRole unitRole;

  final DateTime createdAt;

  const User({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
    this.buildingId,
    this.unitId,
    this.membershipStatus = MembershipStatus.none,
    this.unitRole = UnitRole.tenant,
    required this.createdAt,
  });

  bool get isManager => role == UserRole.manager;
  bool get isOwner => unitRole == UnitRole.owner;

  User copyWith({
    String? fullName,
    String? buildingId,
    String? unitId,
    MembershipStatus? membershipStatus,
    UnitRole? unitRole,
    bool clearUnit = false,
  }) =>
      User(
        id: id,
        phone: phone,
        fullName: fullName ?? this.fullName,
        role: role,
        buildingId: buildingId ?? this.buildingId,
        unitId: clearUnit ? null : (unitId ?? this.unitId),
        membershipStatus: membershipStatus ?? this.membershipStatus,
        unitRole: unitRole ?? this.unitRole,
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
        'unitRole': unitRole.index,
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
        // سازگاری با نسخه قدیمی: isOwner (bool) → unitRole
        unitRole: m['unitRole'] != null
            ? UnitRole.values[m['unitRole']]
            : (m['isOwner'] == true ? UnitRole.owner : UnitRole.tenant),
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
  final UnitRole requestedRole;
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
    required this.requestedRole,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  bool get isOwner => requestedRole == UnitRole.owner;

  MembershipRequest copyWith({MembershipStatus? status, DateTime? resolvedAt}) =>
      MembershipRequest(
        id: id,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        buildingId: buildingId,
        unitNumber: unitNumber,
        requestedRole: requestedRole,
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
        'requestedRole': requestedRole.index,
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
        requestedRole: m['requestedRole'] != null
            ? UnitRole.values[m['requestedRole']]
            : (m['isOwner'] == true ? UnitRole.owner : UnitRole.tenant),
        status: MembershipStatus.values[m['status']],
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
        resolvedAt: m['resolvedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['resolvedAt'])
            : null,
      );
}

/// اعلان ساختمان (تابلوی اعلانات)
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
  final String category;
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
