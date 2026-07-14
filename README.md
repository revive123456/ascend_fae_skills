# ascend-fae-skills

昇腾 FAE 技能插件 — 面向华为昇腾 AI 处理器生态的 Claude Code 技能集合。

## 安装

```bash
claude plugins install <repository-url>
```

## 技能列表

| 分类 | 技能 | 说明 |
|------|------|------|
| deployment | (待添加) | 部署交付相关 |

## 技能分类框架（规划中）

```
skills/
├── cann/              # CANN 异构计算架构
├── mindspore/         # MindSpore 框架
├── pytorch-ascend/    # PyTorch 昇腾适配
├── tools/             # 工具链（MindStudio、ModelArts 等）
└── deployment/        # 部署交付
```

## 开发

本项目遵循 TDD 原则开发技能。详见 [CLAUDE.md](./CLAUDE.md)。

## License

MIT
