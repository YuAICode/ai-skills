---
name: lambda-logs-zh
description: 拉 AWS Lambda 的 CloudWatch 最近报错,按频次聚类并给中文根因摘要。当用户说"看 lambda 日志 / lambda 报错排查 / 这个函数出错了 / 查 CloudWatch"时触发。脚本负责取日志,Claude 负责聚类去重 + 中文根因 + 修复建议。
---

# lambda-logs-zh — Lambda 报错中文速查

把 CloudWatch 里一大片重复报错,收敛成"几类问题 + 每类的中文根因和建议"。

## 何时触发

用户说"看下 xx 函数的 lambda 日志 / lambda 报错了 / 查 CloudWatch / 排查这个函数"。

## 用法

1. 取报错日志(需 aws CLI + 凭据):
   ```bash
   bash <skill>/bin/fetch-errors.sh <函数名> [窗口] [region]
   # 例:bash <skill>/bin/fetch-errors.sh my-func 6h ap-southeast-1
   # 或直传日志组:bash <skill>/bin/fetch-errors.sh --group /aws/lambda/my-func 24h
   ```
   窗口缺省 1h(支持 1h/6h/24h/7d)。输出 LOG_GROUP / WINDOW / ERRORS(原始报错文本)。
2. **聚类去重**:把 ERRORS 按"同一类错误"归并(忽略时间戳/requestId/具体值的差异),统计每类出现次数。
3. 对每类给出中文小结:
   - **现象**(报错关键行)· **出现次数** · **疑似根因** · **建议排查/修复方向**
   - 按次数从高到低排;高频的优先。
4. 报告读取范围(日志组 + 窗口)与"没覆盖到的"(如窗口外、非 ERROR 级)。

## 输出模板

```markdown
## <函数名> 最近 <窗口> 报错小结(共 N 类 / M 条)

### 1. <一句话归类> ×<次数>
- 现象:`<报错关键行>`
- 疑似根因:<分析>
- 建议:<排查/修复方向>

### 2. ...
```

## 硬规则

- **不臆造**:根因拿不准就说"需结合代码/调用上下文确认",别编。
- 聚类按错误**本质**归并,不要把同一类的不同 requestId 当成多类。
- 报错里若含疑似密钥/PII,在摘要里**打码**,不要原样回显敏感值。
- 只读日志,不改任何 AWS 资源。

## 边界

- 依赖 aws CLI + 已配置凭据/region;缺失时脚本会明确报错。
- 只看 CloudWatch Logs;不拉 X-Ray / 指标(需要的话另说)。
