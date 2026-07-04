# Lotus 顶层 Skill 精品版清单

- 原始顶层 skill：50 个（35 个单文件，15 个目录型）。
- 本次合并重复入口：14 个。
- 本次删除非精品入口：8 个（`auto-build`, `conversion-copywriter`, `debugging-strategies`, `image-to-code`, `mobile-agent-bridge`, `powerup`, `stitch-design-taste`, `web-to-design-md`）。
- 当前保留精品版：28 个。
- 注：`btw` 和 `loop` 仍保留在 Lotus 源仓库，但 Codex App 安装路径会按既有规则排除。

## 重复融合

| 重复组 | 已融合入口 | 保留入口 |
|---|---|---|
| GSAP 子入口 | gsap-core, gsap-frameworks, gsap-performance, gsap-plugins, gsap-react, gsap-scrolltrigger, gsap-timeline, gsap-utils | gsap |
| 前端视觉风格微入口 | design-taste-frontend-v1, gpt-taste, high-end-visual-design, minimalist-ui, industrial-brutalist-ui, redesign-existing-projects | taste-skill |

## 暂不融合

| 保留组 | 原因 |
|---|---|
| gstack investigate / mini-investigate | 前者是官方 gstack 的正式调查流程，后者处理单一小 Bug 的最小闭环。 |
| gstack 官方系列 | 保留官方细分入口，方便调研、评审、QA、发布等任务被精准调用。 |
| test-driven-development / loop | `loop` 是会话内定时轮询；`test-driven-development` 是先写失败测试再实现的开发纪律。 |

## 精品版清单

