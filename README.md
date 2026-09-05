# Multi-Agent Academic Writing Pipeline（多代理学术写作流水线）

一套把学位论文正文写作拆成「**同步进度 → 独立规划 → 用户确认 → 成文 → 独立审计 → 文献落库**」闭环的多代理编排模板。以虚构的公共管理课题《城市社区居家养老服务供需匹配机制研究》为演示案例，展示如何用角色化子代理群把大纲与零散想法，加工成达到盲审质量的学术正文——整套方法论可整体迁移到任意学科课题。

> ⚠️ **免责声明**：本仓库中的「导师」等角色为**虚构学术角色模板**，仅用于演示多代理写作编排方法，**不指向任何真实个人、机构或院校**。仓库内的研究主题、例文与全部文献条目均为**虚构占位**，非真实课题成果；请勿将其用于任何学术署名、查重或投稿用途。
>
> 本工具是**写作方法与流程的辅助框架**，不替代作者的独立研究与学术判断；使用 AI 辅助写作时请遵守所在机构的学术规范，并对最终文本负责。

## 目录结构

```
.
├── prompts/
│   ├── system-prompt.md        # 主系统提示词（模板，含 <占位符>）
│   └── roles/                  # 七个子代理角色的独立 prompt
│       ├── planner.md          # 规划专家
│       ├── writer.md           # 成文专家
│       ├── auditor.md          # 审计专家
│       ├── librarian.md        # 文献管理员
│       ├── consistency.md      # 术语与一致性审查（以 glossary.md 为基准）
│       ├── blind-review.md     # 盲审预审
│       └── steward.md          # 大纲与进度管家（维护 STATUS.md / 会话交接）
├── docs/
│   ├── workflow.md             # 全流程协议（第〇步～第五步）
│   ├── session-recovery.md     # 跨会话恢复协议（长文写作不丢状态）
│   ├── roles-matrix.md         # 角色职责速查 + 模型路由建议
│   ├── zotero-schema.md        # 文献库分类集合设计示例
│   └── customize-from-proposal.md  # 用开题报告自动定制提示词的作业单
├── scripts/                    # 工具脚本（Windows PowerShell，须为 UTF-8 with BOM）
│   ├── docx2md.ps1             # 第〇步：docx → markdown 进度快照
│   └── citation-check.ps1      # 第五步：引用三对照机械核验（正文⇄文末）
├── templates/                  # 部署产物模板（复制到"你的项目根目录"后替换占位符）
│   ├── STATUS.md               # 进度台账（steward 维护）
│   ├── glossary.md             # 术语与概念口径基准（consistency 的锚）
│   ├── session-handoff.md      # 会话交接卡（每次会话结束前填写）
│   ├── citation-audit.md       # 引用三对照人工核对单
│   └── AGENTS.md               # Codex 项目指令（方式 A 的部署产物）
├── demo/                       # 演示工作区：项目根目录"应该长什么样"（虚构课题）
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
> 执行前请先通读第 1 阶段，向用户确认两个决策点，再开始执行。

## 阶段 1：前置确认（需要用户拍板，先停下问清楚）

部署开始前，必须向用户确认以下事项，**不得擅自假设**：

| # | 确认项 | 默认建议 |
|---|---|---|
| 1.1 | 宿主环境：Codex（方式 A）还是 DeepSeek Harness（方式 B）？可两者都装 | 用户有 DSH 则优先 B；否则 A |
| 1.2 | 课题信息从哪来？三选一：① 有开题报告文件（docx/pdf/md）→ 阶段 3A 自动定制；② 无报告但可现场回答问题 → 阶段 3B 访谈式定制；③ 都不想提供 → 阶段 3C demo 课题先部署 | 有开题报告最省力；①②③ 均不中断部署 |
| 1.3 | 论文正文文件：用户将使用哪个 docx 作为主文件？文件当前是否被 Word 占用？ | 建议命名 `论文.docx` 放项目根 |
| 1.4 | 文献库：是否需要 Zotero 集成？插件用 Google Scholar / SmartLib 是否需要 API Key？ | 可后补，先部署骨架 |

确认后，向用户说明你将执行：**复制模板 → 定制提示词 → 搭台账 → 装入宿主 → 冒烟测试**。

## 阶段 2：复制本仓库为"项目根"

```powershell
# 在本仓库的上级目录执行：把整个仓库复制为项目根（示例名 my-thesis）
Copy-Item -Recurse ".\Multi-Agent-Academic-Writing-Pipeline" ".\my-thesis"
cd ".\my-thesis"
# 若已有 git：移除模板仓库的 .git，按需重新 git init（或保留以便 fork 跟踪上游）
```

✅ 验收：目录含 `prompts/` `docs/` `scripts/` `templates/` `demo/` `plugins/`；`pwd` 显示在项目根。

## 阶段 3：定制系统提示词（三级路径，任何情形都不中断）

> 决策：有开题报告 → 3A（全自动）；无报告但对方愿回答问题 → 3B（访谈式，一问一答即可）；
> 既无报告又不愿访谈 → 3C（demo 课题先跑通，日后换肤）。完整作业单见
> [`docs/customize-from-proposal.md`](docs/customize-from-proposal.md)（含两种模式）。

### 3A. 有开题报告 → 自动定制（最省力）

把开题报告文件放入项目根，然后**把 `docs/customize-from-proposal.md` 中的模式一作业单全文**作为指令发给 Agent
（或直接告诉 Agent："按 docs/customize-from-proposal.md 模式一执行"）。Agent 将自动：

1. 通读开题报告（docx 则先跑 `scripts/docx2md.ps1` 转 md）；
2. 提取：研究主题、问题意识、理论框架、大纲结构、术语清单；
3. 改写 `prompts/system-prompt.md` 的「底层学术画像」等占位段落（同构句式已写在模板括号内）；
4. 把定制结果写入两份产物：项目根 `AGENTS.md`（方式 A 用）与 `prompts/system-prompt.md`。

### 3B. 无开题报告 → 访谈式定制（Agent 主动提问，无需任何文档）

让 Agent 执行 `docs/customize-from-proposal.md` **模式二作业单**：它一次问 1 个问题（共约 10 个：
题目/学科/批判的问题意识/理论框架/机制模型/章节/术语/语言篇幅/文件名/偏好），
对方口头或打字回答即可；答不上来的项 Agent 按 demo 示例给出占位建议并标注"⚠️ 待确认"。
问答结束 Agent 一次性完成与 3A 相同的改写与写回。

### 3C. 既无开题报告又不愿访谈 → demo 课题先部署（兜底）

直接用模板自带的 demo 虚构课题完成部署（阶段 4-6 照常执行，冒烟测试用 demo 数据），
整条流水线先验证可用；日后拿到课题信息，重跑 3A 或 3B 即可"换肤"，无需重新部署。

✅ 验收（3A/3B/3C 通用）：`Select-String -Path prompts/system-prompt.md -Pattern '<'` 仅剩允许的少量占位
（如 `<研究课题>` 等）；通读一遍确认画像与课题一致（3C 阶段允许为 demo 课题，标注待换肤）。

## 阶段 4：搭台账骨架（把 templates 复制到项目根）

```powershell
Copy-Item templates\STATUS.md, templates\glossary.md, templates\session-handoff.md, templates\citation-audit.md -Destination .
```

✅ 验收：项目根出现 `STATUS.md` `glossary.md` `session-handoff.md` `citation-audit.md` 四个文件
（templates/ 与 demo/ 内的同名文件保留不动）。这些文件**含真实课题信息，已被 .gitignore 排除，不会误推公开仓库**。

## 阶段 5：装入宿主（按 1.1 的选择执行 A 或 B，可都做）

### 方式 A：OpenAI Codex

**A1. 放置 AGENTS.md（Codex 自动读取的项目指令）**

- 若 3A 已生成 → 确认项目根 `AGENTS.md` 存在；
- 若 3B → 把 `templates/AGENTS.md` 复制到项目根并替换 `<占位符>`：
  ```powershell
  Copy-Item templates\AGENTS.md AGENTS.md   # 然后编辑替换 <研究课题题目> 等
  ```
- AGENTS.md 会引导 Codex 读取 `prompts/system-prompt.md`、`prompts/roles/*.md`、`docs/workflow.md` 等。

**A2.（可选增强）注册七个 Codex Subagents**

参考 [Codex Subagents 官方文档](https://developers.openai.com/codex/subagents)，
把 `prompts/roles/*.md` 的内容分别作为七个 subagent 的指令体（planner/writer/auditor/librarian/
consistency/blind-review/steward），项目内建 `.codex/` 目录存放。

**A3. 检索插件（Codex 版）**

`plugins/` 是 DSH 插件格式，不适用于 Codex。需要检索时，让 Codex 读取 `plugins/*/lib/index.js`
理解调用逻辑后**重写为 Codex 代码版工具**（密钥用环境变量，如 `SERPAPI_KEY`，不写死在代码中）。

✅ 验收：项目根存在 `AGENTS.md` 且占位符已替换；（若做 A2）`.codex/` 下七个 subagent 定义齐全。
在项目根运行 `codex`，应能按 AGENTS.md 开场白回应（steward 视角汇报状态）。

### 方式 B：DeepSeek Harness（DSH）

**B1. 装入主提示词**

```powershell
# 项目根建 .dsh 目录，把定制后的系统提示词装为 .dsh/prompt.md
New-Item -ItemType Directory -Force .dsh | Out-Null
Copy-Item prompts\system-prompt.md .dsh\prompt.md
```

**B2. 绑定模型路由**

在 DSH 的 settings.yaml 中为七个角色绑定 provider/model（档位建议见 `docs/roles-matrix.md`；
参考 [dsh-plugin-subagent-director](https://github.com/SeverusZh/dsh-plugin-subagent-director) 的做法）。

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
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\citation-check.ps1 -TextPath demo\第三章第二节_正文.md
   ```
   预期：前者输出快照（若 docx 被占用会提示解锁），后者报告"机械核对通过"。
