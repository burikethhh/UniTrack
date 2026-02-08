// Web utility — reload page on web, no-op on other platforms.
// Uses conditional import for platform safety.
import 'web_utils_stub.dart'
    if (dart.library.js_interop) 'web_utils_web.dart' as platform;

void reloadWebPage() => platform.reloadWebPage();
