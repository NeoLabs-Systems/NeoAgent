import 'package:flutter/material.dart';

import '../../main.dart';
import '../../src/mascot/mascot_mood.dart';
import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class OnboardingModelStep extends StatefulWidget {
  const OnboardingModelStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.controller,
  });

  final VoidCallback onNext;
  final VoidCallback onBack;
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
        return OnboardingScaffold(
          mood: MascotMood.thinking,
          fill: models.isNotEmpty,
          eyebrow: appStrings.onboardingEyebrowIntelligence,
          title: appStrings.chooseYourDefaultModel,
          description: appStrings.onboardingModelDescription,
          footer: OnboardingFooter(
            onBack: widget.onBack,
            primary: OnboardingPrimaryButton(
              label: appStrings.continue2,
              icon: Icons.arrow_forward_rounded,
              onPressed: _saving || loading ? null : () => _continue(models),
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
              : models.isEmpty
              ? _NoModelsPanel(controller: _controller)
              : ModelPickerPanel(
                  models: models,
                  value: _selection(models),
                  allowAuto: true,
                  onChanged: (id) => setState(() => _pickedModel = id),
                ),
        );
      },
    );
  }
}

/// Shown when no model can be used yet: the person adds a provider key right
/// here, and the catalog refresh that follows a saved key fills the list.
class _NoModelsPanel extends StatelessWidget {
  const _NoModelsPanel({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            appStrings.noAiModelTitle,
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            appStrings.noAiModelBody,
            style: TextStyle(color: p.textSecondary, height: 1.5),
          ),
          if (controller.isAdmin) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              appStrings.noAiModelAdminHint,
              style: TextStyle(color: p.textMuted, height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          ByokSettingsCard(controller: controller),
        ],
      ),
    );
  }
}
