# Multi-Agent Academic Writing Pipeline（多代理学术写作流水线）

一套把学术写作拆成「**定模式 → 同步进度 → 独立规划 → 用户确认 → 成文 → 独立审计 → 文献落库**」闭环的多代理编排模板。用角色化子代理群把大纲与零散想法，加工成符合**目标产物标准**的可交付正文——**不预设学科，也不预设论文类型**，整套方法论可整体迁移到任意学科与任意写作场景。

## 三个大模式

同一套流水线，服务三种产物；**模式决定"达到什么标准"**（篇幅、结构单元、深度门槛、引注体系、读者身份、审计口径、台账粒度），流程环节本身不变。

| # | 模式 id | 产物 | 默认结构单元 | 常见篇幅 | 默认引注体系 | 评审口径 |
|---|---|---|---|---|---|---|
| 1 | `degree-thesis` | 学位论文（**本 / 硕 / 博**三档） | 章 → 节 | 1.5 万 / 4 万 / 8 万+ 字 | 顺序编码 `[n]` + GB/T 7714 | 盲审 / 答辩 |
| 2 | `journal-article` | 期刊论文 | 全篇 | 6 千 – 1.2 万字（**硬上限**） | **随目标期刊** | 匿名外审 / 编辑初审 |
| 3 | `course-paper` | 课程论文 | 题 → 论述段 | 2 千 – 8 千字 | 著者-年制（APA / Chicago） | 任课教师评分 |

模式细则：[`modes/_mode-overview.md`](modes/_mode-overview.md)（总表 + 决策树 + 配置规格）·
[`modes/degree-thesis.md`](modes/degree-thesis.md) ·
[`modes/journal-article.md`](modes/journal-article.md) ·
[`modes/course-paper.md`](modes/course-paper.md)（含本/硕/博三档的创新性门槛梯度）

三模式各有一套演示工作区：[`demo/degree-thesis/`](demo/degree-thesis/) ·
[`demo/journal-article/`](demo/journal-article/) · [`demo/course-paper/`](demo/course-paper/)

> ⚠️ **免责声明**：本仓库中的「导师」等角色为**虚构学术角色模板**，仅用于演示多代理写作编排方法，**不指向任何真实个人、机构或院校**。仓库内的研究主题、例文与全部文献条目均为**虚构占位**，非真实课题成果；请勿将其用于任何学术署名、查重或投稿用途。
>
> 本工具是**写作方法与流程的辅助框架**，不替代作者的独立研究与学术判断；使用 AI 辅助写作时请遵守所在机构的学术规范，并对最终文本负责。

## 目录结构

