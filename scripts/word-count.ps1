# word-count.ps1 — 字数统计与配额核验
#
# 为什么需要：三个模式的「篇幅纪律」都依赖字数，但此前没有任何工具能数字数——
#   degree-thesis ：字数预算偏差 >20% 须上报用户（steward 职责）
#   journal-article：word_limit_hard 是硬闸门，超限即判「需修订」（auditor 职责）
#   course-paper   ：区间要求（宁短勿长），超区间扣分
# 仅靠模型自估字数不可靠（模型不会真的计数），故以本脚本为机械口径。
#
# 字数口径（近似 Word「字数」统计，中文按字、西文按词）：
#   计入：CJK 汉字 + 西文单词 + 数字串
#   默认排除：Markdown 标记、代码块、行内代码、HTML 注释、图片语法
#   可选排除：参考文献区、摘要区、脚注/尾注区（依目标刊的「字数是否含参考文献」口径）
#
# 用法：
#   # 单文件统计
#   powershell -ExecutionPolicy Bypass -File scripts/word-count.ps1 -TextPath "第三章.md"
#
#   # 与配额比对（期刊硬上限 / 课程区间 / 学位论文预算）
#   powershell -ExecutionPolicy Bypass -File scripts/word-count.ps1 -TextPath "稿件_v3.md" -Limit 12000
#   powershell -ExecutionPolicy Bypass -File scripts/word-count.ps1 -TextPath "课程论文.md" -Min 3000 -Max 5000
#
#   # 按期刊常见口径「参考文献不计」统计，并统计多个文件合计
#   powershell -ExecutionPolicy Bypass -File scripts/word-count.ps1 -TextPath "第一章.md","第二章.md" -ExcludeRef
#
#   # 批量：统计整个目录（按大纲/台账核对各章字数）
#   powershell -ExecutionPolicy Bypass -File scripts/word-count.ps1 -TextPath "." -Pattern "第*章*.md" -ExcludeRef
#
# 退出码：0 = 符合配额（或未给配额）；1 = 违反配额（超上限/低于下限）或出错
#
# 注意：本文件须保存为 UTF-8 with BOM，否则 Windows PowerShell 5.1 会按 ANSI 解析中文而报错。
# 校验/修复：node -e "const fs=require('node:fs');const f='scripts/word-count.ps1';const b=fs.readFileSync(f);if(!(b[0]===0xEF&&b[1]===0xBB&&b[2]===0xBF)){fs.writeFileSync(f,Buffer.concat([Buffer.from([0xEF,0xBB,0xBF]),b]));console.log('BOM 已补')}else{console.log('BOM 正常')}"

param(
    [Parameter(Mandatory = $true)]
    [string[]]$TextPath,

    [Parameter(Mandatory = $false)]
    [string]$Pattern = "*.md",

    [Parameter(Mandatory = $false)]
    [int]$Limit = 0,          # 硬上限（期刊模式 word_limit_hard）；0 = 不检查

    [Parameter(Mandatory = $false)]
    [int]$Min = 0,            # 下限（课程论文区间下限）；0 = 不检查

    [Parameter(Mandatory = $false)]
    [int]$Max = 0,            # 上限（课程论文区间上限）；0 = 不检查（与 -Limit 等价，二者取更严）

    [Parameter(Mandatory = $false)]
    [switch]$ExcludeRef,      # 排除「参考文献」区（期刊常见口径）

    [Parameter(Mandatory = $false)]
    [switch]$ExcludeAbstract, # 排除「摘要/Abstract」区

    [Parameter(Mandatory = $false)]
    [switch]$Verbose_Sections # 打印各区段字数明细
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# --- 收集待统计文件 ---
$files = @()
foreach ($p in $TextPath) {
    if (Test-Path $p -PathType Container) {
        $files += Get-ChildItem -Path $p -Recurse -Filter $Pattern -File -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -notmatch '^(STATUS|glossary|session-handoff|MODE)\.md$' }
    } elseif (Test-Path $p) {
        $files += Get-Item $p
    } else {
        Write-Warning "路径不存在，跳过: $p"
    }
}
$files = @($files | Sort-Object FullName | Select-Object -Unique)
if ($files.Count -eq 0) { Write-Error "没有可统计的文件。"; exit 1 }

