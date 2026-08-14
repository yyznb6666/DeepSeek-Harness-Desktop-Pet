# Generate pet assets: assets/emis.ico (PNG-compressed ICO) + assets/emis.png
# Uses pet/portrait.png (the real chibi portrait) when available,
# otherwise falls back to the drawn pink ghost mark.
param([string]$OutDir)
Add-Type -AssemblyName System.Drawing

function New-IconBitmap([int]$size, [string]$portrait) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $s = $size / 256.0

    # pink aura disc
    $disc = New-Object System.Drawing.Drawing2D.GraphicsPath
    $disc.AddEllipse(18 * $s, 18 * $s, 220 * $s, 220 * $s)
    $pb = New-Object System.Drawing.Drawing2D.PathGradientBrush($disc)
    $pb.CenterColor = [System.Drawing.Color]::FromArgb(255, 255, 173, 216)
    $pb.SurroundColors = @([System.Drawing.Color]::FromArgb(255, 255, 118, 190))
    $g.FillPath($pb, $disc)

    $usePortrait = $false
    if ($portrait -and (Test-Path $portrait)) {
        try {
            $src = New-Object System.Drawing.Bitmap($portrait)
            $ph = 212.0 * $s
            $scale = $ph / $src.Height
            $pw = [int]($src.Width * $scale)
            if ($pw -gt (236 * $s)) { $scale = (236 * $s) / $src.Width; $pw = [int]($src.Width * $scale) }
            $ph = [int]($src.Height * $scale)
            $x = [int]((($size / 2) - ($pw / 2)))
            $y = [int]((254 * $s) - $ph)
            $g.DrawImage($src, $x, $y, $pw, $ph)
            $src.Dispose()
            $usePortrait = $true
            Write-Host "icon uses portrait: $portrait"
        } catch {
            Write-Host "portrait load failed, drawing ghost fallback: $($_.Exception.Message)"
        }
    }

    if (-not $usePortrait) {
        # fallback: pink ghost mark
        $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gx = 70.0 * $s; $gy = 46.0 * $s; $gw = 116.0 * $s; $gh = 116.0 * $s
        $gp.AddArc($gx, $gy, $gw, $gh, 180, 180)
        $rightX = ($gx + $gw)
        $bottomY = 196.0 * $s
        $gp.AddLine($rightX, $gy + $gh / 2, $rightX, $bottomY)
        $n = 6
        for ($i = 0; $i -lt $n; $i++) {
            $x0 = $rightX - $i * ($rightX - $gx) / $n
            $x1 = $rightX - ($i + 1) * ($rightX - $gx) / $n
            $y0 = $bottomY - (($i % 2) * 14 * $s)
            $gp.AddLine([single]$x0, [single]$y0, [single]$x1, [single]$bottomY)
        }
        $gp.AddLine([single]$gx, [single]$bottomY, [single]$gx, [single]($gy + $gh / 2))
        $gp.CloseFigure()
        $gb = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.Point(0, 60)), (New-Object System.Drawing.Point(0, 220)),
            [System.Drawing.Color]::White, [System.Drawing.Color]::FromArgb(255, 255, 214, 235))
        $g.FillPath($gb, $gp)
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 255, 255, 255), (2 * $s))
        $g.DrawPath($pen, $gp)
        $eyeC = [System.Drawing.Color]::FromArgb(255, 43, 217, 255)
        $eyePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 14, 53, 80), (3 * $s))
        $bEye = New-Object System.Drawing.SolidBrush($eyeC)
        $g.FillEllipse($bEye, 96 * $s, 118 * $s, 24 * $s, 32 * $s)
        $g.FillEllipse($bEye, 138 * $s, 118 * $s, 24 * $s, 32 * $s)
        $g.DrawEllipse($eyePen, 96 * $s, 118 * $s, 24 * $s, 32 * $s)
        $g.DrawEllipse($eyePen, 138 * $s, 118 * $s, 24 * $s, 32 * $s)
        $wBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $g.FillEllipse($wBrush, 101 * $s, 122 * $s, 8 * $s, 10 * $s)
        $g.FillEllipse($wBrush, 143 * $s, 122 * $s, 8 * $s, 10 * $s)
        $blush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 255, 158, 203))
        $g.FillEllipse($blush, 78 * $s, 162 * $s, 18 * $s, 10 * $s)
        $g.FillEllipse($blush, 162 * $s, 162 * $s, 18 * $s, 10 * $s)
    }

    $g.Dispose()
    return $bmp
}

function Save-Ico($bmp, [string]$path) {
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $png = $ms.ToArray()
    $ms.Dispose()
    $fs = [System.IO.File]::Create($path)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([uint16]0)   # reserved
    $bw.Write([uint16]1)   # type: icon
    $bw.Write([uint16]1)   # count
    $bw.Write([byte]0)     # width  (0 = 256)
    $bw.Write([byte]0)     # height (0 = 256)
    $bw.Write([byte]0)     # colors
    $bw.Write([byte]0)     # reserved
    $bw.Write([uint16]1)   # planes
    $bw.Write([uint16]32)  # bpp
    $bw.Write([uint32]$png.Length)
    $bw.Write([uint32]22)  # offset of image data
    $bw.Write($png)
    $bw.Close()
}

if (-not $OutDir) { $OutDir = Join-Path (Split-Path $PSScriptRoot -Parent) "assets" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$portrait = Join-Path (Split-Path $PSScriptRoot -Parent) "pet\portrait.png"
$bmp = New-IconBitmap 256 $portrait
Save-Ico $bmp (Join-Path $OutDir "爱弥斯.ico")
$bmp.Save((Join-Path $OutDir "爱弥斯.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "assets generated: 爱弥斯.ico / 爱弥斯.png"
