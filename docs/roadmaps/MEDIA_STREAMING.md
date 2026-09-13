# Audio & Video Streaming Roadmap

> **Status:** Implementation roadmap for `rexone-core`
> **Current target:** Progressive audio/video delivery through short-lived provider-backed playback URLs
> **Future target:** HLS + CMAF / fragmented MP4 when adaptive streaming is actually required

---

## 1. Decision

Rexone will **not** make Rails the default media byte proxy and will **not** introduce HLS in the first implementation.

The first production streaming contract is:

```text
Client
  │
  │ authenticated playback request
  ▼
Rexone Core
  │
  │ authorize Asset
  │ resolve delivery through StorageService
  ▼
short-lived playback URL
  │
  ▼
Web / Mobile media player
  │
  │ normal HTTP GET + Range requests
  ▼
Garage / storage provider
```

### Core principle

> **Core authorizes. Storage serves bytes.**

Rexone Core remains responsible for:

- authentication,
- authorization,
- asset ownership/access rules,
- deciding whether an asset is playable,
- choosing the storage provider,
- producing a short-lived delivery URL,
- exposing stable media metadata,
- keeping storage/provider credentials private.

The storage layer remains responsible for:

- serving the object bytes,
- HTTP range requests,
- partial responses,
- seeking,
- large-file transfer,
- bandwidth-heavy delivery.

This keeps Rails out of the hot path for every video byte while preserving Rexone as the authority over access.

---

# 2. Goals

The V1 implementation must provide:

- protected playback for stored audio and video,
- immediate playback without downloading the whole file,
- seek / scrub support,
- smooth Web, Android, and iOS compatibility,
- provider-neutral behavior through the existing storage abstraction,
- no permanent public asset URLs,
- no storage credentials exposed to clients,
- no Rails/Puma media-byte bottleneck,
- no unnecessary streaming session tables or state,
- a clean path to HLS + CMAF later.

---

# 3. Non-goals for V1

Do **not** build these now:

- HLS playlists,
- adaptive bitrate ladders,
- `.ts` segments,
- CMAF packaging,
- DASH,
- a custom chunk API,
- WebSocket media transport,
- `ActionController::Live` for normal stored media,
- a `StreamingSession` database model,
- a `PlaybackSession` database model,
- a media-specific token table,
- client-managed S3 credentials,
- direct client knowledge of Garage object keys,
- a Rails proxy for every Garage byte,
- multi-quality transcodes solely for this feature.

If the current feature branch already contains a Rails byte-range proxy, keep it only where it has a concrete purpose such as local-development fallback. It should not be the default Garage production path.

---

# 4. Existing Rexone boundaries to preserve

The implementation should fit the existing architecture rather than create a parallel media system.

```text
Asset
  │
  ▼
StorageService::Client
  │
  ├── Garage / S3-compatible storage
  ├── Cloudinary
  └── Local storage
```

Media processing remains separate:

```text
Asset
  │
  ▼
media queue
  │
  ├── image processing
  ├── audio processing
  ├── video compression
  ├── thumbnail generation
  └── format conversion
```

Playback is the **delivery side** of the same media lifecycle:

```text
upload
  ↓
persist
  ↓
process / optimize
  ↓
ready / optimal
  ↓
authorize playback
  ↓
generate temporary delivery URL
  ↓
play / seek
```

Do not create a second source of truth for media.

`Asset` remains the stable product-level record.

---

# 5. Public API contract

## 5.1 Recommended endpoint

Use one explicit playback/delivery endpoint.

Recommended:

```http
GET /v1/assets/:id/playback
Authorization: Bearer <jwt>
X-Platform: web | android | ios
```

If the current branch already has a naming convention that fits better, keep the existing convention rather than renaming merely for this roadmap.

The important contract is the behavior, not the word `playback`.

---

## 5.2 Successful response

Recommended response shape:

```json
{
  "status": {
    "code": 200,
    "message": "Playback ready",
    "error": null
  },
  "data": {
    "asset_id": "uuid",
    "delivery": {
      "type": "progressive",
      "url": "https://media.example.com/...",
      "expires_at": "2026-09-13T14:00:00Z"
    },
    "media": {
      "content_type": "video/mp4",
      "format": "mp4",
      "size_bytes": 128734221,
      "duration_secs": 643.2,
      "thumbnail": {
        "id": "uuid",
        "url": "..."
      },
      "subtitle": {
        "id": "uuid",
        "url": "..."
      }
    }
  }
}
```

