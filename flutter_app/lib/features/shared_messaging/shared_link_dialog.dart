import 'package:flutter/material.dart';

import '../../src/l10n/app_language.dart';
import '../../src/theme/palette.dart';
import 'shared_link_flow.dart';
import 'shared_messaging_widgets.dart';

Future<void> showSharedLinkDialog(
  BuildContext context,
  SharedLinkSession session,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => SharedLinkDialog(session: session),
  );
}

/// [SharedLinkFlow] as a dialog, for screens with no room to run it in place.
class SharedLinkDialog extends StatelessWidget {
  const SharedLinkDialog({super.key, required this.session});

  final SharedLinkSession session;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    void close() => Navigator.of(context).pop();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  PlatformBadge(
                    icon: session.platformIcon,
                    color: session.platformColor,
                    size: 38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      appStrings.sharedMessagingTitle(session.platformLabel),
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: close,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SharedLinkFlow(session: session, onDone: close),
            ],
          ),
        ),
      ),
    );
  }
}
