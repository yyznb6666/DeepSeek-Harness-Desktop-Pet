# ============================================================================
#  爱弥斯桌宠  v1.0
#  鸣潮角色「爱弥斯」(粉发赛博幽灵) 同人 Q 版桌宠 —— DeepSeek Harness 桌面版专用
#
#  用法:
#    powershell -NoProfile -ExecutionPolicy Bypass -STA -File "爱弥斯桌宠.ps1"
#    -HarnessUrl http://127.0.0.1:3080   # 桌宠"打开 Harness"菜单使用的地址
#    -Snapshot <png路径>                 # 只渲染一帧保存 PNG 后退出(画师调试用)
#    -X -Y                               # 指定初始位置(默认屏幕右下角)
#
#  零外部依赖: 仅用 Windows 自带 .NET / WPF / WinForms。
# ============================================================================

param(
    [string]$HarnessUrl = "http://127.0.0.1:3080",
    [switch]$OpenHarness,
    [switch]$NoTaskWatch,
    [string]$Snapshot = "",
    [string]$Mood = "happy",
    [int]$X = -1,
    [int]$Y = -1,
    [int]$ParentPid = 0
)

$ErrorActionPreference = "Stop"

# 防止重复实例(同名互斥量)
try {
    $script:petMutex = New-Object System.Threading.Mutex($false, "EmisPet_DeepSeekHarness_DSH")
    if (-not $script:petMutex.WaitOne(0)) {
        if ($Snapshot) { Write-Host "已有一个爱弥斯桌宠在运行，快照请求被忽略。"; exit 0 }
        Write-Host "已有一个爱弥斯桌宠在运行。"
        exit 0
    }
} catch { }

# 加载 WPF / WinForms 程序集
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================== 基础工具 ===================================
function New-Color([string]$hex, [double]$alpha = 1) {
    $c = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    $c.A = [byte]([math]::Round($alpha * 255))
    return $c
}
function New-Solid([string]$hex, [double]$alpha = 1) {
    $b = New-Object System.Windows.Media.SolidColorBrush
    $b.Color = New-Color $hex $alpha
    $b.Freeze()
    return $b
}
function New-LG([string]$hex1, [string]$hex2, [switch]$Vertical, [double]$a1 = 1, [double]$a2 = 1) {
    $b = New-Object System.Windows.Media.LinearGradientBrush
    $b.StartPoint = New-Object System.Windows.Point(0, 0)
    if ($Vertical) {
        $b.EndPoint = New-Object System.Windows.Point(0, 1)
    } else {
        $b.EndPoint = New-Object System.Windows.Point(1, 0)
    }
    $b.GradientStops.Add((New-Object System.Windows.Media.GradientStop((New-Color $hex1 $a1), 0))) | Out-Null
    $b.GradientStops.Add((New-Object System.Windows.Media.GradientStop((New-Color $hex2 $a2), 1))) | Out-Null
    $b.Freeze()
    return $b
}
function New-Radial([string]$hexIn, [string]$hexOut, [double]$aIn = 1, [double]$aOut = 1) {
    $b = New-Object System.Windows.Media.RadialGradientBrush
    $b.GradientStops.Add((New-Object System.Windows.Media.GradientStop((New-Color $hexIn $aIn), 0))) | Out-Null
    $b.GradientStops.Add((New-Object System.Windows.Media.GradientStop((New-Color $hexOut $aOut), 1))) | Out-Null
    $b.Freeze()
    return $b
}
function Add-ToCanvas($canvas, $el, $x, $y) {
    $null = $canvas.Children.Add($el)
    [System.Windows.Controls.Canvas]::SetLeft($el, $x)
    [System.Windows.Controls.Canvas]::SetTop($el, $y)
}
function New-Ellipse($cx, $cy, $rx, $ry, $fill, $stroke = $null, $sw = 1.0, $op = 1.0) {
    $e = New-Object System.Windows.Shapes.Ellipse
    $e.Width = $rx * 2; $e.Height = $ry * 2
    if ($fill) { $e.Fill = $fill }
    if ($stroke) { $e.Stroke = $stroke; $e.StrokeThickness = $sw }
    $e.Opacity = $op
    $e.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
    Add-ToCanvas $script:canvas $e ($cx - $rx) ($cy - $ry)
    return $e
}
function New-Path([string]$data, $fill = $null, $stroke = $null, $sw = 1.0, $op = 1.0) {
    $p = New-Object System.Windows.Shapes.Path
    $p.Data = [System.Windows.Media.Geometry]::Parse($data)
    if ($fill) { $p.Fill = $fill }
    if ($stroke) { $p.Stroke = $stroke; $p.StrokeThickness = $sw; $p.StrokeStartLineCap = "Round"; $p.StrokeEndLineCap = "Round"; $p.StrokeLineJoin = "Round" }
    $p.Opacity = $op
    $p.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
    $script:canvas.Children.Add($p) | Out-Null
    return $p
}
function New-Text($txt, $x, $y, $size, $color, $bold = $true, $op = 1.0) {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $txt
    $t.FontSize = $size
    $t.FontFamily = New-Object System.Windows.Media.FontFamily("Microsoft YaHei UI")
    $t.FontWeight = if ($bold) { [System.Windows.FontWeights]::Bold } else { [System.Windows.FontWeights]::Normal }
    $t.Foreground = $color
    $t.Opacity = $op
    Add-ToCanvas $script:canvas $t $x $y
    return $t
}

# ============================== 状态与台词 =================================
$script:state = "idle"      # idle | happy | sleep | angry | eat
$script:stateUntil = 0.0
$script:t = 0.0
$script:blinkIn = 2.5
$script:blinkTicks = 0
$script:heartT = -1.0
$script:orbT = -1.0
$script:lastLine = ""
$script:idleChatIn = (Get-Random -Minimum 30 -Maximum 60)
$script:bubbleUntil = 0.0
$script:feedLine = ""
$script:dragOn = $false
$script:moved = $false

# ---- 任务完成提醒(监听 Harness events.host 事件流) ----
$script:taskWatchAlive = $false
$script:taskWatchStarted = $false
$script:taskWatchCts = $null
$script:taskEventQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
$script:rootRunning = [System.Collections.Hashtable]::Synchronized(@{})
$script:subagentSessions = [System.Collections.Hashtable]::Synchronized(@{})
$script:lastTaskAlert = [datetime]::MinValue
$script:wsUrl = ""
$script:httpBase = ""
$script:notifyLog = Join-Path (Split-Path $PSScriptRoot -Parent) "logs\pet-notify.log"

