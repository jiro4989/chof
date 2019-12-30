import unittest

include dirsel

suite "proc listFilesGroupByPrefix":
  test "normal":
    echo ".".listFilesGroupByPrefix()
    echo "src".listFilesGroupByPrefix()
    echo "tests".listFilesGroupByPrefix()
    echo ".git".listFilesGroupByPrefix()
