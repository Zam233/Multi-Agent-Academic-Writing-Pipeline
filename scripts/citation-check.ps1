# citation-check.ps1 — 引用三对照核验（机械部分）
#
# 三对照 = ①正文 [n] 引注 ②文末参考文献表 ③Zotero 文献库条目
# 本脚本自动完成 ①② 的机械核对（③需 librarian 人工对照，脚本输出核对单）。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/citation-check.ps1 -TextPath "第三章正文.md"
#   powershell -ExecutionPolicy Bypass -File scripts/citation-check.ps1 -TextPath "第三章正文.md" -RefHeading "参考文献"
#
# 输出：
#   - 正文引注编号清单（首次出现顺序）
#   - 文末参考文献编号清单
#   - 问题报告：正文引用但文末缺失 / 文末存在但正文未引 / 编号不连续 / 顺序编码制违例

param(
    [Parameter(Mandatory = $true)]
    [string]$TextPath,

    [Parameter(Mandatory = $false)]
    [string]$RefHeading = "参考文献"
)

$ErrorActionPreference = "Stop"

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

# --- 提取编号 ---
$citeNums = [regex]::Matches($body, '\[(\d{1,3})\]') | ForEach-Object { [int]$_.Groups[1].Value }
$refNums  = [regex]::Matches($refBlock, '^\[(\d{1,3})\]', [System.Text.RegularExpressions.RegexOptions]::Multiline) |
            ForEach-Object { [int]$_.Groups[1].Value }
$refNums  = @($refNums | Select-Object -Unique)

$firstOrder = @($citeNums | Select-Object -Unique)   # 首次出现顺序 = 顺序编码制要求
$bodySet  = @($citeNums | Select-Object -Unique | Sort-Object)
$refSet   = @($refNums | Sort-Object)

Write-Host "=== 引用三对照核验报告 ==="
Write-Host "正文引注编号（首次出现顺序）: $($firstOrder -join ', ')"
Write-Host "文末参考文献编号: $($refSet -join ', ')  ($($refSet.Count) 条)"
Write-Host ""

$issues = 0
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
    Write-Host "✅ 机械核对通过。请人工完成第三对照：将下列编号与 Zotero 文献库条目逐一对应——"
    $firstOrder | ForEach-Object { Write-Host "   [$($_)] → Zotero 条目: （待填）" }
} else {
    Write-Host "⚠️ 发现 $issues 类问题，请修正后重跑。"
    exit 1
}
