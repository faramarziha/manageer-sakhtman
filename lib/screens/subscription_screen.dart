import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_store.dart';
import '../data/billing_service.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import '../widgets/common_widgets.dart';

/// صفحه طرح‌های اشتراک و خرید درون‌برنامه‌ای (آماده برای بازار)
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  PlanType? _purchasing;

  @override
  void initState() {
    super.initState();
    BillingService.instance.connect();
  }

  Future<void> _purchase(PlanType plan) async {
    setState(() => _purchasing = plan);
    final billing = BillingService.instance;
    final result = await billing.purchaseSubscription(plan);

    if (!mounted) return;

    if (result.success) {
      await context
          .read<AppStore>()
          .activateSubscription(plan, purchaseToken: result.purchaseToken);
      if (mounted) {
        setState(() => _purchasing = null);
        showSuccessSnack(
            context, 'اشتراک طرح ${plan.name} با موفقیت فعال شد');
      }
    } else {
      setState(() => _purchasing = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(result.message ?? 'خطا در فرایند پرداخت'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sub = store.currentSubscription;

    return Scaffold(
      appBar: AppBar(title: const Text('اشتراک ساختمان')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // وضعیت اشتراک فعلی
            if (sub != null) _CurrentPlanCard(subscription: sub),
            const SizedBox(height: 20),
            const SectionHeader(title: 'طرح‌های اشتراک ماهانه'),
            const SizedBox(height: 4),
            const Text(
              'پرداخت امن از طریق کافه‌بازار',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            ...PlanType.values.map((p) => _PlanCard(
                  plan: p,
                  isCurrent: sub != null && sub.plan == p && sub.isActive,
                  loading: _purchasing == p,
                  onBuy: () => _purchase(p),
                )),
            const SizedBox(height: 16),
            // یادداشت بازار
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.secondary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'در نسخه منتشرشده در کافه‌بازار، پرداخت از طریق درگاه پرداخت درون‌برنامه‌ای بازار انجام می‌شود. اشتراک هر ماه به‌صورت خودکار تمدید می‌گردد و هر زمان قابل لغو است.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final Subscription subscription;
  const _CurrentPlanCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final isTrial = subscription.isTrial;
    final active = subscription.isActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTrial
              ? [AppColors.accent, const Color(0xFFD97706)]
              : [AppColors.primary, AppColors.secondary],
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
              Expanded(
                child: Text(
                  isTrial ? 'دوره آزمایشی رایگان' : 'اشتراک فعال',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'طرح ${subscription.plan.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            active
                ? '${Persian.digits(subscription.daysLeft)} روز باقی‌مانده'
                : 'منقضی شده',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'پایان: ${Persian.shortDate(subscription.expiresAt)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (isTrial) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: subscription.daysLeft / AppStore.trialDays,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanType plan;
  final bool isCurrent;
  final bool loading;
  final VoidCallback onBuy;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.loading,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isPro = plan == PlanType.pro;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPro ? AppColors.primary : AppColors.divider,
          width: isPro ? 2 : 1,
        ),
        boxShadow: isPro
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          if (isPro)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Text(
                'پیشنهاد ویژه - محبوب‌ترین طرح',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'طرح ${plan.name}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.tagline,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Persian.money(plan.priceMonthly),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          'تومان / ماهانه',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                ...plan.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: isCurrent
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('طرح فعلی شما'),
                        )
                      : ElevatedButton(
                          onPressed: loading ? null : onBuy,
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Text(
                                  'خرید از کافه‌بازار - ${Persian.toman(plan.priceMonthly)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
