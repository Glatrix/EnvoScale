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
$Build2 = Join-Path $Root 'build\stage2'
$Stage2 = Join-Path $Root 'compiler'
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

    # Stage 2 is an Envo-S1 program (PLAN D16); envoc1 builds it for both OSes.
    New-Item -ItemType Directory -Force $Build2 | Out-Null
    $envoc1 = Join-Path $Build1 'envoc1.exe'
    $files = @(Get-Content -LiteralPath (Join-Path $Stage2 'files.txt') | Where-Object { $_.Trim() -ne '' })
    foreach ($u in @(@{ Target = 'x86_64-windows'; Out = 'envoc.exe' }, @{ Target = 'x86_64-linux'; Out = 'envoc' })) {
        $out = Join-Path $Build2 $u.Out
        Say "build     compiler -> build/stage2/$($u.Out)"
        $r = Invoke-Tool $envoc1 (@('build') + $files + @('-o', $out, '--target', $u.Target)) $Stage2
        if ($r.Code -ne 0) { Fail "building Stage 2 ($($u.Target)) failed: $($r.Err.Trim())" }
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $out).Hash.ToLowerInvariant()
        $size = (Get-Item -LiteralPath $out).Length
        Say ("          {0,8} bytes  sha256 {1}" -f $size, $hash)
    }

    # envo holds the compiler (PLAN D26): tools\envo plus compiler\ without its entry
    # file, built by Stage 2 with the library (--lib).
    $envoDir = Join-Path $Root 'build\envo'
    New-Item -ItemType Directory -Force $envoDir | Out-Null
    $envoc = Join-Path $Build2 'envoc.exe'
    $files = @(Get-Content -LiteralPath (Join-Path $Root 'tools\envo\files.txt') | Where-Object { $_.Trim() -ne '' })
    $files += @(Get-Content -LiteralPath (Join-Path $Stage2 'files.txt') | Where-Object { $_.Trim() -ne '' -and $_.Trim() -ne 'driver/main.envo' } | ForEach-Object { "compiler/$($_.Trim())" })
    foreach ($u in @(@{ Target = 'x86_64-windows'; Out = 'envo.exe' }, @{ Target = 'x86_64-linux'; Out = 'envo' })) {
        $out = Join-Path $envoDir $u.Out
        Say "build     tools/envo -> build/envo/$($u.Out)"
        $r = Invoke-Tool $envoc (@('build', '-O2', '--lib', $Root) + $files + @('-o', $out, '--target', $u.Target)) $Root
        if ($r.Code -ne 0) { Fail "building envo ($($u.Target)) failed: $($r.Err.Trim())" }
        $size = (Get-Item -LiteralPath $out).Length
        Say ("          {0,8} bytes" -f $size)
    }
}

