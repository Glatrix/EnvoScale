<#
Builds and tests EnvoScale on Windows, with only what Windows ships (PowerShell 5.1 or 7).
build.sh is the POSIX twin; keep the two in step.

  .\build.ps1 build   download the seed compiler, build the compiler with it, then with
                      itself, then the envo tool: build\envoc\ and build\envo\
  .\build.ps1 test    build, then every test
  .\build.ps1 check   quick repository checks
  .\build.ps1 dist    build, then the release archive in build\dist\
  .\build.ps1 clean

The seed is the compiler EnvoScaleAsm builds from assembly
(https://github.com/envoscale/EnvoScaleAsm), downloaded from its releases, or built from
its assembly when that download is not available. Set $env:ENVO_SEED to use an envoc
you already have instead.
#>
param([string]$Command = 'help')

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Stage2 = Join-Path $Root 'compiler'
$BuildA = Join-Path $Root 'build\envoc-seeded'
$Build2 = Join-Path $Root 'build\envoc'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

$SeedTag = 'seed-1'
$SeedSha = '46eaa09c84230fa654ba5e6b7534e57b745931d49686ad7fdde65f836a2f3290'
$SeedUrl = "https://github.com/envoscale/EnvoScaleAsm/releases/download/$SeedTag/envoc-x86_64-windows.exe"
$SeedAsmRepo = 'https://github.com/envoscale/EnvoScaleAsm'
$SeedAsmRef = '9222580cac7a83fc6ec168e973823cabe82f941f'

function Say([string]$msg) { Write-Host $msg }
function Fail([string]$msg) { [Console]::Error.WriteLine("error: $msg"); exit 1 }

# ------------------------------------------------------------------- build
# The seed compiler's path, downloading and checking it the first time.
function Get-Seed {
    if ($env:ENVO_SEED) { return $env:ENVO_SEED }
    $dir = Join-Path $Root "build\seed\$SeedTag"
    $file = Join-Path $dir 'envoc-x86_64-windows.exe'
    if (-not (Test-Path -LiteralPath $file)) {
        New-Item -ItemType Directory -Force $dir | Out-Null
        Say "download  $SeedUrl"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $part = "$file.part"
        $ProgressPreference = 'SilentlyContinue'
        $got = $true
        try { Invoke-WebRequest -UseBasicParsing -Uri $SeedUrl -OutFile $part } catch { $got = $false }
        if (-not $got) {
            # No download: build the seed from assembly, with EnvoScaleAsm at the commit
            # that made this release. The bytes must be the same either way.
            Say '          not available: building the seed from assembly (EnvoScaleAsm)'
            $asm = Join-Path $Root 'build\seed\EnvoScaleAsm'
            if (-not (Test-Path -LiteralPath (Join-Path $asm '.git'))) {
                & git clone -q $SeedAsmRepo $asm | Out-Host
                if ($LASTEXITCODE -ne 0) { Fail "cloning $SeedAsmRepo failed; set `$env:ENVO_SEED to an envoc" }
            }
            & git -C $asm fetch -q origin | Out-Host
            & git -C $asm -c advice.detachedHead=false checkout -q $SeedAsmRef | Out-Host
            if ($LASTEXITCODE -ne 0) { Fail "EnvoScaleAsm: cannot check out $SeedAsmRef" }
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $asm 'bootstrap.ps1') seed | Out-Host
            if ($LASTEXITCODE -ne 0) { Fail 'building the seed from assembly failed' }
            Copy-Item (Join-Path $asm 'build\seed-release\envoc-x86_64-windows.exe') $part
        }
        $got = (Get-FileHash -Algorithm SHA256 -LiteralPath $part).Hash.ToLowerInvariant()
        if ($got -ne $SeedSha) { Remove-Item -Force $part; Fail "the seed's sha256 is $got, expected $SeedSha" }
        Move-Item $part $file
    }
    return $file
}

function Get-CompilerFiles { return @(Get-Content -LiteralPath (Join-Path $Stage2 'files.txt') | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }) }

