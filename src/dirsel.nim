import os, strutils, tables
from unicode import toRunes, runeAt, `$`

import illwill

var
  output: string
  tty = open("/dev/tty", fmReadWrite)
  oldStdin = stdin
  oldStdout = stdout
  oldStderr = stderr
  searchQuery = ""

type
  GroupedFiles* = ref object
    key*: string
    files*: seq[File]

proc `$`*(self: GroupedFiles): string = $self[]

proc listFilesGroupByPrefix*(dir: string): seq[GroupedFiles] =
  ## ファイル名のプレフィックスでグルーピング。
  ## 半角文字のみグルーピング。
  ## マルチバイト文字はその他扱い。
  var tbl = initTable[string, seq[string]]()
  tbl["other"] = @[]
  for k, p in walkDir(dir):
    let
      base = lastPathPart(p)
      prefix = base[0]
      prefixStr = $prefix
    if prefix.isAlphaAscii() or prefix == '.':
      if not tbl.hasKey(prefixStr):
        tbl[prefixStr] = @[]
      tbl[prefixStr].add(base)
    else:
      tbl["other"].add(base)
  echo tbl

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

proc redraw(tb: var TerminalBuffer, itemIndex: var int) =
  let cwd = getCurrentDir()
  let depthSpan = 3
  var x, y: int
  for d in parentDirs(cwd, fromRoot = true):
    inc(x, depthSpan)
    inc(y)

    let col = getFileInfo(d).kind.fileColor()
    tb.setForegroundColor(col, true)
    tb.write(x-depthSpan, y, "|- " & lastPathPart(d))
    tb.resetAttributes()

    if cwd == d:
      inc(x, depthSpan)
      var i: int
      for k, p in walkDir(d):
        if searchQuery notin lastPathPart(p):
          continue
        inc(y)

        if itemIndex == i:
          tb.setForegroundColor(fgBlack, true)
          tb.setBackgroundColor(bgGreen)
          tb.write(x-depthSpan, y, "|- " & lastPathPart(p))
          output = p
          tb.resetAttributes()

          if k == pcDir:
            inc(x, depthSpan)
            for k, p in walkDir(p):
              inc(y)
              let col = fileColor(k)
              tb.setForegroundColor(col, true)
              tb.write(x-depthSpan*2, y, "|  |- " & lastPathPart(p))
              tb.resetAttributes()
            dec(x, depthSpan)
        else:
          let col = fileColor(k)
          tb.setForegroundColor(col, true)
          tb.write(x-depthSpan, y, "|- " & lastPathPart(p))
        inc(i)
        tb.resetAttributes()

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
      itemIndex = 0
      let cwd = getCurrentDir()
      setCurrentDir(cwd.parentDir())
    of Key.L:
      downDir(itemIndex)
    of Key.Space:
      discard
    of Key.C:
      discard
    of Key.Enter:
      exitProc()
    of Key.S:
      searchQuery = "j"
    else: discard

    tb.display()
    sleep(20)

when isMainModule and not defined modeTest:
  stdin = tty
  stdout = tty
  stderr = tty

  main()
