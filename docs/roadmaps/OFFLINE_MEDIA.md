# Offline Audio & Video Roadmap

> **Repositories:** `rexone-core` + `rexone-mobile`
> **Web:** Streaming-only for V1
> **Target:** Private, app-only offline audio/video playback on Flutter Mobile
> **Suggested branch:** `feat/offline-media`

---

## 1. Decision

RexOne will support offline audio/video **on Mobile only** for V1.

Offline media is downloaded to the application's **private persistent sandbox** and never exported to:

```text
Downloads/
Movies/
Music/
Gallery/
Files/
MediaStore/
shared/public storage
```

The bytes still exist physically on the device — offline playback requires that — but the file remains application-private and is only surfaced through RexOne.

### Core rule

> **Core authorizes offline retention. Storage serves the bytes. Mobile owns the private local copy.**

The feature reuses the progressive media foundation:

```text
Asset
  ↓
StorageService
  ↓
short-lived provider URL
  ↓
Garage
```

Offline adds only:

```text
offline authorization
+ offline validity
+ private mobile download lifecycle
```

It does **not** create another media domain.

---

## 2. Goals

V1 must provide:

- private offline audio/video on Android and iOS,
- no Gallery / Downloads / Files exposure,
- no broad storage permission,
- direct provider-to-device download,
- no media-byte proxy through Rails,
- offline validity / expiry,
- user-scoped local files,
- safe partial-download handling,
- retry/cancel,
- optional Range-based resume for large files,
- automatic local-vs-network playback resolution,
- remove one / remove all,
- offline storage usage,
- cleanup on logout/account deletion,
- backup exclusion,
- bounded memory usage.

---

## 3. Non-goals

Do not build now:

- Web offline media,
- Service Worker / IndexedDB / OPFS media caching,
- DRM,
- Widevine,
- FairPlay,
- custom AES media encryption,
- HLS offline packages,
- CMAF offline packages,
- Core `OfflineDownload` table,
- per-device server rows,
- public file export,
- MediaStore integration,
- iOS Files export,
- full native background download infrastructure unless required.

---

## 4. Architecture

### Online playback

```text
Mobile
  │
  │ authenticated request
  ▼
Core
  │ authorize
  ▼
StorageService
  │
  ▼
short-lived playback URL
  │
  ▼
Garage
```

### Offline download

```text
Mobile
  │
  │ authenticated offline request
  ▼
Core
  │
  │ authorize local retention
  │ calculate offline validity
  ▼
StorageService
  │
  ▼
short-lived download URL
  │
  ▼
Garage
  │
  │ bytes
  ▼
OfflineMediaService
  │
  ▼
private application storage
```

### Playback resolution

```text
                 MediaPlaybackService
                        │
               ┌────────┴────────┐
               │                 │
       valid local copy?        no
               │                 │
              yes                ▼
               │          Core playback API
               ▼                 │
         LocalMediaSource        ▼
               │          NetworkMediaSource
               └────────┬────────┘
                        ▼
                   media player
```

---

# CORE

## 5. Offline API

Keep online playback and offline retention as separate intents.

Recommended endpoint:

```http
POST /v1/assets/:id/offline
Authorization: Bearer <jwt>
X-Platform: android | ios
```

Use the existing RexOne naming conventions if the branch already has a better route.

---

## 6. Response contract

Recommended:

```json
{
  "status": {
    "code": 200,
    "message": "Offline download ready",
    "error": null
  },
  "data": {
    "asset_id": "uuid",
    "delivery": {
      "type": "offline",
      "url": "https://media.example.com/...",
      "expires_at": "2026-09-14T02:00:00Z"
    },
    "offline": {
      "expires_at": "2026-10-14T01:00:00Z"
    },
    "media": {
      "content_type": "video/mp4",
      "format": "mp4",
      "size_bytes": 183747383,
      "duration_secs": 826.4
    }
  }
}
```

Two expirations mean different things:

```text
delivery.expires_at
  → how long the provider URL can fetch bytes

offline.expires_at
  → how long the local copy may be played offline
```

