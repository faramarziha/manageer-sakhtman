import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/app_store.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import 'resident/resident_shell.dart';

/// اتصال ساکن به ساختمان با کد دعوت
class ResidentJoinScreen extends StatefulWidget {
  final String name;
  final String phone;

  const ResidentJoinScreen({
    super.key,
    required this.name,
    required this.phone,
  });

  @override
  State<ResidentJoinScreen> createState() => _ResidentJoinScreenState();
}

class _ResidentJoinScreenState extends State<ResidentJoinScreen> {
  final _codeCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final store = context.read<AppStore>();
    final unitNumber =
        int.tryParse(_unitCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final building = store.findBuildingByInviteCode(_codeCtrl.text);
    if (building == null) {
      setState(() {
        _loading = false;
        _error = 'کد دعوت نامعتبر است. از مدیر ساختمان خود بخواهید.';
      });
      return;
    }

    final unit = await store.joinBuildingAsResident(
      name: widget.name,
      phone: widget.phone,
      inviteCode: _codeCtrl.text,
      unitNumber: unitNumber,
    );

    if (!mounted) return;

    if (unit == null) {
      setState(() {
        _loading = false;
        _error = 'واحد ${Persian.digits(unitNumber)} در این ساختمان یافت نشد.';
      });
      return;
    }

    setState(() => _loading = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ResidentShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اتصال به ساختمان')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.key_rounded,
                    size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'کد دعوت ساختمان',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'کد دعوت ۶ حرفی را از مدیر ساختمان خود دریافت و وارد کنید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    controller: _codeCtrl,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'MEHR24',
                    ),
                    validator: (v) => (v == null || v.trim().length != 6)
                        ? 'کد دعوت ۶ کاراکتری را وارد کنید'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _unitCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'شماره واحد شما',
                    hintText: 'مثلاً: ۱۰۲',
                    prefixIcon: Icon(Icons.door_front_door_outlined,
                        color: AppColors.primary),
                  ),
                  validator: (v) {
                    final n = int.tryParse(
                            (v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ??
                        0;
                    return n < 1 ? 'شماره واحد را وارد کنید' : null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _join,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('اتصال به ساختمان',
                          style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'دمو: کد دعوت ساختمان نمونه «MEHR24» و واحد ۱۰۲ است.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.secondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
