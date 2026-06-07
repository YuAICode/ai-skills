# code-haiku

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/code-haiku)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

把一个函数 / 代码片段 / diff 写成一首**俳句或打油诗**，抓住代码的「神韵」。
好玩、可分享；不是注释，是诗。

## 安装

把本目录拷进 Claude Code 的 skills 目录，重启后即可触发：

```bash
# 全局（所有项目可用）
cp -r code-haiku ~/.claude/skills/

# 或 项目级（只在当前项目生效）
cp -r code-haiku .claude/skills/
```

## 用法

### 触发词

直接说出触发词，Claude 会自动运行本 skill：

- `/code-haiku`
- `给这段代码写首诗`
- `把这个函数写成俳句`
- `这个 diff 怎么用诗表达`
- `帮我写个 code haiku`
- `这个 PR 能用俳句总结吗`

### 输入方式

粘贴任意代码片段，加上触发词即可：

```
把下面这个递归函数写成俳句：

def factorial(n):
    if n == 0:
        return 1
    return n * factorial(n - 1)
```

### 输出格式

```
【俳句】
自己召唤己
层层深入无尽处
零时方归来

【英文 haiku】
calls itself again
falling through the looking glass
zero ends the dream

【诗解】
"自己召唤己"映射递归调用自身；"零时方归来"是 n == 0 的基础条件终止递归。
```

### 变体风格

说「再来一个」或「换个风格」，可以切换：

| 风格 | 气质 |
|------|------|
| 写实风 | 还原代码的实际处境（凌晨上线、祈祷别崩） |
| 禅意风 | 自然意象映射逻辑结构（递归→镜中镜） |
| 自嘲风 | 吐槽技术债或命名混乱 |
| 史诗风 | 把工具函数写出宇宙征程的气势 |

## 示例

### 递归函数

**输入：**
```python
def factorial(n):
    if n == 0:
        return 1
    return n * factorial(n - 1)
```

**输出：**
> 自己召唤己  
> 层层深入无尽处  
> 零时方归来

---

### try/catch 吞掉所有异常

**输入：**
```javascript
try {
    await doSomethingRisky()
} catch (e) {
    // TODO: handle this properly
}
```

**输出：**
> 渡劫入火坑  
> TODO 轻描淡写  
> 下次再说吧

---

### TODO 堆积的文件

**输入：**
```python
# TODO: refactor this
# TODO: add validation
# FIXME: this is broken
# TODO: write tests
def process_data(data):
    return data  # placeholder
```

**输出：**
> 满纸皆 TODO  
> 占位符孤守深夜  
> 测试从未来

---

## 硬规则摘要

- 抓意图，不堆术语——诗写的是代码「做什么」，不是「长什么样」
- 别把诗写成注释——不解释参数类型，只写神韵
- 不臆造代码没有的逻辑
- 默认一次一首，要求变体时才多写
- 可调侃技术债，不刻薄攻击作者

完整工作流、意象指引与硬规则见 [SKILL.md](./SKILL.md)。

## License

[MIT](../../LICENSE)