$script:LINES = @{
    idle = @(
        "检测到宿主在线～能量＋100！",
        "我是粉毛赛博幽灵，不客气～",
        "热熔核心稳定运行中，放心～",
        "数据流好吵……陪我说说话嘛～",
        "盯着我看太久，会变成我的粉丝哦～",
        "想让我帮你调试代码吗？我可是超频版的AI！",
        "嘘——我在跟后台的幽灵朋友聊天呢。",
        "鸣潮的世界里，我可受欢迎了～",
        "这个窗口再往左一点，布局会更完美哦～",
        "今天也要元气满满地开工哦！",
        "需要我帮你盯着 DeepSeek Harness 吗？我在呢！"
    )
    praise = @(
        "嘿嘿，被你夸得有点飘～",
        "呜哇，能量过载啦！",
        "最喜欢你啦～（比心）",
        "赛博幽灵也会害羞的！",
        "被摸摸头了……好感度＋999"
    )
    pat = @(
        "呜哇，被摸头了，电流酥酥的～",
        "手感不错吧？我可是精心维护过的赛博毛发！",
        "再摸就要害羞到过载了啦！"
    )
    feed = @(
        "啊——呜！能量补充完毕～",
        "这是什么？超好吃！热熔核心都亮了！",
        "投喂成功！电量从 80% 涨到 100%！"
    )
    sleep = @(
        "Zzz……梦境数据流好美……",
        "别吵，我在给热熔核心充电……Zzz",
        "充电中，请勿打扰～"
    )
    wake = @(
        "谁在叫我？充电完成，满血复活！",
        "哈啊——睡得好香！谢谢宿主～"
    )
    angry = @(
        "喂喂喂！别把我拽来拽去！",
        "再乱动我，我就要放电了哦！",
        "我可是赛博幽灵，惹我生气后果很严重！"
    )
    greet = @(
        "爱弥斯，上线！今天也要一起加油哦～",
        "粉毛赛博幽灵前来报到！",
        "宿主你好，我是爱弥斯～请多指教！"
    )
    bye = @(
        "拜拜～我会在后台等你的！",
        "要记得常来看看我哦～"
    )
    taskdone = @(
        "任务完成啦！快去看看成果吧～",
        "叮——任务送达！本幽灵的雷达从不失手！",
        "热熔核心报告：任务结束，能量回满～",
        "宿主宿主！你的任务完成了，记得验收哦！"
    )
}

function Get-Line([string]$key) {
    $pool = $script:LINES[$key]
    $c = 0
    do {
        $pick = $pool | Get-Random
        $c++
    } while ($pick -eq $script:lastLine -and $c -lt 8)
    $script:lastLine = $pick
    return $pick
}

# ============================== 构建 Q 版爱弥斯 ============================
$script:win = $null
$script:canvas = $null
$script:E = @{}

