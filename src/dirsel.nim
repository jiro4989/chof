import os, strutils
import illwill

proc exitProc() {.noconv.} =
  ## 終了処理
  illwillDeinit()
  showCursor()
  quit(0)

proc redraw(tb: var TerminalBuffer) =
  let cwd = getCurrentDir()
  var x, y: int
  for d in parentDirs(cwd, fromRoot = true):
    inc(x, 2)
    inc(y)
    tb.write(x, y, lastPathPart(d))
    if cwd == d:
      inc(x, 2)
      for k, p in walkDir(d):
        inc(y)
        tb.write(x, y, lastPathPart(p))

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

    # 画面の再描画
    tb.redraw()

    var key = getKey()
    case key
    of Key.None: discard
    of Key.Escape, Key.Q: exitProc()
    of Key.J:
      discard
    of Key.K:
      discard
    of Key.H:
      let cwd = getCurrentDir()
      setCurrentDir(cwd.parentDir())
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
