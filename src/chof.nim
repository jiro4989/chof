import os, strutils, tables, algorithm, sequtils
from terminal import getch
from unicode import toRunes, `$`

import illwill

var
  output: string
  tty = open("/dev/tty", fmReadWrite)
  oldStdin = stdin
  oldStdout = stdout
  searchQuery = ""

type
  GroupedFiles* = OrderedTable[string, seq[string]]
  Terminal = ref object
    tb: TerminalBuffer
    selectedItemIndex: int
    cwd: string
    files: seq[string]
    width, height: int
    searchQuery: string
    filteredFiles: seq[string]

proc setCurrentFiles(term: var Terminal) =
  var files: seq[string]
  for kind, path in walkDir(term.cwd):
    let base = path.lastPathPart()
    files.add(base)
  files.sort()
  term.files = files
  term.filteredFiles = files

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

  if output != "":
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

  let
    pageSize = term.height - 1
    sIdx = term.selectedItemIndex
    startIdx = int(sIdx / pageSize) * pageSize
    files = term.filteredFiles

  var
    y = 0
    endIdx = startIdx + pageSize
  if files.len <= endIdx:
    endIdx = files.len - 1

  for path in files[startIdx .. endIdx]:
    if sIdx - startIdx == y:
      term.tb.setBackgroundColor(bgGreen)
      output = cwd / path
    term.tb.write(0, y+1, path)
    inc(y)
    term.tb.resetAttributes()

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
    term.width = tw
    term.height = th
    #tb.setForegroundColor(fgWhite, true)

    # 画面の再描画
    term.redraw()

    var key = getKey()
    case key
    of Key.None:
      discard
    of Key.Escape, Key.Q:
      output = ""
      exitProc()
    of Key.F:
      let key = getch()
      term.searchPrefix(key)
    of Key.I:
      discard
      # WIP
      when false:
        while true:
          term.redraw()

          let key = getKey()
          case key
          of Key.Enter, Key.Escape:
            break
          of Key.BackSpace:
            if 0 < term.searchQuery.len:
              term.searchQuery = $term.searchQuery.toRunes[0..^2]
          else:
            term.searchQuery.add(key.`$`[0].toLowerAscii)
            term.filteredFiles = term.files.filterIt(term.searchQuery in it)

          term.tb.display()
          sleep(20)
    of Key.H:
      term.selectedItemIndex = 0
      term.cwd = term.cwd.parentDir()
      term.setCurrentFiles()
    of Key.J:
      if term.selectedItemIndex < term.files.len - 1:
        inc(term.selectedItemIndex)
    of Key.K:
      dec(term.selectedItemIndex)
      if term.selectedItemIndex < 0:
        term.selectedItemIndex = 0
    of Key.L:
      let base = term.files[term.selectedItemIndex]
      let path = term.cwd / base
      term.cwd = path
      term.selectedItemIndex = 0
      term.setCurrentFiles()
    of Key.Enter:
      exitProc()
    else: discard

    term.tb.display()
    sleep(20)

when isMainModule and not defined modeTest:
  stdin = tty
  stdout = tty

  main()
