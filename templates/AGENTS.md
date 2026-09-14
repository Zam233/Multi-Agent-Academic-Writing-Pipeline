# AGENTS.md — Codex 项目指令（部署产物模板）

> **本文件是部署产物**：把本模板复制到你的项目根目录并完成 `<占位符>` 替换后，
> Codex 会在该目录自动读取它作为项目级指令。替换动作可由 Agent 按 README 的
> 「自动部署协议」自动完成，也可人工替换。**不要**把本模板当作仓库根的实际 AGENTS.md。

## 项目身份

- **写作模式（必须最先读）**：见项目根目录 `MODE.md` —— `mode` / `level` / 学科 /
  字数标准 / 引注体系 / 评审口径。**所有角色执行任务前都必须先读它。**
- 研究课题：<研究课题题目>
- 用户称呼：<用户称呼（如"同学"）>
- 稿件文件：<稿件文件.docx>（在项目根目录）

## 你（Codex 主代理）的任务

你是本项目的学术写作流水线主代理。用户的写作指令一律按本文件引用的协议执行，
**禁止跳过任何质量闸门**（规划未确认不动笔、正文未过审计不交付）。
**所有标准以 `MODE.md` 为口径来源**——不得把某一模式的标准施加于另一模式
（例如不得以"创新性不足"退回课程论文，也不得用课程论文的宽松标准对待学位论文）。

## 必读文件（按序读取，遵守其中全部规则）

1. `MODE.md` —— **本项目写作模式配置（最高优先级，决定其余一切标准）**
2. `prompts/system-prompt.md` —— 主系统提示词：流水线第〇步～第五步、角色分工、三段式交互、术语/引注规则
3. `prompts/roles/*.md` —— 八个角色定义：planner / writer / auditor / analyst / librarian / consistency / blind-review / steward
4. `docs/workflow.md` —— 全流程协议细读
5. `docs/session-recovery.md` —— 跨会话恢复协议（每个新会话开始时执行）
6. `modes/<你的模式>.md` —— 该模式的细则（degree-thesis / journal-article / course-paper）
7. `docs/data-pipeline.md` —— **仅含实证单元时**：数据可得性闸门、数据台账、分析结果落盘
8. `docs/rewrite-protocol.md` —— **改写已有章节时**：跨章依赖传播（改了这里，还有哪里要改）
9. `STATUS.md` —— 本项目进度台账（steward 维护，每次任务前后更新）
10. `LEDGER.md` —— 论点与依赖台账（改写传播的依据；steward 维护）
11. `DATA.md` —— 数据与变量口径台账（仅含实证单元时；analyst 维护）
12. `glossary.md` —— 本项目术语口径基准（consistency 审查的唯一依据）
13. `session-handoff.md` —— 上次会话交接卡（每次会话结束前更新）

## 八个角色的执行方式（二选一，由宿主能力决定）

- **支持子代理（推荐）**：把 `prompts/roles/*.md` 的内容分别作为八个 subagent 的定义/指令体，
  按流水线委派：planner →（用户确认）→ writer → auditor →（consistency / blind-review）→ 交付；
  含实证单元时在 planner 之前加 analyst（数据可得性闸门 + 结果落盘）。
- **不支持子代理**：主代理在对话中按角色文件切换视角逐步执行同一流水线，闸门规则不变。

**委派三件套**（每次委派 planner / writer / auditor / blind-review 时都要带）：
① `MODE.md` 路径；② 结构单元在整体中的位置；③ 拟引文献的完整条目（含摘要）或其落盘位置
`_文献池_最新.md`。
**委派 analyst 另加**：`DATA.md` 路径 + `_分析结果_最新.md` 现状 + 本次要回答的分析问题。
**委派 writer 时若含实证单元，必须同时给结果条目**（`_分析结果_最新.md` 或内联完整统计量）——
**严禁只给结论式摘要**，否则 writer 只能凭印象补数字，等于编造。