function Initialize-Art {
    $script:canvas = New-Object System.Windows.Controls.Canvas
    $script:canvas.Width = 280
    $script:canvas.Height = 360
    $script:canvas.Background = [System.Windows.Media.Brushes]::Transparent
    $script:canvas.Cursor = [System.Windows.Input.Cursors]::Hand

    $CX = 140.0
    $P = New-Solid "#ffb0da"          # 主粉
    $P2 = New-Solid "#ff8cc6"         # 深粉
    $PINK = New-LG "#ffc3e2" "#ff8cc6" -Vertical
    $PINK2 = New-LG "#ffb6dc" "#ff8cc6" -Vertical
    $SKIN = New-Solid "#ffe9f0"
    $CYAN = New-Solid "#7df3ff"
    $CYAN2 = New-Solid "#37d9ff"
    $DARK = New-LG "#22305c" "#101a38" -Vertical
    $WHITE = New-Solid "#ffffff"

    # ---- 地面阴影 ----
    $script:E.shadow = New-Ellipse $CX 332 64 10 (New-Solid "#000000" 0.16)

    # ---- 粉紫光晕 ----
    $script:E.halo = New-Ellipse $CX 205 104 112 (New-Radial "#ff9fd8" "#ff9fd8" 0.30 0.0)

    # ---- 全息环(赛博元素) ----
    $ring = New-Ellipse $CX 175 116 44 $null (New-Solid "#7df3ff" 0.32) 2.0
    $ring.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection
    $ring.StrokeDashArray.Add(6.0); $ring.StrokeDashArray.Add(5.0)
    $ringT = New-Object System.Windows.Media.RotateTransform(-16, $CX, 175)
    $ring.RenderTransform = $ringT
    $script:E.ring = $ring; $script:E.ringT = $ringT

    # ---- 幽灵尾(程序生成, 波浪下摆) ----
    $tail = New-Object System.Windows.Shapes.Path
    $tail.Fill = New-LG "#ff9fd8" "#7df3ff" -Vertical 0.80 0.55
    $tail.Opacity = 0.92
    $script:canvas.Children.Add($tail) | Out-Null
    $script:E.tail = $tail

    # ---- 后发 ----
    $script:E.backHair = New-Ellipse $CX 158 78 80 $PINK

    # ---- 身体(机甲外套) ----
    $body = New-Object System.Windows.Shapes.Path
    $body.Data = [System.Windows.Media.Geometry]::Parse("M 96,222 C 96,214 100,210 110,208 L 170,208 C 180,210 184,214 184,222 L 188,240 C 189,254 182,262 172,262 L 108,262 C 98,262 91,254 92,240 Z")
    $body.Fill = $DARK
    $script:canvas.Children.Add($body) | Out-Null
    $script:E.body = $body

    # 粉色小领口
    $script:E.collar = New-Path "M 140,209 L 128,226 L 140,219 L 152,226 Z" $P2

    # 胸口热熔核心
    $script:E.coreGlow = New-Ellipse $CX 240 15 15 (New-Solid "#ff5fa8" 0.45)
    $script:E.core = New-Ellipse $CX 240 7.5 7.5 (New-Radial "#ffe9f6" "#ff5fa8")

    # 肩部青色能量条
    $stripL = New-Ellipse 104 216 15 3.4 $CYAN $null 0 0.85
    $stripR = New-Ellipse 176 216 15 3.4 $CYAN $null 0 0.85
    $script:E.stripL = $stripL; $script:E.stripR = $stripR

    # ---- 袖子 + 小手 ----
    $sleeveL = New-Object System.Windows.Shapes.Rectangle
    $sleeveL.Width = 24; $sleeveL.Height = 36; $sleeveL.RadiusX = 10; $sleeveL.RadiusY = 10
    $sleeveL.Fill = New-Solid "#1a2a52"
    $sleeveL.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.9)
    $sT = New-Object System.Windows.Media.RotateTransform(-16)
    $sleeveL.RenderTransform = $sT
    Add-ToCanvas $script:canvas $sleeveL 84 228
    $sleeveR = New-Object System.Windows.Shapes.Rectangle
    $sleeveR.Width = 24; $sleeveR.Height = 36; $sleeveR.RadiusX = 10; $sleeveR.RadiusY = 10
    $sleeveR.Fill = New-Solid "#1a2a52"
    $sleeveR.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.9)
    $sT2 = New-Object System.Windows.Media.RotateTransform(16)
    $sleeveR.RenderTransform = $sT2
    Add-ToCanvas $script:canvas $sleeveR 172 228
    $script:E.sleeveL = $sleeveL; $script:E.sleeveR = $sleeveR
    $script:E.handL = New-Ellipse 80 264 9 9 $SKIN
    $script:E.handR = New-Ellipse 200 264 9 9 $SKIN

    # ---- 脸 ----
    $script:E.face = New-Ellipse $CX 150 60 57 $SKIN

    # ---- 腮红 ----
    $blush = New-Solid "#ff9ecb" 0.50
    $script:E.blushL = New-Ellipse 106 176 11 6.5 $blush
    $script:E.blushR = New-Ellipse 174 176 11 6.5 $blush

    # ---- 刘海(程序生成: 顶部弧 + 锯齿下摆) ----
    $bang = New-Object System.Windows.Shapes.Path
    $bang.Fill = $PINK2
    $script:canvas.Children.Add($bang) | Out-Null
    $script:E.bang = $bang

    # ---- 侧发(双马尾感的长发) ----
    $tailL = New-Path "M 84,118 C 52,148 46,206 66,252 C 84,252 90,214 93,178 Z" $PINK2
    $tailR = New-Path "M 196,118 C 228,148 234,206 214,252 C 196,252 190,214 187,178 Z" $PINK2
    $tailLT = New-Object System.Windows.Media.RotateTransform(0, 82, 150)
    $tailRT = New-Object System.Windows.Media.RotateTransform(0, 198, 150)
    $tailL.RenderTransform = $tailLT
    $tailR.RenderTransform = $tailRT
    $script:E.tailL = $tailL; $script:E.tailR = $tailR
    $script:E.tailLT = $tailLT; $script:E.tailRT = $tailRT

    # ---- 呆毛 ----
    $script:E.ahoge = New-Path "M 138,80 Q 141,64 155,61 Q 148,71 152,75" $null $P2 3.4

    # ---- 发夹(青色能量晶片) ----
    $script:E.clipGlow = New-Ellipse 198 110 10 10 (New-Solid "#7df3ff" 0.40)
    $script:E.clip = New-Path "M 198,101 L 205,110 L 198,119 L 191,110 Z" $CYAN

    # ---- 眉毛 ----
    $browC = New-Solid "#c95a96"
    $script:E.browL = New-Path "M 97,141 Q 108,134 120,139" $null $browC 2.6
    $script:E.browR = New-Path "M 160,139 Q 172,134 183,141" $null $browC 2.6

    # ---- 眼睛(赛博青色发光眼) ----
    $iris = New-LG "#d6fbff" "#0b8fd6" -Vertical
    $eyeGlowC = New-Solid "#6ff0ff" 0.45
    $lidC = New-Solid "#d23f8f"
    $eyeRim = New-Solid "#0e3550"
    $script:E.eyeGlowL = New-Ellipse 108 158 17 19 $eyeGlowC
    $script:E.eyeGlowR = New-Ellipse 172 158 17 19 $eyeGlowC
    $script:E.irisL = New-Ellipse 108 158 13 16 $iris $eyeRim 2.0
    $script:E.irisR = New-Ellipse 172 158 13 16 $iris $eyeRim 2.0
    $script:E.hlL = New-Ellipse 102 150 4.6 5.8 $WHITE
    $script:E.hlR = New-Ellipse 166 150 4.6 5.8 $WHITE
    $script:E.hl2L = New-Ellipse 115 166 2.4 2.8 (New-Solid "#ffffff" 0.85)
    $script:E.hl2R = New-Ellipse 179 166 2.4 2.8 (New-Solid "#ffffff" 0.85)
    $script:E.lidL = New-Path "M 94,152 Q 108,144 122,152" $null $lidC 2.4
    $script:E.lidR = New-Path "M 158,152 Q 172,144 186,152" $null $lidC 2.4

    # 眼睛组(眨眼时整体压扁)
    $script:eyeGroup = New-Object System.Windows.Controls.Canvas
    $script:eyeGroupT = New-Object System.Windows.Media.ScaleTransform(1, 1, $CX, 158)
    $script:eyeGroup.RenderTransform = $script:eyeGroupT
    $script:canvas.Children.Add($script:eyeGroup) | Out-Null
    foreach ($n in @("eyeGlowL","eyeGlowR","irisL","irisR","hlL","hlR","hl2L","hl2R","lidL","lidR")) {
        $script:canvas.Children.Remove($script:E[$n]) | Out-Null
        $script:eyeGroup.Children.Add($script:E[$n]) | Out-Null
        [System.Windows.Controls.Canvas]::SetLeft($script:E[$n], [System.Windows.Controls.Canvas]::GetLeft($script:E[$n]))
        [System.Windows.Controls.Canvas]::SetTop($script:E[$n], [System.Windows.Controls.Canvas]::GetTop($script:E[$n]))
    }

    # ---- 嘴 ----
    $mouthC = New-Solid "#e2578f"
    $script:E.mouthSmile = New-Path "M 128,186 Q 140,195 152,186" $null $mouthC 3.2
    $script:E.mouthOpen = New-Ellipse 140 189 6.5 7.5 $mouthC
    $script:E.mouthPout = New-Path "M 132,191 Q 140,183 148,191" $null $mouthC 3.0

    # ---- Zzz ----
    $script:E.zzz = New-Text "Zzz" 212 96 24 $CYAN $true 0.85
    $script:E.zzz.Visibility = "Collapsed"
    $script:zzzT = New-Object System.Windows.Media.TranslateTransform(0, 0)
    $script:E.zzz.RenderTransform = $script:zzzT

    # ---- 星星闪光 ----
    $sparkFills = @($WHITE, (New-Solid "#aef6ff"), $WHITE, (New-Solid "#ffe3f2"))
    $sparkPos = @(@(58,118), @(228,84), @(44,232), @(238,196))
    $sparkSize = @(8, 6, 5, 7)
    $script:sparks = @()
    for ($i = 0; $i -lt 4; $i++) {
        $s = New-Object System.Windows.Shapes.Path
        $sz = $sparkSize[$i]
        $s.Data = [System.Windows.Media.Geometry]::Parse("M 0,-$sz L $($sz*0.38),-$($sz*0.38) L $sz,0 L $($sz*0.38),$($sz*0.38) L 0,$sz L -$($sz*0.38),$($sz*0.38) L -$sz,0 L -$($sz*0.38),-$($sz*0.38) Z")
        $s.Fill = $sparkFills[$i]
        $s.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
        $script:canvas.Children.Add($s) | Out-Null
        [System.Windows.Controls.Canvas]::SetLeft($s, $sparkPos[$i][0])
        [System.Windows.Controls.Canvas]::SetTop($s, $sparkPos[$i][1])
        $script:sparks += , @($s, (Get-Random -Minimum 0 -Maximum 6.28), (Get-Random -Minimum 0.5 -Maximum 1.7))
    }

    # ---- 爱心(摸头特效) ----
    $heartData = "M 0,3 C -7,-4 -13,-1 -11,6 C -9,12 0,16 0,16 C 0,16 9,12 11,6 C 13,-1 7,-4 0,3 Z"
    $heartC = New-Solid "#ff6fb5"
    $script:hearts = @()
    foreach ($hp in @(@(70,128,10), @(98,104,7), @(58,92,5))) {
        $h = New-Object System.Windows.Shapes.Path
        $h.Data = [System.Windows.Media.Geometry]::Parse($heartData)
        $h.Fill = $heartC
        $h.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
        $h.Visibility = "Collapsed"
        $script:canvas.Children.Add($h) | Out-Null
        [System.Windows.Controls.Canvas]::SetLeft($h, $hp[0] - $hp[2])
        [System.Windows.Controls.Canvas]::SetTop($h, $hp[1] - $hp[2])
        $h.Width = $hp[2] * 2; $h.Height = $hp[2] * 2
        $st = New-Object System.Windows.Media.ScaleTransform(0.2, 0.2, 0, 0)
        $h.RenderTransform = $st
        $script:hearts += , @($h, $st)
    }

    # ---- 能量球(喂食特效) ----
    $script:E.orb = New-Ellipse 250 180 14 14 (New-Radial "#ffffff" "#7df3ff")
    $script:E.orb.Visibility = "Collapsed"
    $script:E.orbGlow = New-Ellipse 250 180 22 22 (New-Solid "#7df3ff" 0.35)
    $script:E.orbGlow.Visibility = "Collapsed"

    # ---- 对话框 ----
    $bubble = New-Object System.Windows.Controls.Border
    $bubble.MaxWidth = 252
    $bubble.Background = New-Solid "#16203a" 0.93
    $bubble.BorderBrush = New-Solid "#7df3ff" 0.9
    $bubble.BorderThickness = New-Object System.Windows.Thickness(1.4)
    $bubble.CornerRadius = New-Object System.Windows.CornerRadius(14)
    $bubble.Padding = New-Object System.Windows.Thickness(12, 9, 12, 9)
    $bubble.Opacity = 0
    $bubble.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{ Color = [System.Windows.Media.Color]::FromArgb(120, 0, 160, 220); BlurRadius = 12; ShadowDepth = 0; Opacity = 0.6 }
    $bubbleText = New-Object System.Windows.Controls.TextBlock
    $bubbleText.FontSize = 13
    $bubbleText.FontFamily = New-Object System.Windows.Media.FontFamily("Microsoft YaHei UI")
    $bubbleText.Foreground = New-Solid "#eaf6ff"
    $bubbleText.TextWrapping = "Wrap"
    $bubbleText.Text = ""
    $bubble.Child = $bubbleText
    Add-ToCanvas $script:canvas $bubble 14 8
    $script:E.bubble = $bubble; $script:E.bubbleText = $bubbleText

    # ---- 初始状态 ----
    $script:E.mouthOpen.Visibility = "Collapsed"
    $script:E.mouthPout.Visibility = "Collapsed"
    Update-Tail 0
    Update-Bangs

    # ---- 立绘模式: 若存在 pet/portrait.png 则用真实立绘替代矢量 Q 版 ----
    $script:portraitPath = Join-Path $PSScriptRoot "portrait.png"
    if (Test-Path $script:portraitPath) {
        try {
            $bi = New-Object System.Windows.Media.Imaging.BitmapImage
            $bi.BeginInit()
            $bi.UriSource = (New-Object System.Uri($script:portraitPath))
            $bi.CacheOption = "OnLoad"
            $bi.EndInit()
            $img = New-Object System.Windows.Controls.Image
            $img.Source = $bi
            $img.Stretch = "Uniform"
            $img.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
            # 按原始宽高比缩放, 底部对齐(脚落在阴影上), 水平居中
            $maxW = 260.0
            $maxH = 310.0
            $scale = [Math]::Min($maxW / $bi.PixelWidth, $maxH / $bi.PixelHeight)
            $dw = [Math]::Round($bi.PixelWidth * $scale)
            $dh = [Math]::Round($bi.PixelHeight * $scale)
            $img.Width = $dw
            $img.Height = $dh
            $lx = [Math]::Round((280 - $dw) / 2)
            $ty = 352 - $dh
            Add-ToCanvas $script:canvas $img $lx $ty
            # 隐藏矢量 Q 版本体, 保留氛围特效(光晕/全息环/星光/阴影/对话框)
            foreach ($ch in @($script:canvas.Children)) { $ch.Visibility = "Collapsed" }
            $img.Visibility = "Visible"
            $script:E.halo.Visibility = "Visible"
            $script:E.ring.Visibility = "Visible"
            $script:E.shadow.Visibility = "Visible"
            $script:E.bubble.Visibility = "Visible"
            foreach ($sp in $script:sparks) { $sp[0].Visibility = "Visible" }
            $script:portraitImg = $img
            Write-Host "立绘模式: 使用 $($script:portraitPath) ($($bi.PixelWidth)x$($bi.PixelHeight) -> ${dw}x${dh})"
        } catch {
            Write-Host "立绘加载失败, 回退到矢量 Q 版: $($_.Exception.Message)"
        }
    }
}

