{{flutter_js}}
{{flutter_build_config}}

// The Android shell always loads the hosted vault. Remove Flutter's deprecated
// cache-first service worker so an older reader cannot survive a security or
// reliability update inside a customer's WebView.
(async () => {
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map((registration) => registration.unregister()));
  }
  if ('caches' in window) {
    const cacheNames = await caches.keys();
    await Promise.all(
      cacheNames
        .filter((name) => name.startsWith('flutter-'))
        .map((name) => caches.delete(name)),
    );
  }
  await _flutter.loader.load();
})();
