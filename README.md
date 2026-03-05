# Copyra

Copyra is a lightweight, keyboard-first clipboard manager for macOS.

Copyra is an independent, fully open-source fork of [Maccy](https://github.com/p0deje/Maccy). It keeps Maccy's speed and simplicity, while adding targeted performance optimizations, UI refinements, and new functionality.

## Fork Attribution

Copyra is built on top of Maccy and would not exist without the original project and its author.

- Base project: [Maccy](https://github.com/p0deje/Maccy)
- Original author: [@p0deje](https://github.com/p0deje)
- Copyra continues from Maccy's codebase with transparent attribution and open-source continuity.

## What Copyra Adds

Current improvements in this fork include:

- Large-history performance improvements with paged/virtualized loading behavior.
- Search responsiveness improvements for large histories, including async large-history search flow.
- Safer App Intent index resolution and temporary image file handling.
- Clipboard ignore-regex performance hardening (compiled regex cache, bounded scan length, invalid-pattern handling).
- Image pipeline optimization to reduce expensive eager decoding work.
- Ongoing UI and interaction refinements on top of Maccy's native macOS foundation.

## Copyra vs Maccy

The table below compares concrete functional differences and fixes introduced in this fork (relative to the upstream baseline this project started from).

| Area | Maccy (upstream baseline) | Copyra (this fork) |
| --- | --- | --- |
| Large-history handling | Standard full-list behavior | Paged/virtualized loading in large-history mode to reduce UI and memory pressure |
| Large-history search | Single-path search flow | Async large-history search pipeline with batched candidate processing |
| Ignore-regex handling | Basic regex filtering path | Compiled-regex cache, bounded scan length, and invalid-pattern safeguards |
| App Intents safety | Baseline intent selection behavior | Safer index validation and stricter temp-file lifecycle handling |
| Image handling | Baseline image decode/display path | Reduced eager decoding and improved thumbnail/cache behavior |
| Reliability fixes | Upstream test/runtime behavior | Additional fixes for clipboard-event handling, throttling behavior, and regression coverage |

Functional additions in Copyra focus on large-history responsiveness and UI/interaction refinements.
Fixes in Copyra focus on performance hardening, safer intent/file handling, and reliability regressions observed during fork maintenance.

## Project Goals

Copyra is maintained as its own clipboard manager project with these goals:

- Maintain Copyra independently under its own repository and release cadence.
- Keep full credit and legal attribution to Maccy.
- Preserve open-source licensing and transparency.
- Expand functionality beyond the original implementation.
- Continue improving performance, reliability, and UX over time.

## Install

Copyra currently targets macOS Sonoma 14 or newer.

### Build from source

```sh
git clone <your-copyra-repo-url>
cd Copyra
open Copyra.xcodeproj
```

Then build/run with Xcode.

## Usage

1. Press `Shift + Command + C` to open Copyra.
2. Type to search clipboard history.
3. Press `Enter` to copy the selected item.
4. Press `Option + Enter` to copy and paste immediately.
5. Press `Option + Shift + Enter` to paste without formatting.
6. Press `Option + Delete` to delete the selected item.
7. Press `Option + P` to pin/unpin an item.
8. Use Preferences to customize behavior.

## Advanced Notes

### Ignore copied items

You can temporarily ignore clipboard events (useful for sensitive workflows) from the menu bar action or via defaults for your bundle identifier.

### Ignore custom copy types

Copyra supports excluding custom pasteboard types and app sources, inherited from Maccy's model with ongoing refinement.

### Large-history performance mode

When history grows beyond the threshold, Copyra prioritizes responsiveness with large-history optimizations and reduced memory pressure behavior.

## Credits and License

Copyra is distributed under the MIT license, consistent with Maccy.

- Copyra remains MIT-licensed.
- Maccy is MIT-licensed.
- License terms and notices are preserved in this repository's [LICENSE](./LICENSE).

If you redistribute or modify Copyra, retain the required copyright and license notices.

## Transparency Statement

Copyra is intentionally presented as an evolved fork, not a from-scratch rewrite. The project direction is to respect Maccy's foundation while delivering sustained improvements in performance, usability, and feature scope.