# 生成刘海路径: 顶部圆弧 + 六个锯齿下摆
function Update-Bangs {
    $CX = 140.0
    $top = 78.0
    $left = 82.0
    $right = 198.0
    $baseY = 150.0
    $pts = @()
    # 顶部: 从左上到右上, 覆盖头顶
    $d = "M $left,$baseY"
    $d += " C $($left-2),$($top+14) $($left+18),$top $CX,$top"
    $d += " C $($right-18),$top $($right+2),$($top+14) $right,$baseY"
    # 锯齿下摆: 从右往左
    $n = 6
    for ($i = 0; $i -lt $n; $i++) {
        $x0 = $right - ($i * ($right - $left) / $n)
        $x1 = $right - (($i + 1) * ($right - $left) / $n)
        $cy = $baseY - (10 + (($i % 2) * 6))
        $off = if ($i % 2 -eq 0) { -6 } else { 6 }
        $mx = (($x0 + $x1) / 2) + $off
        $d += " Q $mx,$cy $x1,$baseY"
    }
    $d += " Z"
    $script:E.bang.Data = [System.Windows.Media.Geometry]::Parse($d)
}

# 生成幽灵尾路径(带波浪下摆)
function Update-Tail([double]$t) {
    $phase = $t * 3.2
    $x0 = 96.0; $x1 = 184.0
    $top = 230.0
    $bot = 322.0
    $n = 9
    $d = "M $x0,$($top+18)"
    $d += " C $($x0-6),$($top+34) $($x0-2),$($top+60) $($x0+10),$($top+84)"
    $d += " L $($x1-10),$($top+84)"
    $d += " C $($x1+2),$($top+60) $($x1+6),$($top+34) $x1,$($top+18)"
    # 波浪下摆
    for ($i = 0; $i -lt $n; $i++) {
        $px = $x1 - ($i + 0.5) * (($x1 - $x0) / $n)
        $py = $bot + [math]::Sin($phase + $i * 1.15) * 7
        $nx = $x1 - ($i + 1) * (($x1 - $x0) / $n)
        $d += " Q $px,$py $nx,$bot"
    }
    $d += " Z"
    $script:E.tail.Data = [System.Windows.Media.Geometry]::Parse($d)
}

