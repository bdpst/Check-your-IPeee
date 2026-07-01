@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "COLOR_GREEN=[32m"
set "COLOR_RED=[31m"
set "COLOR_BLUE=[34m"
set "COLOR_YELLOW=[33m"
set "COLOR_CYAN=[36m"
set "COLOR_RESET=[0m"

for /f %%a in ('date /t') do set "CURRENT_DATE=%%a"
for /f %%a in ('time /t') do set "CURRENT_TIME=%%a"

echo.
echo %COLOR_BLUE%=== Определение локального IP-адреса и подсети ===%COLOR_RESET%
echo %COLOR_BLUE%Дата: %CURRENT_DATE%, Время: %CURRENT_TIME%%COLOR_RESET%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "function Get-MaskBytes([int]$PrefixLength) {" ^
  "  $bytes = @();" ^
  "  $left = $PrefixLength;" ^
  "  for ($i = 0; $i -lt 4; $i++) {" ^
  "    if ($left -ge 8) { $bytes += 255; $left -= 8 }" ^
  "    elseif ($left -gt 0) { $bytes += [int](256 - [math]::Pow(2, 8 - $left)); $left = 0 }" ^
  "    else { $bytes += 0 }" ^
  "  }" ^
  "  return $bytes" ^
  "}" ^
  "function Get-NetworkAddress([string]$IPAddress, [int]$PrefixLength) {" ^
  "  $ipBytes = [System.Net.IPAddress]::Parse($IPAddress).GetAddressBytes();" ^
  "  $maskBytes = Get-MaskBytes $PrefixLength;" ^
  "  $networkBytes = for ($i = 0; $i -lt 4; $i++) { $ipBytes[$i] -band $maskBytes[$i] };" ^
  "  [pscustomobject]@{ Network = ($networkBytes -join '.'); Mask = ($maskBytes -join '.') }" ^
  "}" ^
  "$items = foreach ($config in Get-NetIPConfiguration) {" ^
  "  foreach ($addr in @($config.IPv4Address)) {" ^
  "    if (-not $addr) { continue }" ^
  "    if ($addr.IPAddress -like '127.*' -or $addr.IPAddress -like '169.254.*') { continue }" ^
  "    $iface = Get-NetIPInterface -AddressFamily IPv4 -InterfaceIndex $config.InterfaceIndex -ErrorAction SilentlyContinue | Select-Object -First 1;" ^
  "    $network = Get-NetworkAddress $addr.IPAddress $addr.PrefixLength;" ^
  "    [pscustomobject]@{" ^
  "      IPAddress = $addr.IPAddress;" ^
  "      PrefixLength = $addr.PrefixLength;" ^
  "      Network = $network.Network;" ^
  "      Mask = $network.Mask;" ^
  "      InterfaceAlias = $config.InterfaceAlias;" ^
  "      Gateway = (@($config.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join ', ');" ^
  "      InterfaceMetric = if ($iface) { $iface.InterfaceMetric } else { 9999 }" ^
  "    }" ^
  "  }" ^
  "};" ^
  "$items = @($items | Sort-Object @{ Expression = { if ($_.Gateway) { 0 } else { 1 } } }, InterfaceMetric, InterfaceAlias);" ^
  "if ($items.Count -eq 0) { exit 1 }" ^
  "$item = @($items | Where-Object { $_.Gateway } | Select-Object -First 1);" ^
  "if (-not $item) { $item = $items[0] }" ^
  "Write-Host 'Подсеть:    ' -NoNewline -ForegroundColor Yellow; Write-Host ($item.Network + '/' + $item.PrefixLength) -ForegroundColor Yellow;" ^
  "Write-Host 'IP-адрес:   ' -NoNewline -ForegroundColor Green; Write-Host $item.IPAddress -ForegroundColor Green;" ^
  "Write-Host 'Маска:      ' -NoNewline -ForegroundColor Cyan; Write-Host $item.Mask -ForegroundColor Cyan;" ^
  "Write-Host 'Интерфейс:  ' -NoNewline -ForegroundColor Cyan; Write-Host $item.InterfaceAlias -ForegroundColor Cyan;" ^
  "if ($item.Gateway) { Write-Host 'Шлюз:       ' -NoNewline -ForegroundColor Cyan; Write-Host $item.Gateway -ForegroundColor Cyan }"

if errorlevel 1 (
    echo %COLOR_RED%Не найден активный локальный IPv4-адрес.%COLOR_RESET%
)

echo %COLOR_BLUE%=== Проверка завершена ===%COLOR_RESET%
echo %COLOR_BLUE%Дата: %CURRENT_DATE%, Время: %CURRENT_TIME%%COLOR_RESET%
echo.

pause
