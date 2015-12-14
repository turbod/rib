define (require) ->
  BaseModels = require 'basemodels'

  class TestModel extends BaseModels.Model

  ret =
    test: ->
      # =======================
      describe '_BaseModel', ->
        beforeEach ->
          @testModel = new TestModel flag: true

        it 'toggleAttr / invertAttr', ->
          @testModel.toggleAttr 'flag'
          expect(@testModel.has 'flag').not.toBeTruthy()
          @testModel.toggleAttr 'flag'
          expect(@testModel.get 'flag').toEqual true

          @testModel.invertAttr 'flag'
          expect(@testModel.get 'flag').toEqual false
          @testModel.invertAttr 'flag'
          expect(@testModel.get 'flag').toEqual true

          @testModel.toggleAttr 'flag', true
          expect(@testModel.get 'flag').toEqual true
          @testModel.toggleAttr 'flag', false
          expect(@testModel.has 'flag').not.toBeTruthy()
          @testModel.toggleAttr 'flag', false
          expect(@testModel.has 'flag').not.toBeTruthy()

          @testModel.toggleAttr 'flag', 1
          expect(@testModel.get 'flag').toEqual true
          @testModel.toggleAttr 'flag', 1
          expect(@testModel.get 'flag').toEqual true
          @testModel.toggleAttr 'flag', 0
          expect(@testModel.has 'flag').not.toBeTruthy()

  ret
