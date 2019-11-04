import os, strutils
import illwill

when false:
  let cwd = getCurrentDir().parentDir().parentDir().parentDir()
  var depth: int
  for d in parentDirs(cwd, fromRoot = true):
    inc(depth)
    echo repeat(" ", depth).join() & lastPathPart(d)
    if cwd == d:
      inc(depth)
      for k, p in walkDir(d):
        echo repeat(" ", depth).join() & lastPathPart(p)

proc exitProc() {.noconv.} =
  ## 終了処理
  illwillDeinit()
  showCursor()
  quit(0)

proc main =
  # 初期設定。とりあえずやっとく
  illwillInit(fullscreen=true)
  setControlCHook(exitProc)
  hideCursor()

  while true:
    # 後から端末の幅が変わる場合があるため
    # 端末の幅情報はループの都度取得
    let tw = terminalWidth()
    let th = terminalHeight()

    var tb = newTerminalBuffer(tw, th)
    tb.setForegroundColor(fgWhite, true)

    var key = getKey()
    case key
    of Key.None: discard
    of Key.Escape, Key.Q: exitProc()
    of Key.J:
      discard
    of Key.K:
      discard
    of Key.H:
      discard
    of Key.L:
      discard
    of Key.Space:
      discard
    of Key.C:
      discard
    of Key.Enter:
      discard
    else: discard

    tb.display()
    sleep(20)

main()
