gnome_sudoku_vala_args = ['--pkg=posix']

gnome_sudoku_sources = [
  'config.vapi',
  'aspect-frame.vala',
  'gnome-sudoku.vala',
  'number-picker.vala',
  'preferences-dialog.vala',
  'print-dialog.vala',
  'cell.vala',
  'printer.vala',
  'start-menu.vala',
  'view.vala',
  'window.vala',
  resources
]

gnome_sudoku_dependencies = [gtk, libsudoku_dep, adw]

gnome_sudoku = executable(
  meson.project_name(),
  gnome_sudoku_sources,
  vala_args: gnome_sudoku_vala_args,
  c_args: '-w',
  dependencies: [gnome_sudoku_dependencies, threads],
  link_with: libsudoku,
  install: true
)
