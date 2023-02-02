> https://github.com/xdebug/vscode-php-debug/issues/817

# xdebug_auto_update

Simple powershell script to automatically install/update xdebug on Windows.

It fetches your php configuration, sends it to the [xdebug wizard web page](https://xdebug.org/wizard), downloads the dll at the url reported in the wizard, updates the php ini file in order to enable xdebug.

Run it via powershell or batch file:

```batch
.\xdebug_auto_update

powershell .\xdebug_auto_update.ps1
```

# Arguments

All arguments are optional.
| Arg | Meaning |
| --- | --- |
| `-phpbin <path>` | specify the php.exe binary to be used |
| `-ini <path>` | specify the php ini file to be used |
| `-xdebug_dll_filename <path>` | specify the xdebug dll filename to be used |
| `-confirm` | answer Yes to any possible confirmation prompt |
