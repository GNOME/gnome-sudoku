project(
  'gnome-sudoku',
  'rust',
  license: 'GPL3+',
  meson_version: '>= 1.4',
  version: '52.alpha'
)

gnome = import('gnome')
i18n = import('i18n')

datadir     = get_option('datadir')
localedir   = get_option('localedir')
prefix      = get_option('prefix')
bindir      = get_option('bindir')
profile     = get_option('profile')

base_id = 'org.gnome.Sudoku'
app_id = base_id
if profile == 'Devel'
  app_id += '.' + profile
endif

glib_version = '2.80.0'

gio = dependency('gio-2.0', version: '>= @0@'.format(glib_version))
glib = dependency('glib-2.0', version: '>= @0@'.format(glib_version))
gtk = dependency('gtk4', version: '>= 4.19.3')
adw = dependency('libadwaita-1', version: '>= 1.8')
blueprintc = find_program('blueprint-compiler', version: '>= 0.16')
cargo = find_program('cargo')

subdir('data')
subdir('help')
subdir('po')
subdir('src')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
