import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// داشبورد مدیر ساختمان
class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final progress = store.collectionProgress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('داشبورد مدیر'),
        actions: [
          IconButton(
            tooltip: 'بازنشانی داده‌های نمونه',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await store.resetData();
              if (context.mounted) {
                showSuccessSnack(context, 'داده‌های نمونه بازنشانی شد');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // کارت اصلی وصول شارژ
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'وصول شارژ ${Persian.currentMonthName()}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Persian.toman(store.collectedThisMonth),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'مانده: ${Persian.toman(store.pendingThisMonth)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.accent,
                          ),
                        ),
                        Text(
                          Persian.digits('${(progress * 100).round()}٪'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // آمار کلی
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                StatCard(
                  icon: Icons.apartment_rounded,
                  title: 'واحدهای مسکونی',
                  value:
                      '${Persian.digits(store.occupiedUnits)} از ${Persian.digits(store.totalUnits)}',
                  color: AppColors.primary,
                ),
                StatCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'شارژهای معوقه',
                  value: '${Persian.digits(store.overdueCount)} واحد',
                  color: AppColors.danger,
                ),
                StatCard(
                  icon: Icons.build_rounded,
                  title: 'درخواست‌های باز',
                  value: Persian.digits(store.openRequestsCount),
                  color: AppColors.warning,
                ),
                StatCard(
                  icon: Icons.campaign_rounded,
                  title: 'اعلانات فعال',
                  value: Persian.digits(store.notices.length),
                  color: AppColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // آخرین اعلانات
            const SectionHeader(title: 'آخرین اعلانات'),
            const SizedBox(height: 10),
            ...store.notices.take(3).map(
                  (n) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: n.isImportant
                              ? AppColors.dangerLight
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          n.isImportant
                              ? Icons.priority_high_rounded
                              : Icons.campaign_rounded,
                          size: 20,
                          color: n.isImportant
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                      ),
                      title: Text(
                        n.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        Persian.timeAgo(n.date),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            // درخواست‌های در انتظار
            const SectionHeader(title: 'درخواست‌های نیازمند رسیدگی'),
            const SizedBox(height: 10),
            ...store.requests
                .where((r) => r.status.index == 0)
                .take(3)
                .map(
                  (r) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.build_rounded,
                          size: 20,
                          color: AppColors.warning,
                        ),
                      ),
                      title: Text(
                        r.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'واحد ${Persian.digits(store.unitById(r.unitId)?.number ?? 0)} • ${r.category}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
