import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import 'manager/manager_shell.dart';

/// ویزارد راه‌اندازی ساختمان جدید - ثبت‌نام مدیر
class BuildingSetupScreen extends StatefulWidget {
  final String managerName;
  final String phone;

  const BuildingSetupScreen({
    super.key,
    required this.managerName,
    required this.phone,
  });

  @override
  State<BuildingSetupScreen> createState() => _BuildingSetupScreenState();
}

class _BuildingSetupScreenState extends State<BuildingSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _unitsCtrl = TextEditingController(text: '10');
  String _city = AppStore.iranianCities.first;
  PlanType _plan = PlanType.free;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _unitsCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final store = context.read<AppStore>();
    final unitsCount = int.tryParse(_unitsCtrl.text.trim()) ?? 10;

    final building = await store.registerManagerAndBuilding(
      managerName: widget.managerName,
      phone: widget.phone,
      buildingName: _nameCtrl.text.trim(),
      city: _city,
      address: _addressCtrl.text.trim(),
      unitsCount: unitsCount.clamp(1, _plan.maxUnits),
      plan: _plan,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    // نمایش کد دعوت و ورود به پنل مدیر
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.celebration_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('ساختمان ثبت شد!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ساختمان شما با موفقیت ایجاد شد و دوره آزمایشی ۱۴ روزه فعال گردید.',
              style: TextStyle(fontSize: 13, height: 1.7),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'کد دعوت ساکنین',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    building.inviteCode,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'این کد را به ساکنین بدهید تا به ساختمان متصل شوند',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dCtx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ManagerShell()),
                (_) => false,
              );
            },
            child: const Text('ورود به پنل مدیریت'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('راه‌اندازی ساختمان')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // اطلاعات ساختمان
                const _StepTitle(
                  icon: Icons.apartment_rounded,
                  title: 'مشخصات ساختمان',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام ساختمان / مجتمع',
                    hintText: 'مثلاً: برج آسمان، ساختمان گل‌ها',
                    prefixIcon: Icon(Icons.business_rounded,
                        color: AppColors.primary),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'نام ساختمان را وارد کنید'
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _city,
                  decoration: const InputDecoration(
                    labelText: 'شهر',
                    prefixIcon: Icon(Icons.location_city_rounded,
                        color: AppColors.primary),
                  ),
                  items: AppStore.iranianCities
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _city = v!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'آدرس',
                    hintText: 'خیابان، کوچه، پلاک...',
                    prefixIcon: Icon(Icons.location_on_outlined,
                        color: AppColors.primary),
                  ),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'آدرس را وارد کنید'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _unitsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'تعداد واحدها',
                    hintText: '۱۰',
                    prefixIcon: Icon(Icons.door_front_door_outlined,
                        color: AppColors.primary),
                  ),
                  validator: (v) {
                    final n = int.tryParse(
                            (v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ??
                        0;
                    if (n < 1) return 'حداقل ۱ واحد';
                    if (n > _plan.maxUnits) {
                      return 'طرح ${_plan.name} تا ${_plan.maxUnits} واحد را پشتیبانی می‌کند';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                // انتخاب طرح
                const _StepTitle(
                  icon: Icons.workspace_premium_rounded,
                  title: 'انتخاب طرح اشتراک',
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.card_giftcard_rounded,
                          color: AppColors.success, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '۱۴ روز استفاده رایگان از همه امکانات - بدون نیاز به کارت بانکی',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...PlanType.values.map((p) => _PlanOption(
                      plan: p,
                      selected: _plan == p,
                      onTap: () => setState(() => _plan = p),
                    )),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _finish,
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
                      : const Text('ایجاد ساختمان و شروع دوره رایگان',
                          style: TextStyle(fontSize: 15)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'با ثبت ساختمان، قوانین و مقررات استفاده از سرویس را می‌پذیرید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
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

class _StepTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _StepTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  final PlanType plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanOption({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPro = plan == PlanType.comprehensive;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.divider,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'طرح ${plan.name}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'پیشنهاد ما',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تا ${Persian.digits(plan.maxUnits > 100 ? 'نامحدود' : plan.maxUnits)} واحد',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Persian.money(plan.priceMonthly),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'تومان / ماهانه',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