# ------------------------------------------------------------------- fixed point
# PLAN D18, M3.9: stage2a (build\stage2, built by envoc1) builds Stage 2 at -O2 into
# build\stage2b, and stage2b builds it again into build\stage2c, for both targets.
# stage2b and stage2c must be byte-identical. Keep in step with bootstrap.sh.
function Invoke-FixedPoint {
    Invoke-Build
    $files = @(Get-Content -LiteralPath (Join-Path $Stage2 'files.txt') | Where-Object { $_.Trim() -ne '' })
    foreach ($step in @(@{ From = 'stage2'; To = 'stage2b' }, @{ From = 'stage2b'; To = 'stage2c' })) {
        $dir = Join-Path $Root "build\$($step.To)"
        New-Item -ItemType Directory -Force $dir | Out-Null
        $exe = Join-Path $Root "build\$($step.From)\envoc.exe"
        foreach ($u in @(@{ Target = 'x86_64-linux'; Out = 'envoc' }, @{ Target = 'x86_64-windows'; Out = 'envoc.exe' })) {
            $out = Join-Path $dir $u.Out
            Say "build     compiler -> build/$($step.To)/$($u.Out) (by build/$($step.From)/envoc.exe, -O2)"
            $r = Invoke-Tool $exe (@('build') + $files + @('-O2', '-o', $out, '--target', $u.Target)) $Stage2
            if ($r.Code -ne 0) { Fail "building Stage 2 ($($u.Target)) with build/$($step.From) failed: $($r.Err.Trim())" }
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $out).Hash.ToLowerInvariant()
            Say ("          {0,8} bytes  sha256 {1}" -f (Get-Item -LiteralPath $out).Length, $hash)
        }
    }
    foreach ($out in @('envoc', 'envoc.exe')) {
        $b = Join-Path $Root "build\stage2b\$out"
        $c = Join-Path $Root "build\stage2c\$out"
        if ((Get-FileHash -LiteralPath $b).Hash -eq (Get-FileHash -LiteralPath $c).Hash) { Say "fixed point: stage2b/$out = stage2c/$out" }
        else { Fail "no fixed point: build/stage2b/$out and build/stage2c/$out differ" }
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

# Stage 2 only (M3.7): compiles each of the files to an object (--unit), links the objects
# and returns a problem unless the result is the executable `build` wrote, or $null.
function Test-Objects([string]$exe, [string]$dir, [string]$program, [string[]]$files) {
    $objs = @()
    for ($k = 0; $k -lt $files.Count; $k++) {
        $obj = "$program.$k.eo"
        $r = Invoke-Tool $exe (@('compile') + $files + @('--unit', $files[$k], '-o', $obj)) $dir
        if ($r.Code -ne 0) { return "compile --unit $($files[$k]) failed: $($r.Err.Trim())" }
        $objs += $obj
    }
    $r = Invoke-Tool $exe (@('link') + $objs + @('-o', "$program.linked")) $dir
    if ($r.Code -ne 0) { return "link failed: $($r.Err.Trim())" }
    if (-not (Test-SameBytes $program "$program.linked")) { return 'the linked executable differs from the build' }
    return $null
}

# True if the files at a and b hold the same bytes.
function Test-SameBytes([string]$a, [string]$b) {
    if (-not (Test-Path -LiteralPath $a) -or -not (Test-Path -LiteralPath $b)) { return $false }
    $latin1 = [Text.Encoding]::GetEncoding(28591)
    return [string]::Equals($latin1.GetString([IO.File]::ReadAllBytes($a)), $latin1.GetString([IO.File]::ReadAllBytes($b)))
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
    # Then by Stage 2, whose executables must be byte-identical to Stage 1's (M3.6).
    $stage0Exe = $exe
    foreach ($compiler in @('envoc0', 'envoc1', 'envoc')) {
    if ($compiler -eq 'envoc1') { $exe = Join-Path $Build1 'envoc1.exe' }
    elseif ($compiler -eq 'envoc') { $exe = Join-Path $Build2 'envoc.exe' }
    else { $exe = $stage0Exe }
        $runDir = Join-Path $Root "build\run-$compiler"
        New-Item -ItemType Directory -Force $runDir | Out-Null
        # Envo-S1 programs (tests/spec/s1-run) run under Stages 1 and 2 only.
        $runSuites = @('core-run')
        if ($compiler -ne 'envoc0') { $runSuites += 's1-run' }
        # programs only Stage 2 accepts (tests/spec/s2-run, M3.10)
        if ($compiler -eq 'envoc') { $runSuites += 's2-run' }
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
            if ($suite -eq 's2-run') {
                # Stage 1 rejects it, with the code the test names
                $m1 = [regex]::Match($text, '(?m)^// stage1-error: (E\d{4})')
                $r1 = Invoke-Tool (Join-Path $Build1 'envoc1.exe') @('check', $f.FullName) $runDir
                if (-not $m1.Success -or $r1.Code -ne 1 -or -not $r1.Err.Contains("error[$($m1.Groups[1].Value)]")) { Bad $name "envoc1 should reject it with the // stage1-error: code; exit $($r1.Code)"; continue }
            } elseif ($compiler -eq 'envoc') {
                if (-not (Test-SameBytes $program (Join-Path $Root "build\run-envoc1\$(Split-Path -Leaf $program)"))) { Bad $name 'the executable differs from the envoc1 build'; continue }
            }
            if ($compiler -eq 'envoc') {
                $problem = Test-Objects $exe $runDir $program @($f.FullName)
                if ($problem) { Bad $name $problem; continue }
                # the object holds the program's EIR, in the binary form
                $r1 = Invoke-Tool $exe @('eir', $f.FullName) $runDir
                $r2 = Invoke-Tool $exe @('eir-check', "$program.0.eo") $runDir
                if ($r2.Code -ne 0 -or -not [string]::Equals($r1.Out, $r2.Out)) { Bad $name "eir-check of the object differs from eir: exit $($r2.Code)"; continue }
            }
            $r = Invoke-Tool $program @() $runDir
            $out = Normalize $r.Out
            if (-not [string]::Equals($wantOut, $out)) { Bad $name 'stdout differs'; Show-Diff $wantOut $out; continue }
            if ($r.Code -ne $wantCode) { Bad $name "exit code $($r.Code), expected $wantCode; stderr: $($r.Err.Trim())"; continue }
            if ($panic.Success -and -not $r.Err.Contains("panic: $($panic.Groups[1].Value)")) { Bad $name "stderr: $($r.Err.Trim())"; continue }
            if ($compiler -eq 'envoc') {
                # -O2 (M3.8): the same output, exit code and panic
                $fast = Join-Path $runDir ($f.BaseName + '-O2.exe')
                $r = Invoke-Tool $exe @('build', '-O2', $f.FullName, '-o', $fast) $runDir
                if ($r.Code -ne 0) { Bad $name "-O2 build failed: $($r.Err.Trim())"; continue }
                $r = Invoke-Tool $fast @() $runDir
                if (-not [string]::Equals($wantOut, (Normalize $r.Out)) -or $r.Code -ne $wantCode) { Bad $name "-O2: stdout or exit code ($($r.Code)) differs"; continue }
                if ($panic.Success -and -not $r.Err.Contains("panic: $($panic.Groups[1].Value)")) { Bad $name "-O2 stderr: $($r.Err.Trim())"; continue }
            }
            Pass $name
        }
        }

        # Multi-file programs: one folder per test. main.envo is the entry file and holds
        # the annotations; the other .envo files follow in name order. Either
        # `// expect-error: E#### @ <file>:L:C` (envoc0 check) or `// expect:` lines (build, run).
        # Envo-S1 programs of several files (tests/spec/s1-multi) under Stages 1 and 2 only.
        $multiSuites = @('core-multi')
        if ($compiler -ne 'envoc0') { $multiSuites += 's1-multi' }
        foreach ($msuite in $multiSuites) {
        Say "multi-file tests ($compiler): tests/spec/$msuite"
        foreach ($d in Get-ChildItem -LiteralPath (Join-Path $Root "tests\spec\$msuite") -Directory | Sort-Object Name) {
            $name = "$compiler spec/$msuite/$($d.Name)"
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
            $program = Join-Path $runDir ("$msuite-" + $d.Name + '.exe')
            $r = Invoke-Tool $exe (@('build') + $files + @('-o', $program)) $d.FullName
            if ($r.Code -ne 0) { Bad $name "build failed: $($r.Err.Trim())"; continue }
            if ($compiler -eq 'envoc') {
                if (-not (Test-SameBytes $program (Join-Path $Root "build\run-envoc1\$(Split-Path -Leaf $program)"))) { Bad $name 'the executable differs from the envoc1 build'; continue }
                $problem = Test-Objects $exe $d.FullName $program $files
                if ($problem) { Bad $name $problem; continue }
            }
            $r = Invoke-Tool $program @() $runDir
            $out = Normalize $r.Out
            if (-not [string]::Equals($wantOut, $out)) { Bad $name 'stdout differs'; Show-Diff $wantOut $out; continue }
            if ($r.Code -ne 0) { Bad $name "exit code $($r.Code); stderr: $($r.Err.Trim())"; continue }
            if ($compiler -eq 'envoc') {
                $fast = Join-Path $runDir ("$msuite-" + $d.Name + '-O2.exe')
                $r = Invoke-Tool $exe (@('build', '-O2') + $files + @('-o', $fast)) $d.FullName
                if ($r.Code -ne 0) { Bad $name "-O2 build failed: $($r.Err.Trim())"; continue }
                $r = Invoke-Tool $fast @() $runDir
                if (-not [string]::Equals($wantOut, (Normalize $r.Out)) -or $r.Code -ne 0) { Bad $name "-O2: stdout or exit code ($($r.Code)) differs"; continue }
            }
            Pass $name
        }
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
    # Stage 2 embeds the same runtime and prelude (compiler/driver/runtime.envo).
    $r = Invoke-Tool $envoc1 @('embed', 'bootstrap/stage1/runtime/common.envo', 'bootstrap/stage1/runtime/linux.envo', 'bootstrap/stage1/runtime/windows.envo', 'bootstrap/stage1/prelude/prelude.envo') $Root
    $expected = Normalize ([IO.File]::ReadAllText((Join-Path $Root 'compiler\driver\runtime.envo'), $Utf8))
    if ($r.Code -eq 0 -and [string]::Equals($expected, (Normalize $r.Out))) { Pass 'envoc embedded runtime' }
    else { Bad 'envoc embedded runtime' "compiler/driver/runtime.envo is stale: regenerate it with envoc1 embed and Stage 1's runtime and prelude files (see docs/architecture/stage2.md)" }
    # and the WebAssembly OS layer, as RUNTIME_WASM (compiler/driver/runtime_wasm.envo)
    $r = Invoke-Tool $envoc1 @('embed', 'compiler/runtime/wasm.envo') $Root
    $expected = Normalize ([IO.File]::ReadAllText((Join-Path $Root 'compiler\driver\runtime_wasm.envo'), $Utf8))
    $actual = (Normalize $r.Out) -replace '(?m)^const str RUNTIME_0 = ', 'const str RUNTIME_WASM = '
    if ($r.Code -eq 0 -and [string]::Equals($expected, $actual)) { Pass 'envoc embedded wasm runtime' }
    else { Bad 'envoc embedded wasm runtime' 'compiler/driver/runtime_wasm.envo is stale: regenerate it with envoc1 embed compiler/runtime/wasm.envo, renaming RUNTIME_0 to RUNTIME_WASM' }

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
    Say 'stage 2 smoke tests'
    $envoc = Join-Path $Build2 'envoc.exe'
    $r = Invoke-Tool $envoc @('version') $Root
    if ($r.Code -eq 0 -and $r.Out.StartsWith('envoc ')) { Pass 'envoc version' } else { Bad 'envoc version' "exit $($r.Code)" }
    $r = Invoke-Tool $envoc @('selftest') $Root
    if ($r.Code -eq 0 -and $r.Out.StartsWith('selftest: ok')) { Pass 'envoc selftest' } else { Bad 'envoc selftest' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    $r = Invoke-Tool $envoc @() $Root
    if ($r.Code -eq 2 -and $r.Err.StartsWith('usage: envoc')) { Pass 'envoc no arguments' } else { Bad 'envoc no arguments' "exit $($r.Code)" }
    $r = Invoke-Tool $envoc @('frobnicate') $Root
    if ($r.Code -eq 2 -and $r.Err.StartsWith("envoc: error: unknown command 'frobnicate'")) { Pass 'envoc unknown command' } else { Bad 'envoc unknown command' "exit $($r.Code)" }

    # The Stage 2 front end and checker (M3.2-M3.5): the lexer, parser and checker goldens
    # and the lexical, syntax, type and ownership spec tests, in the same modes as for
    # Stage 1; then the same output as envoc1 from `lex` and `parse` on every source file,
    # from `check` on the run programs and goldens, and on both compilers' sources (D17).
    # Keep in step with bootstrap.sh.
    $stage2Golden = @(
        @{ Dir = 'lexer';     Command = 'lex';   Ext = '.tokens'; Modes = @('--core', 's1') },
        @{ Dir = 'parser';    Command = 'parse'; Ext = '.ast';    Modes = @('--core', 's1') },
        @{ Dir = 's1-parser'; Command = 'parse'; Ext = '.ast';    Modes = @('s1') },
        @{ Dir = 'check';     Command = 'check'; Ext = '.check';  Modes = @('--core', 's1') }
    )
    foreach ($suite in $stage2Golden) {
      foreach ($mode in $suite.Modes) {
        $pre = @()
        if ($mode -eq '--core') { $pre = @('--core') }
        Say "stage 2 golden tests ($mode): tests/golden/$($suite.Dir)"
        $dir = Join-Path $Root "tests\golden\$($suite.Dir)"
        foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envo' | Sort-Object Name) {
            $name = "stage2 $mode golden/$($suite.Dir)/$($f.Name)"
            $r = Invoke-Tool $envoc ($pre + @($suite.Command, $f.Name)) $dir
            if ($r.Code -ne 0) { Bad $name "exit $($r.Code), stderr: $($r.Err.Trim())"; continue }
            $expected = Normalize ([IO.File]::ReadAllText(($f.FullName -replace '\.envo$', $suite.Ext), $Utf8))
            $actual = Normalize $r.Out
            if ([string]::Equals($expected, $actual)) { Pass $name } else { Bad $name 'output differs'; Show-Diff $expected $actual }
        }
      }
    }
    $stage2Spec = @(
        @{ Dir = '01-lexical';  Command = 'lex';   Modes = @('--core', 's1') },
        @{ Dir = 'core-syntax'; Command = 'parse'; Modes = @('--core') },
        @{ Dir = 's1-syntax';   Command = 'parse'; Modes = @('s1') },
        @{ Dir = 'core-types';  Command = 'check'; Modes = @('--core') },
        @{ Dir = 's1-types';    Command = 'check'; Modes = @('s1') },
        @{ Dir = 's1-own';      Command = 'check'; Modes = @('s1') },
        @{ Dir = 's2-own';      Command = 'check'; Modes = @('s1') }
    )
    foreach ($suite in $stage2Spec) {
      foreach ($mode in $suite.Modes) {
        $pre = @()
        if ($mode -eq '--core') { $pre = @('--core') }
        Say "stage 2 spec tests ($mode): tests/spec/$($suite.Dir)"
        $dir = Join-Path $Root "tests\spec\$($suite.Dir)"
        foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envo' | Sort-Object Name) {
            $name = "stage2 $mode spec/$($suite.Dir)/$($f.Name)"
            $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($f.FullName))
            $m = [regex]::Match($text, '(?m)^// expect-error: (E\d{4}) @ (\d+:\d+)')
            if (-not $m.Success) { Bad $name 'no // expect-error: annotation with a position'; continue }
            $code = $m.Groups[1].Value
            if ($mode -eq 's1' -and $code -match '^E090[1-4]$') { $code = 'E0950' }
            $want = "$($f.Name):$($m.Groups[2].Value): error[$code]"
            $r = Invoke-Tool $envoc ($pre + @($suite.Command, $f.Name)) $dir
            if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $name }
            else { Bad $name "expected exit 1 with '$want'; got exit $($r.Code), stderr: $($r.Err.Trim())" }
        }
      }
    }
    # EIR (M3.6): the same goldens and verifier errors as Stage 1.
    Say 'stage 2 golden tests: tests/golden/eir'
    $dir = Join-Path $Root 'tests\golden\eir'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.eir' | Sort-Object Name) {
        $expected = Normalize ([IO.File]::ReadAllText(($f.FullName -replace '\.eir$', '.out'), $Utf8))
        foreach ($input in @($f.Name, ($f.Name -replace '\.eir$', '.out'))) {
            $r = Invoke-Tool $envoc @('eir-check', $input) $dir
            $actual = Normalize $r.Out
            if ($r.Code -eq 0 -and [string]::Equals($expected, $actual)) { Pass $input }
            else { Bad "stage2 golden/eir/$input" "exit $($r.Code), stderr: $($r.Err.Trim())"; Show-Diff $expected $actual }
        }
        # the binary form (M3.7): text -> binary -> text, and binary -> binary
        $b1 = Join-Path $Build2 'golden-1.eirb'
        $b2 = Join-Path $Build2 'golden-2.eirb'
        $r = Invoke-Tool $envoc @('eir-check', $f.Name, '-o', $b1) $dir
        if ($r.Code -eq 0) { $r = Invoke-Tool $envoc @('eir-check', $b1) $dir }
        $actual = Normalize $r.Out
        if ($r.Code -eq 0) { $r = Invoke-Tool $envoc @('eir-check', $b1, '-o', $b2) $dir }
        if ($r.Code -eq 0 -and [string]::Equals($expected, $actual) -and (Test-SameBytes $b1 $b2)) { Pass "$($f.Name) (binary)" }
        else { Bad "stage2 golden/eir/$($f.Name) (binary)" "exit $($r.Code), stderr: $($r.Err.Trim())" }
    }
    # -O2's EIR passes (M3.8)
    Say 'stage 2 golden tests: tests/golden/opt'
    $dir = Join-Path $Root 'tests\golden\opt'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.eir' | Sort-Object Name) {
        $expected = Normalize ([IO.File]::ReadAllText(($f.FullName -replace '\.eir$', '.out'), $Utf8))
        $r = Invoke-Tool $envoc @('eir-check', $f.Name, '-O2') $dir
        $actual = Normalize $r.Out
        if ($r.Code -eq 0 -and [string]::Equals($expected, $actual)) { Pass $f.Name }
        else { Bad "stage2 golden/opt/$($f.Name)" "exit $($r.Code), stderr: $($r.Err.Trim())"; Show-Diff $expected $actual }
    }
    Say 'stage 2 spec tests: tests/spec/eir'
    $dir = Join-Path $Root 'tests\spec\eir'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.eir' | Sort-Object Name) {
        $m = [regex]::Match([IO.File]::ReadAllText($f.FullName, $Utf8), '(?m)^; expect-error: (E\d{4}) @ (\d+:\d+)')
        if (-not $m.Success) { Bad "stage2 spec/eir/$($f.Name)" 'no ; expect-error: annotation'; continue }
        $want = "$($f.Name):$($m.Groups[2].Value): error[$($m.Groups[1].Value)]"
        $r = Invoke-Tool $envoc @('eir-check', $f.Name) $dir
        if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $f.Name }
        else { Bad "stage2 spec/eir/$($f.Name)" "expected exit 1 with '$want'; got exit $($r.Code), stderr: $($r.Err.Trim())" }
    }
    # The standard platform and the examples (PLAN D29): `envo test` builds and runs each
    # library test, adapter test and conformance suite (the suites against the reference
    # and the native adapters) at -O0 and -O2, and builds each example package. Keep in
    # step with bootstrap.sh.
    Say 'envo test: lib, adapters, tests/conformance, examples'
    $envo = Join-Path $Root 'build\envo\envo.exe'
    $r = Invoke-Tool $envo @('test', 'lib', 'adapters', 'tests/conformance', 'examples') $Root
    $m = [regex]::Match($r.Out, '(\d+) passed, (\d+) failed')
    if (-not $m.Success) { Bad 'envo test' "no summary (exit $($r.Code)): $($r.Err.Trim())" }
    else {
        $script:passed += [int]$m.Groups[1].Value
        $nfail = [int]$m.Groups[2].Value
        if ($nfail -gt 0 -or $r.Code -ne 0) { Bad 'envo test' (Normalize $r.Out).Trim(); $script:failed += [Math]::Max(0, $nfail - 1) }
    }
    # The script runtime (PLAN D35): every spec run program, and every multi-file one, runs
    # in the VM (`envo run -A`) with the output, exit code and panic it has natively.
    Say 'script runtime: tests/spec/core-run, s1-run, s2-run and the multi-file programs in the VM'
    $vmDir = Join-Path $Root 'build\run-vm'
    New-Item -ItemType Directory -Force $vmDir | Out-Null
    foreach ($suite in @('core-run', 's1-run', 's2-run')) {
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root "tests\spec\$suite") -Filter '*.envo' | Sort-Object Name) {
            $text = Normalize ([IO.File]::ReadAllText($f.FullName, $Utf8))
            $lines = @([regex]::Matches($text, '(?m)^// expect: (.*)$') | ForEach-Object { $_.Groups[1].Value })
            $wantOut = ''
            if ($lines.Count -gt 0) { $wantOut = ($lines -join "`n") + "`n" }
            $wantCode = 0
            $m = [regex]::Match($text, '(?m)^// expect-exit: (\d+)')
            if ($m.Success) { $wantCode = [int]$m.Groups[1].Value }
            $panic = [regex]::Match($text, '(?m)^// expect-panic: (.*)$')
            if ($panic.Success) { $wantCode = 101 }
            $name = "vm spec/$suite/$($f.Name)"
            $r = Invoke-Tool $envo @('run', '-A', $f.FullName) $vmDir
            $out = Normalize $r.Out
            if ($out -ne $wantOut) { Bad $name 'stdout differs'; Show-Diff $wantOut $out; continue }
            if ($r.Code -ne $wantCode) { Bad $name "exit code $($r.Code), expected $($wantCode): $($r.Err.Trim())"; continue }
            if ($panic.Success -and -not $r.Err.Contains("panic: $($panic.Groups[1].Value.Trim())")) { Bad $name "stderr: $($r.Err.Trim())"; continue }
            Pass $name
        }
    }
    foreach ($msuite in @('core-multi', 's1-multi')) {
        foreach ($d in Get-ChildItem -LiteralPath (Join-Path $Root "tests\spec\$msuite") -Directory | Sort-Object Name) {
            $main = Join-Path $d.FullName 'main.envo'
            $text = Normalize ([IO.File]::ReadAllText($main, $Utf8))
            if ($text -match '(?m)^// expect-error: ') { continue }
            $files = @('main.envo') + @(Get-ChildItem -LiteralPath $d.FullName -Filter '*.envo' | Where-Object { $_.Name -ne 'main.envo' } | Sort-Object Name | ForEach-Object { $_.Name })
            $lines = @([regex]::Matches($text, '(?m)^// expect: (.*)$') | ForEach-Object { $_.Groups[1].Value })
            $wantOut = ''
            if ($lines.Count -gt 0) { $wantOut = ($lines -join "`n") + "`n" }
            $r = Invoke-Tool $envo (@('run', '-A') + $files) $d.FullName
            if ($r.Code -eq 0 -and (Normalize $r.Out) -eq $wantOut) { Pass "vm spec/$msuite/$($d.Name)" } else { Bad "vm spec/$msuite/$($d.Name)" "exit $($r.Code): $($r.Err.Trim())"; Show-Diff $wantOut (Normalize $r.Out) }
        }
    }
    # Permissions (PLAN D34): each tests\sandbox program runs with its `// allow:` lines as
    # --allow, in a scratch copy of the folder; stdout must be its `// expect:` lines and
    # stderr must hold each `// expect-stderr:` text (tests/sandbox/README.md)
    Say 'script runtime permissions: tests/sandbox'
    $boxDir = Join-Path $Root 'build\run-sandbox'
    if (Test-Path -LiteralPath $boxDir) { Remove-Item -Recurse -Force $boxDir }
    New-Item -ItemType Directory -Force $boxDir | Out-Null
    Copy-Item -Path (Join-Path $Root 'tests\sandbox\*.envo') -Destination $boxDir
    foreach ($f in Get-ChildItem -LiteralPath $boxDir -Filter '*.envo' | Sort-Object Name) {
        $text = Normalize ([IO.File]::ReadAllText($f.FullName, $Utf8))
        $argv = @('run')
        foreach ($m in [regex]::Matches($text, '(?m)^// allow: (.*)$')) { $argv += @('--allow', $m.Groups[1].Value.Trim()) }
        $argv += $f.Name
        $lines = @([regex]::Matches($text, '(?m)^// expect: (.*)$') | ForEach-Object { $_.Groups[1].Value })
        $wantOut = ''
        if ($lines.Count -gt 0) { $wantOut = ($lines -join "`n") + "`n" }
        $r = Invoke-Tool $envo $argv $boxDir
        $problem = $null
        if ($r.Code -ne 0) { $problem = "exit $($r.Code): $($r.Err.Trim())" }
        elseif ((Normalize $r.Out) -ne $wantOut) { $problem = 'stdout differs'; Show-Diff $wantOut (Normalize $r.Out) }
        else {
            foreach ($m in [regex]::Matches($text, '(?m)^// expect-stderr: (.*)$')) {
                if (-not $r.Err.Contains($m.Groups[1].Value.Trim())) { $problem = "stderr lacks '$($m.Groups[1].Value.Trim())': $($r.Err.Trim())" }
            }
        }
        if ($problem) { Bad "sandbox $($f.Name)" $problem } else { Pass "sandbox $($f.Name)" }
    }
    # The TLS 1.3 client against openssl s_server (tests\tls\README.md), where openssl is
    # installed. Keep in step with bootstrap.sh.
    $openssl = Get-Command openssl -ErrorAction SilentlyContinue
    if (-not $openssl -and (Test-Path -LiteralPath 'C:\Program Files\Git\usr\bin\openssl.exe')) { $openssl = Get-Command 'C:\Program Files\Git\usr\bin\openssl.exe' }
    if ($openssl) {
        Say 'tls: tests/tls/client.envo against openssl s_server'
        $tdir = Join-Path $Root 'build\run-tls'
        if (Test-Path -LiteralPath $tdir) { Remove-Item -Recurse -Force $tdir }
        New-Item -ItemType Directory -Force $tdir | Out-Null
        $os = $openssl.Source
        [IO.File]::WriteAllText((Join-Path $tdir 'leaf.ext'), "subjectAltName=DNS:localhost,IP:127.0.0.1`nbasicConstraints=CA:FALSE`n", $Utf8)
        $steps = @(
            @('req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:prime256v1', '-nodes', '-keyout', 'ca.key', '-out', 'ca.pem', '-days', '30', '-subj', '/CN=Envo Test CA', '-addext', 'basicConstraints=critical,CA:TRUE', '-addext', 'keyUsage=critical,keyCertSign'),
            @('req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:prime256v1', '-nodes', '-keyout', 'other.key', '-out', 'other.pem', '-days', '30', '-subj', '/CN=Other CA'),
            @('req', '-newkey', 'rsa:2048', '-nodes', '-keyout', 'rsa.key', '-out', 'rsa.csr', '-subj', '/CN=localhost'),
            @('x509', '-req', '-in', 'rsa.csr', '-CA', 'ca.pem', '-CAkey', 'ca.key', '-CAcreateserial', '-out', 'rsa.pem', '-days', '30', '-sha256', '-extfile', 'leaf.ext'),
            @('req', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:prime256v1', '-nodes', '-keyout', 'ec.key', '-out', 'ec.csr', '-subj', '/CN=localhost'),
            @('x509', '-req', '-in', 'ec.csr', '-CA', 'ca.pem', '-CAkey', 'ca.key', '-CAcreateserial', '-out', 'ec.pem', '-days', '30', '-sha256', '-extfile', 'leaf.ext')
        )
        $certsOk = $true
        foreach ($s in $steps) {
            $r = Invoke-Tool $os $s $tdir
            if ($r.Code -ne 0) { $certsOk = $false; Bad 'tls certificates' $r.Err.Trim(); break }
        }
        if ($certsOk) {
            $client = Join-Path $tdir 'client.exe'
            $r = Invoke-Tool $envoc @('build', '--lib', $Root, (Join-Path $Root 'tests\tls\client.envo'), '-o', $client) $tdir
            if ($r.Code -ne 0) { Bad 'tls client build' $r.Err.Trim() }
            else {
                $port = 18443
                $cases = @(
                    @{ Key = 'rsa'; Suite = 'TLS_AES_128_GCM_SHA256'; Trust = 'ca.pem'; Want = 'HTTP/1.0 200 ok' },
                    @{ Key = 'ec'; Suite = 'TLS_CHACHA20_POLY1305_SHA256'; Trust = 'ca.pem'; Want = 'HTTP/1.0 200 ok' },
                    @{ Key = 'ec'; Suite = 'TLS_AES_128_GCM_SHA256'; Trust = 'other.pem'; Want = "failed: the server's certificate is not trusted" }
                )
                foreach ($c in $cases) {
                    $port++
                    $server = Start-Process -FilePath $os -ArgumentList @('s_server', '-tls1_3', '-accept', "$port", '-cert', "$($c.Key).pem", '-key', "$($c.Key).key", '-ciphersuites', $c.Suite, '-www', '-quiet') -WorkingDirectory $tdir -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $tdir 'server.log') -RedirectStandardError (Join-Path $tdir 'server.err')
                    Start-Sleep -Seconds 1
                    $r = Invoke-Tool $client @($c.Trust, "$port") $tdir
                    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
                    if ($r.Code -eq 0 -and $r.Out.Contains($c.Want)) { Pass "tls $($c.Key)" } else { Bad "tls $($c.Key) $($c.Suite) trusting $($c.Trust)" "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
                }
            }
        }
    } else {
        Say 'tls: skipped (no openssl on this machine)'
    }
    # The WebAssembly backend: the spec run programs and library tests under Node.js (adapters\interop\js\test-wasm.js).
    # Keep in step with bootstrap.sh.
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        Say 'wasm: tests/spec run programs and lib tests as WebAssembly under Node.js'
        $r = Invoke-Tool $node.Source @((Join-Path $Root 'adapters\interop\js\test-wasm.js'), $envoc) $Root
        if ($r.Code -eq 0) { Pass 'wasm spec run programs' } else { Bad 'wasm spec run programs' ($r.Out.Trim() + ' ' + $r.Err.Trim()) }
    } else {
        Say 'wasm: skipped (no Node.js on this machine)'
    }
    # envo's own commands: new, run, test, check, explain, version (tests/envo/README.md)
    Say 'envo commands: new, run, test, check, explain, version'
    $envoRun = Join-Path $Root 'build\run-envo'
    if (Test-Path -LiteralPath $envoRun) { Remove-Item -Recurse -Force $envoRun }
    New-Item -ItemType Directory -Force $envoRun | Out-Null
    $r = Invoke-Tool $envo @('new', 'demo') $envoRun
    if ($r.Code -eq 0 -and (Test-Path -LiteralPath (Join-Path $envoRun 'demo\envo.envon'))) { Pass 'envo new' } else { Bad 'envo new' "exit $($r.Code): $($r.Err.Trim())" }
    $r = Invoke-Tool $envo @('run', 'demo') $envoRun
    if ($r.Code -eq 0 -and (Normalize $r.Out) -eq "Hello, demo!`n") { Pass 'envo run' } else { Bad 'envo run' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    $r = Invoke-Tool $envo @('run', '--native', 'demo') $envoRun
    if ($r.Code -eq 0 -and (Normalize $r.Out) -eq "Hello, demo!`n") { Pass 'envo run --native' } else { Bad 'envo run --native' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    $r = Invoke-Tool $envo @('test', 'demo') $envoRun
    if ($r.Code -eq 0 -and $r.Out.Contains('4 passed, 0 failed')) { Pass 'envo test (package)' } else { Bad 'envo test (package)' "exit $($r.Code): $($r.Out.Trim())" }
    [IO.File]::WriteAllText((Join-Path $envoRun 'bad.envo'), "i32 x = ;`n", $Utf8)
    $r = Invoke-Tool $envo @('check', 'bad.envo') $envoRun
    if ($r.Code -eq 1 -and $r.Err.Contains('bad.envo:1:9: error[E0101]') -and $r.Err.Contains('1 | i32 x = ;') -and $r.Err.Contains('envo explain E0101')) { Pass 'envo check' } else { Bad 'envo check' "exit $($r.Code): $($r.Err.Trim())" }
    $r = Invoke-Tool $envo @('explain', 'E0004') $envoRun
    if ($r.Code -eq 0 -and $r.Out.Contains('E0004: unterminated string literal') -and $r.Out.Contains('[lex.str.1]')) { Pass 'envo explain' } else { Bad 'envo explain' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    $r = Invoke-Tool $envo @('explain', 'E9999') $envoRun
    if ($r.Code -eq 1) { Pass 'envo explain (unknown)' } else { Bad 'envo explain (unknown)' "exit $($r.Code)" }
    $r = Invoke-Tool $envo @('version') $envoRun
    if ($r.Code -eq 0 -and $r.Out.StartsWith('envo ')) { Pass 'envo version' } else { Bad 'envo version' "exit $($r.Code)" }
    # envo repl: cells piped in; each cell's output shows once, a bad cell shows its error
    $replIn = "print(`"hello`")`ni32 Twice(i32 x) {`n    return x * 2;`n}`nuse alloc.text;`nprint(text.Int(Twice(21) as i64).AsStr())`nu8 bad = nope;`n:quit`n"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $envo
    $psi.Arguments = 'repl'
    $psi.WorkingDirectory = $envoRun
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $Utf8
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    $bytes = $Utf8.GetBytes($replIn)
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.BaseStream.Close()
    $p.WaitForExit()
    $got = Normalize $outTask.Result
    $hellos = ([regex]::Matches($got, 'hello')).Count
    if ($p.ExitCode -eq 0 -and $hellos -eq 1 -and $got.Contains("42`n") -and $got.Contains('error[E0203]')) { Pass 'envo repl' } else { Bad 'envo repl' "exit $($p.ExitCode): $got $($errTask.Result)" }
    $r = Invoke-Tool $envo @('frobnicate') $envoRun
    if ($r.Code -eq 2) { Pass 'envo (unknown command)' } else { Bad 'envo (unknown command)' "exit $($r.Code)" }
    # envo fmt: each tests\golden\fmt\name.envo formats to name.expected, which formats to
    # itself; and the repository's own code is already in the canonical layout
    Say 'envo fmt: tests/golden/fmt, and --check on the code'
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root 'tests\golden\fmt') -Filter '*.envo' | Sort-Object Name) {
        $expected = [IO.Path]::ChangeExtension($f.FullName, '.expected')
        $want = Normalize ([IO.File]::ReadAllText($expected, $Utf8))
        $r = Invoke-Tool $envo @('fmt', '--stdout', $f.FullName) $envoRun
        if ($r.Code -eq 0 -and (Normalize $r.Out) -eq $want) { Pass "fmt $($f.Name)" } else { Bad "golden fmt/$($f.Name)" "exit $($r.Code): $($r.Err.Trim())"; Show-Diff $want (Normalize $r.Out) }
        $r = Invoke-Tool $envo @('fmt', '--stdout', $expected) $envoRun
        if ($r.Code -eq 0 -and (Normalize $r.Out) -eq $want) { Pass "fmt $($f.Name) (again)" } else { Bad "golden fmt/$($f.Name) (formatting the expected output changes it)" "exit $($r.Code)" }
    }
    $r = Invoke-Tool $envo @('fmt', '--check', 'lib', 'adapters', 'tools', 'tests/conformance', 'compiler', 'bootstrap/stage1', 'runtime', 'examples') $Root
    if ($r.Code -eq 0) { Pass 'envo fmt --check' } else { Bad 'envo fmt --check (run envo fmt on these files)' "$($r.Out.Trim()) $($r.Err.Trim())" }
    # envo lsp: tests\lsp\session.jsonl, framed, piped in; the bodies it writes back must
    # be tests\lsp\expected.jsonl (tests/lsp/README.md)
    Say 'envo lsp: tests/lsp/session.jsonl'
    $lspDir = Join-Path $Root 'build\run-lsp'
    New-Item -ItemType Directory -Force $lspDir | Out-Null
    $uri = 'file:///' + ((Join-Path $lspDir 'doc.envo') -replace '\\', '/')
    $framed = New-Object System.Text.StringBuilder
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $Root 'tests\lsp\session.jsonl'), $Utf8)) {
        if ($line.Trim() -eq '') { continue }
        $body = $line.Replace('${URI}', $uri)
        [void]$framed.Append("Content-Length: $($Utf8.GetByteCount($body))`r`n`r`n$body")
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $envo
    $psi.Arguments = 'lsp'
    $psi.WorkingDirectory = $lspDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $Utf8
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    $bytes = $Utf8.GetBytes($framed.ToString())
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    # the raw stream: closing the StreamWriter would add a byte order mark
    $p.StandardInput.BaseStream.Close()
    $p.WaitForExit()
    $got = (($outTask.Result -replace "Content-Length: \d+\r\n\r\n", "`n").Trim()).Replace($uri, '${URI}')
    $want = (Normalize ([IO.File]::ReadAllText((Join-Path $Root 'tests\lsp\expected.jsonl'), $Utf8))).Trim()
    if ($p.ExitCode -eq 0 -and $got -eq $want) { Pass 'envo lsp' } else { Bad 'envo lsp' "exit $($p.ExitCode): $($errTask.Result.Trim())"; Show-Diff "$want`n" "$got`n" }
    # Library resolution errors (M4.1): `// lib: root` checks against tests\spec\lib\root
    # instead of the repository
    Say 'stage 2 spec tests: tests/spec/lib'
    $dir = Join-Path $Root 'tests\spec\lib'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envo' | Sort-Object Name) {
        $text = [IO.File]::ReadAllText($f.FullName, $Utf8)
        $m = [regex]::Match($text, '(?m)^// expect-error: (E\d{4}) @ (\S+)')
        if (-not $m.Success) { Bad "stage2 spec/lib/$($f.Name)" 'no // expect-error: annotation'; continue }
        $where = $m.Groups[2].Value
        if ($where -match '\.envo:') { $want = "$($where): error[$($m.Groups[1].Value)]" }
        else { $want = "$($f.Name):$($where): error[$($m.Groups[1].Value)]" }
        $libRoot = $Root
        if ($text -match '(?m)^// lib: root') { $libRoot = 'root' }
        $r = Invoke-Tool $envoc @('check', '--lib', $libRoot, $f.Name) $dir
        if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $f.Name }
        else { Bad "stage2 spec/lib/$($f.Name)" "expected exit 1 with '$want'; got exit $($r.Code): $($r.Err.Trim())" }
    }
    Say 'stage 2 against envoc1: lex and parse on every .envo file in compiler/, bootstrap/stage1/, tests/; check on the run programs and goldens; eir on the run programs'
    $sources = @('compiler', 'bootstrap\stage1', 'tests') | ForEach-Object {
        Get-ChildItem -LiteralPath (Join-Path $Root $_) -Filter '*.envo' -Recurse -File
    } | Sort-Object FullName
    foreach ($f in $sources) {
        $cmds = @('lex', 'parse')
        $rel = $f.FullName.Substring($Root.Length + 1)
        if ($rel -match '^tests\\golden\\') { $cmds = @('lex', 'parse', 'check') }
        if ($rel -match '^tests\\spec\\(core|s1)-run\\') { $cmds = @('lex', 'parse', 'check', 'eir') }
        foreach ($cmd in $cmds) {
            $r1 = Invoke-Tool $envoc1 @($cmd, $f.Name) $f.DirectoryName
            $r2 = Invoke-Tool $envoc @($cmd, $f.Name) $f.DirectoryName
            if ($r1.Code -eq $r2.Code -and [string]::Equals($r1.Out, $r2.Out) -and [string]::Equals($r1.Err, $r2.Err)) { Pass $f.Name }
            else { Bad "stage2 $cmd $($f.FullName.Substring($Root.Length + 1))" "differs from envoc1 (exit $($r1.Code) vs $($r2.Code))" }
        }
    }
    foreach ($unit in @(@{ Dir = 'bootstrap\stage1'; Pre = @('--core', 'check') }, @{ Dir = 'compiler'; Pre = @('check') },
                        @{ Dir = 'bootstrap\stage1'; Pre = @('--core', 'eir') }, @{ Dir = 'compiler'; Pre = @('eir') })) {
        $dir = Join-Path $Root $unit.Dir
        $files = @(Get-Content -LiteralPath (Join-Path $dir 'files.txt') | Where-Object { $_.Trim() -ne '' })
        $r1 = Invoke-Tool $envoc1 ($unit.Pre + $files) $dir
        $r2 = Invoke-Tool $envoc ($unit.Pre + $files) $dir
        $what = "stage2 $($unit.Pre[-1]) $($unit.Dir)"
        if ($r1.Code -eq $r2.Code -and [string]::Equals($r1.Out, $r2.Out) -and [string]::Equals($r1.Err, $r2.Err)) { Pass $what }
        else { Bad $what "differs from envoc1 (exit $($r1.Code) vs $($r2.Code))" }
    }
    # Stage 2 builds Stage 1 as envoc1 does, and builds itself into the envoc that envoc1
    # built, for both targets (M3.6).
    $selfDir = Join-Path $Root 'build\run-envoc'
    foreach ($unit in @(@{ Dir = 'bootstrap\stage1'; Pre = @('--core', 'build'); Target = 'x86_64-windows' },
                        @{ Dir = 'compiler'; Pre = @('build'); Target = 'x86_64-windows' },
                        @{ Dir = 'compiler'; Pre = @('build'); Target = 'x86_64-linux' })) {
        $dir = Join-Path $Root $unit.Dir
        $files = @(Get-Content -LiteralPath (Join-Path $dir 'files.txt') | Where-Object { $_.Trim() -ne '' })
        $what = "stage2 build $($unit.Dir) ($($unit.Target))"
        if ($unit.Dir -eq 'compiler') {
            $want = Join-Path $Build2 'envoc'
            if ($unit.Target -eq 'x86_64-windows') { $want = Join-Path $Build2 'envoc.exe' }
        } else {
            $want = Join-Path $selfDir 'self-stage1-envoc1'
            $r = Invoke-Tool $envoc1 ($unit.Pre + $files + @('-o', $want, '--target', $unit.Target)) $dir
            if ($r.Code -ne 0) { Bad $what "envoc1 failed: exit $($r.Code)"; continue }
        }
        $self = Join-Path $selfDir "self-$($unit.Target)"
        $r = Invoke-Tool $envoc ($unit.Pre + $files + @('-o', $self, '--target', $unit.Target)) $dir
        if ($r.Code -eq 0 -and (Test-SameBytes $want $self)) { Pass $what }
        else { Bad $what "exit $($r.Code), or the executable differs from envoc1's" }
    }
    # Stage 2 at -O2 (M3.8): it builds Stage 2 into the same bytes as envoc1's build at
    # -O0, and into itself at -O2
    $dir = Join-Path $Root 'compiler'
    $files = @(Get-Content -LiteralPath (Join-Path $dir 'files.txt') | Where-Object { $_.Trim() -ne '' })
    $fast = Join-Path $selfDir 'envoc-O2.exe'
    $byFast = Join-Path $selfDir 'by-O2.exe'
    $byFast2 = Join-Path $selfDir 'by-O2-O2.exe'
    $r = Invoke-Tool $envoc (@('build', '-O2') + $files + @('-o', $fast)) $dir
    if ($r.Code -eq 0) { $r = Invoke-Tool $fast (@('build') + $files + @('-o', $byFast)) $dir }
    if ($r.Code -eq 0) { $r = Invoke-Tool $fast (@('build', '-O2') + $files + @('-o', $byFast2)) $dir }
    if ($r.Code -eq 0 -and (Test-SameBytes $byFast (Join-Path $Build2 'envoc.exe')) -and (Test-SameBytes $fast $byFast2)) { Pass 'stage2 -O2 self-build' }
    else { Bad 'stage2 -O2 self-build' "exit $($r.Code), or the -O2 compiler's output differs" }
    # Stage 2 through an object of itself (M3.7), and link errors
    $dir = Join-Path $Root 'compiler'
    $files = @(Get-Content -LiteralPath (Join-Path $dir 'files.txt') | Where-Object { $_.Trim() -ne '' })
    $obj = Join-Path $selfDir 'self.eo'
    $linked = Join-Path $selfDir 'self-linked.exe'
    $r = Invoke-Tool $envoc (@('compile') + $files + @('-o', $obj)) $dir
    if ($r.Code -eq 0) { $r = Invoke-Tool $envoc @('link', $obj, '-o', $linked) $dir }
    if ($r.Code -eq 0 -and (Test-SameBytes $linked (Join-Path $Build2 'envoc.exe'))) { Pass 'stage2 compile and link compiler' }
    else { Bad 'stage2 compile and link compiler' "exit $($r.Code), or the executable differs from build\stage2" }
    $none = Join-Path $selfDir 'none.exe'
    $r = Invoke-Tool $envoc @('link', (Join-Path $selfDir 'core-multi-program.exe.0.eo'), '-o', $none) $Root
    if ($r.Code -eq 1 -and $r.Err.Contains('no object defines @')) { Pass 'stage2 link with a unit missing' } else { Bad 'stage2 link with a unit missing' "exit $($r.Code): $($r.Err)" }
    $r = Invoke-Tool $envoc @('link', (Join-Path $selfDir 'core-multi-program.exe.0.eo'), (Join-Path $selfDir 's1-multi-namespaces.exe.0.eo'), '-o', $none) $Root
    if ($r.Code -eq 1 -and $r.Err.Contains('compiled from different programs')) { Pass 'stage2 link of two programs' } else { Bad 'stage2 link of two programs' "exit $($r.Code): $($r.Err)" }
    $v2 = Join-Path $selfDir 'v2.eo'
    [IO.File]::WriteAllBytes($v2, [byte[]](0x45, 0x49, 0x52, 0, 2, 0))
    $r = Invoke-Tool $envoc @('link', $v2, '-o', $none) $Root
    if ($r.Code -eq 1 -and $r.Err.Contains('binary EIR version 2; this envoc reads version 1')) { Pass 'stage2 link of an unknown version' } else { Bad 'stage2 link of an unknown version' "exit $($r.Code): $($r.Err)" }

    Say ''
    Say "$($script:passed) passed, $($script:failed) failed"
    if ($script:failed -gt 0) { exit 1 }
}

