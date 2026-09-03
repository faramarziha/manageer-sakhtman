import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// مدیریت پرداخت‌های ساختمان: ایجاد، بررسی رسیدها، تایید/رد
class ManagerPaymentsPage extends StatefulWidget {
  const ManagerPaymentsPage({super.key});

  @override
  State<ManagerPaymentsPage> createState() => _ManagerPaymentsPageState();
}

class _ManagerPaymentsPageState extends State<ManagerPaymentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  PaymentCategory? _catFilter;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final awaiting = store.awaitingApprovalPayments;
    final all = store.currentMonthPayments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت پرداخت‌ها'),
        bottom: TabBar(
          controller: _tab,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('بررسی رسیدها'),
                  if (awaiting.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        Persian.digits(awaiting.length),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'همه پرداخت‌ها'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePaymentSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ایجاد پرداخت'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tab,
          children: [
            // ---------- تب بررسی رسیدها ----------
            awaiting.isEmpty
                ? const EmptyState(
                    icon: Icons.task_alt_rounded,
                    message:
                        'رسیدی در انتظار بررسی نیست. رسیدهای کارت به کارت ساکنین اینجا نمایش داده می‌شود.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: awaiting.length,
                    itemBuilder: (ctx, i) =>
                        _ReceiptReviewTile(payment: awaiting[i]),
                  ),

            // ---------- تب همه پرداخت‌ها ----------
            Column(
              children: [
                // آمار ماه جاری
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.check_circle_rounded,
                          title: 'وصول‌شده',
                          value: Persian.money(store.paidPaymentsSum),
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: Icons.pending_actions_rounded,
                          title: 'در انتظار وصول',
                          value: Persian.money(store.unpaidPaymentsSum),
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // فیلتر دسته‌بندی
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _CatChip(
                        label: 'همه',
                        selected: _catFilter == null,
                        onTap: () => setState(() => _catFilter = null),
                      ),
                      ...PaymentCategory.values.map((c) => _CatChip(
                            label: '${c.emoji} ${c.label}',
                            selected: _catFilter == c,
                            onTap: () => setState(() => _catFilter = c),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Builder(
                    builder: (_) {
                      var list = all;
                      if (_catFilter != null) {
                        list = list
                            .where((p) => p.category == _catFilter)
                            .toList();
                      }
                      if (list.isEmpty) {
                        return const EmptyState(
                          icon: Icons.payments_outlined,
                          message:
                              'پرداختی برای ماه جاری ثبت نشده است. با دکمه «ایجاد پرداخت» شروع کنید.',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        itemCount: list.length,
                        itemBuilder: (ctx, i) =>
                            _ManagerPaymentTile(payment: list[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// شیت ایجاد پرداخت جدید برای واحدها
  void _showCreatePaymentSheet(BuildContext context) {
    final store = context.read<AppStore>();
    final units = store.buildingUnits;
    PaymentCategory category = PaymentCategory.charge;
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final monthCtrl =
        TextEditingController(text: _defaultMonth(store));
    final selected = units.map((u) => u.id).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            right: 20,
            left: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const Text(
                  'ایجاد پرداخت جدید',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                // دسته‌بندی
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PaymentCategory.values
                      .map(
                        (c) => ChoiceChip(
                          label: Text('${c.emoji} ${c.label}',
                              style: const TextStyle(fontSize: 12)),
                          selected: category == c,
                          onSelected: (_) =>
                              setSheet(() => category = c),
                          selectedColor: AppColors.primaryLight,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'عنوان پرداخت',
                    hintText: 'مثلاً: شارژ ${_defaultMonth(store)}',
                    prefixIcon: const Icon(Icons.title_rounded,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9۰-۹]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'مبلغ (تومان)',
                    hintText: 'مثلاً: 850000',
                    prefixIcon: Icon(Icons.payments_rounded,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: monthCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ماه / دوره',
                    prefixIcon: Icon(Icons.calendar_month_rounded,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 14),
                // انتخاب واحدها
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'واحدهای مشمول (${Persian.digits(selected.length)})',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    TextButton(
                      onPressed: () => setSheet(() {
                        if (selected.length == units.length) {
                          selected.clear();
                        } else {
                          selected
                            ..clear()
                            ..addAll(units.map((u) => u.id));
                        }
                      }),
                      child: Text(
                        selected.length == units.length
                            ? 'لغو همه'
                            : 'انتخاب همه',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: units
                      .map(
                        (u) => FilterChip(
                          label: Text(Persian.digits(u.number),
                              style: const TextStyle(fontSize: 12)),
                          selected: selected.contains(u.id),
                          onSelected: (v) => setSheet(() {
                            v ? selected.add(u.id) : selected.remove(u.id);
                          }),
                          selectedColor: AppColors.primaryLight,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_card_rounded, size: 20),
                  label: const Text('ثبت پرداخت برای واحدها'),
                  onPressed: () async {
                    final amount = int.tryParse(amountCtrl.text
                            .replaceAll(RegExp(r'[^0-9]'), '')) ??
                        0;
                    if (amount <= 0 || selected.isEmpty) {
                      showSuccessSnack(ctx,
                          'مبلغ معتبر و حداقل یک واحد انتخاب کنید');
                      return;
                    }
                    await store.createPayments(
                      category: category,
                      title: titleCtrl.text.trim().isEmpty
                          ? '${category.label} ${monthCtrl.text.trim()}'
                          : titleCtrl.text.trim(),
                      amount: amount,
                      unitIds: selected.toList(),
                      month: monthCtrl.text.trim(),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      showSuccessSnack(context,
                          'پرداخت برای ${Persian.digits(selected.length)} واحد ثبت شد');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _defaultMonth(AppStore store) {
    final p = store.currentMonthPayments;
    return p.isNotEmpty ? p.first.month : '';
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip(
      {required this.label, required this.selected, required this.onTap});

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

/// کارت بررسی رسید کارت به کارت (تایید/رد با دلیل)
class _ReceiptReviewTile extends StatelessWidget {
  final Payment payment;
  const _ReceiptReviewTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final unit = store.unitById(payment.unitId);

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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(payment.category.emoji,
                      style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'واحد ${Persian.digits(unit?.number ?? 0)} • ${unit?.ownerName ?? ''}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  Persian.toman(payment.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // رسید ساکن (شبیه‌سازی)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_rounded,
                          size: 16, color: AppColors.secondary),
                      SizedBox(width: 6),
                      Text(
                        'رسید ارسالی ساکن (کارت به کارت)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.image_rounded,
                          size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('receipt.jpg',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    payment.receiptNote ?? '-',
                    style: const TextStyle(fontSize: 12, height: 1.7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('تایید پرداخت'),
                    onPressed: () async {
                      await store.approvePayment(payment.id);
                      if (context.mounted) {
                        showSuccessSnack(context,
                            'پرداخت واحد ${Persian.digits(unit?.number ?? 0)} تایید شد');
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('رد با توضیح'),
                    onPressed: () => _showRejectDialog(context, payment),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, Payment payment) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('رد رسید پرداخت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'دلیل رد برای ساکن نمایش داده می‌شود تا بتواند مجدداً رسید ارسال کند.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.7),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'دلیل رد',
                hintText: 'مثلاً: مبلغ رسید با مبلغ پرداخت مطابقت ندارد',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final store = context.read<AppStore>();
              await store.rejectPayment(payment.id, ctrl.text.trim());
              if (dCtx.mounted) Navigator.pop(dCtx);
              if (context.mounted) {
                showSuccessSnack(context, 'رسید رد شد و دلیل آن برای ساکن ثبت گردید');
              }
            },
            child: const Text('ثبت رد',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// کارت پرداخت در تب «همه پرداخت‌ها»
class _ManagerPaymentTile extends StatelessWidget {
  final Payment payment;
  const _ManagerPaymentTile({required this.payment});

  Color get _color => switch (payment.status) {
        PaymentStatus.paid => AppColors.success,
        PaymentStatus.awaitingApproval => AppColors.secondary,
        PaymentStatus.rejected => AppColors.danger,
        PaymentStatus.unpaid => AppColors.warning,
      };

  Color get _bg => switch (payment.status) {
        PaymentStatus.paid => AppColors.successLight,
        PaymentStatus.awaitingApproval => AppColors.secondaryLight,
        PaymentStatus.rejected => AppColors.dangerLight,
        PaymentStatus.unpaid => AppColors.warningLight,
      };

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final unit = store.unitById(payment.unitId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onLongPress: payment.status == PaymentStatus.unpaid
            ? () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('حذف پرداخت'),
                    content: Text(
                        '«${payment.title}» واحد ${Persian.digits(unit?.number ?? 0)} حذف شود؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('انصراف'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('حذف',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await store.deletePayment(payment.id);
                }
              }
            : null,
        leading: CircleAvatar(
          backgroundColor: _bg,
          child: Text(payment.category.emoji,
              style: const TextStyle(fontSize: 18)),
        ),
        title: Text(
          payment.title,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Text(
          'واحد ${Persian.digits(unit?.number ?? 0)} • ${payment.month}${payment.method != PaymentMethod.none ? ' • ${payment.method.label}' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Persian.money(payment.amount),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 4),
            StatusChip(
              label: payment.status.label,
              color: _color,
              bgColor: _bg,
            ),
          ],
        ),
      ),
    );
  }
}
