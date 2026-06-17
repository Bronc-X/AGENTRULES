# Lotus ? Toni 视觉系统

版本：2026-06-18 v3  
视觉母版：`01A-kernel-lotus-executive.png`

## 1. 定位

这套视觉不是单独的 Lotus 标志，也不是单独的 Toni 个人站装饰，而是 **Lotus ? Toni** 共同组成的识别系统。

- **Toni**：个人品牌、作品集、toni.asia 的主身份。
- **Lotus**：Toni 的 Agent Operating Layer，承载规则、技能、运行时和交付体系。
- **组合关系**：Toni 是发起者和背书者，Lotus 是方法、系统与交付能力的视觉化表达。

所有对外文案使用中性表达，不出现具体开发工具品牌名。推荐表达：

- Agent 工作协议
- Agent Operating Layer
- AI 工作流系统
- Toni 的 Agent Operating Layer
- Rules / Skills / Runtime

## 2. Logo 与资产原则

### Exact assets

以下资产来自选定母版的精确栅格裁切，是当前唯一标准版本：

- `assets/master-01A-kernel-lotus-executive.png`
- `assets/exact-logo-lockup-dark.png`
- `assets/exact-logo-lockup-dark-transparent.png`
- `assets/exact-logo-symbol-dark.png`
- `assets/exact-logo-symbol-dark-transparent.png`
- `assets/exact-app-icon.png`
- `assets/favicon-16.png` / `32` / `64` / `128` / `256` / `512`

用于官网、README、Open Graph、图标、应用入口时，优先使用 exact raster 文件。

### Editable vector

- `assets/editable-approx-lotus-symbol.svg`

这个 SVG 只是近似矢量稿，用于尺寸草图、版式占位和 CSS 实验。它不能替代 exact raster logo，也不能作为最终标志源文件。

### Exact raster SVG wrapper

- `assets/exact-logo-lockup-dark-transparent.exact-raster.svg`
- `assets/exact-logo-symbol-dark-transparent.exact-raster.svg`
- `assets/exact-app-icon.exact-raster.svg`

这些 SVG 只是把 exact PNG 包进 SVG 容器，方便某些只接受 SVG 的场景使用；图形本体仍然是栅格图。

## 3. 使用规则

01A 母版里的 Lotus 标志保持不变，不重新生成、不手工重画。

- **网站 / GitHub / README**：使用 exact logo 或从 exact logo 派生的透明 PNG。
- **PDF / 提案 / 交付文档**：使用 Lotus ? Toni 组合标识，不只放 Lotus，不使用黑色底块。
- **小图标**：使用 `exact-app-icon.png` 与 `favicon-*.png`。
- **矢量场景**：只能使用 `editable-approx-lotus-symbol.svg` 做近似辅助，并明确标注 approximate。

## 4. 色彩

| Token | Hex | 用途 |
|---|---:|---|
| Ink 900 | `#0D0F12` | 标题、深色界面、app icon 底色 |
| Ink 800 | `#1A1C21` | 深色卡片与 UI 面 |
| Ink 700 | `#2B2E36` | 正文、次级文字 |
| Paper 100 | `#F6F6F4` | PDF、官网浅色背景 |
| Paper 200 | `#E6E7EB` | 细线、分隔、边框 |
| Petal Pink | `#DFA7B0` | Lotus 花瓣、强调线 |
| Sync Green | `#7BCA71` | 状态、通过、CTA 辅助 |
| Muted Gray | `#929091` | 注释、辅助标签 |

建议比例：Ink 60%、Paper 25%、Petal Pink 8%、Sync Green 4%、Muted Gray 3%。整体保持冷静、克制，不做大面积粉色或绿色。

## 5. 字体选择

不是只能用当前字体。下面是四条可选路线：

### A. 高级工程感

- 英文标题：Instrument Serif / Georgia / Cormorant Garamond
- 英文 UI：Inter / Arial / SF Pro
- 代码与标签：JetBrains Mono / Consolas / SF Mono
- 中文：Noto Sans SC / Microsoft YaHei

适合 toni.asia、Lotus 项目页、PDF 封面与 README。当前交付包默认采用这条路线。

### B. 现代产品感

- 英文标题：Inter Display / Geist / Helvetica Neue
- 英文正文：Inter / Geist Sans
- 代码与标签：JetBrains Mono
- 中文：Noto Sans SC

