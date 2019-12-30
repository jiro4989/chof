import os, strutils, tables
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
    x, y: int

proc listFilesGroupByPrefix*(dir: string): GroupedFiles =
  ## ファイル名のプレフィックスでグルーピング。
  ## 半角文字のみグルーピング。
  ## マルチバイト文字はその他扱い。
  result = initOrderedTable[string, seq[string]]()
  result["~"] = @[]
  for k, p in walkDir(dir):
    let
      base = lastPathPart(p)
      prefix = base[0].toLowerAscii
      prefixStr = $prefix
    if prefix.isAlphaAscii or prefix == '.':
      if not result.hasKey(prefixStr):
        result[prefixStr] = @[]
      result[prefixStr].add(base)
    else:
      result["~"].add(base)
  proc cmp(x, y: (string, seq[string])): int =
    if x[0] < y[0]: 0
    else: 1
  result.sort(cmp)

proc selectElement*() = discard

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

proc fileColor(kind: PathComponent): ForegroundColor =
  if kind == pcDir:
    fgBlue
  else:
    fgWhite

proc redraw(term: Terminal) =
  let cwd = getCurrentDir()
  let files = listFilesGroupByPrefix(cwd)
  var y: int
  for key, paths in files.pairs:
    if term.y == y:
      term.tb.setBackgroundColor(bgGreen)
    let line = $key & ": " & paths.join(" ")
    term.tb.write(0, y, line)
    term.tb.resetAttributes()
    inc(y)

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

  var term = new Terminal
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
    of Key.Escape, Key.Q: exitProc()
    of Key.J:
      inc(term.y)
    of Key.K:
      dec(term.y)
      if term.y < 0:
        term.y = 0
    of Key.H:
      term.y = 0
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
    of Key.S:
      searchQuery = "j"
    else: discard

    term.tb.display()
    sleep(20)

when isMainModule and not defined modeTest:
  stdin = tty
  stdout = tty
  stderr = tty

  main()
