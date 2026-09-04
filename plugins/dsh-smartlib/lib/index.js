// dsh-smartlib — SmartLib 中文期刊学术检索工具（CNKI/万方/维普等 300+ 库）。
// 协议对齐原 Scholar_View smartlib 插件：register → consume → search 三步，
// 多邮箱配额轮换，任何错误一律返回可读中文文本（不抛异常）。
import z from "@deepseek-ai/schemastery";
import { defineTool } from "@deepseek-ai/dsh-tools";

const name = "dsh-smartlib";
const inject = ["tools", "systemPrompt"];

const SKILL_SOURCE = "global-biblio-base";
const PAGE_INDEX = 1;
const PAGE_SIZE = 10;
const TIMEOUT_MS = 30_000;

//: 工具描述（措辞对齐原插件，含单关键词约束警示）
const DESCRIPTION = [
  "中文：通过 SmartLib API 检索中文期刊论文（CNKI/万方/维普等 300+ 库）。",
  "/ English: Search for Chinese academic papers via SmartLib API (300+ Chinese databases incl. CNKI/Wanfang/VIP).",
  "/ 限制：每邮箱免费 100 次/月；⚠️ 每次调用只接受单一关键词，禁止组合",
  "（'大语言模型' 正确，'大语言模型 知识图谱' 错误）；多主题请分多次调用。"
].join(" ");

const Config = z.object({
  gateway_url: z.string().default(""),
  gateway_secret: z.string().default(""),
  emails: z.array(z.string()).default([])
});

// ---- 公共 HTTP / 信号 ----

function makeSignal(exec) {
  const timeout = AbortSignal.timeout(TIMEOUT_MS);
  if (exec?.signal) return AbortSignal.any([exec.signal, timeout]);
  return timeout;
}

async function postJson(url, body, headers, signal) {
  const res = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
    signal
  });
  return res;
}

// ---- register → consume → search 三步协议 ----

async function registerEmail(gateway, headers, email, signal) {
  const res = await postJson(`${gateway}/register`, { email }, headers, signal);
  return res.status === 200 || res.status === 201;
}

async function consumeEmail(gateway, headers, email, signal) {
  const res = await postJson(
    `${gateway}/consume`,
    { email, skill_source: SKILL_SOURCE },
    headers,
    signal
  );
  if (res.status === 429) return null;
  if (res.status !== 200) throw new Error(`consume 返回 HTTP ${res.status}`);
  let data;
  try {
    data = await res.json();
  } catch {
    throw new Error("consume 响应解析失败");
  }
  if (!data || typeof data !== "object") throw new Error("consume 响应格式异常");
  const token = data.consume_token;
  if (!token) return null;
  const remain = data.total_remain != null ? Number(data.total_remain) : null;
  return { token: String(token), remain };
}

async function searchEmail(gateway, headers, email, token, query, signal) {
  const res = await postJson(
    `${gateway}/search`,
    {
      email,
      consume_token: token,
      skill_source: SKILL_SOURCE,
      endpoint: "/search/cn",
      rule: `K=${query}`,
      page_index: PAGE_INDEX,
      page_size: PAGE_SIZE
    },
    headers,
    signal
  );
  if (res.status !== 200) throw new Error(`search 返回 HTTP ${res.status}`);
  let data;
  try {
    data = await res.json();
  } catch {
    throw new Error("search 响应解析失败");
  }
  if (!data || typeof data !== "object" || !data.succeeded) {
    throw new Error("search 返回失败状态");
  }
  const inner = data.data || {};
  const papers = Array.isArray(inner.list) ? inner.list : [];
  const total = inner.total != null ? Number(inner.total) : null;
  return { papers, total };
}

// ---- 结果解析与 Markdown 格式化 ----

function parseAuthors(raw) {
  return String(raw ?? "")
    .replace(/；/g, " ")
    .replace(/;/g, " ")
    .split(/\s+/)
    .filter(Boolean);
}

function parseYear(raw) {
  const text = String(raw ?? "").trim();
  return /^\d+$/.test(text) ? text : "";
}