```
.
├── modes/                      # 【模式层】三个大模式的定义与配置规格
│   ├── _mode-overview.md       # 模式总表 + 选择决策树 + MODE.md 配置规格（先读这个）
│   ├── degree-thesis.md        # 模式 1：学位论文（本科/硕士/博士三档）
│   ├── journal-article.md      # 模式 2：期刊论文（含投稿与返修）
│   └── course-paper.md         # 模式 3：课程论文
├── prompts/
│   ├── system-prompt.md        # 主系统提示词（模板，含 <占位符>；不预设学科与模式）
│   └── roles/                  # 八个子代理角色的独立 prompt
│       ├── planner.md          # 规划专家
│       ├── writer.md           # 成文专家
│       ├── auditor.md          # 审计专家（第 4 维随模式改写）
│       ├── analyst.md          # 数据分析员（实证单元专用；与 librarian 对称）
│       ├── librarian.md        # 文献管理员（含 DOI 有效性核验）
│       ├── consistency.md      # 术语/一致性审查（第 5 维：测量与数据一致性）
│       ├── blind-review.md     # 评审预审（按模式模拟盲审专家/匿名审稿人/任课教师）
│       └── steward.md          # 结构与进度管家（台账粒度随模式）
├── docs/
│   ├── workflow.md             # 全流程协议（第〇步～第五步）+ 三模式差异对照
│   ├── data-pipeline.md        # 实证数据环节（数据可得性闸门/数据台账/结果落盘/测量口径）
│   ├── rewrite-protocol.md     # 改写协议与跨章依赖传播（改了这里，还有哪里要改）
│   ├── session-recovery.md     # 跨会话恢复协议（长文写作不丢状态）
│   ├── roles-matrix.md         # 角色职责速查 + 角色×模式对照 + 模型路由建议
│   ├── zotero-schema.md        # 文献库分类集合设计示例
│   └── customize-from-proposal.md  # 用开题报告自动定制提示词的作业单
├── scripts/                    # 工具脚本（Windows PowerShell，须为 UTF-8 with BOM）
│   ├── docx2md.ps1             # 第〇步：docx → markdown 进度快照（三模式通用）
│   ├── word-count.ps1          # 篇幅纪律：字数统计与配额核验（-Limit 硬上限 / -Min -Max 区间）
│   ├── citation-check.ps1      # 第五步：引用三对照机械核验（-Style numbered|author-date）
│   ├── check-figures.ps1       # 摘要自足性/结构化要素 + 图表编号引用完整性
│   ├── verify-doi.ps1          # DOI 有效性三级核验（格式/可解析/Crossref 元数据比对）
│   └── ledger-impact.ps1       # 改写影响分析：跨章依赖传播（依赖 LEDGER.md）
├── templates/                  # 部署产物模板（复制到"你的项目根目录"后替换占位符）
│   ├── MODE.md                 # 【最先复制】写作模式配置（所有角色的唯一口径来源）
│   ├── STATUS.md               # 进度台账（三模式的台账形态各有一节）
│   ├── LEDGER.md               # 论点与依赖台账（改写传播的依据）
│   ├── DATA.md                 # 数据台账（变量与测量口径；见 templates/data-ledger.md）
│   ├── data-ledger.md          # 数据台账模板（复制为 DATA.md）
│   ├── results.md              # 分析结果落盘模板（复制为 _分析结果_最新.md）
│   ├── abstract.md             # 摘要与关键词（三模式体例 + 自检清单）
│   ├── glossary.md             # 术语与概念口径基准（consistency 的锚）
│   ├── session-handoff.md      # 会话交接卡（每次会话结束前填写）
│   ├── citation-audit.md       # 引用三对照人工核对单（多引注体系）
│   ├── review-response.md      # 审稿意见应答表（期刊论文模式专用）
│   └── AGENTS.md               # Codex 项目指令（方式 A 的部署产物）
├── demo/                       # 演示工作区：项目根目录"应该长什么样"（虚构课题）
│   ├── degree-thesis/          # 学位论文模式（章节四态台账 + 字数预算偏差）
│   ├── journal-article/        # 期刊论文模式（版本台账 + 审稿意见应答表）
│   └── course-paper/           # 课程论文模式（题目清单 + 课程评分点对照）
├── plugins/                    # 学术检索插件（DeepSeek Harness 版）
│   ├── dsh-google-scholar/     # Google Scholar 检索（SerpAPI）
│   └── dsh-smartlib/           # SmartLib 中文期刊检索（CNKI/万方/维普）
└── examples/                   # 一次写作任务的输入输出样例（虚构演示）
```

---

# 自动部署协议（AI 可执行版）

> **给部署者（人或 AI Agent）的说明**：以下 6 个阶段可以**由 Agent 自动顺序执行**，也可人工照做。
> 每阶段末尾有 **✅ 验收** 条件——满足后才进入下一阶段。本协议假定部署者为：
> 一个能读写文件、执行 PowerShell 命令的 Agent（OpenAI Codex / DeepSeek Harness / Claude 均可），
> 工作目录为 `项目根/`（即你要写论文的目录，本仓库内容将复制到其中）。
>
> 执行前请先通读第 1 阶段，向用户确认决策点，再开始执行。

## 阶段 1：前置确认（需要用户拍板，先停下问清楚）

部署开始前，必须向用户确认以下事项，**不得擅自假设**：

