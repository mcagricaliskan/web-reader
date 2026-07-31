# Store package

> Draft listing copy, reviewer notes, exact in-app wording, and the console
> checklists. English is the canonical source; the Turkish text is a translation
> of it, not a separate claim.
>
> **Nothing here guarantees approval.** Character limits were current in July
> 2026 and should be re-checked in the consoles before submission.

---

## 1. Brand

The working name is **Web Reader**. It is descriptive, almost certainly already
in use, and probably not registrable — so it is fine for development and a poor
choice for the store.

**Recommendation: do not ship under "Web Reader", and do not pick a final name
from this list without running the checks in §1.2.**

### 1.1 Shortlist

Constraints applied: no fiction-specific word, no downloader word, pronounceable,
≤ 12 characters, and meaningful for a read-later tool.

| Candidate | Reading | Notes |
|---|---|---|
| **Keepread** | "keep" + "read" | Says the product in one word. Coined, so likely registrable. |
| **Laterly** | read it later | Soft, coined, short. Check for existing SaaS use. |
| **Pagevault** | a vault for pages | Strong "your own copy" connotation. "Vault" is crowded. |
| **Readholt** | read + holt (a small wood / a refuge) | Distinctive and unusual; obscure second element. |
| **Offreader** | offline reader | Very descriptive, weak as a mark. |
| **Marginal** | margins, marginalia | Memorable; the everyday sense of "marginal" is a negative. |

Recommended first choice: **Keepread**. Second: **Laterly**.

### 1.2 Checks required before choosing (not done here)

- [ ] App Store Connect name availability, all target territories
- [ ] Google Play listing-title availability
- [ ] Trademark search: USPTO, EUIPO, and Türkiye (TÜRKPATENT), classes 9 and 42
- [ ] Domain availability for the support and privacy URLs
- [ ] Plain web search for an existing app or service with the name
- [ ] No confusing similarity to an Apple product or interface (Apple 5.2.5)

### 1.3 Bundle identifier

Currently `com.mcagricaliskan.webreader` on both platforms. Changing it after
signing and provisioning exist is disruptive, so decide **before** the first
upload. If the brand changes, change the identifier in the same pass or
deliberately accept that it will not match the name.

---

## 2. Apple App Store

**App name** (≤ 30 chars): `Keepread` *(placeholder — see §1)*

**Subtitle** (≤ 30 chars):

```
Save web pages. Read offline.
```
*(29 characters.)*

**Promotional text** (≤ 170 chars):

```
Save an article now, read it later without a connection. Your library lives on
your device — no account, and nothing is sent to us.
```

**Keywords** (≤ 100 chars, comma-separated, no spaces):

```
read later,offline reading,save article,reading list,web pages,library,reader,bookmarks
```

**Description:**

```
Keepread is a personal reading tool. Save web pages you are allowed to keep,
organise them in your own library, and read them offline — on a plane, on the
underground, or anywhere the signal runs out.

BUILT FOR READING, NOT FOR HOARDING

The ordinary action saves the page in front of you. Nothing else. When a page
turns out to be part of something longer — a multi-page document, a dated series
of posts, a set of related pages — Keepread tells you what it found and asks
before saving more. You see the source, how many items were detected, whether the
sequence has a known end, which direction it runs, and where it will stop. You
can review the list and pick items individually.

YOUR LIBRARY

• Collections group related pages; single pages stay single pages
• Continue reading picks up exactly where you stopped, to the paragraph
• Reading progress survives restarts, re-saves and freeing up space
• Search your library by title or source
• Archive what you have finished without losing a thing
• Storage screen shows what is using space, per collection, with one tap to
  reclaim it

AN OFFLINE READER THAT RESPECTS THE PAGE

Text is stored as text. Images are stored exactly as the site served them — no
re-encoding, no quality profiles. Page dimensions are read from the stored files,
so a saved page opens at the right proportions and at the position you left.

HONEST ABOUT WHAT IT DOES

• Every save is something you started. There is no background saving.
• Multi-page saves are bounded, visible in a queue, and cancellable.
• If a site asks for a sign-in, shows a paywall, or presents a verification
  check, saving stops and says so. Keepread does not work around paywalls,
  logins, access controls, DRM or verification checks.
• You choose what each save keeps: the page images, the readable text, or the
  text with the pictures that sit inside it. Keepread suggests one and shows
  you the alternatives.
• Audio and video are not saved. A saved page links back to the original.
• Every saved page keeps its source address, and "Open original page" is one tap
  from the reader.

PRIVACY

No account. No analytics. No advertising. Your library, your reading position and
your browsing history stay in the app's private storage on your device, and you
can delete any of them at any time. Keepread has no server and receives nothing
from you. The browser does contact the sites you choose to visit, as any browser
does.

YOU ARE RESPONSIBLE FOR WHAT YOU SAVE

Keepread is a tool, not a licence. Save only content you created, own, have
permission to use, or are otherwise allowed to keep. Copyright rules, website
terms and applicable law are yours to follow.
```

