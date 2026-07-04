---
name: ios-ui-centering-fix
description: 修复 SwiftUI 中 header、loading、tab 等中心轴偏移问题。
---

# iOS UI Centering Fix

## Overview
Fix center drift by first removing global axis bias, then applying symmetric header layout and calibrated optical offset.

## Workflow
1. Check global axis first (must)
- Search for hardcoded horizontal shifts in container layers:
  - `ContentView.swift` custom tab bar: `.offset(x: ...)`
  - startup/auth/root wrappers: `.padding(.leading, ...)`
- Remove global horizontal hacks before any per-page tweak.

2. Build structural centering for top bars
- Use symmetric side slots in header HStack, then center title in ZStack:
  - left slot width == right slot width (usually `44`)
  - do not rely on one-sided padding
- Apply only optical compensation to title:
  - `metrics.centerAxisOffset` from `LiquidGlassTheme.swift`
- Targets:
  - `Features/ScienceFeed/ScienceFeedView.swift`
  - `Features/DigitalTwin/DigitalTwinView.swift`
  - `Features/Max/MaxChatView.swift`

3. Center loading states as blocks
- Wrap spinner + text + progress in a centered container:
  - `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)`
- Apply the same `centerAxisOffset` to the whole loading block, not separate child views.

4. Tune optical offset centrally
- Keep one source of truth:
  - `Shared/Theme/LiquidGlassTheme.swift` -> `ScreenMetrics.centerAxisOffset`
- Recommended baseline:
  - compact width: `-4`
  - regular width: `-8`

5. Verify and iterate
- Run `/Users/broncin/.codex/skills/iostest/iostest.sh`
- Manually verify on simulator screenshots:
  - top title center aligns with screen midpoint
  - spinner center aligns with title center
  - bottom tab center matches content center

## Notes
- If UI still appears shifted, re-check global layers first. Do not keep stacking local `.offset(x: -4)` patches.
- Keep edge controls fixed to edges; only center content receives optical offset.
