import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';
import 'manager_shell.dart';

/// مدیریت ساکنین: درخواست‌های عضویت + اعضای فعال واحدها
class ManagerResidentsPage extends StatelessWidget {
  const ManagerResidentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final pending = store.buildingMembershipRequests
        .where((r) => r.status == MembershipStatus.pending)
        .toList();
    final resolved = store.buildingMembershipRequests
        .where((r) => r.status != MembershipStatus.pending)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ساکنین ساختمان'),
        actions: [
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${Persian.digits(pending.length)} درخواست جدید',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------- درخواست‌های عضویت ----------
            SectionHeader(
              title: 'درخواست‌های عضویت',
              actionLabel: pending.isEmpty ? null : null,
            ),
            const SizedBox(height: 10),
            if (pending.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'درخواست جدیدی در انتظار بررسی نیست',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...pending.map((r) => _MembershipRequestTile(request: r)),
            if (resolved.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'سوابق درخواست‌ها',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ...resolved
                  .take(5)
                  .map((r) => _MembershipRequestTile(request: r)),
            ],
            const SizedBox(height: 20),

            // ---------- واحدها و اعضای فعال ----------
            const SectionHeader(title: 'واحدها و اعضای فعال'),
            const SizedBox(height: 10),
            ..._groupedByFloor(store).entries.map(
              (e) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'طبقه ${Persian.digits(e.key)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ...e.value.map((u) => _UnitMembersTile(unit: u)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<int, List<Unit>> _groupedByFloor(AppStore store) {
    final map = <int, List<Unit>>{};
    for (final u in store.buildingUnits) {
      map.putIfAbsent(u.floor, () => []).add(u);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.number.compareTo(b.number));
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }
}

/// کارت درخواست عضویت با دکمه تایید/رد
class _MembershipRequestTile extends StatelessWidget {
  final MembershipRequest request;
  const _MembershipRequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final isPending = request.status == MembershipStatus.pending;
    final isActive = request.status == MembershipStatus.active;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: request.isOwner
                      ? AppColors.primaryLight
                      : AppColors.secondaryLight,
                  child: Icon(
                    request.isOwner
                        ? Icons.key_rounded
                        : Icons.home_work_rounded,
                    color: request.isOwner
                        ? AppColors.primary
                        : AppColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'واحد ${Persian.digits(request.unitNumber)} • ${request.isOwner ? 'مالک' : 'مستأجر'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: request.status.label,
                  color: isPending
                      ? AppColors.warning
                      : isActive
                          ? AppColors.success
                          : AppColors.danger,
                  bgColor: isPending
                      ? AppColors.warningLight
                      : isActive
                          ? AppColors.successLight
                          : AppColors.dangerLight,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_iphone_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  Persian.digits(request.userPhone),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                const Icon(Icons.calendar_month_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  Persian.shortDate(request.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('تایید و اتصال به واحد'),
                      onPressed: () async {
                        await store.approveMembership(request.id);
                        if (context.mounted) {
                          showSuccessSnack(context,
                              '${request.userName} به واحد ${Persian.digits(request.unitNumber)} متصل شد');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('رد درخواست'),
                      onPressed: () async {
                        final ok = await _confirmReject(context);
                        if (ok == true) {
                          await store.rejectMembership(request.id);
                          if (context.mounted) {
                            showSuccessSnack(
                                context, 'درخواست رد شد');
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmReject(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('رد درخواست عضویت'),
        content: Text(
            'درخواست «${request.userName}» برای واحد ${Persian.digits(request.unitNumber)} رد شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child:
                const Text('رد کردن', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// کارت واحد همراه اعضای فعال آن (قابل حذف اتصال)
class _UnitMembersTile extends StatelessWidget {
  final Unit unit;
  const _UnitMembersTile({required this.unit});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final members = store.usersOfUnit(unit.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => showUnitDetailDialog(context, unit),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: unit.isOccupied
                          ? AppColors.primaryLight
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        Persian.digits(unit.number),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: unit.isOccupied
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.ownerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          unit.isOccupied
                              ? '${Persian.digits(unit.residents)} نفر ساکن'
                              : 'خالی',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
            if (members.isNotEmpty) ...[
              const Divider(height: 18),
              ...members.map(
                (m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        m.isOwner ? Icons.key_rounded : Icons.person_rounded,
                        size: 16,
                        color: m.isOwner
                            ? AppColors.primary
                            : AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${m.fullName} (${m.isOwner ? 'مالک' : 'مستأجر'})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        Persian.digits(m.phone),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.link_off_rounded,
                            size: 18, color: AppColors.danger),
                        tooltip: 'حذف اتصال از واحد',
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('حذف اتصال کاربر'),
                              content: Text(
                                  '«${m.fullName}» از واحد ${Persian.digits(unit.number)} جدا شود؟ دسترسی او به پرداخت‌های این واحد قطع می‌شود.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dCtx, false),
                                  child: const Text('انصراف'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dCtx, true),
                                  child: const Text('حذف اتصال',
                                      style: TextStyle(
                                          color: AppColors.danger)),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            final store = context.read<AppStore>();
                            await store.detachUserFromUnit(m.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
