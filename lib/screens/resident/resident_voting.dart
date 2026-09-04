import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// ---------------------------------------------------------------------------
/// رأی‌گیری رسمی مجمع عمومی (گام ۴ سند)
///
///   • شمارش ساده  : هر واحد یک رأی
///   • شمارش وزنی  : وزن رأی برابر مساحت سندی واحد (ماده ۷ آیین‌نامه اجرایی)
///
/// حد نصاب قانونی: تصمیم زمانی معتبر است که مالکین بیش از نصف مساحت کل
/// قسمت‌های اختصاصی به آن رأی داده باشند.
/// ---------------------------------------------------------------------------
class ResidentVoting extends StatelessWidget {
  const ResidentVoting({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final polls = store.buildingPolls;

    return Scaffold(
      appBar: AppBar(title: const Text('رأی‌گیری مجمع عمومی')),
      body: SafeArea(
        child: polls.isEmpty
            ? const EmptyState(
                icon: Icons.how_to_vote_outlined,
                message: 'رأی‌گیری فعالی در این ساختمان وجود ندارد',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final p in polls) ...[
                    PollCard(poll: p),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
    );
  }
}

/// کارت یک رأی‌گیری با امکان ثبت رأی و مشاهده نتیجه
class PollCard extends StatelessWidget {
  final Poll poll;

  /// نمایش دکمه‌های مدیریتی (بستن رأی‌گیری)
  final bool managerMode;

  const PollCard({super.key, required this.poll, this.managerMode = false});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final result = store.resultOf(poll.id);
    final myVote = store.myVote(poll.id);
    final canVote = store.canVoteIn(poll);
    final unit = store.currentUnit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- سربرگ ----------
            Row(
              children: [
                Expanded(
                  child: Text(
                    poll.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusChip(
                  label: poll.isOpen ? 'فعال' : poll.status.label,
                  color: poll.isOpen ? AppColors.success : AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(
                  icon: poll.method == VotingMethod.weighted
                      ? Icons.square_foot_rounded
                      : Icons.looks_one_rounded,
                  label: poll.method.label,
                  color: poll.method == VotingMethod.weighted
                      ? AppColors.secondary
                      : AppColors.primary,
                ),
                if (poll.ownersOnly)
                  const _Tag(
                    icon: Icons.key_rounded,
                    label: 'ویژه مالکین',
                    color: AppColors.warning,
                  ),
                _Tag(
                  icon: Icons.event_rounded,
                  label: poll.isOpen
                      ? 'تا ${Persian.digits(poll.daysLeft)} روز دیگر'
                      : 'پایان: ${Persian.shortDate(poll.endsAt)}',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            if (poll.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                poll.description,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
              ),
            ],
            const Divider(height: 24),

            // ---------- گزینه‌ها ----------
            for (final o in poll.options)
              _OptionRow(
                option: o,
                result: result,
                selected: myVote?.optionId == o.id,
                enabled: canVote,
                onTap: canVote
                    ? () async {
                        final ok = await store.castVote(
                            pollId: poll.id, optionId: o.id);
                        if (!context.mounted) return;
                        if (ok) {
                          showSuccessSnack(context, 'رأی شما ثبت شد');
                        }
                      }
                    : null,
              ),

            const SizedBox(height: 12),

            // ---------- توضیح وزن رأی ----------
            if (poll.method == VotingMethod.weighted && unit != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'وزن رأی واحد شما بر مبنای مساحت سند: '
                  '${Persian.digits(unit.area.toStringAsFixed(0))} متر مربع',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.secondary),
                ),
              ),

            const SizedBox(height: 12),

            // ---------- آمار مشارکت ----------
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'مشارکت',
                    value:
                        '${Persian.digits(result.participantUnits)} از ${Persian.digits(result.eligibleUnits)} واحد',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'درصد مشارکت',
                    value:
                        '${Persian.digits((result.participationRate * 100).round())}٪',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: result.participationRate.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.divider,
                color: result.hasLegalQuorum
                    ? AppColors.success
                    : AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),

            // ---------- حد نصاب قانونی ----------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: result.hasLegalQuorum
                    ? AppColors.successLight
                    : AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    result.hasLegalQuorum
                        ? Icons.gavel_rounded
                        : Icons.timelapse_rounded,
                    size: 18,
                    color: result.hasLegalQuorum
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.hasLegalQuorum
                          ? 'حد نصاب قانونی (بیش از نصف مساحت کل) کسب شده است.'
                          : 'هنوز حد نصاب قانونی مجمع کسب نشده است.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                        color: result.hasLegalQuorum
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (myVote != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'رأی شما در ${Persian.shortDate(myVote.castAt)} ثبت شده است',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.success),
                  ),
                ],
              ),
            ] else if (!canVote && poll.isOpen) ...[
              const SizedBox(height: 10),
              Text(
                poll.ownersOnly
                    ? 'این رأی‌گیری ویژه مالکین است و شما به عنوان مستاجر حق رأی ندارید.'
                    : 'امکان ثبت رأی برای شما وجود ندارد.',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],

            if (managerMode && poll.isOpen) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.lock_clock_rounded, size: 18),
                  label: const Text('بستن رأی‌گیری و اعلام نتیجه'),
                  onPressed: () => store.closePoll(poll.id),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final PollOption option;
  final PollResult result;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _OptionRow({
    required this.option,
    required this.result,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final share = result.shareOf(option.id);
    final weight = result.tally[option.id] ?? 0;
    final isWinner = result.winningOptionId == option.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (isWinner ? AppColors.success : AppColors.divider),
              width: selected || isWinner ? 1.3 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: selected
                        ? AppColors.primary
                        : (enabled
                            ? AppColors.textSecondary
                            : AppColors.divider),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${Persian.digits((share * 100).round())}٪',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isWinner
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: AppColors.divider,
                  color: isWinner ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  result.poll.method == VotingMethod.weighted
                      ? '${Persian.digits(weight.toStringAsFixed(0))} متر مربع'
                      : '${Persian.digits(weight.toStringAsFixed(0))} رأی',
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10.5, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
