import unittest

include chof

suite "getSelectedFileFullPath":
  test "Normal":
    #let term = Terminal(cwd = "/home/user")
    discard

suite "getFileRefs":
  setup:
    let dir = "./tests/tmpdir"
    createDir(dir)
  teardown:
    removeDir(dir)
  test "files exist":
    let fs = getFileRefs("./tests/testdata")
    check fs[0].name == "01.txt"
    check fs[1].name == "02.txt"
  test "directory doesn't exist":
    let fs = getFileRefs("./tests/not_found")
    check fs.len == 0
  test "directory exists and not files":
    let fs = getFileRefs(dir)
    check fs.len == 0

suite "setParentFiles":
  setup:
    let dir = "./tests/1/2"
    createDir(dir)
  teardown:
    removeDir(dir)
  test "./tests/1/2":
    var term = Terminal(cwd: dir)
    term.setParentFiles()
    check term.parentFiles.len == 1
    check term.parentFiles[0].name == "2"
  test "/":
    var term = Terminal(cwd: "/")
    term.setParentFiles()
    check term.parentFiles.len == 0
  test "dir doesn't exist":
    var term = Terminal(cwd: "./tests/not_found/x/y/z")
    term.setParentFiles()
    check term.parentFiles.len == 0

suite "setCurrentFiles":
  test "./tests/testdata":
    var term = Terminal(cwd: "./tests/testdata")
    term.setCurrentFiles()
    check term.files.len == 10
    check term.files[0].name == "01.txt"
  test "./tests/not_found":
    var term = Terminal(cwd: "./tests/not_found")
    term.setCurrentFiles()
    check term.files.len == 0

suite "setChildFiles":
  test "./tests/testdata2":
    var term = Terminal(cwd: "./tests/testdata2")
    term.setCurrentFiles()
    term.setChildFiles()
    check term.childFiles.len == 3
    check term.childFiles[0].name == "1.txt"
