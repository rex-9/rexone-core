# Media Playback

RexOne’s implemented stored-media playback path is progressive audio/video delivery through Core-authorized provider URLs.

## Current contract

```text
Client
  ↓ authenticated request
GET /v1/assets/:id/playback
  ↓
RexOne Core authorizes the Asset
  ↓
StorageService creates a short-lived playback URL
  ↓
Web / Mobile media element plays from storage
```

Core stays responsible for identity, authorization, asset readiness, and provider selection. Storage stays responsible for byte delivery, range requests, seeking, and bandwidth-heavy transfer.

## Endpoints

- `POST /v1/assets/upload` uploads client media.
- `GET /v1/assets/:id/playback` returns a temporary playback contract for playable audio/video assets.

The playback response uses a provider-neutral delivery object:

```json
{
  "delivery": {
    "type": "progressive",
    "url": "https://storage.example.com/...",
    "expires_at": "2026-09-13T14:00:00Z"
  }
}
```

Clients should use the URL directly in `<video>`, `<audio>`, or native media players. Do not download playback files through Axios/fetch first.

## Media pipeline compatibility

Playable files should be optimized by the media queue before normal playback:

- video: MP4 container, H.264 video, AAC audio, `-movflags +faststart`,
- audio: MP3 or M4A/AAC,
- storage metadata and playback MIME type must match the stored bytes.

`+faststart` makes MP4 progressive playback friendlier by moving the MP4 index toward the beginning of the file, so browsers can start and seek earlier.

## Boundaries

- No Rails/Puma byte proxy for ordinary playback.
- No public permanent asset URLs.
- No storage credentials exposed to clients.
- No HLS in the current version.
- Future HLS/adaptive streaming belongs in [the roadmap](roadmaps/MEDIA_STREAMING.md).
