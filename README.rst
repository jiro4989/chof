chof - (choose file)
####################

chof is inspired by `peco <https://github.com/peco/peco>`_.

|demo|

.. contents:: Table of contents
   :depth: 3

Installation
============

.. code-block:: nim

   nimble install chof

Usage
=====

.. code-block:: bash

   chof

Change directory with `chof`.

.. code-block:: bash

   cf() {
     local dir="$(chof)"
     if [[ "$dir" != "" ]]; then
       cd "$dir"
     fi
   }

Key mappings
------------

===========  ==========================================
Key          Description
===========  ==========================================
h            Move parent directory
j            Move next file
k            Move previous file
l            Move child directory
H            Move page top file
J            Move next page
K            Move previous page
L            Move page bottom file
q            Quit application
f + 'char'   Select a file with a prefix char
<ESC>        Quit application
<ENTER>      Print a selected file and quit application
===========  ==========================================

LICENSE
-------

MIT

.. |demo| image:: ./docs/demo.gif
