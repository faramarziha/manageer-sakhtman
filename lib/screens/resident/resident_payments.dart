import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/payment_flow.dart';

/// تاریخچه و وضعیت پرداخت‌های ساکن (مدل Payment مستقل)
class ResidentPaymentsPage extends StatefulWidget {
  const ResidentPaymentsPage({super.key});

  @override
  State<ResidentPaymentsPage> createState() => _ResidentPaymentsPageState();
}

class _ResidentPaymentsPageState extends State<ResidentPaymentsPage> {
  PaymentStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.currentUnit;

    if (unit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('پرداخت‌های من')),
        body: const SafeArea(
          child: EmptyState(
            icon: Icons.door_front_door_outlined,
            message: 'پس از تایید عضویت توسط مدیر، پرداخت‌های واحد شما اینجا نمایش داده می‌شود.',
          ),
        ),
      );
    }

    var list = store.paymentsOfUnit(unit.id);
    if (_filter != null) {
      list = list.where((p) => p.status == _filter).toList();
    }

    final all = store.paymentsOfUnit(unit.id);
    final totalPaid = all
        .where((p) => p.status == PaymentStatus.paid)
        .fold(0, (s, p) => s + p.amount);
    final totalDue = all
        .where((p) =>
            p.status == PaymentStatus.unpaid ||
            p.status == PaymentStatus.rejected)
        .fold(0, (s, p) => s + p.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('پرداخت‌های من')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.check_circle_rounded,
                      title: 'مجموع پرداخت شده',
                      value: Persian.money(totalPaid),
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      icon: Icons.schedule_rounded,
                      title: 'مانده قابل پرداخت',
                      value: Persian.money(totalDue),
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            // فیلتر وضعیت
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: 'همه',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  ...PaymentStatus.values.map((s) => _FilterChip(
                        label: s.label,
                        selected: _filter == s,
                        onTap: () => setState(() => _filter = s),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'تراکنشی با این وضعیت یافت نشد',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) =>
                          _PaymentTile(payment: list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primaryLight,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Payment payment;
  const _PaymentTile({required this.payment});

  Color get _color => switch (payment.status) {
        PaymentStatus.paid => AppColors.success,
        PaymentStatus.awaitingApproval => AppColors.secondary,
        PaymentStatus.rejected => AppColors.danger,
        PaymentStatus.unpaid => AppColors.warning,
      };

  IconData get _icon => switch (payment.status) {
        PaymentStatus.paid => Icons.check_rounded,
        PaymentStatus.awaitingApproval => Icons.hourglass_top_rounded,
        PaymentStatus.rejected => Icons.close_rounded,
        PaymentStatus.unpaid => Icons.schedule_rounded,
      };

  Color get _bg => switch (payment.status) {
        PaymentStatus.paid => AppColors.successLight,
        PaymentStatus.awaitingApproval => AppColors.secondaryLight,
        PaymentStatus.rejected => AppColors.dangerLight,
        PaymentStatus.unpaid => AppColors.warningLight,
      };

  @override
  Widget build(BuildContext context) {
    final needsAction = payment.status == PaymentStatus.unpaid ||
        payment.status == PaymentStatus.rejected;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _bg,
                  child: Icon(_icon, color: _color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${payment.category.emoji} ${payment.title}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Persian.toman(payment.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusChip(
                      label: payment.status.label,
                      color: _color,
                      bgColor: _bg,
                    ),
                  ],
                ),
              ],
            ),
            // دلیل رد شدن
            if (payment.status == PaymentStatus.rejected &&
                payment.rejectionReason != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'دلیل رد: ${payment.rejectionReason}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // دکمه پرداخت / پرداخت مجدد
            if (needsAction) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(
                    payment.status == PaymentStatus.rejected
                        ? Icons.refresh_rounded
                        : Icons.credit_card_rounded,
                    size: 18,
                  ),
                  label: Text(payment.status == PaymentStatus.rejected
                      ? 'ارسال مجدد رسید'
                      : 'پرداخت'),
                  onPressed: () =>
                      showPaymentFlowSheet(context, payment),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    switch (payment.status) {
      case PaymentStatus.paid:
        final m = payment.method == PaymentMethod.cardToCard
            ? 'کارت به کارت'
            : 'آنلاین';
        return payment.paidAt != null
            ? '$m • ${Persian.shortDate(payment.paidAt!)}'
            : m;
      case PaymentStatus.awaitingApproval:
        return 'رسید: ${payment.receiptNote ?? '-'}';
      case PaymentStatus.rejected:
      case PaymentStatus.unpaid:
        return 'مهلت: ${Persian.shortDate(payment.dueDate)}';
    }
  }
}
