# ==============================================================================
# 9Router 1-Click Installer & Optimizer for Windows
# Tự động cài đặt, cấu hình SSL Root Store, DNS Hosts và vá lỗi cho 9Router
# ==============================================================================

# 1. Tự động yêu cầu quyền Administrator nếu chưa có
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "🔑 Đang yêu cầu quyền Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"") -Verb RunAs
    exit
}

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "       🚀 9Router Auto-Setup & Fixer cho Windows       " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# 2. Kiểm tra Node.js và NPM
Write-Host "🔍 Kiểm tra môi trường Node.js..." -ForegroundColor Cyan
try {
    $nodeVersion = node -v
    $npmVersion = npm -v
    Write-Host "✔ Tìm thấy Node.js: $nodeVersion" -ForegroundColor Green
    Write-Host "✔ Tìm thấy NPM: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Không tìm thấy Node.js trên máy!" -ForegroundColor Red
    Write-Host "Bạn có thể cài đặt tự động bằng lệnh: winget install OpenJS.NodeJS.LTS" -ForegroundColor Yellow
    Write-Host "Hoặc tải bộ cài tại: https://nodejs.org" -ForegroundColor Yellow
    Pause
    exit
}

# 3. Cài đặt 9router globally qua npm nếu chưa có
Write-Host "📦 Kiểm tra package 9router..." -ForegroundColor Cyan
try {
    $routerVersion = 9router --version 2>$null
    Write-Host "✔ 9router đã được cài đặt sẵn ($routerVersion)." -ForegroundColor Green
} catch {
    Write-Host "Đang cài đặt 9router globally qua npm..." -ForegroundColor Yellow
    npm install -g 9router
    Write-Host "✔ Đã cài đặt 9router thành công!" -ForegroundColor Green
}

# 4. Chạy script vá lỗi
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$patcherPath = Join-Path $scriptDir "patch-9router.js"
if (Test-Path $patcherPath) {
    Write-Host "🔧 Đang áp dụng các bản vá lỗi cho 9Router..." -ForegroundColor Cyan
    node "$patcherPath"
}

# 5. Khởi tạo thư mục mitm
$routerDataDir = Join-Path $env:USERPROFILE ".9router"
$mitmDir = Join-Path $routerDataDir "mitm"
if (-not (Test-Path $mitmDir)) {
    New-Item -ItemType Directory -Path $mitmDir -Force | Out-Null
}

$certPath = Join-Path $mitmDir "rootCA.crt"
$keyPath = Join-Path $mitmDir "rootCA.key"

# 6. Cài đặt chứng chỉ SSL vào Windows Root Certificate Store
if (Test-Path $certPath) {
    Write-Host "🔑 Cài đặt chứng chỉ vào Windows Root Certificate Store..." -ForegroundColor Cyan
    certutil -delstore Root "9Router MITM Root CA" 2>$null | Out-Null
    certutil -addstore Root "$certPath" | Out-Null
    Write-Host "✔ Chứng chỉ '9Router MITM Root CA' đã được tin cậy trong Windows Root Store!" -ForegroundColor Green
} else {
    Write-Host "ℹ Chứng chỉ Root CA sẽ được 9Router tạo tự động khi khởi chạy lần đầu." -ForegroundColor Yellow
}

# 7. Cấu hình hosts file cho Antigravity
Write-Host "🌐 Cấu hình chuyển hướng DNS trong Windows hosts file..." -ForegroundColor Cyan
$hostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$domains = @("daily-cloudcode-pa.googleapis.com", "cloudcode-pa.googleapis.com")

$hostsContent = Get-Content -Path $hostsPath -Raw -ErrorAction SilentlyContinue
if ($null -eq $hostsContent) { $hostsContent = "" }

$modified = $false
foreach ($domain in $domains) {
    if (-not $hostsContent.Contains($domain)) {
        Add-Content -Path $hostsPath -Value "`r`n127.0.0.1 $domain"
        Write-Host "  ✔ Đã thêm: 127.0.0.1 $domain" -ForegroundColor Green
        $modified = $true
    } else {
        Write-Host "  - Domain $domain đã có trong hosts" -ForegroundColor Yellow
    }
}

ipconfig /flushdns | Out-Null
Write-Host "✔ Đã làm mới DNS Cache của Windows (ipconfig /flushdns)." -ForegroundColor Green

# 8. Cấu hình mapping model mặc định
$aliasesPath = Join-Path $mitmDir "aliases.json"
if (-not (Test-Path $aliasesPath) -or (Get-Item $aliasesPath).Length -le 2) {
    $defaultAliases = @"
{
  "antigravity": {
    "gemini-3.8-flash-high": "ag/gemini-3.8-flash-high",
    "gemini-3.8-flash-medium": "ag/gemini-3.8-flash-medium",
    "gemini-3.8-flash-low": "ag/gemini-3.8-flash-low",
    "gemini-3.8-flash": "ag/gemini-3.8-flash-medium"
  }
}
"@
    Set-Content -Path $aliasesPath -Value $defaultAliases -Encoding UTF8
    Write-Host "✔ Đã tạo file mapping model mặc định: $aliasesPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "      🎉 CÀI ĐẶT & CẤU HÌNH HOÀN TẤT 100%!           " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Bây giờ bạn có thể khởi động 9Router bằng lệnh: 9router" -ForegroundColor Cyan
Write-Host "Trang quản trị: http://localhost:20128" -ForegroundColor Yellow
Write-Host ""
Write-Host "Nhấn phím bất kỳ để khởi động 9Router ngay bây giờ..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Start-Process "9router"