2. **流水线自测**：给主代理一条指令，如：
   > 请先按 session-recovery 协议汇报当前进度，然后为"大纲中第一个待写小节"做一份写作规划，交我确认。
   
   预期响应结构：① 先读 STATUS/glossary/handoff 汇报状态（steward 视角）→ ② 产出规划报告 →
   ③ **停下等待用户确认**（不得直接开写）。若 Agent 未经确认直接写正文，视为部署失败，需重装提示词。

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
                                                      │ 通过
                                                      ▼
                                     ┌───────────────┬───────────────┐
                                     ▼               ▼               ▼
                              ┌───────────┐   ┌───────────┐   ┌───────────┐
                              │consistency│   │blind-review│  │ librarian │
                              │一致性审查  │   │ 盲审预审   │  │ 文献落库   │
                              └───────────┘   └───────────┘   └───────────┘
```

设计要点：

- **用户确认是硬闸门**：规划不通过，绝不动笔；审计不通过，绝不交付——质量把关不在主代理的"自觉"，而在流程结构。
- **交叉验证**：规划者、写作者、审计者是不同视角的不同角色，避免"自己写自己审"的同温层。
- **滚动一致性**：每节完成后与"此前全部已写章节"及 `glossary.md` 做术语/口径比对，专治章节间论点断裂。
- **文献全链路**：规划检索 → 写作引用 → 独立核验落库 → 交付前三对照核验，杜绝"编造文献"与"引注失配"。
- **台账承载状态**：STATUS/glossary/handoff 三件套 + 跨会话恢复协议，6-8 万字长文写作不丢状态、不漂口径。

## 定制到其他学科

把 `prompts/system-prompt.md` 中「研究课题的底层学术画像」整段替换即可（或走阶段 3A 自动定制）：

```
核心问题意识： 批判现有研究只停留在「外部机制」层面 → 攻克「微观机制」：
              行动者为何从被动接受转为对特定供给/安排主动使用与持续依赖？
核心理论框架： 1-2 个核心理论框架 + 1 个刻画动态过程的机制模型（闭环/循环）
整体结构：    以论文文件为准
```

## 许可

[CC BY-SA 4.0](LICENSE)（署名—相同方式共享）。prompts/、docs/、examples/、plugins/ 全部内容均适用。
插件代码中如引用了第三方服务的接口语义（SerpAPI、SmartLib/SkillHub），相关权利归原服务方所有。
