# check-figures.ps1 — 摘要自足性 + 图表编号引用完整性核验
#
# 两个此前完全无人检查、且会「静默通过」的缺陷类别：
#   (A) 摘要问题：超字数、结构要素缺失、出现正文指向语（摘要必须自足）、
#       摘要中的数值/样本量与方法章不一致（与 DATA.md 口径对照）
#   (B) 图表编号：正文引用「表 3」但无表 3（漏图/编号错）；有「图 2」但正文从未引用（孤儿图）；
#       编号不连续；表图编号混用；图表在正文中的首次引用顺序与编号顺序不一致
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/check-figures.ps1 -TextPath "稿件.md"
#   powershell -ExecutionPolicy Bypass -File scripts/check-figures.ps1 -TextPath "稿件.md" -MaxAbstract 300
#   powershell -ExecutionPolicy Bypass -File scripts/check-figures.ps1 -TextPath "稿件.md" -SkipAbstract
#   # 摘要结构要素（期刊常要求结构化摘要）：
#   powershell -ExecutionPolicy Bypass -File scripts/check-figures.ps1 -TextPath "稿件.md" -AbstractSections "目的,方法,结果,结论"
#
# 退出码：0 = 无问题；1 = 发现问题
#
# 注意：本文件须保存为 UTF-8 with BOM，否则 Windows PowerShell 5.1 会按 ANSI 解析中文而报错。
# 校验/修复：node -e "const fs=require('node:fs');const f='scripts/check-figures.ps1';const b=fs.readFileSync(f);if(!(b[0]===0xEF&&b[1]===0xBB&&b[2]===0xBF)){fs.writeFileSync(f,Buffer.concat([Buffer.from([0xEF,0xBB,0xBF]),b]));console.log('BOM 已补')}else{console.log('BOM 正常')}"

