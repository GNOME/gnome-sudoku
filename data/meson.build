resource_files = files('gnome-sudoku.gresource.xml')

resources = gnome.compile_resources('gnome-sudoku', resource_files)

desktop = i18n.merge_file('desktop',
  input: '@0@.desktop.in'.format(application_id),
  output: '@0@.desktop'.format(application_id),
  install: true,
  install_dir: join_paths(datadir, 'applications'),
  po_dir: '../po',
  type: 'desktop'
)

appdata = i18n.merge_file('appdata',
  input: '@0@.appdata.xml.in'.format(application_id),
  output: '@0@.appdata.xml'.format(application_id),
  install: true,
  install_dir: join_paths(datadir, 'metainfo'),
  po_dir: '../po'
)

install_data('@0@.gschema.xml'.format(application_id),
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

install_man('@0@.6'.format(meson.project_name()))

icondir = join_paths(datadir, 'icons', 'hicolor')

foreach icon_size: ['16x16', '22x22', '24x24', '32x32', '48x48']
  install_data('icons/hicolor/@0@/@1@.png'.format(application_id, icon_size),
    install_dir: join_paths(icondir, icon_size, 'apps')
  )
endforeach

install_data('icons/hicolor/scalable/@0@.svg'.format(application_id),
  install_dir: join_paths(icondir, 'scalable', 'apps')
)

install_data('icons/hicolor/symbolic/@0@-symbolic.svg'.format(application_id),
  install_dir: join_paths(icondir, 'symbolic', 'apps')
)
