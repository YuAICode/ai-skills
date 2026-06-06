# naming-buddy

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/naming-buddy)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

命名困难症救星。给一段逻辑/用途描述 + 语言 → 建议好的变量/函数/类/文件/常量/布尔名,中英对照解释。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
# 全局(所有项目可用)
cp -r naming-buddy ~/.claude/skills/

# 或 项目级(只在当前项目生效)
cp -r naming-buddy .claude/skills/
```

**重启 Claude Code** 后即可触发。

## 用法

触发词任选一:

- `/naming-buddy`
- `帮我起个名字`
- `这个变量叫什么好`
- `给这个函数命名`
- `命名建议`

### 示例

**示例 1:给变量命名**

```
/naming-buddy 这是个 Go 变量,存储用户上次登录的时间戳
```

Claude 输出:

```
命名类型:变量
语言:Go(惯例:camelCase)

候选名(按推荐度排):
1. lastLoginAt      — 介词 At 明确这是时间点;Go 标准库也用 xxxAt 后缀
2. lastLoginTime    — 语义清晰,常见写法
3. lastSignInAt     — 若系统统一用 signIn 而非 login 更一致
4. prevLoginAt      — prev 强调"上一次",适合有 currentLoginAt 对应的场景
5. lastAuthAt       — auth 更通用,适合 OAuth 场景

坏味道提醒:
- timestamp、ts、t 太泛,看不出业务含义
- loginTs 匈牙利命名风格,不推荐
```

**示例 2:给布尔变量命名**

```
这是个 Python 变量,表示用户是否已完成邮箱验证
```

Claude 输出包含:
- `is_email_verified`(推荐)
- `email_verified`
- `has_verified_email`
- 坏味道:`emailStatus`、`verified`(太泛)、`flag`

**示例 3:给函数命名**

```
TypeScript 函数,把原始 API 返回的用户对象转换成前端展示用的格式
```

Claude 给出:
- `mapUserToViewModel`、`transformUserResponse`、`toUserViewModel` 等候选

### 命名惯例速查

| 语言 | 变量/函数 | 类 | 常量 | 文件 |
|------|----------|----|------|------|
| Go | camelCase | PascalCase | ALL_CAPS / 包级小写 | snake_case.go |
| Python | snake_case | PascalCase | UPPER_SNAKE_CASE | snake_case.py |
| TypeScript/JS | camelCase | PascalCase | UPPER_SNAKE_CASE | kebab-case.ts |
| Java/Kotlin | camelCase | PascalCase | UPPER_SNAKE_CASE | PascalCase.java |
| Rust | snake_case | PascalCase | UPPER_SNAKE_CASE | snake_case.rs |
| Swift | camelCase | PascalCase | camelCase | PascalCase.swift |
| Dart/Flutter | camelCase | PascalCase | lowerCamelCase | snake_case.dart |
| CSS/HTML | kebab-case | — | — | kebab-case.css |

完整工作流、输出模板与硬规则见 [SKILL.md](./SKILL.md)。

## 硬规则摘要

- 名字表达"意图",不表达"类型"
- 布尔必须有 is/has/can/should 等前缀
- 不臆造领域术语,不确定就问用途
- 遵循目标语言/项目既有惯例
- 指出原名坏味道,说明为什么不好

## 📄 License

[MIT](../../LICENSE)
