// Deliberately do not clear CacheStorage, IndexedDB, OPFS or localStorage.
// Unregister only this installation's obsolete Flutter worker, not other apps.
'use strict';
(function () {
  const button = document.getElementById('update');
  const status = document.getElementById('status');
  const base = new URL('./', window.location.href);
  // After unregistering, navigate once so this document is no longer controlled
  // by the old worker. Then refresh HTTP cache entries before starting Flutter.
  if (new URL(window.location.href).searchParams.has('reload')) {
    button.disabled = true;
    status.textContent = '正在下载新版网页程序，本机数据保持不变…';
    (async function () {
      try {
        for (const file of ['index.html', 'flutter_bootstrap.js', 'main.dart.js',
          'pkg/openlogtool_core.js', 'pkg/openlogtool_core_bg.wasm']) {
          const response = await fetch(new URL(file, base), { cache: 'reload' });
          if (!response.ok) throw new Error('下载失败：' + file);
          await response.arrayBuffer();
        }
        const destination = new URL(base);
        destination.searchParams.set('updated', String(Date.now()));
        window.location.replace(destination.href);
      } catch (error) {
        status.textContent = '更新未完成：' + (error instanceof Error ? error.message : String(error));
        button.disabled = false;
      }
    })();
  }
  button.addEventListener('click', async function () {
    button.disabled = true;
    status.textContent = '正在检查线上版本…';
    try {
      // A query also bypasses the resource keys used by old Flutter workers.
      const versionUrl = new URL('version.json', base);
      versionUrl.searchParams.set('update', String(Date.now()));
      const response = await fetch(versionUrl, { cache: 'no-store' });
      if (!response.ok) throw new Error('无法获取线上版本，请检查网络后重试。');
      const version = await response.json();
      if (typeof version.version !== 'string' || !version.version) {
        throw new Error('线上版本信息无效，请联系管理员。');
      }
      if ('serviceWorker' in navigator) {
        const registrations = await navigator.serviceWorker.getRegistrations();
        for (const registration of registrations) {
          if (registration.scope !== base.href) continue;
          const workers = [registration.active, registration.waiting, registration.installing].filter(Boolean);
          if (workers.length && workers.every(function (worker) {
            const url = new URL(worker.scriptURL);
            return url.origin === base.origin && url.pathname === base.pathname + 'flutter_service_worker.js';
          })) {
            await registration.unregister();
          }
        }
      }
      status.textContent = '正在载入 ' + version.version + '，本机数据保持不变…';
      const destination = new URL('update.html', base);
      destination.searchParams.set('reload', String(Date.now()));
      window.location.replace(destination.href);
    } catch (error) {
      status.textContent = '更新未完成：' + (error instanceof Error ? error.message : String(error));
      button.disabled = false;
    }
  });
})();
