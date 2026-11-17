import { chromium } from 'playwright';
import AxeBuilder from '@axe-core/playwright';
import fs from 'fs';
const START = process.env.SITE || 'https://starskyaviation.co.uk/';
const OUT = 'out';
fs.mkdirSync(`${OUT}/shots`, { recursive: true });
fs.mkdirSync(`${OUT}/html`, { recursive: true });
const host = new URL(START).hostname.replace(/^www\./, '');
const MAX = 40;
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36 SiteAudit' });
const queue = [START]; const seen = new Set(); const pages = []; const allLinks = new Map();
const norm = u => { try { const x = new URL(u); x.hash=''; return x.href; } catch { return null; } };
while (queue.length && pages.length < MAX) {
  const url = queue.shift(); if (seen.has(url)) continue; seen.add(url);
  const page = await ctx.newPage();
  const consoleErr = [], failed = [], reqs = [];
  page.on('console', m => { if (m.type() === 'error' || m.type()==='warning') consoleErr.push(`${m.type()}: ${m.text()}`.slice(0,400)); });
  page.on('pageerror', e => consoleErr.push('pageerror: ' + e.message.slice(0,400)));
  page.on('requestfailed', r => failed.push(`${r.url()} ${r.failure()?.errorText}`));
  page.on('response', r => { reqs.push({ url: r.url(), status: r.status(), type: r.request().resourceType(), size: Number(r.headers()['content-length']||0) }); });
  let status = null, t0 = Date.now();
  try { const resp = await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 }); status = resp?.status(); } catch (e) { status = 'ERR ' + e.message.slice(0,200); }
  const loadMs = Date.now() - t0;
  let info = {};
  try {
    info = await page.evaluate(() => {
      const q = s => [...document.querySelectorAll(s)];
      const meta = n => document.querySelector(`meta[name="${n}"],meta[property="${n}"]`)?.content || null;
      return {
        title: document.title, metaDescription: meta('description'), robots: meta('robots'), viewport: meta('viewport'), generator: meta('generator'),
        canonical: document.querySelector('link[rel=canonical]')?.href || null, lang: document.documentElement.lang,
        og: { title: meta('og:title'), description: meta('og:description'), image: meta('og:image'), type: meta('og:type') },
        twitter: meta('twitter:card'), favicon: document.querySelector('link[rel*=icon]')?.href || null,
        h1: q('h1').map(e => e.innerText.trim()), h2: q('h2').map(e => e.innerText.trim()).slice(0,30), h3: q('h3').map(e=>e.innerText.trim()).slice(0,30),
        jsonld: q('script[type="application/ld+json"]').map(s => s.textContent.slice(0,1500)),
        images: q('img').length, imgNoAlt: q('img').filter(i => !i.hasAttribute('alt') || !i.alt.trim()).map(i=>i.currentSrc||i.src).slice(0,30),
        imgNoLazy: q('img').filter(i=>i.loading!=='lazy').length,
        bigImages: q('img').filter(i=>i.naturalWidth > 2*i.clientWidth && i.clientWidth>0).map(i=>`${i.currentSrc} natural ${i.naturalWidth} shown ${i.clientWidth}`).slice(0,20),
        forms: q('form').map(f => ({ action: f.action, method: f.method, fields: [...f.elements].map(e=>`${e.tagName}:${e.type}:${e.name}:${e.labels?.length?'label':'nolabel'}`), captcha: !!f.querySelector('[class*=captcha],[class*=recaptcha],iframe[src*=recaptcha],[class*=turnstile]') })),
        links: q('a[href]').map(a => ({ href: a.href, text: a.innerText.trim().slice(0,80), target: a.target, rel: a.rel })),
        scripts: q('script[src]').map(s => s.src), styles: q('link[rel=stylesheet]').map(l=>l.href),
        iframes: q('iframe').map(f=>f.src),
        tel: q('a[href^="tel:"]').map(a=>a.href), mail: q('a[href^="mailto:"]').map(a=>a.href),
        text: document.body.innerText.slice(0, 12000), wordCount: document.body.innerText.split(/\s+/).length,
        nav: q('nav a, header a').map(a=>`${a.innerText.trim()} -> ${a.href}`).slice(0,80),
        footer: document.querySelector('footer')?.innerText.slice(0,3000) || null,
        cookieBanner: !!document.querySelector('[id*=cookie i],[class*=cookie i],[id*=consent i],[class*=consent i]'),
        domNodes: document.getElementsByTagName('*').length,
        bodyClass: document.body.className, htmlHead: document.head.innerHTML.slice(0, 20000),
      };
    });
    const cookies = await ctx.cookies(url);
    info.cookies = cookies.map(c => ({ name: c.name, domain: c.domain, secure: c.secure, httpOnly: c.httpOnly, sameSite: c.sameSite }));
    fs.writeFileSync(`${OUT}/html/${pages.length}.html`, await page.content());
  } catch (e) { info.evalError = e.message; }
  const idx = pages.length;
  pages.push({ idx, url, finalUrl: page.url(), status, loadMs, consoleErr, failed, requests: reqs.length,
    badResponses: reqs.filter(r=>r.status>=400).map(r=>`${r.status} ${r.url}`), thirdParty: [...new Set(reqs.map(r=>new URL(r.url).hostname).filter(h=>!h.endsWith(host)))],
    transferBytes: reqs.reduce((a,r)=>a+r.size,0), ...info });
  for (const l of info.links || []) { const n = norm(l.href); if (!n) continue; allLinks.set(n, (allLinks.get(n)||new Set()).add(url));
    try { const u = new URL(n); if (u.hostname.replace(/^www\./,'')===host && /^https?:$/.test(u.protocol) && !/\.(pdf|jpg|jpeg|png|webp|zip|docx?)$/i.test(u.pathname) && !seen.has(n) && !queue.includes(n)) queue.push(n); } catch {} }
  await page.close();
  console.log(idx, status, url, loadMs+'ms');
}
fs.writeFileSync(`${OUT}/pages.json`, JSON.stringify(pages, null, 1));
// broken link check (internal + external) via HEAD/GET
const linkResults = [];
for (const [l, from] of allLinks) { if (!/^https?:/.test(l)) continue;
  let s; try { let r = await fetch(l, { method: 'HEAD', redirect: 'follow', signal: AbortSignal.timeout(15000) }); if (r.status>=400) r = await fetch(l, { redirect:'follow', signal: AbortSignal.timeout(15000) }); s = r.status; } catch (e) { s = 'ERR ' + e.message; }
  linkResults.push({ link: l, status: s, from: [...from].slice(0,5) }); }
