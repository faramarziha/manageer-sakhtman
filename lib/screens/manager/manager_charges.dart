import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// صفحه مدیریت شارژ ساختمان (مدیر)
class ManagerChargesPage extends StatefulWidget {
  const ManagerChargesPage({super.key});

  @override
  State<ManagerChargesPage> createState() => _ManagerChargesPageState();
}

class _ManagerChargesPageState extends State<ManagerChargesPage> {
  ChargeStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var list = store.currentMonthCharges;
    if (_filter != null) {
      list = list.where((c) => c.status == _filter).toList();
    }

    return Scaffold(
      appBar: AppBar(title: Text('شارژ ${Persian.currentMonthName()}')),
      body: SafeArea(
        child: Column(
          children: [
            // خلاصه مالی
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _summaryItem(
                        'وصول شده',
                        Persian.toman(store.collectedThisMonth),
                        AppColors.success,
                      ),
                    ),
                    Container(width: 1, height: 40, color: AppColors.divider),
                    Expanded(
                      child: _summaryItem(
                        'در انتظار',
                        Persian.toman(store.pendingThisMonth),
                        AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // فیلترها
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filterChip('همه', null),
                  _filterChip('پرداخت شده', ChargeStatus.paid),
                  _filterChip('در انتظار', ChargeStatus.pending),
                  _filterChip('معوقه', ChargeStatus.overdue),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.payments_outlined,
                      message: 'موردی یافت نشد',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) =>
                          _ChargeTile(charge: list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, ChargeStatus? status) {
    final selected = _filter == status;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = status),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.divider),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ChargeTile extends StatelessWidget {
  final Charge charge;
  const _ChargeTile({required this.charge});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.unitById(charge.unitId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _bg(charge.status),
          child: Icon(
            _icon(charge.status),
            color: _color(charge.status),
            size: 20,
          ),
        ),
        title: Text(
          'واحد ${Persian.digits(unit?.number ?? 0)} - ${unit?.ownerName ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          charge.status == ChargeStatus.paid && charge.paidAt != null
              ? 'پرداخت در ${Persian.shortDate(charge.paidAt!)}'
              : 'مهلت: ${Persian.shortDate(charge.dueDate)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Persian.money(charge.amount),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'تومان',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Color _color(ChargeStatus s) => switch (s) {
        ChargeStatus.paid => AppColors.success,
        ChargeStatus.pending => AppColors.warning,
        ChargeStatus.overdue => AppColors.danger,
      };

  Color _bg(ChargeStatus s) => switch (s) {
        ChargeStatus.paid => AppColors.successLight,
        ChargeStatus.pending => AppColors.warningLight,
        ChargeStatus.overdue => AppColors.dangerLight,
      };

  IconData _icon(ChargeStatus s) => switch (s) {
        ChargeStatus.paid => Icons.check_circle_rounded,
        ChargeStatus.pending => Icons.schedule_rounded,
        ChargeStatus.overdue => Icons.error_rounded,
      };
}
