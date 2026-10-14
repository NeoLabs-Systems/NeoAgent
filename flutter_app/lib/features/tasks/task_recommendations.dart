import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../src/theme/palette.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

/// What a recommendation needs before it can do anything useful.
enum TaskRequirement { email, calendar }

/// A ready-made scheduled task offered to users who have none yet.
class TaskRecommendation {
  const TaskRecommendation({
    required this.title,
    required this.description,
    required this.scheduleLabel,
    required this.cronExpression,
    required this.prompt,
    required this.icon,
    required this.accent,
    this.requirement,
  });

  final String title;
  final String description;
  final String scheduleLabel;
  final String cronExpression;
  final String prompt;
  final IconData icon;
  final Color accent;
  final TaskRequirement? requirement;
}

/// Built on each read so the texts follow the current app language.
List<TaskRecommendation> get taskRecommendations => <TaskRecommendation>[
  TaskRecommendation(
    title: appStrings.dailyRecap,
    description: appStrings.anEveningSummaryOfWhatHappened,
    scheduleLabel: appStrings.everyDay2000,
    cronExpression: '0 20 * * *',
    prompt: appStrings.taskPromptDailyRecap,
    icon: Icons.nightlight_round,
    accent: const Color(0xFF8B7CF6),
  ),
  TaskRecommendation(
    title: appStrings.hourlyInboxCheck,
    description: appStrings.scansNewEmailAndOnlyPings,
    scheduleLabel: appStrings.everyHour,
    cronExpression: '0 * * * *',
    prompt: appStrings.taskPromptInboxCheck,
    icon: Icons.mark_email_unread_rounded,
    accent: const Color(0xFF3B82F6),
    requirement: TaskRequirement.email,
  ),
  TaskRecommendation(
    title: appStrings.morningBriefing,
    description: appStrings.weatherCalendarAndPrioritiesBeforeYour,
    scheduleLabel: appStrings.weekdays0730,
    cronExpression: '30 7 * * 1-5',
    prompt: appStrings.taskPromptMorningBriefing,
    icon: Icons.wb_sunny_rounded,
    accent: const Color(0xFFF59E0B),
  ),
  TaskRecommendation(
    title: appStrings.tomorrowPrep,
    description: appStrings.looksAheadAtTomorrowSMeetings,
    scheduleLabel: appStrings.weekdays1800,
    cronExpression: '0 18 * * 1-5',
    prompt: appStrings.taskPromptTomorrowPrep,
    icon: Icons.event_note_rounded,
    accent: const Color(0xFF10B981),
    requirement: TaskRequirement.calendar,
  ),
  TaskRecommendation(
    title: appStrings.newsDigest,
    description: appStrings.headlinesOnTheTopicsYouCare,
    scheduleLabel: appStrings.everyDay0800,
    cronExpression: '0 8 * * *',
    prompt: appStrings.taskPromptNewsDigest,
    icon: Icons.newspaper_rounded,
    accent: const Color(0xFFEF4444),
  ),
  TaskRecommendation(
    title: appStrings.weeklyReview,
    description: appStrings.aFridayLookBackAtThe,
    scheduleLabel: appStrings.fridays1700,
    cronExpression: '0 17 * * 5',
    prompt: appStrings.taskPromptWeeklyReview,
    icon: Icons.insights_rounded,
    accent: const Color(0xFF14B8A6),
  ),
];

enum TaskRecommendationStatus { idle, adding, added }

/// Card for one [TaskRecommendation] with a one-click add button.
class TaskRecommendationCard extends StatelessWidget {
  const TaskRecommendationCard({
    super.key,
    required this.recommendation,
    required this.status,
    required this.onAdd,
    this.blockedReason,
  });

  final TaskRecommendation recommendation;
  final TaskRecommendationStatus status;
  final VoidCallback onAdd;

