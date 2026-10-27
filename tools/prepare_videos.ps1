# Prepara los videos para R2 según analisis_videos.csv (generado por check_videos.ps1):
#   reacomodar  → ffmpeg -c copy -movflags +faststart   (sin tocar la imagen)
#   recodificar → H.264 CRF 18 + AAC, MISMA resolución y fps (sin scale ni fps)
# Además genera una miniatura .webp por video. Conserva la estructura de subcarpetas.
#
# Uso:  .\tools\prepare_videos.ps1 [-Src ...\originales] [-Out ...\listos]
param(
  [string]$Src = "$env:USERPROFILE\Videos\Ejercicios\originales",
  [string]$Out = "$env:USERPROFILE\Videos\Ejercicios\listos"
)

$ErrorActionPreference = 'Stop'
$Src = (Resolve-Path $Src).Path.TrimEnd('\')
$csv = Join-Path (Split-Path $Src) 'analisis_videos.csv'
if (-not (Test-Path $csv)) { throw "Primero ejecuta check_videos.ps1 (falta $csv)" }
New-Item -ItemType Directory -Force $Out | Out-Null

foreach ($row in Import-Csv $csv) {
  $in = Join-Path $Src $row.Archivo
  $dest = Join-Path $Out ([IO.Path]::ChangeExtension($row.Archivo, '.mp4'))
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null

  if ($row.Accion -eq 'reacomodar') {
    Write-Host "[reacomodar]  $($row.Archivo)"
    & ffmpeg -hide_banner -loglevel error -y -i $in -map 0 -c copy -movflags +faststart $dest
  } else {
    Write-Host "[recodificar] $($row.Archivo)  (misma resolución $($row.Resolucion))"
    & ffmpeg -hide_banner -loglevel error -y -i $in `
      -c:v libx264 -profile:v high -preset slow -crf 18 -pix_fmt yuv420p `
      -c:a aac -b:a 160k -movflags +faststart $dest
  }
  if ($LASTEXITCODE -ne 0) { Write-Warning "ffmpeg falló con $($row.Archivo)"; continue }

  $thumb = [IO.Path]::ChangeExtension($dest, '.webp')
  & ffmpeg -hide_banner -loglevel error -y -ss 3 -i $dest -frames:v 1 -vf 'scale=640:-2' $thumb
}

$totalGb = (Get-ChildItem $Out -Recurse -Filter *.mp4 | Measure-Object Length -Sum).Sum / 1GB
'Listo. Total en {0}: {1:N2} GB (límite gratis R2: 10 GB)' -f $Out, $totalGb
