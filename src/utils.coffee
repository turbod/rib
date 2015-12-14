define (require) ->
  _ = require 'underscore'
  vent = require 'vent'
  moment = require 'moment'

  require 'jquerynt'
  require 'base64'
  require 'date'

  utils =
    REG_EMAIL  : '[-_a-z0-9]+(\\.[-_a-z0-9]+)*@[-a-z0-9]+(\\.[-a-z0-9]+)' +
                 '*\\.[a-z]{2,6}'
    REG_IP     : '([01]?\\d\\d?|2[0-4]\\d|25[0-5])' +
                 '(\\.([01]?\\d\\d?|2[0-4]\\d|25[0-5])){3}'
    REG_HOST   : '[a-z\\d]([a-z\\d\\-]{0,61}[a-z\\d])?' +
                 '(\\.[a-z\\d]([a-z\\d\\-]{0,61}[a-z\\d])?)*'
    REG_DT_DB  : '\\d{4}(-\\d{2}){2}\\s+\\d{2}(:\\d{2}){2}(\\.\\d+)?'
    REG_DT_ISO : '\\d{4}(-\\d{2}){2}T\\d{2}(:\\d{2}){2}(\\.\\d{1,3})?'
    FMT_DT_DB  : 'YYYY-MM-DD HH:mm:ss'
    FMT_DT_ISO : 'YYYY-MM-DDTHH:mm:ss'

  for fmt in [ 'FMT_DT_DB', 'FMT_DT_ISO' ]
    utils[fmt + '_MS'] = utils[fmt] + '.SSS'

  utils.xor = (a, b) ->
    (a || b) && !(a && b)

  utils.capitalize = (str) ->
    return unless str?
    str = str.toString()
    str.charAt(0).toUpperCase() + str.slice(1)

  utils.extendMethod = (to, from, methodName) ->
    if _.isFunction(to[methodName]) && _.isFunction(from[methodName])
      old = to[methodName]
      to[methodName] = ->
        oldReturn = old.apply @, arguments
        from[methodName].apply @, arguments
        oldReturn

  utils.mixin = (mixins..., classRef) ->
    to = classRef::
    for mixin in mixins
      for method of mixin
        utils.extendMethod to, mixin, method
      _.defaults to, mixin
      _.defaults to.events, mixin.events
    classRef

  utils.obj2Array = (obj, opts) ->
    ret = []
    if _.isObject obj
      keyname = opts?.keyname || 'type'
      for key, val of obj
        val = if _.isObject val
          _.clone val
        else
          value: val
        val[keyname] = key
        ret.push val

    ret

  utils.getProp = (obj, prop, opts) ->
    if opts?.attr && obj instanceof Backbone.Model
      obj.get prop
    else
      _.result obj, prop

  # obj, srcobj, props as args || props array
  utils.adoptProps = ->
    args = [].slice.call arguments
    obj = args.shift()
    srcobj = args.shift()
    if _.isObject(obj) && _.isObject(srcobj)
      keys = if _.isArray args[0] then args[0] else args
      _.extend obj, _.pick srcobj, keys

  utils._chkRegExp = (str, re_name) ->
    re = new RegExp "^#{utils[re_name]}$", 'i'
    str if str?.toString().match re

  utils.chkEmail = (str) ->
    utils._chkRegExp str, 'REG_EMAIL'

  utils.chkIP = (str) ->
    utils._chkRegExp str, 'REG_IP'

  utils.chkHost = (str) ->
    utils._chkRegExp str, 'REG_HOST' if str?.toString().length <= 255

  utils.wrap = (str, wrapper, opts) ->
    return str unless str && wrapper
    opts ?= {}
    qs = if _.isArray wrapper
      wrapper
    else if opts.split && wrapper.length > 1
      wrapper.split ''
    else
      [ wrapper, wrapper ]

    if opts?.quote
      qs = _.map qs, (q) -> '\\' + q

    qs[0] + str + qs[1]

  utils.extractKeywords = (str, opts) ->
    opts ?= {}
    ret = '' : []
    str = $.trim str.toString() if str?
    if str
      opts = '"' : '' if _.isEmpty opts

      _sortFunc = (a, b) ->
        if a[1] < b[1]
          1
        else if a[1] > b[1]
          -1
        else
          0

      markitems = _.pairs opts
      markitems.sort _sortFunc

      for markitem in markitems
        [mark, type] = markitem
        ret[type] ?= []

        qre = utils.wrap '(.*?)', mark, quote: true, split: true
        str = str.replace new RegExp(qre, 'g'), (match, capture, pos) ->
          capture = $.trim capture
          ret[type].push [capture, pos] if capture
          Array(match.length + 1).join(' ')

      str = str.replace /(\S+)/g, (match, capture, pos) ->
        ret[''].push [capture, pos]

      for type of ret
        ret[type] = _.map ret[type].sort(_sortFunc).reverse(), (arr) -> arr[0]

    if _.keys(ret).length == 1 then ret[''] else ret

  utils.throwError = (desc,name) ->
    name = 'Error' unless name?
    desc = 'unknown' unless desc?
    err = new Error desc
    err.name = name
    throw err

  # TODO: advanced string based ranking
  # Ranking algorithm rules:
  # 1. For the first element choose the 2. character
  # 2. When appending try to choose the next character in proportion to the last
  # 3. When inserting try to calculate the median
  #
  # A, B, C, D, E
  # (Q) B
  # (Q) C   <--- before C, insert: BC
  # (Q) D
  # (Q) E
  # (Q) EC  <--- before EC, insert: EB
  # (Q) ED
  # (Q) EE  <--- before EE, insert: EDC
  # (Q) EEC
  # (Q) ...

  utils.calcRank = (prev, next, opts) ->
    if prev? && !_.isNumber(prev) || next? && !_.isNumber(next)
      utils.throwError 'Invalid parameters for calcRank'

    if prev? && !next?
      prev + 1
    else if !prev? && next?
      if opts?.signed
        next - 1
      else
        next / 2
    else if prev? && next?
      (next + prev) / 2
    else
      1

  utils.numToLetters = (num) ->
    num = parseInt num
    return unless _.isFinite num

    ret = ''
    while num > 0
      mod = (num - 1) % 26
      ret = String.fromCharCode(65 + mod) + ret
      num = parseInt((num - mod) / 26)

    ret

  utils.cookie = (key, value, options) ->
    if arguments.length > 1 && (!/Object/.test(Object.prototype.toString.call(value)) || !value?)
      options = $.extend {}, options

      if !value?
        options.expires = -1

      if typeof options.expires == 'number'
        days = options.expires
        t = options.expires = new Date()
        t.setDate t.getDate() + days

      value = String value

      return document.cookie = [
        encodeURIComponent(key)
        '='
        if options.raw then value else encodeURIComponent(value)
        if options.expires then '; expires=' + options.expires.toUTCString() else ''
        if options.path then '; path=' + options.path else ''
        if options.domain then '; domain=' + options.domain else ''
        if options.secure then '; secure' else ''
      ].join ''

    options = value || {}
    decode = if options.raw then (s) -> return s else decodeURIComponent

    pairs = document.cookie.split '; '

    i = 0
    pair = undefined

    while pair = pairs[i] && pairs[i].split /\=(.+)?/
      return decode(pair[1] || '') if decode(pair[0]) is key
      i++

    return null

  utils.decodeCookie = (key) ->
    val = utils.cookie key
    Base64.decode val if val?

  utils.getVarSrc = (src) ->
    if src is 'config' then window.ntConfig else window.ntStatus

  utils.getVar = (src, varname, opts) ->
    src = utils.getVarSrc src
    if varname? && _.isObject src
      varname = varname.toString().split '.'
      ret = src
      for i in [0 .. varname.length - 1]
        if !_.isObject ret
          ret = undefined
          break
        ret = ret[varname[i]]

      if !opts?.ref
        if _.isArray ret
          ret = _.extend [], ret
        else if _.isObject ret
          ret = _.extend {}, ret

    ret

  utils.getConfig = (varname, opts) ->
    utils.getVar 'config', varname, opts

  utils.getStatus = (varname, opts) ->
    ret = utils.getVar 'status', varname, opts
    utils.delStatus varname

    ret

  utils.setVar = (src, varname, value) ->
    if _.isObject varname
      obj = varname
    else
      obj = {}
      obj[varname] = value

    src = utils.getVarSrc src
    _.extend src, obj

  utils.setConfig = (varname, value) ->
    utils.setVar 'config', varname, value

  utils.setStatus = (varname, value) ->
    utils.setVar 'status', varname, value

  utils.delStatus = (varname) ->
    src = utils.getVarSrc 'status'
    delete src[varname] if varname?

  utils.extractVars = (str) ->
    vars = []
    re = /#\{([^\s\}]+).*?\}/g
    while match = re.exec str
      vars.push match[1]
    vars

  utils.maxVersion = ->
    args = [].slice.call arguments
    limit = 4
    _.max args, (arg) ->
      arg = arg.toString().split '.'
      arg.splice limit
      _.reduce arg, (memo, val, idx) ->
        val = if _.isFinite(val) then parseInt(val) else 0
        memo + (Math.pow(10, (limit - idx) * 3) * val)
      , 0

  utils.isNewerVersion = (v1, v2) ->
    v1 isnt v2 && utils.maxVersion(v1, v2) is v2

  utils._sort = (a, b, opts) ->
    ret = if b? && (!a? || a < b)
      -1
    else if a? && (!b? || a > b)
      1

    ret *= -1 if ret && opts?.desc
    ret

  utils.sort = (a, b, props, opts) ->
    opts ?= {}
    ret = 0

    if props
      props = [ props ] unless _.isArray props
      for prop in props
        cmp = []
        pname = if _.isObject(prop) then prop.name else prop
        popts = if _.isObject(prop) then _.clone(prop.opts) else {}
        _.defaults popts, opts, attr: true
        for obj in [a, b]
          if _.isArray pname
            for altpname in pname
              tmp = utils.getProp obj, altpname, popts
              break if tmp?
          else
            tmp = utils.getProp obj, pname, popts

          if popts.natural && _.isString tmp
            tmp = tmp.replace(/(\d+)/g, "0000000000$1")
              .replace(/0*(\d{10,})/g, "$1").replace(/@/g,' ')
            tmp = tmp.toLowerCase()
          cmp.push tmp

        ret = utils._sort.apply @, cmp.concat(popts)
        break if ret
    else
      ret = utils._sort a, b, opts

    ret

  utils.processByFuncs = (val, funcs, ctx) ->
    return val unless funcs?

    funcs = [ funcs ] unless _.isArray funcs
    for func in funcs
      f = if _.isFunction(func)
        func
      else if _.isFunction(utils[func])
        utils[func]

      val = f.call ctx, val if f

    val

  utils.splitName = (str) ->
    str = $.trim str
    lname = if str.match /,/
      arr = str.split(/\s*,\s*/)
      arr.shift()
    else
      arr = str.split(/\s+/)
      arr.pop()

    fname = arr.join ' '

    [ $.trim(fname), $.trim(lname) ]

  utils.joinName = (first, last) ->
    names = []
    names.push n for n in [ $.trim(first), $.trim(last) ] when n
    names.join ' '

  utils.parseJSON = (str) ->
    try
      ret = JSON.parse str
    ret

  utils.getProtocol = ->
    window.location?.protocol

  utils.getHost = ->
    window.location?.host

  utils.getOrigin = ->
    utils.getProtocol() + '//' + utils.getHost()

  utils.getUrlParams = ->
    _.object _.compact _.map location.search[1..].split('&'), (item) ->
      if item then item.split '='

  utils.shareUrlSocial = (url, prov) ->
    base = if prov is 'FB'
      'https://www.facebook.com/sharer/sharer.php?u='
    else
      'https://plus.google.com/share?url='

    base + encodeURIComponent(url)

  utils.link = (link, opts) ->
    opts ?= {}
    text = $.ntEncodeHtml opts.text || link.replace /^https?:\/\//, ''
    ret = "<a href=\"#{link}\""
    ret += " target=\"#{opts.target}\"" if opts.target
    ret + ">#{text}</a>"

  utils.mailtoLink = (recip, opts) ->
    lnk = "mailto:#{recip}"
    if _.isEmpty opts
      lnk
    else
      params = []
      for param of opts
        params.push param + '=' + encodeURIComponent(opts[param])
      lnk + '?' + params.join('&')

  utils.getFrac = (str, opts) ->
    frac = str?.toString().match(/\.\d+$/)?[0]
    if frac
      prec = opts?.prec || 3
      frac = frac.substr(0, prec + 1)
    frac

  utils.isValidDbDate = (str) ->
    utils._chkRegExp str, 'REG_DT_DB'

  utils.isValidIsoDate = (str) ->
    utils._chkRegExp str, 'REG_DT_ISO'

  utils.isSameDay = (d1, d2) ->
    return false unless d1? && d2?
    utils.formatDate(d1, iso: true) is utils.formatDate(d2, iso: true)

  utils.parseDbDate = (str) ->
    if utils.isValidDbDate str
      if utils.getConfig 'disable_utc'
        moment str
      else
        moment.utc(str).local()
    else
      str

  utils.dbDateToIso = (str) ->
    m = utils.parseDbDate str
    if _.isObject m
      fmt = m.format utils.FMT_DT_ISO
      fmt += frac if frac = utils.getFrac(str)
      fmt
    else
      str

  utils.isoToDbDate = (str) ->
    if utils.isValidIsoDate str
      fmt = moment str
      fmt = fmt.utc() unless utils.getConfig 'disable_utc'
      fmt = fmt.format utils.FMT_DT_DB
      fmt += frac if frac = utils.getFrac(str)
      fmt
    else
      str

  utils.parseDate = (dm, opts) ->
    format = opts?.format
    if format
      ret = moment dm, format
    else
      if _.isString dm
        dm = utils.parseDbDate dm

        if _.isString(dm) && !utils.isValidIsoDate(dm)
          dm = if dm.toLowerCase() is 'now'
            utils.getDateTime()
          else
            df = utils.getConfig('date_format') || 'D MMM YYYY'
            if (m = moment dm, df, true).isValid()
              m
            else
              df = utils.getConfig('short_date_format') || 'D MMM'
              if (m = moment dm, df, true).isValid()
                m
              else
                Date.parse dm

      ret = moment dm

    ret

  utils.parseTime = (dm, opts) ->
    opts ?= {}

    if _.isString dm
      dt = dm
      dm = $.trim dm
      if _.isFinite dm
        dm += 'a'
      else if _.isFinite dm.replace /\s+/g, ''
        dm = dm.replace /\s+/g, ':'

    ret = utils.parseDate dm, opts

    if dt && !utils.isValidTime ret
      ret = moment dt, [
        'hh:mm', 'h:mma', 'hh:mma', 'hh:mm a',
        'h:mm a', 'ha', 'h a', 'hh a', 'h:mm'
      ], true
      ret = null unless ret && utils.isValidDate ret

    if ret && opts.ampmBorderHour && ret.hours() < 12 &&
        ret.hours() < opts.ampmBorderHour
      ret.add 12, 'hours'

    ret

  utils.parseMidnight = (str) ->
    if _.isString str
      str.match(/(\s|^)12(:00?){0,2}\s*a/) ||
        str.match(/(\s|^)00?(:00?){0,2}(\s|$)/)
    else
      false

  utils.formatDate = (dm, opts) ->
    opts ?= {}
    m = if utils.isMoment dm
      dm.clone()
    else
      utils.parseDate dm

    if m
      if opts.time
        if opts.iso || opts.db
          m = m.utc() if opts.db && !utils.getConfig 'disable_utc'
          fmt = 'FMT_DT_' + (if opts.iso then 'ISO' else 'DB')
          m.format utils[ fmt + (if opts.ms then '_MS' else '') ]
        else
          utils._formatDateTime m
      else if opts.short
        utils._formatShortDate m
      else if opts.iso || opts.db
        m = m.utc() if opts.db && !utils.getConfig 'disable_utc'
        m.format utils.FMT_DT_DB.split(' ')[0]
      else if opts.format
        m.format opts.format
      else
        utils._formatDate m
    else
      ''

  utils.formatDateTime = (dm, opts) ->
    utils.formatDate dm, _.extend {}, opts, time: true

  utils.formatDateTimeSmart = (dm, opts) ->
    opts = _.extend time: true, opts

    # TODO: more intelligence: omitting year, using yesterday, tomorrow etc.
    m = if dm? && _.isString dm
      utils.parseDate dm
    else
      dm

    return '' unless m

    if opts.time
      time_format = if m.minutes() is 0
        utils.getConfig('time_only_hour_format') || 'ha'
      else
        utils.getConfig('time_format') || 'h:mma'

    fmt = if utils.getDateTime('YYYY-MM-DD') is moment(m).format('YYYY-MM-DD')
      time_format
    else
      dfmt = if !opts.showYear && utils.isDateWithinAYear m
        utils.getConfig('short_date_format') || 'D MMM'
      else
        utils.getConfig('date_format') || 'D MMM YYYY'
      if time_format then "#{dfmt} #{time_format}" else dfmt

    if fmt then m.format fmt else opts.todayStr || 'Today'

  utils.formatTime = (dm, opts) ->
    m = if dm? && _.isString dm
      utils.parseTime dm
    else
      dm

    if m
      if opts?.format
        m.format opts.format
      else
        utils._formatTime m
    else
      ''

  utils._formatDate = (m) ->
    m.format(utils.getConfig('date_format') || 'D MMM YYYY')

  utils._formatTime = (m) ->
    m.format(utils.getConfig('time_format') || 'h:mm a')

  utils._formatShortDate = (m) ->
    m.format(utils.getConfig('short_date_format') || 'D MMM')

  utils._formatDateTime = (m) ->
    # TODO: datetime format
    utils._formatDate(m) + ' ' + utils._formatTime(m)

  utils.formatTextMonth = (dm) ->
    m = moment dm
    m.format(utils.getConfig('monthformat') || 'MMMM YYYY')

  utils.isDateWithinAYear = (m) ->
    input = moment(m)
    now = utils.getDateTime()
    input.isAfter(now.clone().subtract('months', 6)) &&
      input.isBefore(now.add('months', 6))

  utils.isValidDate = (m) ->
    m? && m.toDate().toString() != 'Invalid Date' && 2000 < m.year() < 2099

  utils.isValidTime = (m) ->
    _.isObject(m) && (d = m.toDate()).toString() != 'Invalid Date' &&
      (0 <= d.getHours() <= 23) &&
      (0 <= d.getMinutes() <= 59) &&
      (0 <= d.getSeconds() <= 59)

  utils.isMoment = (obj) ->
    moment.isMoment obj

  utils.isDateBetween = (sdate, edate, date) ->
    date = if date? then utils.parseDate(date) else utils.getDateTime()
    sdate = if sdate? then utils.parseDate(sdate) else date
    edate = if edate? then utils.parseDate(edate) else date

    (sdate.isBefore(date) || sdate.isSame(date)) &&
      (edate.isAfter(date) || edate.isSame(date))

  utils.isToday = (m) ->
    m.startOf('day').isSame utils.getDateTime().startOf 'day'

  utils.splitIsoDateTime = (dt) ->
    if _.isString(dt) then dt.split /[\s+T]/ else []

  utils.joinIsoDateTime = (dtarr, sep) ->
    sep = 'T' unless sep
    if _.isArray(dtarr) then dtarr.join(sep) else ''

  utils.getDateTime = (fmt) ->
    dt = moment()
    offset = utils.getConfig 'time_offset_ms'
    dt.add parseInt(offset), 'milliseconds' if offset
    if fmt then dt.format(fmt) else dt

  utils.getTimeMs = ->
    utils.getDateTime().valueOf()

  utils.getIsoDateTime = (opts) ->
    opts ?= {}
    d = utils.getDateTime().toDate()
    opts.year ?= d.getFullYear()
    opts.month ?= d.getMonth()
    opts.day ?= d.getDate()
    opts.hour ?= d.getHours()
    opts.min ?= d.getMinutes()
    opts.sec ?= d.getSeconds()

    d = new Date(opts.year, opts.month, opts.day, opts.hour, opts.min, opts.sec)

    m = moment(d)
    m.format utils.FMT_DT_ISO

  utils.getIsoDate = (opts) ->
    dt = utils.getIsoDateTime opts
    dt = utils.splitIsoDateTime dt
    dt[0]

  utils.getIsoYearMonth = (y, m) ->
    d = if y && m then new Date(y, m, 0) else utils.getDateTime().toDate()
    moment(d).format 'YYYY-MM'

  utils.extractIsoDateTime = (opts) ->
    opts ?= {}
    dt = opts.dt || utils.getIsoDateTime()
    dtarr = utils.splitIsoDateTime dt
    if opts.date
      dtarr[0]
    else if opts.time
      dtarr[1]
    else
      dtarr

  utils.dateAdd = (date, addValues, fmtopts) ->
    m = utils.parseDate date
    addValues = milliseconds: addValues unless _.isObject addValues

    for prop of addValues
      m.add prop, addValues[prop]

    if _.isEmpty fmtopts
      m
    else
      utils.formatDate m, fmtopts

  utils.dateDiff = (date, prop, base) ->
    base = utils.getDateTime() unless base
    date = moment date
    date.diff base, prop

  utils.updateMoment = (dm, src, opts) ->
    opts ?= {}
    parts = if opts.parts
      if _.isArray(opts.parts) then opts.parts else [ opts.parts ]
    else if opts.time
      [ 'hour', 'minute', 'second' ]
    else if opts.date
      [ 'year', 'month', 'date' ]

    if src && parts
      dm.set v, src.get v for v in parts

    dm

  utils.updateIsoDateTime = (dt, opts) ->
    fmtarr = utils.splitIsoDateTime utils.FMT_DT_ISO
    date = opts?.date
    date = moment(date).format fmtarr[0] if _.isObject date
    time = opts?.time
    time = moment(time).format fmtarr[1] if _.isObject time
    dtarr = utils.extractIsoDateTime dt: dt
    dtarr[0] = date if date
    dtarr[1] = time if time

    utils.joinIsoDateTime dtarr

  utils.getDuration = (val, unit) ->
    moment.duration(val, unit)._data

  utils.formatHMS = (secs) ->
    secs ?= 0
    _m = 60
    _h = 60 * _m

    if secs >= _h
      h = parseInt secs / _h
      secs = secs % _h
    m = parseInt secs / _m
    s = parseInt secs % _m

    m = '0' + m if m < 10
    s = '0' + s if s < 10

    ret = m + ':' + s
    ret = h + ':' + ret if h
    ret

  utils.formatFileSize = (size, opts) ->
    opts ?= {}
    size = parseFloat size
    if _.isFinite size
      size /= 1024 * 1024
      size = if opts.decDigits
        size.toFixed(opts.decDigits)
      else
        Math.round(size)

      size += 'M'
    else
      size = opts.na ? 'NA'

    size

  utils.roundTo = (val, prec) ->
    val = parseFloat val
    if _.isFinite val
      prec = if _.isFinite(prec) then prec else 0
      parseFloat val.toFixed prec

  utils.mean = (arr) ->
    arrLen = arr?.length
    if arrLen > 1
      mean = arr.reduce (a, b) -> a + b
      mean /= arrLen
    else if arrLen > 0
      mean = arr[0]
    mean

  utils.stDev = (arr) ->
    mean = utils.mean arr
    l = arr.length

    sum = 0
    while l--
      sum += Math.pow(arr[l] - mean, 2)
    Math.sqrt(sum / (arr.length || 1))

  utils.reloadPage = (opts) ->
    href = if _.isObject opts then opts.href else opts
    window.location.href = href ? window.location.href

  utils.randomGuid = (length) ->
    length ?= 32
    possible = 'abcdef0123456789'

    text = ''
    text += possible.charAt(Math.floor(Math.random() * possible.length)) \
      for i in [ 1 .. length ]
    text

  utils.getIframeDocument = (iframe) ->
    return null unless iframe
    if iframe.contentWindow
      iframe.contentWindow.document
    else
      iframe.contentDocument

  utils
