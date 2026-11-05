part of 'main.dart';

/// The frame every integration setup popup shares: a branded header with the
/// integration's badge, status pills, a scrolling body, an error banner that
/// stays in view, and a footer that keeps the destructive action apart from
/// the primary one.
class _IntegrationDialog extends StatelessWidget {
  const _IntegrationDialog({
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.status = const <_IntegrationSetupStatusItem>[],
    this.error = '',
    this.leading,
    this.actions = const <Widget>[],
    this.onBack,
    this.onClose,
    this.width = 560,
  });

  final String title;
  final String? subtitle;

  /// Icon key understood by [_OfficialIntegrationIcon], such as `trello`.
  final String? icon;
  final List<_IntegrationSetupStatusItem> status;
  final List<Widget> children;
  final String error;

  /// A destructive action, shown at the far left of the footer.
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onBack;

  /// Closes the dialog; null disables the close button (while busy).
  final VoidCallback? onClose;
  final double width;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.width < AppBreakpoints.mobile;
    final subtitle = this.subtitle;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 40,
        vertical: compact ? 16 : 32,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: media.size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                onBack != null ? 12 : (compact ? 18 : 24),
                compact ? 16 : 20,
                12,
                status.isEmpty ? 16 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (onBack != null) ...<Widget>[
                    IconButton(
                      tooltip: appStrings.back,
                      onPressed: onClose == null ? null : onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (icon != null) ...<Widget>[
                    _OfficialIntegrationIcon.named(
                      icon: icon!,
                      label: title,
                      size: 42,
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: appStrings.close,
                    onPressed: onClose,
                    icon: Icon(Icons.close_rounded, color: _textSecondary),
                  ),
                ],
              ),
            ),
            if (status.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(compact ? 18 : 24, 0, 24, 16),
                child: Wrap(spacing: 8, runSpacing: 8, children: status),
              ),
            Divider(height: 1, thickness: 1, color: _border),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 18 : 24,
                  20,
                  compact ? 18 : 24,
                  20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: error.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 18 : 24,
                        0,
                        compact ? 18 : 24,
                        12,
                      ),
                      child: _IntegrationErrorBanner(message: error),
                    ),
            ),
            if (leading != null || actions.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _bgSecondary.withValues(alpha: 0.55),
                  border: Border(top: BorderSide(color: _border)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 14 : 20,
                    vertical: 14,
                  ),
                  child: compact
                      ? Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[if (leading != null) leading!, ...actions],
                        )
                      : Row(
                          children: <Widget>[
                            if (leading != null) leading!,
                            const Spacer(),
                            for (final (index, action) in actions.indexed) ...<Widget>[
                              if (index > 0) const SizedBox(width: 8),
                              action,
                            ],
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IntegrationErrorBanner extends StatelessWidget {
  const _IntegrationErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.tag),
        border: Border.all(color: _danger.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 18, color: _danger),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(color: _danger, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Secondary explanatory text under a field or block.
class _IntegrationHint extends StatelessWidget {
  const _IntegrationHint(this.text, {this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: _textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The text-and-spinner label of a footer button while it works.
class _IntegrationBusyLabel extends StatelessWidget {
  const _IntegrationBusyLabel({required this.busy, required this.label});

  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!busy) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

/// A destructive text button in the dialog footer.
class _IntegrationDangerButton extends StatelessWidget {
  const _IntegrationDangerButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: _danger),
      onPressed: onPressed,
      icon: const Icon(Icons.link_off_rounded, size: 18),
      label: Text(label),
    );
  }
}

/// Asks before a destructive integration action; true when confirmed.
Future<bool> _confirmIntegrationAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.link_off_rounded, color: _danger),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(color: _textSecondary, height: 1.45),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(appStrings.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

/// Icon key of an official integration, for dialogs that only know its id.
String? _integrationIconFor(NeoAgentController controller, String providerId) =>
    controller.officialIntegrations
        .where((item) => item.id == providerId)
        .firstOrNull
        ?.icon;
