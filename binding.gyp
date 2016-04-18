{
  'target_defaults': {
    'include_dirs': [
      'src',
      'node',
    ],

    'defines': [
      'NODEJS',
    ],

    "link_settings": {
      'ldflags': [
          # '-Wl,-no-undefined',
      ],
    }
  },

  'targets': [
    {
      'target_name': 'scid',
      'sources': [
	'src/bytebuf.cpp',
	'src/date.cpp',
	'src/dstring.cpp',
	'src/filter.cpp',
	'src/game.cpp',
	'src/gfile.cpp',
	'src/index.cpp',
	'src/matsig.cpp',
	'src/mfile.cpp',
	'src/misc.cpp',
	'src/namebase.cpp',
	'src/pgnparse.cpp',
	'src/position.cpp',
	'src/sortcache.cpp',
	'src/stored.cpp',
	'src/textbuf.cpp',
        'src/scidbase.cpp',
        'src/dbasepool.cpp',
        'src/sc_base.cpp',
        'src/tkscid.cpp',
        'node/jsscid.cpp',
      ],
    },
  ],
}
