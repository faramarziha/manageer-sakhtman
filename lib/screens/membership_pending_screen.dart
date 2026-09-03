import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/persian.dart';
import 'resident/resident_shell.dart';
import 'resident_join_screen.dart';

/// صفحه انتظار تایید عضویت توسط مدیر ساختمان
class MembershipPendingScreen extends StatelessWidget {
  const MembershipPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    final req = store.myMembershipRequest;

    // اگر مدیر تایید کرد → هدایت خودکار به اپ ساکن
    if (user != null && user.membershipStatus == MembershipStatus.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ResidentShell()),
            (_) => false,
          );
        }
      });
    }

    final rejected = user?.membershipStatus == MembershipStatus.rejected;
    final building = store.currentBuilding;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: rejected
                        ? AppColors.dangerLight
                        : AppColors.warningLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    rejected
                        ? Icons.cancel_outlined
                        : Icons.hourglass_top_rounded,
                    size: 64,
                    color: rejected ? AppColors.danger : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  rejected
                      ? 'درخواست عضویت رد شد'
                      : 'در انتظار تایید مدیر',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  rejected
                      ? 'متأسفانه درخواست عضویت شما توسط مدیر ساختمان رد شد. می‌توانید مجدداً درخواست دهید یا با مدیر تماس بگیرید.'
                      : 'درخواست عضویت شما ثبت شد و در انتظار بررسی مدیر ساختمان است. پس از تایید، به واحد متصل شده و به پرداخت‌های واحد دسترسی پیدا می‌کنید.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.9,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                // جزئیات درخواست
                if (req != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        _row('ساختمان', building?.name ?? '-'),
                        _row('واحد', Persian.digits(req.unitNumber)),
                        _row('نوع ارتباط',
                            req.isOwner ? 'مالک' : 'مستأجر'),
                        _row(
                          'تاریخ ثبت',
                          Persian.fullDate(req.createdAt),
                        ),
                        _row(
                          'وضعیت',
                          req.status.label,
                          valueColor: rejected
                              ? AppColors.danger
                              : AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                if (rejected)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('ثبت درخواست مجدد'),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ResidentJoinScreen(
                              name: user?.fullName ?? '',
                              phone: user?.phone ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                TextButton.icon(
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('خروج از حساب'),
                  onPressed: () async {
                    await store.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          '/', (_) => false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(
            v,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