---

## 3. Google Play

**Title** (≤ 30 chars): `Keepread: Save & Read Offline`

**Short description** (≤ 80 chars):

```
Save articles and web pages to your personal library and read them offline.
```
*(74 characters.)*

**Full description** (≤ 4000 chars): as §2, with the Apple-specific framing
removed.

---

## 4. Türkçe (Google Play / App Store)

**Uygulama adı:** `Keepread`

**Alt başlık / Kısa açıklama** (≤ 80 karakter):

```
Web sayfalarını kişisel kitaplığınıza kaydedin ve çevrimdışı okuyun.
```

**Tam açıklama:**

```
Keepread kişisel bir okuma aracıdır. Saklamaya hakkınız olan web sayfalarını
kaydedin, kendi kitaplığınızda düzenleyin ve çevrimdışı okuyun — uçakta, metroda
ya da bağlantının kesildiği her yerde.

OKUMAK İÇİN TASARLANDI

Olağan işlem, önünüzdeki sayfayı kaydeder. Başka bir şey yapmaz. Bir sayfanın
daha uzun bir bütünün parçası olduğu anlaşıldığında — çok sayfalı bir belge,
tarihli bir gönderi dizisi, birbiriyle ilişkili sayfalar — Keepread ne bulduğunu
söyler ve devam etmeden önce sorar. Kaynağı, kaç öğe bulunduğunu, dizinin bilinen
bir sonu olup olmadığını, hangi yönde ilerlediğini ve nerede duracağını görürsünüz.
Listeyi inceleyip öğeleri tek tek seçebilirsiniz.

KİTAPLIĞINIZ

• Koleksiyonlar ilişkili sayfaları gruplar; tek sayfalar tek sayfa kalır
• Kaldığınız yerden, paragrafına kadar devam edin
• Okuma durumu yeniden başlatmalardan, yeniden kaydetmelerden ve yer açmaktan
  etkilenmez
• Kitaplığınızda başlığa veya kaynağa göre arama yapın
• Bitirdiklerinizi hiçbir şey kaybetmeden arşivleyin
• Depolama ekranı neyin yer kapladığını koleksiyon bazında gösterir

SAYFAYA SAYGILI BİR ÇEVRİMDIŞI OKUYUCU

Metin metin olarak saklanır. Görseller sitenin sunduğu biçimde, yeniden
kodlanmadan saklanır. Sayfa boyutları kaydedilen dosyalardan okunur; böylece
kaydedilmiş bir sayfa doğru oranlarla ve bıraktığınız konumda açılır.

NE YAPTIĞI KONUSUNDA DÜRÜST

• Her kayıt sizin başlattığınız bir işlemdir. Arka planda kayıt yapılmaz.
• Çok sayfalı kayıtlar sınırlıdır, kuyrukta görünür ve iptal edilebilir.
• Bir site oturum açma isterse, ödeme duvarı ya da doğrulama kontrolü gösterirse
  kayıt durur ve nedenini söyler. Keepread ödeme duvarlarını, oturum açmayı,
  erişim denetimlerini, DRM'i veya doğrulama kontrollerini aşmaya çalışmaz.
• Her kaydın neyi tutacağına siz karar verirsiniz: sayfanın görselleri, okunabilir
  metin ya da metin ile içindeki görseller. Keepread birini önerir, diğerlerini
  de gösterir.
• Ses ve video kaydedilmez. Kaydedilen sayfa özgün sayfaya bağlantı verir.
• Her kaydedilen sayfa kaynak adresini korur; "Özgün sayfayı aç" okuyucudan tek
  dokunuş uzaktadır.

GİZLİLİK

Hesap yok. Analitik yok. Reklam yok. Kitaplığınız, okuma konumunuz ve tarama
geçmişiniz cihazınızdaki uygulamaya özel depolamada kalır ve dilediğiniz an
silebilirsiniz. Keepread'in sunucusu yoktur ve sizden hiçbir veri almaz. Tarayıcı,
her tarayıcı gibi, yalnızca sizin ziyaret etmeyi seçtiğiniz sitelere bağlanır.

KAYDETTİKLERİNİZDEN SİZ SORUMLUSUNUZ

Keepread bir araçtır, bir izin değil. Yalnızca kendi oluşturduğunuz, size ait
olan, kullanma izniniz bulunan veya saklamanıza başka bir şekilde izin verilen
içerikleri kaydedin. Telif hakkı kurallarına, web sitesi koşullarına ve geçerli
yasalara uymak sizin sorumluluğunuzdadır.
```

