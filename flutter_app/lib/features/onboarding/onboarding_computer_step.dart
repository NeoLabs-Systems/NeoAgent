import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../../src/mascot/mascot_mood.dart';
import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

/// Where NeoAgent does its work by default. Only shown in the desktop app,
/// the one place that can offer this computer as well as the cloud one.
class OnboardingComputerStep extends StatefulWidget {
  const OnboardingComputerStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.controller,
  });

  final VoidCallback onNext;
  final VoidCallback onBack;
  final NeoAgentController controller;

  @override
  State<OnboardingComputerStep> createState() => _OnboardingComputerStepState();
}

class _OnboardingComputerStepState extends State<OnboardingComputerStep> {
  /// What the person picked here; null follows the saved provider.
  String? _picked;

  NeoAgentController get _controller => widget.controller;

  String get _selection => _picked ?? _controller.computerProvider;

  Future<void> _continue() async {
    if (_selection != _controller.computerProvider) {
      await _controller.selectComputerProvider(_selection);
      if (!mounted) return;
      final error = _controller.errorMessage;
      if (_selection != _controller.computerProvider && error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selection = _selection;
        final cloudUnavailable = _controller.computerRuntimeAvailable == false;
        return OnboardingScaffold(
          mood: MascotMood.working,
          eyebrow: appStrings.onboardingEyebrowComputer,
          title: appStrings.onboardingComputerChoiceTitle,
          description: appStrings.onboardingComputerChoiceDescription,
          footer: OnboardingFooter(
            onBack: widget.onBack,
            primary: OnboardingPrimaryButton(
              label: appStrings.continue2,
              icon: Icons.arrow_forward_rounded,
              onPressed: _controller.isRunningDeviceAction ? null : _continue,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _PlaceCard(
                  icon: Icons.cloud_outlined,
                  title: appStrings.cloudComputer,
                  subtitle: cloudUnavailable
                      ? appStrings.notSetUp
                      : appStrings.onboardingCloudComputerSubtitle,
                  selected: selection == 'cloud',
                  onTap: () => setState(() => _picked = 'cloud'),
                ).animate().fadeIn(duration: 420.ms, delay: 180.ms),
                const SizedBox(height: 12),
                _PlaceCard(
                  icon: Icons.laptop_rounded,
                  title: appStrings.onboardingThisComputer,
                  subtitle: appStrings.onboardingThisComputerSubtitle,
                  selected: selection == 'local',
                  onTap: () => setState(() => _picked = 'local'),
                ).animate().fadeIn(duration: 420.ms, delay: 250.ms),
                if (selection == 'local') ...<Widget>[
                  const SizedBox(height: 18),
                  _LocalPermissions(controller: _controller),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: OnboardingOptionCard(
        selected: selected,
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? p.accent.withValues(alpha: 0.14)
                    : p.textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? p.accent : p.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.geist(
                      color: p.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle.toUpperCase(),
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
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? p.accent : p.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// What NeoAgent may do on this computer, granted right here so the first
/// local session does not stop to ask.
class _LocalPermissions extends StatelessWidget {
  const _LocalPermissions({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final granted = controller.localComputerPermissions;
    final permissions = <({String key, String label})>[
      (key: 'screen', label: appStrings.screen),
      (key: 'input', label: appStrings.mouseKeyboard),
      (key: 'files', label: appStrings.workspaceFiles),
      (key: 'shell', label: appStrings.commandsApps),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < permissions.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: p.border)),
              ),
              child: SwitchListTile(
                value: granted.contains(permissions[i].key),
                onChanged: (on) => on
                    ? controller.grantLocalComputerPermission(
                        permissions[i].key,
                        remember: true,
                      )
                    : controller.revokeLocalComputerPermission(
                        permissions[i].key,
                      ),
                title: Text(
                  permissions[i].label,
                  style: GoogleFonts.geist(
                    color: p.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
