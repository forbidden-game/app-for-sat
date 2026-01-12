# Procedures（自增长规则 + steps 模板）

本页描述 procedure taxonomy 的自增长方式，以及 steps 的统一格式要求。

## 1) Procedure 的定义
- Procedure = 可复用的解题套路/方法（跨题可复用），用于“步骤相似”检索。
- 每题至少归属 1 个主 procedure（MVP）。

字段要点：
- `name`：短、稳定、可复用（避免带具体数字/题干语句）。
- `steps[]`：3–7 步，短句，尽量是动作动词开头。

## 2) Steps 输出格式（统一约束）
- 3–7 步
- 每步 <= 12 个中文词（或 <= 80 字符）
- 不要写“计算过程长篇”，只写“该做什么”
- 例（SAT Math 通用）：
  1) 识别目标与已知条件
  2) 建模：列式/设变量
  3) 变形：整理到可求解形式
  4) 求解：得到目标量
  5) 校验：代回与检查约束
  6) 映射：匹配选项并排除陷阱

## 3) 自增长护栏（必须）
### A. 先检索再创建
- 调 `search_procedure_candidates(subject, query)`
- 若 top1 相似度 >= 阈值（建议 0.80 起），禁止创建新 procedure，直接复用。

### B. 允许合并/别名
- 若检测到重复：发起 `merge_procedures(from,to,rationale)`
- 合并后：
  - `from.status = merged`
  - `from.merged_into = to`
  - `to.aliases += from.name + from.aliases`

### C. Steps 版本化
- 修改 steps 时：`steps_version += 1`
- `attempt_insights` 记录当次 version

## 4) 无解析条件下的“procedure 归类”策略
- AI 先自己解题得到“解法摘要”（不需要展示给学生）。
- 再把摘要映射到已有 procedure：
  - 若已有 procedure 的 steps 能覆盖该解法（>= 80% 匹配），复用。
  - 否则创建。

## 5) 评估与迭代（后续）
- 指标：
  - procedure 数增长率（过快说明碎片化）
  - merge 频率（过低说明不会去重）
  - 重复错题命中率（学生体验关键）
- 当 error_mode_detail 分布集中时，考虑升级为新的 error_mode_enum。
