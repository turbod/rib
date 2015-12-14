define (require) ->
  _ = require 'underscore'
  BaseViews = require 'baseviews'
  BaseModels = require 'basemodels'
  BaseCollections = require 'basecollections'
  utils = require 'utils'

  class TestView extends BaseViews.View
    initialize: ->
      @template = '<div id="foo">{{vars.foo}}</div>' +
                  '<div id="bar">{{{vars.bar}}}</div>' +
                  '<div id="part">{{> part}}</div>'
      @tplvars =
        foo: '<FooFoo>'
        bar: '<strong>BAR</strong>'
      @partials =
        part: '<p>PART</p>'

    events:
      'click #foo' : 'fooClick'

    fooClick: =>
      @clicked = true

    beforeRender: =>

    afterRender: =>

    afterDomAdd: =>
      @$el.find('#part').addClass('foobar')

  class TestModelView extends BaseViews.View
    className: 'foo'

    initialize: ->
      @template = '<div class="modelid">{{modelid}}</div>' +
                  '<div class="name">{{model.name}}</div>'

  class TestModel extends BaseModels.Model
    defaults:
      name: 'Hello'

  class TestCollection extends BaseCollections.Collection
    model: TestModel

  class TestParentView extends BaseViews.ParentView
    initialize: ->
      @template = '<div></div>'

  class TestCollectionView extends BaseViews.CollectionView
    initialize: ->
      @ItemView = TestModelView

  ret =
    test: ->
      # ======================
      describe '_BaseView', ->
        beforeEach ->
          @testView = new TestView
            el: '#container'

        afterEach ->
          @testView.close()

        # -----------------------
        describe 'Initialize', ->
          it 'inits correctly', ->
            expect(@testView.embedded).toBeTruthy()

        # ----------------------
        describe 'Rendering', ->
          it 'renders correctly', ->
            spyOn @testView, 'beforeRender'
            spyOn @testView, 'afterRender'

            @testView.render()

            for method in [ @testView.beforeRender, @testView.afterRender ]
              expect(method).toHaveBeenCalled()

            exp =
              'foo'  : $.ntEncodeHtml @testView.tplvars.foo
              'bar'  : @testView.tplvars.bar
              'part' : @testView.partials.part

            for id of exp
              expect( @testView.$el.find('#' + id).html() ).toEqual exp[id]

        # -------------------
        describe 'Events', ->
          beforeEach ->
            @testView.render()
            spyOn(@testView, 'fooClick').andCallThrough()
            @testView.delegateEvents()

          it 'calls jquery event callbacks', ->
            @testView.$el.find('#foo').click()
            expect(@testView.fooClick).toHaveBeenCalled()
            expect(@testView.clicked).toBeTruthy()

          it 'cleans up events', ->
            @testView.close()
            expect( @testView.$el.html() ).toEqual ''

            @testView.$el.append('<div id="foo"></div>')
            @testView.$el.find('#foo').click()
            expect(@testView.fooClick).not.toHaveBeenCalled()
            expect(@testView.clicked).not.toBeTruthy()

      # =================================
      describe '_BaseView with Model', ->
        beforeEach ->
          @testModelView = new TestModelView
            model: new TestModel()

        afterEach ->
          @testModelView.close()

        # -----------------------
        describe 'Initialize', ->
          it 'inits correctly', ->
            expect(@testModelView.embedded).not.toBeTruthy()

        # ----------------------
        describe 'Rendering', ->
          it 'renders & removes correctly', ->
            @testModelView.render().$el.appendTo '#container'

            expect( $('#container > div:eq(0)') ).toHaveClass 'foo'

            exp =
              'modelid' : @testModelView.model.cid
              'name'    : @testModelView.model.get 'name'

            for cname of exp
              expect( @testModelView.$el.find('.' + cname).html() ).toEqual exp[cname]

            @testModelView.model.destroy()

            waitsFor ->
              $('#container').html() is ''
            , 1000

      # =============================
      describe '_BaseView Parent', ->
        beforeEach ->
          @testParentView = new TestParentView()
          @testView = new TestView()

        afterEach ->
          @testParentView.close()
          @testView.close()

        # ------------------
        describe 'Store', ->
          it 'it stores & renders its children correctly', ->
            spyOn @testView, 'render'
            @testParentView.storeChild @testView, 'testView', render: true
            child = @testParentView.getChild 'testView'

            expect(child).toEqual @testView
            expect(@testParentView.children.testView).toEqual @testView
            expect(@testView.parent).toEqual @testParentView
            expect(@testView.render).toHaveBeenCalled()

          it 'stores multiple children correctly', ->
            @testView2 = new TestView()
            @testView2.template = '<div></div>'
            spyOn @testView, 'render'
            spyOn @testView2, 'render'

            @testParentView.storeChildren
              'test'  : @testView
              'test2' : @testView2
            , render: true

            expect(@testParentView.children.test).toEqual @testView
            expect(@testParentView.children.test2).toEqual @testView2
            expect(@testView.render).toHaveBeenCalled()
            expect(@testView2.render).toHaveBeenCalled()

            spyOn(@testParentView, 'closeChildren').andCallThrough()
            spyOn(@testView, 'close').andCallThrough()
            spyOn(@testView2, 'close').andCallThrough()
            @testParentView.render()

            expect(@testParentView.closeChildren).toHaveBeenCalled()
            expect(@testView.close).toHaveBeenCalled()
            expect(@testView2.close).toHaveBeenCalled()

        # ---------------------------
        describe 'Render & Close', ->
          it 'renders & closes children correctly', ->
            spyOn @testView, 'render'
            spyOn @testView, 'close'
            @testParentView.storeChild @testView, 'testView'

            expect(@testView.render).not.toHaveBeenCalled()

            @testParentView.renderChildren()

            expect(@testView.render).toHaveBeenCalled()

            @testParentView.close()

            expect(@testView.close).toHaveBeenCalledWith noremove: true

      # =================================
      describe '_BaseView Collection', ->
        beforeEach ->
          @testCollectionView = new TestCollectionView
            el         : '#container'
            collection : new TestCollection [
              name: 'Newt'
            ,
              name: 'Ash'
            ]

        afterEach ->
          @testCollectionView.close()

        # --------------------------------------------
        describe 'collection add / remove / reset', ->
          beforeEach ->
            @testCollectionView.render()

          it 'it adds itemviews correctly', ->
            spyOn(@testCollectionView, 'buildItemView').andCallThrough()
            @testCollectionView.collection.add name: 'Ripley'

            expect(@testCollectionView.buildItemView).toHaveBeenCalled()
            expect( @testCollectionView.$el.find('.name:last').html() ).toEqual 'Ripley'

          it 'it re-renders collection upon reset', ->
            @testCollectionView.collection.reset [
              name: 'Marvin'
            ,
              name: 'Arthur'
            ]

            expect( @testCollectionView.$el.find('.name:eq(0)').html() ).toEqual 'Marvin'
            expect( @testCollectionView.$el.find('.name:eq(1)').html() ).toEqual 'Arthur'

            @testCollectionView.collection.reset []

            expect( @testCollectionView.$el.html() ).toEqual ''

          it 'removes item views when item is removed from the collection', ->
            @testCollectionView.collection.remove @testCollectionView.collection.at(0)

            waitsFor ->
              @testCollectionView.$el.find('.name:eq(0)').html() is 'Ash'
            , 1000

        # ---------------------------------------------
        describe 'collection view async operations', ->
          beforeEach ->
            @testCollectionView.collection.reset []
            @testCollectionView.collection.url = '/things'
            @server = sinon.fakeServer.create()
            @server.respondWith 'GET', '/things', [
              200
            ,
              'Content-Type': 'application/json'
            ,
              '[{ "name" : "Hiroyuki" }]'
            ]
            @server.autoRespond = true
            @server.autoRespondAfter = 1000

          afterEach ->
            @server.restore()

          it 'renders items correctly after a deferred fetch', ->
            expect(@testCollectionView.collection.deferData).not.toBeTruthy()
            expect( @testCollectionView.$el.html() ).toEqual ''

            @testCollectionView.collection.fetch()

            expect(@testCollectionView.collection.deferData).toBeTruthy()

            @testCollectionView.render()

            waitsFor ->
              @testCollectionView.$el.find('.name:first').html() is 'Hiroyuki'
            , 1500

            runs ->
              @testCollectionView.collection.reset []
  
              expect( @testCollectionView.$el.html() ).toEqual ''

              @testCollectionView.collection.reset [ name: 'Sanada' ]

              expect( @testCollectionView.$el.find('.name:eq(0)').html() ).toEqual 'Sanada'

          # TODO: async render tests

  ret

