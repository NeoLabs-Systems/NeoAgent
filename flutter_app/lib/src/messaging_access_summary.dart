import 'package:flutter/material.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

String messagingSubjectName(String? name) {
  final trimmed = (name ?? '').trim();
  return trimmed.isEmpty ? 'this agent' : trimmed;
}

String messagingAccessModeLabel(String mode) {
  switch (mode) {
    case 'open':
      return appStrings.anyone;
    case 'disabled':
      return appStrings.noOne;
    default:
      return appStrings.approvedOnly;
  }
}

String messagingAccessModeHelp(
  String mode, {
  required bool shared,
  String? agentName,
}) {
  final name = messagingSubjectName(agentName);
  final place = shared ? 'groups and channels' : appStrings.privateChats2;
  switch (mode) {
    case 'open':
      return appStrings.anyoneOnThisPlatformCanMessage2(name, place);
    case 'disabled':
      return appStrings.arg1WillNotReplyToArg2(name, place);
    default:
      return shared
          ? appStrings.arg1OnlyJoinsTheGroupsAndChannels(name)
          : appStrings.arg1OnlyRepliesToThePeople(name);
  }
}

bool looksLikeRawMessagingId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  if (trimmed.startsWith('dm_')) return true;
  return RegExp(r'^\d{8,}$').hasMatch(trimmed);
}

bool looksLikeDirectMessagingValue(String value) {
  return value.trim().startsWith('dm_');
}

String messagingRuleDisplayLabel({
  String? label,
  required String value,
}) {
  final named = (label ?? '').trim();
  if (named.isNotEmpty && !looksLikeRawMessagingId(named)) return named;
  if (looksLikeDirectMessagingValue(value) ||
      looksLikeDirectMessagingValue(named)) {
    return appStrings.privateChat;
  }
  if (named.isNotEmpty) return named;
  return value;
}

String messagingScopePickerLabel(String scope) {
  switch (scope) {
    case 'phone_number':
      return appStrings.phoneNumber;
    case 'server':
      return appStrings.server;
    case 'channel':
      return appStrings.channel;
    case 'group':
      return 'Group';
    case 'room':
      return 'Room';
    case 'role':
      return 'Role';
    case 'dm':
      return appStrings.privateChat;
    case 'user':
      return 'Person';
    default:
      return appStrings.chat;
  }
}

class MessagingAccessSummaryCard extends StatelessWidget {
  const MessagingAccessSummaryCard({
    super.key,
    required this.accent,
    required this.headline,
    required this.hint,
    this.details = const <String>[],
  });

  final Color accent;
  final String headline;
  final String hint;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final surface =
        Theme.of(context).dialogTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[accent.withValues(alpha: 0.16), surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.forum_outlined,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      headline,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(hint, style: const TextStyle(height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: details
                  .map(
                    (detail) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(detail),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}
