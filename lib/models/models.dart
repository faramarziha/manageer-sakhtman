/// مدل واحد ساختمان
class Unit {
  final String id;
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
  final String title;
  final String body;
  final DateTime date;
  final bool isImportant;

  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.isImportant = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'date': date.millisecondsSinceEpoch,
        'isImportant': isImportant,
      };

  factory Notice.fromMap(Map m) => Notice(
        id: m['id'],
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
  final String title;
  final String description;
  final String category; // تاسیسات، برق، آسانسور، نظافت، سایر
  final DateTime date;
  final RequestStatus status;

  const MaintenanceRequest({
    required this.id,
    required this.unitId,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.status,
  });

  MaintenanceRequest copyWith({RequestStatus? status}) => MaintenanceRequest(
        id: id,
        unitId: unitId,
        title: title,
        description: description,
        category: category,
        date: date,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'unitId': unitId,
        'title': title,
        'description': description,
        'category': category,
        'date': date.millisecondsSinceEpoch,
        'status': status.index,
      };

  factory MaintenanceRequest.fromMap(Map m) => MaintenanceRequest(
        id: m['id'],
        unitId: m['unitId'],
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
  final DateTime date;
  final String timeSlot; // مثلا «۱۰ تا ۱۲»

  const Booking({
    required this.id,
    required this.facilityId,
    required this.unitId,
    required this.date,
    required this.timeSlot,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'facilityId': facilityId,
        'unitId': unitId,
        'date': date.millisecondsSinceEpoch,
        'timeSlot': timeSlot,
      };

  factory Booking.fromMap(Map m) => Booking(
        id: m['id'],
        facilityId: m['facilityId'],
        unitId: m['unitId'],
        date: DateTime.fromMillisecondsSinceEpoch(m['date']),
        timeSlot: m['timeSlot'],
      );
}
