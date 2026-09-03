import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import '../widgets/common_widgets.dart';
import 'subscription_screen.dart';
import 'login_screen.dart';
import 'manager/card_settings_screen.dart';

/// صفحه تنظیمات و حساب کاربری
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser!;
    final building = store.currentBuilding;
    final sub = store.currentSubscription;

    return Scaffold(
      appBar: AppBar(title: const Text('حساب کاربری')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // پروفایل کاربر
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0] : '؟',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            Persian.digits(user.phone),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: user.role == UserRole.manager
                                  ? AppColors.primaryLight
                                  : AppColors.secondaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              user.role == UserRole.manager
                                  ? 'مدیر ساختمان'
                                  : 'ساکن - واحد ${Persian.digits(store.currentUnit?.number ?? 0)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: user.role == UserRole.manager
                                    ? AppColors.primary
                                    : AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // اطلاعات ساختمان
            if (building != null) ...[
              const SectionHeader(title: 'ساختمان'),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.apartment_rounded,
                          color: AppColors.primary),
                      title: Text(building.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(
                        '${building.city}، ${building.address}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    if (user.role == UserRole.manager) ...[
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.key_rounded,
                            color: AppColors.accent),
                        title: const Text('کد دعوت ساکنین',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: Text(
                          building.inviteCode,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: AppColors.primary,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'کپی کد دعوت',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: building.inviteCode));
                            showSuccessSnack(context, 'کد دعوت کپی شد');
                          },
                        ),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: building.hasCardInfo
                                ? AppColors.successLight
                                : AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.credit_card_rounded,
                            color: building.hasCardInfo
                                ? AppColors.success
                                : AppColors.danger,
                            size: 20,
                          ),
                        ),
                        title: const Text('کارت مقصد (کارت به کارت)',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: Text(
                          building.hasCardInfo
                              ? '${building.cardHolder} • ${Persian.digits(building.cardNumber)}'
                              : 'ثبت نشده - برای دریافت کارت به کارت الزامی است',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14,
                            color: AppColors.textSecondary),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CardSettingsScreen()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // اشتراک
            if (user.role == UserRole.manager) ...[
              const SectionHeader(title: 'اشتراک و پرداخت'),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.warning),
                  ),
                  title: Text(
                    sub != null
                        ? 'طرح ${sub.plan.name}${sub.isTrial ? ' (آزمایشی)' : ''}'
                        : 'بدون اشتراک',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    sub != null && sub.isActive
                        ? '${Persian.digits(sub.daysLeft)} روز باقی‌مانده'
                        : 'برای ادامه استفاده اشتراک تهیه کنید',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 14, color: AppColors.textSecondary),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // سایر گزینه‌ها
            const SectionHeader(title: 'عمومی'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  _menuTile(
                    icon: Icons.support_agent_rounded,
                    title: 'پشتیبانی',
                    subtitle: '۰۲۱-۹۱۰۰۱۱۰۰ - شنبه تا پنجشنبه ۹ تا ۱۸',
                    onTap: () {},
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _menuTile(
                    icon: Icons.description_outlined,
                    title: 'قوانین و مقررات',
                    subtitle: 'شرایط استفاده از سرویس',
                    onTap: () {},
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _menuTile(
                    icon: Icons.info_outline_rounded,
                    title: 'درباره اپلیکیشن',
                    subtitle: 'نسخه ۱.۰.۰ - ساخته‌شده برای ایران',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // خروج
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('خروج از حساب'),
                    content: const Text(
                        'آیا می‌خواهید از حساب کاربری خود خارج شوید؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('انصراف'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('خروج',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await store.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout_rounded,
                  size: 18, color: AppColors.danger),
              label: const Text('خروج از حساب کاربری',
                  style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.arrow_back_ios_new_rounded,
          size: 14, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
