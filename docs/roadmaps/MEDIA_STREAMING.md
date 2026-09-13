# Future HLS / Adaptive Media Streaming Roadmap

> **Status:** Future roadmap
> **Current shipped baseline:** progressive audio/video playback through Core-authorized provider URLs
> **Future target:** HLS + CMAF / fragmented MP4 only when adaptive streaming is justified

Rexone’s first stored-media playback version is intentionally not HLS. The current product path should stay simple: Core authorizes playback, storage serves bytes, and Web/Mobile consume a short-lived progressive URL.

This roadmap now tracks the next streaming step only: adaptive delivery.

## When HLS becomes worth it

Introduce HLS/CMAF only when Rexone has a real need for one or more of these:

- long-form video where startup time and seeking matter at scale,
- adaptive bitrate for unstable mobile networks,
- CDN-friendly segment caching,
- multiple quality levels,
- structured subtitle/audio track switching,
- high concurrent playback traffic where progressive MP4 is no longer enough.

Do not migrate merely because HLS is more sophisticated.

## Future architecture

```text
Asset
  ↓
Media processing queue
  ↓
HLS package
  ├─ master playlist
  ├─ variant playlists
  ├─ CMAF/fMP4 media segments
  └─ subtitles / alternate tracks
  ↓
Garage / S3-compatible storage
  ↓
CDN or provider delivery
```

Core should keep the same high-level rule:

```text
Core authorizes. Media infrastructure serves bytes.
```

The existing `GET /v1/assets/:id/playback` contract can later return another delivery strategy, for example `delivery.type = "hls"`, without forcing clients to understand Garage object keys or provider internals.

## Future design notes

- Prefer HLS with CMAF/fMP4 segments over old TS-first packaging.
- Keep HLS presentations as generated delivery artifacts, not normal first-class `Asset` rows for every segment.
- Store only the metadata needed to authorize and locate the presentation.
- Keep Rails out of the segment hot path.
- Keep provider-specific signing logic behind `StorageService`.
- Add CDN support when traffic justifies it.

## Non-goals until this roadmap is started

- no HLS playlist tables,
- no segment database rows,
- no DASH implementation,
- no custom chunk API,
- no WebSocket media transport,
- no Rails byte proxy for normal stored media playback,
- no multi-quality ladder before real product requirements exist.

## First acceptance criteria for the future HLS project

- An authorized client can request the same playback endpoint and receive an HLS delivery object.
- Unauthorized or discarded assets cannot mint HLS delivery URLs.
- HLS playback works on Web, Android, and iOS.
- Segment URLs remain opaque and short-lived or safely CDN-scoped.
- Progressive playback remains available for ordinary audio/video assets.
