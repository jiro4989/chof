import os, strutils, tables, algorithm
export tables

import illwill

var
  output: string
  tty = open("/dev/tty", fmReadWrite)
  oldStdin = stdin
  oldStdout = stdout
  oldStderr = stderr
  searchQuery = ""

type
  GroupedFiles* = OrderedTable[string, seq[string]]
  Terminal = ref object
    tb: TerminalBuffer
    selectedItemIndex: int
    cwd: string
    files: seq[string]

proc setCurrentFiles(term: var Terminal) =
  var files: seq[string]
  for kind, path in walkDir(term.cwd):
    let base = path.lastPathPart()
    files.add(base)
  files.sort()
  term.files = files

proc newTerminal(): Terminal =
  result = Terminal()
  result.cwd = getCurrentDir()
  result.setCurrentFiles()

proc exitProc() {.noconv.} =
  ## 終了処理
  illwillDeinit()
  showCursor()

  tty.close()
  stdin = oldStdin
  stdout = oldStdout
  stderr = oldStderr

  echo output
  quit(0)

proc searchPrefix(term: var Terminal, prefix: char) =
  let
    idx = term.selectedItemIndex
    files = term.files
  if idx + 1 < files.len and files[idx][0] == prefix and files[idx + 1][0] == prefix:
    inc(term.selectedItemIndex)
    return

  for i, file in files:
    if file.startsWith(prefix):
      term.selectedItemIndex = i
      break

proc redraw(term: Terminal) =
  let cwd = term.cwd
  term.tb.write(0, 0, cwd)
  var y = 0
  for path in term.files:
    if term.selectedItemIndex == y:
      term.tb.setBackgroundColor(bgGreen)
      output = cwd / path
    term.tb.write(0, y+1, path)
    inc(y)
    term.tb.resetAttributes()

proc downDir(itemIndex: var int) =
  let cwd = getCurrentDir()
  var i: int
  for k, p in walkDir(cwd):
    if searchQuery notin lastPathPart(p):
      continue
    if itemIndex == i:
      if k == pcDir:
        setCurrentDir(p)
        itemIndex = 0
        return
    inc(i)

proc main =
  # 初期設定。とりあえずやっとく
  illwillInit(fullscreen=true)
  setControlCHook(exitProc)
  hideCursor()

  var term = newTerminal()
  while true:
    # 後から端末の幅が変わる場合があるため
    # 端末の幅情報はループの都度取得
    let tw = terminalWidth()
    let th = terminalHeight()

    term.tb = newTerminalBuffer(tw, th)
    #tb.setForegroundColor(fgWhite, true)

    # 画面の再描画
    term.redraw()

    var key = getKey()
    case key
    of Key.None: discard
    of Key.Escape: exitProc()
    of Key.A,
       Key.B,
       Key.C,
       Key.D,
       Key.E,
       Key.F,
       Key.G,
       Key.I,
       Key.M,
       Key.N,
       Key.O,
       Key.P,
       Key.Q,
       Key.R,
       Key.S,
       Key.T,
       Key.U,
       Key.V,
       Key.W,
       Key.X,
       Key.Y,
       Key.Z:
      let key = ($key)[0].toLowerAscii
      term.searchPrefix(key)
    of Key.J:
      inc(term.selectedItemIndex)
    of Key.K:
      dec(term.selectedItemIndex)
      if term.selectedItemIndex < 0:
        term.selectedItemIndex = 0
    of Key.H:
      term.selectedItemIndex = 0
      term.cwd = term.cwd.parentDir()
      term.setCurrentFiles()
    of Key.Enter:
      exitProc()
    else: discard

    term.tb.display()
    sleep(20)

when isMainModule and not defined modeTest:
  stdin = tty
  stdout = tty
  stderr = tty

  main()
