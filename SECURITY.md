# Security policy / 安全报告说明

## Report privately / 私密报告

Do not publish vulnerability details, exploit code, credentials or affected user data in public issues, pull requests or group chats.

Open the [repository Security tab](https://github.com/gzxx-2025/aid-studio/security) and choose **Report a vulnerability** to contact the maintainers privately. You need to sign in to GitHub. If that option is unavailable, contact a maintainer privately through the [community contact entry](README.md#交流与反馈) and ask for a secure reporting channel before sending technical details. Do not post the report to the group.

请在 GitHub 仓库 Security 页使用 **Report a vulnerability** 私密报告。若入口不可用，可通过[社区联系入口](README.md#交流与反馈)私下联系维护者，先确认安全接收渠道，再提供细节；不要在公开 Issue、PR 或交流群发布漏洞利用方法及敏感数据。

## Include in the private report / 私密报告内容

- Affected release tag or commit and deployment mode.
- A concise description, impact and required access or permissions.
- Minimal reproduction steps using a local or explicitly authorized environment.
- A redacted proof of concept and any suggested mitigation.

报告应包含受影响版本、部署方式、影响范围、所需权限、最小复现步骤及可能的缓解措施。请使用自己拥有或获授权的环境；不要上传真实密钥、数据库备份或其他用户的数据。

## Versions and coordination / 版本与协调

Check the [latest stable release](https://github.com/gzxx-2025/aid-studio/releases/latest) when identifying affected versions. Include older versions if you have verified them, and clearly identify prereleases. This project does not publish a long-term support or security-backport schedule.

Maintainers assess reports and coordinate fixes and disclosure with the reporter. Please allow that coordination before publishing details. No fixed response time or bounty is promised by this policy.

请区分已核验受影响的正式版与预发布版。项目目前未公布长期支持或安全修复回补周期；维护者会评估报告，并与报告者协调修复与披露。本说明不承诺固定响应时限或漏洞奖励。
