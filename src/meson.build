subdir ('blueprints')

resources = gnome.compile_resources(
  'gnome-sudoku',
  resource_files,
  dependencies: blueprints,
  source_dir: [
    join_paths(meson.project_build_root(), 'data'), #metainfo
    join_paths(meson.project_source_root(), 'data'), #styles
    join_paths(meson.current_build_dir(), 'blueprints') #blueprints
  ]
)

gnome_sudoku_vala_args = ['--pkg=posix']

gnome_sudoku_sources = [
  'config.vapi',
  'cell.vala',
  'earmark.vala',
  'game-view.vala',
  'gnome-sudoku.vala',
  'grid.vala',
  'grid-layout.vala',
  'menu-button.vala',
  'number-picker.vala',
  'preferences-dialog.vala',
  'print-multiple-dialog.vala',
  'printer.vala',
  'start-view.vala',
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
