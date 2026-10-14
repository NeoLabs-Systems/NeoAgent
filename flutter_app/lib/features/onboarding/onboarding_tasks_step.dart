import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../../src/mascot/mascot_mood.dart';
import '../../src/theme/palette.dart';
import '../tasks/task_recommendations.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class OnboardingTasksStep extends StatefulWidget {
  const OnboardingTasksStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.controller,
  });

  final VoidCallback onNext;
  final VoidCallback onBack;
  final NeoAgentController controller;

  @override
  State<OnboardingTasksStep> createState() => _OnboardingTasksStepState();
}

class _OnboardingTasksStepState extends State<OnboardingTasksStep> {
  /// Phones get routine results as notifications, which they must allow.
  static bool get _isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _notificationsRequested = false;

  NeoAgentController get _controller => widget.controller;

  Future<void> _toggle(TaskRecommendation recommendation, bool on) async {
    try {
      if (on) {
        await _controller.addRecommendedTask(recommendation);
      } else {
        await _controller.removeRecommendedTask(recommendation);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.friendlyErrorMessage(error))),
      );
    }
  }

  Future<void> _requestNotifications() async {
    await _controller.requestNotificationPermission();
    if (mounted) setState(() => _notificationsRequested = true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final p = paletteOf(context);
        final recommendations = taskRecommendations;
        final anyAdded = recommendations.any(
          (recommendation) =>
              _controller.taskRecommendationStatus(recommendation) ==
              TaskRecommendationStatus.added,
        );
        return OnboardingScaffold(
          mood: MascotMood.asleep,
          eyebrow: appStrings.onboardingEyebrowAutomation,
          title: appStrings.letItWorkWhileYouDon,
          description: _isPhone
              ? appStrings.onboardingRoutinesDescriptionPhone
              : appStrings.onboardingRoutinesDescription,
          footer: OnboardingFooter(
            onBack: widget.onBack,
            secondary: <Widget>[
              if (!anyAdded)
                OnboardingGhostButton(
                  label: appStrings.skipForNow,
                  onPressed: widget.onNext,
                ),
            ],
            primary: OnboardingPrimaryButton(
              label: appStrings.continue2,
              icon: Icons.arrow_forward_rounded,
              onPressed: widget.onNext,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_isPhone && !_notificationsRequested) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.notifications_none_rounded,
                          color: p.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            appStrings.onboardingNotifications,
                            style: GoogleFonts.geist(
                              color: p.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _requestNotifications,
                          child: Text(appStrings.allow),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      for (var i = 0; i < recommendations.length; i++)
                        _RoutineRow(
                          recommendation: recommendations[i],
                          status: _controller.taskRecommendationStatus(
                            recommendations[i],
                          ),
                          blockedReason: _controller
                              .taskRecommendationBlockedReason(
                                recommendations[i],
                              ),
                          divider: i > 0,
                          onChanged: (on) => _toggle(recommendations[i], on),
                        ).animate().fadeIn(
                          duration: 380.ms,
                          delay: (160 + i * 60).ms,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One suggested routine with its schedule and an on/off switch. A routine
/// that cannot run yet shows why instead of the switch.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.recommendation,
    required this.status,
    required this.blockedReason,
    required this.divider,
    required this.onChanged,
  });

  final TaskRecommendation recommendation;
  final TaskRecommendationStatus status;
  final String? blockedReason;
  final bool divider;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final added = status == TaskRecommendationStatus.added;
    final blocked = blockedReason != null && !added;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: p.border)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recommendation.title,
                    style: GoogleFonts.geist(
                      color: blocked ? p.textMuted : p.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (blocked ? blockedReason! : recommendation.scheduleLabel)
                        .toUpperCase(),
                    style: GoogleFonts.geistMono(
                      color: p.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: added,
              onChanged: blocked || status == TaskRecommendationStatus.adding
                  ? null
                  : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