function Invoke-Build {
    $seed = Get-Seed
    # The seed builds the compiler for this host; that compiler builds it again for both
    # OSes, so build\envoc is the compiler as its own sources say, whatever the seed was.
    New-Item -ItemType Directory -Force $BuildA | Out-Null
    New-Item -ItemType Directory -Force $Build2 | Out-Null
    $files = Get-CompilerFiles
    Say 'build     compiler -> build/envoc-seeded (by the seed)'
    $r = Invoke-Tool $seed (@('build', '-O2') + $files + @('-o', (Join-Path $BuildA 'envoc.exe'))) $Stage2
    if ($r.Code -ne 0) { Fail "building the compiler with the seed failed: $($r.Err.Trim())" }
    foreach ($u in @(@{ Target = 'x86_64-windows'; Out = 'envoc.exe' }, @{ Target = 'x86_64-linux'; Out = 'envoc' })) {
        $out = Join-Path $Build2 $u.Out
        Say "build     compiler -> build/envoc/$($u.Out)"
        $r = Invoke-Tool (Join-Path $BuildA 'envoc.exe') (@('build', '-O2') + $files + @('-o', $out, '--target', $u.Target)) $Stage2
        if ($r.Code -ne 0) { Fail "building the compiler ($($u.Target)) failed: $($r.Err.Trim())" }
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
    $files += @(Get-Content -LiteralPath (Join-Path $Stage2 'files.txt') | Where-Object { $_.Trim() -ne '' -and $_.Trim() -ne 'driver/main.envol' } | ForEach-Object { "compiler/$($_.Trim())" })
    foreach ($u in @(@{ Target = 'x86_64-windows'; Out = 'envo.exe' }, @{ Target = 'x86_64-linux'; Out = 'envo' })) {
        $out = Join-Path $envoDir $u.Out
        Say "build     tools/envo -> build/envo/$($u.Out)"
        $r = Invoke-Tool $envoc (@('build', '-O2', '--lib', $Root) + $files + @('-o', $out, '--target', $u.Target)) $Root
        if ($r.Code -ne 0) { Fail "building envo ($($u.Target)) failed: $($r.Err.Trim())" }
        $size = (Get-Item -LiteralPath $out).Length
        Say ("          {0,8} bytes" -f $size)
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
    $exe = Join-Path $Build2 'envoc.exe'
    $envoc = $exe
    $script:passed = 0
    $script:failed = 0
    function Pass([string]$name) { $script:passed++ }
    function Bad([string]$name, [string]$why) { $script:failed++; Say "FAIL  $name"; if ($why) { Say "      $why" } }

    # Hardening (PLAN D68): executables keep code and data apart (W^X)
    # and can be loaded anywhere (ASLR): Linux ET_DYN with an R+X and an R+W segment;
    # Windows with DYNAMIC_BASE and HIGH_ENTROPY_VA and no section both writable and executable
    Say ''
    Say 'hardening: W^X and ASLR in the executables envoc builds'
    $hsrc = (Get-ChildItem -LiteralPath (Join-Path $Root 'tests\spec\core-run') -Filter '*.envol' | Sort-Object Name | Select-Object -First 1).FullName
    $hdir = Join-Path $Root 'build\hardening'
    New-Item -ItemType Directory -Force $hdir | Out-Null
    foreach ($hComp in @((Join-Path $Build2 'envoc.exe'))) {
        $hElf = Join-Path $hdir 'h-linux'
        $hExe = Join-Path $hdir 'h-win.exe'
        Invoke-Tool $hComp @('build', $hsrc, '-o', $hElf, '--target', 'x86_64-linux') $Root | Out-Null
        Invoke-Tool $hComp @('build', $hsrc, '-o', $hExe, '--target', 'x86_64-windows') $Root | Out-Null
        $hb = [IO.File]::ReadAllBytes($hElf)
        $hEt = [BitConverter]::ToUInt16($hb, 16)
        $hF0 = [BitConverter]::ToUInt32($hb, 68)
        $hF1 = [BitConverter]::ToUInt32($hb, 124)
        $hName = Split-Path $hComp -Leaf
        if ($hEt -eq 3 -and $hF0 -eq 5 -and $hF1 -eq 6) { Pass "hardening: ELF from $hName" } else { Bad "hardening: ELF from $hName" "e_type $hEt, segment flags $hF0 and $hF1" }
        $hb = [IO.File]::ReadAllBytes($hExe)
        $hPe = [BitConverter]::ToUInt32($hb, 60)
        $hDll = [BitConverter]::ToUInt16($hb, $hPe + 94)
        $hNs = [BitConverter]::ToUInt16($hb, $hPe + 6)
        $hWx = $false
        for ($hi = 0; $hi -lt $hNs; $hi++) {
            $hc = [BitConverter]::ToUInt32($hb, 0x16C + 40 * $hi)
            if (($hc -band 0x20000000) -ne 0 -and ($hc -band 0x80000000) -ne 0) { $hWx = $true }
        }
        if (($hDll -band 0x60) -eq 0x60 -and $hNs -ge 2 -and -not $hWx) { Pass "hardening: PE from $hName" } else { Bad "hardening: PE from $hName" "DllCharacteristics $hDll, $hNs sections, writable code: $hWx" }
    }

    Say ''
    Say 'smoke tests'
    $r = Invoke-Tool $exe @('lex', 'no such file.envol') $Root
    if ($r.Code -eq 1 -and $r.Err.StartsWith("envoc: error: cannot open 'no such file.envol'")) { Pass 'missing file' } else { Bad 'missing file' "exit $($r.Code), stderr: $($r.Err)" }
    # Paths are UTF-8 on every OS: a name with a space, a Latin, a CJK and a non-BMP character.
    $tmp = Join-Path $Root 'build\tmp'
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $uname = "u$([char]0x00FC)nicode $([char]0x65E5)$([char]::ConvertFromUtf32(0x1F600)).envol"
    [IO.File]::WriteAllText((Join-Path $tmp $uname), "print(`"hi`")`n", $Utf8)
    $r = Invoke-Tool $exe @('lex', $uname) $tmp
    if ($r.Code -eq 0 -and $r.Out.StartsWith('1:1 n ident print')) { Pass 'unicode path' } else { Bad 'unicode path' "exit $($r.Code), stderr: $($r.Err)" }
    # Cross-compilation: this host builds the other OS's executable (it can only check the header).
    [IO.File]::WriteAllText((Join-Path $tmp 'cross.envol'), "print(`"hi`")`n", $Utf8)
    $r = Invoke-Tool $exe @('build', 'cross.envol', '-o', 'cross-linux', '--target', 'x86_64-linux') $tmp
    $ok = $false
    if ($r.Code -eq 0) { $head = [IO.File]::ReadAllBytes((Join-Path $tmp 'cross-linux')); $ok = ($head[0] -eq 0x7F -and $head[1] -eq 0x45 -and $head[2] -eq 0x4C -and $head[3] -eq 0x46) }
    if ($ok) { Pass 'cross build (linux)' } else { Bad 'cross build (linux)' "exit $($r.Code), stderr: $($r.Err)" }

    # Programs compiled and run: `// expect:` stdout lines, `// expect-exit: N`,
    # `// expect-panic: <reason>` (exit 101 and "panic: <reason>" on stderr).
    foreach ($compiler in @('envoc')) {
        $runDir = Join-Path $Root "build\run-$compiler"
        New-Item -ItemType Directory -Force $runDir | Out-Null
        $runSuites = @('core-run', 's1-run', 's2-run')
        foreach ($suite in $runSuites) {
        Say "run tests ($compiler): tests/spec/$suite"
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root "tests\spec\$suite") -Filter '*.envol' | Sort-Object Name) {
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

        # Multi-file programs: one folder per test. main.envol is the entry file and holds
        # the annotations; the other .envol files follow in name order. Either
        # `// expect-error: E#### @ <file>:L:C` (envoc check) or `// expect:` lines (build, run).
        $multiSuites = @('core-multi', 's1-multi')
        foreach ($msuite in $multiSuites) {
        Say "multi-file tests ($compiler): tests/spec/$msuite"
        foreach ($d in Get-ChildItem -LiteralPath (Join-Path $Root "tests\spec\$msuite") -Directory | Sort-Object Name) {
            $name = "$compiler spec/$msuite/$($d.Name)"
            $files = @('main.envol') + @(Get-ChildItem -LiteralPath $d.FullName -Filter '*.envol' | Where-Object { $_.Name -ne 'main.envol' } | Sort-Object Name | ForEach-Object { $_.Name })
            $text = Normalize ([IO.File]::ReadAllText((Join-Path $d.FullName 'main.envol'), $Utf8))
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


    # The runtime and prelude compiled into every program (compiler/driver/runtime*.envol)
    # must be generated from the current sources in compiler/runtime.
    Say 'embedded runtime: compiler/driver/runtime*.envol'
    $r = Invoke-Tool $envoc @('embed', 'compiler/runtime/common.envol', 'compiler/runtime/linux.envol', 'compiler/runtime/windows.envol', 'compiler/runtime/prelude.envol') $Root
    $expected = Normalize ([IO.File]::ReadAllText((Join-Path $Root 'compiler\driver\runtime.envol'), $Utf8))
    if ($r.Code -eq 0 -and [string]::Equals($expected, (Normalize $r.Out))) { Pass 'embedded runtime' }
    else { Bad 'embedded runtime' 'compiler/driver/runtime.envol is stale: regenerate it with envoc embed compiler/runtime/common.envol compiler/runtime/linux.envol compiler/runtime/windows.envol compiler/runtime/prelude.envol' }
    foreach ($u in @(@('wasm', 'WASM', 'wasm'), @('linux_aarch64', 'A64', 'a64'), @('macos_aarch64', 'MACOS', 'macos'))) {
        $r = Invoke-Tool $envoc @('embed', "compiler/runtime/$($u[0]).envol") $Root
        $expected = Normalize ([IO.File]::ReadAllText((Join-Path $Root "compiler\driver\runtime_$($u[2]).envol"), $Utf8))
        $actual = (Normalize $r.Out) -replace '(?m)^const str RUNTIME_0 = ', "const str RUNTIME_$($u[1]) = "
        if ($r.Code -eq 0 -and [string]::Equals($expected, $actual)) { Pass "embedded runtime ($($u[0]))" }
        else { Bad "embedded runtime ($($u[0]))" "compiler/driver/runtime_$($u[2]).envol is stale: regenerate it with envoc embed compiler/runtime/$($u[0]).envol, renaming RUNTIME_0 to RUNTIME_$($u[1])" }
    }

    Say ''
    Say 'compiler smoke tests'
    $r = Invoke-Tool $envoc @('version') $Root
    if ($r.Code -eq 0 -and $r.Out.StartsWith('envoc ')) { Pass 'envoc version' } else { Bad 'envoc version' "exit $($r.Code)" }
    $r = Invoke-Tool $envoc @('selftest') $Root
    if ($r.Code -eq 0 -and $r.Out.StartsWith('selftest: ok')) { Pass 'envoc selftest' } else { Bad 'envoc selftest' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    $r = Invoke-Tool $envoc @() $Root
    if ($r.Code -eq 2 -and $r.Err.StartsWith('usage: envoc')) { Pass 'envoc no arguments' } else { Bad 'envoc no arguments' "exit $($r.Code)" }
    $r = Invoke-Tool $envoc @('frobnicate') $Root
    if ($r.Code -eq 2 -and $r.Err.StartsWith("envoc: error: unknown command 'frobnicate'")) { Pass 'envoc unknown command' } else { Bad 'envoc unknown command' "exit $($r.Code)" }

    # The front end and checker: the lexer, parser and checker goldens and the lexical,
    # syntax, type and ownership spec tests, in --core (Envo-Core) and in full mode.
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
        Say "golden tests ($mode): tests/golden/$($suite.Dir)"
        $dir = Join-Path $Root "tests\golden\$($suite.Dir)"
        foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envol' | Sort-Object Name) {
            $name = "$mode golden/$($suite.Dir)/$($f.Name)"
            $r = Invoke-Tool $envoc ($pre + @($suite.Command, $f.Name)) $dir
            if ($r.Code -ne 0) { Bad $name "exit $($r.Code), stderr: $($r.Err.Trim())"; continue }
            $expected = Normalize ([IO.File]::ReadAllText(($f.FullName -replace '\.envol$', $suite.Ext), $Utf8))
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
        Say "spec tests ($mode): tests/spec/$($suite.Dir)"
        $dir = Join-Path $Root "tests\spec\$($suite.Dir)"
        foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envol' | Sort-Object Name) {
            $name = "$mode spec/$($suite.Dir)/$($f.Name)"
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
    Say 'golden tests: tests/golden/eir'
    $dir = Join-Path $Root 'tests\golden\eir'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.eir' | Sort-Object Name) {
        $expected = Normalize ([IO.File]::ReadAllText(($f.FullName -replace '\.eir$', '.out'), $Utf8))
        foreach ($input in @($f.Name, ($f.Name -replace '\.eir$', '.out'))) {
            $r = Invoke-Tool $envoc @('eir-check', $input) $dir
            $actual = Normalize $r.Out
            if ($r.Code -eq 0 -and [string]::Equals($expected, $actual)) { Pass $input }
            else { Bad "golden/eir/$input" "exit $($r.Code), stderr: $($r.Err.Trim())"; Show-Diff $expected $actual }
        }
        # the binary form (M3.7): text -> binary -> text, and binary -> binary
        $b1 = Join-Path $Build2 'golden-1.eirb'
        $b2 = Join-Path $Build2 'golden-2.eirb'
        $r = Invoke-Tool $envoc @('eir-check', $f.Name, '-o', $b1) $dir
        if ($r.Code -eq 0) { $r = Invoke-Tool $envoc @('eir-check', $b1) $dir }
        $actual = Normalize $r.Out
        if ($r.Code -eq 0) { $r = Invoke-Tool $envoc @('eir-check', $b1, '-o', $b2) $dir }
        if ($r.Code -eq 0 -and [string]::Equals($expected, $actual) -and (Test-SameBytes $b1 $b2)) { Pass "$($f.Name) (binary)" }
        else { Bad "golden/eir/$($f.Name) (binary)" "exit $($r.Code), stderr: $($r.Err.Trim())" }
    }
    # -O2's EIR passes (M3.8)
    Say 'golden tests: tests/golden/opt'
    $dir = Join-Path $Root 'tests\golden\opt'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.eir' | Sort-Object Name) {
        $expected = Normalize ([IO.File]::ReadAllText(($f.FullName -replace '\.eir$', '.out'), $Utf8))
        $r = Invoke-Tool $envoc @('eir-check', $f.Name, '-O2') $dir
        $actual = Normalize $r.Out
        if ($r.Code -eq 0 -and [string]::Equals($expected, $actual)) { Pass $f.Name }
        else { Bad "golden/opt/$($f.Name)" "exit $($r.Code), stderr: $($r.Err.Trim())"; Show-Diff $expected $actual }
    }
    Say 'spec tests: tests/spec/eir'
    $dir = Join-Path $Root 'tests\spec\eir'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.eir' | Sort-Object Name) {
        $m = [regex]::Match([IO.File]::ReadAllText($f.FullName, $Utf8), '(?m)^; expect-error: (E\d{4}) @ (\d+:\d+)')
        if (-not $m.Success) { Bad "spec/eir/$($f.Name)" 'no ; expect-error: annotation'; continue }
        $want = "$($f.Name):$($m.Groups[2].Value): error[$($m.Groups[1].Value)]"
        $r = Invoke-Tool $envoc @('eir-check', $f.Name) $dir
        if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $f.Name }
        else { Bad "spec/eir/$($f.Name)" "expected exit 1 with '$want'; got exit $($r.Code), stderr: $($r.Err.Trim())" }
    }
    # The standard platform and the examples (PLAN D29): `envo test` builds and runs each
    # library test, adapter test and conformance suite (the suites against the reference
    # and the native adapters) at -O0 and -O2, and builds each example package. Keep in
    # step with build.sh.
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
    # The examples: each runs, as a script and natively, and prints its output.txt
    Say 'examples: each one, as a script and natively, against its output.txt'
    $envoExe = Join-Path $Root 'build\envo\envo.exe'
    foreach ($d in Get-ChildItem -LiteralPath (Join-Path $Root 'examples') -Directory | Sort-Object Name) {
        $want = Join-Path $d.FullName 'output.txt'
        if (-not (Test-Path -LiteralPath $want)) { continue }
        $expected = Normalize ([IO.File]::ReadAllText($want, $Utf8))
        $extra = @()
        $argsFile = Join-Path $d.FullName 'run.args'
        if (Test-Path -LiteralPath $argsFile) { $extra = @(([IO.File]::ReadAllText($argsFile)).Trim() -split '\s+') }
        foreach ($mode in @('script', 'native')) {
            if ($mode -eq 'script') { $r = Invoke-Tool $envoExe (@('run') + $extra + @('.')) $d.FullName }
            else { $r = Invoke-Tool $envoExe @('run', '--native', '.') $d.FullName }
            if ($r.Code -eq 0 -and [string]::Equals($expected, (Normalize $r.Out))) { Pass "example $($d.Name) ($mode)" }
            else { Bad "example $($d.Name) ($mode)" "exit $($r.Code): $($r.Err.Trim())" }
        }
    }
    # The script runtime (PLAN D35): every spec run program, and every multi-file one, runs
    # in the VM (`envo run -A`) with the output, exit code and panic it has natively.
    Say 'script runtime: tests/spec/core-run, s1-run, s2-run and the multi-file programs in the VM'
    $vmDir = Join-Path $Root 'build\run-vm'
    New-Item -ItemType Directory -Force $vmDir | Out-Null
    foreach ($suite in @('core-run', 's1-run', 's2-run')) {
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root "tests\spec\$suite") -Filter '*.envol' | Sort-Object Name) {
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
            $main = Join-Path $d.FullName 'main.envol'
            $text = Normalize ([IO.File]::ReadAllText($main, $Utf8))
            if ($text -match '(?m)^// expect-error: ') { continue }
            $files = @('main.envol') + @(Get-ChildItem -LiteralPath $d.FullName -Filter '*.envol' | Where-Object { $_.Name -ne 'main.envol' } | Sort-Object Name | ForEach-Object { $_.Name })
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
    Copy-Item -Path (Join-Path $Root 'tests\sandbox\*.envol') -Destination $boxDir
    foreach ($f in Get-ChildItem -LiteralPath $boxDir -Filter '*.envol' | Sort-Object Name) {
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
    # installed. Keep in step with build.sh.
    $openssl = Get-Command openssl -ErrorAction SilentlyContinue
    if (-not $openssl -and (Test-Path -LiteralPath 'C:\Program Files\Git\usr\bin\openssl.exe')) { $openssl = Get-Command 'C:\Program Files\Git\usr\bin\openssl.exe' }
    if ($openssl) {
        Say 'tls: tests/tls/client.envol against openssl s_server'
        $tdir = Join-Path $Root 'build\run-tls'
        if (Test-Path -LiteralPath $tdir) { Remove-Item -Recurse -Force $tdir }
        New-Item -ItemType Directory -Force $tdir | Out-Null
        $os = $openssl.Source
        [IO.File]::WriteAllText((Join-Path $tdir 'leaf.ext'), "subjectAltName=DNS:localhost,IP:127.0.0.1`nbasicConstraints=CA:FALSE`n", $Utf8)
        $steps = @(
            @('req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:prime256v1', '-nodes', '-keyout', 'ca.key', '-out', 'ca.pem', '-days', '30', '-subj', '/CN=EnvoL Test CA', '-addext', 'basicConstraints=critical,CA:TRUE', '-addext', 'keyUsage=critical,keyCertSign'),
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
            $r = Invoke-Tool $envoc @('build', '--lib', $Root, (Join-Path $Root 'tests\tls\client.envol'), '-o', $client) $tdir
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
    # Keep in step with build.sh.
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        Say 'wasm: tests/spec run programs and lib tests as WebAssembly under Node.js'
        $r = Invoke-Tool $node.Source @((Join-Path $Root 'adapters\interop\js\test-wasm.js'), $envoc) $Root
        if ($r.Code -eq 0) { Pass 'wasm spec run programs' } else { Bad 'wasm spec run programs' ($r.Out.Trim() + ' ' + $r.Err.Trim()) }
    } else {
        Say 'wasm: skipped (no Node.js on this machine)'
    }
    # AArch64 Linux (M10, PLAN D69): programs build as AArch64 ELF executables, with and
    # without the library; CI runs the run and library tests on an arm64 machine
    # (build.sh cross, cross-run)
    $a64Out = Join-Path $Root 'build\hello-a64'
    $r = Invoke-Tool $envoc @('build', (Join-Path $Root 'examples\00-hello\main.envol'), '--lib', $Root, '-o', $a64Out, '--target', 'aarch64-linux') $Root
    $a64Head = ''
    if (Test-Path -LiteralPath $a64Out) { $a64Bytes = [IO.File]::ReadAllBytes($a64Out); $a64Head = '{0:x2}{1:x2}{2:x2}{3:x2}' -f $a64Bytes[16], $a64Bytes[17], $a64Bytes[18], $a64Bytes[19] }
    if ($r.Code -eq 0 -and $a64Head -eq '0300b700') { Pass 'aarch64-linux build' } else { Bad 'aarch64-linux build' "exit $($r.Code): $($r.Err.Trim())" }
    # envo's own commands: new, run, test, check, explain, version (tests/envo/README.md)
    Say 'envo commands: new, run, test, check, explain, version, prof, fuzz, dbg, packages'
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
    [IO.File]::WriteAllText((Join-Path $envoRun 'bad.envol'), "i32 x = ;`n", $Utf8)
    $r = Invoke-Tool $envo @('check', 'bad.envol') $envoRun
    if ($r.Code -eq 1 -and $r.Err.Contains('bad.envol:1:9: error[E0101]') -and $r.Err.Contains('1 | i32 x = ;') -and $r.Err.Contains('envo explain E0101')) { Pass 'envo check' } else { Bad 'envo check' "exit $($r.Code): $($r.Err.Trim())" }
    $r = Invoke-Tool $envo @('explain', 'E0004') $envoRun
    if ($r.Code -eq 0 -and $r.Out.Contains('E0004: unterminated string literal') -and $r.Out.Contains('[lex.str.1]')) { Pass 'envo explain' } else { Bad 'envo explain' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    $r = Invoke-Tool $envo @('explain', 'E9999') $envoRun
    if ($r.Code -eq 1) { Pass 'envo explain (unknown)' } else { Bad 'envo explain (unknown)' "exit $($r.Code)" }
    $r = Invoke-Tool $envo @('version') $envoRun
    if ($r.Code -eq 0 -and $r.Out.StartsWith('envo ')) { Pass 'envo version' } else { Bad 'envo version' "exit $($r.Code)" }
    # envo prof: exact counts (tests/envo/prof); envo fuzz: finds a 4-byte magic input
    Copy-Item (Join-Path $Root 'tests\envo\prof\hot.envol') $envoRun
    Copy-Item (Join-Path $Root 'tests\envo\fuzz\magic.envol') $envoRun
    $r = Invoke-Tool $envo @('prof', 'hot.envol') $envoRun
    $errN = Normalize $r.Err
    if ($r.Code -eq 0 -and (Normalize $r.Out) -eq "ok`n" -and $errN -match '(?m)^ +177 +\d+ +[\d.]+  Fib$' -and $errN -match '(?m)^ +10 +\d+ +[\d.]+  Square$') { Pass 'envo prof' } else { Bad 'envo prof' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    $r = Invoke-Tool $envo @('fuzz', 'magic.envol', '--runs', '50000', '--seed', '1') $envoRun
    if ($r.Code -eq 1 -and $r.Out.Contains('crash: ') -and $r.Err.Contains('panic: found the magic input') -and (Test-Path -LiteralPath (Join-Path $envoRun 'build\fuzz\magic\crash'))) { Pass 'envo fuzz' } else { Bad 'envo fuzz' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    # envo dbg: a scripted session (tests/envo/dbg) gives the expected transcript
    Copy-Item (Join-Path $Root 'tests\envo\dbg\sum.envol') $envoRun
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $envo
    $psi.Arguments = 'dbg sum.envol'
    $psi.WorkingDirectory = $envoRun
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $Utf8
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    $bytes = [IO.File]::ReadAllBytes((Join-Path $Root 'tests\envo\dbg\session.txt'))
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.BaseStream.Close()
    $p.WaitForExit()
    $want = Normalize ([IO.File]::ReadAllText((Join-Path $Root 'tests\envo\dbg\expected.txt')))
    if ($p.ExitCode -eq 0 -and (Normalize $outTask.Result) -eq $want) { Pass 'envo dbg' } else { Bad 'envo dbg' "exit $($p.ExitCode): $($outTask.Result) $($errTask.Result)" }
    # packages (PLAN D66; tests\envo\pkg): a path dependency; a signed archive in a folder
    # registry, fetched into a lock; a changed archive and an untrusted key refused
    $pk = Join-Path $envoRun 'pk'
    if (Test-Path -LiteralPath $pk) { Remove-Item -Recurse -Force $pk }
    Copy-Item -Recurse (Join-Path $Root 'tests\envo\pkg') $pk
    $r = Invoke-Tool $envo @('run', 'pk/app') $envoRun
    if ($r.Code -eq 0 -and (Normalize $r.Out) -eq "Hello, app!`n") { Pass 'packages: a path dependency' } else { Bad 'packages: a path dependency' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    # a git dependency, by commit: pk\greet as a repository of its own (where git is installed)
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gdir = Join-Path $envoRun 'pk\greet-git'
        $adir = Join-Path $envoRun 'pk\appg'
        foreach ($d in @($gdir, $adir)) { if (Test-Path -LiteralPath $d) { Remove-Item -Recurse -Force $d } }
        Copy-Item -Recurse (Join-Path $envoRun 'pk\greet') $gdir
        & git -C $gdir -c core.autocrlf=false init -q | Out-Null
        & git -C $gdir -c core.autocrlf=false -c core.safecrlf=false add -A | Out-Null
        & git -C $gdir -c core.autocrlf=false -c user.name=t -c user.email=t@t commit -q -m greet | Out-Null
        $grev = (& git -C $gdir rev-parse HEAD).Trim()
        New-Item -ItemType Directory -Force $adir | Out-Null
        $gurl = $gdir.Replace('\', '/')
        [IO.File]::WriteAllText((Join-Path $adir 'envo.envon'), "#eon 1`npackage {`n    name = `"appg`"`n}`ndependencies {`n    greet = { git = `"$gurl`", rev = `"$grev`" }`n}`n", $Utf8)
        [IO.File]::WriteAllText((Join-Path $adir 'main.envol'), "use greet;`nprint(greet.Hello(`"appg`").AsStr());`n", $Utf8)
        $r = Invoke-Tool $envo @('run', 'pk/appg') $envoRun
        $dep = Join-Path $adir "build\deps\greet-$grev\envo.envon"
        if ($r.Code -eq 0 -and (Normalize $r.Out) -eq "Hello, appg!`n" -and (Test-Path -LiteralPath $dep)) { Pass 'packages: a git dependency' } else { Bad 'packages: a git dependency' "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    }
    $r = Invoke-Tool $envo @('key', 'pk/publisher.key') $envoRun
    $pub = ($r.Out.Trim() -replace '^public key ', '')
    $r = Invoke-Tool $envo @('key', 'pk/other.key') $envoRun
    $other = ($r.Out.Trim() -replace '^public key ', '')
    foreach ($pair in @(@('app2', $pub), @('app3', $other))) {
        $m = Join-Path $pk "$($pair[0])\envo.envon"
        [IO.File]::WriteAllText($m, ([IO.File]::ReadAllText($m) -creplace 'KEY', $pair[1]), $Utf8)
    }
    $r1 = Invoke-Tool $envo @('publish', 'pk/greet', '--registry', 'pk/reg', '--key', 'pk/publisher.key') $envoRun
    $r2 = Invoke-Tool $envo @('publish', 'pk/greet', '--registry', 'pk/reg') $envoRun
    if ($r1.Code -eq 0 -and $r2.Code -eq 1 -and (Test-Path -LiteralPath (Join-Path $pk 'reg\greet\1.0.0.envopkg')) -and (Test-Path -LiteralPath (Join-Path $pk 'reg\greet\1.0.0.sig'))) { Pass 'packages: envo publish (once per version)' } else { Bad 'packages: envo publish (once per version)' "exit $($r1.Code), then $($r2.Code): $($r1.Err.Trim()) $($r2.Err.Trim())" }
    $r1 = Invoke-Tool $envo @('run', 'pk/app2') $envoRun
    $r2 = Invoke-Tool $envo @('fetch', 'pk/app2') $envoRun
    $r = Invoke-Tool $envo @('run', 'pk/app2') $envoRun
    if ($r1.Code -eq 1 -and $r2.Code -eq 0 -and (Test-Path -LiteralPath (Join-Path $pk 'app2\envo.lock.envon')) -and $r.Code -eq 0 -and (Normalize $r.Out) -eq "Hello, app2!`n") { Pass 'packages: envo fetch, the lock, a registry dependency' } else { Bad 'packages: envo fetch, the lock, a registry dependency' "exit $($r1.Code), $($r2.Code), $($r.Code): $($r.Out.Trim()) $($r.Err.Trim()) $($r2.Err.Trim())" }
    $r = Invoke-Tool $envo @('fetch', 'pk/app3') $envoRun
    if ($r.Code -eq 1 -and $r.Err.Contains('no signature by a trusted key')) { Pass 'packages: an untrusted signature' } else { Bad 'packages: an untrusted signature' "exit $($r.Code): $($r.Err.Trim())" }
    [IO.File]::AppendAllText((Join-Path $pk 'reg\greet\1.0.0.envopkg'), ' ')
    $r = Invoke-Tool $envo @('run', 'pk/app2') $envoRun
    if ($r.Code -eq 1 -and $r.Err.Contains("the registry's copy changed")) { Pass 'packages: a changed archive' } else { Bad 'packages: a changed archive' "exit $($r.Code): $($r.Err.Trim())" }
    # envo build --sbom: an SPDX 2.3 SBOM beside the program, the same for the same build
    $env:SOURCE_DATE_EPOCH = '1762905600'
    $r = Invoke-Tool $envo @('build', '--sbom', 'pk/app') $envoRun
    Remove-Item Env:SOURCE_DATE_EPOCH
    $sb = Join-Path $pk 'app\build\app.exe.spdx.json'
    $sbText = ''
    if (Test-Path -LiteralPath $sb) { $sbText = [IO.File]::ReadAllText($sb) }
    if ($r.Code -eq 0 -and $sbText -match '"spdxVersion":\s*"SPDX-2.3"' -and $sbText -match '"name":\s*"greet"' -and $sbText.Contains('2025-11-12T00:00:00Z')) { Pass 'envo build --sbom' } else { Bad 'envo build --sbom' "exit $($r.Code): $($r.Err.Trim())" }
    # releases (https://github.com/envoscale/EnvoScale/blob/main/guides/offline-install.md): envo archive gives the same bytes on every
    # OS (the digest is pinned in both scripts); envo sign and envo verify
    $RelTarSha = 'b54a3aa9ab43038969bf16347b53b6940e813f9889ab3be0e0f29c6ef9b11ee1'
    $env:SOURCE_DATE_EPOCH = '1762905600'
    $r = Invoke-Tool $envo @('archive', 'pk/greet', 'pk/greet.tar') $envoRun
    Remove-Item Env:SOURCE_DATE_EPOCH
    $relTar = Join-Path $pk 'greet.tar'
    $relSha = ''
    if (Test-Path -LiteralPath $relTar) { $relSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $relTar).Hash.ToLowerInvariant() }
    if ($r.Code -eq 0 -and $relSha -eq $RelTarSha) { Pass 'envo archive (reproducible)' } else { Bad 'envo archive (reproducible)' "exit $($r.Code): $relSha $($r.Err.Trim())" }
    $r1 = Invoke-Tool $envo @('sign', 'pk/greet.tar', '--key', 'pk/publisher.key') $envoRun
    $r2 = Invoke-Tool $envo @('verify', 'pk/greet.tar', '--key', $pub) $envoRun
    $r = Invoke-Tool $envo @('verify', 'pk/greet.tar', '--key', $other) $envoRun
    if ($r1.Code -eq 0 -and $r2.Code -eq 0 -and $r.Code -eq 1) { Pass 'envo sign, envo verify' } else { Bad 'envo sign, envo verify' "exit $($r1.Code), $($r2.Code), $($r.Code): $($r1.Err.Trim()) $($r2.Err.Trim())" }
    # fuzz targets (tests\fuzz): each parser of untrusted input takes a few hundred fuzzed
    # inputs without a panic
    Say 'fuzz targets: tests/fuzz, 300 runs each'
    $frun = Join-Path $Root 'build\run-fuzz'
    if (Test-Path -LiteralPath $frun) { Remove-Item -Recurse -Force $frun }
    New-Item -ItemType Directory -Force $frun | Out-Null
    foreach ($t in (Get-ChildItem -LiteralPath (Join-Path $Root 'tests\fuzz') -Filter '*.envol' | Sort-Object Name)) {
        $n = $t.BaseName
        Copy-Item -Recurse (Join-Path $Root "tests\fuzz\corpus\$n") (Join-Path $frun "corpus-$n")
        $r = Invoke-Tool $envo @('fuzz', $t.FullName, '--runs', '300', '--seed', '1', '--corpus', "corpus-$n", '--max-len', '1024') $frun
        if ($r.Code -eq 0 -and $r.Out.Contains('no crash')) { Pass "fuzz $n" } else { Bad "fuzz $n" "exit $($r.Code): $($r.Out.Trim()) $($r.Err.Trim())" }
    }
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
    # envo fmt: each tests\golden\fmt\name.envol formats to name.expected, which formats to
    # itself; and the repository's own code is already in the canonical layout
    Say 'envo fmt: tests/golden/fmt, and --check on the code'
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root 'tests\golden\fmt') -Filter '*.envol' | Sort-Object Name) {
        $expected = [IO.Path]::ChangeExtension($f.FullName, '.expected')
        $want = Normalize ([IO.File]::ReadAllText($expected, $Utf8))
        $r = Invoke-Tool $envo @('fmt', '--stdout', $f.FullName) $envoRun
        if ($r.Code -eq 0 -and (Normalize $r.Out) -eq $want) { Pass "fmt $($f.Name)" } else { Bad "golden fmt/$($f.Name)" "exit $($r.Code): $($r.Err.Trim())"; Show-Diff $want (Normalize $r.Out) }
        $r = Invoke-Tool $envo @('fmt', '--stdout', $expected) $envoRun
        if ($r.Code -eq 0 -and (Normalize $r.Out) -eq $want) { Pass "fmt $($f.Name) (again)" } else { Bad "golden fmt/$($f.Name) (formatting the expected output changes it)" "exit $($r.Code)" }
    }
    $r = Invoke-Tool $envo @('fmt', '--check', 'lib', 'adapters', 'tools', 'tests/conformance', 'compiler', 'runtime', 'examples') $Root
    if ($r.Code -eq 0) { Pass 'envo fmt --check' } else { Bad 'envo fmt --check (run envo fmt on these files)' "$($r.Out.Trim()) $($r.Err.Trim())" }
    # envo lsp: tests\lsp\session.jsonl, framed, piped in; the bodies it writes back must
    # be tests\lsp\expected.jsonl (tests/lsp/README.md)
    Say 'envo lsp: tests/lsp/session.jsonl'
    $lspDir = Join-Path $Root 'build\run-lsp'
    New-Item -ItemType Directory -Force $lspDir | Out-Null
    $uri = 'file:///' + ((Join-Path $lspDir 'doc.envol') -replace '\\', '/')
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
    Say 'spec tests: tests/spec/lib'
    $dir = Join-Path $Root 'tests\spec\lib'
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.envol' | Sort-Object Name) {
        $text = [IO.File]::ReadAllText($f.FullName, $Utf8)
        $m = [regex]::Match($text, '(?m)^// expect-error: (E\d{4}) @ (\S+)')
        if (-not $m.Success) { Bad "spec/lib/$($f.Name)" 'no // expect-error: annotation'; continue }
        $where = $m.Groups[2].Value
        if ($where -match '\.envol:') { $want = "$($where): error[$($m.Groups[1].Value)]" }
        else { $want = "$($f.Name):$($where): error[$($m.Groups[1].Value)]" }
        $libRoot = $Root
        if ($text -match '(?m)^// lib: root') { $libRoot = 'root' }
        $r = Invoke-Tool $envoc @('check', '--lib', $libRoot, $f.Name) $dir
        if ($r.Code -eq 1 -and $r.Err.Contains($want)) { Pass $f.Name }
        else { Bad "spec/lib/$($f.Name)" "expected exit 1 with '$want'; got exit $($r.Code): $($r.Err.Trim())" }
    }
    # The compiler builds itself into the same bytes (the fixed point), and through an
    # object of itself, compiled and linked
    Say 'fixed point: build/envoc builds itself into the same bytes'
    $selfDir = Join-Path $Root 'build\run-envoc'
    New-Item -ItemType Directory -Force $selfDir | Out-Null
    $files = Get-CompilerFiles
    foreach ($u in @(@{ Target = 'x86_64-windows'; Out = 'envoc.exe' }, @{ Target = 'x86_64-linux'; Out = 'envoc' })) {
        $self = Join-Path $selfDir "self-$($u.Out)"
        $r = Invoke-Tool $envoc (@('build', '-O2') + $files + @('-o', $self, '--target', $u.Target)) $Stage2
        if ($r.Code -eq 0 -and (Test-SameBytes $self (Join-Path $Build2 $u.Out))) { Pass "fixed point ($($u.Target))" }
        else { Bad "fixed point ($($u.Target))" "exit $($r.Code), or build\envoc\$($u.Out) builds itself into different bytes: $($r.Err.Trim())" }
    }
    $obj = Join-Path $selfDir 'self.eo'
    $linked = Join-Path $selfDir 'self-linked.exe'
    $r = Invoke-Tool $envoc (@('compile', '-O2') + $files + @('-o', $obj)) $Stage2
    if ($r.Code -eq 0) { $r = Invoke-Tool $envoc @('link', '-O2', $obj, '-o', $linked) $Stage2 }
    if ($r.Code -eq 0 -and (Test-SameBytes $linked (Join-Path $Build2 'envoc.exe'))) { Pass 'compile and link the compiler' }
    else { Bad 'compile and link the compiler' "exit $($r.Code), or the executable differs from build\envoc" }

    $none = Join-Path $selfDir 'none.exe'
    $r = Invoke-Tool $envoc @('link', (Join-Path $selfDir 'core-multi-program.exe.0.eo'), '-o', $none) $Root
    if ($r.Code -eq 1 -and $r.Err.Contains('no object defines @')) { Pass 'link with a unit missing' } else { Bad 'link with a unit missing' "exit $($r.Code): $($r.Err)" }
    $r = Invoke-Tool $envoc @('link', (Join-Path $selfDir 'core-multi-program.exe.0.eo'), (Join-Path $selfDir 's1-multi-namespaces.exe.0.eo'), '-o', $none) $Root
    if ($r.Code -eq 1 -and $r.Err.Contains('compiled from different programs')) { Pass 'link of two programs' } else { Bad 'link of two programs' "exit $($r.Code): $($r.Err)" }
    $v2 = Join-Path $selfDir 'v2.eo'
    [IO.File]::WriteAllBytes($v2, [byte[]](0x45, 0x49, 0x52, 0, 2, 0))
    $r = Invoke-Tool $envoc @('link', $v2, '-o', $none) $Root
    if ($r.Code -eq 1 -and $r.Err.Contains('binary EIR version 2; this envoc reads version 1')) { Pass 'link of an unknown version' } else { Bad 'link of an unknown version' "exit $($r.Code): $($r.Err)" }


    Say ''
    Say "$($script:passed) passed, $($script:failed) failed"
    if ($script:failed -gt 0) { exit 1 }
}

# ------------------------------------------------------------------- check
function Invoke-Check {
    $problems = New-Object System.Collections.Generic.List[string]

    foreach ($f in @('README.md', 'LICENSE', 'CONTRIBUTING.md', 'build.sh', 'build.ps1', 'spec/README.md', 'spec/errors.md',
                     'NOTICE')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $f))) { $problems.Add("missing file: $f") }
    }

    # The principles (project/principles.md in the docs): lib/** never imports adapters/**.
    $lib = Join-Path $Root 'lib'
    foreach ($f in Get-ChildItem -LiteralPath $lib -Recurse -Filter '*.envol' -ErrorAction SilentlyContinue) {
        $hits = Select-String -LiteralPath $f.FullName -Pattern '^\s*(use|using)\s+adapters\b'
        foreach ($h in $hits) { $problems.Add("lib imports an adapter: $($f.FullName.Substring($Root.Length + 1)):$($h.LineNumber)") }
    }


    if ($problems.Count -gt 0) {
        foreach ($p in $problems) { [Console]::Error.WriteLine("check: $p") }
        Fail "$($problems.Count) problem(s)"
    }
    Say "check: ok (no lib->adapters imports)"
}

# ------------------------------------------------------------------- dist
# dist: the release archive (https://github.com/envoscale/EnvoScale/blob/main/guides/offline-install.md); the same bytes as build.sh's.
function Invoke-Dist {
    Invoke-Build
    $v = ([regex]::Match([IO.File]::ReadAllText((Join-Path $Root 'tools\envo\main.envol')), 'const str ENVO_VERSION = "([^"]*)"')).Groups[1].Value
    $dist = Join-Path $Root 'build\dist'
    if (Test-Path -LiteralPath $dist) { Remove-Item -Recurse -Force $dist }
    $top = Join-Path $dist "envoscale-$v"
    New-Item -ItemType Directory -Force (Join-Path $top 'bin') | Out-Null
    foreach ($f in @('build\envo\envo', 'build\envo\envo.exe', 'build\envoc\envoc', 'build\envoc\envoc.exe')) { Copy-Item (Join-Path $Root $f) (Join-Path $top 'bin') }
    foreach ($d in @('lib', 'adapters', 'spec')) { Copy-Item -Recurse (Join-Path $Root $d) (Join-Path $top $d) }
    foreach ($f in @('LICENSE', 'NOTICE', 'README.md')) { Copy-Item (Join-Path $Root $f) $top }
    $env:SOURCE_DATE_EPOCH = '0'
    $r = Invoke-Tool (Join-Path $Root 'build\envo\envo.exe') @('archive', "envoscale-$v", "envoscale-$v.tar") $dist
    Remove-Item Env:SOURCE_DATE_EPOCH
    if ($r.Code -ne 0) { Fail "envo archive failed: $($r.Err.Trim())" }
    $tar = Join-Path $dist "envoscale-$v.tar"
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $tar).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS'), "$hash  envoscale-$v.tar`n", (New-Object System.Text.UTF8Encoding($false)))
    # an in-toto statement (SLSA provenance v1) of how the archive was built, as build.sh's
    $commit = $env:GITHUB_SHA
    if (-not $commit) { $commit = (& git -C $Root rev-parse HEAD 2>$null); if (-not $commit) { $commit = 'unknown' } }
    $builder = 'local'
    if ($env:GITHUB_RUN_ID) { $builder = "$($env:GITHUB_SERVER_URL)/$($env:GITHUB_REPOSITORY)/actions/runs/$($env:GITHUB_RUN_ID)" }
    $by = @()
    foreach ($b in @(@("seed $SeedTag", (Get-Seed)), @('envoc.exe', (Join-Path $Root 'build\envoc\envoc.exe')))) {
        $bh = (Get-FileHash -Algorithm SHA256 -LiteralPath $b[1]).Hash.ToLowerInvariant()
        $by += "        {`"name`": `"$($b[0])`", `"digest`": {`"sha256`": `"$bh`"}}"
    }
    $prov = @(
        '{',
        '  "_type": "https://in-toto.io/Statement/v1",',
        "  `"subject`": [{`"name`": `"envoscale-$v.tar`", `"digest`": {`"sha256`": `"$hash`"}}],",
        '  "predicateType": "https://slsa.dev/provenance/v1",',
        '  "predicate": {',
        '    "buildDefinition": {',
        '      "buildType": "https://github.com/envoscale/EnvoScale/blob/main/guides/offline-install.md#provenance",',
        '      "externalParameters": {"command": "build.ps1 dist", "SOURCE_DATE_EPOCH": "0"},',
        "      `"resolvedDependencies`": [{`"uri`": `"git+https://github.com/envoscale/EnvoLang`", `"digest`": {`"gitCommit`": `"$commit`"}}]",
        '    },',
        '    "runDetails": {',
        "      `"builder`": {`"id`": `"$builder`"},",
        '      "byproducts": [',
        ($by -join ",`n"),
        '      ]',
        '    }',
        '  }',
        '}'
    ) -join "`n"
    [IO.File]::WriteAllText((Join-Path $dist "envoscale-$v.provenance.json"), "$prov`n", (New-Object System.Text.UTF8Encoding($false)))
    Say "dist      build\dist\envoscale-$v.tar"
    Say "          sha256 $hash"
}

switch ($Command) {
    'build' { Invoke-Build }
    'test'  { Invoke-Test }
    'check' { Invoke-Check }
    'dist'  { Invoke-Dist }
    'clean' { if (Test-Path -LiteralPath (Join-Path $Root 'build')) { Remove-Item -Recurse -Force (Join-Path $Root 'build') }; Say 'removed build/' }
    default {
        Say 'usage: .\build.ps1 <build|test|check|dist|clean>'
        Say '  build   download the seed compiler, then build build\envoc and build\envo'
        Say '  test    build, then run every test'
        Say '  check   quick repository checks'
        Say '  dist    build, then the release archive in build\dist'
        Say '  clean   delete build\'
        if ($Command -ne 'help') { exit 2 }
    }
}