fs.writeFileSync(`${OUT}/links.json`, JSON.stringify(linkResults, null, 1));
// screenshots + responsiveness + axe
const shotUrls = pages.slice(0, 8).map(p => p.url);
const vps = { mobile: { width: 375, height: 812 }, tablet: { width: 768, height: 1024 }, laptop: { width: 1366, height: 768 }, desktop: { width: 1920, height: 1080 } };
const resp = [];
for (const [i, u] of shotUrls.entries()) for (const [name, vp] of Object.entries(vps)) {
  const c = await browser.newContext({ viewport: vp, deviceScaleFactor: 1, isMobile: name==='mobile', hasTouch: name!=='desktop' && name!=='laptop' });
  const p = await c.newPage();
  try { await p.goto(u, { waitUntil: 'networkidle', timeout: 60000 }); await p.waitForTimeout(1500);
    const r = await p.evaluate(() => { const vw = document.documentElement.clientWidth;
      const over = [...document.querySelectorAll('body *')].filter(e => { const b = e.getBoundingClientRect(); return b.width>0 && (b.right > vw + 2); }).slice(0,15).map(e => `${e.tagName.toLowerCase()}.${(e.className+'').slice(0,60)} right=${Math.round(e.getBoundingClientRect().right)}`);
      const small = [...document.querySelectorAll('a,button,input,select')].filter(e => { const b = e.getBoundingClientRect(); return b.width>0 && b.height>0 && (b.height<24 || b.width<24); }).length;
      const tinyText = [...document.querySelectorAll('p,li,span,a')].filter(e => e.innerText?.trim() && parseFloat(getComputedStyle(e).fontSize) < 12).length;
      return { scrollWidth: document.documentElement.scrollWidth, vw, overflow: over, smallTapTargets: small, tinyText, height: document.documentElement.scrollHeight }; });
    resp.push({ url: u, vp: name, ...r });
    await p.screenshot({ path: `${OUT}/shots/p${i}-${name}-fold.png` });
    await p.screenshot({ path: `${OUT}/shots/p${i}-${name}-full.png`, fullPage: true });
    if (name === 'desktop' || name === 'mobile') { const ax = await new AxeBuilder({ page: p }).analyze();
      fs.writeFileSync(`${OUT}/axe-p${i}-${name}.json`, JSON.stringify(ax.violations.map(v => ({ id: v.id, impact: v.impact, help: v.help, count: v.nodes.length, sample: v.nodes.slice(0,3).map(n=>n.target.join(' ')+' | '+n.html.slice(0,150)) })), null, 1)); }
  } catch (e) { resp.push({ url: u, vp: name, error: e.message }); }
  await c.close();
}
fs.writeFileSync(`${OUT}/responsive.json`, JSON.stringify(resp, null, 1));
await browser.close();
