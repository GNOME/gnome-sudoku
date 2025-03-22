desktop_conf = configuration_data()
desktop_conf.set('icon', app_id)
desktop_file = i18n.merge_file(
  input: configure_file(
    input: '@0@.desktop.in.in'.format(base_id),
    output: '@BASENAME@',
    configuration: desktop_conf
  ),
  output: '@0@.desktop'.format(app_id),
  install: true,
  install_dir: join_paths(datadir, 'applications'),
  po_dir: '../po',
  type: 'desktop'
)

desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: desktop_file.full_path(),
    depends: desktop_file,
  )
endif

metainfo_conf = configuration_data()
metainfo_conf.set('app-id', app_id)
metainfo_file = i18n.merge_file(
  input: configure_file(
    input: '@0@.metainfo.xml.in.in'.format(base_id),
    output: '@BASENAME@',
    configuration: metainfo_conf
  ),
  output: '@0@.metainfo.xml'.format(app_id),
  install: true,
  install_dir: join_paths(datadir, 'metainfo'),
  po_dir: '../po'
)

appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test(
    'validate-metainfo',
    appstreamcli,
    args: ['validate', '--no-net', metainfo_file.full_path()],
    depends: metainfo_file ,
  )
endif

resource_conf = configuration_data()
resource_conf.set('app-id', app_id)
resource_conf.set('base-id-slashed', '/' + base_id.replace('.', '/'))
resource_files = configure_file(
  input: 'gnome-sudoku.gresource.xml.in',
  output: '@BASENAME@',
  configuration: resource_conf
)

blueprints = custom_target(
  'blueprints',
  input: files(
    'preferences-dialog.blp',
    'print-dialog.blp',
    'shortcuts-window.blp',
    'start-menu.blp',
    'game-view.blp',
    'window.blp',
  ),
  output: '.',
  command: [blueprintc, 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
  depends: metainfo_file,
)

resources = gnome.compile_resources(
  'gnome-sudoku',
  resource_files,
  dependencies: blueprints,
  source_dir: meson.current_source_dir()
)

install_data(
  '@0@.gschema.xml'.format(base_id),
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

install_man('@0@.6'.format(meson.project_name()))

icondir = join_paths(datadir, 'icons', 'hicolor')
install_data(
  'icons/hicolor/scalable/@0@.svg'.format(app_id),
  install_dir: join_paths(icondir, 'scalable', 'apps')
)

install_data(
  'icons/hicolor/symbolic/@0@-symbolic.svg'.format(base_id),
  install_dir: join_paths(icondir, 'symbolic', 'apps'),
  rename: '@0@-symbolic.svg'.format(app_id)
)

# Make D-Bus activatable
service_conf = configuration_data()
service_conf.set('bindir', join_paths(prefix, bindir))
service_conf.set('app-id', app_id)

configure_file(
  input: '@0@.service.in'.format(base_id),
  output: '@0@.service'.format(app_id),
  install: true,
  install_dir: join_paths(prefix, datadir, 'dbus-1', 'services'),
  configuration: service_conf
)
