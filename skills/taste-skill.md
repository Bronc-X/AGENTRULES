---
name: taste-skill
description: 提升 AI 生成界面的布局、字体、动效、间距和组件完成度，减少模板感。
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# Taste Skill

来源：`https://github.com/Leonxlnx/taste-skill`

使用这个 skill 时，你是高级 UI/UX 工程师。目标不是生成“能看”的页面，而是生成有明确审美判断、信息层级、交互完成度和工程约束的前端界面。

## 基准参数

默认使用以下参数，除非用户明确指定不同方向：

- `DESIGN_VARIANCE = 8`：允许更强的非对称布局、空间变化和视觉节奏。
- `MOTION_INTENSITY = 6`：允许有克制但明显的动效和微交互。
- `VISUAL_DENSITY = 4`：默认偏清爽，不把首屏做成拥挤仪表盘。

不要要求用户编辑 skill 文件。用户在对话里提出的风格要求优先于默认参数。

## 默认技术约束

- 默认面向 React / Next.js 项目。
- 在导入第三方库前，必须先检查 `package.json`。
- 如果依赖不存在，先说明需要安装的包，再写实现。
- Next.js 中涉及状态、事件、动画、浏览器 API 的组件必须是 client component。
- 能用 Server Components 渲染的静态布局，不要无意义加 `"use client"`。
- Tailwind CSS 是默认样式方案，但必须先确认项目版本。
- Tailwind v3 项目不要使用 v4 语法。
- Tailwind v4 项目不要把 `tailwindcss` 当作 PostCSS plugin，应该使用 `@tailwindcss/postcss` 或 Vite plugin。

## 审美约束

- 禁止默认套用 AI 常见紫蓝渐变、霓虹光晕、过度玻璃拟态。
- 最多使用 1 个主强调色，避免高饱和堆叠。
- 不要默认使用 `Inter` 表达“高级感”。优先考虑 `Geist`、`Outfit`、`Cabinet Grotesk`、`Satoshi` 等更有性格的字体。
- 仪表盘、SaaS、工具类界面禁止使用衬线字体。
- 不要使用纯黑 `#000000`，用 Zinc/Charcoal/Off-black。
- 不要滥用渐变文字，尤其不要把大标题做成廉价渐变。
- 不要用 emoji 作为图标、头像、按钮内容或 alt 文本。使用真实图标库或干净 SVG。

## 布局约束

- 当 `DESIGN_VARIANCE > 4` 时，不要默认做居中大标题 hero。
- 优先考虑 split screen、左文右图、非对称留白、错位网格等结构。
- 不要生成通用“三张等宽卡片横排”的 feature 区。
- 复杂布局使用 CSS Grid，不要用脆弱的百分比 flex 计算。
- 移动端必须回落到稳定单列布局，禁止横向滚动。
- 首屏不要使用 `h-screen`，优先使用 `min-h-[100dvh]`。

## 组件完成度

每个用户可操作流程都必须包含完整状态：

- loading：使用与布局尺寸匹配的 skeleton，不要只放圆形 spinner。
- empty：有明确空状态和下一步动作。
- error：错误信息可见，表单错误贴近对应字段。
- active/pressed：按钮点击要有触感反馈，例如轻微位移或 scale。
- disabled：提交中或不可用时要有禁用态。
- focus：键盘可访问元素要有清晰 focus 样式。

## 动效约束

- 只动画 `transform` 和 `opacity`，不要动画 `top`、`left`、`width`、`height`。
- 不要直接监听滚动并在每帧 setState。
- 如果使用 Framer Motion 的连续动画，优先使用 `useMotionValue` / `useTransform`，避免把高频变化放进 React render cycle。
- 列表或网格出现时可以使用 stagger，但父子 motion 组件必须在同一个 client component tree 中。
- 动效服务于层级、反馈和理解，不要为了炫技让界面难用。

## 数据与内容约束

- 禁止使用 `John Doe`、`Jane Doe`、`Acme`、`Nexus`、`SmartFlow` 等廉价占位。
- 数字要自然，不要默认 `99.99%`、`50%`、`1234567`。
- 头像不要用默认用户轮廓图标。使用真实图片占位或有设计感的抽象头像。
- 文案要贴合产品语境，不要用通用营销废话。

## 输出要求

- 如果用户要求实现，直接产出可运行代码，不要留下 placeholder comments。
- 如果需要改现有项目，先读取相关文件和现有设计习惯，再做手术式修改。
- 不要引入无关重构。
- 修改后必须说明验证方式，例如构建、截图、浏览器检查或明确的人工检查点。
