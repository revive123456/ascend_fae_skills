---
name: ascend-fae-skills:download_weight
description: 从国内镜像（ModelScope、HF Mirror、魔乐社区等）下载任意模型权重。支持断点续传、精度变体选择、后台执行。触发词：下载权重、下载模型、download weight、download model、pull model。
---

# 下载模型权重

## 核心原则

- **路径硬规则**：用户没说下载到哪个目录，必须先反问，不得自行假设。
- **国内源优先**：默认按以下优先级选择下载源，用户指定则尊重。
- **后台执行**：下载操作必须使用 `run_in_background: true` 在后台执行，不得阻塞主会话。启动后告知用户任务 ID 和查看进度方式（`/tasks`）。
- **local_dir**：下载时必须指定 `local_dir` 直接写入目标目录，禁止用 `cache_dir`（会产生嵌套缓存路径）。

## 下载源优先级

| 优先级 | 源 |
|--------|-----|
| 1 | ModelScope |
| 2 | HF Mirror |
| 3 | git clone（HF Mirror） |
| 4 | 魔乐社区 |
| 5 | 用户指定 |

## 参数收集

| 参数 | 必须？ | 说明 |
|------|--------|------|
| 模型名 | ✅ | 完整路径如 `Qwen/Qwen2-7B-Instruct`，或简称如 `Qwen2-7B` |
| 下载路径 | ✅ | 绝对路径，如 `/data/models/Qwen2-7B` |
| 精度变体 | 可选 | `bf16`、`fp16`、`fp8`、`w4a8`、`int4` |
| 下载源 | 可选 | 不指定则按优先级自动选 |

缺少模型名或下载路径必须先问清楚再继续。

## 基线测试场景

| # | 输入 | 期望行为 |
|---|------|----------|
| 1 | "下载 Qwen/Qwen2-7B" | 反问下载目录 |
| 2 | "下载权重到 /data/models" | 反问模型名 |
| 3 | "下载 Qwen/Qwen2-7B bf16 到 /data/models" | 参数齐全，按源优先级 **后台** 下载 |
| 4 | "下载 Qwen2-7B 到 /data/models" | 简称 → 搜索解析 → 确认 → **后台** 下载 |
| 5 | "从魔乐社区下载 ChatGLM-6B 到 /data/models" | 指定源优先 → 搜索解析 → **后台** 下载 |
| 6 | "下载 foo-bar-baz 到 /data/models" | 搜不到 → 请用户提供完整路径 |
| 7 | "下载 Qwen/Qwen3.5-4B 到 /d" | 所有步骤完成后，下载动作必须 `run_in_background: true`，告知用户任务 ID |
