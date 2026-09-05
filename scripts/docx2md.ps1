# docx2md.ps1 — 第〇步工具：把学位论文 docx 转为 markdown 进度快照
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/docx2md.ps1 -DocxPath "毕业论文.docx"
#   powershell -ExecutionPolicy Bypass -File scripts/docx2md.ps1 -DocxPath "毕业论文.docx" -OutPath "_进度_最新.md"
#
# 行为：
#   - 解出 word/document.xml，按 </w:p> 分段、剥离 XML 标签、解码实体
#   - 同名 docx 存在于多个目录时，取 LastWriteTime 更新的那份
#   - 文件被占用（PermissionError）时提示从可读副本提取
#   - 默认输出 _论文进度_最新.md（工作区约定名）
#
# 用法（PowerShell）：
#   .\scripts\docx2md.ps1 -DocxPath "论文.docx"

param(
    [Parameter(Mandatory = $false)]
    [string]$DocxPath = "",

    [Parameter(Mandatory = $false)]
    [string]$OutPath = "_论文进度_最新.md"
)

$ErrorActionPreference = "Stop"

# --- 定位 docx：显式路径 > 目录内同名文件（取最新）> 工作区递归搜索 ---
function Resolve-Docx {
    param([string]$Path)
    if ($Path -and (Test-Path $Path)) { return (Get-Item $Path) }
    if ($Path) {
        $cands = Get-ChildItem -Path . -Recurse -Filter $Path -File -ErrorAction SilentlyContinue
        if ($cands) { return ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1) }
    }
    $cands = Get-ChildItem -Path . -Recurse -Filter "毕业论文*.docx" -File -ErrorAction SilentlyContinue
    if ($cands) { return ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1) }
    throw "未找到 docx 文件：请用 -DocxPath 显式指定，或确认工作目录内存在论文 docx。"
}

$docx = Resolve-Docx -Path $DocxPath
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
