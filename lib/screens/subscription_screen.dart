import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/payment_gateway.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import '../widgets/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// اشتراک ساختمان (گام ۷ سند - منطق Freemium)
///
/// قانون طلایی: ساختمان‌های تا ۶ واحد کاملاً رایگان و همیشگی هستند و
/// **هیچ درخواست پرداختی** به آن‌ها نمایش داده نمی‌شود. تنها زمانی که
/// مدیر قصد ثبت واحد هفتم را داشته باشد، پنجره ارتقا به پلن اقتصادی
/// نمایش داده می‌شود.
/// ---------------------------------------------------------------------------
class SubscriptionScreen extends StatefulWidget {
  /// در صورت باز شدن از مسیر «تلاش برای افزودن واحد مازاد»
  final bool triggeredByUnitLimit;

  const SubscriptionScreen({super.key, this.triggeredByUnitLimit = false});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingCycle _cycle = BillingCycle.yearly;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final building = store.currentBuilding;
    final sub = store.currentSubscription;
    final plan = store.currentPlan;
    final units = store.totalUnits;

    if (building == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.apartment_outlined,
            message: 'ابتدا باید ساختمان خود را ثبت کنید',
          ),
        ),
      );
    }

    // ------------------------------------------------------------------
    // حالت رایگان بدون فشار فروش: ساختمان ≤۶ واحد و بدون تلاش برای
    // افزودن واحد مازاد → فقط پیام اطمینان‌بخش، بدون هیچ دکمه پرداخت.
    // ------------------------------------------------------------------
    final quietFreeMode = store.isFreePlan &&
        units <= AppStore.freeUnitLimit &&
        !widget.triggeredByUnitLimit;

    return Scaffold(
      appBar: AppBar(title: const Text('اشتراک ساختمان')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CurrentPlanCard(
              plan: plan,
              subscription: sub,
              units: units,
              limit: store.unitLimit,
            ),
            const SizedBox(height: 16),

            if (quietFreeMode) ...[
              const _FreeForeverBanner(),
              const SizedBox(height: 16),
              _PlanCard(
                plan: PlanType.free,
                cycle: _cycle,
                isCurrent: true,
                units: units,
                onSelect: null,
              ),
              const SizedBox(height: 16),
              const _ZeroCostNote(),
              const SizedBox(height: 24),
              const SectionHeader(title: 'پلن‌های آینده (در صورت رشد ساختمان)'),
              const SizedBox(height: 8),
              const Text(
                'اگر روزی تعداد واحدهای ساختمان از ۶ عدد بیشتر شد، '
                'پلن مناسب به شما پیشنهاد خواهد شد. تا آن زمان نیازی به '
                'هیچ پرداختی نیست.',
                style: TextStyle(
                    fontSize: 12, height: 1.8, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              for (final p in [PlanType.economy, PlanType.comprehensive])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlanCard(
                    plan: p,
                    cycle: _cycle,
                    isCurrent: false,
                    units: units,
                    dimmed: true,
                    onSelect: () => _purchase(p),
                  ),
                ),
            ] else ...[
              if (widget.triggeredByUnitLimit) ...[
                _UnitLimitBanner(
                  units: units,
                  limit: store.unitLimit,
                  required_: store.requiredPlanForNextUnit,
                ),
                const SizedBox(height: 16),
              ],
              if (store.subscriptionExpired) ...[
                const _ExpiredBanner(),
                const SizedBox(height: 16),
              ],

              // انتخاب دوره پرداخت
              Center(
                child: SegmentedButton<BillingCycle>(
                  segments: [
                    const ButtonSegment(
                        value: BillingCycle.monthly, label: Text('ماهانه')),
                    ButtonSegment(
                      value: BillingCycle.yearly,
                      label: Text(
                          'سالانه (${Persian.digits(PlanType.economy.yearlyDiscountPercent)}٪ تخفیف)'),
                    ),
                  ],
                  selected: {_cycle},
                  onSelectionChanged: (s) => setState(() => _cycle = s.first),
                ),
              ),
              const SizedBox(height: 18),

              for (final p in PlanType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlanCard(
                    plan: p,
                    cycle: _cycle,
                    isCurrent: p == plan && !store.subscriptionExpired,
                    units: units,
                    recommended: p == store.requiredPlanForNextUnit &&
                        p != PlanType.free,
                    disabled: p.maxUnits < units,
                    onSelect: (p == plan && !store.subscriptionExpired) ||
                            p.maxUnits < units
                        ? null
                        : () => _purchase(p),
                  ),
                ),
              const SizedBox(height: 8),
              const _ZeroCostNote(),
            ],

            const SizedBox(height: 24),

            // ---------- بسته اعتبار پیامک ----------
            const SectionHeader(title: 'اعتبار پیامک سیستمی (اختیاری)'),
            const SizedBox(height: 6),
            Text(
              'ارسال قبض از طریق پیام‌رسان‌های گوشی (ایتا، بله، روبیکا، واتساپ، '
              'تلگرام) کاملاً رایگان است. تنها در صورتی که ساختمان شما اصرار '
              'به ارسال پیامک سیستمی دارد، باید اعتبار پیش‌خرید کنید.\n'
              'اعتبار فعلی: ${Persian.digits(building.smsCredit)} پیامک',
              style: const TextStyle(
                  fontSize: 12, height: 1.8, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final pack in SmsCreditPack.packs)
              _SmsPackTile(
                pack: pack,
                busy: _busy,
                onBuy: () => _buySms(pack),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------

  Future<void> _purchase(PlanType plan) async {
    final store = context.read<AppStore>();
    final building = store.currentBuilding;
    if (building == null || _busy) return;

    if (plan.isFree) {
      await store.activateSubscription(PlanType.free);
      if (mounted) showSuccessSnack(context, 'پلن رایگان فعال شد');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('خرید پلن ${plan.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('دوره: ${_cycle.label}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              'مبلغ قابل پرداخت: ${Persian.toman(plan.priceFor(_cycle))}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'این مبلغ بابت اشتراک نرم‌افزار به حساب شرکت واریز می‌شود و '
              'کاملاً از وجوه شارژ ساختمان (که مستقیماً به شبای مدیر واریز '
              'می‌گردد) جدا است.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.8, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('پرداخت')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final res = await PaymentGateway.instance.purchaseSubscription(
      buildingId: building.id,
      plan: plan,
      cycle: _cycle,
    );
    if (!mounted) return;

    if (res.success) {
      await store.activateSubscription(plan,
          cycle: _cycle, paymentRef: res.rrn);
      if (!mounted) return;
      setState(() => _busy = false);
      showSuccessSnack(context, 'پلن ${plan.name} با موفقیت فعال شد');
      if (widget.triggeredByUnitLimit) Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(res.message ?? 'پرداخت ناموفق بود'),
        ),
      );
    }
  }

  Future<void> _buySms(SmsCreditPack pack) async {
    final store = context.read<AppStore>();
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await store.addSmsCredit(pack.smsCount);
    if (!mounted) return;
    setState(() => _busy = false);
    showSuccessSnack(
        context, '${Persian.digits(pack.smsCount)} پیامک به اعتبار افزوده شد');
  }
}

// ===========================================================================
// دیالوگ ارتقا هنگام تلاش برای افزودن واحد مازاد بر سقف پلن (گام ۷)
// ===========================================================================

/// نمایش دیالوگ ارتقای پلن هنگام رسیدن به سقف واحد.
/// خروجی `true` یعنی کاربر پلن را ارتقا داد و می‌توان واحد را ثبت کرد.
Future<bool> showUpgradePlanDialog(BuildContext context) async {
  final store = context.read<AppStore>();
  final required_ = store.requiredPlanForNextUnit;
  final current = store.currentPlan;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.workspace_premium_rounded,
          color: AppColors.primary, size: 34),
      title: const Text(
        'سقف واحدهای پلن فعلی تکمیل شد',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'پلن «${current.name}» تا ${Persian.digits(store.unitLimit)} واحد '
            'پشتیبانی می‌شود و شما هم‌اکنون ${Persian.digits(store.totalUnits)} '
            'واحد ثبت کرده‌اید.\n\n'
            'برای ثبت واحد جدید، پلن «${required_.name}» با هزینه '
            '${Persian.toman(required_.priceMonthly)} در ماه '
            '(یا ${Persian.toman(required_.priceYearly)} سالانه) لازم است.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, height: 1.9),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'وجوه شارژ ساختمان همچنان مستقیماً به شبای مدیر واریز می‌شود؛ '
              'این هزینه فقط بابت اشتراک نرم‌افزار است.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, height: 1.7),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('بعداً')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مشاهده پلن‌ها')),
      ],
    ),
  );

  if (go != true || !context.mounted) return false;

  final upgraded = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const SubscriptionScreen(triggeredByUnitLimit: true),
    ),
  );
  return upgraded ?? false;
}