# ------------------------------------------------------------------- check
function Invoke-Check {
    $problems = New-Object System.Collections.Generic.List[string]

    foreach ($f in @('README.md', 'CHARTER.md', 'STATUS.md', 'CONTRIBUTING.md', 'SECURITY.md',
                     'CODE_OF_CONDUCT.md', 'LICENSE', 'LICENSING.md', 'CLA.md', 'TRADEMARKS.md',
                     'LICENSES/PolyForm-Noncommercial-1.0.0.md', 'LICENSES/LicenseRef-EnvoScale-Commercial.md', 'envo.envon', 'bootstrap.sh', 'bootstrap.ps1',
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
    'fixedpoint' { Invoke-FixedPoint }
    'check' { Invoke-Check }
    'clean' { if (Test-Path -LiteralPath (Join-Path $Root 'build')) { Remove-Item -Recurse -Force (Join-Path $Root 'build') }; Say 'removed build/' }
    default {
        Say 'usage: .\bootstrap.ps1 <build|test|fixedpoint|check|clean|help>'
        Say '  build   assemble Stage 0 (needs NASM; see adapters/bootstrap/nasm/README.md), then build Stage 1'
        Say '  test    build, then run the Stage 0 and Stage 1 tests'
        Say '  fixedpoint  build, then Stage 2 by itself twice at -O2 (build\stage2b, build\stage2c); they must match'
        Say '  check   repository layout, lib->adapters imports, Hello World Gallery limits'
        Say '  clean   delete build/'
        if ($Command -ne 'help') { exit 2 }
    }
}
