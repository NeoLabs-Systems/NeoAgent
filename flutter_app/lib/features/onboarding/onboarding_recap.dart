import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../src/theme/palette.dart';

/// One line of what setup achieved, or what can still wait.
class OnboardingRecapItem {
  const OnboardingRecapItem({
    required this.icon,
    required this.label,
    required this.done,
  });

  final IconData icon;
  final String label;
  final bool done;
}

/// The closing summary: real facts about this person's setup, not a slogan.
class OnboardingRecap extends StatelessWidget {
  const OnboardingRecap({super.key, required this.items});

  final List<OnboardingRecapItem> items;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: p.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: <Widget>[
                  Icon(
                    item.done ? Icons.check_circle_rounded : item.icon,
                    size: 19,
                    color: item.done ? p.success : p.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: GoogleFonts.geist(
                        color: item.done ? p.textPrimary : p.textSecondary,
                        fontSize: 14,
                        fontWeight: item.done
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
