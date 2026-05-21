import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import 'onboarding_chrome.dart';

class OnboardingCompanionStep extends StatefulWidget {
  const OnboardingCompanionStep({
    super.key,
    required this.onNext,
    required this.controller,
  });

  final VoidCallback onNext;
  final NeoAgentController controller;

  @override
  State<OnboardingCompanionStep> createState() => _OnboardingCompanionStepState();
}

class _OnboardingCompanionStepState extends State<OnboardingCompanionStep> {
  final Set<String> _clickedDownloads = <String>{};

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useGrid = width >= 700;
    final columns = width >= 1050 ? 3 : (useGrid ? 2 : 1);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final extConnected = widget.controller.browserExtensionConnected;
        final desktopConnected = widget.controller.desktopCompanionConnected;

        final items = <_CompanionItemData>[
          _CompanionItemData(
            id: 'extension',
            title: 'Chrome Extension',
            subtitle: 'Automate browser tasks and capture web page context directly.',
            icon: Icons.extension_rounded,
            accentColor: extConnected ? const Color(0xFF10A37F) : const Color(0xFF4285F4),
            connected: extConnected,
            buttonText: extConnected ? 'Extension Connected' : 'Download Extension',
            onTap: () async {
              setState(() => _clickedDownloads.add('extension'));
              await widget.controller.downloadBrowserExtension();
            },
          ),
          _CompanionItemData(
            id: 'desktop',
            title: 'Desktop App',
            subtitle: 'Enable native command run, system capture, and global controls.',
            icon: Icons.laptop_mac_rounded,
            accentColor: desktopConnected ? const Color(0xFF10A37F) : const Color(0xFF8A5CF5),
            connected: desktopConnected,
            buttonText: desktopConnected ? 'Desktop Connected' : 'Get Desktop App',
            onTap: () async {
              setState(() => _clickedDownloads.add('desktop'));
              await _launchUrl('https://github.com/NeoLabs-Systems/NeoAgent/releases');
            },
          ),
          _CompanionItemData(
            id: 'mobile',
            title: 'Mobile Companion',
            subtitle: 'Sync notifications, phone calls, and health connect metrics.',
            icon: Icons.phone_iphone_rounded,
            accentColor: const Color(0xFFF5A623),
            connected: false,
            buttonText: 'Download Android APK',
            onTap: () async {
              setState(() => _clickedDownloads.add('mobile'));
              await _launchUrl('https://github.com/NeoLabs-Systems/NeoAgent/releases');
            },
          ),
        ];

        return OnboardingScaffold(
          step: 1,
          totalSteps: 4,
          eyebrow: 'INTEGRATION',
          title: 'Connect your\ndevices & apps.',
          description: 'NeoOS works best when integrated with your desktop, browser, and mobile devices.',
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              OnboardingGhostButton(
                label: 'Skip integration',
                onPressed: widget.onNext,
              ),
              OnboardingPrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: widget.onNext,
              ),
            ],
          ),
          child: useGrid
              ? GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: width >= 1050 ? 1.42 : 1.25,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CompanionCard(
                          item: item,
                          compact: true,
                          isClicked: _clickedDownloads.contains(item.id),
                        )
                        .animate()
                        .fadeIn(duration: 420.ms, delay: (180 + (index * 80)).ms)
                        .slideY(begin: 0.16, end: 0);
                  },
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CompanionCard(
                          item: item,
                          compact: false,
                          isClicked: _clickedDownloads.contains(item.id),
                        )
                        .animate()
                        .fadeIn(duration: 420.ms, delay: (180 + (index * 80)).ms)
                        .slideY(begin: 0.16, end: 0);
                  },
                ),
        );
      },
    );
  }
}

class _CompanionItemData {
  const _CompanionItemData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.connected,
    required this.buttonText,
    required this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool connected;
  final String buttonText;
  final VoidCallback onTap;
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({
    required this.item,
    required this.compact,
    required this.isClicked,
  });

  final _CompanionItemData item;
  final bool compact;
  final bool isClicked;

  @override
  Widget build(BuildContext context) {
    final shellSize = compact ? 48.0 : 58.0;
    final iconSize = compact ? 24.0 : 30.0;

    final cardContent = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: shellSize,
                    height: shellSize,
                    decoration: BoxDecoration(
                      color: item.accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.accentColor,
                      size: iconSize,
                    ),
                  ),
                  const Spacer(),
                  _StatusIndicator(connected: item.connected, color: item.accentColor),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  item.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DownloadButton(item: item, isClicked: isClicked),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: shellSize,
                height: shellSize,
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  item.icon,
                  color: item.accentColor,
                  size: iconSize,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DownloadButton(item: item, isClicked: isClicked),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusIndicator(connected: item.connected, color: item.accentColor),
            ],
          );

    return OnboardingOptionCard(
      selected: item.connected,
      accent: item.accentColor,
      compact: compact,
      onTap: item.onTap,
      child: cardContent,
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.connected, required this.color});

  final bool connected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: connected
          ? Icon(
              Icons.check_circle_rounded,
              key: const ValueKey<String>('connected'),
              color: color,
              size: 28,
            )
          : Icon(
              Icons.arrow_circle_down_rounded,
              key: const ValueKey<String>('downloadable'),
              color: Colors.white.withValues(alpha: 0.26),
              size: 28,
            ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.item, required this.isClicked});

  final _CompanionItemData item;
  final bool isClicked;

  @override
  Widget build(BuildContext context) {
    if (item.connected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: item.accentColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.done_all_rounded, size: 14, color: item.accentColor),
            const SizedBox(width: 6),
            Text(
              'Connected',
              style: TextStyle(
                color: item.accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isClicked 
            ? Colors.white.withValues(alpha: 0.08) 
            : item.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClicked 
              ? Colors.white.withValues(alpha: 0.2) 
              : item.accentColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isClicked ? Icons.hourglass_empty_rounded : Icons.open_in_new_rounded,
            size: 14,
            color: isClicked ? Colors.white70 : item.accentColor,
          ),
          const SizedBox(width: 6),
          Text(
            isClicked ? 'Waiting for pairing...' : item.buttonText,
            style: TextStyle(
              color: isClicked ? Colors.white70 : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
