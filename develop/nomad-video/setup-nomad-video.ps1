# setup-nomad-video.ps1 — 멀티에이전트 베이스를 복사해 nomad-video 개발 폴더를 만든다 (Windows PowerShell 7+)
#
# 사용:  pwsh -File setup-nomad-video.ps1            실제 실행
#        pwsh -File setup-nomad-video.ps1 -DryRun    할 일만 출력(아무것도 바꾸지 않음)
#
# 하는 일은 setup-nomad-video.sh 와 같다.
#   1) 베이스 복사  2) 복사본에서 init-project.sh(Git Bash의 bash.exe로 실행)  3) nomad-video-root 내용물 붙여넣기
#   4) docs/etc 삭제  5) 에이전트 모델 지정(주 Opus / 부 Sonnet / 고문 Fable)  6) 무결성 점검
# init-project.sh 와 _shared/*.sh 는 bash 스크립트라 PowerShell 로는 실행되지 않는다. Git Bash 가 필요하다.
param(
  [switch]$DryRun,
  [string]$Base = 'D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork',
  [string]$Target = 'D:\WorkSpace\DEV\nomad-video'
)
$ErrorActionPreference = 'Stop'
$Product = 'nomad-video'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Pkg = Join-Path $Here "$Product-root"

function Say([string]$m) { Write-Output $m }
function Fail([string]$m) { Write-Error "중단: $m"; exit 1 }

Say '[0/6] 사전 확인'
if (-not (Test-Path $Base -PathType Container)) { Fail "베이스 원본이 없습니다: $Base" }
if (-not (Test-Path (Join-Path $Base 'init-project.sh'))) { Fail "베이스에 init-project.sh 가 없습니다: $Base" }
if (-not (Test-Path $Pkg -PathType Container)) { Fail "붙여넣을 묶음이 없습니다: $Pkg" }
if (Test-Path $Target) { Fail "대상 폴더가 이미 있습니다(덮어쓰지 않습니다): $Target" }

# Git Bash 를 쓴다. System32\bash.exe 와 WindowsApps\bash.exe 는 WSL 실행기라 경로가 맞지 않아 제외한다.
$Bash = $null
$candidates = @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe")
$candidates += @(Get-Command bash -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
foreach ($c in $candidates) {
  if ($c -and (Test-Path $c) -and ($c -notlike '*\System32\*') -and ($c -notlike '*\WindowsApps\*')) { $Bash = $c; break }
}
if (-not $Bash) { Fail "Git Bash(bash.exe)를 찾지 못했습니다. Git for Windows 를 설치하세요(WSL bash 는 쓰지 않습니다)" }
foreach ($t in @('git', 'jq')) {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { Fail "필수 도구가 없습니다: $t (베이스 INSTALL.md §1. jq: winget install jqlang.jq)" }
}
Say "  베이스: $Base"
Say "  대상:   $Target"
Say "  묶음:   $Pkg"
Say "  bash:   $Bash"

Say '[1/6] 베이스 복사'
if ($DryRun) { Say "  (dry-run) Copy-Item `"$Base`" `"$Target`" -Recurse" }
else { Copy-Item -Path $Base -Destination $Target -Recurse }

Say '[2/6] 복사본에서 init-project.sh 실행(복사본 안의 스크립트만 실행합니다)'
if ($DryRun) { Say "  (dry-run) Push-Location `"$Target`"; & `"$Bash`" init-project.sh $Product --reset-git" }
else {
  Push-Location $Target
  try {
    & $Bash init-project.sh $Product --reset-git
    if ($LASTEXITCODE -ne 0) { Fail "init-project.sh 실패(exit $LASTEXITCODE). 위 메시지를 확인하세요" }
  } finally { Pop-Location }
}

Say "[3/6] $Product-root 내용물 붙여넣기(docs, supabase, infra, .claude)"
if ($DryRun) { Say "  (dry-run) Copy-Item `"$Pkg\*`" `"$Target`" -Recurse -Force" }
else { Copy-Item -Path (Join-Path $Pkg '*') -Destination $Target -Recurse -Force }
# 숨김 폴더(.claude)는 와일드카드에 포함되지 않을 수 있어 따로 복사한다
$PkgClaude = Join-Path $Pkg '.claude'
if (Test-Path $PkgClaude) {
  if ($DryRun) { Say "  (dry-run) Copy-Item `"$PkgClaude`" `"$Target`" -Recurse -Force" }
  else { Copy-Item -Path $PkgClaude -Destination $Target -Recurse -Force }
}

Say '[4/6] docs/etc 삭제(베이스 설명서 PDF, 제품 개발에 쓰지 않음)'
$Etc = Join-Path $Target 'docs\etc'
if ($DryRun) { Say "  (dry-run) Remove-Item `"$Etc`" -Recurse -Force" }
elseif (Test-Path $Etc) { Remove-Item -Path $Etc -Recurse -Force }

Say '[5/6] 에이전트 모델 지정: plan-challenger=Fable(고문), 도메인 expert 3개=Sonnet(부)'
function Set-AgentModel([string]$File, [string]$Model) {
  $raw = [System.IO.File]::ReadAllText($File, [System.Text.UTF8Encoding]::new($false))
  $crlf = $raw.Contains("`r`n")
  $t = $raw.Replace("`r`n", "`n")
  $m = [regex]::Match($t, '^---\n(.*?)\n---\n', [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if (-not $m.Success) { Fail "frontmatter 없음: $File" }
  $fm = $m.Groups[1].Value
  if ($fm -match '(?m)^model:') { $fm = [regex]::Replace($fm, '(?m)^model:.*$', "model: $Model") }
  else { $fm = $fm + "`nmodel: $Model" }
  $new = "---`n$fm`n---`n" + $t.Substring($m.Length)
  if ($crlf) { $new = $new.Replace("`n", "`r`n") }
  [System.IO.File]::WriteAllText($File, $new, [System.Text.UTF8Encoding]::new($false))
}
$Agents = Join-Path $Target '.claude\agents'
if ($DryRun) {
  Say '  (dry-run) .claude\agents\plan-challenger.md  model: opus -> model: claude-fable-5-1'
  Say '  (dry-run) .claude\agents\{nextjs,fastapi,supabase}-expert.md  frontmatter 에 model: sonnet 추가'
} else {
  Set-AgentModel (Join-Path $Agents 'plan-challenger.md') 'claude-fable-5-1'
  foreach ($n in @('nextjs-expert.md', 'fastapi-expert.md', 'supabase-expert.md')) { Set-AgentModel (Join-Path $Agents $n) 'sonnet' }
  Say '  모델 지정 완료'
}

Say '[6/6] 무결성 점검'
if ($DryRun) { Say "  (dry-run) Push-Location `"$Target`"; & `"$Bash`" _shared/check-invariants.sh" }
else {
  Push-Location $Target
  try {
    & $Bash _shared/check-invariants.sh
    if ($LASTEXITCODE -ne 0) { Say '  무결성 점검에 FAIL 이 있습니다. 커밋 전에 해소하세요' }
  } finally { Pop-Location }
}

Say ''
Say '완료. 다음 순서:'
Say "  1) $Target\_shared\project-profile.md 의 스택 버전과 명령을 채웁니다(nomad-video_develop.md 6절)"
Say "  2) $Target 에서 claude 를 실행하고 /agent-check 로 에이전트를 확인합니다"
Say '  3) nomad-video_develop.md 7절부터 진행합니다'
