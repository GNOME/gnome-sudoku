gnome_sudoku_vala_args = [
  '--gresources', resource_files,
  '--pkg', 'posix'
]

gnome_sudoku_sources = [
  'config.vapi',
  'aspect-frame.vala',
  'gnome-sudoku.vala',
  'main-menu.vala',
  'number-picker.vala',
  'preferences-window.vala',
  'print-dialog.vala',
  'sudoku-cell.vala',
  'sudoku-printer.vala',
  'sudoku-view.vala',
  'sudoku-window.vala',
  resources
]

gnome_sudoku_dependencies = [gtk, libsudoku_dep, adw]

gnome_sudoku = executable(meson.project_name(), gnome_sudoku_sources,
  vala_args: gnome_sudoku_vala_args,
  dependencies: gnome_sudoku_dependencies,
  link_with: libsudoku,
  install: true
)
