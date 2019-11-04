import os, strutils
import illwill

var
  output: string

proc exitProc() {.noconv.} =
  ## 終了処理
  illwillDeinit()
  showCursor()
  echo output
  quit(0)

proc redraw(tb: var TerminalBuffer, itemIndex: var int) =
  let cwd = getCurrentDir()
  var x, y: int
  for d in parentDirs(cwd, fromRoot = true):
    inc(x, 2)
    inc(y)
    tb.write(x, y, lastPathPart(d))
    if cwd == d:
      inc(x, 2)
      var i: int
      for k, p in walkDir(d):
        inc(y)
        if itemIndex == i:
          tb.setForegroundColor(fgBlack, true)
          tb.setBackgroundColor(bgGreen)
          tb.write(x, y, lastPathPart(p))
          output = p
        else:
          var col =
            if k == pcDir: fgBlue
            else: fgWhite
          tb.setForegroundColor(col, true)
          tb.write(x, y, lastPathPart(p))
        inc(i)
        tb.resetAttributes()

proc main =
  # 初期設定。とりあえずやっとく
  illwillInit(fullscreen=true)
  setControlCHook(exitProc)
  hideCursor()

  var itemIndex: int
  while true:
    # 後から端末の幅が変わる場合があるため
    # 端末の幅情報はループの都度取得
    let tw = terminalWidth()
    let th = terminalHeight()

    var tb = newTerminalBuffer(tw, th)
    #tb.setForegroundColor(fgWhite, true)

    # 画面の再描画
    tb.redraw(itemIndex)

    var key = getKey()
    case key
    of Key.None: discard
    of Key.Escape, Key.Q: exitProc()
    of Key.J:
      inc(itemIndex)
    of Key.K:
      dec(itemIndex)
      if itemIndex < 0:
        itemIndex = 0
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
      exitProc()
    else: discard

    tb.display()
    sleep(20)

main()
