import os, strutils, tables, algorithm, sequtils
from terminal import getch
from strformat import `&`
from unicode import toRunes, `$`

import illwill

var
  output: string
  tty =
    when not defined modeTest:
      open("/dev/tty", fmReadWrite)
    else:
      stdout
  oldStdin = stdin
  oldStdout = stdout
  searchQuery = ""

type
  GroupedFiles* = OrderedTable[string, seq[string]]
  FileRef = ref object
    kind: PathComponent
    name: string
    size: BiggestInt
  Terminal = ref object
    tb: TerminalBuffer
    selectedItemIndex: int
    cwd: string
    width, height: int
    searchQuery: string
    parentFiles: seq[FileRef]
    files: seq[FileRef]
    childFiles: seq[FileRef]
    filteredFiles: seq[FileRef]

func getSelectedFileFullPath(term: Terminal): string =
  let idx = term.selectedItemIndex
  let base = term.files[idx].name
  let path = term.cwd / base
  result = path

proc getFileRefs(path: string): seq[FileRef] =
  for kind, path in walkDir(path):
    let base = path.lastPathPart()
    let size =
      if kind == pcFile: getFileSize(path)
      else: 0
    let f = FileRef(kind: kind, name: base, size: size)
    result.add(f)
  result = result.sortedByIt(it.name)

proc setParentFiles(term: var Terminal) =
  let file = term.cwd.parentDir()
  let files =
    if file.existsDir(): file.getFileRefs()
    else: @[]
  term.parentFiles = files

proc setCurrentFiles(term: var Terminal) =
  term.files = term.cwd.getFileRefs()
  term.filteredFiles = term.files

proc setChildFiles(term: var Terminal) =
  let file = term.getSelectedFileFullPath()
  let files =
    if file.existsDir(): file.getFileRefs()
    else: @[]
  term.childFiles = files

proc setFiles(term: var Terminal) =
  term.setParentFiles()
  term.setCurrentFiles()
  term.setChildFiles()

proc newTerminal(): Terminal =
  result = Terminal()
  result.cwd = getCurrentDir()
  result.setFiles()

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
  if idx + 1 < files.len and files[idx].name[0] == prefix and files[idx + 1].name[0] == prefix:
    inc(term.selectedItemIndex)
    return

  for i, file in files:
    if file.name.startsWith(prefix):
      term.selectedItemIndex = i
      break

proc searchInteractively(term: var Terminal) =
  discard # WIP
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

func getSelectedFileIndex(files: seq[FileRef], name: string): int =
  for i, f in files:
    if f.name == name:
      return i

proc moveParentDir(term: var Terminal) =
  term.selectedItemIndex = 0
  let base = term.cwd.lastPathPart()
  term.cwd = term.cwd.parentDir()
  if term.cwd.dirExists():
    term.setFiles()
    term.selectedItemIndex = term.files.getSelectedFileIndex(base)

proc moveChildDir(term: var Terminal) =
  let base = term.files[term.selectedItemIndex]
  let path = term.cwd / base.name
  term.cwd = path
  term.selectedItemIndex = 0
  term.setFiles()

proc moveNextFile(term: var Terminal) =
  if term.selectedItemIndex < term.files.len - 1:
    inc(term.selectedItemIndex)
  term.setChildFiles()

proc movePreviousFile(term: var Terminal) =
  dec(term.selectedItemIndex)
  if term.selectedItemIndex < 0:
    term.selectedItemIndex = 0
  term.setChildFiles()

proc drawFilePane(tb: var TerminalBuffer, files: seq[FileRef],
                  pageSize: int, selectedItemIndex: int, x, y, width: int) =
  let startIdx = int(selectedItemIndex / pageSize) * pageSize
  var
    y = y
    endIdx = startIdx + pageSize
  if files.len <= endIdx:
    endIdx = files.len - 1

  for file in files[startIdx .. endIdx]:
    if selectedItemIndex - startIdx == y:
      tb.setBackgroundColor(bgGreen)
    let
      kind = ($file.kind)[2]
      name = file.name
      size = file.size
      line = &"[{kind}] {name} {size}"
    if file.kind == pcDir:
      tb.setForegroundColor(fgBlue)
    else:
      tb.setForegroundColor(fgWhite)
    tb.write(x, y+1, line)
    inc(y)
    tb.resetAttributes()

proc redraw(term: Terminal) =
  let cwd = term.cwd
  term.tb.write(0, 0, cwd)

  let
    pageSize = term.height - 1
    parentFileIndex = term.parentFiles.getSelectedFileIndex(cwd.lastPathPart)
    width = int(term.width / 3)
    y = 0
  term.tb.drawFilePane(term.parentFiles, pageSize, parentFileIndex, 0, y, 1)
  term.tb.drawFilePane(term.files, pageSize, term.selectedItemIndex, width, y, 1)
  term.tb.drawFilePane(term.childFiles, pageSize, 0, width*2, y, 1)
  output = term.getSelectedFileFullPath()

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
    term.tb.setForegroundColor(fgWhite)

    # 画面の再描画
    term.redraw()

    let key = getKey()
    case key
    of Key.None: discard
    of Key.Escape, Key.Q:
      output = ""
      exitProc()
    of Key.F:
      let key = getch()
      term.searchPrefix(key)
    of Key.I: term.searchInteractively()
    of Key.H: term.moveParentDir()
    of Key.J: term.moveNextFile()
    of Key.K: term.movePreviousFile()
    of Key.L: term.moveChildDir()
    of Key.Enter: exitProc()
    else: discard

    term.tb.display()
    sleep(20)

when isMainModule and not defined modeTest:
  stdin = tty
  stdout = tty

  main()
