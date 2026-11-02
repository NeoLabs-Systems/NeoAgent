import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../../src/mascot/mascot_mood.dart';
import '../../src/theme/palette.dart';
import '../messaging_hub/messaging_hub_widgets.dart';
import '../shared_messaging/shared_messaging_widgets.dart';
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
  final VoidCallback? onBack;
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
        // A routine waiting on an account nobody has connected yet is only
        // noise here; it is offered again on the Tasks page once it can run.
        final recommendations = taskRecommendations
            .where(
              (recommendation) =>
                  _controller.taskRecommendationBlockedReason(recommendation) ==
                      null ||
                  _controller.taskRecommendationStatus(recommendation) ==
                      TaskRecommendationStatus.added,
            )
            .toList(growable: false);
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
            primary: anyAdded
                ? OnboardingPrimaryButton(
                    label: appStrings.onboardingNext,
                    icon: Icons.arrow_forward_rounded,
                    onPressed: widget.onNext,
                  )
                : OnboardingGhostButton(
                    label: appStrings.skipForNow,
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
                HubGroup(
                  children: <Widget>[
                    for (var i = 0; i < recommendations.length; i++)
                      _RoutineRow(
                        recommendation: recommendations[i],
                        status: _controller.taskRecommendationStatus(
                          recommendations[i],
                        ),
                        onChanged: (on) => _toggle(recommendations[i], on),
                      ).animate().fadeIn(
                        duration: 380.ms,
                        delay: (120 + i * 50).ms,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One suggested routine: what it does, when, and a switch. The whole row is
/// the target.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.recommendation,
    required this.status,
    required this.onChanged,
  });

  final TaskRecommendation recommendation;
  final TaskRecommendationStatus status;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final added = status == TaskRecommendationStatus.added;
    final busy = status == TaskRecommendationStatus.adding;
    return InkWell(
      onTap: busy ? null : () => onChanged(!added),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: <Widget>[
            PlatformBadge(
              icon: recommendation.icon,
              color: recommendation.accent,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recommendation.title,
                    style: GoogleFonts.geist(
                      color: p.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recommendation.description,
                    style: GoogleFonts.geist(
                      color: p.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recommendation.scheduleLabel,
                    style: GoogleFonts.geist(color: p.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(value: added, onChanged: busy ? null : onChanged),
          ],
        ),
      ),
    );
  }
}
