import 'page_reload_stub.dart'
    if (dart.library.html) 'page_reload_web.dart';

/// Whether this client is a web page that can load itself again.
bool get canReloadPage => platformCanReloadPage;

/// Loads the app again, e.g. after an update replaced the web client.
void reloadPage() => platformReloadPage();
