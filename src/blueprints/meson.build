blueprints = custom_target(
  'blueprints',
  input: files(
    'game-view.blp',
    'menu-button.blp',
    'preferences-dialog.blp',
    'print-multiple-dialog.blp',
    'shortcuts-dialog.blp',
    'start-view.blp',
    'window.blp',
  ),
  output: '.',
  install_dir: '@CURRENT_SOURCE_DIR@',
  command: [blueprintc, 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
  depends: metainfo_file,
)

