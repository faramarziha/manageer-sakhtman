/// ---------------------------------------------------------------------------
/// موجودیت‌های حقوقی: استیفای مطالبات (ماده ۱۰ مکرر) و بیمه بنا (ماده ۱۴)
/// ---------------------------------------------------------------------------

/// مرحله فرایند قانونی وصول دیون (ماده ۱۰ مکرر قانون تملک آپارتمان‌ها)
///
/// گردش کار قانونی:
///   ۱. اخطاریه داخلی (ابلاغ درون‌برنامه‌ای به بدهکار)
///   ۲. اظهارنامه رسمی ۱۰ روزه (ارائه به دفاتر خدمات الکترونیک قضایی)
///   ۳. قطع خدمات مشترک (پس از انقضای مهلت ۱۰ روزه)
///   ۴. ارجاع به اجرای ثبت / مراجع قضایی
enum LegalStage { none, internalWarning, formalNotice, serviceCutoff, judicial }

extension LegalStageX on LegalStage {
  String get label => switch (this) {
        LegalStage.none => 'بدون اقدام',
        LegalStage.internalWarning => 'اخطاریه داخلی ابلاغ شد',
        LegalStage.formalNotice => 'اظهارنامه رسمی ۱۰ روزه صادر شد',
        LegalStage.serviceCutoff => 'قطع خدمات مشترک اجرا شد',
        LegalStage.judicial => 'ارجاع به مراجع قضایی',
      };

  String get shortLabel => switch (this) {
        LegalStage.none => '-',
        LegalStage.internalWarning => 'اخطاریه',
        LegalStage.formalNotice => 'اظهارنامه',
        LegalStage.serviceCutoff => 'قطع خدمات',
        LegalStage.judicial => 'قضایی',
      };

  /// مرحله بعدی مجاز در گردش کار قانونی
  LegalStage? get next => switch (this) {
        LegalStage.none => LegalStage.internalWarning,
        LegalStage.internalWarning => LegalStage.formalNotice,
        LegalStage.formalNotice => LegalStage.serviceCutoff,
        LegalStage.serviceCutoff => LegalStage.judicial,
        LegalStage.judicial => null,
      };
}

/// نوع خدمت مشترک قابل قطع (طبق ماده ۱۰ مکرر)
///
/// تبصره: قطع خدمات مشترک صرفاً پس از انقضای مهلت ۱۰ روزه اظهارنامه
/// و با رعایت شرط عدم ایجاد خطر برای ساکنین مجاز است.
enum SharedService { heating, hotWater, parkingRemote, poolAccess, gymAccess }

extension SharedServiceX on SharedService {
  String get label => switch (this) {
        SharedService.heating => 'موتورخانه / شوفاژ',
        SharedService.hotWater => 'آب گرم مشترک',
        SharedService.parkingRemote => 'ریموت پارکینگ',
        SharedService.poolAccess => 'دسترسی استخر',
        SharedService.gymAccess => 'دسترسی سالن ورزشی',
      };

  String get emoji => switch (this) {
        SharedService.heating => '🔥',
        SharedService.hotWater => '🚿',
        SharedService.parkingRemote => '🅿️',
        SharedService.poolAccess => '🏊',
        SharedService.gymAccess => '🏋️',
      };
}

/// ---------------------------------------------------------------------------
/// پرونده حقوقی مطالبات یک واحد بدهکار (ماده ۱۰ مکرر)
/// ---------------------------------------------------------------------------
class LegalCase {
  final String id;
  final String buildingId;
  final String unitId;

  /// مبلغ کل بدهی در زمان تشکیل پرونده (تومان)
  final int debtAmount;

  /// شناسه صورتحساب‌های معوق موضوع پرونده
  final List<String> invoiceIds;

  final LegalStage stage;

  /// تاریخ ابلاغ اخطاریه داخلی درون‌برنامه‌ای
  final DateTime? warningServedAt;

  /// تاریخ صدور اظهارنامه رسمی (شروع مهلت ۱۰ روزه قانونی)
  final DateTime? noticeIssuedAt;

  /// تاریخ اجرای قطع خدمات مشترک
  final DateTime? cutoffAt;

  /// خدماتی که قطع شده‌اند
  final List<SharedService> cutServices;

  /// مستندات بارگذاری‌شده (تصاویر فشرده ابلاغیه، صورتجلسه قطع خدمات)
  final List<String> documentUrls;

  final String? note;
  final bool isResolved;
  final DateTime createdAt;

  const LegalCase({
    required this.id,
    required this.buildingId,
    required this.unitId,
    required this.debtAmount,
    this.invoiceIds = const [],
    this.stage = LegalStage.none,
    this.warningServedAt,
    this.noticeIssuedAt,
    this.cutoffAt,
    this.cutServices = const [],
    this.documentUrls = const [],
    this.note,
    this.isResolved = false,
    required this.createdAt,
  });

  /// مهلت قانونی اظهارنامه ماده ۱۰ مکرر (روز)
  static const int noticeGraceDays = 10;