# ============================== 表情与行为 =================================
function Set-Face([string]$mode) {
    # mode: normal | happy | sleep | angry
    $smile = $script:E.mouthSmile; $open = $script:E.mouthOpen; $pout = $script:E.mouthPout
    $smile.Visibility = "Collapsed"; $open.Visibility = "Collapsed"; $pout.Visibility = "Collapsed"
    # 非睡眠状态下眼睛始终可见
    foreach ($n in @("irisL","irisR","hlL","hlR","hl2L","hl2R","lidL","lidR","eyeGlowL","eyeGlowR")) {
        $script:E[$n].Visibility = "Visible"
    }
    switch ($mode) {
        "happy" { $open.Visibility = "Visible"; $script:E.blushL.Opacity = 0.85; $script:E.blushR.Opacity = 0.85 }
        "angry" { $pout.Visibility = "Visible"; $script:E.blushL.Opacity = 0.5; $script:E.blushR.Opacity = 0.5 }
        "sleep" {
            $smile.Visibility = "Visible"
            foreach ($n in @("irisL","irisR","hlL","hlR","hl2L","hl2R")) { $script:E[$n].Visibility = "Collapsed" }
            $script:E.lidL.Visibility = "Collapsed"; $script:E.lidR.Visibility = "Collapsed"
            $script:E.eyeGlowL.Visibility = "Collapsed"; $script:E.eyeGlowR.Visibility = "Collapsed"
            $script:E.blushL.Opacity = 0.5; $script:E.blushR.Opacity = 0.5
        }
        default {
            $smile.Visibility = "Visible"
            $script:E.blushL.Opacity = 0.5; $script:E.blushR.Opacity = 0.5
        }
    }
}

function Set-Bubble([string]$text, [double]$seconds = 3.8) {
    $script:E.bubbleText.Text = $text
    $script:E.bubble.Measure([System.Windows.Size]::new(252, 600))
    $script:E.bubble.Opacity = 1
    $script:bubbleUntil = $script:t + $seconds
}

function Set-State([string]$s, [double]$dur = 0) {
    $script:state = $s
    $script:stateUntil = $script:t + $dur
    switch ($s) {
        "idle" { Set-Face "normal" }
        "happy" { Set-Face "happy" }
        "sleep" { Set-Face "sleep"; $script:E.zzz.Visibility = "Visible" }
        "angry" { Set-Face "angry" }
        "eat" { Set-Face "happy" }
    }
    if ($s -ne "sleep") { $script:E.zzz.Visibility = "Collapsed" }
}

function React([string]$kind) {
    switch ($kind) {
        "praise" {
            Set-State "happy" 1.6
            Set-Bubble (Get-Line "praise")
            $script:heartT = $script:t + 1.2
        }
        "pat" {
            Set-State "happy" 1.8
            Set-Bubble (Get-Line "pat")
            $script:heartT = $script:t + 1.6
        }
        "feed" {
            Set-State "eat" 1.9
            $script:orbT = $script:t + 0.0
            $script:E.orb.Visibility = "Visible"; $script:E.orbGlow.Visibility = "Visible"
            [System.Windows.Controls.Canvas]::SetLeft($script:E.orb, 236)
            [System.Windows.Controls.Canvas]::SetTop($script:E.orb, 168)
            [System.Windows.Controls.Canvas]::SetLeft($script:E.orbGlow, 228)
            [System.Windows.Controls.Canvas]::SetTop($script:E.orbGlow, 160)
            $script:feedLine = Get-Line "feed"
        }
        "sleep" {
            Set-State "sleep"
            Set-Bubble (Get-Line "sleep") 4.5
        }
        "wake" {
            Set-State "happy" 1.4
            Set-Bubble (Get-Line "wake")
        }
        "angry" {
            Set-State "angry" 1.5
            Set-Bubble (Get-Line "angry")
        }
        "taskdone" {
            Set-State "happy" 2.2
            $script:heartT = $script:t + 1.6
        }
        "click" {
            $r = Get-Random -Minimum 1 -Maximum 100
            if ($r -lt 40) { React "praise" }
            elseif ($r -lt 70) { React "pat" }
            else {
                Set-State "happy" 1.2
                Set-Bubble (Get-Line "idle")
            }
        }
    }
}

