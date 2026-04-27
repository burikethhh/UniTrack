import 'dart:js_interop';

/// Clear all Service Worker caches then hard-reload the page.
/// This ensures the browser fetches completely fresh assets after a deploy.
void reloadWebPage() {
  // Use JS interop to clear caches then reload
  _clearCachesAndReload();
}

@JS('eval')
external JSAny _jsEval(JSString code);

void _clearCachesAndReload() {
  // Execute cache clearing via raw JS — avoids Dart type-mapping issues
  // with the CacheStorage API's Promise-based interface
  _jsEval(
    '''
    (function() {
      if (window.caches) {
        caches.keys().then(function(names) {
          return Promise.all(names.map(function(n) { return caches.delete(n); }));
        }).then(function() {
          window.location.reload();
        });
      } else {
        window.location.reload();
      }
    })()
  '''
        .toJS,
  );
}