### Why `delivery.type` exists

Do not expose provider-specific concepts such as:

```json
{
  "presigned_s3_url": "..."
}
```

Use:

```json
{
  "delivery": {
    "type": "progressive",
    "url": "..."
  }
}
```

That gives Rexone one small, honest future extension point.

Later:

```json
{
  "delivery": {
    "type": "hls",
    "url": "https://media.example.com/.../master.m3u8"
  }
}
```

No large streaming framework is needed now.

---

# 6. Playback eligibility

Before generating a playback URL, Core must verify the asset is eligible.

At minimum:

1. Asset exists.
2. Asset is not discarded.
3. Current user is authenticated where the resource requires authentication.
4. Current user is authorized to access the asset.
5. Asset type is playable.
6. Asset has a valid backing storage key.
7. Asset processing state is playable.

Recommended playable asset types:

```text
audio
video
```

Potentially allow specific attachment/general assets only if their media type is explicitly supported.

Recommended processing states:

```text
ready
optimal
```

Do not generate playback for:

```text
pending
processing
failed
```

unless an existing Rexone rule explicitly allows the original object to be played during processing.

---

# 7. Authorization

Authorization must happen **before** generating the provider URL.

The short-lived URL is a delivery capability granted only after Core decides the user is allowed to access the logical Asset.

The controller should not contain complicated ownership/business rules.

Preferred structure:

```text
Controller
  ↓
existing authorization / policy / permission boundary
  ↓
Playback / storage service
```

Rules should come from the same product authorization model already used for the asset or its parent resource.

Do not build a second permissions system specifically for streaming.

---

# 8. StorageService contract

## 8.1 Add a provider-neutral playback method

Recommended conceptual API:

```ruby
StorageService::Client.playback_url(
  asset,
  expires_in: MediaConstants::Playback::URL_TTL
)
```

or:

```ruby
StorageService::Client.delivery(
  asset,
  expires_in: ...
)
```

Choose the name that best matches the current service style.

The important requirement is that controllers do **not** call AWS/Garage signing primitives directly.

Bad:

```ruby
Aws::S3::Presigner.new.presigned_url(...)
```

inside a controller.

Good:

```ruby
StorageService::Client.playback_url(asset)
```

The provider implementation owns the signing details.

---

# 9. Garage / S3-compatible implementation

For Garage, generate a short-lived **presigned GET URL**.

Conceptually:

```ruby
object.presigned_url(
  :get,
  expires_in: playback_ttl,
  response_content_type: asset.mime_type,
  response_content_disposition: "inline"
)
```

The exact AWS SDK call should follow the existing Rexone S3/Garage adapter style.

### Required behavior

The returned URL must:

- use the externally reachable media/storage host,
- remain valid long enough for normal playback,
- allow ordinary media-player GET requests,
- allow the storage provider to satisfy Range requests,
- preserve the correct content type,
- use inline delivery rather than forcing download.

---

# 10. Internal vs public Garage endpoint

This is critical.

Rexone commonly needs two different storage addresses:

```text
Core → Garage internal network
Client → Garage public network
```

Recommended configuration:

```env
STORAGE_ENDPOINT=http://garage:3900
STORAGE_PUBLIC_ENDPOINT=https://media.example.com
```

The internal endpoint is used for server-to-server operations.

The public endpoint is used when signing URLs that Web/Mobile must actually reach.

## Important SigV4 rule

Do **not**:

1. sign a URL for `http://garage:3900`,
2. replace the hostname afterward with `https://media.example.com`.

The request host participates in signature validation.

Use an S3 client / presigner configured with the correct public endpoint when generating public playback URLs.

A clean implementation may maintain:

```text
storage operation client
storage public-delivery presigner/client
```

without exposing this distinction above the storage adapter.

---

# 11. Playback URL TTL

Make the TTL configurable.

Recommended starting value:

```env
MEDIA_PLAYBACK_URL_TTL=3600
```

Default:

```text
1 hour
```

Why not extremely short?

Media players can make additional requests while the user:

- seeks,
- pauses,
- resumes,
- buffers,
- changes network,
- returns from temporary background state.

