# docx2md.ps1 — 第〇步工具：把稿件 docx 转为 markdown 进度快照
#
# 不预设论文类型：学位论文 / 期刊论文 / 课程论文三种模式均适用。
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/docx2md.ps1 -DocxPath "论文.docx"
#   powershell -ExecutionPolicy Bypass -File scripts/docx2md.ps1 -DocxPath "论文.docx" -OutPath "_进度_最新.md"
#   powershell -ExecutionPolicy Bypass -File scripts/docx2md.ps1 -Pattern "稿件*.docx"
#
# 行为：
#   - 解出 word/document.xml，按 </w:p> 分段、剥离 XML 标签、解码实体
#   - 同名 docx 存在于多个目录时，取 LastWriteTime 更新的那份
#   - 未指定 -DocxPath 时，按 -Pattern（默认 *.docx）在工作目录递归查找并取最新
#   - 文件被占用（PermissionError）时提示从可读副本提取
#   - 默认输出 _进度_最新.md（工作区约定名，见 docs/session-recovery.md）
#
# 注意：本文件须保存为 UTF-8 with BOM，否则 Windows PowerShell 5.1 会按 ANSI 解析中文而报错。
# 校验/修复：node -e "const fs=require('node:fs');const f='scripts/docx2md.ps1';const b=fs.readFileSync(f);if(!(b[0]===0xEF&&b[1]===0xBB&&b[2]===0xBF)){fs.writeFileSync(f,Buffer.concat([Buffer.from([0xEF,0xBB,0xBF]),b]));console.log('BOM 已补')}else{console.log('BOM 正常')}"

param(
    [Parameter(Mandatory = $false)]
    [string]$DocxPath = "",

    [Parameter(Mandatory = $false)]
    [string]$OutPath = "_进度_最新.md",

    [Parameter(Mandatory = $false)]
    [string]$Pattern = "*.docx"
)

$ErrorActionPreference = "Stop"

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# --- 定位 docx：显式路径 > 目录内同名文件（取最新）> 按 -Pattern 递归搜索取最新 ---
function Resolve-Docx {
    param([string]$Path, [string]$SearchPattern)
    if ($Path -and (Test-Path $Path)) { return (Get-Item $Path) }
    if ($Path) {
        $cands = Get-ChildItem -Path . -Recurse -Filter $Path -File -ErrorAction SilentlyContinue
        if ($cands) { return ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1) }
    }
    # 未指定或未命中：按 Pattern 递归查找（排除临时文件）
    $cands = Get-ChildItem -Path . -Recurse -Filter $SearchPattern -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -notlike '~$*' }
    if ($cands) { return ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1) }
    throw "未找到 docx 文件：请用 -DocxPath 显式指定，或用 -Pattern 指定匹配式（当前：$SearchPattern）。"
}

$docx = Resolve-Docx -Path $DocxPath -SearchPattern $Pattern
Write-Host "使用文件: $($docx.FullName)（LastWriteTime: $($docx.LastWriteTime)）"

# --- 解包 document.xml ---
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($docx.FullName)
} catch {
    Write-Host "⚠️ 无法打开 docx（可能被 Word/OneDrive 锁定）：$($_.Exception.Message)"
    Write-Host "   请先关闭 Word，或把文件复制为可读副本后再试。"
    exit 1
}

try {
    $entry = $zip.Entries | Where-Object { $_.FullName -eq "word/document.xml" }
    if (-not $entry) { throw "压缩包中未找到 word/document.xml，可能不是有效 docx。" }
    $reader = New-Object System.IO.StreamReader($entry.Open())
    $xml = $reader.ReadToEnd()
    $reader.Close()
} finally {
    $zip.Dispose()
}

# --- 清洗：分段 → 去标签 → 解实体 ---
$xml = $xml -replace '</w:p>', "`n"
$xml = $xml -replace '<[^>]+>', ''
$xml = $xml -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' `
              -replace '&quot;', '"' -replace '&apos;', "'"
$xml = $xml -replace '[ \t]+\r?\n', "`n"   # 行尾空白
$xml = ($xml -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) -join "`n"  # 去空行

Set-Content -Path $OutPath -Value $xml -Encoding UTF8
Write-Host "✅ 已写出进度快照: $OutPath（$(($xml -split "`n").Count) 行）"
