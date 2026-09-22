import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../src/theme/palette.dart';

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
  });

  final String title;
  final String description;
  final String scheduleLabel;
  final String cronExpression;
  final String prompt;
  final IconData icon;
  final Color accent;
}

const List<TaskRecommendation> taskRecommendations = <TaskRecommendation>[
  TaskRecommendation(
    title: 'Daily recap',
    description:
        'An evening summary of what happened and what to follow up on.',
    scheduleLabel: 'Every day · 20:00',
    cronExpression: '0 20 * * *',
    prompt:
        'Recap my day: summarize the conversations, finished work and '
        'decisions from today, then list anything I should follow up on '
        'tomorrow. Keep it short and send it to me.',
    icon: Icons.nightlight_round,
    accent: Color(0xFF8B7CF6),
  ),
  TaskRecommendation(
    title: 'Hourly inbox check',
    description: 'Scans new email and only pings you when something matters.',
    scheduleLabel: 'Every hour',
    cronExpression: '0 * * * *',
    prompt:
        'Check my email inbox for messages that arrived since the last check. '
        'Only message me about emails that are urgent or need a reply, with a '
        'one-line summary each. If nothing needs my attention, do not send '
        'anything.',
    icon: Icons.mark_email_unread_rounded,
    accent: Color(0xFF3B82F6),
  ),
  TaskRecommendation(
    title: 'Morning briefing',
    description: 'Weather, calendar and priorities before your day starts.',
    scheduleLabel: 'Weekdays · 07:30',
    cronExpression: '30 7 * * 1-5',
    prompt:
        'Prepare my morning briefing: today\'s weather where I am, the events '
        'on my calendar, and the most important open items I know about. '
        'Send it as a short, scannable message.',
    icon: Icons.wb_sunny_rounded,
    accent: Color(0xFFF59E0B),
  ),
  TaskRecommendation(
    title: 'Tomorrow prep',
    description:
        'Looks ahead at tomorrow\'s meetings so nothing surprises you.',
    scheduleLabel: 'Weekdays · 18:00',
    cronExpression: '0 18 * * 1-5',
    prompt:
        'Look at my calendar for tomorrow. For each meeting, tell me what it '
        'is about, who is involved and anything I should prepare. If tomorrow '
        'is empty, do not send anything.',
    icon: Icons.event_note_rounded,
    accent: Color(0xFF10B981),
  ),
  TaskRecommendation(
    title: 'News digest',
    description: 'Headlines on the topics you care about, filtered for signal.',
    scheduleLabel: 'Every day · 08:00',
    cronExpression: '0 8 * * *',
    prompt:
        'Search the web for today\'s most important news on the topics I care '
        'about (use what you remember about my interests). Send me a digest '
        'of up to five items with one sentence each and a link.',
    icon: Icons.newspaper_rounded,
    accent: Color(0xFFEF4444),
  ),
  TaskRecommendation(
    title: 'Weekly review',
    description: 'A Friday look back at the week and a plan for the next.',
    scheduleLabel: 'Fridays · 17:00',
    cronExpression: '0 17 * * 5',
    prompt:
        'Review my week: what got done, what slipped and what is still open. '
        'Suggest the three most important things to focus on next week.',
    icon: Icons.insights_rounded,
    accent: Color(0xFF14B8A6),
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
  });

  final TaskRecommendation recommendation;
  final TaskRecommendationStatus status;
  final VoidCallback onAdd;

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.geist(
                        color: p.textPrimary,
                        fontSize: 15,
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
          Expanded(
            child: Text(
              recommendation.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.geist(
                color: p.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 10),
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
          Text('Add', style: _labelStyle(accent)),
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
          const Icon(Icons.check_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text('Added', style: _labelStyle(Colors.white)),
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
                'Get inspired',
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
                        'Need an idea?',
                        style: GoogleFonts.geist(
                          color: p.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: p.textMuted),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 14),
                  child: Text(
                    'Pick one to fill in the task. You can tweak everything afterwards.',
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