  /// Why this task cannot be added yet, such as a missing email connection.
  /// The card shows it in place of the add button.
  final String? blockedReason;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final accent = recommendation.accent;
    final added = status == TaskRecommendationStatus.added;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: added ? accent.withValues(alpha: 0.08) : p.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: added ? accent.withValues(alpha: 0.7) : p.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(recommendation.icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recommendation.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.geist(
                        color: p.textPrimary,
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recommendation.scheduleLabel.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.geistMono(
                        color: p.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            recommendation.description,
            style: GoogleFonts.geist(
              color: p.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          if (blockedReason != null && !added)
            Row(
              children: <Widget>[
                Icon(Icons.link_off_rounded, size: 16, color: p.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    blockedReason!,
                    style: GoogleFonts.geist(
                      color: p.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: _AddButton(status: status, accent: accent, onAdd: onAdd),
            ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.status,
    required this.accent,
    required this.onAdd,
  });

  final TaskRecommendationStatus status;
  final Color accent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (status) {
      TaskRecommendationStatus.idle => Row(
        key: const ValueKey<String>('idle'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.add_rounded, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(appStrings.add, style: _labelStyle(accent)),
        ],
      ),
      TaskRecommendationStatus.adding => SizedBox(
        key: const ValueKey<String>('adding'),
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: accent),
      ),
      TaskRecommendationStatus.added => Row(
        key: const ValueKey<String>('added'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(appStrings.added, style: _labelStyle(Colors.white)),
        ],
      ),
    };
    final added = status == TaskRecommendationStatus.added;
    return Material(
      color: added ? accent : accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: status == TaskRecommendationStatus.idle ? onAdd : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: content,
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(Color color) {
    return GoogleFonts.geist(
      color: color,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );
  }
}

/// Small pill that opens the inspiration picker for an empty task form.
class TaskInspirationButton extends StatelessWidget {
  const TaskInspirationButton({super.key, required this.onPicked});

  final ValueChanged<TaskRecommendation> onPicked;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Material(
      color: p.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          final picked = await showTaskInspirationPicker(context);
          if (picked != null) onPicked(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, size: 14, color: p.accent),
              const SizedBox(width: 6),
              Text(
                appStrings.getInspired,
                style: GoogleFonts.geist(
                  color: p.accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the user pick one of [taskRecommendations] to prefill a task.
Future<TaskRecommendation?> showTaskInspirationPicker(BuildContext context) {
  return showDialog<TaskRecommendation>(
    context: context,
    builder: (context) {
      final p = paletteOf(context);
      return Dialog(
        backgroundColor: p.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.auto_awesome_rounded, color: p.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        appStrings.needAnIdea,
                        style: GoogleFonts.geist(
                          color: p.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: appStrings.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: p.textMuted),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 14),
                  child: Text(
                    appStrings.pickOneToFillInThe,
                    style: GoogleFonts.geist(
                      color: p.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: taskRecommendations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final recommendation = taskRecommendations[index];
                      return _InspirationTile(
                        recommendation: recommendation,
                        onTap: () => Navigator.of(context).pop(recommendation),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _InspirationTile extends StatefulWidget {
  const _InspirationTile({required this.recommendation, required this.onTap});

  final TaskRecommendation recommendation;
  final VoidCallback onTap;

  @override
  State<_InspirationTile> createState() => _InspirationTileState();
}

class _InspirationTileState extends State<_InspirationTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final recommendation = widget.recommendation;
    final accent = recommendation.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _hovered ? accent.withValues(alpha: 0.07) : p.bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? accent.withValues(alpha: 0.6) : p.borderLight,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(recommendation.icon, color: accent, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                recommendation.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.geist(
                                  color: p.textPrimary,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              recommendation.scheduleLabel.toUpperCase(),
                              maxLines: 1,
                              style: GoogleFonts.geistMono(
                                color: p.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          recommendation.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.geist(
                            color: p.textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _hovered ? 1 : 0.35,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: _hovered ? accent : p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