Never reuse one value for both concepts.

---

## 7. Offline policy

Core decides whether local retention is allowed using existing authorization/entitlement rules.

Examples:

```text
permanent ownership
  → offline_expires_at = null

subscription
  → min(subscription.active_until, now + offline_max_ttl)

temporary access
  → min(access.active_until, now + offline_max_ttl)

no access
  → deny
```

Suggested configurable upper bound:

```env
OFFLINE_MEDIA_MAX_TTL_DAYS=30
```

This is a product policy, not a transport requirement.

---

## 8. Eligibility

Before issuing an offline URL verify:

1. Asset exists.
2. Asset is not discarded.
3. User is authenticated.
4. User is authorized.
5. Offline retention is allowed.
6. Asset type is playable.
7. Asset has a valid backing object.
8. Asset state is playable.

Recommended types:

```text
audio
video
```

Recommended states:

```text
ready
optimal
```

Do not issue for:

```text
pending
processing
failed
```

unless an existing RexOne rule explicitly allows it.

---

## 9. StorageService

Do not create a second storage stack.

Reuse the provider-neutral boundary:

```ruby
StorageService::Client.delivery_url(
  asset,
  purpose: :offline,
  expires_in: ...
)
```

or reuse the current playback delivery primitive if `purpose:` adds no real value.

Controllers must not call Garage/AWS signing code directly.

---

## 10. Core database

V1 requires **no new Core table**.

Do not add:

```text
offline_downloads
offline_sessions
device_downloads
asset_downloads
download_tokens
```

unless a real server-side requirement later appears.

Core already has the necessary authority through:

```text
User
Asset
Access / entitlement
```

Possible future reasons for a table:

- per-device limits,
- remote revocation,
- compliance/audit trail,
- download analytics,
- DRM licenses.

Not V1.

---

## 11. Error behavior

Use the normal RexOne envelope.

Expected cases:

```text
404 → missing / intentionally hidden asset
403 → not authorized for offline access
409 → asset exists but is not playable yet
503 → temporary provider/storage failure
```

Follow existing RexOne conventions if a domain already uses another status.

Never expose raw provider exceptions or object keys.

---

# MOBILE STORAGE

## 12. Private persistent directory

Use Flutter:

```dart
final root = await getApplicationSupportDirectory();
```

Recommended:

```text
<ApplicationSupport>/offline/
```

Do **not** use:

```dart
getDownloadsDirectory()
```

Do not use public media directories.

Do not use Android MediaStore.

---

## 13. Why not cache storage

Do not store a user-visible “Downloaded” item in a cache directory.

The OS may evict cache files.

That creates:

```text
Downloaded ✓
   ↓
OS needs space
   ↓
file disappears
```

Use persistent app-private storage instead.

Then explicitly exclude the offline directory from backup.

---

## 14. User-scoped layout

Recommended:

```text
offline/
└── <opaque-user-scope>/
    ├── <asset-id>.mp4
    ├── <asset-id>.mp3
    └── ...
```

Use opaque IDs/hashes.

Do not use:

```text
email
username
full name
course title
media title
```

in paths.

---

## 15. Opaque filenames

Good:

```text
57cf3e48-....mp4
a23018cf-....m4a
```

Bad:

```text
Premium Lesson 8.mp4
john@example.com-lesson.mp4
```

Private storage already hides normal browsing, but opaque names reduce accidental information disclosure.

---

## 16. Backup exclusion — required

Downloaded media is re-downloadable and may be large.

It must **not** enter cloud/device backup.

### iOS

`Application Support` is private but included in normal backups by default.

Mark the offline directory/files:

```text
isExcludedFromBackup = true
```

using the Foundation URL resource property.

### Android

The normal app files directory can participate in Auto Backup/device transfer.

Exclude:

```text
offline/
```

from both cloud backup and device-to-device transfer through Android backup rules.

For Android 12+ use the current `dataExtractionRules` configuration.

Maintain the legacy rule for older supported Android versions where required.

Alternative:

