---
name: gsap
description: 做 GSAP 动画时处理补间、时间线、滚动、插件、框架集成和性能。
source: official-wrapper
upstream: https://github.com/greensock/gsap-skills
date_added: "2026-07-03"
---

# GSAP

单一 GSAP 顶层入口。原 `gsap-core`、`gsap-timeline`、`gsap-scrolltrigger`、`gsap-react`、`gsap-frameworks`、`gsap-plugins`、`gsap-utils`、`gsap-performance` 已合并到这里，避免 UI 顶层重复。

## 何时使用

用户提到以下任务时使用：

- GSAP 或 JavaScript 动画选型、实现、排障。
- React、Next.js、Vue、Nuxt、Svelte、Astro 或原生 JS 动画。
- 补间、时间线、入场、悬停、点击、滚动联动、pin、scrub。
- ScrollTrigger、SplitText、Flip、Draggable、SVG、ScrollSmoother、Observer、ScrollToPlugin 等插件。
- 动画卡顿、布局抖动、清理泄漏、`prefers-reduced-motion` 适配。
- Webflow Interactions 的 GSAP 行为解释或定制。

## 内部分流

不再读取独立子 skill。按任务类型只调用当前所需规则：

| 意图 | 使用规则 |
|---|---|
| 基础动画 | `gsap.to/from/fromTo/set`、ease、duration、stagger、overwrite。 |
| 时间线 | `gsap.timeline()`、label、position 参数、播放控制、嵌套。 |
| 滚动动画 | ScrollTrigger、pin、scrub、start/end、refresh、组件卸载清理。 |
| React/Next.js | `@gsap/react`、`useGSAP`、ref、`gsap.context()`、cleanup。 |
| Vue/Svelte/Nuxt | 挂载后创建动画，销毁时 kill/revert，避免服务端访问 DOM。 |
| 插件 | 注册插件一次；按需使用 SplitText、Flip、Draggable、SVG、ScrollToPlugin。 |
| 工具函数 | `gsap.utils.clamp/mapRange/normalize/interpolate/random/snap/toArray/wrap/pipe`。 |
| 性能 | 优先 transform/opacity，减少 layout thrash，适配 reduced motion。 |

跨类任务组合使用规则，例如 React + ScrollTrigger + SplitText。

## 核心约束

- GSAP 不是组件库；不要把它说成能提供按钮、卡片或布局系统。
- 保留项目现有框架、样式系统和设计语言；除非用户要求重设计，否则只动画化现有 UI。
- DOM/SVG 属性用 camelCase；位移、缩放、旋转优先用 `x/y/scale/rotation` 等 GSAP transform 别名。
- 大动画必须照顾 `prefers-reduced-motion`。
- 组件框架中只在挂载后创建动画，卸载时 `revert()` 或 `kill()`。
- 插件先 `gsap.registerPlugin(...)`，且只注册一次。

## 依赖

项目没有 GSAP 时：

```bash
npm install gsap
```

React 项目需要官方 hook 时：

```bash
npm install @gsap/react
```

## 调用例子

- `/gsap add a ScrollTrigger entrance animation to this section`
- `/gsap 用 useGSAP 给 React hero 加入场动画并清理副作用`
- `/gsap 让这个 panel 滚动 pin 住并 scrub`
- `/gsap 用 SplitText 做标题逐字动效`