A URL that expires too aggressively can turn a healthy player into random playback failures.

Why not permanent?

Authorization may change, subscriptions may expire, access may be revoked, and object URLs should not become permanent shareable public capabilities.

### Rule

Playback URLs are:

```text
short-lived
not persisted
not cached in Asset
not stored as database state
```

Core can mint a new one when needed.

---

# 12. Browser / player Range behavior

Rexone itself does **not** need to manually parse `Range` for the Garage production path.

The media player will issue requests similar to:

```http
GET /object.mp4
Range: bytes=0-1048575
```

The storage server may respond:

```http
HTTP/1.1 206 Partial Content
Accept-Ranges: bytes
Content-Range: bytes 0-1048575/128734221
Content-Length: 1048576
Content-Type: video/mp4
```

This enables:

- progressive playback,
- random seeking,
- resume,
- partial retrieval,
- no requirement to download the whole object first.

Invalid ranges should be handled by the underlying HTTP/storage implementation with the correct range semantics.

Core should test the real provider behavior instead of reimplementing HTTP range logic unless a fallback adapter requires it.

---

# 13. CORS requirements

Because Web may play media from a different origin, configure the public media/storage origin correctly.

At minimum verify browser access for:

```text
GET
HEAD   # if the chosen player/browser uses it
```

And expose/allow the headers actually required by the player and debugging tooling, including where applicable:

```text
Range
Content-Range
Content-Length
Content-Type
Accept-Ranges
ETag
Last-Modified
```

Do not blindly use `Access-Control-Allow-Origin: *` if the final security model requires narrower origins.

Recommended production origins should come from configuration.

---

# 14. GET vs HEAD compatibility

Presigned operations are method-specific.

A URL signed for `GET` is not automatically a generic signed URL for every HTTP method.

Therefore, test the exact clients Rexone supports.

Required matrix:

```text
Chrome
Safari
Firefox
Android player
iOS player
```

Check whether the chosen Web and Flutter player implementations:

- use only GET / Range,
- make HEAD probes,
- retry using another method,
- issue additional requests after seeking.

If a supported client requires a method the chosen presigned delivery cannot satisfy cleanly, solve that concrete compatibility issue.

Do **not** build a media gateway in advance without an observed need.

---

# 15. Content-Type

Media playback depends on correct MIME metadata.

At minimum ensure:

```text
video/mp4       → MP4
audio/mpeg      → MP3
audio/mp4       → M4A/AAC
video/webm      → WebM if intentionally supported
audio/ogg       → OGG if intentionally supported
```

Do not trust a random filename extension alone if Rexone already stores canonical format/content metadata.

The playback response and storage object should agree on media type.

---

# 16. Content-Disposition

Playback URLs should prefer:

```http
Content-Disposition: inline
```

Do not force:

```http
Content-Disposition: attachment
```

for media intended to play inside the application.

Downloads can use a separate download behavior if needed.

---

# 17. Video encoding target for effortless compatibility

The first implementation should optimize for broad playback compatibility rather than support every uploaded codec natively.

Recommended baseline output:

```text
Container: MP4
Video:     H.264
Audio:     AAC
```

This should be the normal optimized playback representation for ordinary video where transcoding is already part of the media pipeline.

---

# 18. MP4 fast start

Progressive MP4 should be generated with the index metadata positioned for early playback.

Use FFmpeg:

```bash
-movflags +faststart
```

`+faststart` moves the MP4 `moov` atom/index toward the beginning of the file.

This allows players to obtain media metadata without first reading the end of a large MP4.

### Media worker requirement

Where Rexone creates/re-encodes normal non-fragmented MP4 output, verify that the final playable output is fast-start optimized.

Do not apply this flag blindly to a future fragmented/CMAF pipeline; that is a different output structure.

---

# 19. Audio target

For ordinary Rexone playback, keep audio simple.

Preferred common outputs:

```text
MP3
M4A / AAC
```

Use the existing media processing architecture rather than introducing HLS for normal short or medium audio.

HLS audio can be introduced later if a real product needs:

- long-form adaptive audio,
- radio/live delivery,
- alternate audio renditions,
- large-scale streaming behavior.

---

# 20. Asset serialization

Do not automatically replace every serialized asset URL with an expiring playback URL.

