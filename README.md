# Multi-Agent Academic Writing Pipeline（多代理学术写作流水线）

一套把学位论文正文写作拆成「**同步进度 → 独立规划 → 用户确认 → 成文 → 独立审计 → 文献落库**」闭环的多代理编排模板。以虚构的公共管理课题《城市社区居家养老服务供需匹配机制研究》为演示案例，展示如何用角色化子代理群把大纲与零散想法，加工成达到盲审质量的学术正文——整套方法论可整体迁移到任意学科课题。

> ⚠️ **免责声明**：本仓库中的「导师」等角色为**虚构学术角色模板**，仅用于演示多代理写作编排方法，**不指向任何真实个人、机构或院校**。仓库内的研究主题、例文与全部文献条目均为**虚构占位**，非真实课题成果；请勿将其用于任何学术署名、查重或投稿用途。
>
> 本工具是**写作方法与流程的辅助框架**，不替代作者的独立研究与学术判断；使用 AI 辅助写作时请遵守所在机构的学术规范，并对最终文本负责。

## 核心思想

单代理一口气写论文的常见失败模式：缺少中期检查、文献不可信、风格前后漂移、交稿才发现论证漏洞。本模板把这些质量环节**外置为独立子代理**，形成互相制衡的流水线：

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
- **滚动一致性**：每节完成后与"此前全部已写章节"做术语/口径比对（consistency），以及滚动盲审预审（blind-review），专治章节间论点断裂。
- **文献全链路**：规划检索 → 写作引用 → 独立核验落库，正文引用与文献库条目一一对应，避免"编造文献"与"引注失配"。

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
│       ├── consistency.md      # 术语与一致性审查
│       ├── blind-review.md     # 盲审预审
│       └── steward.md          # 大纲与进度管家
├── docs/
│   ├── workflow.md             # 全流程协议（第〇步～第五步）
│   ├── roles-matrix.md         # 角色职责速查 + 模型路由建议
│   ├── zotero-schema.md        # 文献库分类集合设计示例
│   └── customize-from-proposal.md  # 用开题报告自动定制提示词的作业单
├── plugins/                    # 学术检索插件（DeepSeek Harness 版）
│   ├── dsh-google-scholar/     # Google Scholar 检索（SerpAPI）
│   └── dsh-smartlib/           # SmartLib 中文期刊检索（CNKI/万方/维普）
└── examples/                   # 一次写作任务的输入输出样例（虚构演示）
```

## Quickstart

### 0. 用你自己的开题报告自动生成提示词（推荐入口）

模板自带的示例课题（居家养老）。**最省力的定制方式是把你的开题报告交给 Agent，让它自动生成属于你的 `prompts/system-prompt.md` 与 `AGENTS.md`**——完整作业单见 [`docs/customize-from-proposal.md`](docs/customize-from-proposal.md)。大致流程：

1. 把你的开题报告（docx/pdf/md）放进项目根目录；
2. 把作业单全文发给 Agent（Codex 或 DSH 均可），它会：通读开题报告 → 提取问题意识/理论工具/大纲/术语 → 按同构句式改写「底层学术画像」→ 写回 `prompts/system-prompt.md` 与 `AGENTS.md` → 输出定制报告；
3. 按作业单末尾的「人工复核清单」检查一遍即可。

> 若暂不开题报告（或想先跑通流程），可先用模板自带的示例课题练手，或手工替换 `<...>` 占位符（研究主题、用户称呼、论文文件名、文献库集合键等）。`docs/workflow.md` 是你要遵循的完整工作协议。

### 方式 A：OpenAI Codex（CLI / IDE）

Codex 会自动读取项目根目录的 `AGENTS.md` 作为项目级指令，也支持通过 subagents 定义角色化子代理。两种粒度任选：

**A1. 最小启动（单代理 + AGENTS.md）**——不引入子代理，主对话按流水线"扮演"各角色：

1. 将 `prompts/system-prompt.md` 的全部内容（定制后，可由第 0 步自动生成）写入项目根目录 `AGENTS.md`；
2. 在项目目录启动 `codex`（或 `codex exec`），直接下达第一个写作指令，例如：
   > 请按 AGENTS.md 中定义的工作协议，先派"规划专家"角色为第三章第二节做写作规划，交我确认。
3. 之后每步由主代理按协议依次切换规划/写作/审计视角执行，审计通过后再交付。

**A2. 完整启动（Codex Subagents）**——把七个角色注册为真正的子代理：

1. 参考官方文档 [Codex Subagents](https://developers.openai.com/codex/subagents)，在项目的 `.codex/` 下为七个角色各建一个 subagent 定义（把 `prompts/roles/*.md` 的内容作为各角色的指令体）；
2. 将 `prompts/system-prompt.md`（定制后）写入项目根 `AGENTS.md`，并在其中写明流水线与角色分工速查表（第〇步～第五步）；
3. 在 Codex 中按流水线委派子代理：规划阶段派 planner → 等你确认 → 写作阶段派 writer → 审计阶段派 auditor，审计未过则退回 writer 修订，循环至通过。

**A3. 检索插件（Codex 版）**：本仓库的 `plugins/` 为 DeepSeek Harness 插件格式，不适用于 Codex。在 Codex 中使用 Google Scholar / SmartLib 检索时，把对应插件的语义交给 Codex，让它**重写为 Codex 的代码版工具**——读取 `plugins/*/lib/index.js` 理解调用逻辑、读取 `cordis.patch.yml` 理解配置字段；密钥用环境变量注入，不写死在代码中。两个插件的「移植到 Codex」说明已写在各插件自己的 README 里。

> 提示：Codex 读取项目指令与自定义指令的机制见 [AGENTS.md 说明](https://learn.chatgpt.com/docs/agent-configuration/agents-md) 与 [Codex CLI Custom Instructions](https://mintlify.wiki/openai/codex/advanced/custom-instructions)。若你的环境不支持 subagent_role 类工具，用 A1 即可跑通完整流程。

### 方式 B：DeepSeek Harness（DSH）

DSH 原生支持角色路由：把模板装进 `.dsh/prompt.md`，七个角色经 subagent_role 委派，模型绑定在 settings.yaml 统一配置。推荐完整启用：

1. **装入主提示词**：在项目根目录建 `.dsh/prompt.md`，将定制后的 `prompts/system-prompt.md` 全文写入（DSH 会把它作为该项目的系统提示词加载；定制稿可由第 0 步自动生成）；
2. **绑定模型路由**：在 settings.yaml 中为七个角色绑定 provider/model（按 `docs/roles-matrix.md` 的档位建议配置，可参考相关 [dsh 子代理角色插件](https://github.com/SeverusZh/dsh-plugin-subagent-director) 的做法）；
3. **安装检索插件**：把 `plugins/` 下的 `dsh-google-scholar` 与 `dsh-smartlib` 放入你的插件目录，然后**直接让 DSH 的 AI 帮你安装与配置**（告诉它"安装 plugins 目录下的两个学术检索插件"即可，它会执行 `dsh plugin` 命令并提示你补配置）——
   - Google Scholar 插件需要 SerpAPI Key：到 <https://serpapi.com/> 注册获取（插件内 `serpapi_key` 字段）；
   - SmartLib 插件需要网关地址与配额邮箱，服务说明参考 <https://skillhub.cloud.tencent.com/skills/user_164f4c1f/smartlib-citation-checker>（插件内 `gateway_url` / `gateway_secret` / `emails` 字段）；
   - 手动安装命令见各插件 README：`dsh plugin --profile web add link:...`；
4. **开始写作**：在 DSH 会话中直接下达写作指令（如"帮我把第三章大纲扩写成一节正文"），主代理会按 system-prompt 的协议自动调用 subagent_role 委派各角色——规划 → 等你确认 → 成文 → 审计 → 一致性/盲审把关 → 文献落库；
5. **文献落库**：若需接入 Zotero，按 `docs/zotero-schema.md` 建立集合结构，librarian 角色负责落库与核验。

> 提示：模型绑定是宿主环境配置，不在提示词内硬编码——主代理不得自行指定模型，统一由 settings.yaml 绑定，一处切换、全局生效。

## 定制到其他学科

把 `system-prompt.md` 中「研究课题的底层学术画像」整段替换即可（或直接用第 0 步的开题报告自动生成）：

```
核心问题意识： 批判现有研究只停留在「外部机制」层面 → 攻克「微观机制」：
              行动者为何从被动接受转为对特定供给/安排主动使用与持续依赖？
核心理论框架： 1-2 个核心理论框架 + 1 个刻画动态过程的机制模型（闭环/循环）
整体结构：    以论文文件为准
```

## 许可

[CC BY-NC-SA 4.0](LICENSE)（署名—非商业性使用—相同方式共享）。prompts/、docs/、examples/、plugins/ 全部内容均适用。插件代码中如引用了第三方服务的接口语义（SerpAPI、SmartLib/SkillHub），相关权利归原服务方所有。
