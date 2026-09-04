import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// شفافیت مالی ساکنین (گام ۴ سند)
///
/// نمودار دایره‌ای سهم هر سرفصل از هزینه‌های ساختمان + فهرست فاکتورها با
/// امکان مشاهده تصویر فاکتور (WebP فشرده زیر ۱۰۰ کیلوبایت) با یک لمس.
/// ---------------------------------------------------------------------------
class ResidentTransparency extends StatefulWidget {
  const ResidentTransparency({super.key});

  @override
  State<ResidentTransparency> createState() => _ResidentTransparencyState();
}

class _ResidentTransparencyState extends State<ResidentTransparency> {
  int _touchedIndex = -1;
  ExpenseType? _filter;

  static const List<Color> _palette = [
    Color(0xFF0D7A7A),
    Color(0xFF3B6EA5),
    Color(0xFFE8873B),
    Color(0xFF7C5CBF),
    Color(0xFF2E9E5B),
    Color(0xFFD64545),
    Color(0xFF139A8F),
    Color(0xFF9B7A1A),
    Color(0xFF6B7280),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final balance = store.fundBalance;
    final byCategory = store.expenseByCategory;
    final total = byCategory.values.fold<int>(0, (s, v) => s + v);

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final expenses = _filter == null
        ? store.buildingExpenses
        : store.expensesOfType(_filter!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('شفافیت مالی ساختمان'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------- مانده صندوق‌ها ----------
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.savings_rounded,
                    title: 'مانده صندوق جاری',
                    value: Persian.money(balance.currentBalance),
                    color: balance.hasCurrentDeficit
                        ? AppColors.danger
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.foundation_rounded,
                    title: 'مانده صندوق عمرانی',
                    value: Persian.money(balance.reserveBalance),
                    color: balance.hasReserveDeficit
                        ? AppColors.danger
                        : AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.trending_up_rounded,
                    title: 'مجموع وصولی',
                    value: Persian.money(balance.totalCollected),
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.hourglass_bottom_rounded,
                    title: 'مطالبات وصول‌نشده',
                    value: Persian.money(balance.totalReceivable),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ---------- نمودار دایره‌ای ----------
            const SectionHeader(title: 'سهم سرفصل‌ها از هزینه‌ها'),
            const SizedBox(height: 12),
            if (total == 0)
              const EmptyState(
                icon: Icons.pie_chart_outline_rounded,
                message: 'هنوز هزینه‌ای در این ساختمان ثبت نشده است',
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 52,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                setState(() {
                                  _touchedIndex = response
                                          ?.touchedSection?.touchedSectionIndex ??
                                      -1;
                                });
                              },
                            ),
                            sections: [
                              for (var i = 0; i < entries.length; i++)
                                PieChartSectionData(
                                  value: entries[i].value.toDouble(),
                                  color: _palette[i % _palette.length],
                                  radius: _touchedIndex == i ? 64 : 54,
                                  title:
                                      '${Persian.digits((entries[i].value / total * 100).round())}٪',
                                  titleStyle: TextStyle(
                                    fontSize: _touchedIndex == i ? 14 : 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // راهنمای نمودار
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < entries.length; i++)
                            _LegendChip(
                              color: _palette[i % _palette.length],
                              label: entries[i].key.label,
                              amount: entries[i].value,
                              highlighted: _touchedIndex == i,
                            ),
                        ],
                      ),
                      const Divider(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('مجموع هزینه‌ها: ',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          Text(
                            Persian.toman(total),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // ---------- فهرست فاکتورها ----------
            const SectionHeader(title: 'فاکتورهای هزینه'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _FilterChip(
                  label: 'همه',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                _FilterChip(
                  label: 'مصرفی (مستاجر)',
                  selected: _filter == ExpenseType.consumable,
                  onTap: () =>
                      setState(() => _filter = ExpenseType.consumable),
                ),
                _FilterChip(
                  label: 'عمرانی (مالک)',
                  selected: _filter == ExpenseType.capital,
                  onTap: () => setState(() => _filter = ExpenseType.capital),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (expenses.isEmpty)
              const EmptyState(
                icon: Icons.receipt_outlined,
                message: 'فاکتوری در این سرفصل ثبت نشده است',
              )
            else
              ...expenses.map((e) => _ExpenseTile(expense: e)),
            const SizedBox(height: 12),
            const _TransparencyNote(),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final int amount;
  final bool highlighted;

  const _LegendChip({
    required this.color,
    required this.label,
    required this.amount,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? color.withValues(alpha: 0.14) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11.5)),
          const SizedBox(width: 4),
          Text(
            Persian.money(amount),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

/// ردیف یک فاکتور هزینه — با لمس، تصویر فاکتور نمایش داده می‌شود
class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  const _ExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final isCapital = expense.expenseType == ExpenseType.capital;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: expense.hasInvoiceImage
            ? () => showExpenseInvoiceViewer(context, expense)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCapital
                      ? AppColors.secondary.withValues(alpha: 0.12)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(expense.category.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${expense.category.label} • ${Persian.shortDate(expense.date)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        StatusChip(
                          label: expense.expenseType.shortLabel,
                          color: isCapital
                              ? AppColors.secondary
                              : AppColors.primary,
                        ),
                        if (expense.hasInvoiceImage) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.image_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          const Text('مشاهده فاکتور',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                Persian.money(expense.amount),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نمایشگر تصویر فاکتور (پشتیبانی از data-URI، مسیر فایل محلی و URL)
Future<void> showExpenseInvoiceViewer(
    BuildContext context, Expense expense) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Persian.toman(expense.amount)} • ${Persian.shortDate(expense.date)}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              maxScale: 4,
              child: expenseImageWidget(expense.invoiceUrl),
            ),
          ),
          if (expense.invoiceSizeBytes != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'حجم تصویر پس از فشرده‌سازی: '
                '${Persian.digits((expense.invoiceSizeBytes! / 1024).toStringAsFixed(0))} کیلوبایت',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          if (expense.note != null && expense.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(expense.note!,
                  style: const TextStyle(fontSize: 12, height: 1.7)),
            ),
        ],
      ),
    ),
  );
}

/// ساخت ویجت تصویر از منابع مختلف (data-URI / فایل / شبکه)
Widget expenseImageWidget(String? url) {
  if (url == null || url.isEmpty) {
    return const SizedBox(
      height: 180,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 48, color: AppColors.divider),
      ),
    );
  }
  try {
    if (url.startsWith('data:')) {
      final b64 = url.substring(url.indexOf(',') + 1);
      return Image.memory(base64Decode(b64), fit: BoxFit.contain);
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 180,
          child: Center(child: Icon(Icons.broken_image_outlined, size: 48)),
        ),
      );
    }
    return Image.file(File(url), fit: BoxFit.contain);
  } catch (_) {
    return const SizedBox(
      height: 180,
      child: Center(child: Icon(Icons.broken_image_outlined, size: 48)),
    );
  }
}

class _TransparencyNote extends StatelessWidget {
  const _TransparencyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'طبق ماده ۴ قانون تملک آپارتمان‌ها، سهم هر واحد از هزینه‌های '
              'مشترک بر مبنای مساحت، تعداد نفرات و پارکینگ محاسبه می‌شود. '
              'هزینه‌های عمرانی بر عهده مالک و هزینه‌های مصرفی بر عهده '
              'متصرف (مستاجر) است.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.8, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