Why:

- serialized records may be cached,
- URLs expire,
- not every asset listing means the client intends to play the asset,
- generating signatures for large admin lists is unnecessary.

Preferred:

```text
Asset metadata endpoint
        +
explicit playback endpoint
```

The client asks for playback only when playback is required.

For tiny public images/thumbnails, existing delivery behavior may remain unchanged.

---

# 21. Core controller responsibilities

The playback controller/action should remain thin.

Conceptually:

```ruby
def show
  asset = find_asset
  authorize_playback!(asset)

  delivery = StorageService::Client.playback_url(
    asset,
    expires_in: MediaConstants::Playback::URL_TTL
  )

  render_success(
    PlaybackSerializer.new(asset, delivery: delivery)
  )
end
```

Responsibilities:

- locate,
- authorize,
- validate playable state,
- request delivery URL,
- serialize.

It should not:

- parse byte ranges for Garage,
- open the full file,
- stream chunks through Rails,
- know SigV4 details,
- know Garage bucket credentials.

---

# 22. Recommended constants/configuration

Keep knobs centralized.

Conceptually:

```ruby
module MediaConstants
  module Playback
    URL_TTL = ENV.fetch("MEDIA_PLAYBACK_URL_TTL", 3600).to_i

    PLAYABLE_TYPES = %w[audio video].freeze
    PLAYABLE_STATUSES = %w[ready optimal].freeze
  end
end
```

Follow the project's existing constants/configuration conventions rather than copying this exact shape if another pattern already exists.

Avoid magic numbers inside controllers/services.

---

# 23. Error contract

Use normal Rexone API envelopes and localized messages.

Expected cases:

### `404`

Asset does not exist or is intentionally hidden from the requester.

### `403`

Authenticated user is not authorized to play it.

### `409` or existing domain-equivalent response

Asset exists but is not yet playable because processing is still pending/processing.

### `422`

Only where request input itself is invalid according to existing API conventions.

### `503`

Storage provider cannot currently create the delivery URL and the error is appropriate to surface as temporary infrastructure failure.

Do not expose raw AWS/Garage exceptions or object keys in public error messages.

---

# 24. Logging and observability

Log the **authorization/delivery decision**, not every streamed byte.

Useful structured context:

```text
asset_id
user_id
platform
provider
delivery_type=progressive
asset_type
format
result
error_class   # internal only
```

Do not log:

- the entire presigned URL,
- signature query parameters,
- storage access keys,
- JWTs.

The presigned URL is effectively temporary bearer capability data.

Treat it as sensitive.

---

# 25. Metrics worth having

Do not build a giant streaming analytics system in V1.

Useful low-cost metrics if existing observability supports them:

```text
playback_url_issued
playback_url_failed
playback_authorization_denied
playback_asset_not_ready
```

Business-level playback analytics should remain a separate product decision.

Do not infer “video watched” from “URL issued”.

---

# 26. Web integration

Web should:

1. request the Rexone playback endpoint through the normal authenticated API client,
2. receive the opaque delivery URL,
3. pass the URL to the existing media component/player,
4. let the browser perform ordinary media requests directly.

Conceptually:

```text
Axios authenticated request
        ↓
Core playback contract
        ↓
delivery.url
        ↓
Video / Audio component
```

Do not fetch the whole media file through Axios and convert it into a Blob unless there is a concrete requirement.

That defeats the effortless browser streaming path.

---

# 27. Mobile integration

Mobile should follow the same contract:

```text
authenticated Core request
        ↓
delivery.url
        ↓
native/Flutter media player network source
```

The player owns:

- buffering,
- pause,
- resume,
- seeking,
- partial retrieval.

The Rexone API client should not manually download the whole file first.

---

# 28. URL expiry recovery

A playback URL can expire while the UI remains open for a long time.

Keep recovery simple.

If the player fails because the delivery capability has expired:

```text
request a fresh playback URL
        ↓
restore playback position if available
        ↓
continue
```

Do not preemptively refresh URLs every few minutes unless real clients need it.

Start with failure-driven refresh.

---

# 29. Local storage fallback

Local development may not have an externally reachable S3-compatible endpoint.

If local storage already serves files directly, keep the simplest valid local path.

If Core must serve the local file, a Rails/send-file/range-capable development fallback is acceptable.

