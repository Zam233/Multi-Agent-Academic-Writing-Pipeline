# ledger-impact.ps1 — 修订影响分析（跨章依赖传播）
#
# 解决的问题：改动一处后，「还有什么地方需要跟着改」靠人回忆必然遗漏。
# 纯文本写作没有编译器，改一个核心论点不会报错——本脚本提供缺失的那张"依赖图"。
#
# 输入：项目根 LEDGER.md（论点与依赖台账，模板见 templates/LEDGER.md）
# 输出：受影响节清单（按传导深度分级）+ 建议的修订动作
#
# 传导规则（按依赖类型分级，见 docs/rewrite-protocol.md）：
#   概念依赖 → 深度 1（须重写论证）
#   证据依赖 → 深度 1（须重核数值与论证）
#   引用依赖 → 深度 2（须修订引述）
#   风格依赖 → 深度 3（建议复核）
# 传播是**传递**的：若 S3 依赖 S2、S4 依赖 S3，则改动 S2 会同时命中 S3 与 S4。
#
# 用法：
#   # 某个论点被替换，看谁受影响
#   powershell -ExecutionPolicy Bypass -File scripts/ledger-impact.ps1 -Ledger LEDGER.md -Changed C2
#
#   # 指定变更类型（影响建议文案）
#   powershell -ExecutionPolicy Bypass -File scripts/ledger-impact.ps1 -Ledger LEDGER.md -Changed C2 -ChangeType 替换
#
#   # 只看直接依赖，不做传递闭包
#   powershell -ExecutionPolicy Bypass -File scripts/ledger-impact.ps1 -Ledger LEDGER.md -Changed C2 -Direct
#
#   # 输出到文件（供 steward 归档、写入变更记录）
#   powershell -ExecutionPolicy Bypass -File scripts/ledger-impact.ps1 -Ledger LEDGER.md -Changed C2 -OutPath "_影响清单_最新.md"
#
#   # 台账自检（不指定 -Changed）：查悬空引用、孤立节、循环依赖
#   powershell -ExecutionPolicy Bypass -File scripts/ledger-impact.ps1 -Ledger LEDGER.md
#
# 退出码：0 = 正常；1 = 台账自检发现结构错误（悬空引用/循环依赖）
#
# 注意：本文件须保存为 UTF-8 with BOM，否则 Windows PowerShell 5.1 会按 ANSI 解析中文而报错。
# 校验/修复：node -e "const fs=require('node:fs');const f='scripts/ledger-impact.ps1';const b=fs.readFileSync(f);if(!(b[0]===0xEF&&b[1]===0xBB&&b[2]===0xBF)){fs.writeFileSync(f,Buffer.concat([Buffer.from([0xEF,0xBB,0xBF]),b]));console.log('BOM 已补')}else{console.log('BOM 正常')}"

