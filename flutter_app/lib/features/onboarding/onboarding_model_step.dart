import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../main.dart';
import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';

class OnboardingModelStep extends StatefulWidget {
  const OnboardingModelStep({
    super.key,
    required this.onNext,
    required this.controller,
  });

  final VoidCallback onNext;
  final NeoAgentController controller;

  @override
  State<OnboardingModelStep> createState() => _OnboardingModelStepState();
}

class _OnboardingModelStepState extends State<OnboardingModelStep> {
  String? _selectedModel;

  List<ModelMeta> get _models => widget.controller.supportedModels
      .where((m) => m.available && !m.id.startsWith('tool:'))
      .toList();

  @override
  void initState() {
    super.initState();
    final defaultChatModel = widget.controller.defaultChatModel;
    if (defaultChatModel.isNotEmpty &&
        _models.any((m) => m.id == defaultChatModel)) {
      _selectedModel = defaultChatModel;
    } else if (_models.isNotEmpty) {
      _selectedModel = _models.first.id;
    }
  }

  Color _getColorForModel(ModelMeta model) {
    final value = model.provider.toLowerCase() + model.id.toLowerCase();
    if (value.contains('google') || value.contains('gemini')) {
      return const Color(0xFF4285F4);
    }
    if (value.contains('openai') || value.contains('gpt')) {
      return const Color(0xFF10A37F);
    }
    if (value.contains('anthropic') || value.contains('claude')) {
      return const Color(0xFFD97757);
    }
    if (value.contains('meta') || value.contains('llama')) {
      return const Color(0xFF0668E1);
    }
    if (value.contains('mistral')) return const Color(0xFFF97316);
    return const Color(0xFF7C8CFF);
  }

  IconData _getIconForModel(ModelMeta model) {
    final value = model.provider.toLowerCase() + model.id.toLowerCase();
    if (value.contains('google') || value.contains('gemini')) {
      return Icons.auto_awesome_rounded;
    }
    if (value.contains('openai') || value.contains('gpt')) {
      return Icons.bolt_rounded;
    }
    if (value.contains('anthropic') || value.contains('claude')) {
      return Icons.menu_book_rounded;
    }
    if (value.contains('meta') || value.contains('llama')) {
      return Icons.visibility_rounded;
    }
    return Icons.memory_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useGrid = width >= 720;

    return OnboardingScaffold(
      step: 3,
      totalSteps: 4,
      eyebrow: 'INTELLIGENCE',
      title: 'Choose your\ndefault model.',
      description: 'Pick the model NeoAgent should use by default.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          OnboardingPrimaryButton(
            label: 'Finish setup',
            icon: Icons.check_rounded,
            onPressed: widget.onNext,
          ),
        ],
      ),
      child: _models.isEmpty
          ? Center(
              child: Text(
                'No available models found.\nYou can configure providers later in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: paletteOf(context).textMuted,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            )
          : useGrid
          ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 214,
              ),
              itemCount: _models.length,
              itemBuilder: (context, index) {
                final model = _models[index];
                return _ModelChoiceCard(
                      model: model,
                      color: _getColorForModel(model),
                      icon: _getIconForModel(model),
                      selected: _selectedModel == model.id,
                      compact: true,
                      onTap: () => _selectModel(context, model),
                    )
                    .animate()
                    .fadeIn(
                      duration: 420.ms,
                      delay: (180 + (index.clamp(0, 5) * 70)).ms,
                    )
                    .slideY(begin: 0.16, end: 0);
              },
            )
          : ListView.separated(
              itemCount: _models.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final model = _models[index];
                return _ModelChoiceCard(
                      model: model,
                      color: _getColorForModel(model),
                      icon: _getIconForModel(model),
                      selected: _selectedModel == model.id,
                      onTap: () => _selectModel(context, model),
                    )
                    .animate()
                    .fadeIn(
                      duration: 420.ms,
                      delay: (180 + (index.clamp(0, 5) * 70)).ms,
                    )
                    .slideY(begin: 0.16, end: 0);
              },
            ),
    );
  }

  Future<void> _selectModel(BuildContext context, ModelMeta model) async {
    final previousModel = _selectedModel;
    setState(() => _selectedModel = model.id);
    try {
      await widget.controller.saveSettingsPayload(<String, Object?>{
        'default_chat_model': model.id,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save selection: $e')));
      }
      setState(() => _selectedModel = previousModel);
    }
  }
}

class _ModelChoiceCard extends StatelessWidget {
  const _ModelChoiceCard({
    required this.model,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final ModelMeta model;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final shellSize = compact ? 48.0 : 58.0;
    final iconSize = compact ? 24.0 : 30.0;
    final titleSize = compact ? 17.0 : 20.0;
    final purposeSize = compact ? 13.0 : 14.0;

    return OnboardingOptionCard(
      selected: selected,
      accent: color,
      compact: compact,
      onTap: onTap,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: shellSize,
                      height: shellSize,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: iconSize),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: ValueKey<String>(model.id),
                              color: color,
                              size: 28,
                            )
                          : Icon(
                              Icons.radio_button_unchecked_rounded,
                              key: ValueKey<String>('idle-${model.id}'),
                              color: p.textMuted.withValues(alpha: 0.5),
                              size: 28,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  model.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: p.bgSecondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    model.provider,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  model.purpose,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: purposeSize,
                    height: 1.35,
                  ),
                ),
              ],
            )
          : Row(
              children: <Widget>[
                Container(
                  width: shellSize,
                  height: shellSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: color, size: iconSize),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            model.label,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: p.bgSecondary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              model.provider,
                              style: TextStyle(
                                color: p.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        model.purpose,
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: purposeSize,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: ValueKey<String>(model.id),
                          color: color,
                          size: 28,
                        )
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: ValueKey<String>('idle-${model.id}'),
                          color: p.textMuted.withValues(alpha: 0.5),
                          size: 28,
                        ),
                ),
              ],
            ),
    );
  }
}
