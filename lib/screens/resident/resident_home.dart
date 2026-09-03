import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/payment_flow.dart';

/// صفحه اصلی ساکن - کارت‌های اسلایدی پرداخت‌های ماه جاری
class ResidentHome extends StatefulWidget {
  const ResidentHome({super.key});

  @override
  State<ResidentHome> createState() => _ResidentHomeState();
}

class _ResidentHomeState extends State<ResidentHome> {
  final _pageCtrl = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.currentUnit;
    final building = store.currentBuilding;

    if (unit == null) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.door_front_door_outlined,
            message:
                'هنوز به واحدی متصل نشده‌اید. پس از تایید مدیر به واحد متصل می‌شوید.',
          ),
        ),
      );
    }

    final payments = store.currentMonthPaymentsOfUnit(unit.id);
    final myRequests =
        store.buildingRequests.where((r) => r.unitId == unit.id).toList();
    final openRequests =
        myRequests.where((r) => r.status != RequestStatus.done).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // هدر خوش‌آمد
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
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
                          'سلام، ${store.currentUser?.fullName ?? unit.ownerName}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'واحد ${Persian.digits(unit.number)} • ${building?.name ?? ''}',
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
            ),
            const SizedBox(height: 18),

            // ---------- کارت‌های اسلایدی پرداخت‌های ماه جاری ----------
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: 'پرداخت‌های ماه جاری'),
            ),
            const SizedBox(height: 10),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: EmptyState(
                  icon: Icons.payments_outlined,
                  message: 'پرداختی برای ماه جاری ثبت نشده است',
                ),
              )
            else ...[
              SizedBox(
                height: 215,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: payments.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _PaymentSlideCard(payment: payments[i]),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // نقطه‌های ناوبری
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  payments.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _page == i ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? AppColors.primary
                          : AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // دسترسی سریع
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  StatCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'پرداخت‌های تایید شده',
                    value: Persian.digits(store
                        .paymentsOfUnit(unit.id)
                        .where((p) => p.status == PaymentStatus.paid)
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
                    value: Persian.digits(store.buildingBookings
                        .where((b) => b.unitId == unit.id)
                        .length),
                    color: AppColors.secondary,
                  ),
                  StatCard(
                    icon: Icons.campaign_rounded,
                    title: 'اعلانات',
                    value: Persian.digits(store.buildingNotices.length),
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // آخرین اعلانات
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: 'آخرین اعلانات ساختمان'),
            ),
            const SizedBox(height: 10),
            ...store.buildingNotices.take(3).map(
                  (n) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
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
                ),
          ],
        ),
      ),
    );
  }
}

/// کارت اسلایدی یک پرداخت مستقل
class _PaymentSlideCard extends StatelessWidget {
  final Payment payment;
  const _PaymentSlideCard({required this.payment});

  Color get _statusColor => switch (payment.status) {
        PaymentStatus.paid => AppColors.success,
        PaymentStatus.awaitingApproval => AppColors.secondary,
        PaymentStatus.rejected => AppColors.danger,
        PaymentStatus.unpaid => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final needsAction = payment.status == PaymentStatus.unpaid ||
        payment.status == PaymentStatus.rejected;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: payment.status == PaymentStatus.paid
              ? [AppColors.success, const Color(0xFF15803D)]
              : payment.status == PaymentStatus.rejected
                  ? [AppColors.danger, const Color(0xFF991B1B)]
                  : payment.status == PaymentStatus.awaitingApproval
                      ? [AppColors.secondary, const Color(0xFF2C4A73)]
                      : [AppColors.primary, AppColors.secondary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(payment.category.emoji,
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  payment.status.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            Persian.toman(payment.amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _subtitle(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (needsAction) ...[
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: Icon(
                  payment.status == PaymentStatus.rejected
                      ? Icons.refresh_rounded
                      : Icons.credit_card_rounded,
                  size: 18,
                ),
                label: Text(
                  payment.status == PaymentStatus.rejected
                      ? 'پرداخت مجدد'
                      : 'پرداخت',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () => showPaymentFlowSheet(context, payment),
              ),
            ),
          ] else if (payment.status ==
              PaymentStatus.awaitingApproval) ...[
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'رسید ارسال شد - در انتظار تایید مدیر',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Spacer(),
            const Row(
              children: [
                Icon(Icons.verified_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'این پرداخت تسویه شده است',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _subtitle() {
    switch (payment.status) {
      case PaymentStatus.paid:
        return payment.paidAt != null
            ? 'پرداخت شده در ${Persian.shortDate(payment.paidAt!)}'
            : 'پرداخت شده';
      case PaymentStatus.awaitingApproval:
        return 'در انتظار تایید مدیر ساختمان';
      case PaymentStatus.rejected:
        return 'رد شده: ${payment.rejectionReason ?? 'بدون توضیح'}';
      case PaymentStatus.unpaid:
        return 'مهلت پرداخت: ${Persian.shortDate(payment.dueDate)}';
    }
  }
}
