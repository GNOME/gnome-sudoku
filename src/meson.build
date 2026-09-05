subdir ('blueprints')

if profile == 'Devel'
  rust_target = 'dev'
else
  rust_target = 'release'
endif

build_root = meson.project_build_root()
source_root = meson.project_source_root()

resources = gnome.compile_resources(
  'gnome-sudoku',
  resource_files,
  dependencies: blueprints,
  source_dir: [
    join_paths(build_root, 'data'), #metainfo
    join_paths(source_root, 'data'), #styles
    join_paths(meson.current_build_dir(), 'blueprints') #blueprints
  ],
  gresource_bundle: true
)

cargo_options = ['--manifest-path', source_root / 'Cargo.toml']
cargo_options += ['--target-dir', build_root / 'src']

cargo_env = {
  'CARGO_HOME': build_root / 'cargo-home',
  'APP_ID': app_id,
  'GETTEXT_PACKAGE': meson.project_name(),
  'LOCALEDIR': join_paths(prefix, localedir),
  'VERSION': meson.project_version(),
  'GNOME_SUDOKU_RESOURCES_FILE': resources.full_path(),
  'QQWING_EASY': join_paths(meson.project_source_root(), 'test', 'qqwing-simple'),
  'QQWING_MEDIUM': join_paths(meson.project_source_root(), 'test', 'qqwing-easy'),
  'QQWING_HARD': join_paths(meson.project_source_root(), 'test', 'qqwing-intermediate'),
  'QQWING_VERY_HARD': join_paths(meson.project_source_root(), 'test', 'qqwing-expert')
}

meson.add_devenv(cargo_env)

run_target (
  'cargo-fix',
  command: [cargo, 'fix', cargo_options],
  env: cargo_env
)

run_target (
  'cargo-test',
  command: [cargo, 'test', cargo_options, '--', '--nocapture'],
  env: cargo_env
)

# Build binary
cargo_build = custom_target(
  'cargo-build',
  build_by_default: true,
  build_always_stale: true,
  output: 'src',
  console: true,
  depends: [resources],
  env: cargo_env,
  command: [
    cargo,
    'build',
    cargo_options,
  ],
)

custom_target(
  'cp-binary',
  depends: cargo_build,
  build_by_default: true,
  build_always_stale: true,
  install: true,
  install_dir: get_option('bindir'),
  output: meson.project_name(),
  command: [
    'cp',
    'src' / 'debug' / meson.project_name(),
    '@OUTPUT@',
  ],
)
