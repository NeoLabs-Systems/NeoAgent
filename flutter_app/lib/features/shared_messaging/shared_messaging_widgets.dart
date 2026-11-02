import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../src/l10n/app_language.dart';
import '../../src/theme/palette.dart';

/// The platform's icon on a soft tile of its own colour.
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// A small dot-and-label status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum NoticeTone { info, warning, danger, success }

/// A tinted line of guidance, with an optional fix beside it.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.tone,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final NoticeTone tone;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final (color, icon) = switch (tone) {
      NoticeTone.info => (p.info, Icons.info_outline_rounded),
      NoticeTone.warning => (p.warning, Icons.warning_amber_rounded),
      NoticeTone.danger => (p.danger, Icons.error_outline_rounded),
      NoticeTone.success => (p.success, Icons.check_circle_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (actionLabel != null) ...<Widget>[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAction,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        actionLabel!,
                        style: TextStyle(
                          color: p.accentHover,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One numbered step of a guided setup. The body is whatever the step needs
/// beyond its sentence: a field, a button, a code.
class SetupStep extends StatelessWidget {
  const SetupStep({
    super.key,
    required this.number,
    required this.title,
    this.child,
  });

  final int number;
  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.13),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: p.accentHover,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  title,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ),
              if (child != null) ...<Widget>[
                const SizedBox(height: 10),
                child!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A switch with its explanation; the whole row is the target.
class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A QR code on the white plate scanners need, in light and dark themes alike.
class ScanCode extends StatelessWidget {
  const ScanCode({super.key, required this.data, this.size = 148});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrImageView(
        data: data,
        size: size,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
      ),
    );
  }
}

/// A one-time code in large type, with one-tap copy that says it worked.
class LinkCodeTile extends StatefulWidget {
  const LinkCodeTile({super.key, required this.code, this.enabled = true});

  final String code;
  final bool enabled;

  @override
  State<LinkCodeTile> createState() => _LinkCodeTileState();
}

class _LinkCodeTileState extends State<LinkCodeTile> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) setState(() => _copied = true);
  }

  @override
  void didUpdateWidget(LinkCodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) _copied = false;
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: p.bgTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              widget.code,
              maxLines: 1,
              style: GoogleFonts.geistMono(
                color: widget.enabled ? p.textPrimary : p.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                decoration: widget.enabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          IconButton(
            tooltip: _copied
                ? appStrings.sharedMessagingCopied
                : appStrings.sharedMessagingCopyCode,
            onPressed: widget.enabled ? _copy : null,
            icon: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 18,
              color: _copied ? p.success : null,
            ),
          ),
        ],
      ),
    );
  }
}
