---
name: image-2
description: 生图改图时生成视觉素材
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# Image 2

使用这个 skill 时，默认把用户需求转成可执行的 GPT Image 2 生图或改图任务，并优先调用 Codex 原生 `image_generation` / `image_gen` 能力。不要让用户再手写“请用 image-2”这类提示。

## 执行原则

- 默认直接生图或改图，不要只给提示词模板。
- 不要要求用户提供 `OPENAI_API_KEY`；Codex 原生生图不需要用户在对话里粘贴 key。
- 调用 API 时，默认使用当前本机 Codex 已登录账号/会话对应的 API 能力；不要另找、另配或要求用户提供其他 API key，除非用户明确指定。
- 如果当前 Codex 暴露了可选模型，选择 GPT Image 2 / `gpt-image-2`。
- 如果当前 Codex 只暴露原生 `image_generation` / `image_gen` 工具而没有模型参数，直接使用原生工具，不要为了指定模型改走临时 SDK 脚本。
- 只有在用户明确要求 API/CLI、批处理脚本、固定输出路径参数，或原生工具不可用时，才说明 CLI/API 回退方案。
- 对本地项目要用的图片，生成后把最终文件放进项目目录；不要让项目引用只停留在 Codex 默认生成目录。

## 输入判断

- 用户没有给图片：按新图生成处理。
- 用户给了参考图但没有要求保留原图局部：按参考生成处理。
- 用户要求“把这张图改成/去掉/换成/保留某人/换背景”：按改图处理。
- 用户要求多张素材或多种风格：逐张生成，不要把多个不同资产塞进同一个提示词。
- 用户要求透明背景：先用纯色抠图流程；复杂毛发、玻璃、烟雾、半透明材质再询问是否需要真透明回退方案。

## 提示词规整

把用户原话整理成清晰的视觉规格。用户已经写得很具体时，只做结构化；用户说得很泛时，可以补少量有助于成片的细节。

推荐结构：

```text
Use case: <product-mockup / poster / ui-mockup / avatar / icon / illustration / photo-edit>
Primary request: <用户核心需求>
Input images: <参考图/改图目标/风格图，若有>
Subject: <主体>
Style: <摄影/插画/3D/扁平/UI mockup 等>
Composition: <构图、比例、留白、视角>
Lighting and mood: <光线与情绪>
Text: "<必须逐字出现的文字>"
Constraints: <必须保留/必须避免>
Avoid: watermark, random text, distorted hands, broken UI, low-resolution artifacts
```

## 常见效果

- 产品图：明确材质、尺寸感、背景、阴影、镜头和用途。
- 海报/封面：明确主题、主视觉、文字原文、层级和留白。
- UI mockup：明确设备、界面类型、信息密度、组件状态；不要生成不可读的随机小字。
- 头像/角色：明确年龄段、服装、表情、镜头、风格；需要保留身份时反复强调不改变脸部结构。
- 换背景：强调只改背景，保留主体、边缘、姿态、颜色和光照一致性。
- 风格迁移：说明参考图只作为风格，不要照抄构图，除非用户要求。
- 透明素材：生成在纯色背景上，留足边距，不要阴影、反光和接触地面。

## 透明背景默认流程

Codex 原生生图通常不提供显式透明背景参数。默认这样处理：

1. 先生成纯色背景版本，优先用 `#00ff00`，绿色主体改用 `#ff00ff`。
2. 提示中写明背景必须是完全纯色，无阴影、渐变、纹理、反射或地面。
3. 生成后使用可用的本地抠图工具去背景；如果当前环境有系统 `imagegen` skill 的 `remove_chroma_key.py`，优先使用它。
4. 检查输出是否有 alpha 通道、边缘是否干净、主体是否被误删。
5. 如果主体包含毛发、玻璃、烟雾、透明液体、复杂半透明边缘，先告诉用户这类图更适合真透明回退方案，再确认是否继续。

透明图提示片段：

```text
Create the subject on a perfectly flat solid #00ff00 chroma-key background for background removal.
The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation.
Keep the subject fully separated from the background with crisp edges and generous padding.
Do not use #00ff00 anywhere in the subject.
No cast shadow, no contact shadow, no reflection, no watermark, and no text unless explicitly requested.
```

## 质量检查

生成或改图后至少检查：

- 主体是否符合需求。
- 风格、构图、比例是否适合用途。
- 文字是否逐字正确；文字错误时重试，不要假装正确。
- 改图是否只改了指定区域，主体身份和重要细节有没有漂移。
- 是否有水印、乱码文字、多余 logo、畸形手指、破碎 UI、低清噪点。

如果需要迭代，每次只改一个明确问题，例如“文字不对”“背景太复杂”“主体太小”。

## 交付

- 预览/头脑风暴：直接展示生成图。
- 项目素材：把最终图片保存到项目中合适目录，并说明路径。
- 多资产：给每个文件稳定、可读的英文文件名。
- 不要覆盖已有资产，除非用户明确要求替换；默认使用 `name-v2.png` 这类版本名。
