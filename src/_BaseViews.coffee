define (require) ->
  _ = require 'underscore'
  Backbone = require 'backbone'
  ModelBinder = require 'modelbinder'
  Handlebars = require 'handlebars'
  utils = require 'utils'
  vent = require 'vent'

  Base = {}

  # ---- View -----------------------------------------------------------------

  class Base.View extends Backbone.View
    getClass: => @_class

    notifier: _.extend {}, Backbone.Events

    notifierPub: =>
      args = Array.prototype.slice.call arguments
      @notifier.trigger.apply @notifier, args if args[0]?

    notifierSub: (event, callback) =>
      if _.isObject event
        events = event
      else
        (events = {})[event] = callback

      @listenTo @notifier, eventName, events[eventName] for eventName of events

    sharedStatus: _.extend {}

    adoptOptions: =>
      utils.adoptProps @, @options, [].slice.call arguments

    constructor: (options) ->
      @setDomId = true
      @fadeOnRemove = true
      @options = options || {}
      @embedded = true if @options.el
      super

      id = @$el.attr('id')
      @$el.attr('id', @model.modelid()) if !id? && @model && @setDomId

      @$el.data 'backbone-view', @

      @adoptOptions 'template', 'partials', 'modelBindOnRender'

      if _.isFunction @initTplVars
        @tplvars ?= {}
        @initTplVars()

      @modelBindOnRender ?= true

      @initModelDomBindings() if _.isFunction @initModelDomBindings

      # initialize view, DOM, notifier events
      for type in [ 'Events', 'DomEvents', 'NotifierSub' ]
        func = 'init' + type
        if _.isFunction @[func]
          isDomEvents = type is 'DomEvents'
          @events ?= {} if isDomEvents
          @[func]()
          @delegateEvents() if isDomEvents

      @dim = @options.dim if @options.hasOwnProperty 'dim'

      if @dim
        @notifierSub 'cont:adjust:height', @adjustHeight
        @listenTo @, 'render', @adjustHeight

    addTplVar: (varname, value) =>
      if _.isObject varname
        vars = varname
      else
        (vars = {})[varname] = value

      @tplvars ?= {}
      _.extend @tplvars, vars

    delTplVar: (varname) =>
      delete @tplvars[varname]

    extendTplVar: (varname, value) =>
      if _.isObject varname
        vars = varname
      else
        (vars = {})[varname] = value

      for v of vars
        @tplvars[v] ?= if _.isArray vars[v] then [] else {}

        if _.isArray(@tplvars[v]) && _.isArray(vars[v])
          @tplvars[v].push elem for elem in vars[v]
        else if _.isObject(@tplvars[v]) && _.isObject(vars[v])
          _.extend @tplvars[v], vars[v]
        else
          utils.throwError 'Incompatible types!', 'extendTplVar'

    addModelDomBinding: (fld, binding) =>
      if _.isObject fld
        bindings = fld
      else
        (bindings = {})[fld] = binding

      @modelDomBindings ?= {}
      _.extend @modelDomBindings, bindings

    delModelDomBinding: (flds) =>
      if @modelDomBindings
        flds = [ flds ] unless _.isArray flds
        delete @modelDomBindings[fld] for fld in flds

    toggleModelDomBindings: (set) =>
      if set
        if @el && @model && @modelDomBindings
          @modelBinder = new ModelBinder() unless @modelBinder
          @modelBinder.bind @model, @$el, @modelDomBindings, @modelBinderOpts
      else if @modelBinder
        @modelBinder.unbind()

    initEvents: =>
      @listenTo @, 'domadd', @afterDomAdd if _.isFunction @afterDomAdd
      if @model
        @listenTo @model, 'destroy', @remove unless @model.collection
        @listenTo @model, 'fetch', @render

    addDomEvent: (selector, callback) =>
      if _.isObject selector
        domEvents = selector
      else
        (domEvents = {})[selector] = callback

      _.extend @events, domEvents

    delDomEvent: (selector) =>
      delete @events[selector]

    initDomEvents: =>
      if @model?.collection?.rankAttr
        @addDomEvent 'sortItem', (e, opts) =>
          e.stopPropagation()
          @sortItem opts

    sortItem: (opts) =>
      if @model?.collection?.rankAttr
        @model.collection.sortItem @model, @model.collection, opts
      else
        utils.throwError 'No sorted collection found for model', 'sortError'

    renderTpl: =>
      @template = Handlebars.compile @template unless _.isObject @template

      args = {}

      if @model
        args.modelid = @model.modelid()
        args.model = if _.isFunction @encodeModel
          @encodeModel()
        else
          @model.toJSON()
      args.vars = @tplvars if @tplvars

      if @partials
        Handlebars.registerPartial pname, ptext for pname, ptext of @partials

      @$el.html @template args

    render: =>
      if @template
        @beforeRender() if _.isFunction @beforeRender
        @rendered = false
        @renderTpl()
        @afterRender() if _.isFunction @afterRender
        @toggleModelDomBindings true if @modelBindOnRender
        @rendered = true
        @trigger 'render'
      else
        utils.throwError 'No template specified for the view'

      @

    close: (opts) =>
      @trigger 'close'
      @closed = true
      @beforeClose() if _.isFunction(@beforeClose) && !opts?.skipBefore
      @stopListening()
      @unbind()
      @toggleModelDomBindings false

      if !opts?.noremove
        if @embedded
          @$el.empty()
          @undelegateEvents()
        else
          @$el.remove()

    remove: (opts) =>
      @beforeClose() if _.isFunction @beforeClose
      dfd = $.Deferred()

      _close = =>
        @close skipBefore: true
        dfd.resolve()

      if opts?.noFade || !opts?.noFade? && !@fadeOnRemove
        _close()
      else
        @$el.fadeOut _close

      dfd

    adjustHeight: (opts) =>
      return unless @el
      contHeight = opts?.contHeight
      # TODO: better dim selector handling
      if @el.id is 'container' && opts?.init
        addh = 0
        for cssdef in [ 'padding-top', 'padding-bottom',
                        'margin-top', 'margin-bottom' ]
          addh += parseInt @$el.css cssdef

        contHeight ?= $(window).height()
        contHeight -= addh
        @$el.height contHeight
        @sharedStatus.contHeight = contHeight
        contPtop = parseInt(@$el.css 'padding-top')
        @sharedStatus.contOffset = @$el.offset().top + contPtop
        @notifierPub 'cont:adjust:height', contHeight: contHeight
      else if @dim
        contHeight ?= @sharedStatus.contHeight
        return unless contHeight

        elems = _.map @dim, (val,key) -> $(key)

        _.each @dim, (pars, elem) =>
          return unless pars?
          $obj = if elem then @$el.find(elem) else @$el

          perc = (pars.height?.match /^(\d+)%$/)?[1]
          if !perc
            perc = (pars.maxHeight?.match /^(\d+)%$/)?[1]
            max = true

          if perc
            h = contHeight

            if !pars.noOffset
              $offObj = if pars.selfOffset then $obj else @$el
              contOffset = @sharedStatus.contOffset || 0

              if @el.id isnt 'container'
                h -= $offObj.offset().top - contOffset +
                  @$el.outerHeight() - @$el.height()

            if pars.subtract
              $subBase = if pars.subtractBase
                @$el.find(pars.subtractBase)
              else
                @$el

              $subBase.find(pars.subtract).each ->
                return unless $(@).is ':visible'
                subh = $(@).outerHeight true

                for $el in elems
                  isChild = false
                  $inspected = $(@)
                  $el.each -> isChild = true if $(@).closest($inspected).length
                  elh = $el.outerHeight()
                  subh -= elh if isChild && elh < subh

                h -= subh

            h = parseInt h * perc / 100
            padding = $obj.outerHeight() - $obj.height()
            h -= padding
            h = 0 if h < 0

            if max
              $obj.css 'max-height', h + 'px'
            else
              h = pars.minHeight if pars.minHeight && pars.minHeight > h
              $obj.height h

            $obj.css 'min-height', pars.minHeight + 'px' if pars.minHeight

            $obj.trigger 'heightchange'

          overflow = pars.overflow || 'auto'
          $obj.css 'overflow-y', overflow
          $obj.css '-webkit-overflow-scrolling', 'touch'

        @trigger 'heightchange'


  # ---- Default Empty List Placeholder ---------------------------------------

  class Base.EmptyListPhView extends Base.View
    className: 'nt-empty-list-ph'

    initialize: ->
      @template = '<p>{{lang vars.msg}}</p>'
      @msg = @options.msg

    initTplVars: =>
      @addTplVar msg: @msg if @msg

  # ---- ParentView -----------------------------------------------------------

  class Base.ParentView extends Base.View
    render: =>
      @closeChildren()
      super

    createChild: (ViewClass, opts, childName) =>
      @storeChild (new ViewClass opts), childName, render: true

    getChild: (name) =>
      @children?[name]

    storeChild: (view, name, opts) =>
      @children ?= {}
      if _.isObject view
        key = name || view.model?.cid || view.cid
      else
        utils.throwError 'Invalid view given for storeChild'

      view.parent = @
      @children[key] = view

      view.render() if opts?.render
      view.afterDomAdd() if opts?.domadd && _.isFunction view.afterDomAdd

      view

    storeChildren: (obj, opts) =>
      @storeChild view, name, opts for name, view of obj

    renderChildren: =>
      _.each @children, (child) ->
        child.render()

    closeChildren: (children, opts) =>
      if children? && (_.isArray(children) || !_.isObject children)
        children = [ children ] unless _.isArray children
      else
        opts = children
        children = null

      for childId, child of @children
        if !children || childId in children
          child.close opts
          @stopListening child
          delete @children[childId]

    close: =>
      @closed = true
      @closeChildren noremove: true
      super

    createModal: (modalClass, opts, callbacks) =>
      return if @closed
      opts ?= {}
      delay = opts.delay
      opts = _.omit opts, 'delay'

      childId = opts.childId
      if @closed ||
         (childId && @getChild(childId) && !@getChild(childId).closed)
        return

      delete opts.childId

      modalView = new modalClass opts
      if _.isObject callbacks
        for cname of callbacks
          @listenTo modalView, cname, callbacks[cname]

      showModal = =>
        childId ?= "modal#{modalView.cid}"
        @storeChild modalView, childId, render: true

      if delay
        setTimeout showModal, delay
      else
        showModal()

    afterDomAdd: =>
      _.each @children, (child) ->
        child.afterDomAdd() if _.isFunction child.afterDomAdd

  # ---- CollectionView -------------------------------------------------------

  class Base.CollectionView extends Base.ParentView
    constructor: ->
      super
      @adoptOptions 'itemSelector', 'itemCont', 'emptyViewCont',
        'emptyHideSelector', 'emptyMsg', 'emptyFilterMsg', 'EmptyView',
        'EmptyViewOpts', 'renderOnFilter'

      @$itemCont = @$el unless @template && @itemCont
      @itemSelector ?= 'div'

    initCollectionEvents: =>
      if @collection
        @listenTo @collection, 'add', @addItemView
        @listenTo @collection, 'remove', @removeItemView
        @listenTo @collection, 'reset', (list, opts) =>
          @render list, _.extend reset: true, opts

    initEvents: =>
      super
      @initCollectionEvents()

    buildItemView: (item) =>
      ItemView = @options.ItemView || @ItemView
      if ItemView
        opts = _.extend {}, @ItemViewOpts, @options.ItemViewOpts
        opts.model = item
        itemView = new ItemView opts
        @storeChild itemView
      else
        utils.throwError 'No ItemView specified for the CollectionView'

      @trigger 'builditemview', itemView

      itemView

    addItemView: (item, list, opts) =>
      @closeEmptyView restore: true

      itemView = @buildItemView item

      $el = itemView.render().$el
      idx = if opts?.at? then opts.at else @collection.indexOf(item)
      @addItemEl $el, idx

      if !opts?.hide && @showItems && @options.showOnAdd
        @showItems[item.id] = 1
      else if opts?.hide || (@showItems && !@showItems[item.id])
        $el.addClass 'hide'

      @afterAddItemView itemView, opts if _.isFunction @afterAddItemView

      @trigger 'additemview', itemView, opts
      @changeVisibleItems() if @showItems && @options.obsVisItems

    addItemEl: ($el, idx) ->
      children = @$itemCont.children @itemSelector
      if idx? && idx < children.length
        $el.insertBefore children.eq(idx)
      else if children.length
        $el.insertAfter children.last()
      else
        @$itemCont.append $el

    removeItemView: (item, list, opts) =>
      itemView = @children[item.cid]
      itemView?.remove(opts).done =>
        delete @children[item.cid]
        @showEmptyView()
        @changeVisibleItems if @options.obsVisItems
        @afterRemoveItemView itemView, opts if _.isFunction @afterRemoveItemView
        @trigger 'removeitemview', itemView

    render: (items, opts) =>
      @$el.clearQueue() if @asyncRender

      items = @collection.models unless items?
      items = items.models unless _.isArray items

      @closeEmptyView()

      if @collection.deferData && @collection.deferData.state() isnt 'rejected'
        @collection.deferData.done => @_render items, opts
      else
        @_render items, opts

      @

    _render: (items, opts) =>
      @beforeRender() if _.isFunction @beforeRender

      @closeChildren noremove: true

      if !opts?.reset || !@rendered?
        @$el.empty()
        @renderTpl() if @template && (items.length || @emptyViewCont)
        @toggleModelDomBindings true if @model && @modelBindOnRender
      else
        @$itemCont.empty()

      @rendered = false

      @renderItems items, opts

    renderItems: (items, opts) =>
      len = items?.length

      if len
        if @asyncRender
          @$el.clearQueue()
          chunkSize = if _.isObject @asyncRender
            @asyncRender.chunkSize
          else
            @asyncRender
          chunkSize = 20 unless _.isFinite chunkSize
          dfd = $.Deferred()
          for idx in [ 0 .. len - 1 ] by chunkSize
            chunkEnd = idx + chunkSize
            lastmarker = chunkEnd >= len
            @_queueRender items.slice(idx, chunkEnd), lastmarker, dfd, opts
        else
          @addItemView item, {}, opts for item in items

      @showEmptyView items, opts if !len || @emptyViewCont

      renderDone = => @trigger 'renderitems', items, opts

      if dfd
        dfd.done renderDone
      else
        renderDone()

      if !opts?.partial
        if dfd && len
          dfd.done @_postRender
        else
          @_postRender()

      @

    _queueRender: (chunk, lastmarker, dfd, opts) =>
      @$el.queue (next) =>
        if _.isObject(@asyncRender) && chainEvent = @asyncRender.chainEvent
          @listenToOnce @, 'builditemview', (itemView) =>
            if itemView.model is chunk[chunk.length - 1]
              @listenToOnce itemView, chainEvent, next

        @addItemView item, {}, opts for item in chunk

        _.defer next unless chainEvent

        dfd.resolve() if lastmarker

    _postRender: =>
      @afterRender() if _.isFunction @afterRender
      @rendered = true
      @trigger 'render'
      @changeVisibleItems() if @options.obsVisItems

    renderTpl: =>
      super
      @$itemCont = @$el.find(@itemCont) if @itemCont

    getUnrenderedItems: =>
      @collection.filter (model) => !@children[model.cid]

    showEmptyView: (items, opts) =>
      opts ?= {}
      @closeEmptyView opts if opts.refresh
      len = items?.length ? @collection.length
      return if @emptyViewVisible || len ||
                !(@emptyMsg || @EmptyView || @EmptyViewOpts)

      @EmptyView ?= Base.EmptyListPhView

      emptyMsg = if opts?.emptyMsg?
        opts.emptyMsg
      else if opts?.filter && @emptyFilterMsg?
        @emptyFilterMsg
      else
        @emptyMsg
      eopts = if emptyMsg? then msg: emptyMsg else {}
      eopts = _.extend {}, @EmptyViewOpts, eopts

      @emptyView = new @EmptyView eopts
      @emptyViewVisible = true

      emptyViewCont = @$el
      if @emptyViewCont
        emptyViewCont = if _.isObject @emptyViewCont
          @emptyViewCont
        else
          @$(@emptyViewCont)
      @$(@emptyHideSelector).hide() if @emptyHideSelector
      emptyViewCont.html @emptyView.render().$el
      @trigger 'showempty'

    closeEmptyView: (opts) =>
      if @emptyViewVisible
        @emptyView.close()
        delete @emptyViewVisible
        @renderTpl() if @template && opts?.restore
        @trigger 'hideempty'

    close: =>
      @$el.clearQueue() if @asyncRender
      @closeEmptyView()
      super

    _filter: (kword, flds, subs) =>
      # NOTE: renderOnFilter gives empty list when search has no kwords/subs
      items = if !@renderOnFilter || kword || subs
        @collection.search kword, flds, subs
      else
        []

      if @renderOnFilter
        @render items, if kword || subs then filter: true
      else
        @showItems = {}
        @showItems[item.id] = 1 for item in items

        _.each @children, (child) =>
          child.$el.toggleClass 'hide', !@showItems[child.model.id]

      @trigger 'filter'
      if @$itemCont && @options.obsVisItems && !@renderOnFilter
        @changeVisibleItems()
      items

    visibleItemCnt: =>
      @$itemCont.find('>*').not('.hide').length

    changeVisibleItems: =>
      @trigger 'changevisibleitems', @visibleItemCnt()

    getItemAt: (opts) =>
      opts ?= {}
      if opts.at
        children = @$itemCont.children(@itemSelector)
        @$(children.get(opts.at))?.data 'backbone-view'

  # ---- Return ---------------------------------------------------------------

  Base
