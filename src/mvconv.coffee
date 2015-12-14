define (require) ->
  mvconv = {}

  mvconv.html = (dir, val) ->
    if dir is 'ModelToView'
      $.ntEncodeHtml val
    else
      $.ntDecodeHtml val

  mvconv.float = (dir, val) ->
    if dir is 'ViewToModel'
      val = parseFloat val
      val = null if isNaN val

    val

  mvconv.float0 = (dir, val) ->
    if dir is 'ViewToModel'
      val = parseFloat val
      val = 0 if isNaN val

    val

  mvconv.strToInt = (dir, val) ->
    if dir is 'ViewToModel'
      val = parseInt val
      val = null if isNaN val
    else
      val = if val? then val.toString() else ''

    val

  mvconv.flag = (dir, val) ->
    if dir is 'ViewToModel'
      val = if val then '1' else ''
    val

  mvconv.trimText = (dir, val) ->
    if dir is 'ViewToModel'
      $.trim val
    else
      val ? ''

  mvconv.seqNum = (dir, val) ->
    if dir is 'ModelToView'
      val = val + '.' if val?
    val

  mvconv.seqNumHash = (dir, val) ->
    if dir is 'ModelToView'
      val = '#' + val if val?
    val

  mvconv.bool = (dir, val) ->
    !!val if dir is 'ModelToView'

  mvconv.invBool = (dir, val) ->
    !val if dir is 'ModelToView'

  mvconv.arrayify = (dir, val) ->
    if dir is 'ModelToView'
      if _.isArray val then val[0] else val
    else
      if _.isArray val then val.slice(0, 1) else [ val ]

  mvconv.arrayifyCompact = (dir, val) ->
    ret = mvconv.arrayify.apply @, arguments
    ret = _.compact ret if dir is 'ViewToModel'
    ret

  mvconv
