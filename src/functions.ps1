
function section([string] $text) {
    ''
    # -NoNewLine stops the coloring from polluting the next line
    write-host -NoNewline -foregroundcolor Magenta -backgroundcolor white $text
    ''
}

function warn([string] $text) {
    write-warning $text
}

function out([string] $text) {
    Write-Output "> $text"
}

function err([string] $text) {
    Write-Error $text
}

function confirm([string] $text) {
    ''; ''
    out "$text"
    if ($script:confirm) {
        out '[AUTO_CONFIRM]'
        return $true
    }
    $ok = ((Read-Host).tolower() -in @('yes', 'y'))
    if (!$ok) {
        err "Aborted."
        exit 1
    }
    return $true
}