param(
    [Parameter(Mandatory = $true)]
    [string]$TextPath,

    [Parameter(Mandatory = $false)]
    [int]$MaxAbstract = 0,          # 摘要字数上限；0 = 不检查

    [Parameter(Mandatory = $false)]
    [string]$AbstractSections = "", # 期望的结构化摘要要素，逗号分隔，如 "目的,方法,结果,结论"

    [Parameter(Mandatory = $false)]
    [switch]$SkipAbstract,

    [Parameter(Mandatory = $false)]
    [switch]$SkipFigures
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if (-not (Test-Path $TextPath)) { Write-Error "文件不存在: $TextPath"; exit 1 }
$raw = Get-Content $TextPath -Raw -Encoding UTF8
# 统一全角空格，便于模式匹配
$raw = $raw -replace [char]0x3000, ' '

$issues = 0

Write-Host "=== 摘要自足性 + 图表编号核验报告 ==="
Write-Host "文件: $TextPath"
Write-Host ""

# ============ (A) 摘要检查 ============
if (-not $SkipAbstract) {
    Write-Host "--- (A) 摘要 ---"

    # 定位摘要区：从「摘要/Abstract」标题到下一个同级或更高级标题
    $lines = $raw -split "`n"
    $absStart = -1; $absEnd = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($absStart -lt 0 -and $lines[$i] -match '^\s*#{1,6}\s*(摘要|Abstract)\s*$') { $absStart = $i; continue }
        if ($absStart -ge 0 -and $i -gt $absStart -and $lines[$i] -match '^\s*#{1,6}\s*\S') { $absEnd = $i; break }
    }

    if ($absStart -lt 0) {
        Write-Host "⚠️ 未找到「摘要 / Abstract」标题行——无法检查。"
        Write-Host "   （若本稿件类型确实不需要摘要，如部分书评，可加 -SkipAbstract 跳过）"
    } else {
        $absLines = $lines[($absStart + 1)..([Math]::Max($absStart + 1, $absEnd - 1))]
        $absText = ($absLines -join "`n").Trim()
        # 去 Markdown 标记后计字数
        $absPlain = $absText -replace '(?m)^\s*#{1,6}\s*', '' -replace '[*_~>|]', ' '
        $absPlain = $absPlain -replace '(?m)^\s*[-+]\s+', ' '
        $cjk = ([regex]::Matches($absPlain, '[\u4e00-\u9fff]')).Count
        $lat = ([regex]::Matches($absPlain, '[A-Za-z]+')).Count
        $dgt = ([regex]::Matches($absPlain, '\d+')).Count
        $absCount = $cjk + $lat + $dgt
        Write-Host "   摘要字数（CJK+西文词+数字）: $absCount"

        if ($MaxAbstract -gt 0) {
            if ($absCount -gt $MaxAbstract) {
                Write-Host "   ❌ 摘要超限：$absCount / $MaxAbstract 字，须压缩 $($absCount - $MaxAbstract) 字"
                $issues++
            } else {
                Write-Host "   ✅ 摘要在上限内（$absCount / $MaxAbstract）"
            }
        }

        # 结构化摘要要素检查
        if ($AbstractSections) {
            $want = $AbstractSections -split '[,，]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            $missing = @()
            foreach ($w in $want) {
                if ($absText -notmatch [regex]::Escape($w)) { $missing += $w }
            }
            if ($missing) {
                Write-Host "   ❌ 结构化摘要缺少要素: $($missing -join ', ')"
                $issues++
            } else {
                Write-Host "   ✅ 结构化摘要要素齐全（$($want -join '/')）"
            }
        }

        # 自足性：摘要不应出现指向正文的表述
        # 逐位置扫描（而非逐模式 -match），这样重叠匹配只算一次，
        # 避免「详见第二章」同时命中 '见第…' 与 '详见第…' 而被重复计数。
        $selfRefRe = '(?:如前所述|如后所述|下文将|上文已|参见第[一二三四五六七八九十\d]+[章节]|' +
                     '(?:详见|见)第[一二三四五六七八九十\d]+[章节部分]|本[章节]将(?:在|于)后|' +
                     '(?:见|参见|详见)\s*[图表]\s*\d{1,2})'
        $selfRefs = @()
        foreach ($m in [regex]::Matches($absText, $selfRefRe)) { $selfRefs += $m.Value }
        if ($selfRefs) {
            Write-Host "   ❌ 摘要出现指向正文的表述（摘要必须自足）：$((@($selfRefs | Select-Object -Unique)) -join ' / ')"
            $issues++
        } else {
            Write-Host "   ✅ 摘要自足（未检出指向正文的表述）"
        }

        # 摘要不应含引用编号（多数体例不要求在摘要中引注）
        $absCites = @([regex]::Matches($absText, '\[\d{1,3}\]') | ForEach-Object { $_.Value })
        if ($absCites.Count -gt 0) {
            Write-Host "   ⚠️ 摘要中出现引注编号 $((@($absCites | Select-Object -Unique)) -join ', ')——多数体例要求摘要不引注，请核对目标刊/学校要求"
        }

        # 摘要中的样本量，供与方法章/表注交叉核对
        $ns = @([regex]::Matches($absText, '[Nn]\s*=\s*(\d{1,7})') | ForEach-Object { $_.Groups[1].Value })
        if ($ns.Count -gt 0) {
            Write-Host "   ℹ️ 摘要中的样本量: N = $((@($ns | Select-Object -Unique)) -join ', ')"
            Write-Host "      → 请与 DATA.md / _分析结果_最新.md / 各表注的 N 逐处核对（样本量不一致是高频硬伤）"
        }
    }
    Write-Host ""
}