---

## 5. Screenshot captions

Each caption describes a screen the reviewer can reach. No third-party content
appears in any of them — every screenshot uses the demo content in
`docs/DEMO_CONTENT.md`.

| # | Screen | EN caption | TR caption |
|---|---|---|---|
| 1 | Library | Your reading library, on your device | Okuma kitaplığınız, cihazınızda |
| 2 | Save scope sheet | The default saves one page. More is your choice. | Varsayılan tek sayfa kaydeder. Fazlası sizin kararınız. |
| 3 | Review related items | See what was found before anything is saved | Hiçbir şey kaydedilmeden önce ne bulunduğunu görün |
| 4 | Reader | Read offline, exactly where you left off | Çevrimdışı okuyun, tam bıraktığınız yerden |
| 5 | Collection detail | Related pages, in order, with progress | İlişkili sayfalar, sırayla, ilerlemeyle |
| 6 | Queue / Activity | Every save is visible and cancellable | Her kayıt görünür ve iptal edilebilir |
| 7 | Storage | Know what is using space. Reclaim it in a tap. | Neyin yer kapladığını bilin. Tek dokunuşla geri kazanın. |
| 8 | Content rights | Save only what you are allowed to keep | Yalnızca saklamanıza izin verilenleri kaydedin |

**Feature graphic copy (Play, 1024×500):** `Save web pages. Read offline.` over
the app mark on the palette's quiet surface. No screenshots-in-graphic, no
third-party logos, no device frames implying an endorsement.

---

## 6. Exact in-app wording

The single source for these strings. The app must not paraphrase them.

### 6.1 First-use content-rights disclosure

Shown once, immediately before the first save of an external page.

> **Before you save**
>
> Keepread is a personal reading tool. Save only content you created, own, have
> permission to use, or are otherwise legally allowed to keep. You are
> responsible for following copyright rules, website terms, and applicable law.
>
> The app does not bypass paywalls, logins, access controls, DRM, or site
> restrictions. It cannot check whether you have permission — that judgement is
> yours.

Actions: **Review terms** · **I understand**

Notes: no pre-ticked box, no countdown, no "Agree" styled as the only route out.
Dismissing without acknowledging cancels the save. Re-readable at
**Settings → Content rights**. Acknowledgement is stored locally with a version
(`disclosure.contentRights.version`); a material change asks once more.

### 6.2 Contextual multi-entry notice

Shown once per domain, before the first save of more than one page from it.

> **Saving several pages from example.com**
>
> Only save content you have permission to keep. This site's terms may limit
> automated requests or offline copies.
>
> This will save up to **12 items**, following next-page links, and will stop
> when there is no next page.

Actions: **Review items** · **Cancel** · **Save**

### 6.3 What to save

Shown at the top of the save sheet, above the range options. The heading is
**What to save**, with one line of what was detected beneath it:

| Detection | Line |
|---|---|
| Confident | `This looks like an article.` |
| Low confidence | `This is probably not something we could classify, but the page did not say clearly.` |
| Not analysed | `This page could not be analysed, so every option is offered. Pick what fits.` |
| Nothing possible | `Nothing on this page can be saved offline.` |

Modes, all three always visible; unavailable ones are disabled with the reason
in place of the description:

| Mode | Description | Reason when unavailable |
|---|---|---|
| **Images only** | Save the page images in order, with no text. | This page does not have enough full-size images to save as an image sequence. |
| **Text only** | Save the readable text. No images are downloaded. | No readable text was found on this page. |
| **Text and images** | Save the readable text with the images that sit inside it. | No images were found inside the readable text. |

Optional, when the page belongs to a collection:
**Use "<mode>" for this collection from now on**

### 6.4 Save-scope review

Header: **Review what will be saved**

