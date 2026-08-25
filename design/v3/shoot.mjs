/**
 * Renders every Sijil Obsidian screen to PNG.
 *
 * The screens are NOT redefined here. The stylesheet and the render script are
 * lifted straight out of sijil-obsidian.html, so a change to the design shows up
 * in the exported images the next time this runs — there is one source of truth.
 *
 *   node design/v3/shoot.mjs
 */
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SOURCE = join(HERE, 'sijil-obsidian.html');
const BUILD = join(HERE, '.build');
const OUT = join(HERE, 'shots');

const CHROME = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
].find(p => { try { readFileSync(p); return true; } catch { return false; } });
if (!CHROME) throw new Error('No Chrome or Edge found.');

/* ---------- lift the design out of the page ---------- */
const page = readFileSync(SOURCE, 'utf8');

function between(open, close, from = 0) {
  const a = page.indexOf(open, from);
  if (a < 0) throw new Error(`missing ${open}`);
  const b = page.indexOf(close, a);
  if (b < 0) throw new Error(`missing ${close}`);
  return { text: page.slice(a + open.length, b), end: b + close.length };
}
const fonts = page.match(/<link rel="stylesheet" href="https:\/\/fonts[^>]*>/)[0];
const css = between('<style>', '</style>').text;
const js = between('<script>', '</script>').text;

/* ---------- one phone, nothing else ---------- */
const SHOT = `<!doctype html><html><head><meta charset="utf-8">${fonts}
<style>${css}
html,body{margin:0;padding:0;}
body{display:flex;align-items:center;justify-content:center;min-height:100vh;padding:28px;background:var(--shot-bg);}
body[data-app="dark"]{--shot-bg:#05091A;}
body[data-app="light"]{--shot-bg:#E9EDF6;}
.bar,.mast,.wrap{display:none!important;}
</style></head><body>
<div class="pf"><div class="pf-in" id="one"></div></div>
<script>${js}<\/script>
<script>
  const q = new URLSearchParams(location.search);
  state.lang = q.get('lang') || 'ar';
  state.app  = q.get('app')  || 'dark';
  document.body.dataset.lang = state.lang;
  document.body.dataset.app  = state.app;
  document.getElementById('one').innerHTML = S[q.get('s') || 'home'](DICT[state.lang]);
<\/script></body></html>`;

/* ---------- all of them at once, for a contact sheet ---------- */
const ORDER = ['connect', 'login', 'home', 'assets', 'detail', 'repair',
               'audit', 'handover', 'history', 'scan', 'more'];
const TITLE = {
  ar: { connect: '١ · الاتصال بالسيرفر', login: '٢ · تسجيل الدخول', home: '٣ · الرئيسية',
        assets: '٤ · الأصول', detail: '٥ · تفاصيل الأصل', repair: '٦ · الصيانة والصور',
        audit: '٧ · وضع الجرد', handover: '٨ · التسليم والتوقيع', history: '٩ · سجل الحركة',
        scan: '١٠ · المسح', more: '١١ · المزيد' },
  en: { connect: '1 · Connect', login: '2 · Sign in', home: '3 · Home', assets: '4 · Assets',
        detail: '5 · Asset detail', repair: '6 · Repair + photos', audit: '7 · Audit mode',
        handover: '8 · Handover', history: '9 · History', scan: '10 · Scan', more: '11 · More' },
};

const SHEET = `<!doctype html><html><head><meta charset="utf-8">${fonts}
<style>${css}
html,body{margin:0;padding:0;}
body{background:var(--shot-bg);padding:44px;}
body[data-app="dark"]{--shot-bg:#05091A;--cap:#8E9AC4;}
body[data-app="light"]{--shot-bg:#E9EDF6;--cap:#5A6790;}
.bar,.mast,.wrap{display:none!important;}
.sheet{display:grid;grid-template-columns:repeat(4,390px);gap:52px 40px;justify-content:center;}
.cell{display:flex;flex-direction:column;gap:14px;align-items:center;}
.cap{font-family:var(--ar);font-size:16px;font-weight:700;color:var(--cap);}
.head{text-align:center;margin-bottom:46px;font-family:var(--sans);}
.head .t{font-size:52px;font-weight:900;letter-spacing:-.04em;color:#F3F6FD;}
body[data-app="light"] .head .t{color:#101A38;}
.head .s{font-family:var(--ar);font-size:19px;color:var(--cap);margin-top:8px;}
</style></head><body>
<div class="head"><div class="t">Sijil Obsidian</div><div class="s" id="sub"></div></div>
<div class="sheet" id="sheet"></div>
<script>${js}<\/script>
<script>
  const ORDER = ${JSON.stringify(ORDER)};
  const TITLE = ${JSON.stringify(TITLE)};
  const q = new URLSearchParams(location.search);
  state.lang = q.get('lang') || 'ar';
  state.app  = q.get('app')  || 'dark';
  document.body.dataset.lang = state.lang;
  document.body.dataset.app  = state.app;
  document.getElementById('sub').textContent =
    state.lang === 'ar' ? 'تطبيق سِجل لإدارة أصول الـ IT · ١١ شاشة'
                        : 'Sijil IT asset management · 11 screens';
  document.getElementById('sheet').innerHTML = ORDER.map(id =>
    '<div class="cell"><div class="pf"><div class="pf-in">' + S[id](DICT[state.lang]) +
    '</div></div><div class="cap">' + TITLE[state.lang][id] + '</div></div>').join('');
<\/script></body></html>`;

rmSync(BUILD, { recursive: true, force: true });
mkdirSync(BUILD, { recursive: true });
writeFileSync(join(BUILD, 'shot.html'), SHOT, 'utf8');
writeFileSync(join(BUILD, 'sheet.html'), SHEET, 'utf8');

/* ---------- capture ---------- */
function capture(file, out, w, h) {
  mkdirSync(dirname(out), { recursive: true });
  execFileSync(CHROME, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars',
    '--force-device-scale-factor=2',
    `--window-size=${w},${h}`,
    `--screenshot=${resolve(out)}`,
    '--virtual-time-budget=9000',
    file,
  ], { stdio: 'pipe' });
}

const url = (f, p) => `${pathToFileURL(join(BUILD, f)).href}?${new URLSearchParams(p)}`;
const PHONE_W = 390 + 12 + 56;   // screen + bezel + padding
const PHONE_H = 844 + 12 + 56;

rmSync(OUT, { recursive: true, force: true });

const VARIANTS = [
  { lang: 'ar', app: 'dark',  dir: 'عربي-داكن' },
  { lang: 'ar', app: 'light', dir: 'عربي-فاتح' },
  { lang: 'en', app: 'dark',  dir: 'english-dark' },
];

for (const v of VARIANTS) {
  ORDER.forEach((s, i) => {
    const n = String(i + 1).padStart(2, '0');
    capture(url('shot.html', { s, lang: v.lang, app: v.app }),
            join(OUT, v.dir, `${n}-${s}.png`), PHONE_W, PHONE_H);
    process.stdout.write(`  ${v.dir}/${n}-${s}.png\n`);
  });
  capture(url('sheet.html', { lang: v.lang, app: v.app }),
          join(OUT, `الكل-${v.dir}.png`), 4 * 390 + 3 * 40 + 88, 3 * 940 + 200);
  process.stdout.write(`  الكل-${v.dir}.png\n`);
}

rmSync(BUILD, { recursive: true, force: true });
console.log('\nDone →', OUT);
