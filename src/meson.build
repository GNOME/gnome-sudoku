gnome_sudoku_vala_args = [
  '--gresources', resource_files,
  '--pkg', 'posix'
]

gnome_sudoku_sources = [
  'config.vapi',
  'gnome-sudoku.vala',
  'menu-item.vala',
  'number-picker.vala',
  'print-dialog.vala',
  'sudoku-printer.vala',
  'sudoku-view.vala',
  'sudoku-window.vala',
  resources
]

gnome_sudoku_dependencies = [gtk, libsudoku_dep]

gnome_sudoku = executable(meson.project_name(), gnome_sudoku_sources,
  vala_args: gnome_sudoku_vala_args,
  dependencies: gnome_sudoku_dependencies,
  link_with: libsudoku,
  install: true
)