# ============ (B) 图表编号检查 ============
if (-not $SkipFigures) {
    Write-Host "--- (B) 图表编号引用完整性 ---"

    # 1) 正文中的图表引用（宽松匹配：表 3 / 表3 / 图 2 / 图2；含 Table 3 / Figure 2）
    $refRe = '(?<type>表|图|Table|Figure|Tab\.|Fig\.)\s*(?<num>\d{1,2})'
    $refs = @()
    foreach ($m in [regex]::Matches($raw, $refRe)) {
        $t = $m.Groups['type'].Value
        $norm = switch -Regex ($t) {
            '^(表|Table|Tab\.)$' { '表' }
            '^(图|Figure|Fig\.)$' { '图' }
            default { $t }
        }
        $refs += [pscustomobject]@{ Type = $norm; Num = [int]$m.Groups['num'].Value }
    }

    # 2) 图表题注声明
    #    单一正则太脆（「表 3：样本描述」这类行首题注，与正文内「见表 3」高度相似）。
    #    故用多重启发式合并，并剔除明显是「提及」而非「声明」的行：
    #      (a) 行首「表 N：/./、」——后接标点，典型题注；
    #      (b) 行首加粗「**表 N」；
    #      (c) 行内「表 N：」——后接中文标点冒号，正文提及极少这样用；
    #      (d) 行内含「（表 N…）」「(表 N…)」——括注题注常见形式；
    #      (e) Markdown 图片语法 ![题注](path)
    #    排除：行内先出现「见/如/参见 + 表 N」的提及式用法。
    #    关键排除项（否则会产生假阳性）：
    #      · Markdown 表格行（以 | 开头者）——表内「表 N」字样不是题注。
    #        实测曾把表体里的一行「表 4：稳健性检验」当成题注，凭空造出一个"孤儿表 4"。
    #      · 代码围栏内的内容
    #      · 标题行
    #      · 「见/参见/详见 + 表 N」这类提及式用法
    $capPatterns = @(
        '(?m)^\s*(?:\*\*|__)?(?<type>表|图)\s*(?<num>\d{1,2})\s*[：:\.、]',
        '(?m)^\s*(?:\*\*|__)(?<type>表|图)\s*(?<num>\d{1,2})\b',
        '(?<type>表|图)\s*(?<num>\d{1,2})\s*[：:]',
        '[（(]\s*(?<type>表|图)\s*(?<num>\d{1,2})\s*[^）)]*[）)]',
        '!\[[^\]]*?(?<type>表|图)\s*(?<num>\d{1,2})[^\]]*?\]\([^)]*\)'
    )
    # 「提及式」上下文：这些词紧邻编号时，视为正文引用而非题注
    $mentionRe = '(见|如|参见|详见|据|依|按)\s*(表|图)\s*\d{1,2}'

    $caps = @()
    $inFence = $false
    foreach ($ln in ($raw -split "`n")) {
        if ($ln -match '^\s*```') { $inFence = -not $inFence; continue }   # 代码围栏
        if ($inFence) { continue }
        if ($ln -match '^\s*#{1,6}\s') { continue }        # 标题行不含题注
        if ($ln -match '^\s*\|') { continue }              # Markdown 表格行，非题注
        if ($ln -match $mentionRe) { continue }             # 提及式，跳过
        $hit = $false
        foreach ($p in $capPatterns) {
            foreach ($m in [regex]::Matches($ln, $p)) {
                $caps += [pscustomobject]@{ Type = $m.Groups['type'].Value; Num = [int]$m.Groups['num'].Value }
                $hit = $true
            }
            if ($hit) { break }                             # 一行只按一种模式计，避免重复
        }
    }

    # 去重
    $refSet = @($refs | Select-Object -Unique Type, Num | Sort-Object Type, Num)
    $capSet = @($caps | Select-Object -Unique Type, Num | Sort-Object Type, Num)

    $refTables = @($refSet | Where-Object { $_.Type -eq '表' })
    $refFigs   = @($refSet | Where-Object { $_.Type -eq '图' })
    $capTables = @($capSet | Where-Object { $_.Type -eq '表' })
    $capFigs   = @($capSet | Where-Object { $_.Type -eq '图' })

    Write-Host ("   正文引用: 表 {0} 处编号 / 图 {1} 处编号" -f $refTables.Count, $refFigs.Count)
    Write-Host ("   题注声明: 表 {0} 个 / 图 {1} 个" -f $capTables.Count, $capFigs.Count)

    if ($refTables.Count -eq 0 -and $refFigs.Count -eq 0 -and $capTables.Count -eq 0 -and $capFigs.Count -eq 0) {
        Write-Host "   ⚠️ 未检出任何图表引用或题注——本稿件可能确无图表，或图表采用了脚本不识别的格式。"
        Write-Host "      若确有图表，请确认题注以「表 N」「图 N」开头。"
    } else {
        # 逐个类型比对
        foreach ($pair in @(@{T='表'; R=$refTables; C=$capTables}, @{T='图'; R=$refFigs; C=$capFigs})) {
            $T = $pair.T
            $rn = @($pair.R | ForEach-Object { $_.Num })
            $cn = @($pair.C | ForEach-Object { $_.Num })

            # ① 正文引用了但无题注（漏图 / 编号错）
            $missing = @($rn | Where-Object { $_ -notin $cn })
            if ($missing) {
                Write-Host "   ❌ 正文引用了$T $((($missing | Sort-Object) -join "、$T "))，但未找到对应题注（漏图或编号写错）"
                $issues++
            }

            # ② 有题注但正文从未引用（孤儿图表）
            $orphan = @($cn | Where-Object { $_ -notin $rn })
            if ($orphan) {
                Write-Host "   ❌ $T $((($orphan | Sort-Object) -join "、$T ")) 有题注但正文从未引用（孤儿图表）"
                $issues++
            }

            # ③ 编号连续性（题注侧）
            if ($cn.Count -gt 0) {
                $max = ($cn | Measure-Object -Maximum).Maximum
                $gap = @(1..$max | Where-Object { $_ -notin $cn })
                if ($gap) {
                    Write-Host "   ❌ $T 编号不连续（题注缺号）: $T $($gap -join "、$T ")"
                    $issues++
                }
            }

            if (-not $missing -and -not $orphan) {
                if ($rn.Count -gt 0) { Write-Host "   ✅ $T 的正文引用与题注一一对应（共 $($rn.Count) 个）" }
            }
        }

        # ④ 图表编号跳跃（正文引用侧）——正文应按编号顺序首次引用
        foreach ($pair in @(@{T='表'; R=$refTables}, @{T='图'; R=$refFigs})) {
            $T = $pair.T
            if ($pair.R.Count -lt 2) { continue }
            $order = @()
            foreach ($m in [regex]::Matches($raw, $refRe)) {
                $tt = $m.Groups['type'].Value
                $norm = switch -Regex ($tt) { '^(表|Table|Tab\.)$' { '表' } '^(图|Figure|Fig\.)$' { '图' } default { $tt } }
                if ($norm -eq $T) {
                    $n = [int]$m.Groups['num'].Value
                    if ($order -notcontains $n) { $order += $n }
                }
            }
            $sorted = @($order | Sort-Object)
            if (($order -join ',') -ne ($sorted -join ',')) {
                Write-Host "   ⚠️ $T 在正文中的首次引用顺序与编号顺序不一致（引用序: $($order -join ',') / 编号序: $($sorted -join ',')）"
                Write-Host "      多数体例要求图表按编号顺序首次出现，请核对"
            }
        }
    }
    Write-Host ""
}

# ============ 结论 ============
if ($issues -eq 0) {
    Write-Host "✅ 摘要与图表编号核验通过。"
    Write-Host "   注：图表检查依赖题注以「表 N」「图 N」开头；若你的稿件另有题注格式，请据实调整。"
} else {
    Write-Host "⚠️ 发现 $issues 类问题，请修正后重跑。"
    exit 1
}
