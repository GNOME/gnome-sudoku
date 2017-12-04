resource_files = files('gnome-sudoku.gresource.xml')

resources = gnome.compile_resources('gnome-sudoku', resource_files)

desktop = i18n.merge_file('desktop',
  input: 'gnome-sudoku.desktop.in',
  output: 'gnome-sudoku.desktop',
  install: true,
  install_dir: join_paths(datadir, 'applications'),
  po_dir: '../po',
  type: 'desktop'
)

appdata = i18n.merge_file('appdata',
  input: 'gnome-sudoku.appdata.xml.in',
  output: 'gnome-sudoku.appdata.xml',
  install: true,
  install_dir: join_paths(datadir, 'appdata'),
  po_dir: '../po'
)

install_data('org.gnome.sudoku.gschema.xml',
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

install_man('gnome-sudoku.6')

icondir = join_paths(datadir, 'icons', 'hicolor')

foreach icon_size: ['16x16', '22x22', '24x24', '32x32', '48x48']
  install_data('icons/hicolor/@0@/gnome-sudoku.png'.format(icon_size),
    install_dir: join_paths(icondir, icon_size, 'apps')
  )
endforeach

install_data('icons/hicolor/scalable/gnome-sudoku.svg',
  install_dir: join_paths(icondir, 'scalable', 'apps')
)

install_data('icons/hicolor/symbolic/gnome-sudoku-symbolic.svg',
  install_dir: join_paths(icondir, 'symbolic', 'apps')
)
