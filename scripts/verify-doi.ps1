# verify-doi.ps1 — DOI 有效性与元数据核验
#
# 为什么需要：librarian 被要求「核验文献真伪」，但此前没有任何工具。citation-check.ps1 只查
# 「正文编号 ⇄ 文末条目」的对应关系——**格式完美但指向不存在文献的条目能一路过审**。
# 编造文献是学术硬伤，必须机械可查。
#
# 两级检查：
#   第 1 级 格式校验（离线，必做）
#     · DOI 形态是否合法（10.<4-9 位注册机构码>/<后缀>）
#     · 是否出现明显伪造特征（占位符如 10.xxxx/、示例号 10.1000/182 等）
#   第 2 级 可解析性（联网，尽力而为）
#     · 通过 https://doi.org/<DOI> 解析，检查 HTTP 状态
#     · 404 / 不解析 ⇒ 该 DOI 不存在（强造假信号）
#     · 若同时给出 -Title，则调用 Crossref 比对题名，判断元数据是否张冠李戴
#
# 用法：
#   # 只做离线格式校验（无网络也能跑）
#   powershell -ExecutionPolicy Bypass -File scripts/verify-doi.ps1 -TextPath "正文.md" -Offline
#
#   # 格式 + 联网可解析性
#   powershell -ExecutionPolicy Bypass -File scripts/verify-doi.ps1 -TextPath "正文.md"
#
#   # 额外做元数据比对（题名相似度）
#   powershell -ExecutionPolicy Bypass -File scripts/verify-doi.ps1 -TextPath "正文.md" -CheckMetadata
#
# 退出码：0 = 无问题（或全部跳过）；1 = 发现格式错误 / DOI 不解析 / 元数据不符
#
# 注意：本文件须保存为 UTF-8 with BOM，否则 Windows PowerShell 5.1 会按 ANSI 解析中文而报错。
# 校验/修复：node -e "const fs=require('node:fs');const f='scripts/verify-doi.ps1';const b=fs.readFileSync(f);if(!(b[0]===0xEF&&b[1]===0xBB&&b[2]===0xBF)){fs.writeFileSync(f,Buffer.concat([Buffer.from([0xEF,0xBB,0xBF]),b]));console.log('BOM 已补')}else{console.log('BOM 正常')}"

