[CmdletBinding(PositionalBinding = $false)]
param(
	[Parameter(Mandatory = $false)][string] $phpbin = '',
	[Parameter(Mandatory = $false)][string] $ini = '',
	[Parameter(Mandatory = $false)][string] $xdebug_dll_filename = 'php_xdebug.dll',
	[Parameter(Mandatory = $false)][switch] $confirm = $false,
	[Parameter(Mandatory = $false)][AllowEmptyString()][string] $logfile = "$PWD/xdebug_auto_update_$(get-date -format 'yyyy-MM-dd_HH.mm.ss').log",
	[parameter(Position = 0, ValueFromRemainingArguments = $true)] $args
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/src/functions.ps1"
$wizard_parser_script = "$PSScriptRoot/src/wizard_parser_script.php"
$wizard_url = 'https://xdebug.org/wizard'


if (![string]::IsNullOrEmpty($logfile)) {
	Start-Transcript -Path $logfile
}



section "SCRIPT STARTED ..."
out "arg 'phpbin': $phpbin"
out "arg 'ini': $ini"
out "arg 'xdebug_dll_filename': $xdebug_dll_filename"
out "arg 'confirm': $confirm"
out "arg 'logfile': $logfile"
if (!!$args) { out "[ignored additional arguments: $args]" }
$phpbin_passed = !!$phpbin
$ini_passed = !!$ini
$output_filename = $xdebug_dll_filename



section "PHPBIN & INI FILE SETUP ..."
if (!$phpbin_passed) {
	out "looking for phpbin ..."
	$phpbin = "php"
}
$where_phpbin = Get-Command $phpbin -ErrorAction SilentlyContinue
if (!$where_phpbin) {
	if (!$phpbin_passed) {
		err "phpbin not found in PATH and not specified via argument"
		exit 11
	}
	else {
		err "specified phpbin '$phpbin' not found"
		exit 22
	}
}
$phpbin = $where_phpbin.source
out "using phpbin: $phpbin"
if (!$ini_passed) {
	out "looking for ini file ..."
	$ini_filepath = (
		(
			((& $phpbin -d xdebug.mode=off -d xdebug.enable=0 --ini | out-string) -split '\n')[1]
		) -replace 'Loaded Configuration File:', ''
	).TRIM()
	if (($ini_filepath.contains("none")) -or ($ini_filepath -eq "") -or (!(test-path $ini_filepath))) {
		err "it seems like the php binary '$phpbin' doesn't use any php.ini file! please create one and rerun this script."
		exit 33
	}
}
else {
	if (!(test-path $ini_filepath)) {
		err "ini file '$ini_filepath' not found!"
		exit 44
	}
	else {
		if (!($ini_filepath -Like "*.ini")) {
			err "ini file '$ini_filepath' not valid!"
			exit 55
		}
	}
}
out "using ini file: $ini_filepath"
$phpdir = [io.path]::getdirectoryname($phpbin)
$ini_content = get-content $ini_filepath | OUT-STRING



section "GETTING PHP CONFIG VIA php -i ..."
$runtime_config = (& $phpbin -c $ini_filepath -d xdebug.mode=off -d xdebug.enable=0 -i) | out-string
$extension_dir = ($runtime_config | & findstr /r "/c:^[ ]*extension_dir[ ]*=.*`$")
if (!$extension_dir) {
	warn "> cannot determine 'extension_dir', fallback to 'ext'"
}
$extension_dir = if ($extension_dir) { ($extension_dir -split '=>')[2].trim() } else { 'ext' }
Push-Location $phpdir # necessary for resolve-path
$actual_extension_dir = (resolve-path $extension_dir).path
Pop-Location
mkdir $actual_extension_dir -ErrorAction SilentlyContinue
$output_filepath = join-path $actual_extension_dir $output_filename
$output_filepath_overwrite = test-path $output_filepath
out "using extension_dir: $actual_extension_dir"



section "CHECKING XDEBUG STATUS ..."
if ($runtime_config.contains("xdebug.loglevel")) {
	out "xdebug already installed!"
	confirm "do you want to update/reinstall? (yes/no)"
}
else {
	out "xdebug not installed"
}



section "CONFIRMATION"
out "phpbin='$phpbin'"
out "phpdir='$phpdir'"
out "ini file='$ini_filepath'"
out "extension_dir='$actual_extension_dir'$(if($extension_dir){''}else{' (fallback)'})"
out "output_filepath='$output_filepath'"
out "The file '$output_filepath' will be $(If($output_filepath_overwrite){'overwritten'}else{'created'}), and the ini file '$ini_filepath' will be updated if necessary."
"`n`n"; warn "Please check that all the parameters above are correct."
confirm "Continue? (yes-no)"



section "ENCODING PHP CONFIG WITH urlencode() ..."
$runtime_config_encoded = $runtime_config | & $phpbin -d xdebug.mode=off -d xdebug.enable=0 -r "echo urlencode(stream_get_contents(STDIN));" | out-string



section "SENDING CONFIG TO ONLINE WIZARD"
try {
	$response = Invoke-WebRequest -Method POST -Headers @{"content-type" = "application/x-www-form-urlencoded" } -Body "submit&data=$runtime_config_encoded" $wizard_url
}
catch {
	$err = $_
}
if (!$response -or ($response.statuscode -ne 200)) {
	err "Error during web request or local file saving"
	$response
	$err
	exit 66
}



section "PARSING RESPONSE BODY ..."
$response_html_body = $response.content
$href = $response_html_body | & $phpbin -d xdebug.mode=off -d xdebug.enable=0 -f $wizard_parser_script
if (($LASTEXITCODE -ne 0) -or !$href) {
	err "could not determine download URL"
	exit 77
}



section "DOWNLOADING DLL ..."
out "href='$href'"
$remote_filename = [io.path]::GetFileName($href)
out "remote_filename='$remote_filename'"
out "output_filename='$output_filename'"
out "output_filepath='$output_filepath'"
out "download started..."
try {
	$ProgressPreference = 'SilentlyContinue'    # Subsequent calls do not display UI.
	$dl = invoke-webrequest $href -outfile $output_filepath
	$dlok = test-path $output_filepath
}
catch {
	$err = $_
}
if (!$dlok -or $err -or ($dl -and ($dl.statuscode -ne 200))) {
	err "Error during web request: $err"
	exit 888
}
out "file downloaded"



section "UPDATING PHP.INI ..."
if ($output_filename -eq 'php_xdebug.dll') {
	$new_zend_extension_value = 'xdebug'
}
else {
	$new_zend_extension_value = $output_filepath
}
out "reading ini file '$ini_filepath'"
$inibck_filepath = "$ini_filepath.bck_$(datetime)"
Copy-Item $ini_filepath $inibck_filepath
out "backup created: $inibck_filepath"
if ($ini_content | & findstr /r "/c:^[ ]*zend_extension[ ]*=.*`$") {
	out "zend_extension line found in ini file, updating..."
	$ini_content | `
		& $phpbin -d xdebug.mode=off -d xdebug.enable=0 -r `
		"echo preg_replace('/^[ ]*zend_extension[ ]*=(.+)`$/mi', 'zend_extension=$new_zend_extension_value', stream_get_contents(STDIN));" | `
		out-file $ini_filepath -Encoding utf8
}
else {
	out "zend_extension line NOT found in ini file, adding..."
	$ini_content + "`n`n`nzend_extension=$new_zend_extension_value`n" | out-file $ini_filepath -Encoding utf8
}
out "new_zend_extension_value='$new_zend_extension_value'"



"`n`n" ; Write-Host -ForegroundColor white -BackgroundColor Green " ====== ALL DONE ====== " ; ""
out 'Quitting in 6 seconds...'
if (![string]::IsNullOrEmpty($logfile)) {
	Stop-Transcript
}
& timeout 6