| # | 确认项 | 默认建议 |
|---|---|---|
| 1.1 | **写作模式**：学位论文 `/` 期刊论文 `/` 课程论文？（**最关键——模式决定后续所有标准**） | 按 `modes/_mode-overview.md` 决策树提问确认，**判不准就提二选一问题，不得默认** |
| 1.2 | （模式 1 追加）**学位层次**：本科 / 硕士 / 博士？ | 决定篇幅与创新性门槛，判错会导致 planner 篇幅分配整体失准 |
| 1.3 | （模式 2 追加）**目标期刊 / 稿件类型 / 字数硬上限 / 引注体例**？ | 四项缺一不可——缺则 auditor 无法做"期刊适配"审计 |
| 1.4 | （模式 3 追加）**课程名 / 教师要求原文 / 评分点（rubric）**？ | 有 rubric 就逐条对齐，这是提分最直接的手段 |
| 1.5 | 宿主环境：Codex（方式 A）还是 DeepSeek Harness（方式 B）？可两者都装 | 用户有 DSH 则优先 B；否则 A |
| 1.6 | 课题信息从哪来？三选一：① 有开题报告文件（docx/pdf/md）→ 阶段 3A 自动定制；② 无报告但可现场回答问题 → 阶段 3B 访谈式定制；③ 都不想提供 → 阶段 3C demo 课题先部署 | 有开题报告最省力；①②③ 均不中断部署 |
| 1.7 | 稿件正文文件：用户将使用哪个 docx 作为主文件？文件当前是否被 Word 占用？ | 建议命名 `论文.docx` 放项目根 |
| 1.8 | 文献库：是否需要 Zotero 集成？插件用 Google Scholar / SmartLib 是否需要 API Key？ | 可后补，先部署骨架 |

确认后，向用户说明你将执行：**复制模板 → 定模式（生成 MODE.md）→ 定制提示词 → 搭台账 → 装入宿主 → 冒烟测试**。

## 阶段 2：复制本仓库为"项目根"

```powershell
# 在本仓库的上级目录执行：把整个仓库复制为项目根（示例名 my-thesis）
Copy-Item -Recurse ".\Multi-Agent-Academic-Writing-Pipeline" ".\my-thesis"
cd ".\my-thesis"
# 若已有 git：移除模板仓库的 .git，按需重新 git init（或保留以便 fork 跟踪上游）
```

✅ 验收：目录含 `modes/` `prompts/` `docs/` `scripts/` `templates/` `demo/` `plugins/`；`pwd` 显示在项目根。

## 阶段 3：定模式 + 定制系统提示词（三级路径，任何情形都不中断）

### 3.0 定模式并生成 MODE.md（**必须在定制提示词之前**）

按阶段 1.1–1.4 的确认结果，把 `templates/MODE.md` 复制到项目根并填写。**填完请用户确认一次**——
模式填错会导致整条流水线的标准失准（例如用学位论文的标准写课程论文）。

```powershell
Copy-Item templates\MODE.md MODE.md   # 然后按确认结果填写 mode / level / discipline / 字数 / 引注 / 评审口径
```

✅ 验收：项目根 `MODE.md` 存在，`mode` 与 `level` 已由用户确认；期刊/课程模式的必填项已补齐。

> 决策（按 1.6）：有开题报告 → 3A（全自动）；无报告但对方愿回答问题 → 3B（访谈式，一问一答即可）；
> 既无报告又不愿访谈 → 3C（demo 课题先跑通，日后换肤）。完整作业单见
> [`docs/customize-from-proposal.md`](docs/customize-from-proposal.md)（含两种模式）。

### 3A. 有开题报告 → 自动定制（最省力）

把开题报告文件放入项目根，然后**把 `docs/customize-from-proposal.md` 中的模式一作业单全文**作为指令发给 Agent
（或直接告诉 Agent："按 docs/customize-from-proposal.md 模式一执行"）。Agent 将自动：

1. 先定模式并生成 `MODE.md`（含期刊/课程模式的必填项确认）；
2. 通读开题报告（docx 则先跑 `scripts/docx2md.ps1` 转 md）；
3. 提取：研究主题、问题意识、理论框架、大纲结构、术语清单；
4. 改写 `prompts/system-prompt.md` 的「底层学术画像」等占位段落（同构句式已写在模板括号内）；
5. 把定制结果写入三份产物：项目根 `MODE.md`、项目根 `AGENTS.md`（方式 A 用）与 `prompts/system-prompt.md`。

### 3B. 无开题报告 → 访谈式定制（Agent 主动提问，无需任何文档）

让 Agent 执行 `docs/customize-from-proposal.md` **模式二作业单**：它一次问 1 个问题（共约 11 个：
**模式与档位**、题目、学科、批判的问题意识、理论框架、机制模型、章节、术语、语言篇幅、文件名、偏好），
对方口头或打字回答即可；答不上来的项 Agent 按 demo 示例给出占位建议并标注"⚠️ 待确认"。
问答结束 Agent 一次性完成与 3A 相同的改写与写回。

### 3C. 既无开题报告又不愿访谈 → demo 课题先部署（兜底）

