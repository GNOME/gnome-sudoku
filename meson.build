project('gnome-sudoku', ['c', 'cpp', 'vala'],
  default_options: [
    'cpp_std=c++11'
  ],
  license: 'GPL3+',
  meson_version: '>= 0.59',
  version: '47.beta'
)

add_project_arguments([
    '-include', 'config.h'
  ],
  language: 'c'
)

add_project_arguments([
    '--vapidir', join_paths(meson.current_source_dir(), 'lib')
  ],
  language: 'vala'
)

gnome = import('gnome')
i18n = import('i18n')

datadir     = get_option('datadir')
localedir   = get_option('localedir')
prefix      = get_option('prefix')
bindir      = get_option('bindir')
profile     = get_option('profile')

application_id = 'org.gnome.Sudoku'
if profile != ''
  application_id = 'org.gnome.Sudoku.' + profile
endif

glib_version = '2.40.0'

gee = dependency('gee-0.8')
gio = dependency('gio-2.0', version: '>= @0@'.format(glib_version))
glib = dependency('glib-2.0', version: '>= @0@'.format(glib_version))
gtk = dependency('gtk4', version: '>= 4.10.0')
adw = dependency('libadwaita-1', version: '>= 1.5')
json_glib = dependency('json-glib-1.0')
qqwing = dependency('qqwing', version: '>= 1.3.4')
threads = dependency('threads')

config_include_dir = include_directories('.')

conf = configuration_data()

conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALEDIR', join_paths(prefix, localedir))
conf.set_quoted('VERSION', meson.project_version())

configure_file(output: 'config.h',
  configuration: conf
)

subdir('data')
subdir('help')
subdir('lib')
subdir('po')
subdir('src')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
