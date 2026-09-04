/// ---------------------------------------------------------------------------
/// موجودیت‌های تعاملات ساکنین: رزرواسیون مشاعات و رأی‌گیری مجمع
/// ---------------------------------------------------------------------------

/// امکانات مشترک قابل رزرو
class Amenity {
  final String id;
  final String name;
  final String icon;

  /// ودیعه پیش‌فرض رزرو (تومان) - قابل دریافت آنلاین
  final int defaultDeposit;

  /// حداکثر ساعت مجاز هر رزرو
  final int maxHours;

  const Amenity({
    required this.id,
    required this.name,
    required this.icon,
    this.defaultDeposit = 0,
    this.maxHours = 2,
  });

  bool get requiresDeposit => defaultDeposit > 0;

  /// امکانات پیش‌فرض سیستم
  static const List<Amenity> defaults = [
    Amenity(
        id: 'am_hall',
        name: 'سالن اجتماعات',
        icon: 'hall',
        defaultDeposit: 500000,
        maxHours: 6),
    Amenity(
        id: 'am_pool',
        name: 'استخر و سونا',
        icon: 'pool',
        defaultDeposit: 200000,
        maxHours: 2),
    Amenity(id: 'am_gym', name: 'سالن ورزشی', icon: 'gym', maxHours: 2),
    Amenity(
        id: 'am_guest',
        name: 'سوئیت مهمان',
        icon: 'guest',
        defaultDeposit: 800000,
        maxHours: 24),
    Amenity(
        id: 'am_roof',
        name: 'روف‌گاردن',
        icon: 'roof',
        defaultDeposit: 300000,
        maxHours: 4),
  ];

