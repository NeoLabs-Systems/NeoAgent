import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../main.dart';
import '../../src/mascot/mascot_mood.dart';
import '../../src/theme/palette.dart';
import '../messaging_hub/messaging_hub_models.dart';
import '../tasks/task_recommendations.dart';
import 'onboarding_chrome.dart';
import 'onboarding_recap.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

/// The last step: a first message that opens the normal chat and sends it.
class OnboardingReadyStep extends StatefulWidget {
  const OnboardingReadyStep({
    super.key,
    required this.onFinish,
    required this.onBack,
    required this.controller,
  });

  /// Completes setup and opens the chat with the message, which may be empty.
  final Future<void> Function(String message) onFinish;
  final VoidCallback? onBack;
  final NeoAgentController controller;

  @override
  State<OnboardingReadyStep> createState() => _OnboardingReadyStepState();
}

class _OnboardingReadyStepState extends State<OnboardingReadyStep> {
  final TextEditingController _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _finish() => widget.onFinish(_message.text.trim());

  /// Starters fill the box rather than send, like the chat's own starters,
  /// so the person can still edit before sending.
  void _useStarter(String prompt) {
    _message.text = prompt;
    _message.selection = TextSelection.collapsed(offset: prompt.length);
  }

  /// What this person actually has now, and what can still wait.
  List<OnboardingRecapItem> _recap(BuildContext context) {
    final controller = widget.controller;
    final connected = messagingHubApps(context, controller)
        .where((app) => app.state == HubAppState.live)
        .map((app) => app.label)
        .toList(growable: false);
    final routines = taskRecommendations
        .where(
          (recommendation) =>
              controller.taskRecommendationStatus(recommendation) ==
              TaskRecommendationStatus.added,
        )
        .length;
    return <OnboardingRecapItem>[
      OnboardingRecapItem(
        icon: Icons.psychology_outlined,
        done: controller.hasUsableChatModel,
        label: controller.hasUsableChatModel
            ? appStrings.onboardingRecapModel
            : appStrings.onboardingRecapNoModel,
      ),
      OnboardingRecapItem(
        icon: Icons.forum_outlined,
        done: connected.isNotEmpty,
        label: connected.isNotEmpty
            ? appStrings.onboardingRecapMessaging(connected.join(', '))
            : appStrings.onboardingRecapNoMessaging,
      ),
      if (routines > 0)
        OnboardingRecapItem(
          icon: Icons.schedule_rounded,
          done: true,
          label: appStrings.onboardingRecapRoutines(routines),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final p = paletteOf(context);
        final canChat = widget.controller.hasUsableChatModel;
        final finishing = widget.controller.isCompletingOnboarding;
        final finishError = widget.controller.onboardingCompletionError;
        final starters = <String>[
          appStrings.whatIsOnTomorrow,
          appStrings.onboardingStarterTrip,
          appStrings.onboardingStarterLanding,
        ];
        return OnboardingScaffold(
          mood: canChat ? MascotMood.done : MascotMood.waiting,
          eyebrow: appStrings.onboardingEyebrowReady,
          title: canChat
              ? appStrings.onboardingReadyTitle
              : appStrings.onboardingAlmostTitle,
          description: canChat
              ? appStrings.onboardingReadyDescription
              : appStrings.onboardingAlmostDescription,
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (finishError != null) ...<Widget>[
                _FinishError(message: finishError),
                const SizedBox(height: 12),
              ],
              OnboardingFooter(
                onBack: finishing ? null : widget.onBack,
                primary: OnboardingPrimaryButton(
                  label: finishError != null
                      ? appStrings.retry
                      : appStrings.onboardingOpenNeoagent,
                  icon: finishError != null
                      ? Icons.refresh_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: finishing ? null : _finish,
                ),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                OnboardingRecap(
                  items: _recap(context),
                ).animate().fadeIn(duration: 420.ms, delay: 100.ms),
                // A first message needs a model to answer it.
                if (canChat) ...<Widget>[
                  const SizedBox(height: 18),
                  TextField(
                    controller: _message,
                    enabled: !finishing,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _finish(),
                    decoration: InputDecoration(
                      labelText: appStrings.onboardingMessageNeoagent,
                      hintText: appStrings.onboardingAskAnything,
                      suffixIcon: IconButton(
                        tooltip: appStrings.send,
                        onPressed: finishing ? null : _finish,
                        icon: Icon(Icons.arrow_upward_rounded, color: p.accent),
                      ),
                    ),
                  ).animate().fadeIn(duration: 420.ms, delay: 180.ms),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final starter in starters)
                        ActionChip(
                          label: Text(starter),
                          onPressed: finishing
                              ? null
                              : () => _useStarter(starter),
                        ),
                    ],
                  ).animate().fadeIn(duration: 420.ms, delay: 260.ms),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FinishError extends StatelessWidget {
  const _FinishError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: p.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appStrings.onboardingFinishFailed(message),
              style: TextStyle(color: p.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
