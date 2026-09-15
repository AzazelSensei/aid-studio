# Support / 获取帮助

中文与英文问题均可。Questions in Chinese and English are welcome.

## Choose a channel / 选择入口

| Need / 问题 | Channel / 入口 |
| --- | --- |
| Installation, upgrade or recovery / 安装升级 | [Deployment guide / 部署指南](deploy/README.md) |
| Getting started / 首次使用 | [中文说明](README.md#快速开始) · [English guide](README.en.md#quick-start) |
| Usage walkthrough / 操作教程 | [Usage tutorials (Chinese) / 使用教程](https://gzxxaitdb.feishu.cn/docx/LZ5zdesEgo1z4Mxc7OWc7zTHnJc) |
| Reproducible bug or feature request / 缺陷或建议 | [GitHub issue templates](https://github.com/gzxx-2025/aid-studio/issues/new/choose) |
| Configuration or deployment question / 配置部署咨询 | [GitHub issues](https://github.com/gzxx-2025/aid-studio/issues/new/choose) or [community chat / 交流群](README.md#交流与反馈) |
| Security vulnerability / 安全漏洞 | [Private reporting instructions / 私密报告说明](SECURITY.md) |

GitHub is the primary issue tracker so reports can be searched and followed in one place. The [Gitee mirror](https://gitee.com/gzxx-2025/aid-studio) provides another source access point. Avoid filing the same report on multiple platforms; if you already did, link the reports.

建议优先在 GitHub 统一记录问题，方便搜索和跟进；已在其他渠道反馈时，请附上链接，避免重复排查。

## What to include / 反馈内容

- AID release tag or commit, and updater version if the problem involves an upgrade.
- Operating system, CPU architecture, memory, deployment mode and relevant browser version.
- The affected workflow and exact steps to reproduce it.
- Expected and actual behavior, plus a small redacted log excerpt or screenshot.
- For model issues, the public provider/model name and parameters. Never include credentials or private gateway addresses.

版本、环境、复现步骤、预期与实际结果越明确，越方便定位。只附最小必要的脱敏日志，不上传完整数据库、配置文件或私人作品。

Output from `sudo aid default`, `sudo aid mysql`, configuration files and some logs can include sensitive information. Inspect and redact content before sharing it. For a suspected vulnerability, stop and use [SECURITY.md](SECURITY.md).

## Community support / 社区支持

The community chat is for open-source discussion and technical support, with no advertising or hidden charges. Community help is provided as maintainers and contributors are available; there is no guaranteed response time. AI provider usage, hosting and storage are separate services and may incur costs.

交流群用于开源交流与技术支持，无广告和隐形消费。社区按维护者与贡献者实际可用时间提供帮助，不承诺固定响应时限。模型调用、服务器与存储费用由相应服务决定。
