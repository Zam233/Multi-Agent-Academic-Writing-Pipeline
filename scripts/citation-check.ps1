# citation-check.ps1 — 引用三对照核验（机械部分）
#
# 三对照 = ①正文引注 ②文末参考文献表 ③文献库条目
# 本脚本自动完成 ①② 的机械核对（③需 librarian 人工对照，脚本输出核对单）。
#
# 引注体系随 MODE.md 的 citation_style 而定：
#   -Style numbered    顺序编码制 [n]（中文学位论文与部分中文期刊默认）
#   -Style author-date 著者-年制 （作者, 年份）（课程论文默认、部分社科期刊使用）
#   脚注体例（footnote）暂无脚本支持，须人工核验。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/citation-check.ps1 -TextPath "第三章正文.md"
#   powershell -ExecutionPolicy Bypass -File scripts/citation-check.ps1 -TextPath "论文.md" -Style numbered
#   powershell -ExecutionPolicy Bypass -File scripts/citation-check.ps1 -TextPath "课程论文.md" -Style author-date
#   powershell -ExecutionPolicy Bypass -File scripts/citation-check.ps1 -TextPath "论文.md" -RefHeading "参考文献"

param(
    [Parameter(Mandatory = $true)]
    [string]$TextPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet("numbered", "author-date")]
    [string]$Style = "numbered",

    [Parameter(Mandatory = $false)]
    [string]$RefHeading = "参考文献"
)

$ErrorActionPreference = "Stop"

# --- 控制台按 UTF-8 输出，避免中文报告乱码 ---
# 注意：若在 Windows PowerShell 5.1 下运行且本文件丢失 UTF-8 BOM，脚本自身的中文会被按 ANSI 解析而报错。
# 校验/修复：node -e "const fs=require('node:fs');const f='scripts/citation-check.ps1';const b=fs.readFileSync(f);if(!(b[0]===0xEF&&b[1]===0xBB&&b[2]===0xBF)){fs.writeFileSync(f,Buffer.concat([Buffer.from([0xEF,0xBB,0xBF]),b]));console.log('BOM 已补')}else{console.log('BOM 正常')}"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if (-not (Test-Path $TextPath)) { Write-Error "文件不存在: $TextPath"; exit 1 }
$lines = Get-Content $TextPath -Encoding UTF8

# --- 切分正文区与参考文献区 ---
$refStart = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s*#{1,3}\s*$([regex]::Escape($RefHeading))\s*$") { $refStart = $i; break }
}
if ($refStart -lt 0) { Write-Warning "未找到『$RefHeading』标题行，将全文视为正文区处理。"; $refStart = $lines.Count }

$body = $lines[0..($refStart - 1)] -join "`n"
$refBlock = if ($refStart -lt $lines.Count) { $lines[$refStart..($lines.Count - 1)] -join "`n" } else { "" }

$issues = 0

function Get-YearTokens {
    param([string]$Text)
    # 抓取 4 位年份（19xx/20xx），用于著者-年制的年份比对
    return @([regex]::Matches($Text, '\b(?:19|20)\d{2}[a-z]?\b') | ForEach-Object { $_.Value })
}