param(
    [Parameter(Mandatory = $true)]
    [string]$TextPath,

    [Parameter(Mandatory = $false)]
    [switch]$Offline,           # 只做离线格式校验

    [Parameter(Mandatory = $false)]
    [switch]$CheckMetadata,     # 额外调用 Crossref 比对题名

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSec = 20
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if (-not (Test-Path $TextPath)) { Write-Error "文件不存在: $TextPath"; exit 1 }
$raw = Get-Content $TextPath -Raw -Encoding UTF8

Write-Host "=== DOI 有效性与元数据核验报告 ==="
Write-Host "文件: $TextPath"
Write-Host ("模式: " + $(if ($Offline) { "仅离线格式校验" } else { "格式 + 联网可解析性" }) + $(if ($CheckMetadata) { " + Crossref 元数据比对" } else { "" }))
Write-Host ""

# --- 提取 DOI（含 doi: 前缀与 https://doi.org/ 形态）---
# 注意：提取形态必须**宽于**合法形态，否则形如 10.abcd/xxx 的**格式错误** DOI 会被
# 悄悄跳过，而「格式校验」这一级的全部意义就在于抓出这种错误。
# 故注册机构码部分用 [\d\w]+（宽），由第 1 级格式校验判定其是否合法。
# 关键点：前缀里必须排除 '/'，否则正则引擎会匹配更短的备选分支而把前缀截断，
# 只抓到 10.1234 这样的残片（实测踩过）。后缀允许含 '/'（DOI 后缀常含斜杠）。
$doiRe = '(?:doi\s*:\s*|https?://(?:dx\.)?doi\.org/)(10\.[\d\w]+/[^\s\]\)）"，,；;、]+)'
$found = @()
foreach ($m in [regex]::Matches($raw, $doiRe, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    $d = $m.Groups[1].Value.TrimEnd('.', ',', ';', '）', ')', '。', '，')
    $found += $d
}
$dois = @($found | Select-Object -Unique | Sort-Object)

if ($dois.Count -eq 0) {
    Write-Host "ℹ️ 未在文中检出任何 DOI。"
    Write-Host "   若本文参考文献体例要求著录 DOI（如 GB/T 7714 的电子资源、多数英文期刊），"
    Write-Host "   这本身可能是一项缺失——请核对。"
    exit 0
}

Write-Host "检出 DOI 共 $($dois.Count) 个。"
Write-Host ""

$issues = 0
$formatBad = @()
$placeholder = @()
$unresolved = @()
$metaMismatch = @()
$unreachable = $false

# --- 第 1 级：格式校验 ---
Write-Host "--- 第 1 级：格式校验 ---"
$valid = @()
foreach ($d in $dois) {
    # 合法：10.<4-9 位数字>/<非空后缀>
    if ($d -notmatch '^10\.\d{4,9}/\S+$') {
        $formatBad += $d
        continue
    }
    # 伪造/占位特征：注册机构码为 0 或全同数字；后缀含 xxx/yyy 之类占位词
    $prefix = ($d -split '/')[0]
    $code = $prefix -replace '^10\.', ''
    if ($code -match '^0+$' -or $code -match '^(\d)\1{1,}$' -or $d -match '(?i)/(x{3,}|y{3,}|z{3,}|example|test|dummy|sample)') {
        $placeholder += $d
        continue
    }
    $valid += $d
}

if ($formatBad.Count -gt 0) {
    Write-Host "❌ 格式不合法（不符合 10.<注册机构码>/<后缀>）:"
    $formatBad | ForEach-Object { Write-Host "   $_" }
    $issues++
} else {
    Write-Host "✅ 所有 DOI 格式合法"
}

if ($placeholder.Count -gt 0) {
    Write-Host "❌ 疑似占位/伪造 DOI（注册机构码或后缀呈占位特征）:"
    $placeholder | ForEach-Object { Write-Host "   $_" }
    Write-Host "   → 这类 DOI 几乎必然无法解析，请核对原始文献后替换"
    $issues++
}

# --- 第 2 级：联网可解析性 ---
if (-not $Offline -and $valid.Count -gt 0) {
    Write-Host ""
    Write-Host "--- 第 2 级：可解析性（联网核查 $($valid.Count) 个）---"

    # 用 node 统一发请求（其 TLS 栈在本环境可用；schannel 在部分 Windows 环境会因
    # SEC_E_NO_CREDENTIALS 失败）。每个 DOI 一次 HEAD。
    #
    # 重要：载荷**必须经文件传递，不能作为命令行参数**。
    # Windows PowerShell 向原生命令传参时会吞掉 JSON 里的双引号（实测：
    # ["10.1000/182","a/b"] 会变成 [10.1000/182,a/b]，导致 JSON.parse 失败）。
    # 故此处把 JSON 写入无 BOM 的临时文件，由 node 侧 readFileSync 读取。
    # 注意：ConvertTo-Json 对**单元素数组**会退化为裸字符串（PowerShell 5.1 无 -AsArray），
    # 下游 JSON.parse 出来就成了字符串，循环会按字符逐个请求（实测踩过）。
    # 故此处手工构造 JSON 数组字符串。
    $payload = '[' + (($valid | ForEach-Object { '"' + ($_ -replace '\\', '\\' -replace '"', '\"') + '"' }) -join ',') + ']'
    $nodeScript = @'
import { readFileSync } from "node:fs";
const dois = JSON.parse(readFileSync(process.argv[2], "utf8"));
(async () => {
  const out = [];
  for (const d of dois) {
    const url = 'https://doi.org/' + encodeURIComponent(d);
    try {
      const ac = new AbortController();
      const t = setTimeout(() => ac.abort(), TIMEOUT_MS);
      const r = await fetch(url, { method: 'HEAD', redirect: 'follow', signal: ac.signal });
      clearTimeout(t);
      out.push({ doi: d, status: r.status, finalUrl: r.url });
    } catch (e) {
      out.push({ doi: d, status: 0, error: String(e.message || e) });
    }
  }
  console.log(JSON.stringify(out));
})();
'@
    $nodeScript = $nodeScript.Replace('TIMEOUT_MS', ($TimeoutSec * 1000).ToString())

    $tmpJs = Join-Path $env:TEMP ("verify-doi-" + [guid]::NewGuid().ToString('N') + ".mjs")
    $tmpPayload = Join-Path $env:TEMP ("verify-doi-payload-" + [guid]::NewGuid().ToString('N') + ".json")
    # 用 WriteAllText 以确保**无 BOM**：经 Set-Content -Encoding UTF8 在部分 PowerShell 版本下
    # 会写入 BOM，BOM 后的字节会让 node 报 SyntaxError（实测踩过）。
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tmpJs, $nodeScript, $utf8NoBom)
    [System.IO.File]::WriteAllText($tmpPayload, $payload, $utf8NoBom)
    try {
        # 关键：本脚本开头设了 $ErrorActionPreference = "Stop"，而原生命令写入 stderr 会被
        # PowerShell 当成 terminating error（实测：node 的报错直接把脚本打断）。
        # 故此处临时放宽，仅收集输出文本，由后续 JSON 解析失败来判定。
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $rawOut = & node $tmpJs $tmpPayload 2>&1
            $nodeExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $prevEap
        }
        $results = $null
        try {
            $joined = ($rawOut | ForEach-Object { "$_" }) -join "`n"
            $results = $joined | ConvertFrom-Json
        } catch { $results = $null }
        if (-not $results -and $nodeExit -ne 0) {
            $errText = (($rawOut | ForEach-Object { "$_" }) -join "`n")
            if ($errText.Length -gt 1200) { $errText = $errText.Substring(0, 1200) + '…' }
            Write-Host "   [诊断] node 调用失败（exit $nodeExit）：`n$errText"
        }
    } finally {
        Remove-Item $tmpJs -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpPayload -Force -ErrorAction SilentlyContinue
    }

    if (-not $results) {
        Write-Host "⚠️ 联网核查未取得结果（可能是网络不可达或 node 不可用）。"
        Write-Host "   离线格式校验结果仍然有效；可稍后重试，或用 -Offline 明确跳过。"
        $unreachable = $true
    } else {
        foreach ($r in $results) {
            if ($r.status -eq 0) {
                Write-Host "   ⚠️ 请求失败（网络/超时）: $($r.doi)"
                $unreachable = $true
            } elseif ($r.status -ge 200 -and $r.status -lt 400) {
                Write-Host "   ✅ 可解析 ($($r.status)): $($r.doi)"
            } elseif ($r.status -eq 404) {
                Write-Host "   ❌ 不存在 (404): $($r.doi)"
                Write-Host "      → 该 DOI 未在注册机构登记。这是**强造假信号**，请核对原始文献"
                $unresolved += $r.doi
            } elseif ($r.status -eq 403 -or $r.status -eq 401) {
                Write-Host "   ⚠️ 已登记但拒绝匿名访问 ($($r.status)): $($r.doi)"
                Write-Host "      → DOI 存在（注册机构有记录），仅目标站点限制了自动访问，不算问题"
            } else {
                Write-Host "   ⚠️ 异常状态 $($r.status): $($r.doi)"
            }
        }
        if ($unresolved.Count -gt 0) { $issues++ }
    }
}

