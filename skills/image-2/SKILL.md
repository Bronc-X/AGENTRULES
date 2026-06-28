---
name: image-2
description: GPT Image 2 生图改图入口；用于图片生成、图片编辑、风格迁移、换背景、透明素材和批量视觉资产。触发后优先调用 Codex 内置 `image_gen` / `image_generation`；如果宿主没有暴露原生工具，则使用本 skill 的本机 newapi fallback 调用 `gpt-image-2`。
---

# Image 2

这个 skill 是 Lotus 对 GPT Image 2 / Codex 原生生图能力的入口，不是只产出提示词的协议。用户请求生成或编辑位图素材时，默认直接执行生图/改图；不要只回复“我可以给你提示词”。

## 执行路由

1. 优先使用当前 Codex 宿主暴露的原生 GPT Image 工具：
   - 首选 `image_gen`。
   - 如果宿主使用 `image_generation`，使用 `image_generation`。
   - 如果工具允许选择模型，选择 GPT Image 2 / `gpt-image-2`。
   - 如果工具没有模型参数，直接调用原生工具，不要为了指定模型改走临时 SDK 脚本。
2. 如果当前会话同时有系统 `imagegen` skill，把系统 `imagegen` 视为原生工具流程的细节真源。
3. 如果当前宿主没有暴露原生生图工具，使用本 skill 自带的 newapi fallback：
   - 脚本：`scripts/image2_newapi.py`
   - 本机私有配置：`runtime.local.json`
   - 配置模板：`runtime.example.json`
   - 默认模型：`gpt-image-2`
4. skill 不能把未暴露的宿主工具“变出来”。如果原生工具不可用，就直接走 newapi fallback；不要停在解释层。

## 本机 newapi fallback

只在原生 `image_gen` / `image_generation` 不可用时使用。不要把本机 key 写进仓库；每台机器自行创建自己的 `runtime.local.json` 或设置环境变量。

配置优先级：

1. 命令行参数 `--api-key` / `--base-url`
2. 环境变量 `IMAGE2_NEWAPI_KEY` / `IMAGE2_NEWAPI_BASE_URL`
3. `runtime.local.json`
4. `runtime.example.json` 仅作模板，不能直接用于真实调用

推荐命令：

```bash
python ~/.codex/skills/image-2/scripts/image2_newapi.py generate \
  --prompt "a clean square minimal lotus flower made from subtle circuit traces, calm white background, premium product icon style, no text, no watermark" \
  --out output/imagegen/lotus-preview.png \
  --size 1024x1024 \
  --quality low
```

批量生成：

```bash
python ~/.codex/skills/image-2/scripts/image2_newapi.py generate-batch \
  --input tmp/imagegen/prompts.jsonl \
  --out-dir output/imagegen/batch \
  --size 1024x1024 \
  --quality low
```

JSONL 每行可以是：

```json
{"prompt":"...","out":"image-name.png","size":"1024x1024","quality":"low"}
```

## 原生工具优先原则

- 默认直接生图或改图，不要只给提示词模板。
- 不要要求用户在对话里粘贴 key。
- 原生工具可用时，不要绕去 newapi fallback。
- 对本地项目要用的图片，生成后把最终文件放进项目目录；不要让项目引用只停留在 Codex 默认生成目录。

## 输入判断

- 用户没有给图片：按新图生成处理。
- 用户给了参考图但没有要求保留原图局部：按参考生成处理。
- 用户要求“把这张图改成/去掉/换成/保留某人/换背景”：按改图处理；当前 newapi fallback 先覆盖生成和批量生成，复杂改图优先原生工具。
- 用户要求多张素材或多种风格：逐张生成，不要把多个不同资产塞进同一个提示词。
- 用户要求透明背景：`gpt-image-2` 不走真透明参数，先生成纯色背景版本，再用本地抠图工具去背景。

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
