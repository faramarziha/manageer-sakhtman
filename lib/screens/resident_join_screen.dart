import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import 'membership_pending_screen.dart';

/// ثبت درخواست عضویت ساکن (مالک/مستأجر) - نیازمند تایید مدیر
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
  bool _isOwner = true; // مالک یا مستأجر

  @override
  void dispose() {
    _codeCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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

    final request = await store.submitMembershipRequest(
      name: widget.name,
      phone: widget.phone,
      inviteCode: _codeCtrl.text,
      unitNumber: unitNumber,
      requestedRole: _isOwner ? UnitRole.owner : UnitRole.tenant,
    );

    if (!mounted) return;

    if (request == null) {
      setState(() {
        _loading = false;
        _error = 'واحد ${Persian.digits(unitNumber)} در این ساختمان یافت نشد.';
      });
      return;
    }

    setState(() => _loading = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MembershipPendingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('درخواست عضویت در ساختمان')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.how_to_reg_rounded,
                    size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'درخواست عضویت در واحد',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'درخواست شما پس از تایید مدیر ساختمان فعال می‌شود و سپس به واحد متصل خواهید شد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
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
                      labelText: 'کد دعوت ساختمان',
                    ),
                    validator: (v) => (v == null || v.trim().length != 6)
                        ? 'کد دعوت ۶ کاراکتری را وارد کنید'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                // نوع ارتباط با واحد
                const Text(
                  'نوع ارتباط شما با واحد:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RelationCard(
                        icon: Icons.key_rounded,
                        label: 'مالک',
                        subtitle: 'صاحب واحد هستم',
                        selected: _isOwner,
                        onTap: () => setState(() => _isOwner = true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RelationCard(
                        icon: Icons.home_work_rounded,
                        label: 'مستأجر',
                        subtitle: 'ساکن واحد هستم',
                        selected: !_isOwner,
                        onTap: () => setState(() => _isOwner = false),
                      ),
                    ),
                  ],
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
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
                      : const Text('ثبت درخواست عضویت',
                          style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'دمو: کد دعوت «MEHR24» و واحد ۱۰۲. درخواست شما در پنل مدیر در انتظار بررسی قرار می‌گیرد.',
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

class _RelationCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RelationCard({
    required this.icon,
    required this.label,
    required this.subtitle,
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
                size: 26,
                color:
                    selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color:
                    selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
