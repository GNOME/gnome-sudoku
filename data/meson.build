resource_files = files('gnome-sudoku.gresource.xml')

resources = gnome.compile_resources('gnome-sudoku', resource_files)

desktop_file = i18n.merge_file(
  input: 'org.gnome.Sudoku.desktop.in',
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
    ],
    depends: [
      desktop_file
    ],
  )
endif

appdata_file = i18n.merge_file(
  input: 'org.gnome.Sudoku.appdata.xml.in',
  output: '@0@.appdata.xml'.format(application_id),
  install: true,
  install_dir: join_paths(datadir, 'metainfo'),
  po_dir: '../po'
)
appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test(
    'validate-appdata', appstreamcli,
    args: [
      'validate', '--no-net', appdata_file.full_path()
    ],
    depends: [
      appdata_file
    ],
  )
endif

install_data('org.gnome.Sudoku.gschema.xml',
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

install_man('@0@.6'.format(meson.project_name()))

icondir = join_paths(datadir, 'icons', 'hicolor')

install_data('icons/hicolor/scalable/@0@.svg'.format(application_id),
  install_dir: join_paths(icondir, 'scalable', 'apps')
)

install_data('icons/hicolor/symbolic/org.gnome.Sudoku-symbolic.svg',
  install_dir: join_paths(icondir, 'symbolic', 'apps'),
  rename: '@0@-symbolic.svg'.format(application_id)
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
