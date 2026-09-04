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

/// ---------------------------------------------------------------------------
/// صورتحساب‌های ساکن
///
/// فهرست کامل صورتحساب‌های واحد فعال با تفکیک وضعیت، امکان پرداخت
/// (درگاه شاپرک / کارت به کارت) و اشتراک‌گذاری صورتحساب از طریق
/// پیام‌رسان‌های نصب‌شده روی گوشی (بدون هزینه پیامک).
/// ---------------------------------------------------------------------------
class ResidentPaymentsPage extends StatefulWidget {
  const ResidentPaymentsPage({super.key});

  @override
  State<ResidentPaymentsPage> createState() => _ResidentPaymentsState();
}

class _ResidentPaymentsState extends State<ResidentPaymentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
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
            icon: Icons.receipt_long_outlined,
            message: 'ابتدا باید به یک واحد متصل شوید',
          ),
        ),
      );
    }

    final all = store.myInvoices;
    final unpaid = all.where((i) => i.status.isDebt).toList();
    final pending = all
        .where((i) => i.status == InvoiceStatus.awaitingApproval)
        .toList();
    final paid = all.where((i) => i.status == InvoiceStatus.paid).toList();
    final debt = store.myDebt;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ---------- هدر ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'صورتحساب‌های من',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (unpaid.isNotEmpty)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.ios_share_rounded, size: 16),
                          label: const Text('اشتراک‌گذاری',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () => ShareService.shareUnitStatement(
                            building: building,
                            unit: unit,
                            invoices: unpaid,
                            recipientName: store.currentUser?.fullName,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const PropertySwitcher(),
                  const SizedBox(height: 12),
                  _DebtSummary(debt: debt, count: unpaid.length),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ---------- تب‌ها ----------
            TabBar(
              controller: _tab,
              labelStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'پرداخت‌نشده (${Persian.digits(unpaid.length)})'),
                Tab(text: 'در انتظار (${Persian.digits(pending.length)})'),
                Tab(text: 'تسویه‌شده (${Persian.digits(paid.length)})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _InvoiceList(
                      invoices: unpaid,
                      building: building,
                      unit: unit,
                      emptyMessage: 'صورتحساب پرداخت‌نشده‌ای ندارید'),
                  _InvoiceList(
                      invoices: pending,
                      building: building,
                      unit: unit,
                      emptyMessage: 'رسیدی در انتظار تایید مدیر نیست'),
                  _InvoiceList(
                      invoices: paid,
                      building: building,
                      unit: unit,
                      emptyMessage: 'هنوز صورتحساب تسویه‌شده‌ای ندارید'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtSummary extends StatelessWidget {
  final int debt;
  final int count;
  const _DebtSummary({required this.debt, required this.count});

  @override
  Widget build(BuildContext context) {
    final settled = debt == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: settled
              ? [AppColors.success, const Color(0xFF15803D)]
              : [AppColors.primary, AppColors.secondary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            settled
                ? Icons.verified_rounded
                : Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settled ? 'بدهی ندارید' : 'مانده بدهی شما',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  settled ? 'تسویه کامل' : Persian.toman(debt),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!settled) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${Persian.digits(count)} صورتحساب باز',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<Invoice> invoices;
  final Building building;
  final Unit unit;
  final String emptyMessage;

  const _InvoiceList({
    required this.invoices,
    required this.building,
    required this.unit,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return EmptyState(
          icon: Icons.receipt_long_outlined, message: emptyMessage);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (ctx, i) => InvoiceTile(
        invoice: invoices[i],
        building: building,
        unit: unit,
      ),
    );
  }
}

/// ردیف یک صورتحساب (قابل استفاده مجدد در صفحات دیگر)
class InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final Building building;
  final Unit unit;

  /// نمایش شماره واحد (برای صفحات مدیر)
  final bool showUnit;

  const InvoiceTile({
    super.key,
    required this.invoice,
    required this.building,
    required this.unit,
    this.showUnit = false,
  });

  Color get _color => switch (invoice.status) {
        InvoiceStatus.paid => AppColors.success,
        InvoiceStatus.awaitingApproval => AppColors.secondary,
        InvoiceStatus.rejected => AppColors.danger,
        InvoiceStatus.overdue => AppColors.danger,
        InvoiceStatus.unpaid => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showPaymentFlowSheet(context, invoice),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(invoice.kind.emoji,
                        style: const TextStyle(fontSize: 19)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showUnit
                              ? 'واحد ${Persian.digits(unit.number)} • ${invoice.title}'
                              : invoice.title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${invoice.period} • مهلت ${Persian.shortDate(invoice.dueDate)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Persian.money(invoice.amount),
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      StatusChip(
                          label: invoice.status.label, color: _color),
                    ],
                  ),
                ],
              ),
              if (invoice.isOverdue) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 15, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${Persian.digits(invoice.daysOverdue)} روز تاخیر — '
                          'مشمول ماده ۱۰ مکرر قانون تملک آپارتمان‌ها',
                          style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.6,
                              color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (invoice.status == InvoiceStatus.rejected &&
                  invoice.rejectionReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  'علت رد رسید: ${invoice.rejectionReason}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (invoice.status.isDebt)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        icon: const Icon(Icons.credit_card_rounded, size: 17),
                        label: Text(
                          invoice.status == InvoiceStatus.rejected
                              ? 'ارسال مجدد رسید'
                              : 'پرداخت',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        onPressed: () =>
                            showPaymentFlowSheet(context, invoice),
                      ),
                    )
                  else if (invoice.hasElectronicReceipt)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.confirmation_number_outlined,
                              size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'کد پیگیری: ${Persian.digits(invoice.rrn!)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),
                  // گام ۳ سند — اشتراک‌گذاری بومی بدون هزینه پیامک
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 16),
                    label: const Text('اشتراک‌گذاری',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () => ShareService.shareInvoice(
                      building: building,
                      unit: unit,
                      invoice: invoice,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
