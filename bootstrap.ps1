<#
EnvoScale bootstrap entry point for Windows (Windows PowerShell 5.1 or PowerShell 7).
Uses only what Windows ships with, plus NASM through adapters/bootstrap/nasm (Phase A).

  .\bootstrap.ps1 build   assemble Stage 0: build\stage0\envoc0.exe and build\stage0\envoc0
  .\bootstrap.ps1 test    build, then run the Stage 0 test suites with the Windows binary
  .\bootstrap.ps1 check   repository checks: layout, lib->adapters imports, gallery limits
  .\bootstrap.ps1 clean   delete build\
  .\bootstrap.ps1 help

bootstrap.sh is the POSIX twin of this script; keep the two in step.
#>
param([string]$Command = 'help')

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Build = Join-Path $Root 'build\stage0'
$Stage0 = Join-Path $Root 'bootstrap\stage0'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Say([string]$msg) { Write-Host $msg }
function Fail([string]$msg) { [Console]::Error.WriteLine("error: $msg"); exit 1 }

# ------------------------------------------------------------------- build
function Invoke-Build {
    New-Item -ItemType Directory -Force $Build | Out-Null
    $adapter = Join-Path $Root 'adapters\bootstrap\nasm\assemble.ps1'
    $units = @(
        @{ Src = 'envoc0-windows.eas'; Out = 'envoc0.exe' },
        @{ Src = 'envoc0-linux.eas';   Out = 'envoc0' }
    )
    foreach ($u in $units) {
        $src = Join-Path $Stage0 $u.Src
        $out = Join-Path $Build $u.Out
        Say "assemble  bootstrap/stage0/$($u.Src) -> build/stage0/$($u.Out)"
        & $adapter $src $out $Stage0
        if ($LASTEXITCODE -ne 0) { Fail "assembling $($u.Src) failed (exit $LASTEXITCODE)" }
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $out).Hash.ToLowerInvariant()
        $size = (Get-Item -LiteralPath $out).Length
        Say ("          {0,8} bytes  sha256 {1}" -f $size, $hash)
    }
}

# ------------------------------------------------------------------- process helper
function Quote-Arg([string]$a) {
    if ($a -match '[\s"]') { return '"' + ($a -replace '"', '\"') + '"' }
    return $a
}

# Runs a program and captures exit code, stdout and stderr as UTF-8 text.
function Invoke-Tool([string]$exe, [string[]]$argv, [string]$cwd) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = (($argv | ForEach-Object { Quote-Arg $_ }) -join ' ')
    $psi.WorkingDirectory = $cwd
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $Utf8
    $psi.StandardErrorEncoding = $Utf8
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $err = $p.StandardError.ReadToEnd()
    $out = $outTask.Result
    $p.WaitForExit()
    return [pscustomobject]@{ Code = $p.ExitCode; Out = $out; Err = $err }
}

function Normalize([string]$s) { return ($s -replace "`r`n", "`n") }

# Shows the first line where two texts differ.
function Show-Diff([string]$expected, [string]$actual) {
    $e = $expected -split "`n"
    $a = $actual -split "`n"
    $n = [Math]::Max($e.Count, $a.Count)
    for ($i = 0; $i -lt $n; $i++) {
        $el = if ($i -lt $e.Count) { $e[$i] } else { '<end of file>' }
        $al = if ($i -lt $a.Count) { $a[$i] } else { '<end of file>' }
        if (-not [string]::Equals($el, $al)) {
            Say "      first difference at output line $($i + 1):"
            Say "        expected: $el"
            Say "        actual:   $al"
            return
        }
    }
}

# ------------------------------------------------------------------- test
function Invoke-Test {
    Invoke-Build
    $exe = Join-Path $Build 'envoc0.exe'
    $script:passed = 0
    $script:failed = 0
    function Pass([string]$name) { $script:passed++ }
    function Bad([string]$name, [string]$why) { $script:failed++; Say "FAIL  $name"; if ($why) { Say "      $why" } }

    Say ''
    Say 'smoke tests'
    $r = Invoke-Tool $exe @('version') $Root
    if ($r.Code -eq 0 -and $r.Out.StartsWith('envoc0 ')) { Pass 'version' } else { Bad 'version' "exit $($r.Code), stdout: $($r.Out)" }
    $r = Invoke-Tool $exe @() $Root
    if ($r.Code -eq 2 -and $r.Err.StartsWith('usage: envoc0')) { Pass 'no arguments' } else { Bad 'no arguments' "exit $($r.Code), stderr: $($r.Err)" }
    $r = Invoke-Tool $exe @('frobnicate') $Root
    if ($r.Code -eq 2 -and $r.Err.StartsWith("envoc0: error: unknown command 'frobnicate'")) { Pass 'unknown command' } else { Bad 'unknown command' "exit $($r.Code), stderr: $($r.Err)" }
    $r = Invoke-Tool $exe @('lex', 'no such file.envo') $Root
    if ($r.Code -eq 1 -and $r.Err.StartsWith("envoc0: error: cannot open 'no such file.envo'")) { Pass 'missing file' } else { Bad 'missing file' "exit $($r.Code), stderr: $($r.Err)" }

    Say 'golden tests: tests/golden/lexer'
    $dir = Join-Path $Root 'tests\golden\lexer'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envo' | Sort-Object Name) {
        $name = "golden/lexer/$($f.Name)"
        $tokens = [IO.Path]::ChangeExtension($f.FullName, '.tokens')
        if (-not (Test-Path -LiteralPath $tokens)) { Bad $name 'missing .tokens file'; continue }
        $expected = Normalize ([IO.File]::ReadAllText($tokens, $Utf8))
        $r = Invoke-Tool $exe @('lex', $f.Name) $dir
        $actual = Normalize $r.Out
        if ($r.Code -ne 0) { Bad $name "exit $($r.Code), stderr: $($r.Err.Trim())"; continue }
        if ([string]::Equals($expected, $actual)) { Pass $name } else { Bad $name 'token dump differs'; Show-Diff $expected $actual }
    }

    Say 'spec tests: tests/spec/01-lexical'
    $dir = Join-Path $Root 'tests\spec\01-lexical'
    $latin1 = [Text.Encoding]::GetEncoding(28591)    # byte-transparent, for files that are not UTF-8
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envo' | Sort-Object Name) {
        $name = "spec/01-lexical/$($f.Name)"
        $text = [IO.File]::ReadAllText($f.FullName, $latin1)
        $m = [regex]::Match($text, '(?m)^// expect-error: (E\d{4})(?: @ (\d+):(\d+))?')
        if (-not $m.Success) { Bad $name 'no // expect-error: annotation'; continue }
        $code = $m.Groups[1].Value
        $want = "error[$code]"
        if ($m.Groups[2].Success) { $want = "$($f.Name):$($m.Groups[2].Value):$($m.Groups[3].Value): error[$code]" }
        $r = Invoke-Tool $exe @('lex', $f.Name) $dir
        if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $name }
        else { Bad $name "expected exit 1 with '$want'; got exit $($r.Code), stderr: $($r.Err.Trim())" }
    }

    Say ''
    Say "$($script:passed) passed, $($script:failed) failed"
    if ($script:failed -gt 0) { exit 1 }
}