# ============================== 动画主循环 =================================
function Start-Loop {
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(33)
    $timer.Add_Tick({
        $script:t += 0.033
        $t = $script:t
        $CX = 140.0

        # ---- 任务完成提醒(消费事件队列) ----
        while ($script:taskEventQueue.Count -gt 0) {
            $ev = $script:taskEventQueue.Dequeue()
            if ($ev -eq "done") { Notify-TaskDone }
        }

        # ---- 待机呼吸/摇摆 ----
        $bob = [math]::Sin($t * 2.4) * 4.5
        $sway = [math]::Sin($t * 1.05) * 1.6
        if ($script:state -eq "sleep") { $bob = [math]::Sin($t * 1.0) * 2.2 }
        $rootT.X = $sway; $rootT.Y = $bob

        # ---- 侧发与呆毛的微风 ----
        $wa = [math]::Sin($t * 1.8) * 3.0
        $script:E.tailLT.Angle = $wa
        $script:E.tailRT.Angle = -$wa

        # ---- 全息环旋转 ----
        $script:E.ringT.Angle = ($script:E.ringT.Angle + 0.35) % 360

        # ---- 眨眼 ----
        if ($script:state -ne "sleep") {
            $script:blinkIn -= 0.033
            if ($script:blinkIn -le 0) { $script:blinkTicks = 2; $script:blinkIn = (Get-Random -Minimum 2.2 -Maximum 4.8) }
            if ($script:blinkTicks -gt 0) { $script:blinkTicks--; $script:eyeGroupT.ScaleY = 0.1 } else { $script:eyeGroupT.ScaleY = 1 }
        }

        # ---- 幽灵尾波浪 ----
        Update-Tail $t

        # ---- 星星闪烁 ----
        for ($i = 0; $i -lt $script:sparks.Count; $i++) {
            $sp = $script:sparks[$i]
            $o = 0.35 + 0.65 * ([math]::Sin($t * $sp[2] + $sp[1]) + 1) / 2
            $sp[0].Opacity = $o
            $rot = New-Object System.Windows.Media.RotateTransform(($t * 30 + $i * 45) % 360)
            $sp[0].RenderTransform = $rot
        }

        # ---- 状态计时 ----
        if ($script:state -ne "idle" -and $script:state -ne "sleep" -and $t -ge $script:stateUntil) {
            Set-State "idle"
        }
        if ($script:state -eq "eat" -and $script:orbT -ge 0) {
            $p = [math]::Min(1, ($t - $script:orbT) / 1.5)
            $e = 1 - [math]::Pow(1 - $p, 3)
            $ox = 236 + (140 - 236) * $e
            $oy = 168 + (196 - 168) * $e
            [System.Windows.Controls.Canvas]::SetLeft($script:E.orb, $ox - 14)
            [System.Windows.Controls.Canvas]::SetTop($script:E.orb, $oy - 14)
            [System.Windows.Controls.Canvas]::SetLeft($script:E.orbGlow, $ox - 22)
            [System.Windows.Controls.Canvas]::SetTop($script:E.orbGlow, $oy - 22)
            if ($p -ge 1) {
                $script:E.orb.Visibility = "Collapsed"; $script:E.orbGlow.Visibility = "Collapsed"
                $script:orbT = -1
                Set-State "happy" 1.6
                Set-Bubble $script:feedLine
            }
        }

        # ---- 爱心动画 ----
        if ($script:heartT -ge 0) {
            $hp = 1 - [math]::Min(1, ($script:heartT - $t) / 1.2)
            if ($hp -le 1) {
                for ($i = 0; $i -lt $script:hearts.Count; $i++) {
                    $h = $script:hearts[$i][0]; $st = $script:hearts[$i][1]
                    $h.Visibility = "Visible"
                    $rise = $hp * 26 + $i * 6
                    [System.Windows.Controls.Canvas]::SetTop($h, 104 - $hp * 26 - $i * 6)
                    $s = 0.3 + $hp * 1.1
                    $st.ScaleX = $s; $st.ScaleY = $s
                    $h.Opacity = [math]::Max(0, 1 - $hp * 1.2)
                }
            }
            if ($t -ge $script:heartT) {
                $script:heartT = -1
                foreach ($h in $script:hearts) { $h[0].Visibility = "Collapsed" }
            }
        }

        # ---- 睡眠 Zzz ----
        if ($script:state -eq "sleep") {
            $zp = ($t * 1.2) % 1
            $script:zzzT.Y = -($zp * 26)
            $script:E.zzz.Opacity = 0.9 * (1 - $zp) + 0.1
        }

        # ---- 对话框自动隐藏 ----
        if ($script:bubbleUntil -gt 0 -and $t -ge $script:bubbleUntil) {
            $script:E.bubble.Opacity = 0
            $script:bubbleUntil = 0
        }

        # ---- 随机闲聊 ----
        if ($script:state -eq "idle") {
            $script:idleChatIn -= 0.033
            if ($script:idleChatIn -le 0) {
                $script:idleChatIn = (Get-Random -Minimum 35 -Maximum 75)
                Set-Bubble (Get-Line "idle")
            }
        }
    })
    $timer.Start()
    return $timer
}

# ============================== 鼠标交互 ==================================
function Wire-Events {
    $script:canvas.Add_MouseLeftButtonDown({
        param($s, $e)
        $p = $e.GetPosition($script:win)
        $script:dragOn = $true
        $script:moved = $false
        $script:dragStart = @{ X = $p.X; Y = $p.Y }
        $script:winStart = @{ X = $script:win.Left; Y = $script:win.Top }
        $e.Handled = $true
    })
    $script:canvas.Add_MouseMove({
        param($s, $e)
        if ($script:dragOn) {
            $p = $e.GetPosition($script:win)
            $dx = $p.X - $script:dragStart.X
            $dy = $p.Y - $script:dragStart.Y
            if ([math]::Abs($dx) -gt 5 -or [math]::Abs($dy) -gt 5) {
                if (-not $script:moved) {
                    $script:moved = $true
                    # 拖动动作开始: 若正在睡觉则保持, 否则不打断
                }
                $script:win.Left = $script:winStart.X + $dx
                $script:win.Top = $script:winStart.Y + $dy
            }
        }
    })
    $script:canvas.Add_MouseLeftButtonUp({
        param($s, $e)
        if ($script:dragOn) {
            $script:dragOn = $false
            if (-not $script:moved) {
                if ($script:state -eq "sleep") { React "wake" }
                else { React "click" }
            }
        }
    })
    $script:canvas.Add_MouseLeave({
        # 拖动快速甩动 → 生气
        if ($script:dragOn) {
            $script:dragOn = $false
            $script:moved = $true
            if ($script:state -ne "sleep") { React "angry" }
        }
    })
    $script:canvas.Add_MouseRightButtonUp({
        param($s, $e)
        # 交给 ContextMenu 处理
    })
}

