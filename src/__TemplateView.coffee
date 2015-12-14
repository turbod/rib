define (require) ->
  Base = require 'baseviews'
  utils = require 'utils'
  # tpl = require 'text!tpls/__template.html'

  # __TemplateView = utils.mixin mixinObj.mixin1, mixinObj.mixin2, class extends Base.ParentView
  class __TemplateView extends Base.ParentView
    initialize: ->
      @template = tpl
      # @adoptOptions 'opt1', 'opt2'

    initEvents: =>
      # @listenTo @model, 'change', @changeHandler

    initNotifierSub: =>
      # @notifierSub 'sub:event', @subHandler

    initTplVars: =>
      # @addTplVar myvar: 'myvalue'

    initModelDomBindings: =>
      ###
      @addModelDomBinding
        name:
          selector: '#selector'
          elAttribute: 'href'
          converter: @myConverter      
      ###

    initDomEvents: =>
      ###
      @addDomEvent
        'click .myclass' : 'myHandler'
      ###

    afterRender: =>
      ###
      subView = new SubView
        collection : @coll
        el         : @$('.sub')
      @storeChild subView, 'sub', render: true
      ###

    beforeClose: =>
      # cleanup
