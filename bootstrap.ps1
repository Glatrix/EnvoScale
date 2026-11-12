<#
EnvoScale bootstrap entry point for Windows (Windows PowerShell 5.1 or PowerShell 7).
Uses only what Windows ships with, plus NASM through adapters/bootstrap/nasm (Phase A).

  .\bootstrap.ps1 build   assemble Stage 0 (build\stage0\envoc0.exe, envoc0), then build
                          Stage 1 with it (build\stage1\envoc1.exe, envoc1)
  .\bootstrap.ps1 test    build, then run the Stage 0 and Stage 1 tests with the Windows binaries
  .\bootstrap.ps1 check   repository checks: layout, lib->adapters imports, gallery limits
  .\bootstrap.ps1 clean   delete build\
  .\bootstrap.ps1 help

bootstrap.sh is the POSIX twin of this script; keep the two in step.
#>
param([string]$Command = 'help')

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Build = Join-Path $Root 'build\stage0'
$Build1 = Join-Path $Root 'build\stage1'
$Stage0 = Join-Path $Root 'bootstrap\stage0'
$Stage1 = Join-Path $Root 'bootstrap\stage1'
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

    # Stage 1 is an Envo-Core program (PLAN D11); envoc0 builds it for both OSes.
    New-Item -ItemType Directory -Force $Build1 | Out-Null
    $envoc0 = Join-Path $Build 'envoc0.exe'
    $files = @(Get-Content -LiteralPath (Join-Path $Stage1 'files.txt') | Where-Object { $_.Trim() -ne '' })
    foreach ($u in @(@{ Target = 'x86_64-windows'; Out = 'envoc1.exe' }, @{ Target = 'x86_64-linux'; Out = 'envoc1' })) {
        $out = Join-Path $Build1 $u.Out
        Say "build     bootstrap/stage1 -> build/stage1/$($u.Out)"
        $r = Invoke-Tool $envoc0 (@('build') + $files + @('-o', $out, '--target', $u.Target)) $Stage1
        if ($r.Code -ne 0) { Fail "building Stage 1 ($($u.Target)) failed: $($r.Err.Trim())" }
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
    # Paths are UTF-8 on every OS: a name with a space, a Latin, a CJK and a non-BMP character.
    $tmp = Join-Path $Build 'tmp'
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $uname = "u$([char]0x00FC)nicode $([char]0x65E5)$([char]::ConvertFromUtf32(0x1F600)).envo"
    [IO.File]::WriteAllText((Join-Path $tmp $uname), "print(`"hi`")`n", $Utf8)
    $r = Invoke-Tool $exe @('lex', $uname) $tmp
    if ($r.Code -eq 0 -and $r.Out.StartsWith('1:1 n ident print')) { Pass 'unicode path' } else { Bad 'unicode path' "exit $($r.Code), stderr: $($r.Err)" }
    # Cross-compilation: this host builds the other OS's executable (it can only check the header).
    [IO.File]::WriteAllText((Join-Path $tmp 'cross.envo'), "print(`"hi`")`n", $Utf8)
    $r = Invoke-Tool $exe @('build', 'cross.envo', '-o', 'cross-linux', '--target', 'x86_64-linux') $tmp
    $ok = $false
    if ($r.Code -eq 0) { $head = [IO.File]::ReadAllBytes((Join-Path $tmp 'cross-linux')); $ok = ($head[0] -eq 0x7F -and $head[1] -eq 0x45 -and $head[2] -eq 0x4C -and $head[3] -eq 0x46) }
    if ($ok) { Pass 'cross build (linux)' } else { Bad 'cross build (linux)' "exit $($r.Code), stderr: $($r.Err)" }

    # Golden suites: tests/golden/<dir>/<name>.envo -> <name><ext>, produced by `envoc0 <command>`.
    # Keep this list in step with bootstrap.sh.
    $goldenSuites = @(
        @{ Dir = 'lexer';  Command = 'lex';   Ext = '.tokens' },
        @{ Dir = 'parser'; Command = 'parse'; Ext = '.ast' },
        @{ Dir = 'check';  Command = 'check'; Ext = '.check' }
    )
    foreach ($suite in $goldenSuites) {
      Say "golden tests: tests/golden/$($suite.Dir)"
      $dir = Join-Path $Root "tests\golden\$($suite.Dir)"
      foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envo' | Sort-Object Name) {
        $name = "golden/$($suite.Dir)/$($f.Name)"
        $expectedFile = [IO.Path]::ChangeExtension($f.FullName, $suite.Ext)
        if (-not (Test-Path -LiteralPath $expectedFile)) { Bad $name "missing $($suite.Ext) file"; continue }
        $expected = Normalize ([IO.File]::ReadAllText($expectedFile, $Utf8))
        $r = Invoke-Tool $exe @($suite.Command, $f.Name) $dir
        $actual = Normalize $r.Out
        if ($r.Code -ne 0) { Bad $name "exit $($r.Code), stderr: $($r.Err.Trim())"; continue }
        if ([string]::Equals($expected, $actual)) { Pass $name } else { Bad $name 'output differs'; Show-Diff $expected $actual }
      }
    }

    # Spec error tests run through `envoc0 check`, which lexes and parses first, so
    # lexical and syntax errors are still reported by their own stage.
    # Keep this list in step with bootstrap.sh.
    $latin1 = [Text.Encoding]::GetEncoding(28591)    # byte-transparent, for files that are not UTF-8
    foreach ($specDir in @('01-lexical', 'core-syntax', 'core-types')) {
      Say "spec tests: tests/spec/$specDir"
      $dir = Join-Path $Root "tests\spec\$specDir"
      foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envo' | Sort-Object Name) {
        $name = "spec/$specDir/$($f.Name)"
        $text = [IO.File]::ReadAllText($f.FullName, $latin1)
        $m = [regex]::Match($text, '(?m)^// expect-error: (E\d{4})(?: @ (\d+):(\d+))?')
        if (-not $m.Success) { Bad $name 'no // expect-error: annotation'; continue }
        $code = $m.Groups[1].Value
        $want = "error[$code]"
        if ($m.Groups[2].Success) { $want = "$($f.Name):$($m.Groups[2].Value):$($m.Groups[3].Value): error[$code]" }
        $r = Invoke-Tool $exe @('check', $f.Name) $dir
        if ($r.Err.Contains('(no message for this error code)')) { Bad $name "missing message: $($r.Err.Trim())" }
        elseif ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $name }
        else { Bad $name "expected exit 1 with '$want'; got exit $($r.Code), stderr: $($r.Err.Trim())" }
      }
    }

    # Programs compiled and run: `// expect:` stdout lines, `// expect-exit: N`,
    # `// expect-panic: <reason>` (exit 101 and "panic: <reason>" on stderr).
    # Programs compiled and run: by Stage 0, then by Stage 1, which must give the same
    # output and exit codes (M2.7, PLAN D14).
    $stage0Exe = $exe
    foreach ($compiler in @('envoc0', 'envoc1')) {
    if ($compiler -eq 'envoc1') { $exe = Join-Path $Build1 'envoc1.exe' } else { $exe = $stage0Exe }
        $runDir = Join-Path $Root "build\run-$compiler"
        New-Item -ItemType Directory -Force $runDir | Out-Null
        # Envo-S1 programs (tests/spec/s1-run) run under Stage 1 only.
        $runSuites = @('core-run')
        if ($compiler -eq 'envoc1') { $runSuites += 's1-run' }
        foreach ($suite in $runSuites) {
        Say "run tests ($compiler): tests/spec/$suite"
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root "tests\spec\$suite") -Filter '*.envo' | Sort-Object Name) {
            $name = "$compiler spec/$suite/$($f.Name)"
            $text = Normalize ([IO.File]::ReadAllText($f.FullName, $Utf8))
            $lines = @([regex]::Matches($text, '(?m)^// expect: (.*)$') | ForEach-Object { $_.Groups[1].Value })
            $wantOut = ''
            if ($lines.Count -gt 0) { $wantOut = ($lines -join "`n") + "`n" }
            $wantCode = 0
            $m = [regex]::Match($text, '(?m)^// expect-exit: (\d+)')
            if ($m.Success) { $wantCode = [int]$m.Groups[1].Value }
            $panic = [regex]::Match($text, '(?m)^// expect-panic: (.*)$')
            if ($panic.Success) { $wantCode = 101 }
            $program = Join-Path $runDir ($f.BaseName + '.exe')
            $r = Invoke-Tool $exe @('build', $f.FullName, '-o', $program) $runDir
            if ($r.Code -ne 0) { Bad $name "build failed: $($r.Err.Trim())"; continue }
            $r = Invoke-Tool $program @() $runDir
            $out = Normalize $r.Out
            if (-not [string]::Equals($wantOut, $out)) { Bad $name 'stdout differs'; Show-Diff $wantOut $out; continue }
            if ($r.Code -ne $wantCode) { Bad $name "exit code $($r.Code), expected $wantCode; stderr: $($r.Err.Trim())"; continue }
            if ($panic.Success -and -not $r.Err.Contains("panic: $($panic.Groups[1].Value)")) { Bad $name "stderr: $($r.Err.Trim())"; continue }
            Pass $name
        }
        }

        # Multi-file programs: one folder per test. main.envo is the entry file and holds
        # the annotations; the other .envo files follow in name order. Either
        # `// expect-error: E#### @ <file>:L:C` (envoc0 check) or `// expect:` lines (build, run).
        Say "multi-file tests ($compiler): tests/spec/core-multi"
        foreach ($d in Get-ChildItem -LiteralPath (Join-Path $Root 'tests\spec\core-multi') -Directory | Sort-Object Name) {
            $name = "$compiler spec/core-multi/$($d.Name)"
            $files = @('main.envo') + @(Get-ChildItem -LiteralPath $d.FullName -Filter '*.envo' | Where-Object { $_.Name -ne 'main.envo' } | Sort-Object Name | ForEach-Object { $_.Name })
            $text = Normalize ([IO.File]::ReadAllText((Join-Path $d.FullName 'main.envo'), $Utf8))
            $m = [regex]::Match($text, '(?m)^// expect-error: (E\d{4}) @ (\S+)$')
            if ($m.Success) {
                $want = "$($m.Groups[2].Value): error[$($m.Groups[1].Value)]"
                $r = Invoke-Tool $exe (@('check') + $files) $d.FullName
                if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $name }
                else { Bad $name "expected exit 1 with '$want'; got exit $($r.Code), stderr: $($r.Err.Trim())" }
                continue
            }
            $lines = @([regex]::Matches($text, '(?m)^// expect: (.*)$') | ForEach-Object { $_.Groups[1].Value })
            $wantOut = ''
            if ($lines.Count -gt 0) { $wantOut = ($lines -join "`n") + "`n" }
            $program = Join-Path $runDir ("multi-" + $d.Name + '.exe')
            $r = Invoke-Tool $exe (@('build') + $files + @('-o', $program)) $d.FullName
            if ($r.Code -ne 0) { Bad $name "build failed: $($r.Err.Trim())"; continue }
            $r = Invoke-Tool $program @() $runDir
            $out = Normalize $r.Out
            if (-not [string]::Equals($wantOut, $out)) { Bad $name 'stdout differs'; Show-Diff $wantOut $out; continue }
            if ($r.Code -ne 0) { Bad $name "exit code $($r.Code); stderr: $($r.Err.Trim())"; continue }
            Pass $name
        }
    }
    $exe = $stage0Exe

    Say ''
    Say 'stage 1 smoke tests'
    $envoc1 = Join-Path $Build1 'envoc1.exe'
    $r = Invoke-Tool $envoc1 @('version') $Root
    if ($r.Code -eq 0 -and $r.Out.StartsWith('envoc1 ')) { Pass 'envoc1 version' } else { Bad 'envoc1 version' "exit $($r.Code), stdout: $($r.Out)" }
    $r = Invoke-Tool $envoc1 @('selftest') $Root
    if ($r.Code -eq 0 -and $r.Out.StartsWith('selftest: ok')) { Pass 'envoc1 selftest' } else { Bad 'envoc1 selftest' "exit $($r.Code), output: $($r.Out)$($r.Err)" }
    $r = Invoke-Tool $envoc1 @() $Root
    if ($r.Code -eq 2 -and $r.Err.StartsWith('usage: envoc1')) { Pass 'envoc1 no arguments' } else { Bad 'envoc1 no arguments' "exit $($r.Code), stderr: $($r.Err)" }
    $r = Invoke-Tool $envoc1 @('frobnicate') $Root
    if ($r.Code -eq 2 -and $r.Err.StartsWith("envoc1: error: unknown command 'frobnicate'")) { Pass 'envoc1 unknown command' } else { Bad 'envoc1 unknown command' "exit $($r.Code), stderr: $($r.Err)" }

    # The runtime embedded in envoc1 must be generated from the current runtime sources.
    $r = Invoke-Tool $envoc1 @('embed', 'runtime/common.envo', 'runtime/linux.envo', 'runtime/windows.envo', 'prelude/prelude.envo') $Stage1
    $expected = Normalize ([IO.File]::ReadAllText((Join-Path $Stage1 'runtime\embedded.envo'), $Utf8))
    if ($r.Code -eq 0 -and [string]::Equals($expected, (Normalize $r.Out))) { Pass 'envoc1 embedded runtime' }
    else { Bad 'envoc1 embedded runtime' 'bootstrap/stage1/runtime/embedded.envo is stale: regenerate it with envoc1 embed (see docs/architecture/stage1.md)' }

    # The x86-64 encoder and image writer: a minimal native program must exit with 42.
    $t42 = Join-Path $tmp 't42.exe'
    $r = Invoke-Tool $envoc1 @('selftest-image', $t42, 'windows') $Root
    if ($r.Code -eq 0) {
        $r = Invoke-Tool $t42 @() $Root
        if ($r.Code -eq 42) { Pass 'envoc1 selftest-image' } else { Bad 'envoc1 selftest-image' "exit $($r.Code), expected 42" }
    } else { Bad 'envoc1 selftest-image' "exit $($r.Code), stderr: $($r.Err)" }

    # Differential tests (PLAN D14). Golden suites: envoc1 must print exactly envoc0's
    # expected files, in --core mode and in Envo-S1 mode (Core programs mean the same in
    # S1). Spec suites: the same error code at the same position; lexical tests run in
    # both modes (E0901-E0904 become E0950 in S1), syntax tests in --core mode.
    # Keep these lists in step with bootstrap.sh.
    $stage1Golden = @(
        @{ Dir = 'lexer';  Command = 'lex';   Ext = '.tokens' },
        @{ Dir = 'parser'; Command = 'parse'; Ext = '.ast' },
        @{ Dir = 'check';  Command = 'check'; Ext = '.check' },
        @{ Dir = 's1-parser'; Command = 'parse'; Ext = '.ast'; Modes = @('s1') }
    )
    foreach ($suite in $stage1Golden) {
      $modes = @('--core', 's1')
      if ($suite.Modes) { $modes = $suite.Modes }
      foreach ($mode in $modes) {
        $pre = @()
        if ($mode -eq '--core') { $pre = @('--core') }
        Say "stage 1 golden tests ($mode): tests/golden/$($suite.Dir)"
        $dir = Join-Path $Root "tests\golden\$($suite.Dir)"
        foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envo' | Sort-Object Name) {
            $name = "stage1 $mode golden/$($suite.Dir)/$($f.Name)"
            $r = Invoke-Tool $envoc1 ($pre + @($suite.Command, $f.Name)) $dir
            if ($r.Code -ne 0) { Bad $name "exit $($r.Code), stderr: $($r.Err.Trim())"; continue }
            $expected = Normalize ([IO.File]::ReadAllText(($f.FullName -replace '\.envo$', $suite.Ext), $Utf8))
            $actual = Normalize $r.Out
            if ([string]::Equals($expected, $actual)) { Pass $name } else { Bad $name 'output differs'; Show-Diff $expected $actual }
        }
      }
    }
    $stage1Spec = @(
        @{ Dir = '01-lexical';  Command = 'lex';   Modes = @('--core', 's1') },
        @{ Dir = 'core-syntax'; Command = 'parse'; Modes = @('--core') },
        @{ Dir = 'core-types';  Command = 'check'; Modes = @('--core') },
        @{ Dir = 's1-syntax';   Command = 'parse'; Modes = @('s1') },
        @{ Dir = 's1-types';    Command = 'check'; Modes = @('s1') },
        @{ Dir = 's1-own';      Command = 'check'; Modes = @('s1') }
    )
    foreach ($suite in $stage1Spec) {
      foreach ($mode in $suite.Modes) {
        $pre = @()
        if ($mode -eq '--core') { $pre = @('--core') }
        Say "stage 1 spec tests ($mode): tests/spec/$($suite.Dir)"
        $dir = Join-Path $Root "tests\spec\$($suite.Dir)"
        foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envo' | Sort-Object Name) {
            $name = "stage1 $mode spec/$($suite.Dir)/$($f.Name)"
            $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($f.FullName))
            $m = [regex]::Match($text, '(?m)^// expect-error: (E\d{4}) @ (\d+:\d+)')
            if (-not $m.Success) { Bad $name 'no // expect-error: annotation with a position'; continue }
            $code = $m.Groups[1].Value
            if ($mode -eq 's1' -and $code -match '^E090[1-4]$') { $code = 'E0950' }
            $want = "$($f.Name):$($m.Groups[2].Value): error[$code]"
            $r = Invoke-Tool $envoc1 ($pre + @($suite.Command, $f.Name)) $dir
            if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $name }
            else { Bad $name "expected exit 1 with '$want'; got exit $($r.Code), stderr: $($r.Err.Trim())" }
        }
      }
    }
    # Multi-file error tests, and Stage 1 checking its own source (D14).
    Say 'stage 1 multi-file tests (--core): tests/spec/core-multi'
    foreach ($d in Get-ChildItem -LiteralPath (Join-Path $Root 'tests\spec\core-multi') -Directory | Sort-Object Name) {
        $main = Join-Path $d.FullName 'main.envo'
        $m = [regex]::Match([IO.File]::ReadAllText($main, $Utf8), '(?m)^// expect-error: (E\d{4}) @ (\S+)')
        if (-not $m.Success) { continue }
        $files = @('main.envo') + @(Get-ChildItem -LiteralPath $d.FullName -Filter '*.envo' | Where-Object { $_.Name -ne 'main.envo' } | Sort-Object Name | ForEach-Object { $_.Name })
        $want = "$($m.Groups[2].Value): error[$($m.Groups[1].Value)]"
        $r = Invoke-Tool $envoc1 (@('--core', 'check') + $files) $d.FullName
        if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $d.Name }
        else { Bad "stage1 --core core-multi/$($d.Name)" "expected exit 1 with '$want'; got exit $($r.Code), stderr: $($r.Err.Trim())" }
    }
    # EIR v1 (M2.6): canonical printing round-trips, and verifier errors.
    Say 'stage 1 golden tests: tests/golden/eir'
    $dir = Join-Path $Root 'tests\golden\eir'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.eir' | Sort-Object Name) {
        $expected = Normalize ([IO.File]::ReadAllText(($f.FullName -replace '\.eir$', '.out'), $Utf8))
        foreach ($input in @($f.Name, ($f.Name -replace '\.eir$', '.out'))) {
            $r = Invoke-Tool $envoc1 @('eir-check', $input) $dir
            $actual = Normalize $r.Out
            if ($r.Code -eq 0 -and [string]::Equals($expected, $actual)) { Pass $input }
            else { Bad "golden/eir/$input" "exit $($r.Code), stderr: $($r.Err.Trim())"; Show-Diff $expected $actual }
        }
    }
    Say 'stage 1 spec tests: tests/spec/eir'
    $dir = Join-Path $Root 'tests\spec\eir'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.eir' | Sort-Object Name) {
        $m = [regex]::Match([IO.File]::ReadAllText($f.FullName, $Utf8), '(?m)^; expect-error: (E\d{4}) @ (\d+:\d+)')
        if (-not $m.Success) { Bad "spec/eir/$($f.Name)" 'no ; expect-error: annotation'; continue }
        $want = "$($f.Name):$($m.Groups[2].Value): error[$($m.Groups[1].Value)]"
        $r = Invoke-Tool $envoc1 @('eir-check', $f.Name) $dir
        if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $f.Name }
        else { Bad "spec/eir/$($f.Name)" "expected exit 1 with '$want'; got exit $($r.Code), stderr: $($r.Err.Trim())" }
    }
    Say 'stage 1 self-check: envoc1 --core check bootstrap/stage1'
    $files = @(Get-Content -LiteralPath (Join-Path $Stage1 'files.txt') | Where-Object { $_.Trim() -ne '' })
    $r = Invoke-Tool $envoc1 (@('--core', 'check') + $files) $Stage1
    if ($r.Code -eq 0) { Pass 'stage1 self-check' } else { Bad 'stage1 self-check' "exit $($r.Code), stderr: $($r.Err.Trim())" }

    Say ''
    Say "$($script:passed) passed, $($script:failed) failed"
    if ($script:failed -gt 0) { exit 1 }
}

