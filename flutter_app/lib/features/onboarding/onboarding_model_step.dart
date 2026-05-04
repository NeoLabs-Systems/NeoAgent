import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';

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

  List<ModelMeta> get _models {
    return widget.controller.supportedModels.where((m) => m.available && !m.id.startsWith('tool:')).toList();
  }

  @override
  void initState() {
    super.initState();
    final defaultChatModel = widget.controller.defaultChatModel;
    if (defaultChatModel.isNotEmpty && _models.any((m) => m.id == defaultChatModel)) {
      _selectedModel = defaultChatModel;
    } else if (_models.isNotEmpty) {
      _selectedModel = _models.first.id;
    }
  }

  Color _getColorForModel(ModelMeta model) {
    final l = model.provider.toLowerCase() + model.id.toLowerCase();
    if (l.contains('google') || l.contains('gemini')) return const Color(0xFF4285F4);
    if (l.contains('openai') || l.contains('gpt')) return const Color(0xFF10A37F);
    if (l.contains('anthropic') || l.contains('claude')) return const Color(0xFFD97757);
    if (l.contains('meta') || l.contains('llama')) return const Color(0xFF0668E1);
    if (l.contains('mistral')) return const Color(0xFFF97316);
    return Colors.purpleAccent;
  }

  IconData _getIconForModel(ModelMeta model) {
    final l = model.provider.toLowerCase() + model.id.toLowerCase();
    if (l.contains('google') || l.contains('gemini')) return Icons.auto_awesome;
    if (l.contains('openai') || l.contains('gpt')) return Icons.bolt;
    if (l.contains('anthropic') || l.contains('claude')) return Icons.library_books;
    if (l.contains('meta') || l.contains('llama')) return Icons.visibility_rounded;
    return Icons.memory_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 40),
            Text(
              'Select your\nBrain',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -1.5,
                color: Colors.white,
              ),
            ).animate()
             .fadeIn(duration: 600.ms)
             .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
             
            const SizedBox(height: 16),
            Text(
              'NeoOS works with the best LLMs. Choose the intelligence that powers your assistant.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ).animate()
             .fadeIn(duration: 600.ms, delay: 200.ms)
             .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
             
            const SizedBox(height: 60),
            
            Expanded(
              child: _models.isEmpty 
                ? Center(
                    child: Text(
                      'No available models found.\nYou can configure providers later in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                    ),
                  ).animate().fadeIn()
                : ListView.separated(
                itemCount: _models.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final model = _models[index];
                  final isSelected = _selectedModel == model.id;
                  
                  return _ModelCard(
                    model: model,
                    color: _getColorForModel(model),
                    icon: _getIconForModel(model),
                    isSelected: isSelected,
                    onTap: () async {
                      final previousModel = _selectedModel;
                      setState(() {
                        _selectedModel = model.id;
                      });
                      try {
                        await widget.controller.saveSettingsPayload({'default_chat_model': model.id});
                      } catch (e) {
                        debugPrint('Failed to save model setting: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save selection: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          setState(() {
                            _selectedModel = previousModel;
                          });
                        }
                      }
                    },
                  ).animate()
                   .fadeIn(duration: 500.ms, delay: (400 + (index.clamp(0, 5)) * 100).ms)
                   .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
                },
              ),
            ),
            
            // Bottom Action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: widget.onNext,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'Finish Setup',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5, end: 0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final ModelMeta model;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ] : [],
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        model.label,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          model.provider,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    model.purpose,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 16),
              Icon(Icons.check_circle_rounded, color: color, size: 28)
                .animate().scale(curve: Curves.elasticOut),
            ],
          ],
        ),
      ),
    );
  }
}
