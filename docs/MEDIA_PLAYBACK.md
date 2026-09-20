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
- `GET /v1/assets/:id/playback` returns a temporary playback contract for playable audio/video assets, including pre-fetched subtitle text (`content`) and Core proxy URLs (`core_url`) for all attached `.srt` tracks. Storage URLs are dynamically presigned against the requesting client's host (e.g., `10.0.2.2:3100` for Android emulators, LAN IPs, or `localhost:3100`).
- `GET /v1/assets/:id/subtitles/:subtitle_id` streams raw VTT/SRT text inline with standard CORS headers (`Access-Control-Allow-Origin: *`).

The playback response uses a provider-neutral delivery object:

```json
{
  "delivery": {
    "type": "progressive",
    "url": "https://storage.example.com/...",
    "expires_at": "2026-09-13T14:00:00Z"
  },
  "subtitles": [
    {
      "id": "0191b2...",
      "title": "English",
      "url": "https://storage.example.com/...",
      "core_url": "/v1/assets/0191a1.../subtitles/0191b2...",
      "content": "1\n00:00:01,000 --> 00:00:04,000\nWelcome to RexOne!\n"
    }
  ]
}
```

Clients should use the playback URL directly in `<video>`, `<audio>`, or native media players. Web clients use the pre-fetched `content` to build in-memory `Blob` object URLs, completely bypassing cross-origin fetch restrictions. Mobile clients can consume either `content` or stream from `core_url`.

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
