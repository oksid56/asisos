/*
  pwa-editor/sw.js - simple cache-first service worker
  CC0 1.0 Universal - https://creativecommons.org/publicdomain/zero/1.0/
  SPDX-License-Identifier: CC0-1.0
  See ./LICENSE for the full legal text.
*/
const CACHE_NAME = 'pwa-editor-v1';
const FILES_TO_CACHE = [
  './',
  './index.html',
  './style.css',
  './manifest.json',
  './sw.js',
  './icon.svg'
];

self.addEventListener('install', (evt) => {
  evt.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(FILES_TO_CACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (evt) => {
  evt.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.map((k) => (k !== CACHE_NAME ? caches.delete(k) : Promise.resolve()))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch', (evt) => {
  if (evt.request.method !== 'GET') return;
  evt.respondWith(
    caches.match(evt.request).then((cached) => {
      if (cached) return cached;
      return fetch(evt.request).then((res) => {
        if (!evt.request.url.startsWith(self.location.origin)) return res;
        const clone = res.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(evt.request, clone).catch(()=>{});
        });
        return res;
      }).catch(() => {
        if (evt.request.headers.get('accept') && evt.request.headers.get('accept').includes('text/html')) {
          return caches.match('./index.html');
        }
      });
    })
  );
});
