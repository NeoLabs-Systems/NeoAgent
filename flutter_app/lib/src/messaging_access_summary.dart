import 'package:flutter/material.dart';

class MessagingAccessSummaryCard extends StatelessWidget {
  const MessagingAccessSummaryCard({
    super.key,
    required this.accent,
    required this.summary,
    required this.hint,
  });

  final Color accent;
  final String summary;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.18),
            Theme.of(context).dialogTheme.backgroundColor ??
                Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            summary,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(hint),
        ],
      ),
    );
  }
}
