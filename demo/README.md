# demo/ — 演示工作区（项目根目录应长什么样）

> 本目录模拟**已经按本流水线运行了一段时间**的写作项目根目录，展示各台账工件实际填好后的形态。
> 复制本仓库做新项目时，把对应模式的 demo 工件（STATUS.md、glossary.md、session-handoff.md、
> MODE.md）拷到你的项目根目录，按你的课题重填即可。
>
> **所有示例课题、文献与数据均为虚构**，仅演示流程形态与工件结构，不可当作真实学术内容引用。

## 三个模式各有一套演示

对应 `modes/` 下的三个大模式。**上手时先看你所属模式的那一套**——三套的台账粒度、
引注体系和工件清单都不同，这正是"模式决定流程标准"的直观体现。

| 目录 | 模式 | 演示课题（虚构） | 引注体系 | 台账粒度 | 特有工件 |
|---|---|---|---|---|---|
| `degree-thesis/` | 学位论文（硕士档） | 城市社区居家养老服务供需匹配机制研究 | 顺序编码 `[n]` + GB/T 7714 | 章节四态 | 字数预算偏差表、目录同步状态 |
| `journal-article/` | 期刊论文 | 睡眠时长与青少年学业表现的关系 | 顺序编码 `[n]`（随目标期刊） | 稿件版本 | 版本台账、**审稿意见应答表** |
| `course-paper/` | 课程论文 | 社交媒体使用与大学生注意力 | 著者-年制（APA 7th） | 题目清单 | 课程评分点对照表 |

## 各套演示包含什么

### `degree-thesis/` — 学位论文模式

| 文件 | 对应模板 | 说明 |
|---|---|---|
| `STATUS.md` | `templates/STATUS.md` | 章节四态台账 + **字数预算偏差**（学位论文特有）+ **目录同步状态** |
| `glossary.md` | `templates/glossary.md` | 术语译名与概念定义登记示例 |
| `session-handoff.md` | `templates/session-handoff.md` | 交接卡已填示例 |
| `第三章第二节_正文.md` | — | 一节"已交付正文"样例（含 `[n]` 引注与文末 GB/T 7714 参考文献） |
| `大纲.md` | — | 论文大纲（节选），演示目录文件如何组织 |

### `journal-article/` — 期刊论文模式

| 文件 | 对应模板 | 说明 |
|---|---|---|
| `STATUS.md` | `templates/STATUS.md` | **稿件版本台账**（v1→v4）+ 字数 vs **硬上限** + 审稿应答进度 |
| `glossary.md` | `templates/glossary.md` | 含"摘要—正文—结论三处口径一致"的贡献表述备忘 |
| `session-handoff.md` | `templates/session-handoff.md` | 返修阶段的交接卡（含字数余量提醒） |
| `稿件_v3_节选.md` | — | 稿件形态样例：标题、结构化摘要、关键词、`[n]` 引注、期刊体例参考文献 |
| `审稿意见应答表.md` | `templates/review-response.md` | **期刊模式特有**：3 位审稿人 11 条意见的逐条应答（含"说明理由"的正确写法） |

### `course-paper/` — 课程论文模式

| 文件 | 对应模板 | 说明 |
|---|---|---|
| `STATUS.md` | `templates/STATUS.md` | 题目/段落清单 + **课程要求原文** + **评分点 rubric 对照** |
| `glossary.md` | `templates/glossary.md` | 含"课程理论口径登记"（课程模式特有核对项） |
| `session-handoff.md` | `templates/session-handoff.md` | 轻量交接卡 |
| `课程论文_正文.md` | — | 正文样例：著者-年制引注、字母序参考文献、与课程理论的显式咬合 |

## 从 demo 到你的项目

1. **先定模式**：读 `modes/_mode-overview.md` 的决策树，确定你属于哪个模式；
2. 把该模式 demo 目录下的工件拷到你的项目根目录，按你的课题重填
   （或让 Agent 用 `docs/customize-from-proposal.md` 的作业单代填）；
3. 在项目根生成 `MODE.md`（模板 `templates/MODE.md`）——**这是所有角色的唯一口径来源**；
4. 开始写作后，每次任务前后让 steward 更新 STATUS.md，每会话结束填 handoff。

> 跨会话如何恢复、各工件何时更新，见 `docs/session-recovery.md`。
> 想对照看**一次完整流水线的输入输出**，见 `examples/01-流水线样例.md`。
