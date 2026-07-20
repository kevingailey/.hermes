# iOS/tvOS Video Playback Libraries — Comparison & Architecture

Research from kgx TV guide app (iOS + tvOS, SwiftPM/xtool). Sources: HDHomeRun (HTTP MPEG-TS), Jellyfin (HLS, often self-signed HTTPS), IPTV M3U (HLS .m3u8), Xtream API (HLS).

## Library Comparison

| Feature | AVPlayer (AVFoundation/AVKit) | VLCKit (MobileVLCKit) | KMPlayer | Swift AVPlayer wrappers (GSPlayer, Player) |
|---|---|---|---|---|
| HLS | Native, first-class | Full (VLC demuxer) | Not a real iOS library | Inherits AVPlayer |
| Non-HLS HTTP (MPEG-TS) | No — only HLS + progressive MP4/MOV | Yes — MPEG-TS, RTSP, RTMP, any format | N/A | No (AVPlayer limitation) |
| Picture-in-Picture | Yes via AVPictureInPictureController (iOS only) | No — VLC uses custom rendering, not AVPlayerLayer; PiP APIs don't work | N/A | Yes if built on AVPlayerLayer |
| tvOS | System framework, works | Available on tvOS | N/A | Most target iOS only |
| SwiftPM/xtool | System framework — just `import AVKit`. Perfect fit | Binary xcframework. Has SPM binary-target but awkward without Xcode | N/A | Pure-Swift SPM, ideal |
| License | Apple SDK — free | LGPL v2.1+ (dynamic linking) or commercial license from VideoLAN | Unknown | MIT (typical) |
| Self-signed HTTPS | No — system TLS validation rejects. Needs proxy workaround | Yes — VLC's own networking stack can ignore cert errors | N/A | No (AVPlayer limitation) |
| App Store risk | Zero | Low-moderate (LGPL compliance, codec patents) | N/A | Zero |

## Key Constraints

### PiP is iOS-only
`AVPictureInPictureController` has no tvOS equivalent. On tvOS, `AVPlayerViewController` supports background audio and system navigation overlay, but there is no developer-facing PiP API. This applies to ALL libraries — no library can provide PiP on tvOS.

### AVPlayer cannot play non-HLS live streams
Raw MPEG-TS over HTTP (HDHomeRun native URL like `http://192.168.1.100:5004/auto/v5.1`) fails. AVPlayer only supports HLS (.m3u8) and progressive HTTP download of MP4/MOV.

### AVPlayer rejects self-signed HTTPS
AVPlayer uses system TLS validation. Self-signed certs (common for Jellyfin on local network) are rejected. No built-in way to bypass.

## Recommended Architecture: AVPlayer + Local Proxy

### Self-signed HTTPS → In-app HTTP proxy
Run a lightweight in-app HTTP server (GCDWebServer or Swifter, both SPM-compatible) on localhost:
1. AVPlayer connects to `http://127.0.0.1:<port>/<path>` (plain HTTP, no TLS issue)
2. Proxy connects to upstream HTTPS endpoint using `URLSession` with custom `URLSessionDelegate` that accepts self-signed certs
3. Proxy streams response bytes through to AVPlayer

### Non-HLS HTTP streams (HDHomeRun) → Transcode to HLS
- HDHomeRun transcoding models: append `?transcode=heavy` to the native URL to get HLS output
- Non-transcoding models: use Jellyfin's built-in HLS transcoding, or an in-app segmenter
- HDHomeRun serves plain HTTP on local network (no cert issue) — only format is the problem

### Protocol abstraction for dual-player fallback
If in-app transcoding is too complex, use VLCKit as a secondary player for non-HLS sources:

```swift
protocol PlaybackService {
    func play(url: URL, streamType: StreamType) async throws
    var supportsPiP: Bool { get }
}

enum StreamType {
    case hls       // → AVPlayer (PiP available)
    case httpLive  // → proxy to HLS → AVPlayer, or fallback to VLCKit
    case direct    // → VLCKit (no PiP)
}
```

Tradeoff: PiP only available for HLS sources. Non-HLS sources lose PiP when routed to VLCKit. Budget for LGPL compliance or commercial VLCKit license.

## Why AVPlayer wins as primary
- Native PiP (critical requirement for iOS)
- Perfect SwiftPM/xtool compatibility (system framework, zero dependencies)
- No LGPL/GPL license concerns
- Full HLS support for IPTV/Jellyfin/Xtream
- Minimal app binary size vs VLCKit (~30-50MB larger)
- Zero App Store review risk

## VLCKit integration notes (if needed as fallback)
- Distribution: binary xcframework from code.videolan.org
- SPM: has binary-target support but can be fragile without Xcode
- License: LGPL v2.1+ — must allow library replacement (dynamic linking satisfies this), or purchase commercial license
- No AVPictureInPictureController support because VLC uses its own rendering pipeline (not AVPlayerLayer)
- Some custom PiP-like implementations exist via sampling buffer display layer bridging but are fragile
