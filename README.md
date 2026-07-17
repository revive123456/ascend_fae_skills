# ascend-fae-skills

昇腾 FAE 技能插件 — 面向华为昇腾 AI 处理器生态的 Claude Code 技能集合。

## 安装

```bash
git clone https://github.com/revive123456/ascend_fae_skills.git
cd ascend_fae_skills
bash install.sh
```

重启 Claude Code 后运行 `/ascend-fae-skills:download_weight` 验证。

### 卸载

```bash
bash install.sh --uninstall
```

### 原理

- `install.sh` 将项目目录链接到 `~/.claude/skills/ascend-fae-skills`（Windows: Junction，Linux/macOS: symlink）
- Claude Code 自动发现 `~/.claude/skills/` 下的插件，加载为 `ascend-fae-skills@skills-dir`
- 改代码即时生效（技能内容修改后下个会话生效），无需重新安装

### 开发

在项目 working copy 里直接运行 `bash install.sh` 即链接到当前目录。

新增 skill 只需两步：
1. 在 `skills/<新技能>/SKILL.md` 写技能内容
2. 在 `.claude-plugin/plugin.json` 的 `skills` 数组中加一行路径

## 技能列表

| 技能 | 说明 |
|------|------|
| `download_weight` | 从国内镜像下载模型权重，支持断点续传 & 后台执行 |
| `pd-separated-service` | PD（Prefill-Decode）分离推理服务部署，支持单机多卡 & 多机分离 |
