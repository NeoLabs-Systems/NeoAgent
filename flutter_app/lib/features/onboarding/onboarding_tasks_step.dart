import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../main.dart';
import '../tasks/task_recommendations.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class OnboardingTasksStep extends StatelessWidget {
  const OnboardingTasksStep({
    super.key,
    required this.onNext,
    required this.controller,
  });

  final VoidCallback onNext;
  final NeoAgentController controller;

  Future<void> _add(
    BuildContext context,
    TaskRecommendation recommendation,
  ) async {
    try {
      await controller.addRecommendedTask(recommendation);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.friendlyErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final anyAdded = taskRecommendations.any(
          (recommendation) =>
              controller.taskRecommendationStatus(recommendation) ==
              TaskRecommendationStatus.added,
        );
        return OnboardingScaffold(
          step: 4,
          totalSteps: 5,
          eyebrow: 'AUTOMATION',
          title: appStrings.letItWorkWhileYouDon,
          description:
              appStrings.tasksRunOnAScheduleOr +
              appStrings.messageYouWithTheResultAdd +
              appStrings.findTheseLaterInTasks,
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (anyAdded)
                const SizedBox.shrink()
              else
                OnboardingGhostButton(label: appStrings.skipForNow, onPressed: onNext),
              OnboardingPrimaryButton(
                label: appStrings.finishSetup,
                icon: Icons.check_rounded,
                onPressed: onNext,
              ),
            ],
          ),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 178,
            ),
            itemCount: taskRecommendations.length,
            itemBuilder: (context, index) {
              final recommendation = taskRecommendations[index];
              return TaskRecommendationCard(
                    recommendation: recommendation,
                    status: controller.taskRecommendationStatus(recommendation),
                    onAdd: () => _add(context, recommendation),
                  )
                  .animate()
                  .fadeIn(duration: 420.ms, delay: (180 + index * 70).ms)
                  .slideY(begin: 0.16, end: 0);
            },
          ),
        );
      },
    );
  }
}