Keep it behind the same provider-neutral method:

```ruby
StorageService::Client.playback_url(asset)
```

The caller should not care whether:

```text
Garage → presigned URL
Cloudinary → provider URL
Local → Core/local URL
```

---

# 30. Cloudinary strategy

Do not force Garage signing semantics onto Cloudinary.

The provider adapter should produce the best appropriate protected/temporary delivery mechanism Cloudinary supports in the Rexone configuration.

The upper contract remains:

```text
delivery.type
delivery.url
expires_at
```

Provider-specific behavior belongs below `StorageService`.

---

# 31. Migration from a Rails Range proxy

If the feature branch already contains:

```text
GET /.../stream
        ↓
Rails parses Range
        ↓
Rails gets object range
        ↓
Rails sends bytes
```

migrate it deliberately.

### Keep

- playback authorization logic,
- playable-state validation,
- MIME handling,
- relevant tests,
- provider abstraction work,
- local fallback if useful.

### Replace for Garage production

```text
Rails byte forwarding
```

with:

```text
Core-authorized presigned playback URL
```

### Remove if no longer needed

- manual Range parsing,
- hand-built `Content-Range` responses,
- streaming loops,
- Rails response-body chunk forwarding,
- provider reads from the playback controller.

This should make the branch **smaller**, not larger.

---

# 32. Tests — Core

## 32.1 Request specs

Cover:

- authenticated authorized user receives playback delivery,
- unauthorized user is denied,
- missing asset,
- discarded asset,
- pending asset,
- processing asset,
- ready audio,
- ready video,
- optimal audio/video,
- unsupported type,
- missing storage key,
- storage provider failure,
- configured TTL is passed through,
- response never exposes provider credentials,
- response follows Rexone envelope conventions.

---

## 32.2 Storage service specs

For Garage adapter:

- creates presigned GET delivery,
- uses correct bucket/key,
- uses configured public endpoint,
- applies TTL,
- applies content type where supported,
- applies inline disposition where supported,
- does not mutate asset/storage state,
- does not persist generated URL.

For Local adapter:

- returns valid local playback delivery.

For Cloudinary adapter:

- returns provider-appropriate playback delivery.

Mock SDK signing in ordinary unit specs.

---

## 32.3 Real Garage integration test

At least one real integration/environment test should verify:

1. upload known MP4,
2. obtain playback URL through Core,
3. full GET works,
4. byte Range GET works,
5. seek-like later Range works,
6. invalid range behaves correctly,
7. correct content type is returned,
8. public hostname is reachable,
9. URL expires as configured.

Do not rely only on mocked AWS SDK specs.

---

# 33. Manual compatibility matrix

Before merge/release, test a real processed video and real audio asset.

| Client  | Play | Pause | Seek | Resume | Long pause | Expiry recovery |
| ------- | ---: | ----: | ---: | -----: | ---------: | --------------: |
| Chrome  |    ☐ |     ☐ |    ☐ |      ☐ |          ☐ |               ☐ |
| Safari  |    ☐ |     ☐ |    ☐ |      ☐ |          ☐ |               ☐ |
| Firefox |    ☐ |     ☐ |    ☐ |      ☐ |          ☐ |               ☐ |
| Android |    ☐ |     ☐ |    ☐ |      ☐ |          ☐ |               ☐ |
| iOS     |    ☐ |     ☐ |    ☐ |      ☐ |          ☐ |               ☐ |

Also test:

- slow network,
- Wi-Fi → mobile-network transition where practical,
- background → foreground on mobile,
- seeking near the end,
- repeated seek,
- replay,
- expired URL,
- revoked authorization before requesting a new URL.

---

# 34. Video fixtures

Keep small deterministic fixtures for test/development.

Recommended:

```text
short-video.mp4
short-audio.mp3
```

Video fixture should be:

```text
MP4
H.264
AAC
faststart
```

Avoid committing huge media files.

---

# 35. Media-processing acceptance criteria

For the progressive video representation:

- valid MP4,
- H.264 video where transcoding is expected,
- AAC audio where applicable,
- correct duration metadata,
- correct MIME type,
- `+faststart`,
- stored object accessible through delivery adapter,
- thumbnail relationship remains intact,
- subtitle relationship remains intact.

Do not change the existing optimal-first compression philosophy solely to implement playback.

