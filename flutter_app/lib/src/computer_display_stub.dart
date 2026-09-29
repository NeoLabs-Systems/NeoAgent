import 'package:flutter/material.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class ComputerDisplay extends StatelessWidget {
  const ComputerDisplay({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          appStrings.theInteractiveLinuxDesktopIsAvailable,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
