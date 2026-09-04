import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/payment_flow.dart';

/// ---------------------------------------------------------------------------
/// رزرو مشاعات با تقویم و ودیعه آنلاین (گام ۴ سند)
///
/// کاربر امکان (سالن اجتماعات، استخر، سوئیت مهمان، …) و روز مورد نظر را
/// انتخاب می‌کند؛ بازه‌های ساعتی آزاد/رزروشده نمایش داده می‌شود. در صورت
/// نیاز به ودیعه، هم‌زمان با ثبت رزرو یک صورتحساب ودیعه صادر شده و رزرو
/// تنها پس از پرداخت آن قطعی می‌گردد.
/// ---------------------------------------------------------------------------
class ResidentBookingPage extends StatefulWidget {
  const ResidentBookingPage({super.key});

  @override
  State<ResidentBookingPage> createState() => _ResidentBookingPageState();
}

class _ResidentBookingPageState extends State<ResidentBookingPage> {
  String _amenityId = Amenity.defaults.first.id;
  late DateTime _day = _dateOnly(DateTime.now());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// بازه‌های ساعتی قابل رزرو (۸ صبح تا ۲۲)
  static const List<int> _startHours = [8, 10, 12, 14, 16, 18, 20];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.currentUnit;

    if (unit == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.event_busy_outlined,
            message: 'ابتدا باید به یک واحد متصل شوید',
          ),
        ),
      );
    }

    final amenity = Amenity.byId(_amenityId)!;
    final dayBookings = store.bookingsOn(_amenityId, _day);
    final myBookings = store.myBookings;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('رزرو مشاعات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'انتخاب امکانات، روز و بازه ساعتی؛ ودیعه به‌صورت آنلاین دریافت می‌شود.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // ---------- انتخاب امکانات ----------
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: Amenity.defaults.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final a = Amenity.defaults[i];
                  final sel = a.id == _amenityId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _amenityId = a.id),
                    child: Container(
                      width: 116,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            _iconFor(a.icon),
                            color: sel ? Colors.white : AppColors.primary,
                            size: 22,
                          ),
                          Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  sel ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            a.requiresDeposit
                                ? 'ودیعه ${Persian.money(a.defaultDeposit)}'
                                : 'بدون ودیعه',
                            style: TextStyle(
                              fontSize: 10,
                              color: sel
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // ---------- تقویم افقی ۱۴ روزه ----------
            const SectionHeader(title: 'انتخاب روز'),
            const SizedBox(height: 10),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final d = _dateOnly(DateTime.now().add(Duration(days: i)));
                  final j = Jalali.fromDateTime(d);
                  final sel = d == _day;
                  final count = store.bookingsOn(_amenityId, d).length;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _day = d),
                    child: Container(
                      width: 62,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              sel ? AppColors.primary : AppColors.divider,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            j.formatter.wN.substring(0, 2),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: sel
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Persian.digits(j.day),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color:
                                  sel ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            count > 0
                                ? '${Persian.digits(count)} رزرو'
                                : 'آزاد',
                            style: TextStyle(
                              fontSize: 9,
                              color: sel
                                  ? Colors.white70
                                  : (count > 0
                                      ? AppColors.warning
                                      : AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // ---------- بازه‌های ساعتی ----------
            SectionHeader(title: 'بازه‌های ${Persian.shortDate(_day)}'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.0,
              children: [
                for (final h in _startHours)
                  _SlotTile(
                    start: h,
                    end: (h + amenity.maxHours).clamp(h + 1, 24),
                    available: store.isSlotAvailable(
                      amenityId: _amenityId,
                      start: _day.add(Duration(hours: h)),
                      end: _day.add(
                        Duration(
                            hours: (h + amenity.maxHours).clamp(h + 1, 24)),
                      ),
                    ),
                    isPast: _day
                        .add(Duration(hours: h))
                        .isBefore(DateTime.now()),
                    onTap: () => _confirmBooking(context, amenity, h),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (dayBookings.isNotEmpty) ...[
              const SizedBox(height: 10),
              const SectionHeader(title: 'رزروهای این روز'),
              const SizedBox(height: 8),
              for (final b in dayBookings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${_hhmm(b.startTime)} تا ${_hhmm(b.endTime)}'
                        ' • ${b.status.label}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 24),

            // ---------- رزروهای من ----------
            const SectionHeader(title: 'رزروهای من'),
            const SizedBox(height: 10),
            if (myBookings.isEmpty)
              const EmptyState(
                icon: Icons.event_available_outlined,
                message: 'هنوز رزروی ثبت نکرده‌اید',
              )
            else
              ...myBookings.map((b) => _MyBookingTile(booking: b)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static String _hhmm(DateTime d) =>
      Persian.digits('${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}');

  IconData _iconFor(String icon) => switch (icon) {
        'hall' => Icons.groups_rounded,
        'pool' => Icons.pool_rounded,
        'gym' => Icons.fitness_center_rounded,
        'guest' => Icons.hotel_rounded,
        'roof' => Icons.deck_rounded,
        _ => Icons.apartment_rounded,
      };

  Future<void> _confirmBooking(
      BuildContext context, Amenity amenity, int hour) async {
    final store = context.read<AppStore>();
    final start = _day.add(Duration(hours: hour));
    final endHour = (hour + amenity.maxHours).clamp(hour + 1, 24);
    final end = _day.add(Duration(hours: endHour));

    if (start.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('امکان رزرو بازه گذشته وجود ندارد'),
        ),
      );
      return;
    }
    if (!store.isSlotAvailable(
        amenityId: amenity.id, start: start, end: end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('این بازه قبلاً رزرو شده است'),
        ),
      );
      return;
    }

    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('رزرو ${amenity.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('روز', Persian.fullDate(start)),
            _kv('ساعت',
                '${Persian.digits(hour)}:۰۰ تا ${Persian.digits(endHour)}:۰۰'),
            _kv(
              'ودیعه',
              amenity.requiresDeposit
                  ? Persian.toman(amenity.defaultDeposit)
                  : 'ندارد',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'توضیحات (اختیاری)',
                isDense: true,
              ),
            ),
            if (amenity.requiresDeposit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'پس از ثبت، صورتحساب ودیعه صادر می‌شود. رزرو تنها پس از '
                  'پرداخت ودیعه قطعی خواهد شد.',
                  style: TextStyle(fontSize: 11, height: 1.7),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ثبت رزرو')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final booking = await store.createBooking(
      amenityId: amenity.id,
      start: start,
      end: end,
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );

    if (!context.mounted) return;
    if (booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('ثبت رزرو ناموفق بود'),
        ),
      );
      return;
    }

    setState(() {});
    showSuccessSnack(context, 'رزرو شما ثبت شد');

    // هدایت مستقیم به پرداخت ودیعه
    if (booking.depositInvoiceId != null) {
      final inv = store.invoiceById(booking.depositInvoiceId!);
      if (inv != null && context.mounted) {
        await showPaymentFlowSheet(context, inv);
        final updated = store.invoiceById(inv.id);
        if (updated?.status == InvoiceStatus.paid) {
          await store.confirmBookingAfterDeposit(booking.id);
        }
      }
    }
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _SlotTile extends StatelessWidget {
  final int start;
  final int end;
  final bool available;
  final bool isPast;
  final VoidCallback onTap;

  const _SlotTile({
    required this.start,
    required this.end,
    required this.available,
    required this.isPast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = available && !isPast;
    final color = enabled
        ? AppColors.success
        : (isPast ? AppColors.textSecondary : AppColors.danger);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${Persian.digits(start)}:۰۰ - ${Persian.digits(end)}:۰۰',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              isPast ? 'گذشته' : (available ? 'آزاد' : 'رزرو شده'),
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyBookingTile extends StatelessWidget {
  final AmenityBooking booking;
  const _MyBookingTile({required this.booking});

  Color get _color => switch (booking.status) {
        BookingStatus.confirmed => AppColors.success,
        BookingStatus.pendingDeposit => AppColors.warning,
        BookingStatus.cancelled => AppColors.danger,
        BookingStatus.completed => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.amenityName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusChip(label: booking.status.label, color: _color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${Persian.fullDate(booking.startTime)} • '
              '${Persian.digits(booking.startTime.hour)}:۰۰ تا '
              '${Persian.digits(booking.endTime.hour)}:۰۰',
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondary),
            ),
            if (booking.requiresDeposit) ...[
              const SizedBox(height: 4),
              Text(
                'ودیعه: ${Persian.toman(booking.depositAmount)}',
                style: const TextStyle(fontSize: 11.5),
              ),
            ],
            if (booking.status == BookingStatus.pendingDeposit &&
                booking.depositInvoiceId != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.credit_card_rounded, size: 16),
                      label: const Text('پرداخت ودیعه',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final inv =
                            store.invoiceById(booking.depositInvoiceId!);
                        if (inv == null) return;
                        await showPaymentFlowSheet(context, inv);
                        final updated = store.invoiceById(inv.id);
                        if (updated?.status == InvoiceStatus.paid) {
                          await store
                              .confirmBookingAfterDeposit(booking.id);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => store.cancelBooking(booking.id),
                    child: const Text('لغو', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ] else if (booking.status == BookingStatus.confirmed &&
                !booking.isPast) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => store.cancelBooking(booking.id),
                  child: const Text('لغو رزرو',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