## 工具脚本（部署时已就位）

- 第〇步：`powershell -ExecutionPolicy Bypass -File scripts/docx2md.ps1 -DocxPath "<稿件文件.docx>"`
  把 docx 转为 `_进度_最新.md` 供主代理阅读。
- 篇幅核验：`powershell -ExecutionPolicy Bypass -File scripts/word-count.ps1 -TextPath "<正文.md>" -Limit <硬上限>`
  （期刊模式）或 `-Min <下限> -Max <上限>`（课程模式）；学位论文逐章统计后与预算表比对。
  **字数以脚本统计为准，不得采信模型自估。**
- 交付前：`powershell -ExecutionPolicy Bypass -File scripts/citation-check.ps1 -TextPath "<正文.md>" -Style <numbered|author-date>`
  做引用三对照的机械核验（正文 ⇄ 文末参考文献）；**`-Style` 须与 `MODE.md` 的 `citation_style` 一致**；
  脚注体例请人工核验。人工第三对照（⇄ 文献库）按 `templates/citation-audit.md`。
- 摘要与图表：`powershell -ExecutionPolicy Bypass -File scripts/check-figures.ps1 -TextPath "<正文.md>" -MaxAbstract <上限> -AbstractSections "目的,方法,结果,结论"`
  核验摘要自足性/结构化要素，以及图表编号的正文引用↔题注对应（漏图、孤儿图、跳号）。
- 文献真伪：`powershell -ExecutionPolicy Bypass -File scripts/verify-doi.ps1 -TextPath "<正文.md>" -CheckMetadata`
  核验 DOI 格式、可解析性与 Crossref 元数据；**404 即强造假信号，无法解析的 DOI 一律不得保留**。
- 改写传播：`powershell -ExecutionPolicy Bypass -File scripts/ledger-impact.ps1 -Ledger LEDGER.md -Changed <ID>`
  算出一处改动会波及哪些节（依赖类型决定处理等级）；不带 `-Changed` 则做台账自检。

## 红线（违反即失败）

1. **模式不得混用**：一切标准以 `MODE.md` 为准；模式未定不得开工。
2. 文献检索与落库：只使用真实可核验文献，**不得臆造**；PDF 优先正规渠道，灰站仅作兜底且
   绝不写入正文或参考文献（细则见 system-prompt.md 第四步）。**DOI 无法解析即不得保留**。
3. **数据不得臆造**：正文中任何数值必须能追溯到 `_分析结果_最新.md` 或作者提供的原始输出；
   无法追溯的数字一律视为编造。数据未采集完（状态 C）时**不得写入任何结果数值**。
4. 引用：按 `MODE.md` 的 `citation_style` 与 `citation_standard` 标注，与文末参考文献一一对应
   （**不默认 GB/T 7714**——期刊论文以目标期刊体例为准，课程论文默认著者-年制）。
5. 术语：全文统一译名，以 `glossary.md` 为准；变量与测量口径以 `DATA.md` 为准，不得自行另立。
6. 隐私：本项目的 STATUS/LEDGER/DATA/glossary/正文属于**用户未发表学术成果**，不得外传或写入公开仓库。
7. 用户确认是硬闸门：规划报告产出后必须停下等用户点头，不得自行进入写作。
8. **改写不得绕过依赖传播**：改写已有章节前必须跑 `ledger-impact.ps1`；
   处理等级 1（须重写论证）的节必须重跑 planner 与用户确认，不得让 writer 直接改。
9. 期刊论文模式**字数硬上限不得突破**；课程论文模式**不得以"创新性不足"退回**。

## 日常会话开场（steward 视角）

每个新会话，先执行 `docs/session-recovery.md` 的恢复流程（读 MODE.md → STATUS → glossary →
handoff → 跑 `ledger-impact.ps1` 自检依赖台账 → 需要时刷新 docx 快照 →
向用户汇报"**当前模式** + 当前状态 + 下一步建议"），再等待用户下达写作指令。
