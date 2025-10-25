libsudoku_sources = [
  'backend.vala',
  'board.vala',
  'game.vala',
  'generator.vala',
  'saver.vala',
  'qqwing/qqwing-wrapper.cpp',
  'qqwing/qqwing-wrapper.h',
]

libsudoku_dependencies = [
  gee,
  json_glib,
  threads,
  qqwing
]

libsudoku = static_library('sudoku', libsudoku_sources,
  c_args: '-w',
  dependencies: libsudoku_dependencies,
  vala_header: 'libsudoku.h',
  vala_vapi: 'libsudoku.vapi'
)

libsudoku_dep = declare_dependency(dependencies: libsudoku_dependencies,
  include_directories: include_directories('.'),
  link_with: libsudoku
)
