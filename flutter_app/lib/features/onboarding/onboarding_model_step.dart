import 'package:flutter/material.dart';

import '../../main.dart';
import '../../src/mascot/mascot_mood.dart';
import '../../src/theme/palette.dart';
import '../messaging_hub/messaging_hub_widgets.dart';
import '../shared_messaging/shared_messaging_widgets.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

/// Only reached when no AI model works yet: a server with a provider already
/// never asks. One button connects one; the rest is for those who want it.
class OnboardingModelStep extends StatefulWidget {
  const OnboardingModelStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.controller,
  });

  final VoidCallback onNext;
  final VoidCallback? onBack;
  final NeoAgentController controller;

  @override
  State<OnboardingModelStep> createState() => _OnboardingModelStepState();
}

class _OnboardingModelStepState extends State<OnboardingModelStep> {
  static const String _autoModelId = 'auto';

  /// What the person picked here; null until they pick, so the highlight
  /// follows the saved default as the catalog loads.
  String? _pickedModel;
  bool _saving = false;

  NeoAgentController get _controller => widget.controller;

  List<ModelMeta> get _models => _controller.supportedModels
      .where((m) => m.available && !m.id.startsWith('tool:'))
      .toList();

  /// The highlighted choice, recomputed whenever the model list changes.
  String _selection(List<ModelMeta> models) {
    bool listed(String? id) =>
        id == _autoModelId || models.any((model) => model.id == id);
    if (listed(_pickedModel)) return _pickedModel!;
    final saved = _controller.defaultChatModel;
    return listed(saved) ? saved : _autoModelId;
  }

  Future<void> _continue(List<ModelMeta> models) async {
    final selection = _selection(models);
    if (models.isEmpty || selection == _controller.defaultChatModel) {
      widget.onNext();
      return;
    }
    setState(() => _saving = true);
    try {
      await _controller.saveSettingsPayload(<String, Object?>{
        'default_chat_model': selection,
      });
      if (!mounted) return;
      widget.onNext();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appStrings.failedToSaveSelectionArg1(
              _controller.friendlyErrorMessage(error),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final models = _models;
        final loading =
            models.isEmpty &&
            (_controller.isRefreshing || !_controller.hasLoadedInitialData);
        final ready = models.isNotEmpty;
        return OnboardingScaffold(
          mood: ready ? MascotMood.done : MascotMood.thinking,
          eyebrow: appStrings.onboardingEyebrowIntelligence,
          title: appStrings.onboardingModelTitle,
          description: ready
              ? appStrings.onboardingModelDescription
              : '${appStrings.onboardingModelNeededDescription} ${appStrings.uxModelSkipHint}',

          footer: OnboardingFooter(
            onBack: widget.onBack,
            primary: ready
                ? OnboardingPrimaryButton(
                    label: appStrings.onboardingNext,
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _saving ? null : () => _continue(models),
                  )
                : OnboardingGhostButton(
                    label: appStrings.skipForNow,
                    onPressed: loading ? null : widget.onNext,
                  ),
          ),
          child: loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        appStrings.onboardingLoadingModels,
                        style: TextStyle(color: paletteOf(context).textMuted),
                      ),
                    ],
                  ),
                )
              : ready
              ? _ModelReadyPanel(
                  models: models,
                  value: _selection(models),
                  onChanged: (id) => setState(() => _pickedModel = id),
                )
              : _ConnectModelPanel(controller: _controller),
        );
      },
    );
  }
}

/// A model just arrived. Automatic is the right answer for nearly everyone, so
/// picking a specific one waits behind a heading.
class _ModelReadyPanel extends StatelessWidget {
  const _ModelReadyPanel({
    required this.models,
    required this.value,
    required this.onChanged,
  });

  final List<ModelMeta> models;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InlineNotice(
            tone: NoticeTone.success,
            message: appStrings.onboardingModelReady,
          ),
          const SizedBox(height: 8),
          HubDisclosure(
            title: appStrings.onboardingModelChoose,
            child: SizedBox(
              height: 320,
              child: ModelPickerPanel(
                models: models,
                value: value,
                allowAuto: true,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// No model works yet: sign in with one button, or add a provider key.
class _ConnectModelPanel extends StatelessWidget {
  const _ConnectModelPanel({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final canSignIn = controller.byokProviders.any(
      (provider) =>
          provider['signInAvailable'] == true && provider['configured'] != true,
    );
    final keys = ByokSettingsCard(controller: controller, showSignIn: false);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ProviderSignInCard(controller: controller),
          if (canSignIn) ...<Widget>[
            const SizedBox(height: 8),
            HubDisclosure(title: appStrings.onboardingModelUseKey, child: keys),
          ] else
            keys,
          if (controller.isAdmin) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              appStrings.noAiModelAdminHint,
              style: TextStyle(
                color: paletteOf(context).textMuted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
