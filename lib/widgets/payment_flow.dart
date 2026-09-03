import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import 'common_widgets.dart';

/// بازکردن شیت جریان پرداخت یک پرداخت مستقل
void showPaymentFlowSheet(BuildContext context, Payment payment) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => PaymentFlowSheet(paymentId: payment.id),
  );
}

/// شیت جریان پرداخت: انتخاب روش → کارت به کارت → ارسال رسید
class PaymentFlowSheet extends StatefulWidget {
  final String paymentId;
  const PaymentFlowSheet({super.key, required this.paymentId});

  @override
  State<PaymentFlowSheet> createState() => _PaymentFlowSheetState();
}

class _PaymentFlowSheetState extends State<PaymentFlowSheet> {
  PaymentMethod _method = PaymentMethod.none;
  final _receiptCtrl = TextEditingController();
  bool _receiptAttached = false;
  bool _submitting = false;

  @override
  void dispose() {
    _receiptCtrl.dispose();
    super.dispose();
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    showSuccessSnack(context, '$what کپی شد');
  }

  String _formatCard(String raw) {
    final b = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) b.write('-');
      b.write(raw[i]);
    }
    return Persian.digits(b.toString());
  }

  Future<void> _simulateOnlinePay(AppStore store) async {
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    await store.payOnline(widget.paymentId);
    if (!mounted) return;
    Navigator.pop(context);
    showSuccessSnack(context, 'پرداخت آنلاین با موفقیت انجام و تایید شد.');
  }

  Future<void> _submitReceipt(AppStore store) async {
    if (_receiptCtrl.text.trim().isEmpty) {
      showSuccessSnack(context, 'لطفاً توضیح یا شماره پیگیری رسید را وارد کنید');
      return;
    }
    setState(() => _submitting = true);
    await store.submitCardToCardReceipt(
        widget.paymentId, _receiptCtrl.text.trim());
    if (!mounted) return;
    Navigator.pop(context);
    showSuccessSnack(
        context, 'رسید شما ارسال شد. پرداخت در انتظار تایید مدیر است.');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    Payment? found;
    try {
      found = store.payments.firstWhere((p) => p.id == widget.paymentId);
    } catch (_) {
      return const SizedBox.shrink();
    }
    final payment = found;
    final building = store.currentBuilding;
    final bool showCard = building != null && building.hasCardInfo;
    final String cardHolder = building?.cardHolder ?? '';
    final String cardNumber = building?.cardNumber ?? '';

    return Padding(
      padding: EdgeInsets.only(
        right: 20,
        left: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
            const SizedBox(height: 18),
            // عنوان و مبلغ
            Row(
              children: [
                Text(payment.category.emoji,
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'دوره ${payment.month}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('مبلغ قابل پرداخت:',
                      style: TextStyle(fontSize: 13)),
                  Text(
                    Persian.toman(payment.amount),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // انتخاب روش پرداخت
            const Text('روش پرداخت را انتخاب کنید:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MethodCard(
                    icon: Icons.language_rounded,
                    label: 'پرداخت آنلاین',
                    selected: _method == PaymentMethod.online,
                    onTap: () =>
                        setState(() => _method = PaymentMethod.online),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MethodCard(
                    icon: Icons.credit_card_rounded,
                    label: 'کارت به کارت',
                    selected: _method == PaymentMethod.cardToCard,
                    onTap: () =>
                        setState(() => _method = PaymentMethod.cardToCard),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ---------- جریان پرداخت آنلاین ----------
            if (_method == PaymentMethod.online) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 20),
                  label: const Text('اتصال به درگاه و پرداخت'),
                  onPressed:
                      _submitting ? null : () => _simulateOnlinePay(store),
                ),
              ),
            ],

            // ---------- جریان کارت به کارت ----------
            if (_method == PaymentMethod.cardToCard) ...[
              if (!showCard)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'مدیر ساختمان هنوز اطلاعات کارت مقصد را ثبت نکرده است. لطفاً با مدیر تماس بگیرید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600),
                  ),
                )
              else ...[
                // کارت مقصد
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.primary],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.credit_card_rounded,
                              color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          const Text('کارت مقصد ساختمان',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          const Spacer(),
                          Text(cardHolder,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              _formatCard(cardNumber),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          _CopyBtn(
                            label: 'کپی کارت',
                            onTap: () => _copy(
                                cardNumber, 'شماره کارت'),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(Persian.toman(payment.amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              )),
                          _CopyBtn(
                            label: 'کپی مبلغ',
                            onTap: () =>
                                _copy('${payment.amount}', 'مبلغ'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // آپلود رسید (شبیه‌سازی)
                InkWell(
                  onTap: () =>
                      setState(() => _receiptAttached = !_receiptAttached),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _receiptAttached
                          ? AppColors.successLight
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _receiptAttached
                            ? AppColors.success
                            : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _receiptAttached
                              ? Icons.check_circle_rounded
                              : Icons.add_photo_alternate_outlined,
                          color: _receiptAttached
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _receiptAttached
                                ? 'رسید پرداخت پیوست شد (receipt.jpg)'
                                : 'آپلود رسید یا اسکرین‌شات پرداخت',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _receiptAttached
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(Icons.upload_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _receiptCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'توضیح رسید / شماره پیگیری',
                    hintText: 'مثلاً: کارت به کارت ساعت ۱۴:۳۰ - پیگیری ۱۲۳۴۵۶',
                    prefixIcon:
                        Icon(Icons.notes_rounded, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded,
                            size: 20),
                    label: const Text('پرداخت کردم'),
                    onPressed: _submitting
                        ? null
                        : () => _submitReceipt(store),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'پس از ارسال رسید، پرداخت شما در وضعیت «در انتظار تایید مدیر» قرار می‌گیرد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CopyBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
