import 'app_link_location_stub.dart'
    if (dart.library.html) 'app_link_location_web.dart';

/// A place in the app that a link opens:
/// `<server>/app/open/<section>[/<page>][/<focus>]`. The server builds these
/// (server/services/settings/app_links.js), so the assistant can send one in
/// chat or over a messaging platform. A settings link names a page and,
/// optionally, the setting to scroll to; an integration link names the
/// integration to open.
class AppLink {
  const AppLink({required this.section, this.page, this.focus});

  final String section;
  final String? page;
  final String? focus;

  /// The link [uri] carries, or null when it is not an app link.
  static AppLink? tryParse(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.length < 3 || segments[0] != 'app' || segments[1] != 'open') {
      return null;
    }
    final rest = segments.sublist(3);
    // A model writing a link by hand may put the focus in the fragment.
    final fragment = uri.fragment.isEmpty ? null : uri.fragment;
    if (segments[2] == 'settings') {
      return AppLink(
        section: segments[2],
        page: rest.elementAtOrNull(0),
        focus: rest.elementAtOrNull(1) ?? fragment,
      );
    }
    return AppLink(
      section: segments[2],
      focus: rest.elementAtOrNull(0) ?? fragment,
    );
  }
}

/// The app link the web app was opened at, if any. Taking it resets the
/// address to the app's root, so a reload starts where people expect.
AppLink? takeLaunchAppLink() {
  final location = launchLocation();
  final link = location == null ? null : AppLink.tryParse(location);
  if (link != null) resetLaunchLocation();
  return link;
}
