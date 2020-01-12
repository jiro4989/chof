import os, strutils, tables, algorithm
from terminal import getch
from strformat import `&`

import illwill

var
  output: string
  tty =
    when defined windows:
      {.fatal "windows not supported".}
    elif not defined modeTest:
      open("/dev/tty", fmReadWrite)
    else:
      stdout
  oldStdin = stdin
  oldStdout = stdout

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

func getPageSize(term: Terminal): int = term.height - 3

func getSelectedFileFullPath(term: Terminal): string =
  let idx = term.selectedItemIndex
  let base = term.files[idx].name
  let path = term.cwd / base
  result = path

proc getFileRefs(path: string): seq[FileRef] =
  for kind, path in walkDir(path):
    try:
      let base = path.lastPathPart()
      let size =
        if path.existsFile: getFileSize(path)
        else: 0
      let f = FileRef(kind: kind, name: base, size: size)
      result.add(f)
    except OSError, IOError:
      # ignore 'no such device or address error'
      discard
  result = result.sortedByIt(it.name)

proc setParentFiles(term: var Terminal) =
  let file = term.cwd.parentDir()
  let files =
    if file.existsDir(): file.getFileRefs()
    elif term.cwd == "/": @[]
    elif file == "": "/".getFileRefs() # root directory
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
  if term.cwd == "":
    term.cwd = "/"
  if term.cwd.dirExists():
    term.setFiles()
    term.selectedItemIndex = term.files.getSelectedFileIndex(base)

proc moveChildDir(term: var Terminal) =
  if term.files.len < 1 or term.childFiles.len < 1:
    return
  let base = term.files[term.selectedItemIndex]
  let path = term.cwd / base.name
  term.cwd = path
  term.selectedItemIndex = 0
  term.setFiles()

proc moveNext(term: var Terminal, index: int) =
  term.selectedItemIndex = index
  if term.files.len <= index:
    term.selectedItemIndex = term.files.len - 1
  term.setChildFiles()

proc moveNextFile(term: var Terminal) =
  let index = term.selectedItemIndex + 1
  term.moveNext(index)

proc moveNextPageFile(term: var Terminal) =
  let pageSize = term.getPageSize
  let index = int((term.selectedItemIndex + pageSize) / pageSize) * pageSize
  term.moveNext(index)

proc movePageBottomFile(term: var Terminal) =
  let pageSize = term.getPageSize
  let index = int((term.selectedItemIndex + pageSize) / pageSize) * pageSize - 1
  term.moveNext(index)

proc movePrevious(term: var Terminal, index: int) =
  term.selectedItemIndex = index
  if index < 0:
    term.selectedItemIndex = 0
  term.setChildFiles()

proc movePreviousFile(term: var Terminal) =
  let index = term.selectedItemIndex - 1
  term.movePrevious(index)

proc movePreviousPageFile(term: var Terminal) =
  let pageSize = term.getPageSize
  let index = int((term.selectedItemIndex - pageSize) / pageSize) * pageSize
  term.movePrevious(index)

proc movePageTopFile(term: var Terminal) =
  let pageSize = term.getPageSize
  let index = int((term.selectedItemIndex) / pageSize) * pageSize
  term.movePrevious(index)

proc drawFilePane(tb: var TerminalBuffer, title: string, files: seq[FileRef],
                  pageSize: int, selectedItemIndex: int, x, y, width: int) =
  let startIdx = int(selectedItemIndex / pageSize) * pageSize
  var
    y = y
    endIdx = startIdx + pageSize - 1
  if files.len <= endIdx:
    endIdx = files.len - 1

  # draw pane frame
  tb.drawRect(x, y, x+width-1, y+pageSize+1)
  tb.write(x+2, y, &"[{title}]")

  for file in files[startIdx .. endIdx]:
    if selectedItemIndex - startIdx == y-1:
      tb.setBackgroundColor(bgGreen)
    let
      kind = ($file.kind)[2]
      line = &"[{kind}] {file.name} {file.size}"
    if file.kind == pcDir:
      tb.setForegroundColor(fgBlue)
    else:
      tb.setForegroundColor(fgWhite)
    tb.write(x+1, y+1, line)
    inc(y)
    tb.resetAttributes()

proc redraw(term: Terminal) =
  let cwd = term.cwd
  term.tb.write(0, 0, cwd)

  let
    pageSize = term.getPageSize
    parentFileIndex = term.parentFiles.getSelectedFileIndex(cwd.lastPathPart)
    width = int(term.width / 3)
    y = 1
  term.tb.drawFilePane("Parent", term.parentFiles, pageSize, parentFileIndex, 0, y, width)
  term.tb.drawFilePane("Current", term.files, pageSize, term.selectedItemIndex, width, y, width)
  term.tb.drawFilePane("Child", term.childFiles, pageSize, 0, width*2, y, width)
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
    of Key.ShiftH: term.movePageTopFile()
    of Key.J: term.moveNextFile()
    of Key.ShiftJ: term.moveNextPageFile()
    of Key.K: term.movePreviousFile()
    of Key.ShiftK: term.movePreviousPageFile()
    of Key.L: term.moveChildDir()
    of Key.ShiftL: term.movePageBottomFile()
    of Key.Enter: exitProc()
    else: discard

    term.tb.display()
    sleep(20)

when isMainModule and not defined modeTest:
  stdin = tty
  stdout = tty

  main()