直接用模板自带的 demo 虚构课题完成部署（阶段 4-6 照常执行，冒烟测试用 demo 数据）——
**按拟用模式选对应那套 demo**（`demo/degree-thesis/`、`demo/journal-article/`、`demo/course-paper/`），
整条流水线先验证可用；日后拿到课题信息，重跑 3A 或 3B 即可"换肤"，无需重新部署。

✅ 验收（3A/3B/3C 通用）：`MODE.md` 已填且模式经用户确认；`Select-String -Path prompts/system-prompt.md -Pattern '<'` 仅剩允许的少量占位
（如 `<研究课题>` 等）；通读一遍确认画像与课题一致（3C 阶段允许为 demo 课题，标注待换肤）。

## 阶段 4：搭台账骨架（把 templates 复制到项目根）

```powershell
Copy-Item templates\STATUS.md, templates\glossary.md, templates\session-handoff.md, templates\citation-audit.md -Destination .
# 期刊论文模式另需：Copy-Item templates\review-response.md -Destination .
```

✅ 验收：项目根出现 `MODE.md` `STATUS.md` `glossary.md` `session-handoff.md` `citation-audit.md`
（期刊论文模式另有 `review-response.md`；templates/ 与 demo/ 内的同名文件保留不动）。
这些文件**含真实课题信息，已被 .gitignore 排除，不会误推公开仓库**。

## 阶段 5：装入宿主（按 1.5 的选择执行 A 或 B，可都做）

### 方式 A：OpenAI Codex

**A1. 放置 AGENTS.md（Codex 自动读取的项目指令）**

- 若 3A 已生成 → 确认项目根 `AGENTS.md` 存在；
- 若 3B → 把 `templates/AGENTS.md` 复制到项目根并替换 `<占位符>`：
  ```powershell
  Copy-Item templates\AGENTS.md AGENTS.md   # 然后编辑替换 <研究课题题目> 等
  ```
- AGENTS.md 会引导 Codex 依次读取 `MODE.md`、`prompts/system-prompt.md`、`prompts/roles/*.md`、`docs/workflow.md` 等。

**A2.（可选增强）注册七个 Codex Subagents**

