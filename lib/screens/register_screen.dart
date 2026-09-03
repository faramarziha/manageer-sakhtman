import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import 'building_setup_screen.dart';
import 'resident_join_screen.dart';

/// ثبت‌نام کاربر جدید - انتخاب نقش مدیر یا ساکن
class RegisterScreen extends StatefulWidget {
  final String phone;
  const RegisterScreen({super.key, required this.phone});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  UserRole? _role;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate() || _role == null) return;

    if (_role == UserRole.manager) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuildingSetupScreen(
            managerName: _nameCtrl.text.trim(),
            phone: widget.phone,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResidentJoinScreen(
            name: _nameCtrl.text.trim(),
            phone: widget.phone,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تکمیل ثبت‌نام')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'خوش آمدید!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'شماره ${Persian.digits(widget.phone)} تایید شد. اطلاعات خود را تکمیل کنید.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام و نام خانوادگی',
                    hintText: 'مثلاً: علی محمدی',
                    prefixIcon: Icon(Icons.person_outline_rounded,
                        color: AppColors.primary),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'نام کامل را وارد کنید'
                      : null,
                ),
                const SizedBox(height: 28),
                const Text(
                  'شما در ساختمان چه نقشی دارید؟',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _RoleOption(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'مدیر ساختمان',
                  subtitle: 'ساختمان جدیدی ثبت می‌کنم و آن را مدیریت می‌کنم',
                  selected: _role == UserRole.manager,
                  color: AppColors.primary,
                  onTap: () => setState(() => _role = UserRole.manager),
                ),
                const SizedBox(height: 12),
                _RoleOption(
                  icon: Icons.person_rounded,
                  title: 'ساکن ساختمان',
                  subtitle: 'با کد دعوت مدیر، به ساختمانم متصل می‌شوم',
                  selected: _role == UserRole.resident,
                  color: AppColors.secondary,
                  onTap: () => setState(() => _role = UserRole.resident),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _role == null ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('ادامه', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: selected ? color : AppColors.divider,
            ),
          ],
        ),
      ),
    );
  }
}
