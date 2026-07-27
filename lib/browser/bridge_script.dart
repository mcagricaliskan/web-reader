/// The injected JavaScript half of the capture engine.
///
/// Design note (deliberate simplification for the PoC): rather than relying on
/// a persistent document-start injection surviving every navigation, every
/// bridge call ships this preamble in its own function body. It costs a few KB
/// per call — irrelevant next to a page load — and removes an entire class of
/// "the script was not there yet" bugs. The same source is *also* registered
/// as a document-start UserScript so `__wr` is available for hand-poking in
/// the Safari Web Inspector.
const String kBridgePreamble = r'''
window.__wr = window.__wr || (function () {
  function abs(u) {
    if (!u) return null;
    try { return new URL(u, document.baseURI).href; } catch (e) { return null; }
  }

  var CHROME_TAGS = { HEADER: 1, FOOTER: 1, NAV: 1, ASIDE: 1 };

  function inChrome(el) {
    var p = el.parentElement, depth = 0;
    while (p && depth < 15) {
      if (CHROME_TAGS[p.tagName]) return true;
      p = p.parentElement; depth++;
    }
    return false;
  }

  function isHidden(el, rect) {
    var cs = window.getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden') return true;
    if (parseFloat(cs.opacity || '1') === 0) return true;
    if (rect.width === 0 && rect.height === 0) return true;
    return false;
  }

  function lazyAttr(img) {
    var names = ['data-src', 'data-original', 'data-lazy-src', 'data-lazy',
                 'data-echo', 'data-url'];
    for (var i = 0; i < names.length; i++) {
      var v = img.getAttribute(names[i]);
      if (v) return v;
    }
    // Largest candidate from srcset, if that is all we have.
    var ss = img.getAttribute('data-srcset') || img.getAttribute('srcset');
    if (ss) {
      var parts = ss.split(',').map(function (s) { return s.trim().split(/\s+/)[0]; });
      if (parts.length) return parts[parts.length - 1];
    }
    return null;
  }

  function imgInfo(img, i) {
    var r = img.getBoundingClientRect();
    return {
      index: i,
      src: abs(img.getAttribute('src')),
      currentSrc: img.currentSrc || null,
      dataSrc: abs(lazyAttr(img)),
      complete: !!img.complete,
      naturalWidth: img.naturalWidth || 0,
      naturalHeight: img.naturalHeight || 0,
      renderedWidth: Math.round(r.width),
      renderedHeight: Math.round(r.height),
      attrWidth: parseInt(img.getAttribute('width') || '0', 10) || 0,
      attrHeight: parseInt(img.getAttribute('height') || '0', 10) || 0,
      top: Math.round(r.top + (window.scrollY || 0)),
      hidden: isHidden(img, r),
      chrome: inChrome(img),
      className: (typeof img.className === 'string' ? img.className : ''),
      alt: img.alt || ''
    };
  }

  function linkInfo(a) {
    var r = a.getBoundingClientRect();
    var p = a.parentElement, depth = 0, inNav = false;
    while (p && depth < 10) {
      if (p.tagName === 'NAV') { inNav = true; break; }
      var cls = (typeof p.className === 'string' ? p.className : '').toLowerCase();
      if (/(^|[-_ ])(nav|pager|pagination|chapter-?nav)([-_ ]|$)/.test(cls)) {
        inNav = true; break;
      }
      p = p.parentElement; depth++;
    }
    return {
      href: a.href || '',
      rel: (a.getAttribute('rel') || '').toLowerCase(),
      text: (a.textContent || '').trim().slice(0, 120),
      ariaLabel: (a.getAttribute('aria-label') || '').trim().slice(0, 120),
      title: (a.getAttribute('title') || '').trim().slice(0, 120),
      className: (typeof a.className === 'string' ? a.className : ''),
      id: a.id || '',
      imgAlt: (function () {
        var im = a.querySelector('img');
        return im ? (im.alt || '') : '';
      })(),
      inNav: inNav,
      top: Math.round(r.top + (window.scrollY || 0))
    };
  }

  function scroller() {
    // Some reader sites scroll an inner div rather than the document.
    var de = document.scrollingElement || document.documentElement;
    if (de && de.scrollHeight > de.clientHeight + 40) return de;
    var best = null, bestH = 0;
    var all = document.querySelectorAll('div,main,section,article');
    for (var i = 0; i < all.length && i < 400; i++) {
      var el = all[i];
      if (el.scrollHeight > el.clientHeight + 200 && el.clientHeight > 200) {
        var cs = window.getComputedStyle(el);
        if (cs.overflowY === 'auto' || cs.overflowY === 'scroll') {
          if (el.scrollHeight > bestH) { best = el; bestH = el.scrollHeight; }
        }
      }
    }
    return best || de;
  }

  function metrics() {
    var s = scroller();
    var isDoc = (s === document.scrollingElement || s === document.documentElement);
    var docH = isDoc
      ? Math.max(document.documentElement.scrollHeight, document.body ? document.body.scrollHeight : 0)
      : s.scrollHeight;
    var vpH = isDoc ? window.innerHeight : s.clientHeight;
    var y = isDoc ? (window.scrollY || document.documentElement.scrollTop || 0) : s.scrollTop;
    return { el: s, isDoc: isDoc, docH: docH, vpH: vpH, y: y };
  }

  function headNext() {
    var l = document.querySelector('link[rel~="next" i]');
    return l ? abs(l.getAttribute('href')) : null;
  }

  function meta(prop) {
    var el = document.querySelector('meta[property="' + prop + '"]') ||
             document.querySelector('meta[name="' + prop + '"]');
    return el ? (el.getAttribute('content') || '').trim() : '';
  }

  function pathOf(href) {
    try {
      var u = new URL(href, document.baseURI);
      if (u.host !== location.host) return null;
      var p = u.pathname.replace(/\/+$/, '');
      return { href: u.href, path: p || '/' };
    } catch (e) { return null; }
  }

  // Signals about which *series* this chapter belongs to. The most useful is
  // a same-host link pointing "up" from the chapter to its series index: its
  // path is the series and its text is the series name as the site writes it.
  function seriesHints() {
    var here = location.pathname.replace(/\/+$/, '') || '/';
    var seen = {};
    var prefixLinks = [];

    var anchors = Array.prototype.slice.call(
      document.querySelectorAll('a[href]')
    ).slice(0, 400);
    for (var i = 0; i < anchors.length; i++) {
      var a = anchors[i];
      var info = pathOf(a.getAttribute('href') || a.href);
      if (!info || info.path === '/' || info.path === here) continue;
      // Strict prefix of the current path: a link further up the same tree.
      if (here.indexOf(info.path + '/') !== 0) continue;
      if (seen[info.path]) continue;
      seen[info.path] = 1;
      prefixLinks.push({
        href: info.href,
        path: info.path,
        text: (a.textContent || '').trim().slice(0, 120)
      });
    }
    // Deepest first: the series index sits closer to the chapter than the
    // section or site root does.
    prefixLinks.sort(function (x, y) { return y.path.length - x.path.length; });

    var crumbs = [];
    var crumbNodes = document.querySelectorAll(
      '[itemtype*="Breadcrumb" i] a, .breadcrumb a, .breadcrumbs a, ' +
      'nav[aria-label*="bread" i] a'
    );
    for (var j = 0; j < crumbNodes.length && j < 12; j++) {
      var c = pathOf(crumbNodes[j].getAttribute('href') || crumbNodes[j].href);
      if (!c) continue;
      crumbs.push({
        href: c.href,
        path: c.path,
        text: (crumbNodes[j].textContent || '').trim().slice(0, 120)
      });
    }

    var h1 = document.querySelector('h1');
    return {
      ogTitle: meta('og:title'),
      ogSiteName: meta('og:site_name'),
      h1: h1 ? (h1.textContent || '').trim().slice(0, 200) : '',
      breadcrumbs: crumbs,
      prefixLinks: prefixLinks.slice(0, 8)
    };
  }

  function canonical() {
    var l = document.querySelector('link[rel="canonical" i]');
    return l ? abs(l.getAttribute('href')) : null;
  }

  return {
    version: 1,

    probe: function (opts) {
      opts = opts || {};
      var m = metrics();
      var allImgs = Array.prototype.slice.call(document.images || []);
      var IMG_CAP = (opts.imageCap || 800);
      var imgs = allImgs.slice(0, IMG_CAP);
      var out = {
        url: location.href,
        title: document.title || '',
        canonicalUrl: canonical(),
        readyState: document.readyState,
        documentHeight: m.docH,
        viewportHeight: m.vpH,
        scrollY: m.y,
        atBottom: (m.y + m.vpH) >= (m.docH - 8),
        headNextHref: headNext(),
        imageCount: allImgs.length,
        imagesTruncated: allImgs.length > IMG_CAP,
        images: imgs.map(imgInfo)
      };
      if (opts.withLinks) {
        var as = Array.prototype.slice.call(document.querySelectorAll('a[href]'));
        out.links = as.slice(0, 500).map(linkInfo);
        out.seriesHints = seriesHints();
      }
      return out;
    },

    scrollStep: function (dy) {
      var m = metrics();
      var target = m.y + dy;
      if (m.isDoc) { window.scrollTo(0, target); }
      else { m.el.scrollTop = target; }
      var after = metrics();
      return {
        scrollY: after.y,
        documentHeight: after.docH,
        viewportHeight: after.vpH,
        atBottom: (after.y + after.vpH) >= (after.docH - 8)
      };
    },

    scrollTo: function (y) {
      var m = metrics();
      if (m.isDoc) { window.scrollTo(0, y); } else { m.el.scrollTop = y; }
      var after = metrics();
      return { scrollY: after.y, documentHeight: after.docH };
    },


    // --- user-assisted selection -----------------------------------------
    // The user points at the real control when automatic detection is not
    // confident. Clicks are swallowed in capture phase so the page cannot
    // navigate out from under the picker.

    startSelection: function (mode) {
      var self = this;
      this.stopSelection();
      var state = { mode: mode || 'link', last: null, picked: null };
      window.__wrSel = state;

      var style = document.createElement('style');
      style.id = '__wr_sel_style';
      style.textContent =
        '.__wr_hi{outline:3px solid #ff3b30 !important;outline-offset:2px !important;' +
        'background:rgba(255,59,48,.12) !important;}' +
        '.__wr_hi_c{outline:3px solid #34c759 !important;outline-offset:2px !important;}';
      document.documentElement.appendChild(style);

      function target(e) {
        var el = e.target;
        if (!el || el.nodeType !== 1) return null;
        if (state.mode === 'link') {
          var a = el.closest('a[href], button, [role="button"]');
          return a || el;
        }
        return el;
      }

      state.over = function (e) {
        var el = target(e);
        if (!el || el === state.last) return;
        if (state.last) state.last.classList.remove('__wr_hi');
        state.last = el;
        el.classList.add('__wr_hi');
      };

      state.swallow = function (e) {
        var el = target(e);
        if (!el) return;
        e.preventDefault();
        e.stopPropagation();
        if (e.stopImmediatePropagation) e.stopImmediatePropagation();
        if (state.last) state.last.classList.remove('__wr_hi');
        el.classList.add('__wr_hi_c');
        state.picked = el;
        state.last = el;
        try {
          window.flutter_inappwebview.callHandler(
            'webread.selection', self.describe(el, state.mode));
        } catch (err) {}
      };

      ['click', 'mousedown', 'mouseup', 'touchstart', 'touchend', 'pointerdown',
       'pointerup', 'submit'].forEach(function (t) {
        document.addEventListener(t, state.swallow, true);
      });
      ['mousemove', 'pointermove'].forEach(function (t) {
        document.addEventListener(t, state.over, true);
      });
      return { ok: true, mode: state.mode };
    },

    stopSelection: function () {
      var state = window.__wrSel;
      if (state) {
        ['click', 'mousedown', 'mouseup', 'touchstart', 'touchend',
         'pointerdown', 'pointerup', 'submit'].forEach(function (t) {
          document.removeEventListener(t, state.swallow, true);
        });
        ['mousemove', 'pointermove'].forEach(function (t) {
          document.removeEventListener(t, state.over, true);
        });
      }
      window.__wrSel = null;
      var st = document.getElementById('__wr_sel_style');
      if (st && st.parentNode) st.parentNode.removeChild(st);
      Array.prototype.slice.call(
        document.querySelectorAll('.__wr_hi, .__wr_hi_c')
      ).forEach(function (el) {
        el.classList.remove('__wr_hi');
        el.classList.remove('__wr_hi_c');
      });
      return { ok: true };
    },

    // Class tokens that look hand-written rather than generated. Hashed and
    // atomic-utility names are skipped: they look precise and break on the
    // next deploy.
    stableClasses: function (el) {
      var raw = (typeof el.className === 'string' ? el.className : '');
      return raw.split(/\s+/).filter(function (c) {
        if (!c || c.length < 3 || c.length > 30) return false;
        if (c.indexOf('__wr_') === 0) return false;
        if (/\d{4,}/.test(c)) return false;           // hashed
        if (/^[a-z]+-\[/.test(c)) return false;       // tailwind arbitrary
        if (/^(css|sc|jsx|emotion)-/.test(c)) return false;
        if (/^[a-f0-9]{6,}$/i.test(c)) return false;
        return true;
      }).slice(0, 3);
    },

    // A conservative selector, or null. Never a long nth-child chain and never
    // a generated-looking id — a rule that pretends to be stable is worse than
    // one that admits it has few signals.
    selectorFor: function (el) {
      var tag = el.tagName.toLowerCase();
      if (el.id && !/\d{4,}/.test(el.id) && el.id.length < 40) {
        return tag + '#' + CSS.escape(el.id);
      }
      var cls = this.stableClasses(el);
      if (cls.length) {
        return tag + '.' + cls.map(function (c) { return CSS.escape(c); }).join('.');
      }
      var rel = el.getAttribute && el.getAttribute('rel');
      if (rel) return tag + '[rel~="' + rel.split(/\s+/)[0] + '"]';
      return null;
    },

    containerFor: function (el) {
      var p = el.parentElement, depth = 0;
      while (p && depth < 6) {
        var cls = this.stableClasses(p);
        if (p.tagName === 'NAV') return 'nav';
        if (cls.length) return p.tagName.toLowerCase() + '.' + cls[0];
        p = p.parentElement; depth++;
      }
      return null;
    },

    describe: function (el, mode) {
      var a = (el.tagName === 'A') ? el : el.closest('a[href]');
      var rect = el.getBoundingClientRect();
      var out = {
        mode: mode || 'link',
        tag: el.tagName.toLowerCase(),
        text: (el.textContent || '').trim().slice(0, 120),
        ariaLabel: (el.getAttribute('aria-label') || '').trim().slice(0, 120),
        title: (el.getAttribute('title') || '').trim().slice(0, 120),
        id: el.id || '',
        classes: this.stableClasses(el).join(' '),
        rawClasses: (typeof el.className === 'string' ? el.className : '').slice(0, 200),
        rel: (el.getAttribute('rel') || '').toLowerCase(),
        href: a ? (a.href || '') : '',
        imgAlt: (function () { var im = el.querySelector && el.querySelector('img'); return im ? (im.alt || '') : ''; })(),
        selector: this.selectorFor(a || el),
        containerSelector: this.containerFor(a || el),
        parentTag: el.parentElement ? el.parentElement.tagName.toLowerCase() : '',
        outerHtml: (el.outerHTML || '').slice(0, 300),
        width: Math.round(rect.width),
        height: Math.round(rect.height)
      };
      if (mode === 'reader') {
        var imgs = Array.prototype.slice.call(el.querySelectorAll('img'));
        var sizes = imgs.map(function (i) {
          return Math.min(i.naturalWidth || 0, i.naturalHeight || 0);
        }).filter(function (n) { return n > 0; });
        out.imageCount = imgs.length;
        out.minImageEdge = sizes.length ? Math.min.apply(null, sizes) : 0;
        out.imageSelector = imgs.length ? 'img' : null;
      }
      return out;
    },

    // Score every link against a saved locator's independent signals and
    // return the best, or null when nothing scores well enough.
    applyLocator: function (loc) {
      loc = loc || {};
      var links = Array.prototype.slice.call(document.querySelectorAll('a[href]'));
      var best = null, bestScore = 0, hits = 0, bestWhy = [];
      var pattern = null;
      if (loc.hrefPattern) {
        try { pattern = new RegExp(loc.hrefPattern); } catch (e) { pattern = null; }
      }

      for (var i = 0; i < links.length; i++) {
        var a = links[i];
        var score = 0, why = [];

        if (loc.rel && (a.getAttribute('rel') || '').toLowerCase().indexOf(loc.rel) >= 0) {
          score += 5; why.push('rel');
        }
        if (loc.cssSelector) {
          try { if (a.matches(loc.cssSelector)) { score += 4; why.push('selector'); } } catch (e) {}
        }
        if (pattern) {
          try {
            var path = new URL(a.href, document.baseURI).pathname;
            if (pattern.test(path)) { score += 4; why.push('hrefPattern'); }
          } catch (e) {}
        }
        if (loc.linkText) {
          var t = (a.textContent || '').trim().toLowerCase();
          if (t && t === loc.linkText.toLowerCase()) { score += 3; why.push('text'); }
        }
        if (loc.ariaLabel) {
          var al = (a.getAttribute('aria-label') || '').trim().toLowerCase();
          if (al && al === loc.ariaLabel.toLowerCase()) { score += 3; why.push('aria'); }
        }
        if (loc.titleAttr) {
          var ti = (a.getAttribute('title') || '').trim().toLowerCase();
          if (ti && ti === loc.titleAttr.toLowerCase()) { score += 2; why.push('title'); }
        }
        if (loc.imgAlt) {
          var im = a.querySelector('img');
          if (im && (im.alt || '').trim().toLowerCase() === loc.imgAlt.toLowerCase()) {
            score += 2; why.push('imgAlt');
          }
        }
        if (loc.containerSelector) {
          try {
            if (a.closest(loc.containerSelector)) { score += 2; why.push('container'); }
          } catch (e) {}
        }

        if (score > bestScore) { bestScore = score; best = a; hits = 1; bestWhy = why; }
        else if (score === bestScore && score > 0) { hits++; }
      }
      if (!best || bestScore < 4) {
        return { ok: false, score: bestScore, reason: 'no element matched the saved rule' };
      }
      return {
        ok: true,
        href: best.href,
        score: bestScore,
        ambiguous: hits > 1,
        matched: bestWhy.join('+')
      };
    },

    // Images inside a user-selected reader container.
    applyReaderRule: function (rule) {
      rule = rule || {};
      var root = null;
      if (rule.containerSelector) {
        try { root = document.querySelector(rule.containerSelector); } catch (e) {}
      }
      if (!root) return { ok: false, reason: 'reader container not found' };

      var sel = rule.imageSelector || 'img';
      var imgs = Array.prototype.slice.call(root.querySelectorAll(sel));
      var excludes = rule.excludeSelectors || [];
      var minEdge = rule.minImageEdge || 0;

      var out = [];
      for (var i = 0; i < imgs.length; i++) {
        var img = imgs[i];
        var skip = false;
        for (var j = 0; j < excludes.length; j++) {
          try { if (img.matches(excludes[j]) || img.closest(excludes[j])) { skip = true; break; } } catch (e) {}
        }
        if (skip) continue;
        var info = imgInfo(img, i);
        var w = info.naturalWidth || info.attrWidth || info.renderedWidth;
        var h = info.naturalHeight || info.attrHeight || info.renderedHeight;
        if (minEdge && (w < minEdge || h < minEdge)) continue;
        out.push(info);
      }
      return { ok: true, images: out };
    },

    // Read bytes through the page so the request carries the page's own
    // credentials, Referer and cache context. Cross-origin CDNs without CORS
    // headers will reject this — that limitation is documented, not worked
    // around.
    fetchAsBase64: function (url) {
      return fetch(url, { credentials: 'include' })
        .then(function (r) {
          if (!r.ok) throw new Error('http ' + r.status);
          return r.blob();
        })
        .then(function (b) {
          return new Promise(function (resolve, reject) {
            var fr = new FileReader();
            fr.onload = function () {
              var s = String(fr.result);
              var comma = s.indexOf(',');
              resolve({ ok: true, mime: b.type || '', data: s.slice(comma + 1) });
            };
            fr.onerror = function () { reject(new Error('read failed')); };
            fr.readAsDataURL(b);
          });
        })
        .catch(function (e) { return { ok: false, error: String(e) }; });
    }
  };
})();
''';

/// Call bodies. Each is prefixed with [kBridgePreamble] by the controller.
const String kCallProbe = 'return window.__wr.probe({withLinks: false});';
const String kCallProbeWithLinks =
    'return window.__wr.probe({withLinks: true});';
const String kCallScrollStep = 'return window.__wr.scrollStep(dy);';
const String kCallScrollTo = 'return window.__wr.scrollTo(y);';
const String kCallFetchBase64 = 'return await window.__wr.fetchAsBase64(url);';
const String kCallStartSelection = 'return window.__wr.startSelection(mode);';
const String kCallStopSelection = 'return window.__wr.stopSelection();';
const String kCallApplyLocator = 'return window.__wr.applyLocator(locator);';
const String kCallApplyReaderRule = 'return window.__wr.applyReaderRule(rule);';