```text
Context.noBackupFilesDir
```

is also valid if RexOne already has a native helper for it.

### Chosen V1 approach

Prefer:

```text
getApplicationSupportDirectory()
+
Android backup exclusion rules
+
iOS isExcludedFromBackup
```

unless the existing Mobile codebase has a cleaner no-backup abstraction.

---

## 17. No storage permission

The normal implementation should not request:

```text
READ_EXTERNAL_STORAGE
WRITE_EXTERNAL_STORAGE
MANAGE_EXTERNAL_STORAGE
```

If the feature triggers a broad storage permission prompt, reconsider the chosen directory.

---

# MOBILE DOMAIN

## 18. Recommended services

Conceptually:

```text
OfflineMediaService
OfflineMediaStorage
OfflineMediaRepository
MediaPlaybackService
```

Keep the existing RexOne Mobile module/controller/service conventions.

Do not force this exact folder tree if the repository already has an established pattern.

---

## 19. OfflineMediaService

Responsibilities:

```text
download(asset)
retry(asset)
cancel(asset)

isAvailable(asset)
isValid(asset)
localFile(asset)

remove(asset)
removeAll()

cleanupIncomplete()
cleanupExpired()

storageUsed()
downloadState(asset)
```

Optional later:

```text
pause(asset)
resume(asset)
```

---

## 20. MediaPlaybackService

One place chooses local vs network playback.

Conceptually:

```dart
Future<MediaSource> resolve(Asset asset) async {
  final local = await offlineMediaService.validLocalCopy(asset.id);

  if (local != null) {
    return LocalMediaSource(local.file);
  }

  final playback = await playbackService.fetch(asset.id);
  return NetworkMediaSource(playback.url);
}
```

Pages should not repeatedly implement:

```dart
if (offline) ...
else ...
```

The rest of the app should simply ask:

```text
play(asset)
```

---

## 21. Local metadata

Keep a small local manifest:

```json
{
  "asset_id": "uuid",
  "user_id": "uuid",
  "relative_path": "offline/<scope>/<opaque>.mp4",
  "content_type": "video/mp4",
  "format": "mp4",
  "expected_size_bytes": 183747383,
  "actual_size_bytes": 183747383,
  "downloaded_at": "2026-09-14T01:00:00Z",
  "offline_expires_at": "2026-10-14T01:00:00Z",
  "asset_revision": "...",
  "status": "ready"
}
```

Prefer a relative path.

Do not persist full provider URLs.

---

## 22. Local persistence

Reuse the current RexOne Mobile persistence layer if it can safely store this small manifest.

Do not introduce a new database solely for V1.

If offline data later becomes complex, hide persistence behind:

```text
OfflineMediaRepository
```

so implementation can move to SQLite/Isar/etc. without rewriting playback/download logic.

---

## 23. Download states

Use explicit states:

```text
not_downloaded
requesting
downloading
ready
failed
expired
```

Optional future:

```text
paused
```

Avoid multiple booleans that can contradict one another.

---

# DOWNLOAD PIPELINE

## 24. Request flow

```text
User taps Download
      ↓
Mobile requests Core offline grant
      ↓
Core authorizes
      ↓
Core returns temporary provider URL
      ↓
Mobile streams provider response to .partial
      ↓
validate completed bytes
      ↓
rename to final file
      ↓
save ready metadata
      ↓
Available Offline
```

---

## 25. Never buffer the whole file

The HTTP client must stream directly to disk.

Bad:

```text
GET 800 MB
  ↓
entire file in memory
  ↓
write
```

Good:

```text
HTTP stream
  ↓
file sink
```

Requirements:

- progress,
- cancel,
- bounded memory,
- status handling,
- direct file streaming.

Reuse RexOne Mobile's existing networking stack where possible.

---

## 26. Partial file

Never download directly into the final playable file.

Use:

```text
<asset>.partial
```

Only after success:

```text
verify
  ↓
close/flush
  ↓
rename final
  ↓
persist ready metadata
```

An app crash or network failure must never leave a half file marked playable.

---

