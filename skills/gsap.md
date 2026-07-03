---
name: gsap
description: Official GSAP skill router for frontend animation. Use when the user asks for GSAP, JavaScript animation, timelines, ScrollTrigger, React/Vue/Svelte/Nuxt animation, SplitText, Flip, Draggable, SVG motion, or Webflow interactions.
source: official-wrapper
upstream: https://github.com/greensock/gsap-skills
date_added: "2026-07-03"
---

# GSAP Skill Router

This Lotus top-level entry routes GSAP work to the official GreenSock skills installed beside it.

## When to Use

Use this skill when the user asks for:

- GSAP or JavaScript animation
- frontend motion in React, Next.js, Vue, Nuxt, Svelte, SvelteKit, Astro, or vanilla JavaScript
- timelines, staged entrances, hover/click motion, scroll-linked animation, pinned sections, or scrubbed effects
- GSAP plugins such as ScrollTrigger, SplitText, Flip, Draggable, MorphSVG, DrawSVG, ScrollSmoother, Observer, or ScrollToPlugin
- animation performance cleanup or review
- Webflow interactions or Webflow animation behavior

## Route to Specific Official Skills

Before writing code, read only the specific official skill files needed for the request:

| User intent | Read these skills |
|---|---|
| basic tween, easing, stagger, choose animation library | `gsap-core` |
| sequenced animation, labels, playback control | `gsap-timeline` |
| scroll-driven animation, pinning, scrub, refresh, cleanup | `gsap-scrolltrigger` |
| React or Next.js animation | `gsap-react`, plus `gsap-core` as needed |
| Vue, Nuxt, Svelte, SvelteKit, or other framework animation | `gsap-frameworks`, plus `gsap-core` as needed |
| SplitText, Flip, Draggable, SVG, ScrollSmoother, Observer, ScrollToPlugin, physics, easing plugins | `gsap-plugins` |
| clamp/mapRange/random/snap/toArray/wrap helpers | `gsap-utils` |
| performance, reduced motion, layout thrash, cleanup review | `gsap-performance` |

Use multiple official skills together when the task crosses categories, such as React + ScrollTrigger + SplitText.

## Important Boundaries

- GSAP skills are not a UI component library. Do not claim they provide ready-made buttons, cards, hero sections, or layout components.
- Preserve the project's existing framework, styling system, and design language. GSAP should animate the current UI unless the user explicitly asks for a redesign.
- Prefer transforms, opacity, and GSAP-supported properties over layout-heavy animation.
- Respect `prefers-reduced-motion` for substantial motion.
- In component frameworks, create animations after DOM mount and clean them up on unmount.
- Register GSAP plugins once before use.

## Dependency Guidance

If the project does not already have GSAP:

```bash
npm install gsap
```

For React projects that need the official hook:

```bash
npm install @gsap/react
```

## Invocation Examples

- `/gsap add a ScrollTrigger entrance animation to this section`
- `/gsap-react animate this React hero with useGSAP and cleanup`
- `/gsap-scrolltrigger make this panel pin and scrub on scroll`
- `/gsap-plugins use SplitText for this heading`
