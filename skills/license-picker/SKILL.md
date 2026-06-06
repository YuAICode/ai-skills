---
name: license-picker
description: 帮用户选择并生成开源 LICENSE 文件。当用户说"选个开源协议 / 帮我生成 LICENSE / 用什么许可证 / 加个 license"时触发。先问清诉求推荐协议,再用脚本生成填好版权信息的 LICENSE。
---

# license-picker — 选 + 生成开源协议

帮你挑一个合适的开源协议,并生成填好作者/年份的 `LICENSE`。

## 何时触发

用户说"选个开源协议 / 帮我加个 LICENSE / 用什么许可证 / 这个项目该用啥 license"。

## 用法

1. **问清诉求**(决定推荐哪个):
   - 要最宽松、随便用?→ **MIT** / **ISC**(几乎一样,MIT 最流行)
   - 想要专利授权条款?→ **Apache-2.0**
   - 不想承担署名/背书争议?→ **BSD-2/3-Clause**
   - 想彻底放进公共领域?→ **Unlicense**
   - 想要 copyleft(衍生也必须开源)?→ **GPL-3.0**
2. **生成**(内置可填充:MIT / ISC / BSD-2-Clause / BSD-3-Clause / Unlicense):
   ```bash
   bash <skill>/bin/add-license.sh <SPDX-ID> [author] [year] [--dir 目录] [--force]
   # 例:bash <skill>/bin/add-license.sh MIT "张三" 2026
   ```
   author 缺省取 `git config user.name`,year 缺省今年;已存在 LICENSE 不覆盖(除非 `--force`)。
3. **Apache-2.0 / GPL-3.0**:正文很长且须逐字使用,脚本会给官方文本链接;按需把完整正文写入 LICENSE(Apache 另需在源码头加 notice)。

## 边界

- **不是法律意见**。重要商业/合规场景请咨询专业人士。
- 脚本只写 `LICENSE` 文件,不改 package 元数据(如 package.json 的 license 字段)——需要的话另行更新。
- copyleft 长协议不内置填充,只给官方指引,避免分发不完整/被改动的法律文本。
