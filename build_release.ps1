$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$rootDir = $PSScriptRoot
$mobileDir = Join-Path $rootDir "mobile"
$releasesDir = Join-Path $rootDir "releases"

if (-not (Test-Path $releasesDir)) {
    New-Item -ItemType Directory -Path $releasesDir | Out-Null
}

$pubspecPath = Join-Path $mobileDir "pubspec.yaml"
$versionJsonPath = Join-Path $releasesDir "version.json"
$pubspecContent = Get-Content $pubspecPath -Raw

# 현재 버전 파싱
if ($pubspecContent -match 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    $build = [int]$Matches[4]
} else {
    $major = 1; $minor = 0; $patch = 0; $build = 1
}

# 자동 버전 범프: patch +1, build +1
$patch++
$build++
$newVersion = "$major.$minor.$patch+$build"
$newSemver = "$major.$minor.$patch"

# pubspec.yaml 업데이트
$pubspecContent = $pubspecContent -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion"
Set-Content -Path $pubspecPath -Value $pubspecContent.TrimEnd() -Encoding UTF8

# version.json 업데이트
$releaseNotes = Read-Host "릴리즈 노트 입력 (Enter로 건너뛰기)"
if ([string]::IsNullOrWhiteSpace($releaseNotes)) { $releaseNotes = "v$newSemver 업데이트" }
$versionJson = @{
    version = $newSemver
    buildNumber = $build
    apkFile = "smart_vocab_latest.apk"
    releaseNotes = $releaseNotes
} | ConvertTo-Json -Depth 2
Set-Content -Path $versionJsonPath -Value $versionJson -Encoding UTF8

$safeVersion = $newVersion -replace '\+', '_'

Write-Host "========================================="
Write-Host " 🚀 스마트 어학 학습 앱 빌드 시작 (버전: $newVersion)"
Write-Host "========================================="

Set-Location $mobileDir
Write-Host "1. Android APK 빌드 중..."
& flutter build apk --debug

$apkPath = Join-Path $mobileDir "build\app\outputs\flutter-apk\app-debug.apk"
if (Test-Path $apkPath) {
    $destPath = Join-Path $releasesDir "smart_vocab_v${safeVersion}_debug.apk"
    $latestPath = Join-Path $releasesDir "smart_vocab_latest.apk"
    Copy-Item -Path $apkPath -Destination $destPath -Force
    Copy-Item -Path $apkPath -Destination $latestPath -Force
    Write-Host "✅ Android APK 빌드 완료: $destPath"
    Write-Host "✅ Latest APK 업데이트: $latestPath"
    Write-Host "📌 버전: $newSemver (빌드 $build)"
} else {
    Write-Host "❌ Android APK 빌드 실패: 결과 파일을 찾을 수 없습니다."
}

Write-Host "-----------------------------------------"
Write-Host "⚠️ iOS (ipa) 빌드 관련 안내"
Write-Host "현재 운영체제가 Windows(win32)이므로 로컬에서 iOS 앱을 빌드할 수 없습니다."
Write-Host "iOS 빌드는 macOS (Xcode) 환경이 필수적입니다."
Write-Host "대신, 추후 GitHub Actions나 Codemagic 같은 클라우드 CI/CD 환경을 통해 iOS 빌드를 자동화할 수 있습니다."
Write-Host "========================================="
