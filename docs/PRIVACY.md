# Privacy audit

> Every data flow, and the exact claims the listing is allowed to make.
> Written to be checkable: each row names where in the code the behaviour lives.

## 1. What is stored locally

| Data | Where | Deleted by |
|---|---|---|
| Collections, entries, reading position, read state | `entries` / `collections` in the app-private SQLite database | Collection detail → ⋯ → *Delete permanently*, per collection; the debug-only full reset, for everything |
| Saved page bytes (text + images) | `webread/library/…` in app-private storage, excluded from device backup | Remove offline files (per entry, per collection, all finished), which keeps the rows; *Delete permanently*, which removes the collection's files and its rows together |
| Browsing history (manual navigation only) | `browsing_history`, retained 90 days or 5,000 rows | Browser → Full history → Clear |
| Saved sites | `saved_sites` — empty until the user adds one | per-row removal |
| Favicons | `favicon_cache`, ≤ 24 KB each, purely derived | Settings → Browser data |
| Cookies and site storage | the WebView's own store | Settings → Browser data → Clear website data |
| User page hints | `user_page_hints` — empty until the user teaches one | per-row removal |
| Preferences and disclosure acknowledgements | `settings` | the debug-only full reset |

## 2. What leaves the device

**Nothing goes to the developer.** There is no account, no server, no analytics
SDK, no crash-reporting SDK and no advertising SDK.

Outbound requests exist for exactly two reasons, both to hosts the user
navigated to themselves:

1. The WebView loads the page the user opened.
2. `AssetFetcher` fetches that page's images, with the WebView's User-Agent,
   cookies and `Referer`, so the request is indistinguishable from the browsing
   the user was already doing.

| Question | Answer |
|---|---|
| Are browsing URLs sent to the developer? | No |
| Is saved content uploaded anywhere? | No |
| Do analytics receive URLs, titles, domains or content? | There are no analytics |
| Does crash reporting include page data? | There is no crash reporting |
| Is there optional sync? | No |
| How are cookies handled? | In the WebView's own store, cleared by Clear website data |

## 3. Claims the listing may and may not make

**May:** "Your library is stored on your device." · "No account." · "No
analytics, no advertising." · "The app has no server and receives nothing from
you."

**May not:** "No tracking." · "Completely private." · "Everything stays on
device." — the embedded browser necessarily contacts the sites the user visits,
and those sites may set cookies and track normally. Claiming otherwise would be
false.

## 4. Permissions

Internet only. Explicitly **not** requested: Photos, shared storage, all-files
access, contacts, location, installed-app queries, microphone, camera. Saved
images go to app-private storage; there is no export to Photos, Gallery or
Downloads.

## 5. Remaining legal work

- [ ] Publish a privacy policy at a stable URL matching this document
- [ ] Publish Terms of use and a content-rights page
- [ ] Legal review of the offline-copy position (see `STORE_POLICY_MAP.md` R3)
