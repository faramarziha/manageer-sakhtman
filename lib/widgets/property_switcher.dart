import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';

/// ---------------------------------------------------------------------------
/// انتخابگر ملک (گام ۴ سند - ورود چندملکی)
///
/// کاربر با یک شماره موبایل می‌تواند مالک/مستاجر چند واحد در ساختمان‌های
/// مختلف باشد. این ویجت فهرست املاک کاربر را نمایش می‌دهد و امکان تعویض
/// واحد و ساختمان فعال را فراهم می‌کند.
/// ---------------------------------------------------------------------------
class PropertySwitcher extends StatelessWidget {
  /// نمایش فشرده (فقط چیپ) یا کارت کامل
  final bool compact;

  const PropertySwitcher({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final props = store.myProperties;
    final unit = store.currentUnit;
    final building = store.currentBuilding;

    if (unit == null || building == null) return const SizedBox.shrink();

    // تک‌ملکی → فقط نمایش اطلاعات، بدون منوی تعویض
    if (props.length < 2) {
      if (compact) return const SizedBox.shrink();
      return _PropertyBadge(
        building: building,
        unit: unit,
        role: store.currentUnitRole,
        onTap: null,
      );
    }

    return _PropertyBadge(
      building: building,
      unit: unit,
      role: store.currentUnitRole,
      onTap: () => showPropertyPicker(context),
    );
  }
}

/// شیت انتخاب ملک فعال
Future<void> showPropertyPicker(BuildContext context) async {
  final store = context.read<AppStore>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const _PropertyPickerSheet(),
    ),
  );
}

class _PropertyPickerSheet extends StatelessWidget {
  const _PropertyPickerSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final props = store.myProperties;
    final activeUnitId = store.currentUnit?.id;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.apartment_rounded,
                      color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'انتخاب ملک',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'شما با همین شماره موبایل در چند واحد عضو هستید. '
                'واحدی که می‌خواهید مدیریت کنید را انتخاب نمایید.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: props.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final link = props[i];
                  final unit = store.unitById(link.unitId);
                  final b = store.buildingById(link.buildingId);
                  if (unit == null || b == null) {
                    return const SizedBox.shrink();
                  }
                  final selected = unit.id == activeUnitId;
                  final debt = store.debtOfUnit(unit.id);

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await store.switchProperty(unit.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryLight
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.divider,
                          width: selected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.divider.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              Persian.digits(unit.number),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'واحد ${Persian.digits(unit.number)}'
                                  ' • ${link.role.label}'
                                  ' • ${Persian.digits(unit.area.toStringAsFixed(0))} متر',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                                if (debt > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'بدهی: ${Persian.toman(debt)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 22),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_home_work_outlined, size: 18),
                  label: const Text('افزودن ملک جدید'),
                  onPressed: () {
                    Navigator.pop(context);
                    showAttachPropertyDialog(context);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// دیالوگ افزودن ملک جدید با کد دعوت ساختمان
Future<void> showAttachPropertyDialog(BuildContext context) async {
  final store = context.read<AppStore>();
  final codeCtrl = TextEditingController();
  final unitCtrl = TextEditingController();
  var role = UnitRole.tenant;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('افزودن ملک جدید',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'کد دعوت ساختمان',
                prefixIcon: Icon(Icons.qr_code_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'شماره واحد',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<UnitRole>(
              segments: const [
                ButtonSegment(value: UnitRole.owner, label: Text('مالک')),
                ButtonSegment(value: UnitRole.tenant, label: Text('مستاجر')),
              ],
              selected: {role},
              onSelectionChanged: (s) => setLocal(() => role = s.first),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () async {
              final num_ = int.tryParse(
                  Persian.toEnglishDigits(unitCtrl.text.trim()));
              if (codeCtrl.text.trim().isEmpty || num_ == null) return;
              final ok = await store.attachProperty(
                inviteCode: codeCtrl.text.trim().toUpperCase(),
                unitNumber: num_,
                role: role,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor:
                      ok ? AppColors.success : AppColors.danger,
                  content: Text(ok
                      ? 'ملک جدید به حساب شما افزوده شد'
                      : 'کد دعوت یا شماره واحد نامعتبر است'),
                ),
              );
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    ),
  );
}

class _PropertyBadge extends StatelessWidget {
  final Building building;
  final Unit unit;
  final UnitRole role;
  final VoidCallback? onTap;

  const _PropertyBadge({
    required this.building,
    required this.unit,
    required this.role,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.apartment_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    building.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'واحد ${Persian.digits(unit.number)} • ${role.label}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.swap_horiz_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