| Skill | 简写描述 | 详细描述 |
|---|---|---|
| agent-reach | 联网调研时路由搜索、社媒、网页、视频、招聘和代码来源。 | 用于需要外部信息的任务；先判断来源类型，再路由到搜索、社媒、网页、视频、职业、代码或行情渠道，最后汇总证据。 |
| agent-training-loop | 修 Bug 时循环复现、定位、修复和验证直到通过。 | 用于可自动复现的缺陷；不断执行复现命令、收集失败证据、打最小补丁并重跑验证，直到症状消失。 |
| ai-progress-workspace | 用事件流记录和展示 AI 任务的真实进度。 | 用于长任务或多步骤工作；把当前阶段、动作、证据、阻塞和下一步写成可追踪事件流。 |
| anysearch | 用本地多后端搜索网页、垂直站点、批量查询并抽取 URL 内容。 | 用于直接执行实时搜索、站内垂直搜索、并行批量搜索和 URL 正文抽取，是联网检索的底层工具型入口。 |
| baseline-packager | 把已验证行为固化为基线，防止后续改动回归。 | 用于回归保护；把当前正确行为沉淀为脚本、快照、fixture 或检查命令，方便后续改动对照。 |
| brandkit | 生成品牌视觉体系、Logo 方案、识别板和高端品牌物料图。 | 用于品牌图像创作；产出 Logo 方向、视觉板、识别系统、品牌场景图和高质 presentation 视觉资产。 |
| btw | 会话内临时插问时短答，不改文件并回到主线。 | 用于用户插入短问题；只给 3 到 5 句回答，不读取大上下文，不修改文件，答完回到原任务。 |
| codebase-memory-mcp | 用代码图谱索引仓库并查询架构、调用链、依赖和影响面。 | 用于结构化代码发现；优先通过 MCP 图谱做符号搜索、调用链追踪、架构概览和跨文件影响分析。 |
| feynman | 用白话和例子解释复杂概念，帮助用户真正听懂。 | 用于概念解释；把抽象术语拆成普通语言、类比、例子和最小心智模型。 |
| frontend-design | 做功能型前端页面时提升布局、视觉层级、响应式和交互状态。 | 用于产品 UI 和工具界面；关注信息密度、状态闭环、控件合适性、响应式、可访问性和交互反馈。 |
| full-output-enforcement | 要求完整输出代码或长文，禁止省略、占位和中途截断。 | 用于必须完整交付的长代码或长文；禁止 TODO、占位、片段省略和“其余同上”。 |
| goal | 管理长期目标、当前阶段、阻塞点和下一步行动。 | 用于跨轮任务；维护目标、进展、决策、未完成事项和下一步，避免长任务丢线。 |
| gsap | 做 GSAP 动画时处理补间、时间线、滚动、插件、框架集成和性能。 | 合并后的 GSAP 单入口；覆盖 core、timeline、ScrollTrigger、React/Vue/Svelte、插件、utils 和性能规则。 |
| gstack | 需 gstack 调研、评审、调试、QA 或发布流程时打开总入口。 | 用于调用官方 gstack 工作流；根据任务进入调研、计划评审、设计审查、QA、发布或部署等流程。 |
| image-2 | 生成或编辑 GPT Image 2 图片，支持换背景、透明素材和批量资产。 | 用于通用图片生成和编辑；优先使用宿主原生图像工具，缺失时走本地 newapi fallback。 |
| imagegen-frontend-mobile | 为 iOS、Android 和跨端 App 生成高质移动界面参考图。 | 用于移动应用视觉方案；输出多屏一致、层级清楚、可读性强的 app-native 参考图，不写代码。 |
| imagegen-frontend-web | 为网站和落地页逐区生成可还原的高质横版设计参考图。 | 用于网页视觉参考；按页面区块分别生成大图，保证开发者可逐区还原。 |
| insights | 复盘工作习惯和摩擦点，提炼可执行改进建议。 | 用于个人或团队复盘；从行为、流程、工具和反复卡点中提炼改进动作。 |
| ios-codex-preview | 搭建 iOS 模拟器预览，让 Codex 构建、运行、检查 SwiftUI 应用。 | 用于 iOS 开发预览；配置模拟器、浏览器预览、自动重建、健康检查和 SwiftUI 迭代路径。 |
| ios-ui-centering-fix | 修复 SwiftUI 中 header、loading、tab 等中心轴偏移问题。 | 用于 SwiftUI 视觉偏移；通过结构性居中和布局检查修正参考轴，不靠猜测 offset。 |
| loop | 会话内按指定间隔轮询任务，关闭会话后停止。 | 用于短期轮询；解析间隔和目标，在当前会话内重复检查，有副作用前先确认。 |
| mini-investigate | 修小 Bug 时按复现、定位、最小补丁和回归验证闭环。 | 用于单一症状的小缺陷；优先只动一个文件，按复现、原因树、证据、补丁、验证推进。 |
| polanyi-tacit | 阅读复杂代码时识别隐性约束、惯例和不可见风险。 | 用于复杂代码理解；找出没有写进文档的调用约束、数据假设、失败边界和团队习惯。 |
| security-auditor | 审查权限、依赖、密钥、配置和常见安全风险。 | 用于安全检查；覆盖认证授权、敏感信息、依赖风险、配置暴露和常见 Web/基础设施风险。 |
| shadcn-preset-refactor | 安全应用 shadcn preset，迁移视觉系统且保留业务行为。 | 用于 shadcn preset 迁移；先做基线和 dry-run，再应用主题或组件，避免覆盖业务逻辑。 |
| subagent | 把可并行任务拆给子 Agent 并汇总结论或补丁。 | 用于并行协作；把独立子任务分配给子 Agent，限定范围，等待结果并整合。 |
| taste-skill | 做官网、作品集和重设计时生成不模板化的高质前端界面。 | 合并后的视觉品味入口；覆盖旧版 taste、Awwwards 动效、高端视觉、极简、工业粗粝和现有项目重设计。 |
| test-driven-development | 新增功能或修 Bug 前先写失败测试再实现。 | 用于 TDD；先写能复现需求或缺陷的失败测试，再实现并让测试通过。 |
