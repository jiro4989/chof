import unittest

include chof

suite "proc listFilesGroupByPrefix":
  test "normal":
    echo ".".listFilesGroupByPrefix()
    echo "src".listFilesGroupByPrefix()
    echo "tests".listFilesGroupByPrefix()
    echo ".git".listFilesGroupByPrefix()
