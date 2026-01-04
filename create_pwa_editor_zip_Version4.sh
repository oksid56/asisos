#!/usr/bin/env bash
# Create a ZIP archive of the pwa-editor directory (CC0-1.0 licensed files).
# Usage: ./create_pwa_editor_zip.sh
set -euo pipefail

DIR="pwa-editor"
ZIP="pwa-editor.zip"

rm -rf "$DIR" "$ZIP"
mkdir -p "$DIR/icons"

cat > "$DIR/index.html" <<'HTML'
<!--
  pwa-editor/index.html
  CC0 1.0 Universal - https://creativecommons.org/publicdomain/zero/1.0/
  SPDX-License-Identifier: CC0-1.0
  See ./LICENSE for the full legal text.
-->
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <meta name="theme-color" content="#2b2b2b"/>
  <meta name="license" content="CC0-1.0">
  <link rel="license" href="./LICENSE">
  <title>PWA Text Editor</title>

  <link rel="manifest" href="./manifest.json">
  <link rel="icon" href="./icons/icon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="./style.css">

  <meta name="description" content="Simple offline-capable PWA text editor (standalone).">
</head>
<body>
  <header class="bar">
    <div class="left">
      <button id="newBtn" title="New">New</button>
      <button id="openBtn" title="Open">Open</button>
      <input id="fileInput" type="file" accept=".txt,text/plain" style="display:none">
      <button id="downloadBtn" title="Download">Download</button>
      <button id="clearBtn" title="Clear">Clear</button>
    </div>
    <div class="center">PWA Text Editor</div>
    <div class="right">
      <button id="installBtn" style="display:none">Install</button>
      <span id="status" class="status">Saved</span>
    </div>
  </header>

  <main>
    <textarea id="editor" placeholder="Start typing..."></textarea>
  </main>

  <footer class="bar small">
    <label><input id="autosave" type="checkbox" checked> Autosave</label>
    <span class="spacer"></span>
    <small>Shortcuts: <strong>Ctrl/Cmd+S</strong> save · <strong>Ctrl/Cmd+O</strong> open</small>
  </footer>

  <script>
  /*
    pwa-editor/index.html (embedded JS)
    CC0 1.0 Universal - https://creativecommons.org/publicdomain/zero/1.0/
    SPDX-License-Identifier: CC0-1.0
    See ./LICENSE for the full legal text.
  */
  (function () {
    const editor = document.getElementById('editor');
    const status = document.getElementById('status');
    const autosaveCheckbox = document.getElementById('autosave');
    const downloadBtn = document.getElementById('downloadBtn');
    const openBtn = document.getElementById('openBtn');
    const fileInput = document.getElementById('fileInput');
    const newBtn = document.getElementById('newBtn');
    const clearBtn = document.getElementById('clearBtn');
    const installBtn = document.getElementById('installBtn');

    const STORAGE_KEY = 'pwa-editor-content-v1';
    let saveTimeout = null;
    let deferredPrompt = null;

    // load content
    const load = () => {
      const content = localStorage.getItem(STORAGE_KEY) || '';
      editor.value = content;
      showStatus('Loaded');
    };

    // save content
    const save = (show = true) => {
      localStorage.setItem(STORAGE_KEY, editor.value);
      if (show) showStatus('Saved');
    };

    const showStatus = (text) => {
      status.textContent = text;
      status.classList.add('flash');
      setTimeout(() => status.classList.remove('flash'), 700);
    };

    // autosave on typing (debounced)
    editor.addEventListener('input', () => {
      if (autosaveCheckbox.checked) {
        clearTimeout(saveTimeout);
        saveTimeout = setTimeout(() => save(false), 800);
        status.textContent = 'Editing...';
      } else {
        status.textContent = 'Unsaved';
      }
    });

    // manual save / open shortcuts
    document.addEventListener('keydown', (e) => {
      const mod = (navigator.platform && navigator.platform.includes && navigator.platform.includes('Mac')) ? e.metaKey : e.ctrlKey;
      if (mod && e.key && e.key.toLowerCase() === 's') {
        e.preventDefault();
        save();
      }
      if (mod && e.key && e.key.toLowerCase() === 'o') {
        e.preventDefault();
        fileInput.click();
      }
    });

    // download/export
    downloadBtn.addEventListener('click', () => {
      const blob = new Blob([editor.value], { type: 'text/plain;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.download = 'note.txt';
      a.href = url;
      a.click();
      URL.revokeObjectURL(url);
      showStatus('Downloaded');
    });

    // open/import
    openBtn.addEventListener('click', () => fileInput.click());
    fileInput.addEventListener('change', async (e) => {
      const f = e.target.files && e.target.files[0];
      if (!f) return;
      try {
        const text = await f.text();
        editor.value = text;
        save();
        fileInput.value = '';
        showStatus('Opened');
      } catch (err) {
        console.error('Failed to read file', err);
        showStatus('Open failed');
      }
    });

    newBtn.addEventListener('click', () => {
      if (editor.value.trim().length && !confirm('Discard current content and start new?')) return;
      editor.value = '';
      save();
    });

    clearBtn.addEventListener('click', () => {
      if (!confirm('Clear saved content permanently?')) return;
      editor.value = '';
      localStorage.removeItem(STORAGE_KEY);
      showStatus('Cleared');
    });

    // install prompt handling
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      deferredPrompt = e;
      installBtn.style.display = 'inline-block';
    });
    installBtn.addEventListener('click', async () => {
      if (!deferredPrompt) return;
      deferredPrompt.prompt();
      try {
        const choice = await deferredPrompt.userChoice;
        deferredPrompt = null;
        installBtn.style.display = 'none';
        showStatus(choice && choice.outcome === 'accepted' ? 'Installed' : 'Install dismissed');
      } catch (err) {
        deferredPrompt = null;
        installBtn.style.display = 'none';
      }
    });

    // register service worker
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('./sw.js')
        .then(() => console.log('Service worker registered'))
        .catch((err) => console.warn('SW register failed', err));
    }

    // initial load
    load();
  })();
  </script>
