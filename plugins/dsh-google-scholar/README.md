# dsh-google-scholar

DeepSeek Harness 插件：通过 SerpAPI 检索 Google Scholar。

三个工具共享 SerpAPI 月配额（250 次/月）。

## 提供的工具

| 工具 | 说明 |
| --- | --- |
| `google_scholar_search` | 检索 Google Scholar 学术论文（支持 author:/source: 修饰符） |
| `google_scholar_cited_by` | 查询引用某文献的论文（参数 `cites_id` 取自上一步结果的 `cites_id` 字段） |
| `google_scholar_all_versions` | 查询某论文的全部版本（参数 `cluster_id` 取自上一步结果的版本 `cluster_id` 字段） |

## 前置：获取 SerpAPI API Key

在 <https://serpapi.com/> 注册后，从控制台 Dashboard 获取 API Key（免费额度以官网当期政策为准）。

## 配置

配置写在 `cordis.patch.yml` 的 `insert` 行 `config` 字段（安装后即生效），
也可在 profile 的 `cordis.patch.yml`（用户层）以相同 `id` 覆盖：

```yaml
- insert:
    - id: dsh-google-scholar
      name: dsh-google-scholar
      config:
        serpapi_key: YOUR_SERPAPI_KEY_HERE
        max_results: 10
```

字段：

- `serpapi_key`：SerpAPI API Key（https://serpapi.com 控制台获取）
- `max_results`：每次调用默认返回的最大结果数（1-20），默认 10

## 安装（DeepSeek Harness）

把本目录放到插件目录后：

```bash
dsh plugin --profile web add link:C:/<你的路径>/plugins/dsh-google-scholar
```

也可以直接把本仓库地址交给 Harness 的 AI，让它帮你完成安装与配置。

## 移植到 Codex（无 Harness 环境）

把本插件的工具语义（search / cited_by / all_versions + SerpAPI 配额提示）交给 Codex，让它按 Codex 的插件/工具格式重写为代码版：读取 `lib/index.js` 理解调用逻辑、读取 `cordis.patch.yml` 理解配置字段；密钥以环境变量或配置文件注入，不写死在代码中。
