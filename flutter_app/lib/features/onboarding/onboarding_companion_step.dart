import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
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
  String _selectedChannel = 'stable';
  TargetPlatform _selectedDesktopPlatform = TargetPlatform.macOS;

  bool _isLoadingReleases = false;
  Map<String, Map<TargetPlatform, String>> _downloadUrls = {
    'stable': <TargetPlatform, String>{},
    'beta': <TargetPlatform, String>{},
  };

  @override
  void initState() {
    super.initState();
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        _selectedDesktopPlatform = TargetPlatform.windows;
        break;
      case TargetPlatform.linux:
        _selectedDesktopPlatform = TargetPlatform.linux;
        break;
      default:
        _selectedDesktopPlatform = TargetPlatform.macOS;
    }
    _fetchReleases();
  }

  Future<void> _fetchReleases() async {
    if (mounted) {
      setState(() {
        _isLoadingReleases = true;
      });
    }
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/NeoLabs-Systems/NeoAgent/releases'),
        headers: const <String, String>{
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> releasesJson = jsonDecode(response.body) as List<dynamic>;
        final urls = _parseReleases(releasesJson);
        if (mounted) {
          setState(() {
            _downloadUrls = urls;
            _isLoadingReleases = false;
          });
        }
      } else {
        throw Exception('Failed to load releases: status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching releases: $e');
      if (mounted) {
        setState(() {
          _isLoadingReleases = false;
        });
      }
    }
  }

  Map<String, Map<TargetPlatform, String>> _parseReleases(List<dynamic> releases) {
    final Map<String, Map<TargetPlatform, String>> result = {
      'stable': <TargetPlatform, String>{},
      'beta': <TargetPlatform, String>{},
    };

    dynamic latestStable;
    dynamic latestBeta;

    for (final release in releases) {
      if (release is! Map<String, dynamic>) continue;
      final bool isPrerelease = release['prerelease'] == true;
      final String tagName = (release['tag_name'] ?? '').toString();
      final bool isBetaTag = tagName.contains('-beta');

      if ((isPrerelease || isBetaTag) && latestBeta == null) {
        latestBeta = release;
      } else if (!isPrerelease && !isBetaTag && latestStable == null) {
        latestStable = release;
      }

      if (latestStable != null && latestBeta != null) {
        break;
      }
    }

    latestStable ??= latestBeta;
    latestBeta ??= latestStable;

    if (latestStable != null) {
      result['stable'] = _extractUrlsFromRelease(latestStable);
    }
    if (latestBeta != null) {
      result['beta'] = _extractUrlsFromRelease(latestBeta);
    }

    return result;
  }

  Map<TargetPlatform, String> _extractUrlsFromRelease(dynamic release) {
    final Map<TargetPlatform, String> urls = <TargetPlatform, String>{};
    if (release is! Map<String, dynamic>) return urls;
    final List<dynamic> assets = release['assets'] as List<dynamic>? ?? const <dynamic>[];

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final String name = (asset['name'] ?? '').toString().toLowerCase();
      final String downloadUrl = (asset['browser_download_url'] ?? '').toString();

      if (name.endsWith('.dmg')) {
        urls[TargetPlatform.macOS] = downloadUrl;
      } else if (name.endsWith('.exe') && name.contains('setup')) {
        urls[TargetPlatform.windows] = downloadUrl;
      } else if (name.endsWith('.exe')) {
        urls.putIfAbsent(TargetPlatform.windows, () => downloadUrl);
      } else if (name.endsWith('.deb')) {
        urls[TargetPlatform.linux] = downloadUrl;
      } else if (name.endsWith('.apk') && !name.contains('-launcher')) {
        urls[TargetPlatform.android] = downloadUrl;
      }
    }
    return urls;
  }

  String _getFallbackUrl(String channel, TargetPlatform platform) {
    final String tag = channel == 'beta' ? 'v2.4.1-beta.9' : 'v2.4.0';
    final String ver = channel == 'beta' ? '2.4.1-beta.9' : '2.4.0';
    final String debVer = ver.replaceAll('-', '~');

    switch (platform) {
      case TargetPlatform.macOS:
        return 'https://github.com/NeoLabs-Systems/NeoAgent/releases/download/$tag/neoagent-macos-$ver.dmg';
      case TargetPlatform.windows:
        return 'https://github.com/NeoLabs-Systems/NeoAgent/releases/download/$tag/neoagent-windows-x64-setup-$ver.exe';
      case TargetPlatform.linux:
        return 'https://github.com/NeoLabs-Systems/NeoAgent/releases/download/$tag/neoagent-linux-amd64-$debVer.deb';
      case TargetPlatform.android:
        return 'https://github.com/NeoLabs-Systems/NeoAgent/releases/download/$tag/neoagent-android-$ver.apk';
      default:
        return 'https://github.com/NeoLabs-Systems/NeoAgent/releases/tag/$tag';
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _getFileExtensionForPlatform(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.macOS:
        return '.dmg';
      case TargetPlatform.windows:
        return '.exe';
      case TargetPlatform.linux:
        return '.deb';
      default:
        return '';
    }
  }

  Widget _buildChannelSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildChannelButton('stable', 'Stable Release'),
          _buildChannelButton('beta', 'Beta Release'),
        ],
      ),
    );
  }

  Widget _buildChannelButton(String channel, String label) {
    final isSelected = _selectedChannel == channel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedChannel = channel;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
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
            buttonText: desktopConnected
                ? 'Desktop Connected'
                : 'Download for ${_selectedDesktopPlatform.name.toUpperCase()} (${_getFileExtensionForPlatform(_selectedDesktopPlatform)})',
            onTap: () async {
              setState(() => _clickedDownloads.add('desktop'));
              final url = _downloadUrls[_selectedChannel]?[_selectedDesktopPlatform] ??
                  _getFallbackUrl(_selectedChannel, _selectedDesktopPlatform);
              await _launchUrl(url);
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
              final url = _downloadUrls[_selectedChannel]?[TargetPlatform.android] ??
                  _getFallbackUrl(_selectedChannel, TargetPlatform.android);
              await _launchUrl(url);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildChannelSelector(),
                  if (_isLoadingReleases) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
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
                                selectedDesktopPlatform: _selectedDesktopPlatform,
                                onDesktopPlatformChanged: (platform) {
                                  setState(() {
                                    _selectedDesktopPlatform = platform;
                                  });
                                },
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
                                selectedDesktopPlatform: _selectedDesktopPlatform,
                                onDesktopPlatformChanged: (platform) {
                                  setState(() {
                                    _selectedDesktopPlatform = platform;
                                  });
                                },
                              )
                              .animate()
                              .fadeIn(duration: 420.ms, delay: (180 + (index * 80)).ms)
                              .slideY(begin: 0.16, end: 0);
                        },
                      ),
              ),
            ],
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
    required this.selectedDesktopPlatform,
    required this.onDesktopPlatformChanged,
  });

  final _CompanionItemData item;
  final bool compact;
  final bool isClicked;
  final TargetPlatform selectedDesktopPlatform;
  final ValueChanged<TargetPlatform> onDesktopPlatformChanged;

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
              if (item.id == 'desktop' && !item.connected)
                _PlatformSelector(
                  selectedPlatform: selectedDesktopPlatform,
                  onPlatformChanged: onDesktopPlatformChanged,
                ),
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
                    if (item.id == 'desktop' && !item.connected)
                      _PlatformSelector(
                        selectedPlatform: selectedDesktopPlatform,
                        onPlatformChanged: onDesktopPlatformChanged,
                      ),
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

class _PlatformSelector extends StatelessWidget {
  const _PlatformSelector({
    required this.selectedPlatform,
    required this.onPlatformChanged,
  });

  final TargetPlatform selectedPlatform;
  final ValueChanged<TargetPlatform> onPlatformChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildTab(TargetPlatform.macOS, 'macOS'),
          _buildTab(TargetPlatform.windows, 'Windows'),
          _buildTab(TargetPlatform.linux, 'Linux'),
        ],
      ),
    );
  }

  Widget _buildTab(TargetPlatform platform, String label) {
    final isSelected = selectedPlatform == platform;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPlatformChanged(platform),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
