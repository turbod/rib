requirejs = require '/usr/bin/r.js'
fs = require 'fs'

# ---- ARGS & STARTUP ---------------------------------------------------------

outfile = process.argv[2]
basedir = process.argv[3] || process.cwd()
basedir += '/' unless basedir.match /\/$/

# filter keys if needed
filterfile = process.argv[4]

# ---- PROCESS ----------------------------------------------------------------

requirejs [ basedir + 'js/nls/lang.js' ], (lang) ->
  keys = []
  values = []

  if filterfile
    filterkeys = fs.readFileSync filterfile, 'utf8'
    filterkeys = filterkeys.split /\r?\n/

  for key in (filterkeys || Object.keys(lang.root))
    value = lang.root[key] || ''
    keys.push key
    values.push value.replace /\n/g, '\\n'

  values_txt = values.join '\n'

  if outfile
    [ outfile, outfile + '.keys' ].forEach (fname, idx) ->
      data = if idx then keys.join('\n') else values_txt
      fs.writeFile fname, data, (err) ->
        if err
          console.error err
          process.exit 1
        else
          console.log 'File saved: ' + fname
  else
    console.log values_txt