function Get-WordCount {
    param([string]$Raw)

    # 去代码块（``` ... ```）与行内代码
    $t = [regex]::Replace($Raw, '(?s)```.*?```', ' ')
    $t = [regex]::Replace($t, '`[^`]*`', ' ')
    # 去 HTML 注释与图片语法（图片题注文字一般另计，此处按不计处理）
    $t = [regex]::Replace($t, '(?s)<!--.*?-->', ' ')
    $t = [regex]::Replace($t, '!\[[^\]]*\]\([^)]*\)', ' ')
    # 去链接语法但保留链接文字：[文字](url) -> 文字
    $t = [regex]::Replace($t, '\[([^\]]*)\]\([^)]*\)', '$1')
    # 去 Markdown 标记：标题井号、强调符、表格竖线、列表标记、引用标记
    $t = [regex]::Replace($t, '(?m)^\s{0,3}#{1,6}\s*', ' ')
    $t = [regex]::Replace($t, '[*_~>|]', ' ')
    $t = [regex]::Replace($t, '(?m)^\s*[-+]\s+', ' ')
    $t = [regex]::Replace($t, '(?m)^\s*\d+[.)]\s+', ' ')
    # 去分隔线残留
    $t = [regex]::Replace($t, '(?m)^\s*-{3,}\s*$', ' ')

    $cjk   = ([regex]::Matches($t, '[\u4e00-\u9fff\u3400-\u4dbf]')).Count
    $latin = ([regex]::Matches($t, '[A-Za-z]+')).Count
    $digit = ([regex]::Matches($t, '\d+')).Count

    return [pscustomobject]@{ Cjk = $cjk; Latin = $latin; Digit = $digit; Total = ($cjk + $latin + $digit) }
}

# --- 区段切分（用于 -ExcludeRef / -ExcludeAbstract）---
function Split-Sections {
    param([string]$Raw)
    $lines = $Raw -split "`n"
    $refStart = $lines.Count; $absStart = -1; $absEnd = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($refStart -eq $lines.Count -and $lines[$i] -match '^\s*#{1,6}\s*(参考文献|References|Bibliography)\s*$') { $refStart = $i }
        if ($absStart -lt 0 -and $lines[$i] -match '^\s*#{1,6}\s*(摘要|Abstract)\s*$') { $absStart = $i }
        elseif ($absStart -ge 0 -and $absEnd -eq $lines.Count -and $i -gt $absStart -and $lines[$i] -match '^\s*#{1,6}\s*\S') { $absEnd = $i }
    }
    $body = $lines[0..([Math]::Max(0, $refStart - 1))] -join "`n"
    $abs  = if ($absStart -ge 0) { $lines[$absStart..([Math]::Max($absStart, $absEnd - 1))] -join "`n" } else { "" }
    return [pscustomobject]@{ Body = $body; Abstract = $abs; HasRef = ($refStart -lt $lines.Count); HasAbstract = ($absStart -ge 0) }
}

Write-Host "=== 字数统计报告 ==="
Write-Host ("口径：CJK 汉字 + 西文单词 + 数字串" +
    $(if ($ExcludeRef) { "，排除参考文献区" } else { "" }) +
    $(if ($ExcludeAbstract) { "，排除摘要区" } else { "" }))
Write-Host ""

$grand = 0
$rows = @()
foreach ($f in $files) {
    $raw = Get-Content $f.FullName -Raw -Encoding UTF8
    $sec = Split-Sections -Raw $raw
    $target = $sec.Body
    if (-not $ExcludeAbstract -and $sec.HasAbstract) { $target = $target } # 摘要本就在正文前，含在 Body 内
    if ($ExcludeAbstract -and $sec.HasAbstract) {
        $target = ($target -replace [regex]::Escape($sec.Abstract), ' ')
    }
    $c = Get-WordCount -Raw $target
    $grand += $c.Total
    $rows += [pscustomobject]@{ File = $f.Name; Cjk = $c.Cjk; Latin = $c.Latin; Total = $c.Total }
}