---

# 36. Security checklist

- [ ] Garage bucket/object remains private.
- [ ] No permanent public object URL is stored in `Asset`.
- [ ] Presigned URL is generated only after authorization.
- [ ] Playback URL expires.
- [ ] Storage access key is never sent to clients.
- [ ] Storage secret is never sent to clients.
- [ ] Presigned URL is not logged in full.
- [ ] JWT is not embedded into the media URL.
- [ ] Asset ID cannot bypass authorization.
- [ ] Discarded assets cannot mint new playback URLs.
- [ ] Access revocation prevents minting new playback URLs.
- [ ] Public storage origin uses TLS in production.
- [ ] CORS is restricted to intended application origins where appropriate.

---

# 37. Performance checklist

- [ ] Rails does not proxy Garage media bytes in the production default path.
- [ ] Seeking does not download the entire file.
- [ ] Player can request byte ranges.
- [ ] Large media transfer does not occupy a Rails response stream.
- [ ] Playback URL generation is lightweight.
- [ ] Media processing remains in the media worker.
- [ ] MP4 uses faststart.
- [ ] No unnecessary signature generation happens in asset list endpoints.

---

# 38. Configuration checklist

Suggested environment settings:

```env
MEDIA_PLAYBACK_URL_TTL=3600

STORAGE_ENDPOINT=http://garage:3900
STORAGE_PUBLIC_ENDPOINT=https://media.example.com
```

Use existing environment-specific naming if Rexone already has equivalent settings.

The checked-in `.env.example` should document any new setting.

Never provide production credentials in example files.

---

# 39. Documentation updates after implementation

Update:

```text
README.md
ECOSYSTEM.md
docs/FOUNDATION.md
docs/VISUAL_WALKTHRUOGH.md
OpenAPI / Rswag
.env.example
```

Document the public contract, not internal signing details that users of Rexone do not need.

Visual walkthrough language should be:

```text
stored audio/video progressive streaming
```

Keep it distinct from:

```text
live speech streaming
```

---

# 40. Suggested implementation order

## Phase 0 — simplify the branch

- identify Rails byte-proxy code,
- keep reusable authorization/provider work,
- remove unnecessary streaming machinery,
- preserve local fallback only if useful.

**Done when:** the branch architecture clearly follows “Core authorizes; storage serves bytes”.

---

## Phase 1 — storage delivery abstraction

Implement provider-neutral playback URL generation.

- add storage playback/delivery method,
- Garage presigned GET implementation,
- public signing endpoint support,
- TTL configuration,
- MIME/disposition support,
- unit specs.

**Done when:** a service spec can create a valid temporary URL for a stored playable asset.

---

## Phase 2 — Core playback endpoint

Implement:

- route,
- thin controller,
- authorization,
- playable-state validation,
- serializer,
- consistent errors,
- request specs.

**Done when:** an authorized client can request a stable Rexone playback contract without learning anything about Garage.

---

## Phase 3 — Garage integration

Verify against real Garage:

- public URL,
- TLS,
- CORS,
- GET,
- Range,
- seek-like requests,
- expiry.

**Done when:** a browser-compatible Range request receives the correct partial object behavior from the actual deployed storage path.

---

## Phase 4 — media worker compatibility

Verify progressive representations:

- MP4/H.264/AAC,
- `+faststart`,
- MP3/M4A audio,
- content-type metadata,
- thumbnails,
- subtitles.

**Done when:** freshly processed assets are immediately compatible with the progressive playback path.

---

## Phase 5 — Web

- call playback endpoint,
- feed returned URL into existing media primitive,
- handle loading/error,
- refresh URL after expiry failure if needed,
- test browser matrix.

**Done when:** normal Web playback and seeking work without Axios downloading the whole file.

---

## Phase 6 — Mobile

- call same Core playback endpoint,
- feed URL into the chosen network media player,
- verify background/resume,
- verify seek,
- recover from expired delivery URL.

**Done when:** Android and iOS consume the same Core delivery contract cleanly.

---

## Phase 7 — production hardening

- logs,
- metrics,
- security review,
- URL redaction,
- load sanity check,
- production CORS,
- real long-file test,
- docs/OpenAPI.

**Done when:** Rails request throughput is not coupled to video byte throughput.

---

