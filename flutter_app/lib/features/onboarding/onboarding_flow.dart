/// Every page onboarding can show, in order. Stored by index to resume, so new
/// pages go at the end of what they follow rather than renumbering old ones.
enum OnboardingPage { intro, model, computer, messaging, routines, ready }

/// The pages this person actually needs: nobody is asked for what is already
/// settled or shown a page where nothing can be done yet.
List<OnboardingPage> onboardingPages({
  required bool needsModelStep,
  required bool hasComputerChoice,
  required bool hasRoutines,
}) {
  return <OnboardingPage>[
    OnboardingPage.intro,
    if (needsModelStep) OnboardingPage.model,
    if (hasComputerChoice) OnboardingPage.computer,
    OnboardingPage.messaging,
    if (hasRoutines) OnboardingPage.routines,
    OnboardingPage.ready,
  ];
}

/// Where to reopen: the remembered page, or the next one still in the flow if
/// that page has since dropped out.
OnboardingPage resumeOnboardingPage(List<OnboardingPage> pages, int stored) {
  final index = stored.clamp(0, OnboardingPage.values.length - 1);
  return pages.firstWhere(
    (page) => page.index >= index,
    orElse: () => OnboardingPage.ready,
  );
}
