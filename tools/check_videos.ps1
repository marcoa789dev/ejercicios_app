# Analiza los videos con ffprobe y dice si basta con reacomodarlos o hay que recodificarlos.
# Nunca cambia la resolución ni los fps (ver PLAN_MAESTRO §8.3).
#
# Uso:  .\tools\check_videos.ps1 [-Dir C:\Users\sis\Videos\Ejercicios\originales]
# Salida: tabla en pantalla + analisis_videos.csv en la carpeta superior de -Dir.
param([string]$Dir = "$env:USERPROFILE\Videos\Ejercicios\originales")

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Dir)) { throw "No existe la carpeta: $Dir" }
$Dir = (Resolve-Path $Dir).Path.TrimEnd('\')

$rows = Get-ChildItem $Dir -Recurse -File -Include *.mp4, *.mov, *.mkv, *.m4v | ForEach-Object {
  $json = & ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,pix_fmt,r_frame_rate:format=duration,size `
    -of json $_.FullName
  $j = ($json -join "`n") | ConvertFrom-Json
  $v = $j.streams | Where-Object codec_type -eq 'video' | Select-Object -First 1
  $a = $j.streams | Where-Object codec_type -eq 'audio' | Select-Object -First 1

  $ok = $_.Extension -in @('.mp4', '.m4v') -and
        $v.codec_name -in @('h264', 'hevc') -and
        (-not $a -or $a.codec_name -in @('aac', 'mp3'))

  $fps = if ($v.r_frame_rate -match '^(\d+)/(\d+)$' -and [int]$Matches[2] -ne 0) {
    [math]::Round([double]$Matches[1] / [double]$Matches[2], 2)
  } else { $null }

  [pscustomobject]@{
    Archivo    = $_.FullName.Substring($Dir.Length + 1)
    Video      = $v.codec_name
    Audio      = if ($a) { $a.codec_name } else { '(sin audio)' }
    Resolucion = "$($v.width)x$($v.height)"
    Fps        = $fps
    Duracion_s = [int][double]$j.format.duration
    MB         = [math]::Round([double]$j.format.size / 1MB, 1)
    Accion     = if ($ok) { 'reacomodar' } else { 'recodificar' }
    Aviso      = if ([int]$v.height -gt 1080) { 'Más de 1080p: solo lo reproduce el Chromecast 4K' }
                 elseif ($v.codec_name -eq 'hevc') { 'HEVC: probar en los teléfonos más antiguos' }
                 else { '' }
  }
}

if (-not $rows) { Write-Warning "No se encontraron videos en $Dir"; return }

$rows | Format-Table -AutoSize
$csv = Join-Path (Split-Path $Dir) 'analisis_videos.csv'
$rows | Export-Csv $csv -NoTypeInformation -Encoding utf8

$totalGb = ($rows | Measure-Object MB -Sum).Sum / 1024
$reacomodar = @($rows | Where-Object Accion -eq 'reacomodar').Count
'Videos: {0}  ·  reacomodar: {1}  ·  recodificar: {2}  ·  total: {3:N2} GB (límite gratis R2: 10 GB)' -f `
  $rows.Count, $reacomodar, ($rows.Count - $reacomodar), $totalGb
"Análisis guardado en $csv"
