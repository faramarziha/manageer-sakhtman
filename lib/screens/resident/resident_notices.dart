import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// مشاهده اعلانات برای ساکن
class ResidentNoticesPage extends StatelessWidget {
  const ResidentNoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('اعلانات ساختمان')),
      body: SafeArea(
        child: store.buildingNotices.isEmpty
            ? const EmptyState(
                icon: Icons.campaign_outlined,
                message: 'اعلانی برای نمایش وجود ندارد',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: store.buildingNotices.length,
                itemBuilder: (ctx, i) {
                  final n = store.buildingNotices[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              n.body,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.8,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
