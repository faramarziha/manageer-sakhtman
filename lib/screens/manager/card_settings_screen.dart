import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// ثبت و مدیریت اطلاعات کارت مقصد برای پرداخت کارت به کارت
class CardSettingsScreen extends StatefulWidget {
  const CardSettingsScreen({super.key});

  @override
  State<CardSettingsScreen> createState() => _CardSettingsScreenState();
}

class _CardSettingsScreenState extends State<CardSettingsScreen> {
  late final TextEditingController _cardCtrl;
  late final TextEditingController _holderCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = context.read<AppStore>().currentBuilding;
    _cardCtrl = TextEditingController(text: b?.cardNumber ?? '');
    _holderCtrl = TextEditingController(text: b?.cardHolder ?? '');
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final store = context.read<AppStore>();
    await store.updateCardInfo(
      _digitsOnly(_cardCtrl.text),
      _holderCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    showSuccessSnack(context, 'اطلاعات کارت مقصد ذخیره شد');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final building = context.watch<AppStore>().currentBuilding;

    return Scaffold(
      appBar: AppBar(title: const Text('کارت مقصد (کارت به کارت)')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // پیش‌نمایش کارت
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.primary],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.credit_card_rounded,
                              color: Colors.white70, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'کارت مقصد ساختمان',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _previewCard(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _holderCtrl.text.trim().isEmpty
                            ? 'نام صاحب کارت'
                            : _holderCtrl.text.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  building?.hasCardInfo == true
                      ? 'این اطلاعات هنگام انتخاب «کارت به کارت» به ساکنین نمایش داده می‌شود.'
                      : 'هنوز کارتی ثبت نشده است. ساکنین تا ثبت کارت، امکان پرداخت کارت به کارت ندارند.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.7),
                ),
                const SizedBox(height: 24),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    controller: _cardCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 16,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9۰-۹]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      counterText: '',
                      labelText: 'شماره کارت مقصد',
                      hintText: '6104337912345678',
                      prefixIcon: Icon(Icons.credit_card_rounded,
                          color: AppColors.primary),
                    ),
                    validator: (v) => _digitsOnly(v ?? '').length != 16
                        ? 'شماره کارت ۱۶ رقمی را وارد کنید'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _holderCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'نام صاحب کارت',
                    hintText: 'مثلاً: بهنام شریفی',
                    prefixIcon: Icon(Icons.person_rounded,
                        color: AppColors.primary),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'نام صاحب کارت را وارد کنید'
                      : null,
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: const Text('ذخیره اطلاعات کارت',
                      style: TextStyle(fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _previewCard() {
    final raw = _digitsOnly(_cardCtrl.text).padRight(16, '•');
    final b = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) b.write('-');
      b.write(raw[i]);
    }
    return Persian.digits(b.toString());
  }
}