# 41. Definition of Done — V1

The V1 progressive media feature is complete when:

1. An authenticated authorized user can request playback for a playable Asset.
2. Core returns a provider-neutral `delivery` object.
3. Garage production delivery uses a short-lived presigned GET URL.
4. Rails does not relay the media body in the default Garage path.
5. Browser/player Range requests work.
6. Seeking works.
7. MP4 output uses a compatible progressive representation and faststart.
8. Web plays the URL directly.
9. Android plays the URL directly.
10. iOS plays the URL directly.
11. Expired URLs can be refreshed.
12. Unauthorized users cannot mint a playback URL.
13. Discarded/unready assets cannot mint a playback URL.
14. Presigned URLs/secrets are not stored or logged.
15. Local/other providers remain behind the same `StorageService` contract.
16. Core/request/service specs cover the contract.
17. Real Garage integration proves Range behavior.
18. README/ECOSYSTEM/Foundation/OpenAPI/Visual Walkthrough are updated.

---

# 42. Future: HLS + CMAF

HLS should be introduced only when a real Rexone product needs capabilities progressive MP4 cannot provide efficiently.

Typical triggers:

- long-form video,
- large video audiences,
- unstable/mobile networks,
- recurring buffering complaints,
- multiple quality levels,
- serious LMS/course/video-platform workloads,
- CDN optimization becoming materially important,
- alternate audio tracks,
- richer subtitle/caption delivery.

Do not migrate merely because HLS is more sophisticated.

---

# 43. Future HLS architecture

The existing V1 contract is deliberately able to evolve from:

```json
{
  "delivery": {
    "type": "progressive",
    "url": "https://media.example.com/video.mp4?..."
  }
}
```

to:

```json
{
  "delivery": {
    "type": "hls",
    "url": "https://media.example.com/video/master.m3u8?..."
  }
}
```

The product-level asset identity does not need to change.

---

# 44. Use HLS + CMAF, not an old TS-first design

When adaptive streaming is implemented, prefer:

```text
HLS
+
CMAF / fragmented MP4
```

rather than designing the new system around large numbers of old MPEG-2 `.ts` segments.

Conceptual output:

```text
asset/
├── master.m3u8
│
├── 1080p/
│   ├── playlist.m3u8
│   ├── init.mp4
│   ├── 001.m4s
│   ├── 002.m4s
│   └── ...
│
├── 720p/
│   ├── playlist.m3u8
│   ├── init.mp4
│   ├── 001.m4s
│   └── ...
│
└── 480p/
    ├── playlist.m3u8
    ├── init.mp4
    ├── 001.m4s
    └── ...
```

CMAF/fMP4 is a cleaner modern basis for adaptive streaming and keeps a path open to DASH-style delivery if Rexone eventually needs it.

FFmpeg already supports CMAF-compatible fragmented MP4 output.

---

# 45. Future adaptive pipeline

Conceptually:

```text
original / canonical source
        ↓
Media worker
        ↓
transcode bitrate ladder
        │
        ├── 1080p
        ├── 720p
        └── 480p
        ↓
CMAF package
        │
        ├── init.mp4
        ├── .m4s fragments
        └── .m3u8 manifests
        ↓
Garage
        ↓
CDN / media gateway
        ↓
HLS player
```

Keep this as a separate future milestone.

Do not mix this complexity into the progressive-streaming merge.

---

# 46. Future HLS components

Likely future additions:

```text
Media::PackageHlsJob
Media::TranscodeRenditionJob
```

or equivalent names consistent with Rexone's job conventions.

Potential responsibilities:

- bitrate ladder generation,
- resolution selection,
- codec normalization,
- CMAF fragmentation,
- HLS master playlist,
- variant playlists,
- alternate audio tracks,
- subtitles/captions,
- cleanup of generated renditions,
- retry/idempotency,
- real-time processing status.

Do not define the complete model/job hierarchy until HLS work begins.

---

# 47. Future HLS authorization

One presigned URL per file becomes less attractive when playback involves:

```text
master playlist
variant playlists
hundreds of fragments
alternate tracks
```

At that point consider:

```text
Core authorization
        ↓
short-lived media capability
        ↓
media.rexone.app
        ↓
Nginx / CDN / edge authorization
        ↓
Garage
```

