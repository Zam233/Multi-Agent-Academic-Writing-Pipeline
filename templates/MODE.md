# MODE.md — 本项目写作模式配置（模板）

> **用途**：本文件是**本项目所有角色的唯一口径来源**。复制到项目根目录后填写（文件名保持 `MODE.md`）。
> planner / writer / auditor / librarian / consistency / blind-review / steward **在执行任务前
> 都必须先读本文件**，以其中的参数覆盖各自角色文件里的默认值。
>
> 规格说明与取值含义见 [`modes/_mode-overview.md`](../modes/_mode-overview.md)；
> 各模式细则见 `modes/degree-thesis.md`、`modes/journal-article.md`、`modes/course-paper.md`。
>
> **填错模式会导致整条流水线的标准失准**——填完后请让用户确认一次。

---

## 一、必填字段

```markdown
- mode: <degree-thesis | journal-article | course-paper>
- level: <bachelor | master | doctor | n/a>      # 仅 degree-thesis 用，其余填 n/a
- discipline: <学科名，如 教育学 / 计算机科学 / 材料科学 / 社会学>
- language: <zh | en | 其他>
- target_length: <字数区间>
- structure_unit: <节 | 全篇 | 题>
- citation_style: <numeric | author-date | footnote>
- citation_standard: <GB/T 7714—2015 | APA 7th | Chicago 17th | 目标期刊体例>
- review_gate: <盲审 | 匿名外审 | 课程评分 | 仅自查>
- audience: <读者身份>
- has_empirical: <yes | no>   # 是否含"结果"性质章节；yes 时数据可得性状态(A/B/C/D)须登记在 DATA.md
```

## 二、条件必填字段（按模式填）

```markdown
# --- mode: journal-article 时必填 ---
- target_journal: <期刊名>
- journal_tier: <CSSCI / SSCI Q1 / 北大核心 / 中文一级学报 / 普刊 …>
- article_type: <原创研究 | 综述 | 案例 | 方法 | 书评>
- word_limit_hard: <数字上限 + 口径说明，如 "12000 字（含图表摘要，参考文献不计）">

# --- mode: course-paper 时必填 ---
- course_name: <课程名>
- instructor_requirements: <教师要求原文（篇幅/引注/格式/截止时间）>
- grading_rubric: <评分点清单，逐条列出；无则填"无（Agent 按五维自建）">

# --- mode: degree-thesis 时选填 ---
- school_format: <学校学位论文格式规范文件/链接>
```

## 三、备注字段（选填，但建议填）

```markdown
- notes: <其他需要全部角色知道的约定，如"图表需中英双语题注""需提交查重报告"等>
- mode_confirmed_by_user: <yes | no>   # 是否已由用户确认模式与档位
```

---

## 四、三种模式的填写样例（照抄对应一段，删掉其余两段）

### 样例 A：学位论文（硕士）

```markdown
- mode: degree-thesis
- level: master
- discipline: 教育技术学
- language: zh
- target_length: 40000-50000 字
- structure_unit: 节
- citation_style: numeric
- citation_standard: GB/T 7714—2015（学校规范另有要求时以学校为准）
- review_gate: 盲审
- audience: 盲审专家与答辩委员会
- school_format: <学校研究生院学位论文格式规范.pdf>
- mode_confirmed_by_user: yes
```

### 样例 B：期刊论文

```markdown
- mode: journal-article
- level: n/a
- discipline: 计算机科学
- language: zh
- target_journal: 《计算机学报》
- journal_tier: 中文一级学报
- article_type: 原创研究
- word_limit_hard: 12000 字（含图表摘要，参考文献不计）
- target_length: 9000-11000 字
- structure_unit: 全篇
- citation_style: numeric
- citation_standard: 目标期刊《投稿须知》体例
- review_gate: 匿名外审
- audience: 匿名审稿人与责任编辑
- notes: 需提供中英文摘要；实验需报告多次运行的均值与方差
- mode_confirmed_by_user: yes
```

### 样例 C：课程论文

```markdown
- mode: course-paper
- level: n/a
- discipline: 社会学
- language: zh
- target_length: 3000-5000 字
- structure_unit: 题
- citation_style: author-date
- citation_standard: APA 7th
- review_gate: 课程评分
- audience: 任课教师
- course_name: <课程名>
- instructor_requirements: <教师要求原文，如"不少于 3000 字，需引用课程指定读本，APA 格式，第 16 周周五前提交">
- grading_rubric: <若课程大纲给出评分点则逐条抄入；无则填"无（Agent 按五维自建）">
- mode_confirmed_by_user: yes
```

---

## 五、模式对流水线的影响速查（填完后自检）

| 检查项 | degree-thesis | journal-article | course-paper |
|---|---|---|---|
| auditor 第 5 维口径 | 盲审标准 | 审稿人口径（含**期刊适配**与字数合规） | 课程评分点 |
| 字数性质 | 预算（报偏差，偏差>20% 须上报） | **硬上限**（超限即"需修订"） | 区间（取中下位，宁短勿长） |
| blind-review | 滚动预审（本节+此前全部章节） | 模拟匿名审稿人 | 模拟任课教师，通常只跑一次 |
| 台账粒度 | 章/节 + 四态 + 字数偏差 | **版本台账** + 审稿应答表 | 题目清单 |
| 目录同步 | **必须** | 不需要 | 不需要 |
| 是否核对章节编号 | **必须** | 不需要 | 不需要 |
| 引注默认 | `[n]` + GB/T 7714 | **随目标期刊** | 著者-年制 |
| citation-check.ps1 | `-Style numbered` | 按期刊体例选 `-Style` | `-Style author-date` |
| 创新性要求 | 按 level 梯度 | 可发表的边际贡献 | **不要求**（正确运用课程理论即可） |