function Build-Menu {
    $menu = New-Object System.Windows.Controls.ContextMenu
    function Add-MenuItem($header, $handler) {
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = $header
        $mi.FontFamily = New-Object System.Windows.Media.FontFamily("Microsoft YaHei UI")
        $mi.FontSize = 13
        $mi.Add_Click($handler)
        $menu.Items.Add($mi) | Out-Null
    }
    Add-MenuItem "✨ 夸夸我" { React "praise" }
    Add-MenuItem "💗 摸摸头" { React "pat" }
    Add-MenuItem "🍡 喂食" { React "feed" }
    Add-MenuItem "🌙 休息 / 起床" { if ($script:state -eq "sleep") { React "wake" } else { React "sleep" } }
    Add-MenuItem "🧹 回到屏幕右下角" { Reset-Position }
    Add-MenuItem "🖥️ 打开 DeepSeek Harness" { Open-Harness }
    Add-MenuItem "🎨 关于" { Set-Bubble "爱弥斯 v1.0 —— 鸣潮「粉毛赛博幽灵」同人 Q 版桌宠, 专为 DeepSeek Harness 打造 ♡" 6 }
    $menu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
    Add-MenuItem "🚪 退出" { Exit-App }
    $script:canvas.ContextMenu = $menu
}

function Reset-Position {
    $wa = [System.Windows.SystemParameters]::WorkArea
    $script:win.Left = $wa.Right - $script:win.Width - 16
    $script:win.Top = $wa.Bottom - $script:win.Height - 8
}