// ===========================================================================
// ویجت‌های داخلی
// ===========================================================================

class _CurrentPlanCard extends StatelessWidget {
  final PlanType plan;
  final Subscription? subscription;
  final int units;
  final int limit;

  const _CurrentPlanCard({
    required this.plan,
    required this.subscription,
    required this.units,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = limit == 0 ? 0.0 : (units / limit).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'پلن فعال: ${plan.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (subscription?.isPerpetual ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('همیشگی',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            plan.tagline,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'واحدهای ثبت‌شده: ${Persian.digits(units)}'
                '${limit >= 99999 ? '' : ' از ${Persian.digits(limit)}'}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              if (subscription != null && !subscription!.isPerpetual)
                Text(
                  '${Persian.digits(subscription!.daysLeft)} روز اعتبار',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.white24,
              color: ratio >= 1 ? AppColors.warning : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeForeverBanner extends StatelessWidget {
  const _FreeForeverBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.volunteer_activism_rounded,
              color: AppColors.success, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ساختمان شما برای همیشه رایگان است',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'ساختمان‌های تا ۶ واحد بدون هیچ هزینه و محدودیت زمانی از '
                  'همه امکانات پایه استفاده می‌کنند. هیچ درخواست پرداختی از '
                  'شما نخواهیم داشت.',
                  style: TextStyle(fontSize: 11.5, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitLimitBanner extends StatelessWidget {
  final int units;
  final int limit;
  final PlanType required_;

  const _UnitLimitBanner({
    required this.units,
    required this.limit,
    required this.required_,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.upgrade_rounded,
              color: AppColors.warning, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'برای ثبت واحد جدید نیاز به ارتقای پلن دارید',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'سقف پلن فعلی ${Persian.digits(limit)} واحد است و '
                  '${Persian.digits(units)} واحد ثبت شده. '
                  'پلن پیشنهادی: ${required_.name}',
                  style: const TextStyle(fontSize: 11.5, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiredBanner extends StatelessWidget {
  const _ExpiredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'اشتراک شما منقضی شده است. برای ادامه استفاده از امکانات '
              'پیشرفته، پلن خود را تمدید کنید.',
              style: TextStyle(fontSize: 12, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanType plan;
  final BillingCycle cycle;
  final bool isCurrent;
  final bool recommended;
  final bool disabled;
  final bool dimmed;
  final int units;
  final VoidCallback? onSelect;

  const _PlanCard({
    required this.plan,
    required this.cycle,
    required this.isCurrent,
    required this.units,
    this.recommended = false,
    this.disabled = false,
    this.dimmed = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final price = plan.priceFor(cycle);
    final accent = switch (plan) {
      PlanType.free => AppColors.success,
      PlanType.economy => AppColors.primary,
      PlanType.comprehensive => AppColors.secondary,
    };

    return Opacity(
      opacity: dimmed ? 0.75 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? accent
                : (recommended ? accent.withValues(alpha: 0.6) : AppColors.divider),
            width: isCurrent || recommended ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: accent),
                  ),
                ),
                if (isCurrent)
                  const StatusChip(
                      label: 'پلن فعلی', color: AppColors.success)
                else if (recommended)
                  StatusChip(label: 'پیشنهادی', color: accent)
                else if (disabled)
                  const StatusChip(
                      label: 'ناکافی برای تعداد واحد',
                      color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 4),
            Text(plan.tagline,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.isFree ? 'رایگان' : Persian.money(price),
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: accent),
                ),
                if (!plan.isFree) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'تومان / ${cycle.label}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            for (final f in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 15, color: accent),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(f,
                          style: const TextStyle(fontSize: 12, height: 1.6)),
                    ),
                  ],
                ),
              ),
            if (onSelect != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  onPressed: onSelect,
                  child: Text(plan.isFree ? 'فعال‌سازی' : 'خرید این پلن'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SmsPackTile extends StatelessWidget {
  final SmsCreditPack pack;
  final bool busy;
  final VoidCallback onBuy;

  const _SmsPackTile({
    required this.pack,
    required this.busy,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.sms_rounded,
              size: 20, color: AppColors.accent),
        ),
        title: Text(pack.title,
            style:
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${Persian.digits(pack.smsCount)} پیامک • '
          'هر پیامک ${Persian.money(pack.pricePerSms)} تومان',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: FilledButton.tonal(
          onPressed: busy ? null : onBuy,
          child: Text(Persian.money(pack.price),
              style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _ZeroCostNote extends StatelessWidget {
  const _ZeroCostNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'سیاست شفافیت هزینه',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• وجوه شارژ ساکنین از طریق تسهیم پرداخت مستقیماً به شبای مدیر '
            'ساختمان واریز می‌شود و هرگز در حساب شرکت نرم‌افزاری نمی‌نشیند.\n'
            '• کارمزد درگاه شاپرک (یک درصد تا سقف مصوب بانک مرکزی) بر عهده '
            'پرداخت‌کننده است یا از تسویه مدیر کسر می‌شود.\n'
            '• ارسال قبض از طریق پیام‌رسان‌های گوشی رایگان است و هیچ هزینه '
            'پیامکی به ساختمان تحمیل نمی‌شود.\n'
            '• هیچ سازوکار برداشت خودکار از حساب ساکنین در این سامانه وجود '
            'ندارد.',
            style: TextStyle(fontSize: 11.5, height: 2.0),
          ),
        ],
      ),
    );
  }
}
