---
name: taste-skill
description: |
  高质量官网、作品集、marketing page 和现有网站重设计。用户点名 taste-skill、
  anti-slop、Awwwards、premium、editorial、brutalist 或要求页面更高级、
  不模板化时使用。对 Codex/GPT 强制执行设计读取、视觉资产、真实实现、
  浏览器验收和完整交付，不只给设计建议或静态草图。
---

# Taste Skill: Codex Visual Frontend Entry Point

This is Lotus's Codex entry point for visual frontend work. It is an execution
workflow, not a mood-board prompt. Project rules, user requirements, and the
existing stack remain higher priority.

## Activation Contract

When this skill is selected for a frontend task, follow this sequence:

1. Classify the task as greenfield, preserve-brand redesign, overhaul, portfolio,
   editorial, or marketing page. Say one line:
   `Reading this as: <page kind> for <audience>, with a <vibe> language, leaning toward <system or aesthetic>.`
2. Set and state the three dials:
   `DESIGN_VARIANCE`, `MOTION_INTENSITY`, and `VISUAL_DENSITY`. Give one short
   reason for each value. Never silently use the baseline.
3. Inspect the existing project before changing it. Read `package.json`, the
   current routes/components/styles, and existing brand assets. For a redesign,
   audit the live or local page before proposing changes.
4. If the user provides a URL, screenshot, product name, or visual reference,
   inspect it and extract concrete traits: composition, type scale, palette,
   image treatment, section rhythm, motion, and interaction states. Do not
   claim the reference was used if it was not inspected.
5. For an implementation task, read `references/full-rules.md`. If the page
   needs generated or image-first visual assets, also read
   `references/image-first-workflow.md`.
6. Implement the real page in the project's existing stack. Do not stop at a
   design plan, a prompt, a single hero mockup, or a placeholder-heavy shell
   unless the user explicitly asked for one of those.
7. Run the visual verification gate below. A page is not complete until the
   rendered result has been inspected at desktop and mobile sizes, or the
   inability to render has been reported explicitly.

If the brief is genuinely ambiguous between two distinct visual directions,
ask one focused question. Otherwise infer and proceed.

## Visual Asset Gate

For a new or redesigned website:

- Prefer existing real brand/product assets when they are available.
- If an image-generation tool is available and the page benefits from original
  imagery, use it before or during implementation for section-specific assets.
  Generate the right aspect ratio for the section, not one generic image reused
  everywhere.
- If image generation is unavailable, use real local assets or a clearly
  labeled external source. Do not replace meaningful visuals with fake
  screenshots made from nested divs.
- Keep visual references, generated images, and implemented UI in one coherent
  brand world: palette, type scale, radius language, contrast, and image grade.
- For multi-section image reference work, keep one horizontal frame per section
  and deliver the complete set. Do not collapse a full page into one image.

## Implementation Contract

- Preserve the existing framework, routes, copy voice, analytics hooks, and
  accessibility behavior unless the user approves a change.
- Before importing a third-party package, check `package.json`. If it is
  missing, state the install command before using it.
- Use real layout variety and a clear visual concept. Do not default to a
  centered hero, three equal feature cards, AI-purple gradients, generic
  glassmorphism, or repeated left-text/right-image rows.
- Make mobile behavior explicit for every multi-column or asymmetric section.
- Implement meaningful loading, empty, error, hover, focus, active, reduced
  motion, and responsive states where the surface supports them.
- Keep copy short and believable. Re-read every visible string before shipping.
- Use the project's existing icon family. Never hand-roll decorative SVG paths.
- Treat high-end visual quality as a combination of art direction, typography,
  layout rhythm, real imagery, interaction, and QA. Rules alone do not create
  the reference site's finished art direction.

## Visual Verification Gate

After implementation:

1. Start the local dev server when the project requires one. If the expected
   port is occupied, use another port.
2. Use the available Browser or Playwright capability to inspect at least one
   desktop viewport and one narrow mobile viewport.
3. Check for blank or missing images, overflow, clipped text, overlapping
   controls, broken mobile collapse, unreadable contrast, dead interactions,
   console errors, and motion that ignores reduced-motion preferences.
4. Fix every issue found and recheck the affected viewport.
5. Report the design read, dial values, assets used, visual QA viewports, and
   any remaining limitation. Do not call a page polished without fresh
   rendered evidence.

## Reference Routing

- Core rules, anti-slop bans, layout patterns, accessibility, and pre-flight:
  `references/full-rules.md`
- Image-first art direction and per-section reference-frame workflow:
  `references/image-first-workflow.md`

Read only the reference needed for the current task, but do not skip the
reference when implementing a real frontend surface.

## Scope Boundary

This skill is for landing pages, marketing sites, portfolios, editorial pages,
and redesigns. It is not the primary skill for dashboards, dense admin panels,
data tables, multi-step wizards, code editors, native mobile screens, or
realtime collaboration surfaces. For those, use the appropriate product
design system and apply only the relevant visual guidance.
