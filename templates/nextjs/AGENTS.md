# Project-Specific Rules

> Universal workflow rules and quality gates are inherited from the global rules file.
> This file contains only project-specific constraints.
> See: https://github.com/Bronc-X/Lotus

## Tech Stack

- Next.js (App Router) + React
- Framer Motion (animation)
- Lucide React (icons)
- localStorage (lightweight persistence)

## Design Language

- Background: warm white (`#FAF9F6`) or pure white
- Primary border: `#E5E1D8`, hover: `#D97706`
- Text hierarchy: `#111` > `#444` > `#666` > `#888`
- Brand highlight / CTA: `#D97706` (amber orange)
- Secondary button: `bg-[#F3F1ED] text-[#444] border-[#E5E1D8]`
- Cards: `bg-[#F3F1ED]` or white, never pure black
- Animation: only `opacity`/`y`/`x` + spring via Framer Motion

## Backend Integration Mode

- Frontend should call your own backend or route handlers, not third-party AI vendors directly
- During scaffolding or early product development, use a backend-owned mock service before wiring a real provider
- Mock responses must keep the same schema and business shape you expect from the eventual real backend
- No direct browser-side calls to OpenAI, Gemini, Notion, or similar external services
