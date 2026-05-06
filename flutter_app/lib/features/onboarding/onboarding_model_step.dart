import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../main.dart';
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
    return OnboardingScaffold(
      step: 3,
      totalSteps: 4,
      eyebrow: 'INTELLIGENCE',
      title: 'Choose your\ndefault model.',
      description: 'Pick the model NeoOS should use by default.',
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
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            )
          : ListView.separated(
              itemCount: _models.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final model = _models[index];
                final color = _getColorForModel(model);
                final selected = _selectedModel == model.id;
                return OnboardingOptionCard(
                      selected: selected,
                      accent: color,
                      onTap: () async {
                        final previousModel = _selectedModel;
                        setState(() => _selectedModel = model.id);
                        try {
                          await widget.controller.saveSettingsPayload(
                            <String, Object?>{'default_chat_model': model.id},
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save selection: $e'),
                              ),
                            );
                          }
                          setState(() => _selectedModel = previousModel);
                        }
                      },
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              _getIconForModel(model),
                              color: color,
                              size: 30,
                            ),
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        model.provider,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
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
                                    color: Colors.white.withValues(alpha: 0.68),
                                    fontSize: 14,
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
                                    color: Colors.white.withValues(alpha: 0.25),
                                    size: 28,
                                  ),
                          ),
                        ],
                      ),
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
}
