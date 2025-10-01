{
  'targets': [
    {
      # Node-GYP strips the first "lib" for some reason, so here
      # "liblibpq" is _intentional_, as it will produce a module
      # called "libpq.node" in "./build/Release" 
      'target_name': 'liblibpq',
      'sources': [
        'src/connection.cc',
        'src/connect-async-worker.cc',
        'src/addon.cc'
      ],
      'include_dirs': [
        '<!(node -e "require(\'nan\')")',
        'dist/include'
      ],
      'libraries': [
        '../dist/lib/libpgcommon_shlib.a',
        '../dist/lib/libpgport_shlib.a',
        '../dist/lib/libpq.a',
      ],
      'ldflags': [ '<!@(./dist/bin/pg_config --ldflags)' ],
      'conditions' : [
        ['OS=="linux"', {
            'cflags': ['-fvisibility=hidden']
        }],
        ['OS=="mac"', {
          'xcode_settings': {
            'CLANG_CXX_LIBRARY': 'libc++',
            'MACOSX_DEPLOYMENT_TARGET': '11.0'
          }
        }]
      ]
    }
  ]
}
