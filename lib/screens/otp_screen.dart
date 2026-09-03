import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import '../widgets/common_widgets.dart';
import 'manager/manager_shell.dart';
import 'resident/resident_shell.dart';
import 'register_screen.dart';

/// تایید کد یکبارمصرف (OTP) - شبیه‌سازی پیامک
class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const String demoCode = '12345';
  final List<TextEditingController> _ctrls =
      List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(5, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _secondsLeft = 120;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 120;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length != 5) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // تبدیل ارقام فارسی به انگلیسی برای مقایسه
    var code = _code;
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (var i = 0; i < 10; i++) {
      code = code.replaceAll(fa[i], '$i');
    }

    if (code != demoCode) {
      setState(() {
        _loading = false;
        _error = 'کد وارد شده صحیح نیست';
      });
      return;
    }

    final store = context.read<AppStore>();
    final existing = store.findUserByPhone(widget.phone);

    if (existing != null && existing.buildingId != null) {
      // کاربر موجود: ورود مستقیم
      await store.signIn(existing);
      if (!mounted) return;
      setState(() => _loading = false);
      _goHome(existing.role);
    } else {
      // کاربر جدید: ثبت‌نام
      setState(() => _loading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(phone: widget.phone),
        ),
      );
    }
  }

  void _goHome(UserRole role) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => role == UserRole.manager
            ? const ManagerShell()
            : const ResidentShell(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تایید شماره موبایل'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.sms_outlined,
                  size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'کد ۵ رقمی ارسال شده به\n${Persian.digits(widget.phone)} را وارد کنید',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.8,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return Container(
                      width: 52,
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      child: TextField(
                        controller: _ctrls[i],
                        focusNode: _nodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9۰-۹]')),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onChanged: (v) {
                          if (v.isNotEmpty && i < 4) {
                            _nodes[i + 1].requestFocus();
                          }
                          if (v.isEmpty && i > 0) {
                            _nodes[i - 1].requestFocus();
                          }
                          if (_code.length == 5) _verify();
                        },
                      ),
                    );
                  }),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed:
                    _loading || _code.length != 5 ? null : _verify,
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
                    : const Text('تایید و ادامه',
                        style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _secondsLeft > 0
                    ? null
                    : () {
                        _startTimer();
                        showSuccessSnack(
                            context, 'کد جدید ارسال شد (دمو: ۱۲۳۴۵)');
                      },
                child: Text(
                  _secondsLeft > 0
                      ? 'ارسال مجدد کد تا ${Persian.digits(_secondsLeft)} ثانیه دیگر'
                      : 'ارسال مجدد کد',
                  style: TextStyle(
                    color: _secondsLeft > 0
                        ? AppColors.textSecondary
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'نسخه نمایشی: کد تایید ۱۲۳۴۵ است. در نسخه نهایی از سرویس پیامک (کاوه‌نگار/قاصدک) استفاده می‌شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
