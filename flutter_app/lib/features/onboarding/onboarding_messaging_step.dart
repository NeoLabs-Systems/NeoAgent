import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';

class OnboardingMessagingStep extends StatefulWidget {
  const OnboardingMessagingStep({
    super.key,
    required this.onNext,
    required this.controller,
  });

  final VoidCallback onNext;
  final NeoAgentController controller;

  @override
  State<OnboardingMessagingStep> createState() => _OnboardingMessagingStepState();
}

class _OnboardingMessagingStepState extends State<OnboardingMessagingStep> {
  MessagingPlatformDescriptor? _selectedPlatform;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 40),
            Text(
              'Connect your\nCommunication',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -1.5,
                color: Colors.white,
              ),
            ).animate()
             .fadeIn(duration: 600.ms)
             .slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
             
            const SizedBox(height: 16),
            Text(
              'NeoOS works where you do. Connect a platform to allow Neo to intercept and assist with your messages securely.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ).animate()
             .fadeIn(duration: 600.ms, delay: 200.ms)
             .slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
             
            const SizedBox(height: 60),
            
            Expanded(
              child: ListView.separated(
                itemCount: messagingPlatforms.length > 5 ? 6 : messagingPlatforms.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final platformCount = messagingPlatforms.length > 5 ? 5 : messagingPlatforms.length;
                  if (index == platformCount) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 32),
                      child: Center(
                        child: Text(
                          'More providers available in Settings',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 1000.ms);
                  }
                  
                  final platform = messagingPlatforms[index];
                  final isSelected = _selectedPlatform?.id == platform.id;
                  
                  return _PlatformCard(
                    platform: platform,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedPlatform = platform;
                      });
                    },
                  ).animate()
                   .fadeIn(duration: 500.ms, delay: (400 + index * 100).ms)
                   .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
                },
              ),
            ),
            
            // Bottom Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                TextButton(
                  onPressed: widget.onNext,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Skip for now', style: TextStyle(fontSize: 16)),
                ).animate().fadeIn(delay: 800.ms),
                
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedPlatform != null)
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            await openMessagingConfig(context, widget.controller, _selectedPlatform!);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to connect: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text(
                          'Configure',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ).animate().fadeIn(delay: 800.ms),
                    
                    if (_selectedPlatform != null)
                      const SizedBox(width: 8),
                    
                    FilledButton.icon(
                      onPressed: widget.onNext,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: _selectedPlatform != null 
                            ? Colors.white.withValues(alpha: 0.1) 
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        _selectedPlatform != null ? 'Next' : 'Continue',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ).animate().fadeIn(delay: 800.ms),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.platform,
    required this.isSelected,
    required this.onTap,
  });

  final MessagingPlatformDescriptor platform;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = platform.accent;
    
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
              color: color.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ] : [],
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                platform.icon,
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
                  Text(
                    platform.label,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    platform.subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 28)
                .animate().scale(curve: Curves.elasticOut),
          ],
        ),
      ),
    );
  }
}