# --- 第 3 级（可选）：Crossref 元数据比对 ---
if ($CheckMetadata -and -not $Offline -and $valid.Count -gt 0) {
    Write-Host ""
    Write-Host "--- 第 3 级：Crossref 元数据比对（题名相似度）---"
    Write-Host "   做法：取文中每条 DOI 所在行的题名片段，与 Crossref 返回的题名比对；"
    Write-Host "   相似度过低提示「元数据可能张冠李戴」，非判定为造假（题名可能被译写）。"

    # 逐 DOI 找其所在行的文本作为题名候选
    $lines = $raw -split "`n"
    $pairs = @()
    foreach ($d in $valid) {
        $line = $lines | Where-Object { $_ -like "*$d*" } | Select-Object -First 1
        if (-not $line) { continue }
        # 去掉 DOI 本身与常见著录标记，剩下的当题名候选
        $cand = $line -replace [regex]::Escape($d), ' '
        $cand = $cand -replace 'https?://(?:dx\.)?doi\.org/\S*', ' '
        $cand = $cand -replace '^\s*\[?\d{1,3}\]?[\.、\s]*', ''
        $cand = $cand.Trim()
        $pairs += [pscustomobject]@{ Doi = $d; Candidate = $cand }
    }

    if ($pairs.Count -eq 0) {
        Write-Host "   ℹ️ 未能定位 DOI 所在行，跳过元数据比对。"
    } else {
        $payload2 = '[' + (($pairs | ForEach-Object {
            '{"Doi":"' + ($_.Doi -replace '\\', '\\' -replace '"', '\"') + '","Candidate":"' +
            ($_.Candidate -replace '\\', '\\' -replace '"', '\"' -replace "`n", ' ' -replace "`r", '') + '"}'
        }) -join ',') + ']'
        $nodeMeta = @'
import { readFileSync } from "node:fs";
const pairs = JSON.parse(readFileSync(process.argv[2], "utf8"));
function norm(s){ return (s||'').toLowerCase().replace(/[^\p{L}\p{N}]+/gu,' ').trim(); }
function tokens(s){ return new Set(norm(s).split(/\s+/).filter(w => w.length > 1)); }
function overlap(a,b){
  const A = tokens(a), B = tokens(b);
  if (A.size === 0 || B.size === 0) return 0;
  let hit = 0; for (const t of A) if (B.has(t)) hit++;
  return hit / Math.min(A.size, B.size);
}
(async () => {
  const out = [];
  for (const p of pairs) {
    try {
      const ac = new AbortController();
      const t = setTimeout(() => ac.abort(), TIMEOUT_MS);
      const r = await fetch('https://api.crossref.org/works/' + encodeURIComponent(p.Doi) + '?mailto=dsh-pipeline@example.org', { signal: ac.signal });
      clearTimeout(t);
      if (!r.ok) { out.push({ doi: p.Doi, ok: false, status: r.status }); continue; }
      const j = await r.json();
      const m = j.message || {};
      const title = (m.title && m.title[0]) || '';
      const container = (m['container-title'] && m['container-title'][0]) || '';
      const year = (m.issued && m.issued['date-parts'] && m.issued['date-parts'][0] && m.issued['date-parts'][0][0]) || '';
      out.push({ doi: p.Doi, ok: true, title, container, year, score: overlap(p.Candidate, title) });
    } catch (e) {
      out.push({ doi: p.Doi, ok: false, error: String(e.message || e) });
    }
  }
  console.log(JSON.stringify(out));
})();
'@
        $nodeMeta = $nodeMeta.Replace('TIMEOUT_MS', ($TimeoutSec * 1000).ToString())
        $tmpJs2 = Join-Path $env:TEMP ("verify-doi-meta-" + [guid]::NewGuid().ToString('N') + ".mjs")
        $tmpPayload2 = Join-Path $env:TEMP ("verify-doi-meta-payload-" + [guid]::NewGuid().ToString('N') + ".json")
        $utf8NoBom2 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($tmpJs2, $nodeMeta, $utf8NoBom2)
        [System.IO.File]::WriteAllText($tmpPayload2, $payload2, $utf8NoBom2)
        try {
            $prevEap2 = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                $rawMeta = & node $tmpJs2 $tmpPayload2 2>&1
                $metaExit = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $prevEap2
            }
            try {
                $meta = (($rawMeta | ForEach-Object { "$_" }) -join "`n") | ConvertFrom-Json
            } catch { $meta = $null }
            if (-not $meta -and $metaExit -ne 0) {
                Write-Host "   [诊断] Crossref 调用失败（exit $metaExit）：$(($rawMeta | Select-Object -First 2) -join ' | ')"
            }
        } finally {
            Remove-Item $tmpJs2 -Force -ErrorAction SilentlyContinue
            Remove-Item $tmpPayload2 -Force -ErrorAction SilentlyContinue
        }

        if (-not $meta) {
            Write-Host "   ⚠️ Crossref 查询未取得结果（网络不可达？）。"
        } else {
            foreach ($m in $meta) {
                if (-not $m.ok) {
                    if ($m.status -eq 404) {
                        Write-Host "   ❌ Crossref 无此 DOI 记录: $($m.doi)"
                        Write-Host "      → 该 DOI 可能指向非 Crossref 注册的出版方（如 DataCite），也可能不存在"
                        $metaMismatch += $m.doi
                    } else {
                        Write-Host "   ⚠️ Crossref 查询失败 ($($m.status)): $($m.doi)"
                    }
                    continue
                }
                $pct = [Math]::Round(100 * $m.score, 0)
                if ($m.score -lt 0.3) {
                    Write-Host "   ❌ 题名相似度低 ($pct%): $($m.doi)"
                    Write-Host "      文中题名候选: 与 Crossref 记录差异较大"
                    Write-Host "      Crossref 实际题名: $($m.title)"
                    if ($m.container) { Write-Host "      实际出处: $($m.container) ($($m.year))" }
                    Write-Host "      → 请核对：可能 DOI 与文献张冠李戴，或题名被大幅译写"
                    $metaMismatch += $m.doi
                } elseif ($m.score -lt 0.6) {
                    Write-Host "   ⚠️ 题名相似度偏低 ($pct%): $($m.doi) — Crossref 题名: $($m.title)"
                } else {
                    Write-Host "   ✅ 元数据相符 ($pct%): $($m.doi) — $($m.title)"
                }
            }
            if ($metaMismatch.Count -gt 0) { $issues++ }
        }
    }
}

# --- 结论 ---
Write-Host ""
if ($issues -eq 0) {
    if ($unreachable) {
        Write-Host "⚠️ 未发现 DOI 问题，但有部分请求未能完成（网络原因）——结论不完整，建议网络可用时重跑。"
    } else {
        Write-Host "✅ DOI 核验通过。"
        Write-Host "   注：DOI 可解析只说明该编号已登记；**观点归属是否属实**仍须 auditor 以摘要核对"
        Write-Host "   （见 prompts/roles/auditor.md 文献审计维度）。"
    }
} else {
    Write-Host "⚠️ 发现 $issues 类 DOI 问题，请核对后修正并重跑。"
    Write-Host "   红线：无法解析的 DOI 一律不得保留在正文或参考文献中。"
    exit 1
}