## 27. Atomic completion order

Correct:

```text
download .partial
verify
rename final
persist ready metadata
```

Avoid:

```text
persist ready metadata
rename later
```

because process death can leave broken metadata.

---

## 28. Integrity

At minimum verify:

```text
file exists
size > 0
actual size == expected size
```

when expected size is trustworthy.

If RexOne already stores a canonical checksum, optionally verify it.

Do not add expensive hashing solely to create a new feature if no checksum contract currently exists.

---

## 29. Progress

Expose:

```text
downloaded_bytes
total_bytes
progress
```

UI:

```text
183 MB / 420 MB
43%
```

If total is unknown:

```text
Downloading…
183 MB
```

Do not fake percentages.

---

## 30. Cancel

Cancel must:

1. cancel network request,
2. close file sink,
3. remove `.partial`,
4. clear transient state,
5. return to `not_downloaded`.

No stale partial files.

---

## 31. Failure

For the simplest path:

```text
failure
  → failed
  → Retry
```

If resume is not implemented yet:

```text
delete partial
retry from zero
```

For meaningful video sizes, implement Range resume.

---

## 32. Recommended Range resume

Because RexOne's provider path supports byte ranges:

```text
.partial exists
      ↓
N = partial file length
      ↓
request fresh offline grant
      ↓
GET Range: bytes=N-
      ↓
expect 206
      ↓
validate Content-Range
      ↓
append
```

Critical rules:

- obtain a fresh URL when the previous signed URL may have expired,
- append only when the server confirms the expected range,
- if server returns full `200 OK`, restart safely,
- never append a full object to a partial object.

If V1 media can reach hundreds of MB, I recommend including this before calling the feature finished.

---

# APP LIFECYCLE

## 33. Startup reconciliation

On initialization:

```text
OfflineMediaService.initialize()
```

reconcile metadata and filesystem.

Rules:

```text
ready metadata + missing file
  → remove metadata

file + no metadata
  → remove orphan

partial + no active transfer
  → resumable state OR cleanup

expired item
  → apply expiration policy
```

Disk and metadata can drift. Handle it.

---

## 34. App restart

A completed download must survive normal app restarts.

An incomplete download should:

```text
resume
```

if Range resume is implemented, or:

```text
be safely retryable
```

if not.

Never present incomplete media as ready.

---

## 35. App background

Do not add complex OS-level background download infrastructure in V1 unless required.

Initial behavior may support downloading while RexOne remains in a normal active lifecycle.

If later required:

```text
continue after background / app kill
system progress notification
OS-managed retry
```

implement native background downloads as a separate milestone.

---

# OFFLINE VALIDITY

## 36. Playback expiry

Before local playback:

```text
offline_expires_at == null
  → valid

now < offline_expires_at
  → valid

now >= offline_expires_at
  → expired
```

If expired while offline:

```text
Connect to the internet to renew this download.
```

If online:

```text
request Core renewal
```

---

## 37. Renewal without redownload

If:

- user still has access,
- local media revision still matches Core,
- only the offline validity window expired,

then:

```text
Core grants new offline expiry
  ↓
update local metadata
  ↓
keep existing bytes
```

No unnecessary re-download.

---

## 38. Asset revision

Store a stable revision indicator if Core already exposes one:

```text
updated_at
storage version
storage key revision
checksum
```

When online:

```text
local revision != Core revision
  → invalidate / redownload
```

Do not create a new revision framework if an existing Asset field already does the job.

---

## 39. Device clock

V1 expiry uses application/device time locally.

A compromised user can manipulate device time.

That is acceptable under the explicit non-DRM V1 model.

Do not build tamper-resistant licensing yet.

---

# USER ISOLATION

## 40. Account isolation

Offline files belong to the account that downloaded them.

Never allow:

```text
User A downloads
User A logs out
User B logs in
User B sees/plays A's media
```

Every record and directory must be user-scoped.

---

## 41. Logout policy

Recommended V1:

```text
logout
  ↓
cancel active downloads
  ↓
delete that user's local offline files
  ↓
delete offline metadata
```

