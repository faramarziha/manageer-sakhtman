import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';
import 'manager_shell.dart';

/// صفحه مدیریت واحدها
class ManagerUnitsPage extends StatelessWidget {
  const ManagerUnitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final floors = <int, List<Unit>>{};
    for (final u in store.buildingUnits) {
      floors.putIfAbsent(u.floor, () => []).add(u);
    }
    final sortedFloors = floors.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('واحدها و ساکنین')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // خلاصه
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.apartment_rounded,
                    title: 'کل واحدها',
                    value: Persian.digits(store.totalUnits),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.home_rounded,
                    title: 'مسکونی',
                    value: Persian.digits(store.occupiedUnits),
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.home_outlined,
                    title: 'خالی',
                    value:
                        Persian.digits(store.totalUnits - store.occupiedUnits),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...sortedFloors.map((floor) {
              final units = floors[floor]!..sort((a, b) => a.number.compareTo(b.number));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'طبقه ${Persian.digits(floor)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  ...units.map((u) => _UnitTile(unit: u)),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  final Unit unit;
  const _UnitTile({required this.unit});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final charge = store.currentChargeOfUnit(unit.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => showUnitDetailDialog(context, unit),
        leading: CircleAvatar(
          backgroundColor: unit.isOccupied
              ? AppColors.primaryLight
              : AppColors.divider,
          child: Text(
            Persian.digits(unit.number),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: unit.isOccupied
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        title: Text(
          unit.ownerName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${Persian.digits(unit.area)} متر • ${Persian.digits(unit.residents)} نفر',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: charge != null
            ? StatusChip(
                label: charge.status.label,
                color: _statusColor(charge.status),
                bgColor: _statusBg(charge.status),
              )
            : null,
      ),
    );
  }

  Color _statusColor(ChargeStatus s) => switch (s) {
        ChargeStatus.paid => AppColors.success,
        ChargeStatus.pending => AppColors.warning,
        ChargeStatus.overdue => AppColors.danger,
      };

  Color _statusBg(ChargeStatus s) => switch (s) {
        ChargeStatus.paid => AppColors.successLight,
        ChargeStatus.pending => AppColors.warningLight,
        ChargeStatus.overdue => AppColors.dangerLight,
      };
}
