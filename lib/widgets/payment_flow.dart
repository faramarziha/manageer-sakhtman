import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../data/image_compressor.dart';
import '../data/payment_gateway.dart';
import '../data/share_service.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import 'common_widgets.dart';

/// نمایش صفحه پرداخت صورتحساب
///
/// دو مسیر پرداخت مطابق گام ۲ سند راهبردی:
///   ۱) درگاه آنلاین شاپرک (initiate → redirect → verify → RRN)
///   ۲) کارت به کارت / نقدی با چهار رقم آخر کارت و تصویر رسید
///
/// هیچ سازوکار برداشت خودکار (Direct Debit) در این جریان وجود ندارد.
Future<void> showPaymentFlowSheet(BuildContext context, Invoice invoice) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PaymentFlowSheet(invoiceId: invoice.id),
  );
}

class PaymentFlowSheet extends StatefulWidget {
  final String invoiceId;
  const PaymentFlowSheet({super.key, required this.invoiceId});

  @override
  State<PaymentFlowSheet> createState() => _PaymentFlowSheetState();
}

class _PaymentFlowSheetState extends State<PaymentFlowSheet> {
  PayMethod _method = PayMethod.shaparak;
  final _last4Ctrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Uint8List? _receiptBytes;
  CompressionResult? _compression;
  bool _compressing = false;
  bool _submitting = false;

  /// کارمزد بر عهده کیست؟ پیش‌فرض: پرداخت‌کننده
  FeePayer _feePayer = FeePayer.payer;

  @override
  void dispose() {
    _last4Ctrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // انتخاب و فشرده‌سازی تصویر رسید (زیر ۱۰۰ کیلوبایت)
  // ---------------------------------------------------------------------
  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (file == null) return;

    setState(() => _compressing = true);
    final raw = await file.readAsBytes();
    final result = await ImageCompressor.compress(raw);
    if (!mounted) return;

    setState(() {
      _compressing = false;
      _compression = result;
      _receiptBytes = result?.bytes ?? raw;
    });
  }