# ------------------------------------------------------------------- check
function Invoke-Check {
    $problems = New-Object System.Collections.Generic.List[string]

    foreach ($f in @('README.md', 'CHARTER.md', 'STATUS.md', 'CONTRIBUTING.md', 'SECURITY.md',
                     'CODE_OF_CONDUCT.md', 'LICENSE', 'LICENSING.md', 'CLA.md', 'TRADEMARKS.md',
                     'LICENSES/PolyForm-Noncommercial-1.0.0.md', 'LICENSES/LicenseRef-EnvoScale-Commercial.md', 'envo.eon', 'bootstrap.sh', 'bootstrap.ps1',
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

    # docs/spec/eas.md: every jump states its size, so the bytes depend on the source alone.
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root 'bootstrap') -Recurse -Filter '*.eas') {
        $hits = Select-String -LiteralPath $f.FullName -CaseSensitive -Pattern '^\s*j[a-z]+\s+[.A-Za-z_]' |
            Where-Object { $_.Line -notmatch '^\s*j[a-z]+\s+((short|near)\s|r[a-z0-9]+\s*(;|$))' }
        foreach ($h in $hits) { $problems.Add("jump without short/near: $($f.FullName.Substring($Root.Length + 1)):$($h.LineNumber)") }
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
        Say '  build   assemble Stage 0 (needs NASM; see adapters/bootstrap/nasm/README.md), then build Stage 1'
        Say '  test    build, then run the Stage 0 and Stage 1 tests'
        Say '  check   repository layout, lib->adapters imports, Hello World Gallery limits'
        Say '  clean   delete build/'
        if ($Command -ne 'help') { exit 2 }
    }
}
