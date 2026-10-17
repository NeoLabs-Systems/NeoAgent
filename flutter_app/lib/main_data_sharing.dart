part of 'main.dart';

// Opt-in usage data sharing on the Profile page. Turning it on asks first and
// shows exactly what leaves the account; the same list stays one tap away
// under the switch.

class _DataSharingSetting extends StatefulWidget {
  const _DataSharingSetting({required this.controller});

  final NeoAgentController controller;

  @override
  State<_DataSharingSetting> createState() => _DataSharingSettingState();
}

class _DataSharingSettingState extends State<_DataSharingSetting> {
  bool _showScope = false;

  NeoAgentController get _controller => widget.controller;

  Future<void> _setSharing(bool enabled) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => const _DataSharingConsentDialog(),
      );
      if (confirmed != true || !mounted) return;
    }
    final saved = await _controller.setUsageDataSharing(enabled);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage ??
                appStrings.somethingWentWrongPleaseTryAgain,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharing = _controller.sharesUsageData;
    final since = _controller.usageDataSharingSince;
    final description = sharing && since != null
        ? '${appStrings.dataSharingDescription} '
              '${appStrings.dataSharingSince(_formatDate(since))}'
        : appStrings.dataSharingDescription;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsRow(
          anchor: 'dataSharing',
          label: appStrings.dataSharingTitle,
          description: description,
          control: Switch(
            value: sharing,
            onChanged: _controller.isSavingDataSharing ? null : _setSharing,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showScope = !_showScope),
              icon: Icon(
                _showScope ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(appStrings.dataSharingWhatsShared),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _showScope
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _DataSharingScope(),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _DataSharingConsentDialog extends StatelessWidget {
  const _DataSharingConsentDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(appStrings.dataSharingConfirmTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                appStrings.dataSharingDescription,
                style: TextStyle(
                  fontSize: 13.5,
                  color: _textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              const _DataSharingScope(stacked: true),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(appStrings.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(appStrings.dataSharingConfirmAction),
        ),
      ],
    );
  }
}

/// What sharing includes and what it never touches, side by side when there
/// is room. [stacked] keeps one column, as a dialog needs: dialogs size
/// their content intrinsically, which a LayoutBuilder cannot answer.
class _DataSharingScope extends StatelessWidget {
  const _DataSharingScope({this.stacked = false});

  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final included = _DataSharingList(
      title: appStrings.dataSharingIncluded,
      icon: Icons.check_rounded,
      color: _success,
      items: <String>[
        appStrings.dataSharingIncludedDevice,
        appStrings.dataSharingIncludedLocale,
        appStrings.dataSharingIncludedFeatures,
        appStrings.dataSharingIncludedRuns,
        appStrings.dataSharingIncludedActivity,
      ],
    );
    final excluded = _DataSharingList(
      title: appStrings.dataSharingExcluded,
      icon: Icons.block_rounded,
      color: _danger,
      items: <String>[
        appStrings.dataSharingExcludedContent,
        appStrings.dataSharingExcludedRuns,
        appStrings.dataSharingExcludedFiles,
        appStrings.dataSharingExcludedIdentity,
        appStrings.dataSharingExcludedAccounts,
      ],
    );
    final note = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.groups_outlined, size: 16, color: _textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            appStrings.dataSharingPooledNote,
            style: TextStyle(fontSize: 12.5, color: _textMuted, height: 1.45),
          ),
        ),
      ],
    );
    Widget layout(bool sideBySide) {
      final lists = sideBySide
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: included),
                  const SizedBox(width: 12),
                  Expanded(child: excluded),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                included,
                const SizedBox(height: 12),
                excluded,
              ],
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[lists, const SizedBox(height: 14), note],
      );
    }

    if (stacked) return layout(false);
    return LayoutBuilder(
      builder: (context, constraints) => layout(constraints.maxWidth >= 520),
    );
  }
}

class _DataSharingList extends StatelessWidget {
  const _DataSharingList({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: GoogleFonts.geistMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    items[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: _textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
