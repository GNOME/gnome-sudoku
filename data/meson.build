resource_files = files('gnome-sudoku.gresource.xml')

resources = gnome.compile_resources('gnome-sudoku', resource_files)

desktop_file = i18n.merge_file(
  input: '@0@.desktop.in'.format(application_id),
  output: '@0@.desktop'.format(application_id),
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
    args: [
      desktop_file.full_path()
    ]
  )
endif

appdata_file = i18n.merge_file(
  input: '@0@.appdata.xml.in'.format(application_id),
  output: '@0@.appdata.xml'.format(application_id),
  install: true,
  install_dir: join_paths(datadir, 'metainfo'),
  po_dir: '../po'
)
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test(
    'validate-appdata', appstream_util,
    args: [
      'validate-relax', '--nonet', appdata_file.full_path()
    ]
  )
endif

install_data('@0@.gschema.xml'.format(application_id),
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

install_man('@0@.6'.format(meson.project_name()))

icondir = join_paths(datadir, 'icons', 'hicolor')

install_data('icons/hicolor/scalable/@0@.svg'.format(application_id),
  install_dir: join_paths(icondir, 'scalable', 'apps')
)

install_data('icons/hicolor/symbolic/@0@-symbolic.svg'.format(application_id),
  install_dir: join_paths(icondir, 'symbolic', 'apps')
)

# Make D-Bus activatable
service_conf = configuration_data()
service_conf.set('bindir', join_paths(prefix, bindir))

service = 'org.gnome.Sudoku.service'

configure_file (
  input: service + '.in',
  output: service,
  install: true,
  install_dir: join_paths(prefix, datadir, 'dbus-1', 'services'),
  configuration: service_conf
)