This is simplest and safest.

Keeping downloads across logout can be added later if the UX truly requires it.

---

## 42. Account deletion

Account deletion must clear:

```text
completed offline files
partial files
metadata
active downloads
```

before/alongside auth-state cleanup.

---

## 43. Uninstall

The OS removes app-private files on uninstall.

No server cleanup is required because V1 does not persist device-download rows.

---

# STORAGE MANAGEMENT

## 44. Preflight space check

Before download:

```text
required =
expected asset bytes
+ safety margin
```

Suggested margin:

```text
max(50 MB, 5–10% of file size)
```

If insufficient:

```text
Not enough storage.
Need: 420 MB
Available: 210 MB
```

Do not start doomed downloads.

---

## 45. Offline Downloads UI

Recommended:

```text
Offline Downloads

Video Lesson 01      120 MB   Ready
Audio Lesson 02       18 MB   Ready
Video Lesson 03      340 MB   63%

Storage used: 478 MB

[ Remove All Downloads ]
```

Actions:

```text
Play
Retry
Cancel
Remove
Remove All
```

Never expose filesystem paths.

---

## 46. Download action states

```text
not_downloaded → Download
requesting     → Preparing…
downloading    → progress + Cancel
ready          → Downloaded ✓ / Remove
failed         → Retry
expired        → Renew
```

---

## 47. Playback preference

If a valid local file exists:

```text
use local
```

even while online.

Benefits:

- no bandwidth,
- no signed URL,
- fast startup,
- consistent behavior.

If local is missing/invalid:

```text
online → stream
offline → unavailable
```

---

# PLAYER

## 48. Video

Use the existing video player abstraction with a local file source.

Conceptually:

```dart
VideoPlayerController.file(
  File(localPath),
)
```

The UI should remain the same as online playback.

Only the media source changes.

---

## 49. Audio

Use the existing audio player abstraction with:

```text
network source
or
local file source
```

No duplicate offline audio UI.

---

## 50. Thumbnail/subtitle dependencies

Decide explicitly whether an offline item includes:

```text
media
thumbnail
subtitle
```

Recommended:

- download thumbnail if Offline Downloads UI needs it,
- download subtitle if offline caption support is part of the playback contract.

Keep them private and tied to the parent Asset.

---

# SECURITY

## 51. V1 protection

Security model:

```text
private provider object
Core authorization
short-lived delivery URL
private app sandbox
user-scoped files
offline expiry
backup exclusion
no public export
```

This is good normal application protection.

It is not DRM.

---

## 52. Do not persist presigned URLs

Do not store:

```text
https://...signature=...
```

in long-lived local metadata.

Store:

```text
asset_id
relative_path
expiry
revision
format
size
```

Provider URLs are ephemeral capabilities.

---

## 53. Logging

Do not log:

- full presigned URL,
- signature query,
- JWT,
- storage credentials.

Useful:

```text
asset_id
user_id
state
expected bytes
actual bytes
error category
```

---

## 54. Encryption deferred

Do not custom-encrypt media in V1.

Custom encryption immediately creates:

```text
decrypt-to-temp-file
or
custom AVPlayer/ExoPlayer data source
```

plus key management and seeking complexity.

App-private storage is enough for V1.

---

# TESTING

## 55. Core request specs

Cover:

- ready video grant,
- ready audio grant,
- optimal media,
- unauthorized user,
- missing asset,
- discarded asset,
- unsupported type,
- pending asset,
- processing asset,
- failed asset,
- expired entitlement,
- permanent entitlement,
- TTL clamping,
- provider failure,
- envelope shape,
- no credentials leaked.

---

## 56. Core service specs

Cover:

- offline expiry calculation,
- permanent policy,
- max TTL,
- access expiry clamp,
- provider URL TTL separate from offline expiry,
- StorageService used,
- no media body read by Core,
- no download database row created.

---

## 57. Mobile unit tests

### Metadata

- serialization,
- expiration,
- wrong user rejected,
- relative path resolution,
- missing file invalidates item.