  static Amenity? byId(String id) {
    for (final a in defaults) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// وضعیت رزرو مشاعات
enum BookingStatus { pendingDeposit, confirmed, cancelled, completed }

extension BookingStatusX on BookingStatus {
  String get label => switch (this) {
        BookingStatus.pendingDeposit => 'در انتظار پرداخت ودیعه',
        BookingStatus.confirmed => 'تایید شده',
        BookingStatus.cancelled => 'لغو شده',
        BookingStatus.completed => 'انجام شده',
      };

  bool get isBlocking =>
      this == BookingStatus.pendingDeposit || this == BookingStatus.confirmed;
}

/// ---------------------------------------------------------------------------
/// رزرو تقویمی امکانات مشترک با تسویه ودیعه (جدول amenity_bookings)
/// ---------------------------------------------------------------------------
class AmenityBooking {
  final String id;
  final String buildingId;
  final String unitId;
  final String amenityId;
  final String amenityName;
  final DateTime startTime;
  final DateTime endTime;

  /// مبلغ ودیعه رزرو (تومان)
  final int depositAmount;

  /// شناسه صورتحساب ودیعه (در صورت دریافت آنلاین)
  final String? depositInvoiceId;

  final BookingStatus status;
  final String? note;
  final DateTime createdAt;

  const AmenityBooking({
    required this.id,
    required this.buildingId,
    required this.unitId,
    required this.amenityId,
    required this.amenityName,
    required this.startTime,
    required this.endTime,
    this.depositAmount = 0,
    this.depositInvoiceId,
    this.status = BookingStatus.confirmed,
    this.note,
    required this.createdAt,
  });

  /// بازه رزرو به ساعت
  double get durationHours =>
      endTime.difference(startTime).inMinutes / 60.0;

  bool get requiresDeposit => depositAmount > 0;

  /// رزرو در گذشته است؟
  bool get isPast => DateTime.now().isAfter(endTime);

  /// بررسی تداخل زمانی با رزرو دیگر
  bool overlaps(DateTime otherStart, DateTime otherEnd) =>
      startTime.isBefore(otherEnd) && otherStart.isBefore(endTime);

  AmenityBooking copyWith({
    BookingStatus? status,
    String? depositInvoiceId,
    String? note,
  }) =>
      AmenityBooking(
        id: id,
        buildingId: buildingId,
        unitId: unitId,
        amenityId: amenityId,
        amenityName: amenityName,
        startTime: startTime,
        endTime: endTime,
        depositAmount: depositAmount,
        depositInvoiceId: depositInvoiceId ?? this.depositInvoiceId,
        status: status ?? this.status,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'unitId': unitId,
        'amenityId': amenityId,
        'amenityName': amenityName,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'depositAmount': depositAmount,
        'depositInvoiceId': depositInvoiceId,
        'status': status.index,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory AmenityBooking.fromMap(Map m) => AmenityBooking(
        id: m['id'],
        buildingId: m['buildingId'],
        unitId: m['unitId'],
        amenityId: m['amenityId'],
        amenityName: m['amenityName'] ?? '',
        startTime: DateTime.fromMillisecondsSinceEpoch(m['startTime']),
        endTime: DateTime.fromMillisecondsSinceEpoch(m['endTime']),
        depositAmount: m['depositAmount'] ?? 0,
        depositInvoiceId: m['depositInvoiceId'],
        status: BookingStatus.values[m['status'] ?? 1],
        note: m['note'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      );
}

/// ---------------------------------------------------------------------------
/// روش شمارش آرا در مجمع عمومی
///
///   • simple   : هر واحد مسکونی یک رأی (شمارش ساده)
///   • weighted : وزن رأی بر پایه مساحت سندی واحد (ماده ۷ آیین‌نامه)
///
/// طبق قانون تملک آپارتمان‌ها، تصمیمات مجمع عمومی با اکثریت آرای
/// مالکینی که بیش از نصف مساحت تمام قسمت‌های اختصاصی را مالک باشند
/// معتبر است؛ لذا شمارش وزنی مبنای قانونی دارد.
/// ---------------------------------------------------------------------------
enum VotingMethod { simple, weighted }

extension VotingMethodX on VotingMethod {
  String get label => switch (this) {
        VotingMethod.simple => 'شمارش ساده (هر واحد یک رأی)',
        VotingMethod.weighted => 'شمارش وزنی (بر پایه متراژ سندی)',
      };

  String get shortLabel => switch (this) {
        VotingMethod.simple => 'ساده',
        VotingMethod.weighted => 'وزنی',
      };

  String get legalNote => switch (this) {
        VotingMethod.simple =>
          'مناسب تصمیمات جاری و اداری ساختمان؛ هر واحد مسکونی مستقل از متراژ، یک رأی دارد.',
        VotingMethod.weighted =>
          'مبنای قانونی ماده ۶ و ۷ قانون تملک آپارتمان‌ها؛ وزن رأی هر مالک متناسب با مساحت اختصاصی سند اوست.',
      };
}

/// وضعیت رأی‌گیری
enum PollStatus { draft, active, closed }

extension PollStatusX on PollStatus {
  String get label => switch (this) {
        PollStatus.draft => 'پیش‌نویس',
        PollStatus.active => 'در حال رأی‌گیری',
        PollStatus.closed => 'پایان‌یافته',
      };
}

/// گزینه رأی
class PollOption {
  final String id;
  final String title;

  const PollOption({required this.id, required this.title});

  Map<String, dynamic> toMap() => {'id': id, 'title': title};

  factory PollOption.fromMap(Map m) =>
      PollOption(id: m['id'], title: m['title']);
}

/// رأی ثبت‌شده یک واحد
class Vote {
  final String id;
  final String pollId;
  final String unitId;
  final String userId;
  final String optionId;

  /// وزن رأی (در روش وزنی = متراژ واحد، در روش ساده = ۱)
  final double weight;

  final DateTime castAt;

  const Vote({
    required this.id,
    required this.pollId,
    required this.unitId,
    required this.userId,
    required this.optionId,
    this.weight = 1,
    required this.castAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'pollId': pollId,
        'unitId': unitId,
        'userId': userId,
        'optionId': optionId,
        'weight': weight,
        'castAt': castAt.millisecondsSinceEpoch,
      };

  factory Vote.fromMap(Map m) => Vote(
        id: m['id'],
        pollId: m['pollId'],
        unitId: m['unitId'],
        userId: m['userId'] ?? '',
        optionId: m['optionId'],
        weight: (m['weight'] as num?)?.toDouble() ?? 1,
        castAt: DateTime.fromMillisecondsSinceEpoch(m['castAt']),
      );
}

/// ---------------------------------------------------------------------------
/// رأی‌گیری رسمی مجمع عمومی ساختمان
/// ---------------------------------------------------------------------------
class Poll {
  final String id;
  final String buildingId;
  final String title;
  final String description;
  final VotingMethod method;
  final List<PollOption> options;
  final PollStatus status;

  /// فقط مالکین حق رأی دارند؟ (تصمیمات مالکانه مانند تعمیرات اساسی)
  final bool ownersOnly;

  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;

  const Poll({
    required this.id,
    required this.buildingId,
    required this.title,
    this.description = '',
    this.method = VotingMethod.simple,
    required this.options,
    this.status = PollStatus.active,
    this.ownersOnly = false,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
  });

  bool get isOpen =>
      status == PollStatus.active &&
      DateTime.now().isAfter(startsAt) &&
      DateTime.now().isBefore(endsAt);

  bool get isExpired => DateTime.now().isAfter(endsAt);

  int get daysLeft {
    final d = endsAt.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  Poll copyWith({PollStatus? status, DateTime? endsAt}) => Poll(
        id: id,
        buildingId: buildingId,
        title: title,
        description: description,
        method: method,
        options: options,
        status: status ?? this.status,
        ownersOnly: ownersOnly,
        startsAt: startsAt,
        endsAt: endsAt ?? this.endsAt,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'title': title,
        'description': description,
        'method': method.index,
        'options': options.map((o) => o.toMap()).toList(),
        'status': status.index,
        'ownersOnly': ownersOnly,
        'startsAt': startsAt.millisecondsSinceEpoch,
        'endsAt': endsAt.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Poll.fromMap(Map m) => Poll(
        id: m['id'],
        buildingId: m['buildingId'],
        title: m['title'],
        description: m['description'] ?? '',
        method: VotingMethod.values[m['method'] ?? 0],
        options: (m['options'] as List)
            .map((o) => PollOption.fromMap(Map<String, dynamic>.from(o)))
            .toList(),
        status: PollStatus.values[m['status'] ?? 1],
        ownersOnly: m['ownersOnly'] ?? false,
        startsAt: DateTime.fromMillisecondsSinceEpoch(m['startsAt']),
        endsAt: DateTime.fromMillisecondsSinceEpoch(m['endsAt']),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      );
}

/// نتیجه شمارش آرای یک رأی‌گیری
class PollResult {
  final Poll poll;

  /// وزن/تعداد آرای هر گزینه به تفکیک شناسه گزینه
  final Map<String, double> tally;

  /// تعداد واحدهای رأی‌داده
  final int participantUnits;

  /// تعداد کل واحدهای واجد شرایط
  final int eligibleUnits;

  /// مجموع وزن آرای ریخته‌شده
  final double totalWeight;

  /// مجموع وزن واجدین شرایط (کل متراژ در روش وزنی)
  final double eligibleWeight;

  const PollResult({
    required this.poll,
    required this.tally,
    required this.participantUnits,
    required this.eligibleUnits,
    required this.totalWeight,
    required this.eligibleWeight,
  });

  /// درصد مشارکت بر مبنای وزن
  double get participationRate =>
      eligibleWeight <= 0 ? 0 : totalWeight / eligibleWeight;

  /// گزینه برنده (بیشترین وزن)
  String? get winningOptionId {
    if (tally.isEmpty) return null;
    var best = tally.entries.first;
    for (final e in tally.entries) {
      if (e.value > best.value) best = e;
    }
    return best.value > 0 ? best.key : null;
  }

  /// سهم درصدی یک گزینه از کل آرای ریخته‌شده
  double shareOf(String optionId) {
    if (totalWeight <= 0) return 0;
    return (tally[optionId] ?? 0) / totalWeight;
  }

  /// آیا تصمیم حد نصاب قانونی (بیش از نصف مساحت کل) را کسب کرده است؟
  bool get hasLegalQuorum {
    final winner = winningOptionId;
    if (winner == null || eligibleWeight <= 0) return false;
    return (tally[winner] ?? 0) > eligibleWeight / 2;
  }
}
