rockspec_format = '3.0'
package = 'sbarlua'
version = '0.1.0-1'
source = {
  url = 'https://github.com/FelixKratz/SbarLua/archive/dba9cc421b868c918d5c23c408544a28aadf2f2f.tar.gz',
  dir = 'SbarLua-dba9cc421b868c918d5c23c408544a28aadf2f2f',
}
description = {
  summary = 'Pinned SbarLua API for the dotfiles SketchyBar configuration',
  homepage = 'https://github.com/FelixKratz/SbarLua',
  license = 'GPL-3.0',
}
supported_platforms = {'macosx'}
dependencies = {'lua >= 5.5, < 5.6'}
build = {
  type = 'builtin',
  modules = {
    sketchybar = {
      sources = {'src/sketchybar.c', 'src/parsing.c', 'src/cJSON.c'},
      incdirs = {'src'},
    },
  },
}
