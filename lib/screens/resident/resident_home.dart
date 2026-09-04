import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/share_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/payment_flow.dart';
import '../../widgets/property_switcher.dart';
import 'resident_transparency.dart';
import 'resident_voting.dart';

/// ---------------------------------------------------------------------------
/// صفحه اصلی ساکن
///
/// شامل انتخابگر ملک (ورود چندملکی - گام ۴)، کارت‌های اسلایدی صورتحساب‌های
/// دوره جاری با دکمه پرداخت و اشتراک‌گذاری (گام ۲ و ۳)، میان‌برهای شفافیت
/// مالی و رأی‌گیری، و آخرین اعلانات ساختمان.
/// ---------------------------------------------------------------------------
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

    if (unit == null || building == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.door_front_door_outlined,
            message:
                'هنوز به واحدی متصل نشده‌اید. پس از تایید مدیر به واحد متصل می‌شوید.',
          ),
        ),
      );
    }

    final invoices = store.myCurrentPeriodInvoices;
    final unpaid = invoices.where((i) => i.status.isDebt).toList();
    final myRequests =
        store.buildingRequests.where((r) => r.unitId == unit.id).toList();
    final openRequests =
        myRequests.where((r) => r.status != RequestStatus.done).length;
    final debt = store.myDebt;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // ---------- هدر خوش‌آمد ----------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(Icons.person_rounded,
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
                            Persian.currentMonthName(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'اشتراک‌گذاری صورتحساب واحد',
                      onPressed: unpaid.isEmpty
                          ? null
                          : () => ShareService.shareUnitStatement(
                                building: building,
                                unit: unit,
                                invoices: unpaid,
                                recipientName: store.currentUser?.fullName,
                              ),
                      icon: const Icon(Icons.ios_share_rounded,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ---------- انتخابگر ملک (چندملکی) ----------
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: PropertySwitcher(),
              ),
              const SizedBox(height: 16),

              // ---------- خلاصه بدهی ----------
              if (debt > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _DebtBanner(debt: debt, count: unpaid.length),
                ),
              if (debt > 0) const SizedBox(height: 16),

              // ---------- کارت‌های اسلایدی صورتحساب دوره جاری ----------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SectionHeader(
                  title: 'صورتحساب‌های ${store.currentPeriod}',
                  actionLabel: invoices.isEmpty ? null : 'همه',
                  onAction: invoices.isEmpty ? null : () {},
                ),
              ),
              const SizedBox(height: 10),
              if (invoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'صورتحسابی برای دوره جاری صادر نشده است',
                  ),
                )
              else ...[
                SizedBox(
                  height: 232,
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: invoices.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _InvoiceSlideCard(
                        invoice: invoices[i],
                        building: building,
                        unit: unit,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    invoices.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _page == i ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            _page == i ? AppColors.primary : AppColors.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ---------- میان‌برها ----------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.pie_chart_rounded,
                        label: 'شفافیت مالی',
                        color: AppColors.secondary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ResidentTransparency(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.how_to_vote_rounded,
                        label: 'رأی‌گیری مجمع',
                        color: AppColors.accent,
                        badge: store.activePolls.length,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ResidentVoting(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------- آمار ----------
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
                      icon: Icons.verified_rounded,
                      title: 'صورتحساب تسویه‌شده',
                      value: Persian.digits(store.myInvoices
                          .where((i) => i.status == InvoiceStatus.paid)
                          .length),
                      color: AppColors.success,
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
                      value: Persian.digits(store.myBookings.length),
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

              // ---------- آخرین اعلانات ----------
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SectionHeader(title: 'آخرین اعلانات ساختمان'),
              ),
              const SizedBox(height: 10),
              ...store.buildingNotices.take(3).map(
                    (n) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: Text(
                            n.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            tooltip: 'اشتراک‌گذاری',
                            icon: const Icon(Icons.ios_share_rounded, size: 18),
                            onPressed: () => ShareService.shareNotice(
                                building: building, notice: n),
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// نوار هشدار بدهی معوق
class _DebtBanner extends StatelessWidget {
  final int debt;
  final int count;
  const _DebtBanner({required this.debt, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.danger, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بدهی پرداخت‌نشده: ${Persian.toman(debt)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Persian.digits(count)} صورتحساب در انتظار پرداخت',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// کارت اسلایدی یک صورتحساب
class _InvoiceSlideCard extends StatelessWidget {
  final Invoice invoice;
  final Building building;
  final Unit unit;

  const _InvoiceSlideCard({
    required this.invoice,
    required this.building,
    required this.unit,
  });

  List<Color> get _gradient => switch (invoice.status) {
        InvoiceStatus.paid => [AppColors.success, const Color(0xFF15803D)],
        InvoiceStatus.rejected => [AppColors.danger, const Color(0xFF991B1B)],
        InvoiceStatus.awaitingApproval => [
            AppColors.secondary,
            const Color(0xFF2C4A73)
          ],
        InvoiceStatus.overdue => [AppColors.danger, const Color(0xFF7F1D1D)],
        InvoiceStatus.unpaid => [AppColors.primary, AppColors.secondary],
      };

  @override
  Widget build(BuildContext context) {
    final needsAction = invoice.status.isDebt;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _gradient.first.withValues(alpha: 0.3),
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
              Text(invoice.kind.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invoice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
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
                  invoice.status.label,
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
            Persian.toman(invoice.amount),
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
          const Spacer(),
          if (needsAction)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _gradient.first,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: Icon(
                      invoice.status == InvoiceStatus.rejected
                          ? Icons.refresh_rounded
                          : Icons.credit_card_rounded,
                      size: 18,
                    ),
                    label: Text(
                      invoice.status == InvoiceStatus.rejected
                          ? 'پرداخت مجدد'
                          : 'پرداخت',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => showPaymentFlowSheet(context, invoice),
                  ),
                ),
                const SizedBox(width: 8),
                // گام ۳ — اشتراک‌گذاری صورتحساب بدون هزینه پیامک
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    tooltip: 'اشتراک‌گذاری صورتحساب',
                    icon: const Icon(Icons.ios_share_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => ShareService.shareInvoice(
                      building: building,
                      unit: unit,
                      invoice: invoice,
                    ),
                  ),
                ),
              ],
            )
          else if (invoice.status == InvoiceStatus.awaitingApproval)
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
            )
          else
            Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    invoice.hasElectronicReceipt
                        ? 'پرداخت شده • پیگیری ${Persian.digits(invoice.rrn!)}'
                        : 'این صورتحساب تسویه شده است',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'مشاهده رسید',
                  icon: const Icon(Icons.receipt_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => showPaymentFlowSheet(context, invoice),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _subtitle() => switch (invoice.status) {
        InvoiceStatus.paid => invoice.paidAt != null
            ? 'پرداخت شده در ${Persian.shortDate(invoice.paidAt!)}'
            : 'پرداخت شده',
        InvoiceStatus.awaitingApproval => 'در انتظار تایید مدیر ساختمان',
        InvoiceStatus.rejected =>
          'رد شده: ${invoice.rejectionReason ?? 'بدون توضیح'}',
        InvoiceStatus.overdue =>
          'معوقه — ${Persian.digits(invoice.daysOverdue)} روز تاخیر',
        InvoiceStatus.unpaid =>
          'مهلت پرداخت: ${Persian.shortDate(invoice.dueDate)}',
      };
}

/// دکمه میان‌بر
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            if (badge > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  Persian.digits(badge),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