if ($Style -eq "numbered") {

    # ============ 顺序编码制：正文 [n] ⇄ 文末 [n] ============
    # 支持 [n]、[n][m]、[n-m]（连续引用简写，GB/T 7714）三种形态
    $citeNums = [regex]::Matches($body, '\[(\d{1,3}(?:-\d{1,3})?)\]') | ForEach-Object {
        $tok = $_.Groups[1].Value
        if ($tok -match '^(\d{1,3})-(\d{1,3})$') { [int]$Matches[1]..[int]$Matches[2] } else { [int]$tok }
    }
    $refNums = [regex]::Matches($refBlock, '^\[(\d{1,3})\]', [System.Text.RegularExpressions.RegexOptions]::Multiline) |
               ForEach-Object { [int]$_.Groups[1].Value }
    $refNums = @($refNums | Select-Object -Unique)

    $firstOrder = @($citeNums | Select-Object -Unique)   # 首次出现顺序 = 顺序编码制要求
    $bodySet = @($citeNums | Select-Object -Unique | Sort-Object)
    $refSet = @($refNums | Sort-Object)

    Write-Host "=== 引用三对照核验报告（顺序编码制）==="
    Write-Host "正文引注编号（首次出现顺序）: $($firstOrder -join ', ')"
    Write-Host "文末参考文献编号: $($refSet -join ', ')  ($($refSet.Count) 条)"
    Write-Host ""

    # 1) 正文引用但文末缺失
    $missing = $bodySet | Where-Object { $_ -notin $refSet }
    if ($missing) { Write-Host "❌ 正文引用但文末缺失: $($missing -join ', ')"; $issues++ }
    else { Write-Host "✅ 所有正文引注均能在文末找到对应条目" }

    # 2) 文末存在但正文未引
    $orphan = $refSet | Where-Object { $_ -notin $bodySet }
    if ($orphan) { Write-Host "❌ 文末有条目但正文从未引用: $($orphan -join ', ')（孤儿条目）"; $issues++ }

    # 3) 顺序编码制：编号应 = 1..N（首次出现序号即编号，无跳号）
    if ($bodySet.Count -gt 0) {
        $expect = 1..$bodySet[-1]
        $gap = $expect | Where-Object { $_ -notin $bodySet }
        if ($gap) { Write-Host "❌ 编号不连续（存在跳号）: $($gap -join ', ')"; $issues++ }
        else { Write-Host "✅ 编号连续（1..$($bodySet[-1])）" }
    }

    # 4) 重复引用检查
    $dup = $citeNums | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($dup) { Write-Host "ℹ️ 以下编号被多次引用（符合顺序编码制沿用规则，无需处理）: $(($dup | ForEach-Object { "$($_.Name)x$($_.Count)" }) -join ', ')" }

    Write-Host ""
    if ($issues -eq 0) {
        Write-Host "✅ 机械核对通过。请人工完成第三对照：将下列编号与文献库条目逐一对应——"
        $firstOrder | ForEach-Object { Write-Host "   [$($_)] → 文献库条目: （待填）" }
    } else {
        Write-Host "⚠️ 发现 $issues 类问题，请修正后重跑。"
        exit 1
    }

} else {

    # ============ 著者-年制：正文 （作者, 年份） ⇄ 文末按字母序条目 ============
    # 正文引注形态：(作者, 2020) / （作者，2020） / (Author, 2020) / (Author & Other, 2020a) / (Author et al., 2020)
    $citeText = @()
    $citeMatches = [regex]::Matches($body, '[（(]([^（）()]{2,80}?)[,，]\s*((?:19|20)\d{2}[a-z]?)[)）]')
    foreach ($m in $citeMatches) {
        $authorsRaw = $m.Groups[1].Value
        $year = $m.Groups[2].Value
        # 排除非引注形态（如 "（见表 1, 2020）" 之类含数字/单位的）
        if ($authorsRaw -match '^\s*\d') { continue }
        $citeText += [pscustomobject]@{ Raw = $m.Value; Authors = $authorsRaw.Trim(); Year = $year }
    }

    # 文末参考文献条目：以列表标记或段落开头的非空行（排除标题与说明行）
    # 文末参考文献条目：排除标题、引用块与说明行；合法著者-年制条目必含 4 位年份，
    # 以此作为准入条件，避免把说明性文字误判为条目
    $refEntries = @()
    foreach ($ln in ($refBlock -split "`n")) {
        $t = $ln.Trim()
        if ($t.Length -lt 8) { continue }
        if ($t -match '^[>!]') { continue }                       # 引用块 / 提示行
        if ($t -match '^#{1,6}\s') { continue }                   # 小标题
        if ($t -match '^[>|\-]{1,}\s*$') { continue }             # 分隔线
        if ($t -match '^[（(]?\d{1,3}[)）.、]\s') { continue }     # 编号制残留，非著者-年条目
        $t = $t -replace '^[-*+]\s+', ''                          # 去列表标记
        if ($t -notmatch '(?:19|20)\d{2}') { continue }           # 无年份 ⇒ 非文献条目
        $refEntries += $t
    }

    $refYears = @()
    foreach ($r in $refEntries) { $refYears += (Get-YearTokens -Text $r) }

    Write-Host "=== 引用三对照核验报告（著者-年制）==="
    Write-Host "正文引注条数: $($citeText.Count)"
    Write-Host "文末参考文献条数: $($refEntries.Count)"
    Write-Host ""

    if ($citeText.Count -eq 0) {
        Write-Host "⚠️ 未在正文中检出著者-年制引注（形如 （作者, 2020））。"
        Write-Host "   若本文实际使用编号制，请改用 -Style numbered；若使用脚注体例，请人工核验。"
        $issues++
    }

    if ($refEntries.Count -eq 0) {
        Write-Host "⚠️ 未在『$RefHeading』区检出参考文献条目。"
        $issues++
    }

    # 1) 正文引注的作者是否能在文末找到（按姓氏/首作者片段匹配）
    $unmatched = @()
    foreach ($c in $citeText) {
        $key = ($c.Authors -split '[,，&和、]')[0].Trim()
        if ($key.Length -lt 2) { $key = $c.Authors }
        $hit = $refEntries | Where-Object { $_ -like "*$key*" -and $_ -match [regex]::Escape($c.Year) }
        if (-not $hit) {
            $hitLoose = $refEntries | Where-Object { $_ -like "*$key*" }
            if (-not $hitLoose) { $unmatched += "$($c.Raw)  ← 文末未见该作者条目" }
            else { $unmatched += "$($c.Raw)  ← 文末有该作者条目但年份不符（疑年份错误）" }
        }
    }
    $unmatched = @($unmatched | Select-Object -Unique)
    if ($unmatched) {
        Write-Host "❌ 以下正文引注在文末无法对应（或年份不符）："
        $unmatched | ForEach-Object { Write-Host "   $_" }
        $issues++
    } else {
        if ($citeText.Count -gt 0) { Write-Host "✅ 所有正文引注均能在文末找到作者与年份匹配的条目" }
    }

    # 2) 文末条目是否被正文引用过（孤儿条目）
    $orphans = @()
    foreach ($r in $refEntries) {
        $yrs = Get-YearTokens -Text $r
        $cited = $false
        foreach ($y in $yrs) {
            if ($citeText | Where-Object { $_.Year -eq $y }) { $cited = $true; break }
        }
        if (-not $cited) { $orphans += $r }
    }
    if ($orphans) {
        Write-Host "❌ 以下文末条目疑似未被正文引用（孤儿条目，请人工确认）："
        $orphans | ForEach-Object { $s = if ($_.Length -gt 70) { $_.Substring(0, 70) + '…' } else { $_ }; Write-Host "   $s" }
        $issues++
    } else {
        if ($refEntries.Count -gt 0) { Write-Host "✅ 文末条目均能在正文找到对应引注" }
    }

    # 3) 年份范围提示（著者-年制常见硬伤：引注年份与条目年份不符已在上方检出）
    $citeYears = @($citeText | ForEach-Object { $_.Year } | Select-Object -Unique)
    Write-Host "ℹ️ 正文引注涉及年份: $($citeYears -join ', ')"

    Write-Host ""
    if ($issues -eq 0) {
        Write-Host "✅ 机械核对通过。请人工完成第三对照：将下列引注与文献库条目逐一对应——"
        @($citeText | Select-Object -Unique -Property Raw) | ForEach-Object { Write-Host "   $($_.Raw) → 文献库条目: （待填）" }
    } else {
        Write-Host "⚠️ 发现 $issues 类问题，请修正后重跑。"
        Write-Host "   注意：著者-年制的机械核对为启发式判定（按作者姓氏片段+年份匹配），"
        Write-Host "   存在少量误报可能，最终以人工第三对照为准。"
        exit 1
    }
}