### States

```text
not_downloaded → requesting
requesting → downloading
downloading → ready
downloading → failed
downloading → not_downloaded on cancel
ready → expired
ready → not_downloaded on remove
```

### Resolver

- valid local → local,
- missing local → network,
- expired + online → renewal/network,
- expired + offline → unavailable,
- another user's file ignored.

---

## 58. Filesystem tests

Cover:

- root creation,
- user directory,
- partial creation,
- final rename,
- partial cleanup,
- orphan cleanup,
- remove one,
- remove all,
- storage usage,
- startup reconciliation.

---

## 59. Download integration tests

Cover:

- download success,
- progress,
- cancel,
- retry,
- network failure,
- signed URL expiry,
- fresh URL retry,
- incorrect length,
- low disk.

If resume is enabled:

- proper Range,
- expected `206`,
- Content-Range validation,
- unexpected `200` restart,
- no corruption.

---

## 60. Device matrix

| Case                   | Android | iOS |
| ---------------------- | ------: | --: |
| Download video         |       ☐ |   ☐ |
| Download audio         |       ☐ |   ☐ |
| Airplane-mode playback |       ☐ |   ☐ |
| Seek local video       |       ☐ |   ☐ |
| Relaunch app           |       ☐ |   ☐ |
| Cancel/retry           |       ☐ |   ☐ |
| Logout cleanup         |       ☐ |   ☐ |
| Expiry/renewal         |       ☐ |   ☐ |
| Low storage            |       ☐ |   ☐ |
| Not in Gallery         |       ☐ |   ☐ |
| Not in Downloads       |       ☐ |   ☐ |
| Not in Files           |     N/A |   ☐ |
| Backup excluded        |       ☐ |   ☐ |

---

## 61. Large-file test

Test at least one realistic:

```text
300–1000 MB
```

Verify:

- bounded memory,
- responsive UI,
- correct progress,
- cancel,
- resume/retry,
- no public copy,
- local playback,
- app restart behavior.

Do not validate this feature using only tiny fixtures.

---

# IMPLEMENTATION ORDER

## Phase 0 — policy

Decide:

- allowed media types,
- who may download,
- offline TTL,
- permanent ownership behavior,
- logout policy,
- expiry grace policy.

**Done when:** product rules are explicit.

---

## Phase 1 — Core offline grant

Implement:

- route,
- thin controller,
- authorization,
- eligibility,
- offline expiry,
- delivery URL,
- serializer,
- request/service specs.

**Done when:** Mobile gets a temporary download URL plus an offline validity window.

---

## Phase 2 — private storage

Implement:

- Application Support directory,
- user scoping,
- opaque names,
- metadata repository,
- iOS backup exclusion,
- Android backup exclusion,
- startup reconciliation.

**Done when:** test media is private, persistent, and excluded from backup.

---

## Phase 3 — downloader

Implement:

- stream-to-disk,
- `.partial`,
- progress,
- cancel,
- validation,
- atomic rename,
- metadata commit.

**Done when:** a large file downloads without full memory buffering.

---

## Phase 4 — playback resolver

Implement:

```text
valid local → local source
otherwise → online progressive source
```

**Done when:** one player UX seamlessly handles both.

---

## Phase 5 — expiry/account isolation

Implement:

- local expiry check,
- renewal,
- stale revision handling,
- logout cleanup,
- account deletion cleanup,
- per-user directories.

**Done when:** offline access respects both user identity and entitlement lifetime.

---

## Phase 6 — Offline Downloads UI

Implement:

- button states,
- progress,
- cancel/retry,
- list,
- remove,
- remove all,
- storage usage.

**Done when:** users can manage offline content completely inside RexOne.

---

## Phase 7 — resume

Recommended for large video:

- Range resume,
- fresh offline grant,
- safe append validation,
- fallback restart.

**Done when:** interrupted large downloads do not unnecessarily restart.

---

## Phase 8 — hardening

Verify:

- Android privacy,
- iOS privacy,
- backup exclusion,
- airplane mode,
- low storage,
- restart,
- large files,
- expiry,
- user switching.

**Done when:** it behaves like a native offline feature, not a raw file download.

---

# DEFINITION OF DONE

## 62. V1 complete when

1. Core exposes an authenticated offline-grant contract.
2. Existing access rules authorize the grant.
3. Core returns a short-lived provider URL.
4. Core returns an offline validity window.
5. Rails never proxies the large media body.
6. No Core per-download table exists without a real need.
7. Mobile downloads directly from provider storage.
8. Downloads stream to disk, not memory.
9. `.partial` files cannot be played.
10. Completed media lives in persistent app-private storage.
11. Files are not in Downloads.
12. Files are not in Gallery.
13. iOS files are not exposed in Files.
14. No broad Android storage permission is requested.
15. Offline files are excluded from iCloud backup.
16. Offline files are excluded from Android cloud/D2D backup.
17. Downloads are user-scoped.
18. Logout/account deletion follows policy.
19. Valid local media plays with no network.
20. Local playback is preferred when available.
21. Missing local media falls back to streaming when online.
22. Expiry is enforced.
23. Valid access can renew expiry without unnecessary redownload.
24. Progress works.
25. Cancel/retry works.
26. Remove one works.
27. Remove all works.
28. Storage usage is visible.
29. Startup reconciliation handles partial/orphan/missing files.
30. Large-file testing proves bounded memory.
31. Android device tests pass.
32. iOS device tests pass.
33. Core tests pass.
34. Mobile tests pass.
35. README/ECOSYSTEM/docs are updated.

---

# FUTURE

## 63. Later improvements

Only when required:

- native background downloads,
- Wi-Fi-only downloads,
- bulk course/playlist download,
- local quality choice,
- smart cleanup/LRU,
- per-device quotas,
- remote revocation,
- per-device license tracking,
- stronger local encryption.

---

## 64. Future HLS + CMAF

RexOne's future adaptive pipeline should use:

```text
HLS
+
CMAF / fragmented MP4
```

with:

```text
init.mp4
001.m4s
002.m4s
003.m4s
```

When that work begins, revisit offline packaging rather than forcing the current single-file progressive downloader to treat hundreds of fragments like unrelated files.

Future media architecture:

```text
Asset
  ↓
Media Delivery
  ├── progressive online
  ├── HLS/CMAF online
  └── protected offline
```

For high-value licensed content:

```text
HLS/CMAF
  +
Widevine offline licenses
  +
FairPlay offline support
```

That is the correct time to introduce real DRM-grade offline protection.

Do not build home-grown DRM now.

---

# 65. Final principle

Offline mode necessarily stores media bytes locally.

The requirement is not:

> “Never download the media.”

The requirement is:

> **“Keep the downloaded media private to RexOne and expose it as an in-app capability rather than a user-exported file.”**

For V1:

```text
Core authorizes retention
        ↓
Garage serves bytes
        ↓
Flutter stores privately
        ↓
backup excluded
        ↓
MediaPlaybackService prefers local
        ↓
offline expiry protects temporary access
```

This gives RexOne a simple, smooth offline foundation without prematurely dragging in Web offline storage, HLS packaging, custom encryption, DRM, or unnecessary server state.

---

# References

- Flutter `path_provider` / Application Support:
  https://pub.dev/documentation/path_provider/latest/path_provider/

- Flutter `video_player` / local file playback:
  https://pub.dev/documentation/video_player/latest/video_player/VideoPlayerController-class.html

- Android app-specific storage:
  https://developer.android.com/training/data-storage/app-specific

- Android storage overview:
  https://developer.android.com/training/data-storage

- Android backup/data extraction rules:
  https://developer.android.com/about/versions/12/behavior-changes-12

- Apple Application Support and backup exclusion:
  https://developer.apple.com/documentation/foundation/using-the-file-system-effectively

- Apple `NSURLIsExcludedFromBackupKey`:
  https://developer.apple.com/documentation/foundation/urlresourcekey/isexcludedfrombackupkey
