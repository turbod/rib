define (require) ->
  mvconv = require 'mvconv'

  module = {}

  module._generic = (selector, elAttribute, converter) ->
    selector    : selector
    elAttribute : elAttribute
    converter   : converter

  module.bool = (selector, elAttribute) ->
    module._generic selector, elAttribute, mvconv.bool

  module.invBool = (selector, elAttribute) ->
    module._generic selector, elAttribute,  mvconv.invBool

  module.enabled = (selector) ->
    module.bool selector, 'enabled'

  module.disabled = (selector) ->
    module.invBool selector, 'enabled'

  module.displayed = (selector) ->
    module._generic selector, 'displayed'

  module.hidden = (selector) ->
    module._generic selector, 'hidden'

  module.class = (selector, converter) ->
    module._generic selector, 'class', converter

  module.boolClass = (selector, cname) ->
    module.class selector, (dir, val) ->
      if dir is 'ModelToView'
        if val then cname else ''

  module.html = (selector) ->
    module._generic selector, 'html', mvconv.html

  module.trimText = (selector, elAttribute) ->
    module._generic selector, elAttribute, mvconv.trimText

  module.float = (selector, elAttribute) ->
    module._generic selector, elAttribute, mvconv.float

  module.float0 = (selector, elAttribute) ->
    module._generic selector, elAttribute, mvconv.float0

  module.strToInt = (selector, elAttribute) ->
    module._generic selector, elAttribute, mvconv.strToInt

  module.arrayify = (selector, elAttribute) ->
    module._generic selector, elAttribute, mvconv.arrayify

  module.arrayifyCompact = (selector, elAttribute) ->
    module._generic selector, elAttribute, mvconv.arrayifyCompact

  module