$rows | Format-Table -AutoSize | Out-String | Write-Host

if ($Verbose_Sections) {
    Write-Host "--- 区段明细 ---"
    foreach ($f in $files) {
        $sec = Split-Sections -Raw (Get-Content $f.FullName -Raw -Encoding UTF8)
        $b = Get-WordCount -Raw $sec.Body
        $a = Get-WordCount -Raw $sec.Abstract
        Write-Host ("{0}: 正文区 {1} 字 | 摘要区 {2} 字 | 含参考文献 {3}" -f $f.Name, $b.Total, $a.Total, $sec.HasRef)
    }
    Write-Host ""
}

if ($files.Count -gt 1) { Write-Host ("合计：{0} 字（{1} 个文件）" -f $grand, $files.Count); Write-Host "" }

$total = if ($files.Count -gt 1) { $grand } else { $rows[0].Total }

# --- 配额核验 ---
# 区分两种口径：期刊模式是「硬上限」（不可破，超限即退稿风险）；
# 课程模式是「区间」（上限超出扣分，下限不足扣分）。二者判定文案不同。
$issues = 0
$hardLimit = if ($Limit -gt 0) { $Limit } else { 0 }
$rangeMax  = if ($Max -gt 0) { $Max } else { $hardLimit }

if ($hardLimit -gt 0 -and $hardLimit -eq $rangeMax) {
    $pct = [Math]::Round(100.0 * $total / $hardLimit, 1)
    if ($total -gt $hardLimit) {
        Write-Host ("❌ 超出硬上限：{0} / {1} 字（{2}%），须压缩 {3} 字" -f $total, $hardLimit, $pct, ($total - $hardLimit))
        $issues++
    } elseif ($pct -ge 95) {
        Write-Host ("⚠️ 逼近硬上限：{0} / {1} 字（{2}%），余量仅 {3} 字——返修补内容极易超限" -f $total, $hardLimit, $pct, ($hardLimit - $total))
    } else {
        Write-Host ("✅ 在硬上限内：{0} / {1} 字（{2}%），余量 {3} 字" -f $total, $hardLimit, $pct, ($hardLimit - $total))
    }
} elseif ($rangeMax -gt 0) {
    if ($total -gt $rangeMax) {
        Write-Host ("❌ 超出要求区间上限：{0} / {1} 字，超出 {2} 字（课程论文超长通常不加分，须删减）" -f $total, $rangeMax, ($total - $rangeMax))
        $issues++
    } else {
        Write-Host ("✅ 未超区间上限：{0} / {1} 字（{2}%）" -f $total, $rangeMax, [Math]::Round(100.0 * $total / $rangeMax, 1))
    }
}

if ($Min -gt 0) {
    if ($total -lt $Min) {
        Write-Host ("❌ 低于下限：{0} / {1} 字，还差 {2} 字" -f $total, $Min, ($Min - $total))
        $issues++
    } else {
        Write-Host ("✅ 达到下限：{0} / {1} 字" -f $total, $Min)
    }
}

if ($hardLimit -le 0 -and $Min -le 0) {
    Write-Host ("统计合计：{0} 字（未给配额，仅统计）" -f $total)
    Write-Host "  提示：期刊论文请给 -Limit（硬上限）；课程论文请给 -Min/-Max（区间）。"
} elseif ($issues -eq 0) {
    Write-Host ""
    Write-Host "✅ 字数配额核验通过。"
    Write-Host "   注：本统计为机械口径，与目标刊/学校的具体口径可能略有差异"
    Write-Host "   （如是否含摘要、图表题注、参考文献），以对方系统统计为准。"
} else {
    Write-Host ""
    Write-Host "⚠️ 字数配额核验未通过，请按上方提示调整后重跑。"
    exit 1
}