适合 SaaS 风格页面、控制台、工作台界面。比 A 更理性、更轻、更产品化。

### C. 文档与知识库感

- 英文标题：IBM Plex Serif / Source Serif
- 英文正文：IBM Plex Sans / Source Sans
- 代码与标签：IBM Plex Mono
- 中文：Source Han Sans / Source Han Serif

适合白皮书、交付报告、技术说明、知识库。整体更像严肃出版物。

### D. 个人品牌感

- 英文标题：Canela / Editorial New / Georgia fallback
- 英文正文：Suisse / Inter fallback
- 中文：思源宋体 / Noto Serif SC 与 Noto Sans SC 搭配

适合 Toni 个人主页、作品集封面、叙事型页面。更有编辑感和个人气质。

建议组合：官网用 A 或 B；PDF 用 A 或 C；个人品牌页用 A 或 D。

## 6. Lotus ? Toni 组合锁定

推荐层级：

1. 主标题：`Lotus ? Toni`
2. 中文说明：`Toni 的 Agent 工作系统`
3. 英文说明：`Agent Operating Layer`
4. 功能标签：`Rules / Skills / Runtime`

这能避免 Lotus 看起来只是一个单独工具，而是 Toni 工作方法和交付体系的一部分。

## 7. toni.asia 可用位置

### 全站基础

1. `app/layout.tsx` metadata：为 Lotus 相关页面配置 Lotus ? Toni Open Graph 图。
2. `app/icon.svg` / `app/favicon.ico`：主站仍以 Toni 为主，Lotus 页面可使用 Lotus favicon。
3. `public/brand/toni-lotus/`：存放全部公开可引用资产。
4. README / GitHub Profile / 项目介绍：使用 `lotus-lockup-exact.png` 与 Lotus ? Toni 组合说明。

### 首页 / Now 页

1. `app/page.tsx`：在项目或工具区使用 “Lotus ? Toni” 作为 Agent 工作系统入口。
2. `app/now/page.tsx`：Lotus 项目卡使用 `toni-lotus-visual-system-board-v2-dark-logo.png` 或浅色封面。
3. `public/now/lotus-github.png`：替换为 branded project card。
4. `public/now-share-long.png`：加入 Lotus ? Toni 的项目识别。

### Contact 页

1. `app/contact/page.tsx`：Lotus GitHub 链接旁可使用 exact Lotus symbol。
2. 联系卡说明使用 `Lotus ? Toni / Agent Operating Layer`。

### Work / Portfolio 页

1. `app/work/page.tsx` 和 `app/work/[slug]/page.tsx`：增加 Lotus case。
2. `app/portfolio/page.tsx`：把 Lotus 归入 workflow / Agent 系统类作品。
3. `public/cases/`：加入 Lotus case image。

### Lusie / ShipModel 等相关项目

1. 在交付文档、STL 工具链说明、自动化项目卡中使用 Lotus sync badge。
2. 在跨项目说明里使用 `Lotus ? Toni`，表示 Toni 的工作流基础设施。

### Slides / Training

1. Agentic workflow、自动化交付、AI 协作相关讲义可使用这套 logo。
2. PDF、PPT、项目交付封面使用 `pdf-cover-toni-lotus-v2-light.png`。

## 8. PDF 使用规则

PDF 使用浅色组合标识：

- 文件：`assets/toni-lotus-pdf-lockup-light.png`
- 必须同时出现 Toni 与 Lotus。
- 不使用黑色底块。
- 不只放 Lotus 单独标志。
- 保持浅色纸面、粉色细线、清晰留白。

当前已生成的浅底品牌 PDF：

- `pdf/Xero_ZohoBigin_Jira_绩效评分卡自动化项目交付确认书_Toni_Lotus_light_branded.pdf`

## 9. 后续实施清单

toni.asia：

1. 将 `public/brand/toni-lotus` 纳入公开资源。
2. Contact 页增加 Lotus exact symbol。
3. Now 页增加 Lotus 项目图。
4. Work / Portfolio 增加 Lotus case。
5. 为 Lotus 相关页面配置 Open Graph 图片。

Lotus：

1. README 顶部使用 exact Lotus 或 Lotus ? Toni header。
2. PDF 和交付文档统一使用 Lotus ? Toni 浅底 header。
3. app icon、favicon、badge 统一使用 exact raster 资产。