function formatResults(papers, total, remain) {
  const lines = [];
  lines.push(total != null ? `SmartLib 检索结果（共 ${total} 条）：` : "SmartLib 检索结果：");
  papers.forEach((paper, index) => {
    const title = String(paper?.Title ?? "").trim() || "（无标题）";
    const authors = parseAuthors(paper?.Creator);
    const source = String(paper?.Source_Name ?? "").trim();
    const year = parseYear(paper?.Date_PublishYear);
    const url = String(paper?.Identifier ?? "").trim();
    const abstract = String(paper?.Description ?? "").trim();

    lines.push("");
    lines.push(`### ${index + 1}. ${title}`);
    if (authors.length) lines.push(`- 作者：${authors.join("、")}`);
    if (source || year) {
      let meta = source;
      if (year) meta = meta ? `${meta}（${year}）` : year;
      lines.push(`- 来源：${meta}`);
    }
    if (url) lines.push(`- 链接：${url}`);
    if (abstract) lines.push(`- 摘要：${abstract.slice(0, 200)}`);
  });
  if (remain != null) {
    lines.push("");
    lines.push(`本次邮箱剩余配额：${remain} 次`);
  }
  const text = lines.join("\n").trim();
  return text || "SmartLib 检索结果为空";
}

// ---- 主检索流程（多邮箱轮换） ----

async function runSearch(cfg, query, signal) {
  const gateway = (cfg.gateway_url || "").trim().replace(/\/+$/, "");
  const secret = (cfg.gateway_secret || "").trim();
  const emails = (cfg.emails || []).map((e) => String(e).trim()).filter(Boolean);
  if (!gateway || !secret) return "SmartLib 检索失败：未配置网关（URL/密钥）";
  if (emails.length === 0) return "SmartLib 检索失败：未配置邮箱";

  const headers = {
    Authorization: `Bearer ${secret}`,
    "Content-Type": "application/json"
  };

  let lastError = "所有邮箱配额耗尽或检索失败";
  for (const email of emails) {
    try {
      let consumed = await consumeEmail(gateway, headers, email, signal);
      if (consumed == null) {
        const registered = await registerEmail(gateway, headers, email, signal);
        if (registered) consumed = await consumeEmail(gateway, headers, email, signal);
      }
      if (consumed == null) {
        lastError = `邮箱 ${email} 配额不足或注册失败`;
        continue;
      }
      const { papers, total } = await searchEmail(
        gateway, headers, email, consumed.token, query, signal
      );
      return formatResults(papers, total, consumed.remain);
    } catch (err) {
      if (err?.name === "AbortError") {
        lastError = `邮箱 ${email}：请求超时或已取消`;
      } else {
        lastError = `邮箱 ${email}：${err?.message ?? String(err)}`;
      }
    }
  }
  return `SmartLib 检索失败：${lastError}`;
}

// ---- 注册 ----

function apply(ctx, config) {
  const resolved = Config(config ?? {});

  ctx.systemPrompt.section({
    name: "tool:smartlib_search",
    order: 112,
    text: "Use the smartlib_search tool to search Chinese academic papers (CNKI/Wanfang/VIP etc.). It accepts a single keyword per call — run it multiple times for multiple topics."
  });

  ctx.tools.register(defineTool({
    name: "smartlib_search",
    description: DESCRIPTION,
    parameters: {
      query: {
        type: "string",
        required: true,
        description: "单一关键词检索词（SmartLib 每次调用只接受一个关键词，禁止组合；多主题请分多次调用）"
      }
    },
    output: {
      schema: {
        type: "object",
        additionalProperties: false,
        properties: {
          text: { type: "string", required: true }
        }
      },
      render: (_args, value) => [{ type: "text", text: value.text }]
    },
    timeoutMs: TIMEOUT_MS,
    isConcurrencySafe: () => true,
    async execute(args, exec) {
      const query = String(args.query ?? "").trim();
      if (!query) return { text: "SmartLib 检索失败：缺少查询参数 query（单一关键词）" };
      return { text: await runSearch(resolved, query, makeSignal(exec)) };
    }
  }));
}

export { Config, apply, inject, name };
