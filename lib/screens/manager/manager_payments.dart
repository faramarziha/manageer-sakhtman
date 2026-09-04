import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/share_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/payment_flow.dart';

/// ---------------------------------------------------------------------------
/// مدیریت صورتحساب‌ها (پنل مدیر)
///
///   • صدور دسته‌ای شارژ ماهانه بر پایه فرمول ماده ۴
///   • تایید/رد رسیدهای کارت‌به‌کارت با یک لمس
///   • اشتراک‌گذاری صورتحساب هر واحد در پیام‌رسان‌ها (بدون هزینه پیامک)
/// ---------------------------------------------------------------------------
class ManagerPaymentsPage extends StatefulWidget {
  const ManagerPaymentsPage({super.key});

  @override
  State<ManagerPaymentsPage> createState() => _ManagerPaymentsPageState();
}

class _ManagerPaymentsPageState extends State<ManagerPaymentsPage>
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
    final building = store.currentBuilding;
    if (building == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.apartment_outlined,
            message: 'ابتدا ساختمان خود را ثبت کنید',
          ),
        ),
      );
    }

    final all = store.buildingInvoices;
    final awaiting = store.awaitingApprovalInvoices;
    final unpaid = all.where((i) => i.status.isDebt).toList();
    final paid = all.where((i) => i.status == InvoiceStatus.paid).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text('صورتحساب‌های ساختمان',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CollectionCard(store: store),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: Text(
                          'صدور دسته‌ای شارژ ${store.currentPeriod} (ماده ۴)'),
                      onPressed: () => _issueBatch(context, store),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tab,
              labelStyle: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'در انتظار تایید (${Persian.digits(awaiting.length)})'),
                Tab(text: 'پرداخت‌نشده (${Persian.digits(unpaid.length)})'),
                Tab(text: 'تسویه‌شده (${Persian.digits(paid.length)})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _List(
                      invoices: awaiting,
                      building: building,
                      approvalMode: true,
                      empty: 'رسیدی در انتظار تایید نیست'),
                  _List(
                      invoices: unpaid,
                      building: building,
                      empty: 'همه صورتحساب‌ها تسویه شده‌اند'),
                  _List(
                      invoices: paid,
                      building: building,
                      empty: 'هنوز پرداخت تاییدشده‌ای ثبت نشده'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _issueBatch(BuildContext context, AppStore store) async {
    final preview = store.previewBatchCharge();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('صدور دسته‌ای شارژ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('دوره: ${store.currentPeriod}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text('تعداد واحد: ${Persian.digits(preview.breakdowns.length)}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text('مجموع مبلغ: ${Persian.toman(preview.totalAmount)}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
              'فرمول ماده ۴: شارژ = ثابت + (متراژ × نرخ) + (نفرات × نرخ) '
              '+ پارکینگ + کنتور. واحدهای خالی از سهم نفرات معاف هستند.',
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.8,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('صدور')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final created = await store.issueMonthlyCharges();
    if (!context.mounted) return;
    showSuccessSnack(
        context, '${Persian.digits(created.length)} صورتحساب صادر شد');
  }
}

class _CollectionCard extends StatelessWidget {
  final AppStore store;
  const _CollectionCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final progress = store.collectionProgress;
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
          Text('وصول ${store.currentPeriod}',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 6),
          Text(Persian.toman(store.collectedThisPeriod),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('مانده: ${Persian.toman(store.pendingThisPeriod)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'درصد وصول: ${Persian.digits((progress * 100).round())}٪'
            ' • معوقه: ${Persian.digits(store.overdueCount)} واحد',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  final List<Invoice> invoices;
  final Building building;
  final String empty;
  final bool approvalMode;

  const _List({
    required this.invoices,
    required this.building,
    required this.empty,
    this.approvalMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (invoices.isEmpty) {
      return EmptyState(icon: Icons.receipt_long_outlined, message: empty);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (ctx, i) {
        final inv = invoices[i];
        final unit = store.unitById(inv.unitId);
        if (unit == null) return const SizedBox.shrink();
        return _ManagerInvoiceTile(
          invoice: inv,
          unit: unit,
          building: building,
          approvalMode: approvalMode,
        );
      },
    );
  }
}

class _ManagerInvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final Unit unit;
  final Building building;
  final bool approvalMode;

  const _ManagerInvoiceTile({
    required this.invoice,
    required this.unit,
    required this.building,
    required this.approvalMode,
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
    final store = context.read<AppStore>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  child: Text(Persian.digits(unit.number),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${invoice.title} • ${unit.ownerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        '${invoice.period} • ${invoice.recipientRole.label}'
                        ' • ${invoice.method.shortLabel}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Persian.money(invoice.amount),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    StatusChip(label: invoice.status.label, color: _color),
                  ],
                ),
              ],
            ),
            if (approvalMode) ...[
              const SizedBox(height: 10),
              if (invoice.cardLast4 != null)
                Text('چهار رقم آخر کارت: ${Persian.digits(invoice.cardLast4!)}',
                    style: const TextStyle(fontSize: 11.5)),
              if (invoice.receiptNote != null &&
                  invoice.receiptNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('توضیح ساکن: ${invoice.receiptNote}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('تایید',
                          style: TextStyle(fontSize: 12.5)),
                      onPressed: () async {
                        await store.approveInvoice(invoice.id);
                        if (context.mounted) {
                          showSuccessSnack(context, 'پرداخت تایید شد');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label:
                          const Text('رد', style: TextStyle(fontSize: 12.5)),
                      onPressed: () => _reject(context, store),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'مشاهده جزئیات',
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    onPressed: () => showPaymentFlowSheet(context, invoice),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (invoice.status.isDebt)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 16),
                        label: const Text('اشتراک‌گذاری صورتحساب',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => ShareService.shareInvoice(
                          building: building,
                          unit: unit,
                          invoice: invoice,
                          recipientName: unit.ownerName,
                        ),
                      ),
                    )
                  else if (invoice.hasElectronicReceipt)
                    Expanded(
                      child: Text(
                        'کد پیگیری: ${Persian.digits(invoice.rrn!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'جزئیات',
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    onPressed: () => showPaymentFlowSheet(context, invoice),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رد رسید',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'علت رد رسید'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('رد رسید'),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    await store.rejectInvoice(
        invoice.id, reason.isEmpty ? 'مغایرت در مبلغ یا رسید' : reason);
  }
}