  // ---------------------------------------------------------------------
  // پرداخت آنلاین: initiate → درگاه → verify
  // ---------------------------------------------------------------------
  Future<void> _payOnline(Invoice invoice) async {
    final store = context.read<AppStore>();
    setState(() => _submitting = true);

    final init = await store.startOnlinePayment(
      invoice.id,
      feePayer: _feePayer,
    );
    if (!mounted) return;

    if (!init.success || init.authority == null) {
      setState(() => _submitting = false);
      _snack(init.message ?? 'اتصال به درگاه پرداخت برقرار نشد', isError: true);
      return;
    }

    // هدایت به درگاه (در حالت شبیه‌سازی، لینک باز نمی‌شود)
    final url = init.redirectUrl;
    if (url != null && !url.startsWith('https://simulated.gateway')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    final verify = await store.verifyOnlinePayment(
      invoiceId: invoice.id,
      authority: init.authority!,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (verify.success) {
      Navigator.pop(context);
      showSuccessSnack(
        context,
        'پرداخت با موفقیت انجام شد • شماره پیگیری ${Persian.digits(verify.rrn ?? '-')}',
      );
    } else {
      _snack(verify.message ?? 'تایید پرداخت انجام نشد', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // ثبت رسید آفلاین (کارت به کارت / نقدی)
  // ---------------------------------------------------------------------
  Future<void> _submitOfflineReceipt(Invoice invoice) async {
    final last4 = Persian.digits(_last4Ctrl.text.trim());
    if (_last4Ctrl.text.trim().length != 4) {
      _snack('چهار رقم آخر کارت پرداخت‌کننده را وارد کنید', isError: true);
      return;
    }

    setState(() => _submitting = true);
    final store = context.read<AppStore>();
    await store.submitOfflineReceipt(
      invoiceId: invoice.id,
      cardLast4: last4,
      receiptUrl: _receiptBytes == null
          ? null
          : 'local://receipt_${invoice.id}.webp',
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      method: _method,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
    showSuccessSnack(
      context,
      'رسید ثبت شد و برای تایید مدیر ارسال گردید',
    );
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareInvoice(
      Building building, Unit unit, Invoice invoice) async {
    await ShareService.shareInvoice(
      building: building,
      unit: unit,
      invoice: invoice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final invoice = store.invoiceById(widget.invoiceId);
    final unit = invoice == null ? null : store.unitById(invoice.unitId);
    final building =
        invoice == null ? null : store.buildingById(invoice.buildingId);

    if (invoice == null || unit == null || building == null) {
      return const SizedBox(height: 220, child: Center(child: Text('یافت نشد')));
    }

    final fee = PaymentGateway.calculateFee(invoice.amount);
    final payable = PaymentGateway.payableAmount(invoice.amount, _feePayer);
    final canPay = invoice.status.isDebt;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            _handle(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _InvoiceHeader(
                    invoice: invoice,
                    unit: unit,
                    building: building,
                    onShare: () => _shareInvoice(building, unit, invoice),
                  ),
                  const SizedBox(height: 14),
                  if (invoice.breakdown.isNotEmpty) ...[
                    _BreakdownCard(invoice: invoice),
                    const SizedBox(height: 14),
                  ],
                  if (invoice.status == InvoiceStatus.paid)
                    _PaidReceiptCard(invoice: invoice)
                  else if (invoice.status == InvoiceStatus.awaitingApproval)
                    _AwaitingCard(invoice: invoice)
                  else ...[
                    if (invoice.status == InvoiceStatus.rejected)
                      _RejectedCard(invoice: invoice),
                    const SectionHeader(title: 'روش پرداخت'),
                    _MethodTile(
                      icon: Icons.credit_card_rounded,
                      title: 'پرداخت آنلاین (درگاه شاپرک)',
                      subtitle:
                          'پرداخت امن و تایید فوری با صدور رسید الکترونیکی',
                      selected: _method == PayMethod.shaparak,
                      onTap: () =>
                          setState(() => _method = PayMethod.shaparak),
                    ),
                    _MethodTile(
                      icon: Icons.compare_arrows_rounded,
                      title: 'کارت به کارت',
                      subtitle: 'واریز به کارت مدیر و ارسال رسید برای تایید',
                      selected: _method == PayMethod.cardToCard,
                      onTap: () =>
                          setState(() => _method = PayMethod.cardToCard),
                    ),
                    _MethodTile(
                      icon: Icons.payments_rounded,
                      title: 'پرداخت نقدی',
                      subtitle: 'تحویل نقدی به مدیر و ثبت رسید دستی',
                      selected: _method == PayMethod.cash,
                      onTap: () => setState(() => _method = PayMethod.cash),
                    ),
                    const SizedBox(height: 14),
                    if (_method == PayMethod.shaparak)
                      _OnlineSection(
                        invoice: invoice,
                        fee: fee,
                        payable: payable,
                        feePayer: _feePayer,
                        onFeePayerChanged: (v) =>
                            setState(() => _feePayer = v),
                      )
                    else
                      _OfflineSection(
                        building: building,
                        method: _method,
                        last4Ctrl: _last4Ctrl,
                        noteCtrl: _noteCtrl,
                        compression: _compression,
                        compressing: _compressing,
                        hasReceipt: _receiptBytes != null,
                        onPickReceipt: _pickReceipt,
                      ),
                  ],
                ],
              ),
            ),
            if (canPay)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _method == PayMethod.shaparak
                              ? _payOnline(invoice)
                              : _submitOfflineReceipt(invoice),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(_method == PayMethod.shaparak
                              ? Icons.lock_rounded
                              : Icons.upload_rounded),
                      label: Text(
                        _method == PayMethod.shaparak
                            ? 'پرداخت ${Persian.toman(payable)}'
                            : 'ثبت رسید و ارسال برای تایید',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

// ===========================================================================
// اجزای نمایشی
// ===========================================================================

class _InvoiceHeader extends StatelessWidget {
  final Invoice invoice;
  final Unit unit;
  final Building building;
  final VoidCallback onShare;

  const _InvoiceHeader({
    required this.invoice,
    required this.unit,
    required this.building,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(invoice.kind.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    invoice.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusChip(
                  label: invoice.status.label,
                  color: _statusColor(invoice.status),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              Persian.toman(invoice.amount),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _row('ساختمان', building.name),
            _row('واحد',
                '${Persian.digits(unit.number)} — طبقه ${Persian.digits(unit.floor)}'),
            _row('دوره', invoice.period),
            _row('گیرنده صورتحساب', invoice.recipientRole.label),
            _row('شناسه قبض', Persian.digits(invoice.billId)),
            _row('شناسه پرداخت', Persian.digits(invoice.paymentId)),
            _row('مهلت پرداخت', Persian.shortDate(invoice.dueDate)),
            if (invoice.isOverdue)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ ${Persian.digits(invoice.daysOverdue)} روز از مهلت پرداخت گذشته است',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 8),
            // اشتراک‌گذاری صورتحساب — جایگزین کامل پیامک (هزینه صفر)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('اشتراک‌گذاری صورتحساب'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

Color _statusColor(InvoiceStatus s) => switch (s) {
      InvoiceStatus.paid => AppColors.success,
      InvoiceStatus.awaitingApproval => AppColors.warning,
      InvoiceStatus.rejected => AppColors.danger,
      InvoiceStatus.overdue => AppColors.danger,
      InvoiceStatus.unpaid => AppColors.textSecondary,
    };

/// ریز محاسبه شارژ مطابق فرمول ماده ۴
class _BreakdownCard extends StatelessWidget {
  final Invoice invoice;
  const _BreakdownCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calculate_rounded,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 6),
                Text('ریز محاسبه (ماده ۴ قانون تملک آپارتمان‌ها)',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            ...invoice.breakdown.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(e.key,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(Persian.money(e.value),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const Divider(height: 18),
            Row(
              children: [
                const Text('جمع کل',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(Persian.toman(invoice.amount),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// بخش پرداخت آنلاین + شفافیت کارمزد درگاه
class _OnlineSection extends StatelessWidget {
  final Invoice invoice;
  final int fee;
  final int payable;
  final FeePayer feePayer;
  final ValueChanged<FeePayer> onFeePayerChanged;

  const _OnlineSection({
    required this.invoice,
    required this.fee,
    required this.payable,
    required this.feePayer,
    required this.onFeePayerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('جزئیات مالی تراکنش',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _line('مبلغ صورتحساب', Persian.money(invoice.amount)),
            _line('کارمزد درگاه (۱٪ با سقف مصوب)', Persian.money(fee)),
            const Divider(height: 18),
            _line(
              'مبلغ قابل پرداخت',
              Persian.money(payable),
              bold: true,
            ),
            const SizedBox(height: 12),
            SegmentedButton<FeePayer>(
              segments: const [
                ButtonSegment(
                  value: FeePayer.payer,
                  label: Text('کارمزد با پرداخت‌کننده',
                      style: TextStyle(fontSize: 11.5)),
                ),
                ButtonSegment(
                  value: FeePayer.buildingFund,
                  label: Text('کسر از تسویه مدیر',
                      style: TextStyle(fontSize: 11.5)),
                ),
              ],
              selected: {feePayer},
              onSelectionChanged: (s) => onFeePayerChanged(s.first),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'مبلغ پرداختی از طریق تسهیم خودکار پرداخت‌یار، مستقیماً به '
                'حساب (شبای) مدیر ساختمان واریز می‌شود و در هیچ مرحله‌ای در '
                'حساب شرکت نرم‌افزاری نگهداری نمی‌شود.',
                style: TextStyle(
                    fontSize: 11.5, height: 1.7, color: AppColors.primaryDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: bold ? 13 : 12.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                    color: bold
                        ? AppColors.textPrimary
                        : AppColors.textSecondary)),
            const Spacer(),
            Text('$value تومان',
                style: TextStyle(
                    fontSize: bold ? 13 : 12.5,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                    color: bold ? AppColors.primary : AppColors.textPrimary)),
          ],
        ),
      );
}

/// بخش کارت به کارت / نقدی
class _OfflineSection extends StatelessWidget {
  final Building building;
  final PayMethod method;
  final TextEditingController last4Ctrl;
  final TextEditingController noteCtrl;
  final CompressionResult? compression;
  final bool compressing;
  final bool hasReceipt;
  final VoidCallback onPickReceipt;

  const _OfflineSection({
    required this.building,
    required this.method,
    required this.last4Ctrl,
    required this.noteCtrl,
    required this.compression,
    required this.compressing,
    required this.hasReceipt,
    required this.onPickReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (method == PayMethod.cardToCard) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('کارت مقصد (مدیر ساختمان)',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (!building.hasCardInfo)
                    const Text(
                      'مدیر ساختمان هنوز شماره کارت مقصد را ثبت نکرده است.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.danger),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Persian.digits(_formatCard(building.cardNumber)),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                        IconButton(
                          tooltip: 'کپی شماره کارت',
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: building.cardNumber));
                            if (context.mounted) {
                              showSuccessSnack(
                                  context, 'شماره کارت کپی شد');
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 19),
                        ),
                      ],
                    ),
                    Text('به نام ${building.cardHolder}',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اطلاعات رسید',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: last4Ctrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'چهار رقم آخر کارت پرداخت‌کننده',
                    hintText: '۱۲۳۴',
                    counterText: '',
                    prefixIcon: Icon(Icons.pin_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'توضیح (اختیاری)',
                    hintText: 'مثلاً: واریز ساعت ۱۴:۳۰ از بانک ملت',
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: compressing ? null : onPickReceipt,
                  icon: compressing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(hasReceipt
                          ? Icons.check_circle_rounded
                          : Icons.image_rounded),
                  label: Text(compressing
                      ? 'در حال فشرده‌سازی تصویر...'
                      : hasReceipt
                          ? 'تصویر رسید انتخاب شد — تغییر تصویر'
                          : 'انتخاب تصویر رسید'),
                ),
                if (compression != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'تصویر در دستگاه شما فشرده شد: '
                        '${Persian.digits(compression!.compressedKb)} کیلوبایت '
                        '(${Persian.digits(compression!.reductionPercent)}٪ کاهش حجم)',
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.6,
                            color: AppColors.success,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatCard(String card) {
    final digits = card.replaceAll(RegExp(r'\D'), '');
    final parts = <String>[];
    for (var i = 0; i < digits.length; i += 4) {
      parts.add(digits.substring(i, (i + 4).clamp(0, digits.length)));
    }
    return parts.join(' - ');
  }
}

/// رسید الکترونیکی پرداخت موفق
class _PaidReceiptCard extends StatelessWidget {
  final Invoice invoice;
  const _PaidReceiptCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.successLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_rounded, color: AppColors.success),
                SizedBox(width: 8),
                Text('رسید الکترونیکی پرداخت',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            _row('روش پرداخت', invoice.method.label),
            if (invoice.rrn != null)
              _row('شماره پیگیری (RRN)', Persian.digits(invoice.rrn!)),
            if (invoice.cardLast4 != null)
              _row('کارت پرداخت',
                  '**** ${Persian.digits(invoice.cardLast4!)}'),
            if (invoice.paidAt != null)
              _row('تاریخ پرداخت', Persian.fullDate(invoice.paidAt!)),
            _row('شناسه قبض', Persian.digits(invoice.billId)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _AwaitingCard extends StatelessWidget {
  final Invoice invoice;
  const _AwaitingCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.warningLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
                SizedBox(width: 8),
                Text('در انتظار تایید مدیر',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'رسید شما ثبت شده و پس از بررسی مدیر ساختمان، وضعیت '
              'صورتحساب به «پرداخت شده» تغییر می‌کند.',
              style: TextStyle(fontSize: 12, height: 1.7),
            ),
            if (invoice.cardLast4 != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'کارت پرداخت: **** ${Persian.digits(invoice.cardLast4!)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RejectedCard extends StatelessWidget {
  final Invoice invoice;
  const _RejectedCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.dangerLight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'رسید قبلی رد شد: ${invoice.rejectionReason ?? 'بدون دلیل'}',
                style: const TextStyle(
                    fontSize: 12, height: 1.6, color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 22,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.primary : AppColors.divider,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