</body>
</html>
HTML

cat > "$DIR/style.css" <<'CSS'
/*
  pwa-editor/style.css
  CC0 1.0 Universal - https://creativecommons.org/publicdomain/zero/1.0/
  SPDX-License-Identifier: CC0-1.0
  See ./LICENSE for the full legal text.
*/
:root{
  --bg:#1e1e1e;
  --panel:#2b2b2b;
  --accent:#4fc3f7;
  --muted:#9e9e9e;
  --text:#eaeaea;
}

*{box-sizing:border-box}
html,body{height:100%;margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,"Helvetica Neue",Arial;color:var(--text);background:linear-gradient(180deg,var(--bg),#121212)}
.bar{display:flex;align-items:center;padding:8px 12px;background:var(--panel);gap:8px}
.bar.small{font-size:0.9rem;padding:6px 12px}
.left, .right{display:flex;align-items:center;gap:8px}
.center{flex:1;text-align:center;font-weight:600}
main{padding:12px;height:calc(100vh - 120px)}
textarea#editor{width:100%;height:100%;resize:none;padding:12px;border-radius:6px;border:1px solid rgba(255,255,255,0.03);background:#0f0f0f;color:var(--text);font-size:1rem;line-height:1.5;font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, "Roboto Mono", monospace}
button{background:transparent;border:1px solid rgba(255,255,255,0.06);color:var(--text);padding:6px 10px;border-radius:6px;cursor:pointer}
button:hover{border-color:var(--accent);color:var(--accent)}
.status{padding:4px 8px;border-radius:6px;background:transparent;border:1px solid rgba(255,255,255,0.04)}
.status.flash{box-shadow:0 0 8px rgba(79,195,247,0.15)}
.spacer{flex:1}
small{color:var(--muted)}
a{color:var(--accent)}
@media (max-width:520px){
  .center{display:none}
  main{padding:8px}
  textarea#editor{font-size:0.95rem}
}
CSS

cat > "$DIR/sw.js" <<'JS'
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
  './icons/icon.svg'
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
JS

cat > "$DIR/manifest.json" <<'JSON'
{
  "name": "PWA Text Editor",
  "short_name": "Editor",
  "description": "Minimal offline-capable progressive web app text editor",
  "start_url": "./index.html",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#2b2b2b",
  "license": "CC0-1.0",
  "license_url": "./LICENSE",
  "icons": [
    {
      "src": "./icons/icon.svg",
      "type": "image/svg+xml",
      "sizes": "any",
      "purpose": "any"
    },
    {
      "src": "./icons/icon.svg",
      "type": "image/svg+xml",
      "sizes": "192x192",
      "purpose": "maskable"
    }
  ]
}
JSON

cat > "$DIR/icons/icon.svg" <<'SVG'
<!--
  pwa-editor/icons/icon.svg
  CC0 1.0 Universal - https://creativecommons.org/publicdomain/zero/1.0/
  SPDX-License-Identifier: CC0-1.0
  See ../LICENSE for the full legal text.
-->
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2" y="3" width="20" height="18" rx="2" ry="2" fill="#2b2b2b"/>
  <path d="M8 7h8" stroke="#4fc3f7"/>
  <path d="M8 11h8" stroke="#cbeffd"/>
  <path d="M8 15h5" stroke="#9fe6ff"/>
</svg>
SVG

cat > "$DIR/README.md" <<'MD'
# pwa-editor

A minimal offline-capable Progressive Web App text editor.

License
-------
All files in this `pwa-editor/` folder are dedicated to the public domain under
CC0 1.0 Universal (CC0-1.0). See the included `LICENSE` file for the full legal text.

Installation (locally)
1. Copy the folder into your repository:
   - `cp -r pwa-editor /path/to/your/repo/`
2. Commit:
   - git add pwa-editor
   - git commit -m "Add PWA text editor in pwa-editor/ (CC0-1.0)"
   - git push

Serve and test locally
- From the repo root:
  - Python 3: `python -m http.server 8000`
  - Then open: `http://localhost:8000/pwa-editor/`

Notes
- Service worker scope is the folder it's placed in (`pwa-editor/sw.js`) so keep the folder intact.
- Icons are simple SVGs; you can replace them with PNGs for broader device support if needed.
- This folder's contents are public domain (CC0 1.0). If you'd prefer a different license or an additional header style, tell me and I will update the files.
MD

cat > "$DIR/LICENSE" <<'LICENSE'
CC0 1.0 Universal

CREATIVE COMMONS CORPORATION IS NOT A LAW FIRM AND DOES NOT PROVIDE
LEGAL SERVICES. DISTRIBUTION OF THIS DOCUMENT DOES NOT CREATE AN
ATTORNEY-CLIENT RELATIONSHIP. CREATIVE COMMONS PROVIDES THIS INFORMATION
ON AN "AS-IS" BASIS. CREATIVE COMMONS MAKES NO WARRANTIES REGARDING
THE USE OF THIS DOCUMENT OR THE INFORMATION OR WORKS PROVIDED HEREIN,
AND DISCLAIMS LIABILITY FOR DAMAGES RESULTING FROM ITS USE. 

Statement of Purpose

The person who associated a work with this deed has dedicated the work to
the public domain by waiving all of his or her rights to the work worldwide
under copyright law, including all related and neighboring rights, to the
extent allowed by law.

You can copy, modify, distribute and perform the work, even for
commercial purposes, all without asking permission.

In no event will the authors be liable for any damages arising from the use
of this work, nor will they assume any liabilities in connection with its
use.

---

CC0 1.0 Universal (CC0 1.0) Public Domain Dedication

The person who associated a work with this deed has dedicated the work to
the public domain by waiving all of his or her rights to the work worldwide
under copyright law, including all related and neighboring rights, to the
extent allowed by law.

You can copy, modify, distribute and perform the work, even for
commercial purposes, all without asking permission.

1. Copyright and Related Rights.

   A. Copyright and database rights (sometimes called sui generis database
   rights) are protected by law in most countries. Copyright and database
   rights cover original literary and artistic works such as books,
   poems, plays, films, musical works, drawings, photographs, software,
   databases, web site text and other literary and artistic works.

   B. Rights related to copyright include performance, broadcasting,
   sound recording, and moral rights, as well as publicity and privacy
   rights. Rights related to copyright vary widely by country. For
   example, in some countries moral rights are non-waivable, in others
   they can be waived.

   C. In some jurisdictions, copyright and database rights cannot be
   waived. If this is the case, the person who has associated the work
   with this deed may make a non-exclusive, worldwide, royalty-free,
   transferable license to use the Work consisting of all of the rights
   that are otherwise waived under this deed. 

2. Waiver.

   To the greatest extent permitted by, law, the person who has associated
   the work with this deed waives all copyright and related or neighboring
   rights to the work worldwide, including all moral rights to the extent
   possible.

3. Public License Fallback.

   If the waiver of all rights is not possible in a jurisdiction, the
   author grants anyone a license to use the work on the same terms as
   this deed, to the greatest extent permitted by law.

4. Limitations and Disclaimers.

   The dedication may not be effective in all jurisdictions. There is no
   warranty of any kind and the authors disclaim liability for all claims,
   damages, or other liabilities arising from the use or inability to use
   the work.

For more information, visit https://creativecommons.org/publicdomain/zero/1.0/
SPDX-License-Identifier: CC0-1.0
LICENSE

# create zip
zip -r -q "$ZIP" "$DIR"

echo "Created $ZIP (contents follow):"
zipinfo -1 "$ZIP"
shasum -a 256 "$ZIP"
echo "Done."