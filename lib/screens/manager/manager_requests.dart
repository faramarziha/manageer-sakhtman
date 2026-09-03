import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// مدیریت درخواست‌های تعمیرات (مدیر)
class ManagerRequestsPage extends StatefulWidget {
  const ManagerRequestsPage({super.key});

  @override
  State<ManagerRequestsPage> createState() => _ManagerRequestsPageState();
}

class _ManagerRequestsPageState extends State<ManagerRequestsPage> {
  RequestStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var list = [...store.buildingRequests]..sort((a, b) => b.date.compareTo(a.date));
    if (_filter != null) {
      list = list.where((r) => r.status == _filter).toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('درخواست‌های تعمیرات')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _chip('همه', null),
                  _chip('در انتظار', RequestStatus.pending),
                  _chip('در حال انجام', RequestStatus.inProgress),
                  _chip('انجام شده', RequestStatus.done),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.build_outlined,
                      message: 'درخواستی یافت نشد',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) => _RequestCard(request: list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, RequestStatus? status) {
    final selected = _filter == status;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = status),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.divider),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final MaintenanceRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.unitById(request.unitId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                StatusChip(
                  label: request.status.label,
                  color: _color(request.status),
                  bgColor: _bg(request.status),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              request.description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.apartment, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'واحد ${Persian.digits(unit?.number ?? 0)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Icon(Icons.category_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  request.category,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  Persian.timeAgo(request.date),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (request.status != RequestStatus.done) ...[
              const Divider(height: 20),
              Row(
                children: [
                  if (request.status == RequestStatus.pending)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await store.setRequestStatus(
                              request.id, RequestStatus.inProgress);
                          if (context.mounted) {
                            showSuccessSnack(
                                context, 'درخواست به «در حال انجام» تغییر یافت');
                          }
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('شروع انجام'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  if (request.status == RequestStatus.pending)
                    const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await store.setRequestStatus(
                            request.id, RequestStatus.done);
                        if (context.mounted) {
                          showSuccessSnack(
                              context, 'درخواست به «انجام شده» تغییر یافت');
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('اتمام کار'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _color(RequestStatus s) => switch (s) {
        RequestStatus.pending => AppColors.warning,
        RequestStatus.inProgress => AppColors.primary,
        RequestStatus.done => AppColors.success,
      };

  Color _bg(RequestStatus s) => switch (s) {
        RequestStatus.pending => AppColors.warningLight,
        RequestStatus.inProgress => AppColors.primaryLight,
        RequestStatus.done => AppColors.successLight,
      };
}
