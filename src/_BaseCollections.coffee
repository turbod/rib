define (require) ->
  _ = require 'underscore'
  Backbone = require 'backbone'
  utils = require 'utils'

  Base = {}

  # ---- Collection -----------------------------------------------------------

  class Base.Collection extends Backbone.Collection
    constructor: (models, options) ->
      super
      options ?= {}

      utils.adoptProps @, options, 'baseUrl', 'url', 'urlParams', 'autoSave',
        'modelDefaults', 'rankAttr', 'orderAttr', 'orderUrl', 'noSync',
        'relType'

      url = utils.getProp @, 'url'
      @url = @baseUrl + url if @baseUrl && url

      if @rankAttr
        if !@comparator
          @comparator = (item) => item.get @rankAttr
        @sort()
        @on 'add', (item, list, addopts) =>
          @sortItem item, list, addopts unless addopts?.rel

        if @orderUrl
          @on 'sort', (list, sortopts) =>
            if sortopts?.item && (sortopts.item.autoSave || @autoSave) &&
                !sortopts.item.isNew()
              @saveOrder()

    reset: (models, opts) =>
      if models? && @rankAttr
        models = [ models ] unless _.isArray models
        unranked = _.find models, (model) =>
          if model instanceof Backbone.Model
            !model.get(@rankAttr)?
          else
            !model[@rankAttr]?

        if unranked
          models = _.map models, (model, i) =>
            if model instanceof Backbone.Model
              model.set @rankAttr, i + 1
            else
              (_model = if model then _.clone(model) else {})[@rankAttr] = i + 1
              _model

      super models, opts

    saveNewModels: =>
      newModels = @filter (model) -> model.isNew()
      if newModels
        dfds = _.map newModels, (model) ->
          model.save null, url: '/api' + model.urlRoot
        $.when.apply(@, dfds).then ->
          $.Deferred().resolve newModels
      else
        $.Deferred().resolve []

    syncModelsTo: (coll, opts) =>
      return unless coll
      opts ?= {}
      attr = opts.attr || 'id'
      # NOTE: _pale means the model has partial refs
      addObjs = _.filter coll.toJSON(), (obj) =>
        !obj['_pale'] && obj[attr] not in @pluck(attr)
      removeModels = if opts.remove then @filter (model) ->
        model.get(attr) not in coll.pluck(attr)

      @add addObjs if addObjs.length
      @remove removeModels if removeModels?.length

    fetch: =>
      @deferData = super.done( =>
        @trigger 'fetch'
      ).fail =>
        @trigger 'fetchError'

    fetchOnce: (opts) =>
      @deferData || @fetch(opts)

    addItem: (modelAttrs, opts) =>
      return unless modelAttrs?
      opts ?= {}
      modelAttrs = [ modelAttrs ] unless _.isArray modelAttrs

      attrs = opts.chkExAttrs
      if attrs
        attrs = [ attrs ] unless _.isArray attrs
        models = []

        for model in modelAttrs
          exModel = @find (item) ->
            for attr in attrs
              res = item.get(attr) is model[attr]
              break if res
            res

          models.push model unless exModel
      else
        models = modelAttrs

      if models.length
        if @noSync
          @add models, opts
        else if @parentModel && (@relType is 'id' || opts.relType is 'id')
          @addRel models, opts
        else
          @create model, _.extend parse: true, opts for model in models

    sortItem: (item, list, opts) =>
      if item
        at = if _.isNumber opts.at then opts.at else null
        from = @indexOf item
        if at?
          siblings = list.without item
          at = 0 if at < 0
          at = siblings.length if at > siblings.length
          prev = siblings[at - 1]?.get 'rank'
          next = siblings[at]?.get 'rank'
        else if @length > 1
          prev = @at(from - 1)?.get 'rank'

        rank = utils.calcRank prev, next, signed: !!@orderAttr
        item.set 'rank', rank, _.pick opts, 'init'
        if at?
          item.set @orderAttr, @pluck 'id' if item.isNew() && @orderAttr
          @sort item: item, from: from
      else
        utils.throwError 'No model item specified for sortItem'

    saveOrder: =>
      if @orderUrl
        Backbone.sync.call @, 'update', @,
          url  : '/api' + _.result(@, 'url') + @orderUrl
          data : @pluck 'id'

    _handleRel: (action, models, opts) =>
      @[action](models, opts) unless opts?.saveOnly
      models = [ models ] unless _.isArray models
      ids = _.pluck _.filter(models, (model) -> model?.id), 'id'
      if ids.length
        method = if action is 'add' then 'create' else 'delete'
        req = Backbone.sync.call @, method, @, _.extend {}, opts, ids: ids

        if @rankAttr && action is 'add'
          req.done =>
            @each (model) =>
              @sortItem model, @, _.omit opts, 'rel' if model.id in ids

        req
      else
        $.Deferred().resolve()

    addRel: (models, opts) =>
      @_handleRel 'add', models, _.extend rel: true, opts

    removeRel: (models, opts) =>
      @_handleRel 'remove', models, opts

    remove: =>
      super
      @trigger 'empty', @ if @length == 0

    # NOTE: return value is an array of models!
    # USAGE EXAMPLES:
    #   collection.search '"John Doe" superhero', 'name',
    #     tags: flds: 'descr'
    #   collection.search 'john', [ 'name', 'email' ],
    #     tags: flds: 'descr', kwords: 'superhero'
    search: (kws, flds, children) =>
      kws = utils.extractKeywords kws unless _.isArray kws
      flds = [ flds ] if flds? && !_.isArray flds

      @filter (item) ->
        kwords = _.clone kws

        if flds && kwords
          tmp = []
          for kword in kwords
            for fld in flds
              pat = new RegExp '\\s' + $.ntQuoteMeta(kword), 'i'
              val = item.get fld
              res = pat.test ' ' + val if val?
              if res
                tmp.push kword
                break

          kwords = _.difference kwords, tmp

        children_ok = true

        if _.isObject children
          for cname of children
            child = children[cname] || {}
            cflds = child.flds
            continue unless cflds? && item[cname] instanceof Backbone.Collection

            ckwords = child.kwords
            nonEmpty = !_.isArray(ckwords) && !_.isString(ckwords) || ckwords.length

            if ckwords? && nonEmpty
              ckws = if _.isArray ckwords
                ckwords
              else
                utils.extractKeywords ckwords

              for ckw in ckws
                cmodels = item[cname].search ckw, cflds
                if !cmodels.length
                  children_ok = false
                  break

              break unless children_ok
            else
              tmp = []
              for kword in kwords
                cmodels = item[cname].search kword, cflds
                tmp.push kword if cmodels.length

              kwords = _.difference kwords, tmp

        !kwords.length && children_ok

    getByProp: (n, v) =>
      @find (m) -> m.get(n) is v

    getObjs: (opts) =>
      opts ?= {}
      ret = {}

      models = if _.isString opts.models
        @[opts.models]()
      else if _.isFunction opts.models
        opts.models()
      else
        opts.models || @models

      _.each models, (model) ->
        ret[model.id] = if opts.attr
          if _.isArray opts.attr
            for _attr in opts.attr
              _val = model.get _attr
              break if _val?
            _val
          else
            model.get opts.attr
        else if opts.json
          model.toJSON()
        else
          model

      ret

  # ---- Return ---------------------------------------------------------------

  Base
