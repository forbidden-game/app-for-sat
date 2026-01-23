# SAT Math `error_mode_enum`（MVP）

日期：2026-01-14

北极星：稳定枚举支撑“每个学生一个 AI 老师”的长期画像与可追问讲解。

目标：提供一个**稳定、可枚举**的错误模式集合，用于：

- 相似错误的细分（加权证据）
- 重点讲解的“对比你上次错法”
- 长期快照统计

规则：

- 必须包含 `unknown`。
- AI 可补充更细描述到 `error_mode_detail`，但不要随意扩枚举。

## 枚举建议（MVP 版）

- `unknown`
- `setup_equation`：未正确建模/列式
- `translate_words_to_math`：文字到数学翻译错误（条件/单位/关系）
- `algebra_manipulation`：代数变形错误（移项/分配/合并同类项）
- `sign_error`：符号错误（正负号、减法分配）
- `fraction_error`：分数/约分/通分错误
- `exponent_root_rules`：指数/根式规则错误
- `function_interpretation`：函数意义/输入输出/图像对应错误
- `graph_reading`：读图错误（坐标、斜率、截距、尺度）
- `geometry_relation`：几何关系使用错误（相似/全等/角度关系）
- `units_or_conversion`：单位/换算错误
- `compute_arithmetic`：算术计算错误
- `inequality_direction`：不等式方向翻转/范围错误
- `casework_missing`：分类讨论遗漏/边界没考虑
- `choose_option_mapping`：算出结果但映射到选项出错（单位/形式/对错选项）
- `constraint_missed`：漏掉题干约束条件
- `careless_copying`：抄写/看错数字/看错符号
- `time_pressure_guess`：时间压力导致的跳步/猜测

## 与 step 的关系

- `error_step_index` 用于描述“卡在哪一步”（主判定）。
- `error_mode_enum` 用于描述“具体怎么错”（细分/加权）。

MVP 相似错误：优先 `procedure + step`；若 `error_mode_enum` 也相同，则判为更强重复。
