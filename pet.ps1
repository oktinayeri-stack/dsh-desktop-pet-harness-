#requires -version 5
# DeepSeek Harness 桌面桌宠（原生 WinForms 常驻窗口）
# - 始终置顶，浏览器最小化也留在桌面
# - 单击角色图换形象，拖拽移动，双击回默认位置
# - 底部输入框可直接和当前会话对话（流式显示回复）
# - 只要 DSH 终端(127.0.0.1:3080)在运行，桌宠就保持；终端退出后桌宠自动退出
param(
  [string]$ApiBase = "http://127.0.0.1:3080",
  [string]$BaseDir = "E:\download\dsh-desktop-pet"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 带原生投影的无边框窗口（CS_DROPSHADOW）
Add-Type -TypeDefinition @"
using System.Windows.Forms;
public class PetForm : Form {
    protected override CreateParams CreateParams {
        get {
            const int CS_DROPSHADOW = 0x00020000;
            var cp = base.CreateParams;
            cp.ClassStyle |= CS_DROPSHADOW;
            return cp;
        }
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

$FramesDir = Join-Path $BaseDir "frames-png"
$StateFile = Join-Path $BaseDir "pet-state.json"

# ============ 可复用的 RPC / 会话辅助 ============
function Invoke-Rpc {
  param([string]$Method, $Payload = @{})
  try {
    $env = @{ type = "client-request"; rpcId = [guid]::NewGuid().ToString(); method = $Method; payload = $Payload }
    $jsonBody = $env | ConvertTo-Json -Depth 20 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    $req = [System.Net.HttpWebRequest]::Create(("{0}/api/{1}" -f $ApiBase, $Method))
    $req.Method = "POST"
    $req.ContentType = "application/json; charset=utf-8"
    $req.ContentLength = $bytes.Length
    $req.Timeout = 15000
    $stream = $req.GetRequestStream()
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Close()
    $resp = $req.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
    $json = $reader.ReadToEnd()
    $reader.Close()
    $resp.Close()
    $obj = $json | ConvertFrom-Json
    return $obj.result
  } catch {
    return $null
  }
}

function Get-TargetSessionId {
  $r = Invoke-Rpc "session.list" @{}
  if (-not $r -or -not $r.ok) { return $null }
  $items = @($r.value.items)
  $nonBlank = @($items | Where-Object { -not $_.blank })
  if ($nonBlank.Count -gt 0) {
    $top = $nonBlank | Sort-Object updatedAt -Descending | Select-Object -First 1
    return $top.sessionId
  }
  if ($items.Count -gt 0) { return ($items | Sort-Object updatedAt -Descending | Select-Object -First 1).sessionId }
  return $null
}

function Get-AssistantState {
  param([string]$SessionId, [long]$AfterSeq = -1)
  $r = Invoke-Rpc "session.history" @{ sessionId = $SessionId; maxMessages = 40 }
  if (-not $r -or -not $r.ok) { return @{ finalSeq = [long]-1; finalText = $null; streamText = $null } }
  $finalSeq = [long]-1
  $finalText = $null
  $streamParts = New-Object System.Collections.Generic.List[string]
  foreach ($entry in @($r.value.events)) {
    $ev = $entry.event
    if ([long]$ev.seq -le $AfterSeq) { continue }
    if ($ev.type -eq "assistant/chunk") {
      $chunk = $ev.data.chunk
      if ($chunk.type -eq "text-delta" -and $chunk.text) { $streamParts.Add([string]$chunk.text) }
    }
    elseif ($ev.type -eq "assistant/message") {
      $parts = New-Object System.Collections.Generic.List[string]
      $content = $ev.data.message.content
      if ($content) {
        foreach ($block in @($content)) {
          if ($block.type -eq "text" -and $block.text) { $parts.Add([string]$block.text) }
        }
      }
      if ($parts.Count -gt 0) {
        $finalSeq = [long]$ev.seq
        $finalText = ($parts -join "`n")
      }
    }
  }
  $streamText = $null
  if ($streamParts.Count -gt 0) { $streamText = ($streamParts -join "") }
  return @{ finalSeq = $finalSeq; finalText = $finalText; streamText = $streamText }
}

# ============ 状态持久化 ============
function Read-State {
  if (Test-Path -LiteralPath $StateFile) {
    try { return (Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json) } catch {}
  }
  return $null
}
function Write-State {
  param($Index, [int]$X, [int]$Y, $SessionId)
  $o = [ordered]@{ index = $Index; x = $X; y = $Y; sessionId = $SessionId }
  $o | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding UTF8
}

# 圆角区域
function Set-RoundedRegion {
  param($Ctrl, [int]$Radius)
  if ($Ctrl.Width -le 0 -or $Ctrl.Height -le 0) { return }
  $d = $Radius * 2
  $right = $Ctrl.Width - $d
  $bottom = $Ctrl.Height - $d
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc(0, 0, $d, $d, 180, 90)
  $path.AddArc($right, 0, $d, $d, 270, 90)
  $path.AddArc($right, $bottom, $d, $d, 0, 90)
  $path.AddArc(0, $bottom, $d, $d, 90, 90)
  $path.CloseFigure()
  $Ctrl.Region = New-Object System.Drawing.Region($path)
  $path.Dispose()
}

# ============ 加载形象 ============
$frames = @(Get-ChildItem -LiteralPath $FramesDir -Filter *.png | Sort-Object Name | ForEach-Object { $_.FullName })
if ($frames.Count -eq 0) {
  [System.Windows.Forms.MessageBox]::Show("未找到形象图片：$FramesDir", "桌宠", 'OK', 'Error') | Out-Null
  exit 1
}

$st = Read-State
$idx = 0
if ($st -and $st.index -ge 0 -and $st.index -lt $frames.Count) { $idx = [int]$st.index }

# 运行时可变状态
$g = @{
  idx           = $idx
  dragging      = $false
  moved         = $false
  startScreen   = New-Object System.Drawing.Point(0, 0)
  startForm     = New-Object System.Drawing.Point(0, 0)
  sessionId     = $null
  beforeSeq     = [long]-1
  polling       = $false
  pollTicks     = 0
  deadCount     = 0
  everConnected = $false
  disposed      = $false
}

# ============ 主题色 ============
$cCard        = [System.Drawing.Color]::FromArgb(27, 27, 35)
$cPanel       = [System.Drawing.Color]::FromArgb(37, 37, 48)
$cInput       = [System.Drawing.Color]::FromArgb(46, 46, 60)
$cText        = [System.Drawing.Color]::FromArgb(233, 233, 240)
$cSub         = [System.Drawing.Color]::FromArgb(148, 148, 162)
$cAccent      = [System.Drawing.Color]::FromArgb(94, 110, 255)
$cAccentHover = [System.Drawing.Color]::FromArgb(116, 130, 255)
$cGreen       = [System.Drawing.Color]::FromArgb(46, 204, 113)
$cRed         = [System.Drawing.Color]::FromArgb(229, 72, 77)
$cWarn        = [System.Drawing.Color]::FromArgb(240, 180, 60)

$fontTitle = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$fontChat  = New-Object System.Drawing.Font("Microsoft YaHei UI", 11)
$fontInput = New-Object System.Drawing.Font("Microsoft YaHei UI", 11)
$fontSend  = New-Object System.Drawing.Font("Microsoft YaHei UI", 10.5)
$fontDot   = New-Object System.Drawing.Font("Microsoft YaHei UI", 8.5)

# ============ 布局（加大聊天框与字体） ============
$W      = 248
$pad    = 12
$headH  = 34
$imgSz  = 224
$imgX   = $pad
$imgY   = $headH
$chatH  = 104
$chatX  = $pad
$chatY  = $imgY + $imgSz + 8
$chatW  = $W - $pad * 2
$inH    = 36
$inY    = $chatY + $chatH + 8
$sendW  = 52
$sendX  = $W - $pad - $sendW
$inW    = $sendX - $pad - 6
$H      = $inY + $inH + $pad
$closeX = $W - $pad - 26
$closeW = 26
$dotX   = $closeX - 18

$form = New-Object PetForm
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.ClientSize = New-Object System.Drawing.Size($W, $H)
$form.BackColor = $cCard
$form.KeyPreview = $true

if ($st -and $st.x -ne $null -and $st.y -ne $null) {
  $sx = [int]$st.x; $sy = [int]$st.y
} else {
  $scr = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $sx = $scr.Right - $W - 24
  $sy = $scr.Bottom - $H - 24
}
$form.Location = New-Object System.Drawing.Point($sx, $sy)

# ---- 头部（标题 + 状态点 + 关闭按钮，可拖拽）----
$title = New-Object System.Windows.Forms.Label
$title.Text = "桌宠"
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(12, 7)
$title.ForeColor = $cText
$title.Font = $fontTitle
$title.BackColor = [System.Drawing.Color]::Transparent

$dot = New-Object System.Windows.Forms.Label
$dot.Text = "●"
$dot.AutoSize = $true
$dot.Location = New-Object System.Drawing.Point($dotX, 10)
$dot.ForeColor = $cSub
$dot.Font = $fontDot
$dot.BackColor = [System.Drawing.Color]::Transparent

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "✕"
$closeBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$closeBtn.FlatAppearance.BorderSize = 0
$closeBtn.FlatAppearance.MouseOverBackColor = $cRed
$closeBtn.FlatAppearance.MouseDownBackColor = $cRed
$closeBtn.BackColor = $cCard
$closeBtn.ForeColor = $cSub
$closeBtn.Font = $fontTitle
$closeBtn.Size = New-Object System.Drawing.Size($closeW, 26)
$closeBtn.Location = New-Object System.Drawing.Point($closeX, 4)
$closeBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$closeBtn.TabStop = $false

# ---- 角色图（透明背景 PNG，圆角，可点击换形象、可拖拽）----
$pic = New-Object System.Windows.Forms.PictureBox
$pic.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$pic.Size = New-Object System.Drawing.Size($imgSz, $imgSz)
$pic.Location = New-Object System.Drawing.Point($imgX, $imgY)
$pic.BackColor = $cCard
$pic.Cursor = [System.Windows.Forms.Cursors]::Hand
$pic.Image = [System.Drawing.Image]::FromFile($frames[$g.idx])
$pic.TabStop = $false

# ---- 聊天记录 ----
$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$log.WordWrap = $true
$log.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$log.Size = New-Object System.Drawing.Size($chatW, $chatH)
$log.Location = New-Object System.Drawing.Point($chatX, $chatY)
$log.BackColor = $cPanel
$log.ForeColor = $cText
$log.Font = $fontChat
$log.Text = "点一下角色换形象；在下面输入即可对话。"

# ---- 输入框 + 发送按钮 ----
$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$inputBox.Size = New-Object System.Drawing.Size($inW, $inH)
$inputBox.Location = New-Object System.Drawing.Point($pad, $inY)
$inputBox.BackColor = $cInput
$inputBox.ForeColor = $cText
$inputBox.Font = $fontInput

$send = New-Object System.Windows.Forms.Button
$send.Text = "发送"
$send.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$send.FlatAppearance.BorderSize = 0
$send.FlatAppearance.MouseOverBackColor = $cAccentHover
$send.FlatAppearance.MouseDownBackColor = $cAccent
$send.BackColor = $cAccent
$send.ForeColor = [System.Drawing.Color]::White
$send.Font = $fontSend
$send.Size = New-Object System.Drawing.Size($sendW, $inH)
$send.Location = New-Object System.Drawing.Point($sendX, $inY)
$send.Cursor = [System.Windows.Forms.Cursors]::Hand
$send.TabStop = $false

$form.Controls.Add($title)
$form.Controls.Add($dot)
$form.Controls.Add($closeBtn)
$form.Controls.Add($pic)
$form.Controls.Add($log)
$form.Controls.Add($inputBox)
$form.Controls.Add($send)

# 圆角：卡片本身 + 角色图 + 输入框 + 发送按钮 + 关闭按钮
Set-RoundedRegion $form 18
Set-RoundedRegion $pic 14
Set-RoundedRegion $log 12
Set-RoundedRegion $inputBox 12
Set-RoundedRegion $send 12
Set-RoundedRegion $closeBtn 8

# ============ 拖拽 / 点击换图 ============
function Drag-Down {
  $g.dragging = $true
  $g.moved = $false
  $g.startScreen = [System.Windows.Forms.Cursor]::Position
  $g.startForm = $form.Location
}
function Drag-Move {
  if (-not $g.dragging) { return }
  $cur = [System.Windows.Forms.Cursor]::Position
  $dx = $cur.X - $g.startScreen.X
  $dy = $cur.Y - $g.startScreen.Y
  if ([Math]::Abs($dx) + [Math]::Abs($dy) -gt 4) { $g.moved = $true }
  if ($g.moved) {
    $nx = $g.startForm.X + $dx
    $ny = $g.startForm.Y + $dy
    $form.Location = New-Object System.Drawing.Point($nx, $ny)
  }
}
function Drag-Up {
  if (-not $g.dragging) { return }
  $g.dragging = $false
  Write-State $g.idx $form.Left $form.Top $g.sessionId
}
function Pic-Up {
  if (-not $g.dragging) { return }
  $g.dragging = $false
  if (-not $g.moved) {
    $g.idx = ($g.idx + 1) % $frames.Count
    $old = $pic.Image
    try { $pic.Image = [System.Drawing.Image]::FromFile($frames[$g.idx]) } catch {}
    if ($old) { try { $old.Dispose() } catch {} }
  }
  Write-State $g.idx $form.Left $form.Top $g.sessionId
}

$pic.Add_MouseDown({ param($s, $e) Drag-Down })
$pic.Add_MouseMove({ param($s, $e) Drag-Move })
$pic.Add_MouseUp({ param($s, $e) Pic-Up })
$pic.Add_DoubleClick({
  $scr = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $rx = $scr.Right - $W - 24
  $ry = $scr.Bottom - $H - 24
  $form.Location = New-Object System.Drawing.Point($rx, $ry)
  Write-State $g.idx $form.Left $form.Top $g.sessionId
})

$title.Add_MouseDown({ param($s, $e) Drag-Down })
$title.Add_MouseMove({ param($s, $e) Drag-Move })
$title.Add_MouseUp({ param($s, $e) Drag-Up })

$closeBtn.Add_Click({ $form.Close() })

# ============ 发送消息 ============
function Send-Message {
  $text = $inputBox.Text.Trim()
  if ($text -eq "") { return }
  $inputBox.Text = ""

  $sid = $g.sessionId
  if (-not $sid) { $sid = Get-TargetSessionId }
  if (-not $sid) {
    $log.Text = "（没有可用的会话）"
    return
  }
  $g.sessionId = $sid
  Write-State $g.idx $form.Left $form.Top $sid

  $before = Get-AssistantState $sid
  $g.beforeSeq = [long]$before.finalSeq
  $g.pollTicks = 0

  $log.Text = ("你：" + $text)
  $log.AppendText("`r`n思考中…")

  $payload = @{ sessionId = $sid; mode = "queue"; content = @(@{ type = "text"; text = $text }) }
  $res = Invoke-Rpc "session.prompt" $payload
  if (-not $res -or -not $res.ok) {
    $log.AppendText("`r`n（发送失败）")
    return
  }
  $g.polling = $true
  $pollTimer.Start()
}

$send.Add_Click({ Send-Message })
$inputBox.Add_KeyDown({
  param($s, $e)
  if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
    $e.SuppressKeyPress = $true
    Send-Message
  }
})

# ============ 回复轮询（流式 + 最终回复 + 超时） ============
$pollTimer = New-Object System.Windows.Forms.Timer
$pollTimer.Interval = 1200
$pollTimer.Add_Tick({
  if (-not $g.polling) { $pollTimer.Stop(); return }
  $sid = $g.sessionId
  if (-not $sid) { $pollTimer.Stop(); $g.polling = $false; return }
  $g.pollTicks++

  $res = Get-AssistantState $sid -AfterSeq $g.beforeSeq

  if ($res.finalText) {
    $reply = [string]$res.finalText
    if ($reply.Length -gt 1200) { $reply = $reply.Substring(0, 1200) + "…" }
    $log.Text = ("我：" + $reply)
    $pollTimer.Stop()
    $g.polling = $false
    return
  }

  if ($res.streamText) {
    $stream = [string]$res.streamText
    if ($stream.Length -gt 800) { $stream = $stream.Substring($stream.Length - 800) }
    $log.Text = ("我：" + $stream + "…")
  }

  if ($g.pollTicks -ge 400) {
    $pollTimer.Stop()
    $g.polling = $false
    $log.Text = "（超时未收到回复）"
  }
})

# ============ 存活检查（终端退出后桌宠自动退出） ============
$liveTimer = New-Object System.Windows.Forms.Timer
$liveTimer.Interval = 3000
$liveTimer.Add_Tick({
  $r = Invoke-Rpc "session.list" @{}
  if ($r -eq $null) {
    if ($g.everConnected) {
      $g.deadCount++
      $dot.ForeColor = $cWarn
      if ($g.deadCount -ge 3) { $form.Close() }
    } else {
      $dot.ForeColor = $cSub
    }
  } else {
    $g.everConnected = $true
    $g.deadCount = 0
    $dot.ForeColor = $cGreen
  }
})

# ============ 关闭时保存状态 ============
$form.Add_FormClosing({
  param($s, $e)
  if (-not $g.disposed) {
    $g.disposed = $true
    Write-State $g.idx $form.Left $form.Top $g.sessionId
    $pollTimer.Stop()
    $liveTimer.Stop()
    if ($pic.Image) { try { $pic.Image.Dispose() } catch {} }
  }
})

# 首次解析会话
$g.sessionId = Get-TargetSessionId

$liveTimer.Start()
$form.Add_Shown({ $inputBox.Focus() })
[void]$form.ShowDialog()
