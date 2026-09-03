import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// رزرو امکانات مشترک ساختمان
class ResidentBookingPage extends StatefulWidget {
  const ResidentBookingPage({super.key});

  @override
  State<ResidentBookingPage> createState() => _ResidentBookingPageState();
}

class _ResidentBookingPageState extends State<ResidentBookingPage> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.currentUnit!;
    final myBookings = store.buildingBookings.where((b) => b.unitId == unit.id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(title: const Text('رزرو امکانات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'امکانات مشترک'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: AppStore.facilities.length,
              itemBuilder: (ctx, i) {
                final f = AppStore.facilities[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showBookingSheet(context, f),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _facilityIcon(f.icon),
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          f.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'رزروهای من'),
            const SizedBox(height: 12),
            if (myBookings.isEmpty)
              const EmptyState(
                icon: Icons.event_busy_rounded,
                message: 'هنوز رزروی ندارید',
              )
            else
              ...myBookings.map((b) {
                final facility = AppStore.facilities
                    .firstWhere((f) => f.id == b.facilityId);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.secondaryLight,
                      child: Icon(_facilityIcon(facility.icon),
                          color: AppColors.secondary, size: 20),
                    ),
                    title: Text(
                      facility.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${Persian.shortDate(b.date)} • ساعت ${b.timeSlot}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        await store.cancelBooking(b.id);
                        if (context.mounted) {
                          showSuccessSnack(context, 'رزرو لغو شد');
                        }
                      },
                      child: const Text('لغو',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  IconData _facilityIcon(String icon) => switch (icon) {
        'hall' => Icons.celebration_rounded,
        'pool' => Icons.pool_rounded,
        'gym' => Icons.fitness_center_rounded,
        'guest' => Icons.bed_rounded,
        'roof' => Icons.deck_rounded,
        _ => Icons.meeting_room_rounded,
      };

  void _showBookingSheet(BuildContext context, Facility facility) {
    final store = context.read<AppStore>();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String? selectedSlot;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            right: 20,
            left: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'رزرو ${facility.name}',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              const Text('انتخاب روز:',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  itemBuilder: (ctx, i) {
                    final d = DateTime.now().add(Duration(days: i + 1));
                    final selected = d.day == selectedDate.day &&
                        d.month == selectedDate.month;
                    return GestureDetector(
                      onTap: () => setSheet(() {
                        selectedDate = d;
                        selectedSlot = null;
                      }),
                      child: Container(
                        width: 56,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.divider,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _weekdayShort(d),
                              style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? Colors.white70
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Persian.digits(_jalaliDay(d)),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('انتخاب بازه زمانی:',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppStore.timeSlots.map((slot) {
                  final taken =
                      store.isSlotTaken(facility.id, selectedDate, slot);
                  final selected = selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(slot),
                    selected: selected,
                    onSelected: taken
                        ? null
                        : (_) => setSheet(() => selectedSlot = slot),
                    selectedColor: AppColors.primary,
                    disabledColor: AppColors.divider.withValues(alpha: 0.5),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: taken
                          ? AppColors.textSecondary
                          : (selected ? Colors.white : AppColors.textPrimary),
                      decoration: taken ? TextDecoration.lineThrough : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedSlot == null
                      ? null
                      : () async {
                          await store.addBooking(
                            facilityId: facility.id,
                            unitId: store.currentUnit!.id,
                            date: selectedDate,
                            timeSlot: selectedSlot!,
                          );
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          if (context.mounted) {
                            showSuccessSnack(context,
                                '${facility.name} برای ${Persian.shortDate(selectedDate)} ساعت $selectedSlot رزرو شد');
                          }
                        },
                  child: const Text('تایید رزرو'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayShort(DateTime d) {
    final j = Jalali.fromDateTime(d);
    const names = {
      1: 'ش',
      2: 'ی',
      3: 'د',
      4: 'س',
      5: 'چ',
      6: 'پ',
      7: 'ج',
    };
    return names[j.weekDay] ?? '';
  }

  int _jalaliDay(DateTime d) => Jalali.fromDateTime(d).day;
}
