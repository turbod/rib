define (require) ->
  utils = require 'utils'
  Handlebars = require 'handlebars'

  module = {}

  module.interpolate = (str, langobj, opts) ->
    return str unless _.isString str
    opts ?= {}
    langobj ?= {}
    ivars = []

    res = str.replace /#\{(.*?)\}/g, (whole, expr) ->
      if expr.match /^lang\./
        ret = langobj[expr.replace /^lang\./, '']
      else if expr.match /^cfg\./
        ret = utils.getConfig(expr.replace /^cfg\./, '')
      else
        plexpr = expr.match /^(\S+)\s+(.+)$/
        if plexpr
          expr = plexpr[1]
          items = plexpr[2].split '|'
          num = parseFloat opts.vars?[expr]
          # TODO: support languages having more complex pluralization
          descr = if _.isFinite(num) && items.length > 1 && num != 1
            items[1]
          else
            items[0]

        ret = opts.vars?[expr]
        ret += ' ' + descr if ret? && descr?
        ivars.push expr if opts.verbose

      if ret?
        ret = ret.toString() if _.isNumber ret
        ret = '' unless _.isString ret
      else if opts.keepVar
        ret = whole

      ret

    if opts.verbose then { res: res, ivars: ivars } else res

  module.preprocess = (langobj) ->
    preproc = {}
    ivars = {}

    for varname, val of langobj
      continue unless val.match /\#\{(cfg|lang)\./
      obj = module.interpolate val, langobj,
        keepVar : true
        verbose : true
      preproc[varname] = obj.res
      if obj.ivars
        for v in obj.ivars
          ivars[v] ?= []
          ivars[v].push varname

    preproc['__ivars'] = ivars

    _.extend {}, langobj, preproc

  module.isHtmlKey = (key) -> key?.match /_html$/

  module.getLang = (key, langobj, opts) ->
    opts ?= {}
    langobj ?= {}

    check = [ key ]
    check.push key + '_html' if key && !module.isHtmlKey key

    if check && opts.default
      check.push opts.default
      check.push opts.default + '_html' unless module.isHtmlKey opts.default

    for k in check
      break if str?
      str = langobj[k]
      key = k

    if str
      if opts.vars
        str = module.interpolate str, langobj,
          vars: opts.vars, keepVar: !!opts.htmlVars

      if (opts.encode ? opts.hbs) && !module.isHtmlKey key
        str = $.ntEncodeHtml str

      if opts.htmlVars
        str = module.interpolate str, langobj, vars: opts.htmlVars

      str = new Handlebars.SafeString str if opts.hbs

    str

  module