  /// تاریخ انقضای مهلت ۱۰ روزه اظهارنامه
  DateTime? get noticeDeadline =>
      noticeIssuedAt?.add(const Duration(days: noticeGraceDays));

  /// مهلت قانونی ۱۰ روزه سپری شده است؟
  bool get isGracePeriodOver {
    final deadline = noticeDeadline;
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }

  /// روزهای باقی‌مانده از مهلت قانونی
  int get graceDaysLeft {
    final deadline = noticeDeadline;
    if (deadline == null) return LegalCase.noticeGraceDays;
    final d = deadline.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  /// قطع خدمات مشترک قانوناً مجاز است؟
  /// (اظهارنامه صادر شده و مهلت ۱۰ روزه منقضی شده باشد)
  bool get canCutServices =>
      !isResolved && noticeIssuedAt != null && isGracePeriodOver;

  LegalCase copyWith({
    int? debtAmount,
    LegalStage? stage,
    DateTime? warningServedAt,
    DateTime? noticeIssuedAt,
    DateTime? cutoffAt,
    List<SharedService>? cutServices,
    List<String>? documentUrls,
    String? note,
    bool? isResolved,
  }) =>
      LegalCase(
        id: id,
        buildingId: buildingId,
        unitId: unitId,
        debtAmount: debtAmount ?? this.debtAmount,
        invoiceIds: invoiceIds,
        stage: stage ?? this.stage,
        warningServedAt: warningServedAt ?? this.warningServedAt,
        noticeIssuedAt: noticeIssuedAt ?? this.noticeIssuedAt,
        cutoffAt: cutoffAt ?? this.cutoffAt,
        cutServices: cutServices ?? this.cutServices,
        documentUrls: documentUrls ?? this.documentUrls,
        note: note ?? this.note,
        isResolved: isResolved ?? this.isResolved,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'unitId': unitId,
        'debtAmount': debtAmount,
        'invoiceIds': invoiceIds,
        'stage': stage.index,
        'warningServedAt': warningServedAt?.millisecondsSinceEpoch,
        'noticeIssuedAt': noticeIssuedAt?.millisecondsSinceEpoch,
        'cutoffAt': cutoffAt?.millisecondsSinceEpoch,
        'cutServices': cutServices.map((s) => s.index).toList(),
        'documentUrls': documentUrls,
        'note': note,
        'isResolved': isResolved,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory LegalCase.fromMap(Map m) => LegalCase(
        id: m['id'],
        buildingId: m['buildingId'],
        unitId: m['unitId'],
        debtAmount: m['debtAmount'] ?? 0,
        invoiceIds: List<String>.from(m['invoiceIds'] ?? const []),
        stage: LegalStage.values[m['stage'] ?? 0],
        warningServedAt: m['warningServedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['warningServedAt'])
            : null,
        noticeIssuedAt: m['noticeIssuedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['noticeIssuedAt'])
            : null,
        cutoffAt: m['cutoffAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['cutoffAt'])
            : null,
        cutServices: (m['cutServices'] as List?)
                ?.map((i) => SharedService.values[i as int])
                .toList() ??
            const [],
        documentUrls: List<String>.from(m['documentUrls'] ?? const []),
        note: m['note'],
        isResolved: m['isResolved'] ?? false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      );
}

/// ---------------------------------------------------------------------------
/// نوع بیمه‌نامه ساختمان (تکالیف ماده ۱۴ قانون تملک آپارتمان‌ها)
///
/// ماده ۱۴: مدیر مکلف است تمام بنا را به عنوان یک واحد در مقابل
/// آتش‌سوزی بیمه نماید. سهم هر شریک به تناسب مساحت اختصاصی وی
/// از مجموع مساحت‌ها محاسبه و وصول می‌شود.
/// ---------------------------------------------------------------------------
enum InsuranceType { fire, elevator, liability, earthquake }

extension InsuranceTypeX on InsuranceType {
  String get label => switch (this) {
        InsuranceType.fire => 'آتش‌سوزی بنا',
        InsuranceType.elevator => 'آسانسور',
        InsuranceType.liability => 'مسئولیت مدنی هیئت‌مدیره',
        InsuranceType.earthquake => 'زلزله و حوادث طبیعی',
      };

  String get emoji => switch (this) {
        InsuranceType.fire => '🔥',
        InsuranceType.elevator => '🛗',
        InsuranceType.liability => '⚖️',
        InsuranceType.earthquake => '🌎',
      };

  /// این بیمه طبق ماده ۱۴ الزامی قانونی است؟
  bool get isMandatory => this == InsuranceType.fire;

  String get legalNote => switch (this) {
        InsuranceType.fire =>
          'الزام قانونی ماده ۱۴: مدیر مکلف است تمام بنا را در مقابل آتش‌سوزی بیمه کند. در صورت عدم بیمه و بروز حادثه، مدیر مسئول جبران خسارت است.',
        InsuranceType.elevator =>
          'بیمه مسئولیت آسانسور طبق مقررات سازمان ملی استاندارد برای تمدید گواهی استاندارد الزامی است.',
        InsuranceType.liability =>
          'بیمه مسئولیت مدنی، هیئت‌مدیره را در قبال خسارات وارده به ساکنین و اشخاص ثالث در مشاعات پوشش می‌دهد.',
        InsuranceType.earthquake =>
          'پوشش تکمیلی حوادث طبیعی؛ اختیاری اما توصیه‌شده برای بناهای با قدمت بالا.',
      };
}

/// ---------------------------------------------------------------------------
/// بیمه‌نامه ثبت‌شده ساختمان (ماژول پایش بیمه ماده ۱۴)
/// ---------------------------------------------------------------------------
class InsurancePolicy {
  final String id;
  final String buildingId;
  final InsuranceType type;

  /// نام شرکت بیمه‌گر
  final String insurer;

  /// شماره بیمه‌نامه
  final String policyNumber;

  /// مبلغ حق بیمه پرداختی (تومان)
  final int premium;

  /// سرمایه/سقف پوشش بیمه (تومان)
  final int coverageAmount;

  final DateTime startDate;
  final DateTime endDate;

  /// آدرس تصویر فشرده بیمه‌نامه
  final String? documentUrl;

  /// آیا حق بیمه بین واحدها بر اساس متراژ سرشکن شده است؟
  final bool isAllocated;

  final String? note;
  final DateTime createdAt;

  const InsurancePolicy({
    required this.id,
    required this.buildingId,
    required this.type,
    required this.insurer,
    required this.policyNumber,
    required this.premium,
    this.coverageAmount = 0,
    required this.startDate,
    required this.endDate,
    this.documentUrl,
    this.isAllocated = false,
    this.note,
    required this.createdAt,
  });

  /// آستانه‌های هشدار انقضای بیمه‌نامه (روز)
  static const List<int> alertThresholds = [30, 15];

  bool get isExpired => DateTime.now().isAfter(endDate);

  int get daysToExpiry {
    final d = endDate.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  /// بیمه‌نامه در آستانه انقضا است؟ (۳۰ یا ۱۵ روز قبل از سررسید)
  bool get isExpiringSoon => !isExpired && daysToExpiry <= 30;

  /// هشدار بحرانی (کمتر از ۱۵ روز)
  bool get isCriticalAlert => !isExpired && daysToExpiry <= 15;

  /// متن هشدار مناسب وضعیت بیمه‌نامه
  String? get alertMessage {
    if (isExpired) {
      return 'بیمه‌نامه ${type.label} منقضی شده است. تمدید فوری الزامی است.';
    }
    if (isCriticalAlert) {
      return 'تنها $daysToExpiry روز تا انقضای بیمه‌نامه ${type.label} باقی است.';
    }
    if (isExpiringSoon) {
      return 'بیمه‌نامه ${type.label} تا $daysToExpiry روز آینده منقضی می‌شود.';
    }
    return null;
  }

  /// محاسبه سهم یک واحد از حق بیمه بر اساس نسبت متراژ اختصاصی
  ///
  /// طبق ماده ۱۴، مبنای تقسیم حق بیمه آتش‌سوزی صرفاً نسبت مساحت
  /// اختصاصی واحد به مجموع مساحت‌های اختصاصی بناست.
  int shareForUnit({required double unitArea, required double totalArea}) {
    if (totalArea <= 0 || unitArea <= 0) return 0;
    return ((unitArea / totalArea) * premium).round();
  }

  InsurancePolicy copyWith({
    String? insurer,
    String? policyNumber,
    int? premium,
    int? coverageAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? documentUrl,
    bool? isAllocated,
    String? note,
  }) =>
      InsurancePolicy(
        id: id,
        buildingId: buildingId,
        type: type,
        insurer: insurer ?? this.insurer,
        policyNumber: policyNumber ?? this.policyNumber,
        premium: premium ?? this.premium,
        coverageAmount: coverageAmount ?? this.coverageAmount,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        documentUrl: documentUrl ?? this.documentUrl,
        isAllocated: isAllocated ?? this.isAllocated,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'type': type.index,
        'insurer': insurer,
        'policyNumber': policyNumber,
        'premium': premium,
        'coverageAmount': coverageAmount,
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
        'documentUrl': documentUrl,
        'isAllocated': isAllocated,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory InsurancePolicy.fromMap(Map m) => InsurancePolicy(
        id: m['id'],
        buildingId: m['buildingId'],
        type: InsuranceType.values[m['type'] ?? 0],
        insurer: m['insurer'] ?? '',
        policyNumber: m['policyNumber'] ?? '',
        premium: m['premium'] ?? 0,
        coverageAmount: m['coverageAmount'] ?? 0,
        startDate: DateTime.fromMillisecondsSinceEpoch(m['startDate']),
        endDate: DateTime.fromMillisecondsSinceEpoch(m['endDate']),
        documentUrl: m['documentUrl'],
        isAllocated: m['isAllocated'] ?? false,
        note: m['note'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      );
}
