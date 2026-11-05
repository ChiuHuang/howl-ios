# Howl for iOS

Howl is my own build of the [Moonlight iOS client](https://github.com/moonlight-stream/moonlight-ios),
rebranded and themed for my [Howl](https://howl.chiuhuang.dev) cloud-gaming setup
(Wolf host, 2K75, HEVC). It streams from Sunshine / Wolf / GameStream hosts using
the same protocol as Moonlight.

## What is different from upstream

- **Branding** — app name and icon are Howl, and the app launches on a dark screen
  with the amber Howl wordmark.
- **Menu chrome** — the host menu uses Howl's dark/amber look: tinted navigation
  bar, dark canvas, and a `HOWL` wordmark under the host carousel.
- **Traditional Chinese menu** — the host menu and pairing/add-host dialogs are in
  zh-Hant: 搜尋主機中…, 選擇主機, 選擇其他主機, 手動新增主機, 配對中, 配對失敗.
- **Own bundle id** — `dev.chiuhuang.howl`, version `1.0.0`.
- **CI** — `.github/workflows/build-ipa.yml` builds on every push with a macOS
  runner and publishes an **unsigned** `Howl-unsigned.ipa` artifact. Tags
  (`v*`) attach the IPA to a GitHub release.

Everything else — streaming, input, audio, video, pairing, host discovery — is
upstream Moonlight, unmodified.

## Get the app

1. Open the latest [Actions run](https://github.com/ChiuHuang/howl-ios/actions)
   (or the Releases page for a tag) and download `Howl-unsigned-ipa`.
2. Unzip `Howl-unsigned.ipa`.
3. Sideload it, for example:
   - [AltStore](https://altstore.io) / [SideStore](https://sidestore.io) —
     re-signs with your Apple ID, works on stock iOS.
   - [Sideloadly](https://sideloadly.io) — Windows/macOS, same idea.
   - TrollStore — installs the unsigned IPA as-is on supported iOS versions.

The IPA is not signed, so a signing step (your Apple ID or a certificate) is
always required before iOS will run it.

## Build locally

```bash
git clone --recursive https://github.com/ChiuHuang/howl-ios.git
cd howl-ios
open Moonlight.xcodeproj
```

Pick the **Moonlight** scheme (the iOS target keeps its upstream name), set your
team under Signing & Capabilities, then run on a device. The bundle id is
`dev.chiuhuang.howl`; change it if it collides with anything in your account.

Unsigned build, like CI does it:

```bash
xcodebuild -project Moonlight.xcodeproj -scheme Moonlight \
  -configuration Release -sdk iphoneos \
  -archivePath build/Howl.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" archive
```

## License

Upstream Moonlight iOS is GPLv3; this fork stays GPLv3. See `LICENSE.txt`.
The Moonlight name and logo belong to the Moonlight project — this is an
unofficial personal fork, not affiliated with or endorsed by Moonlight.
