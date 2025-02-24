libsudoku_sources = [
  'sudoku-board.vala',
  'sudoku-game.vala',
  'sudoku-generator.vala',
  'sudoku-saver.vala',
  'qqwing-wrapper.cpp',
  'qqwing-wrapper.h'
]

libsudoku_dependencies = [
  gee,
  json_glib,
  threads,
  qqwing
]

libsudoku = static_library('sudoku', libsudoku_sources,
  dependencies: libsudoku_dependencies,
  vala_header: 'libsudoku.h',
  vala_vapi: 'libsudoku.vapi'
)

libsudoku_dep = declare_dependency(dependencies: libsudoku_dependencies,
  include_directories: include_directories('.'),
  link_with: libsudoku
)