This lets one authorization capability cover a logical media prefix/presentation rather than forcing Core to sign every fragment independently.

That is a future scaling decision, not a V1 requirement.

---

# 48. Future CDN

HLS/CMAF becomes especially valuable with a CDN because fragments can be cached close to users.

Future path:

```text
Client
  ↓
CDN / edge
  ↓ cache miss
media gateway / Garage
```

Core should remain the authorization/business authority.

Core should still not become the media-byte transport.

---

# 49. Future data model principle

Do not make every HLS fragment a normal first-class `Asset` row.

One logical media Asset may own an HLS presentation containing many generated storage objects.

Prefer a model where Rexone tracks the **presentation/rendition metadata** it needs without turning thousands of `.m4s` fragments into ordinary user-facing assets.

Exact schema should be designed when HLS requirements are real.

---

# 50. Future HLS quality ladder

Do not hard-code a Netflix-sized ladder from day one.

When HLS work begins, derive the first ladder from real Rexone product requirements.

Example only:

```text
1080p
720p
480p
```

The actual ladder should depend on:

- source resolution,
- content type,
- target devices,
- bandwidth,
- storage budget,
- media-worker capacity.

Never upscale a source simply to populate a ladder.

---

# 51. Future subtitles and audio

Rexone already has useful media relationships such as subtitle and thumbnail assets.

HLS can later provide structured tracks such as:

```text
Video
  ├── 1080p
  ├── 720p
  └── 480p

Audio
  ├── English
  ├── Burmese
  └── Spanish

Subtitles
  ├── English
  ├── Burmese
  └── Spanish
```

This is especially relevant for future LMS/education/video products.

Do not add alternate-track complexity until there is a concrete requirement.

---

# 52. Future transition rule

The V1 progressive implementation is successful if HLS can later be added by changing the **delivery strategy**, not by redesigning Rexone identity/storage architecture.

Target:

```text
Asset
  ↓
authorize
  ↓
Media Delivery
  │
  ├── progressive
  └── hls
```

Not:

```text
ProgressiveAsset
HlsAsset
StreamingAsset
VideoSession
SegmentAsset
...
```

Keep one clear media domain.

---

# 53. Final architecture

## Now

```text
                    Rexone Core
                         │
                         │ authorize
                         ▼
Asset ─────────► StorageService::Client
                         │
                         ▼
                 progressive delivery
                         │
                         ▼
               short-lived URL
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
            Web                    Mobile
             │                       │
             └───── HTTP Range ──────┘
                         │
                         ▼
                       Garage
```

## Later

```text
                    Rexone Core
                         │
                         │ authorize
                         ▼
                       Asset
                         │
                         ▼
                  Media Delivery
                    /        \
                   /          \
          progressive          HLS
               │               │
              MP4       HLS + CMAF/fMP4
                               │
                         CDN / gateway
                               │
                             Garage
```

---

# 54. Implementation philosophy

The purpose of this roadmap is not to build the most advanced media stack possible.

It is to build the **smallest correct streaming foundation that does not become a dead end**.

For the current branch:

> **Authorize in Core. Generate an opaque short-lived playback URL. Let the storage/media infrastructure serve the bytes. Keep the client contract provider-neutral.**

When adaptive streaming becomes justified:

> **Keep the same Asset and authorization model; add HLS as another delivery strategy, package it with CMAF/fMP4, and move high-volume segment delivery through CDN/media infrastructure rather than Rails.**

That keeps Rexone consistent with its broader architecture:

**clarity before cleverness, simplicity without weakness, and expansion through explicit boundaries rather than premature machinery.**

---

# References

- MDN — HTTP Range requests and media-friendly partial retrieval:
  https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Range_requests
- MDN — `206 Partial Content`:
  https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/206
- AWS SDK for Ruby — S3 object presigned URLs:
  https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html
- AWS S3 — `GetObject` / Range support:
  https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html
- FFmpeg — MOV/MP4 `+faststart` and CMAF muxing flags:
  https://ffmpeg.org/ffmpeg-formats.html
- Apple — HTTP Live Streaming:
  https://developer.apple.com/documentation/http-live-streaming
- Apple — Basic HLS with fragmented MP4 media:
  https://developer.apple.com/documentation/http-live-streaming/deploying-a-basic-http-live-streaming-hls-stream
