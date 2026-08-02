/// The injected JavaScript half of the save engine.
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

  // Generic structural words that name page furniture in every language's
  // worth of markup conventions. These are word-boundary matches against class
  // and id tokens — the same technique `linkInfo` already uses for pagers —
  // and NOT a site list: no hostname, no provider, no selector that only makes
  // sense on one website. A page that names its main column "comments" loses
  // some blocks; a page that names its advert rail "content" keeps some. Both
  // are acceptable next to the alternative, which is saving a reader's
  // offline copy full of subscribe boxes.
  var CHROME_WORDS = new RegExp(
    '(^|[-_ ])(' +
    'comment|comments|commentaires|kommentar|yorum|' +
    'ad|ads|advert|adverts|advertisement|sponsor|sponsored|promo|promotion|' +
    'sidebar|side-?bar|aside|widget|' +
    'related|recommend|recommended|recommendation|recirc|more-?from|read-?next|' +
    'share|sharing|social|follow|subscribe|newsletter|signup|paywall|' +
    'nav|navbar|navigation|menu|breadcrumb|breadcrumbs|pager|pagination|' +
    'header|footer|masthead|toolbar|banner|cookie|consent|modal|popup|overlay|' +
    'skip-?link|screen-?reader|visually-?hidden|sr-?only' +
    ')([-_ ]|$)', 'i');

  function namedAsChrome(el) {
    var cls = (typeof el.className === 'string' ? el.className : '');
    if (cls && CHROME_WORDS.test(cls)) return true;
    if (el.id && CHROME_WORDS.test(el.id)) return true;
    var role = el.getAttribute && el.getAttribute('role');
    if (role === 'navigation' || role === 'complementary' ||
        role === 'banner' || role === 'contentinfo' || role === 'search') {
      return true;
    }
    return false;
  }

  function inChrome(el) {
    var p = el.parentElement, depth = 0;
    while (p && depth < 15) {
      if (CHROME_TAGS[p.tagName]) return true;
      p = p.parentElement; depth++;
    }
    return false;
  }

  /// Chrome by tag OR by the generic naming above, including the element
  /// itself. Used for document extraction, where a comments section is worth
  /// excluding even when it is not wrapped in an <aside>.
  function isFurniture(el) {
    var p = el, depth = 0;
    while (p && depth < 15) {
      if (CHROME_TAGS[p.tagName]) return true;
      if (namedAsChrome(p)) return true;
      if (p.getAttribute && p.getAttribute('aria-hidden') === 'true') return true;
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
      if (/(^|[-_ ])(nav|pager|pagination|entry-?nav)([-_ ]|$)/.test(cls)) {
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

  // Signals about which *collection* this entry belongs to. The most useful is
  // a same-host link pointing "up" from the entry to its collection index: its
  // path is the collection and its text is the collection name as the site writes it.
  function pageHints() {
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
    // Deepest first: the collection index sits closer to the entry than the
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


  // --- content and access signals ------------------------------------------
  // Everything below is generic and structural. There is no hostname test and
  // no site-specific selector anywhere in this file: the signals are standard
  // HTML semantics (rel, <article>, <time>, aria roles, form input types) plus
  // measurements a browser can always make. That is what lets the same code
  // read a blog, a documentation page and an image gallery.

  function visibleText(root) {
    var el = root || document.body;
    if (!el) return '';
    var clone = el.cloneNode(true);
    var drop = clone.querySelectorAll('script,style,noscript,template,nav,header,footer,aside');
    for (var i = 0; i < drop.length; i++) {
      if (drop[i].parentNode) drop[i].parentNode.removeChild(drop[i]);
    }
    return (clone.textContent || '').replace(/\s+/g, ' ').trim();
  }

  /// The part of the page a reader would actually read.
  ///
  /// Standard landmarks first, because a page that declares one is telling us
  /// the answer. Only when there is none does this fall back to measuring:
  /// the container holding the most direct paragraph text, which is the same
  /// "count what is there" approach used everywhere else in this file. The
  /// basis is returned so a wrong region is explainable rather than mysterious.
  function readableRegion() {
    function usable(el) {
      if (!el) return false;
      return visibleText(el).length >= 200;
    }

    var el = document.querySelector('article');
    if (usable(el)) return { el: el, basis: 'article element' };

    el = document.querySelector('main') || document.querySelector('[role=main]');
    if (usable(el)) return { el: el, basis: 'main landmark' };

    // Densest container: most text sitting in its own direct <p> children.
    var best = null, bestScore = 0;
    var candidates = document.querySelectorAll('div,section,article,main');
    for (var i = 0; i < candidates.length && i < 600; i++) {
      var c = candidates[i];
      if (isFurniture(c)) continue;
      var score = 0, kids = c.children, paras = 0;
      for (var k = 0; k < kids.length; k++) {
        if (kids[k].tagName !== 'P') continue;
        paras++;
        score += (kids[k].textContent || '').trim().length;
      }
      if (paras >= 2 && score > bestScore) { bestScore = score; best = c; }
    }
    if (best && bestScore >= 200) {
      return { el: best, basis: 'densest paragraph container' };
    }
    return { el: document.body, basis: 'whole document' };
  }

  /// Structural description of the document. No subject matter, no genre.
  function contentSignals() {
    var region = readableRegion();
    var text = visibleText(region.el);
    var paragraphs = document.querySelectorAll('article p, main p, [role=main] p, p');
    var pixels = 0, imageCount = 0;
    var regionPixels = 0, regionCount = 0;
    var imgs = document.images || [];
    for (var i = 0; i < imgs.length; i++) {
      var im = imgs[i];
      var w = im.naturalWidth || im.width || 0;
      var h = im.naturalHeight || im.height || 0;
      if (w < 200 || h < 200) continue;         // icons and chrome
      if (inChrome(im)) continue;
      pixels += w * h;
      imageCount++;
      // The narrower count: inside the readable region and not page furniture.
      // A recommendation grid raises the count above and must not raise this
      // one, because this is what decides whether "text and images" is on offer.
      if (region.el.contains(im) && !isFurniture(im)) {
        regionPixels += w * h;
        regionCount++;
      }
    }

    var headings = region.el.querySelectorAll('h1,h2,h3,h4,h5,h6');
    var headingCount = 0;
    for (var hi = 0; hi < headings.length; hi++) {
      if (!isFurniture(headings[hi])) headingCount++;
    }

    // Publication date: <time datetime>, then the standard metadata names.
    var published = null;
    var t = document.querySelector('article time[datetime], time[datetime][pubdate], time[datetime]');
    if (t) published = t.getAttribute('datetime');
    if (!published) {
      var metaNames = ['article:published_time', 'datePublished', 'publish-date', 'date'];
      for (var mi = 0; mi < metaNames.length; mi++) {
        var mt = document.querySelector('meta[property="' + metaNames[mi] + '"], meta[name="' + metaNames[mi] + '"]');
        if (mt && mt.content) { published = mt.content; break; }
      }
    }
    if (!published) {
      // JSON-LD is the other standard place a date lives.
      var lds = document.querySelectorAll('script[type="application/ld+json"]');
      for (var li = 0; li < lds.length && !published; li++) {
        try {
          var parsed = JSON.parse(lds[li].textContent || '{}');
          var nodes = Array.isArray(parsed) ? parsed : [parsed];
          for (var ni = 0; ni < nodes.length; ni++) {
            if (nodes[ni] && nodes[ni].datePublished) { published = nodes[ni].datePublished; break; }
          }
        } catch (e) { /* a malformed block is not an error here */ }
      }
    }

    // Real pagination: a control set that states a range.
    var pager = document.querySelector('nav[aria-label*="pag" i], [role=navigation][aria-label*="pag" i], .pagination, [class*="pagination" i]');
    var pageNumbers = [];
    if (pager) {
      var pageLinks = pager.querySelectorAll('a,button,span');
      for (var pi = 0; pi < pageLinks.length; pi++) {
        var n = parseInt((pageLinks[pi].textContent || '').trim(), 10);
        if (!isNaN(n) && n > 0 && n < 100000) pageNumbers.push(n);
      }
    }

    // Dated list: several sibling items that each carry a date.
    var datedItems = document.querySelectorAll('article time[datetime], li time[datetime], .post time[datetime]');
    var dates = [];
    for (var di = 0; di < datedItems.length && di < 60; di++) {
      var dv = datedItems[di].getAttribute('datetime');
      if (dv) dates.push(dv);
    }

    return {
      textLength: text.length,
      paragraphCount: paragraphs.length,
      headingCount: headingCount,
      contentImageCount: imageCount,
      contentImagePixels: pixels,
      contentRegionImageCount: regionCount,
      contentRegionImagePixels: regionPixels,
      hasArticleElement: !!document.querySelector('article'),
      hasMainElement: !!document.querySelector('main, [role=main]'),
      publishedAt: published,
      hasRelPrev: !!document.querySelector('link[rel=prev], a[rel=prev]'),
      pagerNumbers: pageNumbers,
      listedDates: dates,
      headingText: (document.querySelector('h1') || {}).textContent || ''
    };
  }

  /// Media the store-ready app deliberately does not save.
  ///
  /// Reported, not fetched: the offline copy holds a placeholder and a link to
  /// the original page. Nothing here reads a media URL.
  /// Geometry only. Nothing here reads, returns or retains a media URL — the
  /// selectors below identify *elements*, and only their measured boxes leave
  /// this function.
  function mediaSignals() {
    var videos = document.querySelectorAll('video, iframe[src*="youtube" i], iframe[src*="vimeo" i], iframe[allow*="fullscreen" i]');
    var audios = document.querySelectorAll('audio');

    // The largest player, and whether it sits in the readable region. One big
    // player in the content is a video page; a rail of small previews, or a
    // player in the header, is not.
    var region = readableRegion();
    var largest = 0, largestInRegion = false;
    for (var i = 0; i < videos.length; i++) {
      var r = videos[i].getBoundingClientRect();
      var area = Math.round(Math.max(0, r.width) * Math.max(0, r.height));
      if (area <= largest) continue;
      largest = area;
      largestInRegion = region.el.contains(videos[i]) && !isFurniture(videos[i]);
    }

    return {
      videoCount: videos.length,
      audioCount: audios.length,
      primaryVideoPixels: largest,
      videoInContentRegion: largestInRegion
    };
  }

  // --- structured document extraction ---------------------------------------
  // Measures and flags; it does not decide. Every block the readable region
  // contains is reported with the facts Dart needs to keep or drop it — see
  // save/document_extraction.dart, where those rules live and are tested.

  var BLOCK_SELECTOR = 'h1,h2,h3,h4,h5,h6,p,blockquote,li,hr,img,pre,figcaption';

  // Elements whose text is taken whole, so their inner paragraphs must not be
  // emitted a second time.
  var WHOLE_TEXT_TAGS = { BLOCKQUOTE: 1, LI: 1, PRE: 1, FIGCAPTION: 1 };

  var MARK_TAGS = {
    STRONG: 'strong', B: 'strong',
    EM: 'emphasis', I: 'emphasis',
    CODE: 'code', KBD: 'code', SAMP: 'code'
  };

  function blockHidden(el) {
    if (el.hasAttribute && el.hasAttribute('hidden')) return true;
    if (el.getAttribute && el.getAttribute('aria-hidden') === 'true') return true;
    var r = el.getBoundingClientRect();
    if (r.width > 0 || r.height > 0) return false;
    // Only pay for computed style once the cheap test says it might be hidden;
    // an <hr> is legitimately zero-height and must not be dropped for it.
    var cs = window.getComputedStyle(el);
    return cs.display === 'none' || cs.visibility === 'hidden' ||
           parseFloat(cs.opacity || '1') === 0;
  }

  /// Plain text plus emphasis ranges, as offsets into that text.
  ///
  /// Flat ranges rather than a nested tree: they cannot come out unbalanced,
  /// they survive JSON unchanged, and they are trivially clamped on the Dart
  /// side when they disagree with the text they describe.
  function textAndMarks(el) {
    var out = '', marks = [];
    var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
    var node, guard = 0;
    while ((node = walker.nextNode()) && guard++ < 4000) {
      var parent = node.parentElement;
      if (!parent) continue;
      var tag = parent.tagName;
      if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' ||
          tag === 'TEMPLATE') {
        continue;
      }
      var t = (node.nodeValue || '').replace(/\s+/g, ' ');
      if (!t) continue;
      if (out.length === 0 && t === ' ') continue;
      if (out.charAt(out.length - 1) === ' ' && t.charAt(0) === ' ') {
        t = t.slice(1);
      }
      if (!t) continue;

      var style = null, p = parent, depth = 0;
      while (p && p !== el && depth < 8) {
        if (MARK_TAGS[p.tagName]) { style = MARK_TAGS[p.tagName]; break; }
        p = p.parentElement; depth++;
      }

      var start = out.length;
      out += t;
      if (style && marks.length < 400) {
        marks.push({ start: start, end: out.length, style: style });
      }
    }

    // Trim, and shift the marks by however much came off the front.
    var lead = out.length - out.replace(/^\s+/, '').length;
    out = out.trim();
    var shifted = [];
    for (var i = 0; i < marks.length; i++) {
      var s = marks[i].start - lead, e = marks[i].end - lead;
      if (e > out.length) e = out.length;
      if (s < 0) s = 0;
      if (e > s) shifted.push({ start: s, end: e, style: marks[i].style });
    }
    return { text: out, marks: shifted };
  }

  function imageBlock(img) {
    var r = img.getBoundingClientRect();
    var src = img.currentSrc || abs(img.getAttribute('src')) || abs(lazyAttr(img));
    return {
      kind: 'image',
      src: (src && src.indexOf('data:') !== 0) ? src : null,
      alt: img.alt || '',
      width: img.naturalWidth || img.width || Math.round(r.width),
      height: img.naturalHeight || img.height || Math.round(r.height),
      chrome: isFurniture(img),
      hidden: blockHidden(img)
    };
  }

  function extractDocument(opts) {
    opts = opts || {};
    var cap = opts.blockCap || 2000;
    var region = readableRegion();
    var root = region.el;
    if (!root) {
      return { title: document.title || '', blocks: [], truncated: false,
               regionBasis: 'no document body' };
    }

    var nodes = root.querySelectorAll(BLOCK_SELECTOR);
    var blocks = [];
    var truncated = false;

    for (var i = 0; i < nodes.length; i++) {
      if (blocks.length >= cap) { truncated = i < nodes.length; break; }
      var el = nodes[i];
      var tag = el.tagName;

      // Inside a container whose text is taken whole. Images are the exception:
      // an illustration inside a list item still has a position worth keeping.
      var nested = false, p = el.parentElement, depth = 0;
      while (p && p !== root && depth < 12) {
        if (WHOLE_TEXT_TAGS[p.tagName]) { nested = true; break; }
        p = p.parentElement; depth++;
      }
      if (nested && tag !== 'IMG') continue;

      if (tag === 'IMG') { blocks.push(imageBlock(el)); continue; }

      if (tag === 'HR') {
        blocks.push({ kind: 'separator', chrome: isFurniture(el),
                      hidden: false });
        continue;
      }

      var tm = textAndMarks(el);
      if (!tm.text) continue;

      var kind = 'paragraph', level = 0, ordered = false;
      if (tag.charAt(0) === 'H' && tag.length === 2) {
        kind = 'heading';
        level = parseInt(tag.charAt(1), 10) || 1;
      } else if (tag === 'BLOCKQUOTE') {
        kind = 'quote';
      } else if (tag === 'LI') {
        kind = 'listItem';
        var list = el.parentElement, d = 0;
        ordered = !!(list && list.tagName === 'OL');
        // Nesting depth, so an indented sub-list still reads as one.
        var q = el.parentElement;
        while (q && q !== root && d < 6) {
          if (q.tagName === 'UL' || q.tagName === 'OL') level++;
          q = q.parentElement; d++;
        }
      } else if (tag === 'PRE') {
        kind = 'paragraph';
      } else if (tag === 'FIGCAPTION') {
        kind = 'quote';
      }

      blocks.push({
        kind: kind,
        text: tm.text.slice(0, 20000),
        level: level,
        ordered: ordered,
        marks: tm.marks,
        chrome: isFurniture(el),
        hidden: blockHidden(el)
      });
    }

    var h1 = root.querySelector('h1') || document.querySelector('h1');
    return {
      title: (h1 ? (h1.textContent || '').trim() : '') || document.title || '',
      blocks: blocks,
      truncated: truncated,
      regionBasis: region.basis
    };
  }

  /// Signals that further automatic navigation must stop.
  ///
  /// Detection only. Nothing here attempts, works around, or retries past any
  /// of these — the run stops and tells the user which one it hit.
  function accessSignals() {
    var text = (visibleText(document.body) || '').toLowerCase();
    var head = text.slice(0, 4000);

    var passwordFields = document.querySelectorAll('input[type=password]');
    var loginForm = document.querySelector('form[action*="login" i], form[action*="signin" i], form[id*="login" i]');

    // CAPTCHA / bot-check widgets advertise themselves with standard attributes.
    var captcha = document.querySelector(
      'iframe[src*="recaptcha" i], iframe[title*="captcha" i], iframe[src*="hcaptcha" i], iframe[src*="turnstile" i], [class*="g-recaptcha" i], [data-sitekey]'
    );

    // A paywall marks itself in schema.org metadata when it is honest about it.
    var paywallMeta = document.querySelector('[isaccessibleforfree="False" i], [data-paywall], meta[name="article:content_tier"][content="locked"]');

    function mentions(list) {
      for (var i = 0; i < list.length; i++) {
        if (head.indexOf(list[i]) >= 0) return list[i];
      }
      return null;
    }

    return {
      hasPasswordField: passwordFields.length > 0,
      hasLoginForm: !!loginForm,
      hasCaptchaWidget: !!captcha,
      hasPaywallMarker: !!paywallMeta,
      // Phrase hints are the weakest signal and are used only to *corroborate*
      // a structural one, never on their own — see save/stop_conditions.dart.
      deniedPhrase: mentions(['access denied', 'forbidden', '403 forbidden', 'not authorized', 'unauthorized']),
      ratePhrase: mentions(['too many requests', 'rate limit', 'rate-limited', 'slow down', '429']),
      paywallPhrase: mentions(['subscribe to continue', 'subscribers only', 'this article is for subscribers', 'become a member to read']),
      authPhrase: mentions(['sign in to continue', 'log in to continue', 'please sign in', 'please log in', 'members only']),
      isEmptyDocument: text.length < 40
    };
  }

  return {
    version: 3,

    extractDocument: function (opts) { return extractDocument(opts); },

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
        viewportWidth: m.isDoc
          ? (window.innerWidth || document.documentElement.clientWidth || 0)
          : Math.round(m.el.clientWidth || 0),
        scrollY: m.y,
        atBottom: (m.y + m.vpH) >= (m.docH - 8),
        headNextHref: headNext(),
        imageCount: allImgs.length,
        imagesTruncated: allImgs.length > IMG_CAP,
        images: imgs.map(imgInfo)
      };
      if (opts.withSignals !== false) {
        out.content = contentSignals();
        out.media = mediaSignals();
        out.access = accessSignals();
      }
      if (opts.withLinks) {
        var as = Array.prototype.slice.call(document.querySelectorAll('a[href]'));
        out.links = as.slice(0, 500).map(linkInfo);
        out.pageHints = pageHints();
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
    // confident. Clicks are swallowed in save phase so the page cannot
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

/// Geometry and images only — no content, media or access signals.
///
/// What the scroll loop actually reads. The full probe additionally walks the
/// readable region twice and clones the whole body a third time to lowercase
/// it for the access phrases (`contentSignals`, `mediaSignals`,
/// `accessSignals`), and that work is repeated on **every scroll step** of a
/// document the save is deliberately making taller. None of it is consulted
/// until the settled probe, which still asks for all of it.
const String kCallProbeLight =
    'return window.__wr.probe({withLinks: false, withSignals: false});';
const String kCallScrollStep = 'return window.__wr.scrollStep(dy);';
const String kCallScrollTo = 'return window.__wr.scrollTo(y);';
const String kCallFetchBase64 = 'return await window.__wr.fetchAsBase64(url);';
const String kCallStartSelection = 'return window.__wr.startSelection(mode);';
const String kCallStopSelection = 'return window.__wr.stopSelection();';
const String kCallApplyLocator = 'return window.__wr.applyLocator(locator);';
const String kCallApplyReaderRule = 'return window.__wr.applyReaderRule(rule);';
const String kCallExtractDocument =
    'return window.__wr.extractDocument({blockCap: blockCap});';

/// The page's own declared icon, absolutised against the document.
///
/// Standalone rather than part of `__wr`: it is read once per completed load
/// for decoration, has nothing to do with save, and must keep working on
/// pages where the preamble was blocked by CSP.
const String kCallPageIcon = r'''
var sel = ['link[rel~="icon"]', 'link[rel="shortcut icon"]',
           'link[rel="apple-touch-icon"]', 'link[rel="apple-touch-icon-precomposed"]'];
for (var i = 0; i < sel.length; i++) {
  var el = document.querySelector(sel[i]);
  if (el && el.href) return el.href;
}
return null;
''';
