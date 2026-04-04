# StateLensHeart Project Structure

This repository uses an iPhone-hosted Apple Watch companion configuration.

Targets:
- `StateLensHeart`
- `StateLensHeart Watch App`

Current companion wiring:
- The iPhone app embeds the watch app via `Embed Watch Content`.
- The watch target points back to the iPhone app with `WKCompanionAppBundleIdentifier`.

Planned code layout:
- `StateLensHeart/`
  iPhone app entry point and iPhone-facing UI
- `StateLensHeart Watch App/`
  Watch app entry point and watch-facing UI
- Shared domain and connectivity code will be added next.
