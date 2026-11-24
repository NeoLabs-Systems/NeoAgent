part of 'main.dart';

// /app/pair?code=…: the "Can't scan?" link of the Pair a phone dialog,
// opened in a browser. On a phone it explains that pairing needs the
// NeoAgent app and hands the code to it; on a computer it says to open the
// link on the phone.

/// Where the apps are downloaded.
const String _appDownloadUrl =
    'https://github.com/NeoLabs-Systems/NeoAgent/releases/latest';

bool get _onPhoneBrowser =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

class PairLandingView extends StatelessWidget {
  const PairLandingView({super.key, required this.controller});

  final NeoAgentController controller;

  /// The pairing link this page was opened at, read back so the server keeps
  /// any base path it is served under.
  PairingLinkData? get _link {
    final code = controller.pendingPairCode ?? '';
    final here = Uri.base.replace(
      queryParameters: <String, String>{'code': code},
      fragment: '',
    );
    return parsePairingLink(here.toString());
  }

  List<Widget> _phone(PairingLinkData link) {
    return <Widget>[
      Text(
        appStrings.pairLandingPhoneBody,
        style: TextStyle(color: _textSecondary, height: 1.45),
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton.icon(
        onPressed: () => unawaited(
          url_launcher.launchUrl(
            link.appLink,
            mode: url_launcher.LaunchMode.externalApplication,
          ),
        ),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: Text(appStrings.pairLandingOpenApp),
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton.icon(
        onPressed: () => unawaited(
          url_launcher.launchUrl(
            Uri.parse(_appDownloadUrl),
            mode: url_launcher.LaunchMode.externalApplication,
          ),
        ),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: Text(appStrings.pairLandingGetApp),
      ),
    ];
  }

  List<Widget> _computer() {
    return <Widget>[
      Text(
        appStrings.pairLandingComputerBody,
        style: TextStyle(color: _textSecondary, height: 1.45),
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        onPressed: controller.finishPairLanding,
        child: Text(appStrings.pairLandingOpenNeoagent),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    return _AuthBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _EntranceMotion(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _border),
                      boxShadow: _softPanelShadow,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Center(child: _LogoBadge(size: 44)),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            appStrings.pairLandingTitle,
                            style: _displayTitleStyle(24),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (link == null) ...<Widget>[
                            _InlineNote(message: appStrings.pairLandingInvalid),
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton(
                              onPressed: controller.finishPairLanding,
                              child: Text(appStrings.pairLandingOpenNeoagent),
                            ),
                          ] else if (_onPhoneBrowser)
                            ..._phone(link)
                          else
                            ..._computer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
