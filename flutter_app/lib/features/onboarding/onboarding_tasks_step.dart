import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../main.dart';
import '../tasks/task_recommendations.dart';
import 'onboarding_chrome.dart';

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
          title: 'Let it work\nwhile you don\'t.',
          description:
              'Tasks run on a schedule or when something happens, then '
              'message you with the result. Add one to start, or skip and '
              'find these later in Tasks.',
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (anyAdded)
                const SizedBox.shrink()
              else
                OnboardingGhostButton(label: 'Skip for now', onPressed: onNext),
              OnboardingPrimaryButton(
                label: 'Finish setup',
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
