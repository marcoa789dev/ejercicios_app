# Recomprime los videos EN SU LUGAR para ahorrar espacio en R2, sin reescalar:
#   - H.264, misma resolución y fps, video ≤ 75 % del bitrate original (CRF 26 con tope)
#   - audio AAC 96 kbps, solo la primera pista de video y de audio, +faststart
#   - miniatura .webp junto a cada video
# Cada resultado se verifica (resolución, fps, duración ±1 s y decodificación del final)
# y SOLO entonces reemplaza al original. Si la verificación falla, el original se conserva.
# Se puede interrumpir y volver a ejecutar: salta los videos ya comprimidos (marca en metadatos).
#
# Uso:  .\tools\compress_videos.ps1 [-Dir .\Videos] [-Ratio 0.75] [-Crf 26]
param(
  [string]$Dir = (Join-Path $PSScriptRoot '..\Videos'),
  [double]$Ratio = 0.75,
  [int]$Crf = 26,
  [string]$AudioBitrate = '96k'
)

$Dir = (Resolve-Path $Dir).Path.TrimEnd('\')
$mark = "ejercicios-app:h264-crf$Crf-r$Ratio"
$log = Join-Path $Dir 'compresion.log'

function Write-Log([string]$msg) {
  $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg
  Write-Host $line
  Add-Content -Path $log -Value $line -Encoding utf8
}

function Get-Probe([string]$path) {
  $json = & ffprobe -v error -show_entries `
    'stream=codec_type,width,height,r_frame_rate,bit_rate:format=duration,bit_rate:format_tags=comment' `
    -of json $path
  return ($json -join "`n") | ConvertFrom-Json
}

$files = Get-ChildItem $Dir -Recurse -File -Filter *.mp4 |
  Where-Object { $_.Name -notlike '*.tmp.mp4' } | Sort-Object FullName
$before = 0L; $after = 0L
Write-Log "Inicio: $($files.Count) videos en $Dir (CRF $Crf, tope $([int]($Ratio * 100)) %, audio $AudioBitrate)"

foreach ($f in $files) {
  $rel = $f.FullName.Substring($Dir.Length + 1)
  $p = Get-Probe $f.FullName
  $thumb = [IO.Path]::ChangeExtension($f.FullName, '.webp')

  if ("$($p.format.tags.comment)" -like "$mark*") {
    Write-Log "[ya comprimido] $rel"
    $before += $f.Length; $after += $f.Length
  } else {
    $v = $p.streams | Where-Object codec_type -eq 'video' | Select-Object -First 1
    $kbps = [double]$(if ($v.bit_rate) { $v.bit_rate } else { $p.format.bit_rate }) / 1000
    $cap = [int]($kbps * $Ratio)
    $tmp = [IO.Path]::ChangeExtension($f.FullName, '.tmp.mp4')
    $source = "$($p.format.tags.comment)"
    $sw = [Diagnostics.Stopwatch]::StartNew()

    & ffmpeg -hide_banner -loglevel error -y -i $f.FullName -map 0:v:0 -map 0:a:0 -map_chapters -1 `
      -c:v libx264 -preset medium -crf $Crf -maxrate "${cap}k" -bufsize "$($cap * 2)k" -pix_fmt yuv420p `
      -c:a aac -b:a $AudioBitrate -movflags +faststart `
      -metadata "comment=$mark | $source" $tmp
    $ok = $LASTEXITCODE -eq 0 -and (Test-Path $tmp)

    $why = 'ffmpeg falló'
    if ($ok) {
      $n = Get-Probe $tmp
      $nv = $n.streams | Where-Object codec_type -eq 'video' | Select-Object -First 1
      $why = ''
      if ($nv.width -ne $v.width -or $nv.height -ne $v.height) { $why += 'resolución distinta; ' }
      if ($nv.r_frame_rate -ne $v.r_frame_rate) { $why += 'fps distintos; ' }
      if ([math]::Abs([double]$n.format.duration - [double]$p.format.duration) -gt 1) { $why += 'duración distinta; ' }
      $decodeErr = & ffmpeg -hide_banner -v error -sseof -15 -i $tmp -f null - 2>&1
      if ($LASTEXITCODE -ne 0 -or $decodeErr) { $why += 'el final no se decodifica; ' }
      $ok = $why -eq ''
    }

    if ($ok) {
      $newSize = (Get-Item $tmp).Length
      Remove-Item -LiteralPath $f.FullName
      Rename-Item -LiteralPath $tmp -NewName $f.Name
      $before += $f.Length; $after += $newSize
      Write-Log ('[ok] {0}  {1:N0} MB -> {2:N0} MB ({3:P0} menos) en {4:N0} min' -f `
        $rel, ($f.Length / 1MB), ($newSize / 1MB), (1 - $newSize / $f.Length), $sw.Elapsed.TotalMinutes)
    } else {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp }
      $before += $f.Length; $after += $f.Length
      Write-Log "[ERROR] $rel  ($why) — se conserva el original"
    }
  }

  if (-not (Test-Path $thumb)) {
    & ffmpeg -hide_banner -loglevel error -y -ss 60 -i $f.FullName -frames:v 1 -vf 'scale=640:-2' -quality 82 $thumb
  }
}

Write-Log ('Fin: {0:N2} GB -> {1:N2} GB (se liberaron {2:N2} GB)' -f ($before / 1GB), ($after / 1GB), (($before - $after) / 1GB))
