define (require) ->
  _ = require 'underscore'
  Backbone = require 'backbone'
  utils = require 'utils'

  Base = {}

  # ---- Model ----------------------------------------------------------------

  class Base.Model extends Backbone.Model
    constructor: (attributes, opts) ->
      super
      @_dirty = {}
      @_unSynced = !!opts?.unSynced
      @noSync = !!opts?.noSync

      @autoSave = opts.autoSave if opts?.autoSave?
      autoSaveTimeout = utils.getConfig('autoSaveTimeout') || 50

      @on 'sync', => delete @_unSynced

      @on 'change', (model, copts) =>
        if !@isNew() && !@_unSynced && !@noSync && !@collection?.noSync &&
            !copts?.init
          changed = @changedAttributes() || {}
          delete changed[key] for key of changed when @isInternalAttr key

          return if _.isEmpty(changed) || 'id' in _.keys(changed)

          _.extend @_dirty, changed

          autoSave = if @collection?.autoSave?
            @collection.autoSave
          else
            @autoSave

          if autoSave
            clearTimeout @_saveTo
            @_saveTo = setTimeout =>
              @save()
            , autoSaveTimeout

    isInternalAttr: (attr) =>
      attr? && (attr.match(/^_/) || attr in (@_internalAttrs || []))

    internalAttrs: =>
      ret = []
      for attr of @attributes
        ret.push attr if @isInternalAttr attr
      ret

    _setArgs: (key, val, opts) =>
      if _.isObject(key) || !key?
        attrs = key
        opts = val
      else
        (attrs = {})[key] = val

      attrs = attrs.attributes if attrs instanceof Base.Model

      [attrs, opts]

    set: (key, val, opts) =>
      [attrs, opts] = @_setArgs key, val, opts

      if opts?.synctype in [ 'create', 'update' ] && !opts?.ids
        refreshAttrs = _.clone(opts.refreshAttrs) || @refreshAttrs

        if refreshAttrs isnt true
          refreshAttrs = [] if !refreshAttrs? || refreshAttrs is false
          refreshAttrs = [ refreshAttrs ] unless _.isArray refreshAttrs
          refreshAttrs.push 'id' if opts.synctype is 'create'
          attrs = _.pick attrs, refreshAttrs

      if !opts?.unset
        for attr, value of attrs
          continue unless value?
          if @_dateAttrs && attr in @_dateAttrs
            attrs[attr] = utils.dbDateToIso value
          else if @_integerAttrs && attr in @_integerAttrs
            attrs[attr] = parseInt value
          else if @_floatAttrs && attr in @_floatAttrs
            attrs[attr] = parseFloat value
          else if @_boolAttrs && attr in @_boolAttrs && !_.isBoolean value
            intval = parseInt value
            attrs[attr] = value && isNaN(intval) || intval

      super attrs, opts

    urlParams: =>
      utils.getProp(@, 'urlRootParams') ||
        utils.getProp(@collection, 'urlParams')

    save: =>
      clearTimeout @_saveTo if @_saveTo
      if !@isNew() && !@isDirty()
        $.Deferred().resolve {}
      else
        super

    setDirty: (attrs) =>
      return unless attrs?
      attrs = [ attrs ] unless _.isArray attrs
      @_dirty[attr] = @get(attr) for attr in attrs

    isDirty: =>
      _.keys(@_dirty).length

    saveAttrs: (attrs, opts) =>
      return unless attrs?

      if $.isPlainObject attrs
        @set attrs, opts
        attrs = _.keys attrs

      @_dirty = {} if opts?.reset
      @setDirty attrs
      @save()

    dirtyAttrs: (opts) =>
      attrs = @_dirty
      @_dirty = {} if opts?.clear
      @toJSON attrs: _.keys(attrs)

    toggleAttr: (attr, bool, opts) =>
      if !opts? && _.isObject bool
        opts = bool
        bool = undefined

      bool ?= !@get attr

      if bool || opts?.invert
        @set attr, !!bool, opts
      else
        @unset attr, opts

    invertAttr: (attr, opts) =>
      @toggleAttr attr, _.extend invert: true, opts

    fetch: =>
      @deferData = super.done( =>
        @trigger 'fetch'
      ).fail =>
        @trigger 'fetchError'

    modelid: =>
      @id || @cid

    toJSON: (opts) =>
      ret = super

      delete ret.id if opts?.skipId

      if opts?.skipInternal
        ret = _.omit ret, @internalAttrs()

      if opts?.attrs?.length
        ret = _.pick ret, opts.attrs

      if @_dateAttrs
        ret[attr] = utils.isoToDbDate ret[attr] for attr in @_dateAttrs

      if opts?.cid
        cidname = if _.isBoolean opts.cid then 'cid' else opts.cid
        ret[cidname] = @cid

      ret

    duplicate: (opts) =>
      attrs = @cloneAttrs opts
      new @constructor attrs

    cloneAttrs: (opts) =>
      @toJSON _.extend skipId: true, opts

  # ---- ParentModel ----------------------------------------------------------

  class Base.ParentModel extends Base.Model
    collections: {}

    set: (key, val, opts) =>
      [attrs, opts] = @_setArgs key, val, opts
      opts ?= {}

      if !opts.unset && !opts.noChildren
        for cname, props of @collections
          coll = @[cname]

          if !coll
            copts = _.extend relType: 'id', props.options
            coll = @[cname] = new props.constructor null, copts
            coll.parentModel = @
            coll.url = @childUrl coll.url if coll.url

            if props.setAttr
              coll.on 'change reset', =>
                (cattrs = {})[cname] = coll.toJSON()
                @set cattrs, noChildren: true

          # TODO: refreshAttrs for child collections?
          if attrs.hasOwnProperty(cname) && opts.synctype isnt 'update'
            if attrs[cname]?
              if opts.synctype is 'create' && opts.cid
                _.each attrs[cname], (_attrs) ->
                  coll.get(_attrs[opts.cid])?.set _attrs, opts
              else
                coll[ if opts.update then 'set' else 'reset' ](attrs[cname],
                  _.extend parse: true, props.resetOpts, _.omit opts, 'at')
            else
              @[cname] = null

      super attrs, opts

    childUrl: (url) =>
      => utils.getProp(@, 'url') + url

    syncChildTo: (cname, coll, opts) ->
      child = @[cname]
      if child
        child.syncModelsTo coll, opts
        @set cname, child.toJSON() unless @collections[cname].setAttr

    toJSON: (opts) =>
      ret = super

      if cmode = opts?.children
        children = {}

        for cname, props of @collections
          continue if props.setAttr ||
            (opts.attrs?.length && cname not in opts.attrs)

          delete ret?[cname]
          coll = @[cname]
          if coll && (!opts.skipEmpty || coll.length)
            ids = _.compact coll.pluck 'id'
            children[cname] = if cmode is 'id' || cmode is 'auto' && ids.length
              ids
            else
              coll.toJSON opts

        ret = _.extend ret, children

      ret

  # ---- Return ---------------------------------------------------------------

  Base
