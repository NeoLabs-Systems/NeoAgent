import 'package:flutter/material.dart';

class ComputerDisplay extends StatelessWidget {
  const ComputerDisplay({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'The interactive Linux desktop is available in the NeoAgent web app.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
