# Extends EXISTING LegionCore teleport command script without altering AzerothCore.
# Restricted to SEC_MODERATOR, exactly as .tele in this Legion core.
$ErrorActionPreference = 'Stop'
$Source = Join-Path $env:GITHUB_WORKSPACE 'legion-src/src/server/scripts/Commands/cs_tele.cpp'
if (-not (Test-Path -LiteralPath $Source)) { throw "Missing upstream command source: $Source" }
$Cpp = [System.IO.File]::ReadAllText($Source)
if ($Cpp.Contains('HandleMallCommand')) {
    Write-Host '.mall command already exists upstream. No patch required.'
    exit 0
}

# Change only the literal top-level command registration, not any tele subcommands.
$Needle = '{ "tele",'
$At = $Cpp.IndexOf($Needle, [System.StringComparison]::Ordinal)
if ($At -lt 0) {
    throw 'Cannot find .tele command registration in cs_tele.cpp.'
}
$LineStart = $Cpp.LastIndexOf([char]10, $At) + 1
$LineEnd = $Cpp.IndexOf([char]10, $At)
if ($LineEnd -lt 0) { $LineEnd = $Cpp.Length }
$Line = $Cpp.Substring($LineStart, $LineEnd - $LineStart)
if (-not ($Line.Contains('SEC_MODERATOR') -and $Line.Contains('teleCommandTable'))) {
    throw 'Found .tele but its registration no longer matches expected security/subcommands.'
}
$Prefix = $Line.Substring(0, $Line.IndexOf('{'))
$NewCommand = $Prefix + '{ "mall", SEC_MODERATOR, false, &HandleMallCommand, "" },' + [Environment]::NewLine
$Cpp = $Cpp.Insert($LineStart, $NewCommand)

$Anchor = '    static bool HandleTeleCommand(ChatHandler* handler, const char* args)'
if (-not $Cpp.Contains($Anchor)) {
    throw 'Cannot find existing .tele implementation. Upstream API changed.'
}
$Method = @'
    // GM Island AtlasLoot showroom. Security is enforced by command registration.
    static bool HandleMallCommand(ChatHandler* handler, const char* /*args*/)
    {
        // Keep a writable buffer for the legacy extractGameTeleFromLink parser.
        char destination[] = "AtlasMall";
        return HandleTeleCommand(handler, destination);
    }

'@
$Cpp = $Cpp.Replace($Anchor, $Method + $Anchor)
[System.IO.File]::WriteAllText($Source, $Cpp, [System.Text.UTF8Encoding]::new($false))
if (-not ($Cpp.Contains('{ "mall", SEC_MODERATOR') -and $Cpp.Contains('char destination[] = "AtlasMall"'))) {
    throw 'AtlasMall command patch verification failed'
}
Write-Host 'Registered GM-only .mall teleport alias using the existing .tele handler.'