param(
    [Parameter(Mandatory = $false)]
    [string]$Ledger = "LEDGER.md",

    [Parameter(Mandatory = $false)]
    [string]$Changed = "",

    [Parameter(Mandatory = $false)]
    [string]$ChangeType = "替换",

    [Parameter(Mandatory = $false)]
    [switch]$Direct,

    [Parameter(Mandatory = $false)]
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if (-not (Test-Path $Ledger)) {
    Write-Error "未找到台账文件: $Ledger（模板见 templates/LEDGER.md）"
    exit 1
}
$lines = Get-Content $Ledger -Encoding UTF8

# ---------- 解析：按二级标题切分小节 ----------
function Get-Section {
    param([string[]]$All, [string]$TitlePattern)
    $start = -1; $end = $All.Count
    for ($i = 0; $i -lt $All.Count; $i++) {
        if ($start -lt 0 -and $All[$i] -match "^\s*##\s*.*$TitlePattern") { $start = $i; continue }
        if ($start -ge 0 -and $i -gt $start -and $All[$i] -match '^\s*##\s') { $end = $i; break }
    }
    if ($start -lt 0) { return @() }
    return @($All[($start + 1)..([Math]::Max($start + 1, $end - 1))])
}

function Parse-Table {
    param([string[]]$Block, [string[]]$RequiredCols)
    # 找表头行（含 | 且包含全部必需列名）
    $header = $null; $hIdx = -1
    for ($i = 0; $i -lt $Block.Count; $i++) {
        $ln = $Block[$i]
        if ($ln -notmatch '\|') { continue }
        $cols = ($ln.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() }
        $ok = $true
        foreach ($c in $RequiredCols) { if ($cols -notcontains $c) { $ok = $false; break } }
        if ($ok) { $header = $cols; $hIdx = $i; break }
    }
    if (-not $header) { return @() }
    $rows = @()
    for ($i = $hIdx + 1; $i -lt $Block.Count; $i++) {
        $ln = $Block[$i]
        if ($ln -notmatch '\|') { if ($ln.Trim() -eq '') { continue } else { break } }
        $cells = ($ln.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() }
        if ($cells.Count -lt $header.Count) { continue }
        if ($cells[0] -match '^[-: ]+$') { continue }   # 分隔行
        $obj = @{}
        for ($j = 0; $j -lt $header.Count; $j++) { $obj[$header[$j]] = $cells[$j] }
        $rows += ,$obj
    }
    return $rows
}

$secRows   = Get-Section -All $lines -TitlePattern '节清单'
$secClaims = Get-Section -All $lines -TitlePattern '论点登记'
$secDeps   = Get-Section -All $lines -TitlePattern '依赖登记'

$nodes = @{}
foreach ($r in (Parse-Table -Block $secRows -RequiredCols @('ID', '节标题'))) {
    if ($r['ID']) { $nodes[$r['ID']] = [pscustomobject]@{ Id = $r['ID']; Title = $r['节标题']; Kind = 'S' } }
}
foreach ($r in (Parse-Table -Block $secClaims -RequiredCols @('ID', '论点表述'))) {
    if ($r['ID']) { $nodes[$r['ID']] = [pscustomobject]@{ Id = $r['ID']; Title = $r['论点表述']; Kind = 'C'; Criticality = $r['关键性'] } }
}

$deps = @()
foreach ($r in (Parse-Table -Block $secDeps -RequiredCols @('来源', '依赖对象'))) {
    if ($r['来源'] -and $r['依赖对象']) {
        $deps += [pscustomobject]@{ From = $r['来源']; To = $r['依赖对象']; Type = $r['依赖类型']; Note = $r['说明'] }
    }
}

if ($nodes.Count -eq 0) {
    Write-Error "未能从 $Ledger 解析出任何节点。请确认台账使用 templates/LEDGER.md 的固定列名（ID/节标题/论点表述）。"
    exit 1
}

# ---------- 结构自检 ----------
Write-Host "=== 台账自检 ==="
Write-Host "节点: $($nodes.Count) 个（节 $(@($nodes.Values | Where-Object { $_.Kind -eq 'S' }).Count) ／ 论点 $(@($nodes.Values | Where-Object { $_.Kind -eq 'C' }).Count)）"
Write-Host "依赖边: $($deps.Count) 条"

$selfIssues = 0

# 悬空引用
$dangling = @()
foreach ($d in $deps) {
    if (-not $nodes.ContainsKey($d.From)) { $dangling += "$($d.From) → $($d.To)（来源 $($d.From) 未定义）" }
    if (-not $nodes.ContainsKey($d.To))   { $dangling += "$($d.From) → $($d.To)（依赖对象 $($d.To) 未定义）" }
}
if ($dangling) {
    Write-Host "❌ 悬空引用（引用了台账中不存在的 ID）:"
    $dangling | Sort-Object -Unique | ForEach-Object { Write-Host "   $_" }
    $selfIssues++
} else {
    Write-Host "✅ 无悬空引用"
}

# 孤立节点（既无出边也无入边）——节可能正常（如结论），但论点孤立通常意味着漏登记
$isolatedC = @()
foreach ($n in ($nodes.Values | Where-Object { $_.Kind -eq 'C' })) {
    $has = ($deps | Where-Object { $_.From -eq $n.Id -or $_.To -eq $n.Id })
    if (-not $has) { $isolatedC += "$($n.Id)（$($n.Title)）" }
}
if ($isolatedC) {
    Write-Host "⚠️ 孤立论点（无任何依赖边，可能漏登记依赖）:"
    $isolatedC | ForEach-Object { Write-Host "   $_" }
} else {
    Write-Host "✅ 无孤立论点"
}

# 循环依赖检测：用 DFS 的"递归栈"（白/灰/黑三色），而非枚举所有路径。
# 枚举路径会在存在环时呈指数爆炸（实测：S1↔S2 互依时递归被调用上万次）。
$adj = @{}
foreach ($n in $nodes.Keys) { $adj[$n] = @() }
foreach ($d in $deps) { if ($adj.ContainsKey($d.From)) { $adj[$d.From] += $d.To } }

$color = @{}                                   # 0/缺省=白(未访问) 1=灰(在栈上) 2=黑(已完成)
foreach ($n in $nodes.Keys) { $color[$n] = 0 }
$script:cycles = @()
$script:stack = @()

function Visit-Node {
    param([string]$Node)
    $color[$Node] = 1
    $script:stack += $Node
    foreach ($nx in $adj[$Node]) {
        if (-not $color.ContainsKey($nx)) { continue }
        if ($color[$nx] -eq 1) {
            # 回边 ⇒ 有环。截取栈中从 $nx 起的一段作为环路径
            $idx = [Array]::IndexOf($script:stack, $nx)
            if ($idx -ge 0) {
                $cyc = @($script:stack[$idx..($script:stack.Count - 1)]) + $nx
                $script:cycles += ($cyc -join ' → ')
            }
        } elseif ($color[$nx] -eq 0) {
            Visit-Node -Node $nx
        }
    }
    $script:stack = @($script:stack | Where-Object { $_ -ne $Node })
    $color[$Node] = 2
}

foreach ($n in $nodes.Keys) { if ($color[$n] -eq 0) { Visit-Node -Node $n } }
$cycles = @($script:cycles | Select-Object -Unique)
if ($cycles) {
    Write-Host "⚠️ 检出循环依赖（改动会无限传导，请确认是否合理）:"
    $cycles | Select-Object -First 5 | ForEach-Object { Write-Host "   $_" }
} else {
    Write-Host "✅ 无循环依赖"
}
Write-Host ""

# ---------- 影响传播 ----------
if (-not $Changed) {
    Write-Host "（未指定 -Changed，仅做自检。用法示例：-Changed C2 -ChangeType 替换）"
    if ($selfIssues -gt 0) { exit 1 }
    exit 0
}

if (-not $nodes.ContainsKey($Changed)) {
    Write-Error "台账中不存在 ID: $Changed"
    exit 1
}

# 两套度量，含义不同，不可混用：
#   Hops  = 从变更点算起的**跳数**（结构距离）
#   Grade = 传导链上**最弱**的依赖类型决定的处理等级（动作强度）
# 早期版本把依赖类型的等级当成跳数传播，导致 2 跳之外（C1→S2→S3→S4）被报成同等级别，
# 掩盖了"越远越弱"的事实。
$gradeByType = @{ '概念依赖' = 1; '证据依赖' = 1; '引用依赖' = 2; '风格依赖' = 3 }
function Grade-Of { param([string]$T) if ($gradeByType.ContainsKey($T)) { return $gradeByType[$T] } return 2 }

# 反向边索引：To → 依赖它的 From（即"谁依赖我"）
$rev = @{}
foreach ($d in $deps) {
    if (-not $rev.ContainsKey($d.To)) { $rev[$d.To] = @() }
    $rev[$d.To] += $d
}

$affected = @{}   # id → [pscustomobject]
$queue = @([pscustomobject]@{ Id = $Changed; Hops = 0; Grade = 0; Via = $null })

while ($queue.Count -gt 0) {
    $cur = $queue[0]; $queue = @($queue | Select-Object -Skip 1)
    if (-not $rev.ContainsKey($cur.Id)) { continue }
    foreach ($e in $rev[$cur.Id]) {
        $newHops = $cur.Hops + 1
        # 链上取最弱等级（数值最大者）：任一段是"风格依赖"，整条链就只能算建议复核
        $edgeGrade = Grade-Of -T $e.Type
        $newGrade = if ($cur.Hops -eq 0) { $edgeGrade } else { [Math]::Max($edgeGrade, $cur.Grade) }
        if ($Direct -and $cur.Hops -gt 0) { continue }

        $isBetter = $true
        if ($affected.ContainsKey($e.From)) {
            # 已有更短路径则不再更新；同跳数时取更弱等级
            if ($affected[$e.From].Hops -lt $newHops) { $isBetter = $false }
            elseif ($affected[$e.From].Hops -eq $newHops -and $affected[$e.From].Grade -ge $newGrade) { $isBetter = $false }
        }
        if ($isBetter) {
            $affected[$e.From] = [pscustomobject]@{ Id = $e.From; Hops = $newHops; Grade = $newGrade; Via = $cur.Id; Type = $e.Type; Note = $e.Note }
            $queue += [pscustomobject]@{ Id = $e.From; Hops = $newHops; Grade = $newGrade; Via = $cur.Id }
        }
    }
}

$target = $nodes[$Changed]
$kindLabel = if ($target.Kind -eq 'S') { '节' } else { '论点' }

$out = @()
$out += "# 修订影响清单（自动生成）"
$out += ""
$out += "- 生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$out += "- 台账文件：$Ledger"
$out += "- 变更对象：**$Changed**（$kindLabel：$($target.Title)）"
$out += "- 变更类型：**$ChangeType**"
$out += $(if ($Direct) { "- 传导范围：仅直接依赖（-Direct）" } else { "- 传导范围：传递闭包（含间接依赖）" })
$out += ""

if ($affected.Count -eq 0) {
    $out += "✅ **无其他节受影响**——本次变更不触及台账中登记的依赖。"
    $out += ""
    $out += "> 注意：这只说明**已登记的**依赖未受影响。若本次变更属于论证层面的实质改动，"
    $out += "> 仍建议由 planner 做一次语义复核（台账只记录显式登记过的依赖）。"
} else {
    $actionByGrade = @{
        1 = '**须重写论证**（重写该节论证或至少重写受影响的段落）'
        2 = '**须修订引述**（引述处改为与新论点一致）'
        3 = '**建议复核**（术语/风格层面，全文检索替换即可）'
    }
    $out += "受影响节共 **$($affected.Count)** 个："
    $out += ""
    $out += "| 受影响 ID | 名称 | 跳数 | 处理等级 | 依赖类型 | 传导路径 | 建议动作 |"
    $out += "|---|---|---|---|---|---|---|"
    foreach ($a in ($affected.Values | Sort-Object Hops, Grade, Id)) {
        $name = if ($nodes.ContainsKey($a.Id)) { $nodes[$a.Id].Title } else { '(未登记)' }
        $act = if ($actionByGrade.ContainsKey($a.Grade)) { $actionByGrade[$a.Grade] } else { '复核' }
        $gradeLabel = if ($a.Grade -eq 1) { '重写' } elseif ($a.Grade -eq 2) { '修订' } else { '复核' }
        # 完整路径：沿 Via 回溯到变更点
        $chain = @($a.Id)
        $cursor = $a
        $guard = 0
        while ($cursor.Via -and $cursor.Via -ne $Changed -and $guard -lt 20) {
            $chain = @($cursor.Via) + $chain
            $cursor = if ($affected.ContainsKey($cursor.Via)) { $affected[$cursor.Via] } else { [pscustomobject]@{ Via = $null } }
            $guard++
        }
        $path = "$Changed → " + ($chain -join ' → ')
        $out += "| $($a.Id) | $name | $($a.Hops) | $gradeLabel | $($a.Type) | $path | $act |"
    }
    $out += ""
    $out += "> **跳数**是从变更点算起的结构距离；**处理等级**由传导链上最弱的一环决定"
    $out += "> （链上只要有一段是「风格依赖」，整条链就只需复核）。两者一起决定该花多少力气。"
    $out += ""
    $out += "## 处理顺序建议"
    $out += ""
    $out += "**先按处理等级、再按跳数**从轻到重处理——等级 1（重写）是论证根基，应先改根基再改引述："
    $out += ""
    foreach ($grade in @(1, 2, 3)) {
        $grp = @($affected.Values | Where-Object { $_.Grade -eq $grade } | Sort-Object Hops, Id)
        if ($grp.Count -eq 0) { continue }
        $label = if ($grade -eq 1) { '等级 1 · 须重写论证' } elseif ($grade -eq 2) { '等级 2 · 须修订引述' } else { '等级 3 · 建议复核' }
        $out += "- **$label**（$($grp.Count) 个）：$(($grp | ForEach-Object { "$($_.Id)(跳$($_.Hops))" }) -join '、')"
    }
    $out += ""
    $out += "## 后续动作（steward 执行）"
    $out += ""
    $out += "1. 把这些节的 `STATUS.md` 状态改为 `需重审`；"
    $out += "2. 在 `LEDGER.md` 的「变更记录」追加一行（变更对象 / 类型 / 本清单 / 处理中）；"
    $out += "3. 由 planner 对每个**等级 1** 的节重新规划 → writer 重写 → auditor 重审；"
    $out += "4. 全部处理完，把变更记录状态改为 `已完成`。"
}

$report = $out -join "`n"
Write-Host $report

if ($OutPath) {
    Set-Content -Path $OutPath -Value $report -Encoding UTF8
    Write-Host ""
    Write-Host "✅ 已写出影响清单: $OutPath"
}

if ($selfIssues -gt 0) { exit 1 }
exit 0