# ------------------------------------------------------------------- check
function Invoke-Check {
    $problems = New-Object System.Collections.Generic.List[string]

    foreach ($f in @('README.md', 'CHARTER.md', 'STATUS.md', 'CONTRIBUTING.md', 'SECURITY.md',
                     'CODE_OF_CONDUCT.md', 'LICENSE', 'envo.eon', 'bootstrap.sh', 'bootstrap.ps1',
                     'docs/PLAN.md', 'docs/rfcs/0000-template.md', 'docs/porting/CHECKLIST.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $f))) { $problems.Add("missing file: $f") }
    }

    $layout = Get-Content -LiteralPath (Join-Path $Root 'tests\layout.txt') -Encoding UTF8
    $dirs = 0
    foreach ($line in $layout) {
        $d = $line.Trim()
        if ($d -eq '' -or $d.StartsWith('#')) { continue }
        $dirs++
        if (-not (Test-Path -LiteralPath (Join-Path $Root "$d\README.md"))) { $problems.Add("layout: $d/README.md is missing") }
    }

    # Charter 2.3: lib/** must never import adapters/**. The compiler enforces this
    # from M3; until then a text check catches it.
    $lib = Join-Path $Root 'lib'
    foreach ($f in Get-ChildItem -LiteralPath $lib -Recurse -Filter '*.envo' -ErrorAction SilentlyContinue) {
        $hits = Select-String -LiteralPath $f.FullName -Pattern '^\s*(use|using)\s+adapters\b'
        foreach ($h in $hits) { $problems.Add("lib imports an adapter: $($f.FullName.Substring($Root.Length + 1)):$($h.LineNumber)") }
    }

    # Brief 17: no Hello World Gallery program may grow past its line count.
    $gallery = Join-Path $Root 'tests\spec\hello'
    $entries = 0
    foreach ($line in Get-Content -LiteralPath (Join-Path $gallery 'limits.txt') -Encoding UTF8) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        $parts = $t -split '\s+'
        $file = Join-Path $gallery $parts[0]
        $limit = [int]$parts[1]
        $entries++
        if (-not (Test-Path -LiteralPath $file)) { $problems.Add("gallery: $($parts[0]) is missing"); continue }
        $code = @(Get-Content -LiteralPath $file -Encoding UTF8 | Where-Object { $_.Trim() -ne '' -and -not $_.Trim().StartsWith('//') }).Count
        if ($code -gt $limit) { $problems.Add("gallery: $($parts[0]) has $code code lines, limit is $limit") }
    }
    if ($entries -ne 11) { $problems.Add("gallery: limits.txt lists $entries programs, the brief has 11") }

    if ($problems.Count -gt 0) {
        foreach ($p in $problems) { [Console]::Error.WriteLine("check: $p") }
        Fail "$($problems.Count) problem(s)"
    }
    Say "check: ok ($dirs layout folders, $entries gallery programs, no lib->adapters imports)"
}

switch ($Command) {
    'build' { Invoke-Build }
    'test'  { Invoke-Test }
    'check' { Invoke-Check }
    'clean' { if (Test-Path -LiteralPath (Join-Path $Root 'build')) { Remove-Item -Recurse -Force (Join-Path $Root 'build') }; Say 'removed build/' }
    default {
        Say 'usage: .\bootstrap.ps1 <build|test|check|clean|help>'
        Say '  build   assemble Stage 0 (needs NASM; see adapters/bootstrap/nasm/README.md)'
        Say '  test    build, then run the Stage 0 test suites'
        Say '  check   repository layout, lib->adapters imports, Hello World Gallery limits'
        Say '  clean   delete build/'
        if ($Command -ne 'help') { exit 2 }
    }
}