| Line | Example |
|---|---|
| What was detected | `A next-page link was found.` / `This appears to be a dated list of posts.` / `This page has 12 numbered pages.` / `We found 8 related items.` / `No related pages found.` |
| Source | `example.com` |
| Count | `12 items` · or `Number of items is not known in advance` |
| Shape | `Numbered, 12 pages` · `Open-ended — no known end` · `Dated, newest first` · `One continuous page` |
| Direction | `Following "next", which moves to older posts` |
| Stop condition | `Stops when there is no next page, or after 12 items` |
| Estimated size | `About 24 MB` · or `Size cannot be estimated yet` |
| Cancel | `You can stop this at any time from Activity.` |

Scope options, in this order, with the first preselected:

1. **Save current page only**
2. **Review related items** → the reviewable list, then **Save selected items**
3. **Save a number of items** → typed positive integer, up to the per-run
   ceiling. There is no open-ended option: every run stops at a number the
   user chose.

### 6.5 Restricted-access stopping

Verbatim from `StopReason.message`:

| Condition | Message |
|---|---|
| Sign-in | Stopped: the site asked for a sign-in. Sign in yourself in the Browser if you have an account, then start again from that page. |
| Paywall | Stopped: this page is behind a paywall. The app does not work around paywalls. |
| Verification | Stopped: the site showed a human-verification check. Complete it yourself in the Browser if you want to continue. |
| Access denied | Stopped: the site refused access to the next page. |
| Rate limited | Stopped: the site asked for fewer requests. Try again later. |
| Different site | Stopped: the next page is on a different website. |
| Loop | Stopped: the pages started repeating themselves. |
| Layout changed | Stopped: the page layout changed, so continuing might have saved the wrong thing. |
| Unclear next | Stopped: it was not clear which link continues the sequence. |
| Limit | Reached the limit you set. |

### 6.6 Video pages

Shown in the save sheet when the page is primarily a video.

When the page also carries readable content:

> **Video is not saved.** The readable text on this page can be, and the entry
> will link back to the original for anything that plays.

When it does not:

> **Video is not saved**, and this page has no readable text to save instead.
> Open it in the Browser when you want to watch it.

In the second case no capture mode is offered and the save is refused. The app
does not fall back to saving a video page's thumbnails, advertisements or
navigation images.

In the reader, an inline image a document did not store reads:

> This image was not saved.

or, when the file is gone rather than never fetched:

> This image is no longer on the device.

### 6.7 Empty and error states

| State | Wording |
|---|---|
| Empty library | **Nothing saved yet.** Open the Browser, find something worth keeping, and tap Save. |
| Empty collection | Nothing in this collection is available offline yet. |
| No saved sites | Sites you save appear here. Nothing is added for you. |
| No history | Pages you visit appear here. Saving a page does not. |
| Entry not offline | Not available offline — save again. |
| Offline, save attempted | You are offline. Saving needs a connection; everything already saved is still readable. |
| Save failed | Could not save this page. Nothing already saved was affected. |
| Out of space | Not enough space. Free some up on Settings → Storage, then try again. |
| Partial save | Saved, but some images are missing. You can try again for the missing ones. |

---

## 7. Reviewer notes (App Store Connect / Play Console)