参考 [Codex Subagents 官方文档](https://developers.openai.com/codex/subagents)，
把 `prompts/roles/*.md` 的内容分别作为八个 subagent 的指令体（planner/writer/auditor/analyst/librarian/
consistency/blind-review/steward），项目内建 `.codex/` 目录存放。

**A3. 检索插件（Codex 版）**

`plugins/` 是 DSH 插件格式，不适用于 Codex。需要检索时，让 Codex 读取 `plugins/*/lib/index.js`
理解调用逻辑后**重写为 Codex 代码版工具**（密钥用环境变量，如 `SERPAPI_KEY`，不写死在代码中）。

✅ 验收：项目根存在 `AGENTS.md` 且占位符已替换；（若做 A2）`.codex/` 下八个 subagent 定义齐全。
在项目根运行 `codex`，应能按 AGENTS.md 开场白回应（steward 视角汇报"当前模式 + 状态"）。

### 方式 B：DeepSeek Harness（DSH）

**B1. 装入主提示词**

```powershell
# 项目根建 .dsh 目录，把定制后的系统提示词装为 .dsh/prompt.md
New-Item -ItemType Directory -Force .dsh | Out-Null
Copy-Item prompts\system-prompt.md .dsh\prompt.md
```

**B2. 绑定模型路由**

在 DSH 的 settings.yaml 中为八个角色绑定 provider/model（档位建议见 `docs/roles-matrix.md`，
含**按模式调整资源投入**的建议；参考 [dsh-plugin-subagent-director](https://github.com/SeverusZh/dsh-plugin-subagent-director) 的做法）。

**B3. 安装检索插件**

把 `plugins/dsh-google-scholar` 与 `plugins/dsh-smartlib` 放入你的 DSH 插件目录
（或直接让 DSH 的 AI 执行安装）。安装后补齐 `cordis.patch.yml` 的配置：

- Google Scholar：`serpapi_key` ← 在 <https://serpapi.com/> 注册获取；
- SmartLib：`gateway_url` / `gateway_secret` / `emails` ← 参考
  <https://skillhub.cloud.tencent.com/skills/user_164f4c1f/smartlib-citation-checker>；
- 手动安装：`dsh plugin --profile web add link:C:/<路径>/plugins/dsh-google-scholar`

✅ 验收：`.dsh/prompt.md` 存在且为定制后内容；`dsh plugin list` 可见两插件；
模型路由绑定无报错。在 DSH 中打开项目目录，会话应加载 `.dsh/prompt.md` 并按协议工作。

## 阶段 6：冒烟测试（验证部署成功）

按宿主执行以下最小任务，确认流水线关键闸门可用：

1. **脚本自测**（Windows）：在项目根执行
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\docx2md.ps1 -DocxPath "论文.docx"
   # 字数配额核验（须与 MODE.md 的 target_length / word_limit_hard 一致）：
   #   期刊模式（硬上限）：
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\word-count.ps1 -TextPath demo\journal-article\稿件_v3_节选.md -Limit 12000 -ExcludeRef
   #   课程模式（区间）：
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\word-count.ps1 -TextPath demo\course-paper\课程论文_正文.md -Min 3000 -Max 5000 -ExcludeRef
   # 引注核验须与 MODE.md 的 citation_style 一致：
   #   numeric 模式（学位论文/部分期刊）：
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\citation-check.ps1 -TextPath demo\degree-thesis\第三章第二节_正文.md -Style numbered
   #   author-date 模式（课程论文/部分社科期刊）：
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\citation-check.ps1 -TextPath demo\course-paper\课程论文_正文.md -Style author-date
   ```
   预期：`docx2md` 输出快照（若 docx 被占用会提示解锁）；`word-count` 报出字数与配额判定
   （课程样例会**如实报"低于下限"**——它是压缩版示例）；`citation-check` 报告"机械核对通过"。
   ```powershell
   # 摘要 + 图表编号（期刊样例摘要 270 字，应通过）
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-figures.ps1 -TextPath demo\journal-article\稿件_v3_节选.md -MaxAbstract 300 -AbstractSections "目的,方法,结果,结论"
   # DOI 三级核验（离线即验证格式，联网另验可解析性）
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-doi.ps1 -TextPath demo\journal-article\稿件_v3_节选.md -Offline
   # 依赖台账自检（悬空引用 / 孤立论点 / 循环依赖）
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ledger-impact.ps1 -Ledger templates\LEDGER.md
   ```
   > ⚠️ `scripts/` 下的**全部脚本**须为 **UTF-8 with BOM**，否则 Windows PowerShell 5.1 会按 ANSI 解析中文而报语法错。
   > 校验：`node -e "const fs=require('node:fs');for(const f of fs.readdirSync('scripts').filter(x=>x.endsWith('.ps1'))){const b=fs.readFileSync('scripts/'+f);console.log((b[0]===0xEF&&b[1]===0xBB&&b[2]===0xBF?'OK  ':'缺失'),f)}"`
2. **模式自测**：让主代理读 `MODE.md` 并复述"本项目模式 / 档位 / 字数标准 / 引注体系 / 评审口径"。
   预期：五项全部答对，且**不把其他模式的标准混进来**。若答错或含糊，视为模式配置未生效，需检查 MODE.md 与提示词装载。
3. **流水线自测**：给主代理一条指令，如：
   > 请先按 session-recovery 协议汇报当前模式与进度，然后为"结构中第一个待写单元"做一份写作规划，交我确认。
   
   预期响应结构：① 先读 MODE.md + STATUS/glossary/handoff，汇报"**当前模式** + 状态"（steward 视角）→
   ② 产出规划报告 → ③ **停下等待用户确认**（不得直接开写）。
   若 Agent 未经确认直接写正文，视为部署失败，需重装提示词。

✅ 全部通过 = 部署完成。日常使用请遵循 `docs/workflow.md`；每次新会话按 `docs/session-recovery.md` 恢复。

---

## 核心思想（为什么这么设计）

单代理一口气写论文的常见失败模式：缺少中期检查、文献不可信、风格前后漂移、交稿才发现论证漏洞。
本模板把这些质量环节**外置为独立子代理**，形成互相制衡的流水线：

```
用户指令
   │
   ▼
┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐
│  planner   │──▶│  用户确认  │──▶│   writer   │──▶│  auditor   │
│ 规划专家   │   │ (硬性闸门) │   │  成文专家  │   │  审计专家  │
└───────────┘   └───────────┘   └───────────┘   └───────────┘
                                                      │ 审计通过?
                                                      ▼
                                     ┌───────────────┬───────────────┐
                                     ▼               ▼               ▼
                              ┌───────────┐   ┌───────────┐   ┌───────────┐
                              │consistency│   │blind-review│  │ librarian │
                              │术语+测量   │   │ 评审预审   │  │ 文献落库   │
                              └───────────┘   └───────────┘   └───────────┘

前置（仅实证单元）：analyst —— 数据可得性闸门 / 结果落盘
改写（非从零）：     ledger-impact.ps1 —— 依赖传播，算出还有哪些节要改
```

**为什么是八个角色**：原先的七个角色覆盖了「文献 → 论证 → 写作」，
但**没有任何角色负责数据**——含实证单元的稿件因此断在"结果章写不出来"或"硬编数据"。
`analyst` 补上这一环，与 `librarian` 对称：一个管文献，一个管数据。

设计要点：

- **模式先行**：所有标准来自项目根 `MODE.md`，而不是写死在提示词里——同一套流水线因此能服务
  学位论文、期刊论文与课程论文三种产物，且标准可一处切换、全局生效；
- **用户确认是硬闸门**：规划不通过，绝不动笔；审计不通过，绝不交付——质量把关不在主代理的"自觉"，而在流程结构；
- **交叉验证**：规划者、写作者、审计者是不同视角的不同角色，避免"自己写自己审"的同温层；
- **滚动一致性**：每节完成后与"此前全部已写内容"及 `glossary.md` 做术语/口径比对，专治章节间论点断裂；
- **文献全链路**：规划检索 → 写作引用 → 独立核验落库 → 交付前三对照核验，杜绝"编造文献"与"引注失配"；
- **摘要全程传递**：文献池 `_文献池_最新.md` 机制杜绝"凭题名猜内容"的张冠李戴（见 `examples/02-走查图文说明.md` 的缺陷复盘）；
- **台账承载状态**：MODE/STATUS/glossary/handoff 四件套 + 跨会话恢复协议，长文写作不丢状态、不漂口径、不错标准。

## 模式如何改变标准（速查）

| 维度 | degree-thesis | journal-article | course-paper |
|---|---|---|---|
| auditor 第 4 维 | 盲审标准（含本/硕/博创新性门槛） | 审稿人口径（含**期刊适配**与字数合规） | 课程评分点（**不得以创新性不足退回**） |
| blind-review 模拟谁 | 盲审专家（本节+此前全部章节**滚动**预审） | 匿名审稿人 | 任课教师（通常只跑一次） |
| 字数性质 | 预算（报偏差，>20% 须上报） | **硬上限**（超限即"需修订"） | 区间（取中下位，宁短勿长） |
| 台账粒度 | 章节四态 + 字数偏差 | **稿件版本** + 审稿应答表 | 题目清单 |
| 目录同步 / 编号防错 | **必须** | 不需要 | 不需要 |
| 引注默认 | `[n]` + GB/T 7714 | 随目标期刊 | 著者-年制 |
| 特有工件 | 字数预算表、大纲、目录同步 | 版本台账、审稿意见应答表、投稿信 | 课程要求对照自查表 |

> 完整对照见 `docs/workflow.md` 末节与 `docs/roles-matrix.md`。

## 迁移到其他学科

**本模板不预设学科。** 学科只影响三件事：术语体系、文献分布、理论/方法的形态。

把 `prompts/system-prompt.md` 中「研究课题的底层学术画像」整段替换即可（或走阶段 3A 自动定制）：

```
核心问题意识： 批判既有研究的什么局限 → 本文要攻克的什么具体问题 → 该问题为何值得研究
核心理论/方法： 按学科填写 1-2 个核心理论/框架，或核心方法路线
               · 文科常见：概念框架 + 机制/分析模型
               · 理工医常见：数学模型 + 实验/试验设计
               · 人文常见：核心范畴 + 文本/史料分析路径
整体结构：     以稿件文件为准
```

**注意**：不要套用其他学科的理论章写法——文科的"理论框架章"、理工科的"方法章"、
人文的"文献考据章"形态差异很大，planner 与 writer 须按本学科惯例执行。

## 许可

[CC BY-SA 4.0](LICENSE)（署名—相同方式共享）。prompts/、docs/、examples/、plugins/ 全部内容均适用。
插件代码中如引用了第三方服务的接口语义（SerpAPI、SmartLib/SkillHub），相关权利归原服务方所有。
