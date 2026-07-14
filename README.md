# ascend-fae-skills

昇腾 FAE 技能插件 — 面向华为昇腾 AI 处理器生态的 Claude Code 技能集合。

## 安装

要求：**Python 3**（Linux/macOS/Windows 通常已预装）

```bash
git clone https://github.com/revive123456/ascend_fae_skills.git
cd ascend_fae_skills
bash install.sh
```

重启 Claude Code 后运行 `/download-weights` 验证。

### 卸载

```bash
bash install.sh --uninstall
```

### 原理

- `install.sh` 将项目目录链到 `~/.claude/plugins/`（Windows: Junction，Linux/macOS: symlink）
- 自动注册到 `installed_plugins.json` 和 `settings.json`
- 改代码即时生效，无需重新安装

### 开发

在项目 working copy 里直接运行 `bash install.sh` 即链接到当前目录。

新增 skill 只需两步：
1. 在 `skills/<分类>/<新技能>/SKILL.md` 写技能内容
2. 在 `.claude-plugin/plugin.json` 的 `skills` 数组中加一行路径

## 技能列表

| 分类 | 技能 | 说明 |
|------|------|------|
| deployment | `download-weights` | 从国内镜像下载模型权重，支持断点续传 & 后台执行 |
