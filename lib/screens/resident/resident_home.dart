import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// صفحه اصلی ساکن
class ResidentHome extends StatelessWidget {
  const ResidentHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.currentUnit!;
    final charge = store.currentChargeOfUnit(unit.id);
    final myRequests = store.requests.where((r) => r.unitId == unit.id).toList();
    final openRequests =
        myRequests.where((r) => r.status != RequestStatus.done).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // هدر خوش‌آمد
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سلام، ${unit.ownerName}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'واحد ${Persian.digits(unit.number)} • ${AppStore.buildingName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // کارت شارژ جاری
            if (charge != null) _ChargeHeroCard(charge: charge),
            const SizedBox(height: 16),
            // دسترسی سریع
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                StatCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'پرداخت‌های من',
                  value: Persian.digits(
                      store.chargesOfUnit(unit.id)
                          .where((c) => c.status == ChargeStatus.paid)
                          .length),
                  color: AppColors.primary,
                ),
                StatCard(
                  icon: Icons.build_rounded,
                  title: 'درخواست‌های باز',
                  value: Persian.digits(openRequests),
                  color: AppColors.warning,
                ),
                StatCard(
                  icon: Icons.event_available_rounded,
                  title: 'رزروهای من',
                  value: Persian.digits(store.bookings
                      .where((b) => b.unitId == unit.id)
                      .length),
                  color: AppColors.secondary,
                ),
                StatCard(
                  icon: Icons.campaign_rounded,
                  title: 'اعلانات',
                  value: Persian.digits(store.notices.length),
                  color: AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // آخرین اعلانات
            const SectionHeader(title: 'آخرین اعلانات ساختمان'),
            const SizedBox(height: 10),
            ...store.notices.take(3).map(
                  (n) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: n.isImportant
                              ? AppColors.dangerLight
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          n.isImportant
                              ? Icons.priority_high_rounded
                              : Icons.campaign_rounded,
                          size: 20,
                          color: n.isImportant
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                      ),
                      title: Text(
                        n.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        n.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ChargeHeroCard extends StatelessWidget {
  final Charge charge;
  const _ChargeHeroCard({required this.charge});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final isPaid = charge.status == ChargeStatus.paid;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPaid
              ? [AppColors.success, const Color(0xFF15803D)]
              : [AppColors.primary, AppColors.secondary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isPaid ? AppColors.success : AppColors.primary)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'شارژ ${charge.month}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                  charge.status.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            Persian.toman(charge.amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPaid && charge.paidAt != null
                ? 'پرداخت شده در ${Persian.shortDate(charge.paidAt!)}'
                : 'مهلت پرداخت: ${Persian.shortDate(charge.dueDate)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (!isPaid) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.credit_card_rounded, size: 20),
                label: const Text('پرداخت آنلاین'),
                onPressed: () => _showPaymentSheet(context, charge, store),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, Charge charge, AppStore store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          right: 20,
          left: 20,
          top: 20,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.account_balance_rounded,
                size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              'درگاه پرداخت آنلاین',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'شارژ ${charge.month} - واحد ${Persian.digits(store.currentUnit?.number ?? 0)}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('مبلغ قابل پرداخت:',
                      style: TextStyle(fontSize: 13)),
                  Text(
                    Persian.toman(charge.amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await Future.delayed(const Duration(milliseconds: 400));
                  await store.payCharge(charge.id);
                  if (context.mounted) {
                    showSuccessSnack(context,
                        'پرداخت با موفقیت انجام شد. رسید شما ثبت گردید.');
                  }
                },
                child: const Text('تایید و پرداخت'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetCtx),
              child: const Text('انصراف'),
            ),
          ],
        ),
      ),
    );
  }
}
