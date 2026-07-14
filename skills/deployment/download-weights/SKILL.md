---
name: download-weights
description: >
  从国内镜像（ModelScope、HF Mirror、魔乐社区等）下载任意模型权重。
  支持断点续传、精度变体选择、后台执行。
  触发词：下载权重、下载模型、download weight、download model、pull model。
---

# 下载模型权重

帮用户在目标环境中从国内源下载模型权重文件。

## 核心原则

- **启发式执行**：以下指引提供知识和原则，你根据实际上下文灵活判断，不机械照搬。
- **路径硬规则**：如果用户没有明确说下载到哪个目录，必须先反问确认路径，不得自行假设。
- **国内源优先**：默认从 ModelScope / HF Mirror / 魔乐社区下载，用户指定了源则尊重用户选择。
- **后台不阻塞**：下载是长耗时操作，确认命令后立即用后台方式执行，让用户继续会话。

## 工作流

### 第一步：收集参数

跟用户确认以下信息，缺少任何一个都必须问清楚：

| 参数 | 必须？ | 说明 |
|------|--------|------|
| 模型名 | ✅ 必须 | 如 `Qwen/Qwen2-7B-Instruct`、`ChatGLM-6B` |
| 下载路径 | ✅ 必须 | 绝对路径，如 `/data/models/Qwen2-7B` |
| 精度变体 | 可选 | `bf16`、`fp16`、`fp8`、`w4a8`、`int4` 等 |
| 下载源 | 可选 | 不指定则按国内镜像优先级自动选择 |

如果用户一次给出了模型名和路径，可以直接进入下一步，无需重复确认。

### 第二步：检测环境可用工具

在目标环境上快速探测可用的下载工具。按以下优先级，找到第一个能用的即可：

```bash
# 1. modelscope (最佳，支持续传、进度显示)
python -c "import modelscope" 2>/dev/null && echo "modelscope: OK"

# 2. huggingface_hub (HF Mirror 场景)
python -c "import huggingface_hub" 2>/dev/null && echo "huggingface_hub: OK"

# 3. git-lfs (git clone 方式)
git lfs version 2>/dev/null && echo "git-lfs: OK"

# 4. wget (直链下载，-c 支持断点续传)
which wget 2>/dev/null && echo "wget: OK"

# 5. curl (直链下载，-C - 支持断点续传)
which curl 2>/dev/null && echo "curl: OK"
```

如果全部不可用，告知用户先安装 `modelscope` 包或 `git-lfs`：

```bash
pip install modelscope
# 或
apt install git-lfs && git lfs install
```

### 第三步：确定下载源和命令

#### 国内源优先级（用户未指定时）

| 优先级 | 源 | 工具 | 命令模板参考 |
|--------|-----|------|-------------|
| 1 | ModelScope | modelscope SDK | `python -c "from modelscope import snapshot_download; snapshot_download('{model_id}', cache_dir='{path}')"` |
| 2 | HF Mirror | huggingface-cli | `huggingface-cli download {model_id} --local-dir {path} --endpoint https://hf-mirror.com` |
| 3 | HF Mirror | git clone | `GIT_LFS_SKIP_SMUDGE=1 git clone https://hf-mirror.com/{model_id} {path} && cd {path} && git lfs pull` |
| 4 | 魔乐社区 | 按其 CLI/SDK | 按魔乐社区文档适配 |
| 5 | 用户指定 | 用户指定的方式 | 尊重用户给的具体 URL 或命令 |

#### 模型名映射

不同源对同一模型的路径格式可能不同。常见映射：

- **ModelScope**: `qwen/Qwen2-7B-Instruct`（全小写组织名）
- **HF / HF Mirror**: `Qwen/Qwen2-7B-Instruct`（保持原始大小写）
- 不确定时，用搜索验证：`modelscope search <模型关键词>` 或访问对应网站

#### 精度变体

- 用户指定精度时，在模型仓库中优先搜索包含精度标识的目录/文件（如 `bf16`、`fp8`、`w4a8`）
- 找不到对应精度 → 告知用户该模型不提供此精度，建议切换到可用精度或换模型
- 如果模型只有一个版本（无精度选择），直接下载，告知用户即可

### 第四步：确认并后台执行

1. **展示将要执行的命令**给用户看一眼
2. 用户确认后，用 `run_in_background: true` 发起下载
3. 明确告知用户："下载已在后台启动，你可以继续其他操作。随时问我'进度如何'来查看状态。"

```bash
# 示例：后台下载（Claude 使用 Bash 工具的 run_in_background: true）
huggingface-cli download Qwen/Qwen2-7B-Instruct \
  --local-dir /data/models/Qwen2-7B \
  --endpoint https://hf-mirror.com
```

### 第五步：进度跟踪

用户询问进度时：

```bash
# 查看目标目录大小变化
du -sh /data/models/Qwen2-7B 2>/dev/null
# 或查看文件列表
ls -lh /data/models/Qwen2-7B 2>/dev/null
```

- 如果目录在持续增长 → 下载进行中
- 如果目录大小稳定 + 有完整文件 → 下载完成
- 如果目录为空或很小 → 可能下载失败，检查后台任务状态

## 断点续传

以下工具天然支持断点续传，优先使用：

| 工具 | 续传机制 |
|------|----------|
| `modelscope snapshot_download` | SDK 内置，自动跳过已下载文件 |
| `huggingface-cli download` | 内置 resume，跳过已有文件 |
| `git lfs pull` | 增量拉取，只下载缺失的 LFS 对象 |
| `wget -c` | `-c` 参数自动续传 |
| `curl -C -` | `-C -` 参数自动续传 |

如果下载中断，直接用相同命令重试即可——这些工具会自动跳过已完成的部分。

## 下载完成后

下载完成后，建议做一次完整性验证：

```bash
# 如果用了 modelscope / huggingface-cli，它们会自行校验
# 如果用 git clone，检查是否有 .lfs 指针文件未展开
find /data/models/xxx -name "*.png" -o -name "*.safetensors" | head -5
ls -lh /data/models/xxx/
```

告知用户下载完成，并提示路径。

## 基线测试场景

以下场景用于验证 skill 行为是否符合预期（通过与 Claude 对话验证，无需测试代码）：

| # | 输入 | 期望行为 |
|---|------|----------|
| 1 | "下载 Qwen/Qwen2-7B" | 反问下载到哪个目录 |
| 2 | "下载权重到 /data/models" | 反问模型名是什么 |
| 3 | "下载 Qwen/Qwen2-7B bf16 到 /data/models" | 检测环境 → 选源 → 拼命令 → 确认 → 后台执行 |
| 4 | "下载 Qwen/Qwen2-7B w4a8 到 /data" | 搜索 w4a8 版本，找不到则提示用户 |
| 5 | "从魔乐社区下载 xxx 到 /data/models" | 按魔乐社区方式下载，尊重用户指定源 |
| 6 | 目标环境无任何下载工具 | 提示安装 modelscope 或 git-lfs |
| 7 | 下载中断后重试 | 自动续传，不重复下载已有文件 |
