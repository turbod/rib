fs = require 'fs'
path = require 'path'

# ---- FUNCS ------------------------------------------------------------------

die = (code, msg) ->
  console.error 'Error: ' + msg
  process.exit code

runSync = ->
  args = [].slice.call arguments
  cmd = args.shift() + 'Sync'
  ret

  try
    ret = fs[cmd].apply @, args
  catch e
    die 2, cmd + ' - ' + e.message

  ret

# ---- ARGS & STARTUP ---------------------------------------------------------

[language, keyfile, transfile, nlspath] = process.argv[2 .. 5]
nlsfile = process.argv[6] || 'lang.coffee'

usage = 'Usage: ' + process.argv[0] + ' ' +
  path.basename(process.argv[1]) + ' <language> <keyfile> <translated-file> ' +
  '<nls-path> [<nls-file>]'

die 1, usage unless language && keyfile && transfile && nlspath

nlspath += '/' unless nlspath.match /\/$/

destpath = nlspath + language

runSync 'mkdir', destpath unless runSync 'exists', destpath

destfile = destpath + '/' + nlsfile

# ---- PROCESS ----------------------------------------------------------------
# NOTE: readFile works well for small files, use streams if lang grows too big

keys = runSync 'readFile', keyfile, 'utf8'
keys = keys.split /\r?\n/

values = runSync 'readFile', transfile, 'utf8'
values = values.split /\r?\n/

for key, i in keys
  value = values[i]

  if key && value
    runSync 'writeFile', destfile, 'define\n' unless has_cont
    has_cont = true

    runSync 'appendFile', destfile, '  ' + key + ": '" +
      value.replace(/\'/g, '\\\'') + "'\n"

console.log if has_cont
  'Successfully created: ' + destfile
else
  'No data found'
