param(
  [Parameter(Mandatory=$true)][string]$Dpr
)

# Compila un .dpr/.dproj con RAD Studio 12 (dcc64, Win64) para GDAL de OSGeo4W.
# 1) Garantiza BOM UTF-8 en todos los .pas/.dpr/.dfm (el compilador lee ANSI
#    si no hay BOM, lo que rompe los literales con acentos).
# 2) Compila con dcc64.

$ErrorActionPreference = "Stop"

$root    = Split-Path -Parent $PSScriptRoot          # D:\AAB\DELPHI_GDAL
$studio  = "C:\Program Files (x86)\Embarcadero\Studio\23.0"
$dcc     = Join-Path $studio "bin\dcc64.exe"
$lib     = Join-Path $studio "lib\win64"
$ns      = "System;Xml;Data;Datasnap;Web;Soap;Winapi;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell"
$dcu     = Join-Path $root "viewer\tests\dcu64"
$bin     = Join-Path $root "viewer\tests\bin64"

# --- 1) BOM UTF-8 ------------------------------------------------------------
$bom = [byte[]](0xEF, 0xBB, 0xBF)
Get-ChildItem -Path (Join-Path $root "viewer") -Recurse -Include *.pas,*.dpr,*.dfm |
  ForEach-Object {
    $b = [System.IO.File]::ReadAllBytes($_.FullName)
    $hasBom = ($b.Length -ge 3) -and ($b[0] -eq 0xEF) -and ($b[1] -eq 0xBB) -and ($b[2] -eq 0xBF)
    if (-not $hasBom) {
      [System.IO.File]::WriteAllBytes($_.FullName, $bom + $b)
    }
  }

# --- 2) compilar -------------------------------------------------------------
$unitPath = "$root\viewer\src;$root\viewer\src\gdal;$root\viewer\tests;$dcu;$lib\release;$lib\debug"
New-Item -ItemType Directory -Force -Path $dcu, $bin | Out-Null

& $dcc -B -Q "-NS$ns" "-U$unitPath" "-N$dcu" "-E$bin" $Dpr
Write-Output "DCC_EXITCODE=$LASTEXITCODE"
