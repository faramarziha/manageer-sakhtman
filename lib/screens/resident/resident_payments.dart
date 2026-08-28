import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// تاریخچه پرداخت‌های ساکن
class ResidentPaymentsPage extends StatelessWidget {
  const ResidentPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.currentUnit!;
    final list = store.chargesOfUnit(unit.id);
    final totalPaid = list
        .where((c) => c.status == ChargeStatus.paid)
        .fold(0, (s, c) => s + c.amount);
    final totalDue = list
        .where((c) => c.status != ChargeStatus.paid)
        .fold(0, (s, c) => s + c.amount);

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
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'هنوز تراکنشی ثبت نشده است',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final c = list[i];
                        final isPaid = c.status == ChargeStatus.paid;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPaid
                                  ? AppColors.successLight
                                  : (c.status == ChargeStatus.overdue
                                      ? AppColors.dangerLight
                                      : AppColors.warningLight),
                              child: Icon(
                                isPaid
                                    ? Icons.check_rounded
                                    : Icons.schedule_rounded,
                                color: isPaid
                                    ? AppColors.success
                                    : (c.status == ChargeStatus.overdue
                                        ? AppColors.danger
                                        : AppColors.warning),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'شارژ ${c.month}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              isPaid && c.paidAt != null
                                  ? 'پرداخت در ${Persian.shortDate(c.paidAt!)}'
                                  : 'مهلت: ${Persian.shortDate(c.dueDate)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              Persian.toman(c.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
