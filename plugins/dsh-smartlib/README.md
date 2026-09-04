# dsh-smartlib

DeepSeek Harness 插件：通过 SmartLib API 检索中文期刊论文（CNKI/万方/维普等 300+ 库），支持多邮箱配额轮换。

## 提供的工具

| 工具 | 说明 |
| --- | --- |
| `smartlib_search` | 按单一关键词检索中文论文，返回 Markdown 列表 |

每次调用只接受一个关键词；多主题请分多次调用。

## 参考实现

SmartLib 检索能力的服务说明与接入参数参考：

<https://skillhub.cloud.tencent.com/skills/user_164f4c1f/smartlib-citation-checker>

（SkillHub 上的 SmartLib 引文核查技能；本插件按该服务的 API 语义实现检索与配额轮换。）

## 配置

配置写在 `cordis.patch.yml` 的 `insert` 行 `config` 字段（安装后即生效），
也可在 profile 的 `cordis.patch.yml`（用户层）以相同 `id` 覆盖：

```yaml
- insert:
    - id: dsh-smartlib
      name: dsh-smartlib
      config:
        gateway_url: https://YOUR_GATEWAY_URL
        gateway_secret: sk-YOUR_SECRET_HERE
        emails:
          - your-account@example.com
```

字段：

- `gateway_url`：SmartLib 网关地址（按参考实现页的接入信息填写）
- `gateway_secret`：网关 Bearer 密钥
- `emails`：邮箱列表，按顺序轮换配额（填你拥有使用权的配额邮箱）

## 安装（DeepSeek Harness）

把本目录放到插件目录后：

```bash
dsh plugin --profile web add link:C:/<你的路径>/plugins/dsh-smartlib
```

也可以直接把本仓库地址交给 Harness 的 AI，让它帮你完成安装与配置。

## 移植到 Codex（无 Harness 环境）

把本插件的工具语义（smartlib_search + 三步协议 + 配额轮换）交给 Codex，让它按 Codex 的插件/工具格式重写为代码版：读取 `lib/index.js` 理解调用逻辑；密钥与邮箱以环境变量/配置文件注入，不写死在代码中。