function Open-Harness {
    $edge = @("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", "C:\Program Files\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($edge) {
        $prof = Join-Path (Split-Path $PSScriptRoot -Parent) ".edge-profile"
        $args = @("--app=$script:HarnessUrl", "--window-size=1500,950", "--window-position=60,30", "--user-data-dir=`"$prof`"", "--no-first-run", "--no-default-browser-check")
        Start-Process $edge -ArgumentList $args | Out-Null
    } else {
        Start-Process $script:HarnessUrl | Out-Null
    }
}

# ============================== 任务完成提醒 =================================
function Log-PetEvent([string]$msg) {
    try {
        $dir = Split-Path $script:notifyLog -Parent
        if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Force -Path $dir }
        Add-Content -Path $script:notifyLog -Value ("{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) -Encoding UTF8
    } catch { }
}

function Get-HarnessSessionList {
    try {
        $body = @{ type = "client-request"; rpcId = [guid]::NewGuid().ToString(); method = "session.list"; payload = @{} } | ConvertTo-Json -Depth 5
        $r = Invoke-RestMethod -Uri "$script:httpBase/api/session.list" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 6
        if ($r.result.ok) { return @($r.result.value.items) }
        return $null
    } catch {
        return $null
    }
}

function Notify-TaskDone {
    $now = [datetime]::Now
    if (($now - $script:lastTaskAlert).TotalSeconds -lt 6) { return }
    $script:lastTaskAlert = $now
    Log-PetEvent "任务完成提醒触发"
    try {
        # 窗口若被隐藏则自动唤起
        if (-not $script:win.IsVisible) { $script:win.Show(); $script:win.Topmost = $true }
        React "taskdone"
        Set-Bubble (Get-Line "taskdone") 6
    } catch { }
    try { $script:tray.ShowBalloonTip(3000, "爱弥斯桌宠", (Get-Line "taskdone"), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch { }
}

# 后台监听(独立 Runspace): HTTP 基线 + WebSocket 实时事件流, 检测主会话任务完成
function Start-TaskWatcher {
    if ($script:taskWatchStarted -or $Snapshot) { return }
    try {
        $u = New-Object System.Uri($HarnessUrl)
        $script:httpBase = "http://$($u.Host):$($u.Port)"
        $script:wsUrl = "ws://$($u.Host):$($u.Port)/api/events.host"
    } catch { return }
    $script:taskWatchStarted = $true
    $script:taskWatchAlive = $true
    $script:taskWatchCts = New-Object System.Threading.CancellationTokenSource
    $script:taskWatchRunspace = [runspacefactory]::CreateRunspace()
    $script:taskWatchRunspace.ApartmentState = "MTA"
    $script:taskWatchRunspace.Open()
    $script:taskWatchPS = [powershell]::Create()
    $script:taskWatchPS.Runspace = $script:taskWatchRunspace
    $null = $script:taskWatchPS.AddScript({
        param($cts, $queue, $rootRunning, $subagentSessions, $logPath, $httpBase, $wsUrl)
        function Log-Line([string]$msg) {
            try { Add-Content -Path $logPath -Value ("{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) -Encoding UTF8 } catch { }
        }
        function Get-SessionList {
            try {
                $body = @{ type = "client-request"; rpcId = [guid]::NewGuid().ToString(); method = "session.list"; payload = @{} } | ConvertTo-Json -Depth 5
                $r = Invoke-RestMethod -Uri "$httpBase/api/session.list" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 6
                if ($r.result.ok) { return @($r.result.value.items) }
                return $null
            } catch { return $null }
        }
        Log-Line "监听线程启动"
        $backoff = 0
        while (-not $cts.IsCancellationRequested) {
            try {
                # 1) HTTP 基线: 会话列表(识别子代理会话, 记录当前运行状态)
                $items = Get-SessionList
                if ($null -ne $items) {
                    foreach ($s in $items) {
                        $sid = [string]$s.sessionId
                        if ($s.parentSessionId) { $subagentSessions[$sid] = $true }
                        if ($s.running -and -not $s.parentSessionId) { $rootRunning[$sid] = $true }
                    }
                    Log-Line ("基线会话: {0} 个, 运行中主会话: {1}" -f $items.Count, $rootRunning.Count)
                } else {
                    Log-Line "基线查询无结果(服务未就绪?)"
                }
                # 2) WebSocket 实时事件流
                $ws = New-Object System.Net.WebSockets.ClientWebSocket
                $null = $ws.ConnectAsync((New-Object System.Uri($wsUrl)), [System.Threading.CancellationToken]::None).GetAwaiter().GetResult()
                Log-Line "已连接 Harness 事件流: $wsUrl"
                $backoff = 0
                $buf = New-Object byte[] 262144
                $acc = New-Object System.Text.StringBuilder
                while (-not $cts.IsCancellationRequested -and $ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                    $seg = [System.ArraySegment[byte]]::new($buf)
                    $res = $ws.ReceiveAsync($seg, $cts.Token).GetAwaiter().GetResult()
                    if ($res.Count -gt 0) {
                        $null = $acc.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $res.Count))
                    }
                    if ($res.EndOfMessage) {
                        $txt = $acc.ToString()
                        $acc.Clear() | Out-Null
                        try {
                            $frame = $txt | ConvertFrom-Json
                            $pt = [string]$frame.payload.type
                            if ($pt -eq "host/session-added") {
                                $sid = [string]$frame.payload.sessionId
                                if ($frame.payload.parentSessionId) { $subagentSessions[$sid] = $true }
                            } elseif ($pt -eq "host/session-removed") {
                                $sid = [string]$frame.payload.sessionId
                                $null = $subagentSessions.Remove($sid)
                                $null = $rootRunning.Remove($sid)
                            } elseif ($pt -eq "host/session-status") {
                                $sid = [string]$frame.payload.sessionId
                                $running = [bool]$frame.payload.running
                                if ($subagentSessions.ContainsKey($sid)) { continue }
                                if ($running) {
                                    if (-not $rootRunning.ContainsKey($sid)) {
                                        $rootRunning[$sid] = $true
                                        Log-Line "任务开始: $sid"
                                    }
                                } else {
                                    if ($rootRunning.ContainsKey($sid)) {
                                        $null = $rootRunning.Remove($sid)
                                        Log-Line "任务完成: $sid"
                                        $queue.Enqueue("done")
                                    }
                                }
                            }
                        } catch { }
                    }
                    if ($res.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { break }
                }
                $ws.Dispose()
            } catch {
                # 断线或服务未启动, 退避后重连
                Log-Line "监听异常(将重连): $($_.Exception.Message)"
            }
            if (-not $cts.IsCancellationRequested) {
                $backoff = [Math]::Min(30, [Math]::Max(3, $backoff * 2))
                Start-Sleep -Seconds $backoff
            }
        }
        Log-Line "监听线程退出"
    })
    $null = $script:taskWatchPS.AddArgument($script:taskWatchCts)
    $null = $script:taskWatchPS.AddArgument($script:taskEventQueue)
    $null = $script:taskWatchPS.AddArgument($script:rootRunning)
    $null = $script:taskWatchPS.AddArgument($script:subagentSessions)
    $null = $script:taskWatchPS.AddArgument($script:notifyLog)
    $null = $script:taskWatchPS.AddArgument($script:httpBase)
    $null = $script:taskWatchPS.AddArgument($script:wsUrl)
    $script:taskWatchHandle = $script:taskWatchPS.BeginInvoke()
    Log-PetEvent "任务监听已启动"
}

# ============================== 托盘 ======================================
function Setup-Tray {
    $tray = New-Object System.Windows.Forms.NotifyIcon
    $icoPath = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\爱弥斯.ico"
    if (Test-Path $icoPath) { $tray.Icon = New-Object System.Drawing.Icon($icoPath) }
    else { $tray.Icon = [System.Drawing.SystemIcons]::Application }
    $tray.Text = "爱弥斯桌宠"
    $tray.Visible = $true

    $cms = New-Object System.Windows.Forms.ContextMenuStrip
    $cms.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    function Add-TrayItem($text, $handler) {
        $it = New-Object System.Windows.Forms.ToolStripMenuItem($text)
        $it.Add_Click($handler)
        $cms.Items.Add($it) | Out-Null
    }
    Add-TrayItem "显示 / 隐藏桌宠" {
        if ($script:win.IsVisible) { $script:win.Hide() } else { $script:win.Show(); $script:win.Topmost = $true }
    }
    Add-TrayItem "打开 DeepSeek Harness" { Open-Harness }
    Add-TrayItem "退出" { Exit-App }
    $tray.ContextMenuStrip = $cms
    $tray.Add_MouseDoubleClick({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if ($script:win.IsVisible) { $script:win.Hide() } else { $script:win.Show(); $script:win.Topmost = $true }
        }
    })
    try { $tray.ShowBalloonTip(1800, "爱弥斯桌宠", (Get-Line "greet"), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
    $script:tray = $tray
}

function Exit-App {
    $script:taskWatchAlive = $false
    try { if ($script:taskWatchCts) { $script:taskWatchCts.Cancel() } } catch { }
    try { $script:tray.Visible = $false; $script:tray.Dispose() } catch { }
    try { $script:petMutex.ReleaseMutex() } catch { }
    try { $script:win.Close() } catch { }
    try {
        if ([System.Windows.Application]::Current) { [System.Windows.Application]::Current.Shutdown() }
        else { [Environment]::Exit(0) }
    } catch { [Environment]::Exit(0) }
}

# ============================== 主流程 =====================================
Initialize-Art

# 快照模式: 渲染一帧存 PNG 后退出(用于画师迭代)
if ($Snapshot) {
    $script:canvas.Measure([System.Windows.Size]::new(280, 360))
    $script:canvas.Arrange([System.Windows.Rect]::new(0, 0, 280, 360))
    $script:canvas.UpdateLayout()
    Set-Face $Mood
    Update-Tail 1.2
    if ($Mood -eq "sleep") { $script:E.zzz.Visibility = "Visible" }
    $script:canvas.UpdateLayout()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(280, 360, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($script:canvas)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb)) | Out-Null
    $fs = [System.IO.File]::Create($Snapshot)
    $enc.Save($fs); $fs.Close()
    Write-Host "快照已保存: $Snapshot"
    exit 0
}

# 主窗口
$script:win = New-Object System.Windows.Window
$script:win.Title = "爱弥斯桌宠"
$script:win.Width = 280
$script:win.Height = 360
$script:win.WindowStyle = "None"
$script:win.AllowsTransparency = $true
$script:win.Background = [System.Windows.Media.Brushes]::Transparent
$script:win.Topmost = $true
$script:win.ShowInTaskbar = $false
$script:win.ResizeMode = "NoResize"
$script:win.ShowActivated = $false
$script:win.Content = $script:canvas

$rootT = New-Object System.Windows.Media.TranslateTransform(0, 0)
$script:canvas.RenderTransform = $rootT

# 初始位置: 屏幕右下角
if ($X -lt 0 -or $Y -lt 0) { Reset-Position } else { $script:win.Left = $X; $script:win.Top = $Y }

Wire-Events
Build-Menu
Setup-Tray
Set-State "idle"
$null = Start-Loop
if (-not $NoTaskWatch) { Start-TaskWatcher }

# ---- 宿主进程看门狗: 插件模式(ParentPid>0)下, 宿主(Harness)进程退出则桌宠自动退场 ----
if ($ParentPid -gt 0) {
    $watchdog = New-Object System.Windows.Threading.DispatcherTimer
    $watchdog.Interval = [TimeSpan]::FromSeconds(4)
    $watchdog.Add_Tick({
        try {
            $parent = Get-Process -Id $ParentPid -ErrorAction Stop
            if ($parent.HasExited) { throw "host exited" }
        } catch {
            Log-PetEvent "宿主进程(Harness)已退出, 桌宠自动退场"
            try { $watchdog.Stop() } catch { }
            Exit-App
        }
    })
    $watchdog.Start()
    Log-PetEvent "宿主看门狗已启动(PID=$ParentPid)"
}

$script:win.Add_Closed({ Exit-App })

$app = [System.Windows.Application]::new()
$app.Run($script:win) | Out-Null