```
WHAT THIS APP IS

Keepread is a personal read-later and offline reading app: an embedded browser,
a native library, and an offline reader. There is no account, no server, and no
back end — nothing needs to be enabled for review, and no demo credentials are
required.

THERE IS NO PRECONFIGURED CONTENT

The app ships with no list of websites, no site-specific rules, no selectors and
no content catalogue. The saved-sites list and the library both start empty. A
build-time test (test/repository_cleanliness_test.dart) fails if a third-party
hostname or a site rule is added.

HOW SAVING WORKS

1. The user browses to a page themselves, in the app's browser.
2. They tap Save. The DEFAULT and preselected action is "Save current page only".
3. If the app detects that the page continues (rel=next, numbered pagination, a
   dated list), it shows a review step first: what was detected, the source
   domain, how many items, whether the end is known, which direction, where it
   stops, and an estimated size. The user can review and pick items individually.
4. Open-ended sequences REQUIRE an explicit maximum. There is no "unlimited".
5. Multi-page saves appear in Activity with live progress and can be cancelled at
   any point; cancellation takes effect at the next safe point and the wording
   says so.
6. Nothing saves in the background. Queued saves wait for an explicit Start.

WHAT IT DOES NOT DO

- It does not bypass authentication, subscriptions, paywalls, DRM, CAPTCHAs,
  robots restrictions, rate limits or anti-bot measures. When any of those is
  detected, saving STOPS and names the reason. There is no retry with different
  headers, no alternate-URL attempt, and no rate-limit wait-out anywhere in the
  code (see lib/save/stop_conditions.dart).
- It does not download, convert or export audio or video. The asset fetcher
  accepts image bytes only, verified by magic number. A page with media shows a
  placeholder and a link to the original page.
- It has no bulk export to Photos, Gallery, Downloads or shared storage. Saved
  files stay in app-private storage.

WEBVIEW AND JAVASCRIPT (for the Play device-and-network-abuse review)

The app injects a measurement script into its WebView. It is read-only: it
reports layout metrics, image metadata, links and structural signals, and can
scroll. It exposes no filesystem, database, network or native API to page
content, and it never evaluates page-supplied code. No code is downloaded or
executed from any source.

WHERE THINGS ARE

- Save scope and the review step: Browser → Save
- Queue, progress, cancel, retry: Library → Activity (top of the Library screen)
- Delete saved files: Collection detail → select → Remove offline files;
  or Settings → Storage
- Clear browsing history: Browser → Home → Full history → Clear
- Clear website data (cookies, cache): Settings → Browser data
- Privacy, Terms, Content rights: Settings → About
- Source attribution and "Open original page": Reader → ⋯, and Entry details

HOW TO TEST EACH CONTENT SHAPE

Use the demo site at <DEMO_BASE_URL> (original content, developer-owned):

  /article            one standalone article, no continuation
  /doc/page-1         a 12-page numbered document (rel=next + pagination)
  /posts              a reverse-chronological list of dated posts
  /journal            a chronological (oldest-first) list of dated posts
  /gallery/1          an image-heavy sequence, original artwork
  /chain/1            an open-ended next-link chain with no declared end
  /gated              a page behind a demo sign-in form — shows the app STOPPING

Suggested pass: save /article (single page) → save /doc/page-1 and choose
"Save a number of items: 3" → open /chain/1 and choose "Continue until no next
page" to see the required maximum → open /gated and start a save to see the
sign-in stop condition → read offline in Airplane Mode → check Activity, then
Settings → Storage.

AGE RATING

The app allows the user to enter any web address, so it is rated for
unrestricted web access and is not directed to children.
```

---

## 8. Console checklists

### 8.1 App Privacy (App Store Connect)

| Question | Answer |
|---|---|
| Does your app collect data? | **No** |
| Third-party SDKs collecting data | **None** |
| Tracking (ATT) | **No** — no `NSUserTrackingUsageDescription`, no IDFA access |
| Privacy policy URL | required — see §8.5 |
| Data used to track you | none |
| Data linked to you | none |
| Data not linked to you | none |

Confirm the app contains no analytics, crash-reporting or advertising SDK before
answering. Current dependencies: `flutter_inappwebview`, `drift`, `dio`,
`flutter_riverpod`, `go_router`, `path_provider`, `uuid`, `crypto`, `collection`,
`wakelock_plus`, `share_plus`, `url_launcher`. None transmits data to the
developer.

### 8.2 Data safety (Play Console)

| Field | Answer |
|---|---|
| Does your app collect or share user data? | **No** |
| Web browsing history | Stored on device only; not collected (Play: local-only processing need not be disclosed) |
| Files and docs | Stored on device only; not collected |
| Is data encrypted in transit? | N/A — no data is sent to the developer |
| Can users request deletion? | **Yes**, in-app: Settings → Storage, Browser data, and the debug-only full reset |
| Committed to Play Families policy | **No** |
| Independent security review | No |

### 8.3 Content rating (IARC)

- Violence / sexual content / language / controlled substances / gambling: **No**
- Users can interact / share location / share personal info: **No**
- **Unrestricted internet access: Yes**
- In-app purchases: **No**

### 8.4 Target audience

- Age groups: **18 and over** only
- Appeals to children: **No**
- Ads: **None**

### 8.5 Support and legal URLs — required, not yet created

- [ ] Privacy policy URL (public, reachable, matches `docs/PRIVACY.md`)
- [ ] Terms of use URL
- [ ] Content-rights page URL (may live under Terms)
- [ ] Support URL with a working contact address
- [ ] Marketing URL (optional)

### 8.6 Manual console tasks that cannot be done from this repository

- [ ] Answer the App Privacy questionnaire (§8.1)
- [ ] Answer the Data safety form (§8.2)
- [ ] Complete the IARC questionnaire (§8.3)
- [ ] Set the target audience to 18+ (§8.4)
- [ ] Enter the reviewer notes from §7 verbatim
- [ ] Upload screenshots built from the demo content only
- [ ] Confirm the final app name and bundle identifier (§1)
- [ ] Enter the privacy, terms and support URLs (§8.5)
- [ ] Declare the WebView/JavaScript position for Play (§7)
