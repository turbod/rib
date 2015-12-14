define (require) ->
  _ = require 'underscore'
  BaseModels = require 'basemodels'
  BaseCollections = require 'basecollections'
  utils = require 'utils'

  class SubModel extends BaseModels.ParentModel

  class SubCollection extends BaseCollections.Collection

  class TestModel extends BaseModels.ParentModel
    collections:
      subs:
        constructor: SubCollection

  class TestCollection extends BaseCollections.Collection
    model: TestModel

  data = [
    id    : 'U1'
    name  : 'John Doe'
    email : 'john@earth.com'
    subs  : [
      descr: 'Hello'
    ,
      descr: 'Baby'
    ]
  ,
    id    : 'U2'
    name  : 'Jane Wright'
    email : 'jane@girls.gov'
    subs  : [ descr: 'Baby' ]
  ,
    id    : 'U3'
    name  : 'Jack Ripper'
    email : 'johann@ripme.edu'
  ]

  chkSearch = (res, exp) ->
    ids = _.pluck res, 'id'
    expect(ids).toEqual exp

  chkArr = (coll, attr, arr) ->
    expect(coll.pluck attr).toEqual arr

  ret =
    test: ->
      # ============================
      describe '_BaseCollection', ->
        # ------------------------
        describe 'sort - rank', ->
          beforeEach ->
            @testCollection = new TestCollection [
              name: 'A', rank: 2
            ,
              name: 'B', rank: 1
            ,
              name: 'C', rank: 3
            ], rankAttr: 'rank'

          it 'sorts initially', ->
            chkArr @testCollection, 'name', [ 'B', 'A', 'C' ]
            chkArr @testCollection, 'rank', [ 1, 2, 3 ]

            @testCollection.add name: 'X'
            chkArr @testCollection, 'name', [ 'B', 'A', 'C', 'X' ]
            chkArr @testCollection, 'rank', [ 1, 2, 3, 4 ]

          it 'adds into position', ->
            @testCollection.add { name: 'X' }, { at: 1 }
            chkArr @testCollection, 'name', [ 'B', 'X', 'A', 'C' ]
            chkArr @testCollection, 'rank', [ 1, 1.5, 2, 3 ]

            @testCollection.add { name: 'Y', rank: 10 }, { at: 2 }
            chkArr @testCollection, 'name', [ 'B', 'X', 'Y', 'A', 'C' ]
            chkArr @testCollection, 'rank', [ 1, 1.5, 1.75, 2, 3 ]

            @testCollection.add { name: 'Z' }, { at: 4 }
            chkArr @testCollection, 'name', [ 'B', 'X', 'Y', 'A', 'Z', 'C' ]
            chkArr @testCollection, 'rank', [ 1, 1.5, 1.75, 2, 2.5, 3 ]

          it 'prepends / appends', ->
            @testCollection.add { name: 'X' }, { at: 0 }
            chkArr @testCollection, 'name', [ 'X', 'B', 'A', 'C' ]
            chkArr @testCollection, 'rank', [ 0.5, 1, 2, 3 ]

            @testCollection.add { name: 'Y' }, { at: 4  }
            chkArr @testCollection, 'name', [ 'X', 'B', 'A', 'C', 'Y' ]
            chkArr @testCollection, 'rank', [ 0.5, 1, 2, 3, 4 ]

          it 'prepends / appends with crazy at', ->
            @testCollection.add { name: 'X' }, { at: -2  }
            chkArr @testCollection, 'name', [ 'X', 'B', 'A', 'C' ]
            chkArr @testCollection, 'rank', [ 0.5, 1, 2, 3 ]

            @testCollection.add { name: 'Y' }, { at: 42  }
            chkArr @testCollection, 'name', [ 'X', 'B', 'A', 'C', 'Y' ]
            chkArr @testCollection, 'rank', [ 0.5, 1, 2, 3, 4 ]

          it 'sorts on sortItem', ->
            move = (from ,to) =>
              @testCollection.sortItem @testCollection.at(from),
                @testCollection, at: to

            # start [ 'B', 'A', 'C ] / [ 1, 2, 3 ]

            move 2, 1
            chkArr @testCollection, 'name', [ 'B', 'C', 'A' ]
            chkArr @testCollection, 'rank', [ 1, 1.5, 2 ]

            move 1, 0
            chkArr @testCollection, 'name', [ 'C', 'B', 'A' ]
            chkArr @testCollection, 'rank', [ 0.5, 1, 2 ]

            move 0, 2
            chkArr @testCollection, 'name', [ 'B', 'A', 'C' ]
            chkArr @testCollection, 'rank', [ 1, 2, 3 ]

            move 0, 1
            chkArr @testCollection, 'name', [ 'A', 'B', 'C' ]
            chkArr @testCollection, 'rank', [ 2, 2.5, 3 ]

        # -------------------
        describe 'search', ->
          beforeEach ->
            @testCollection = new TestCollection data

          it 'searches correctly with empty keywords', ->
            res = @testCollection.search '', 'name'
            chkSearch res, [ 'U1', 'U2', 'U3' ]

            res = @testCollection.search [], 'name'
            chkSearch res, [ 'U1', 'U2', 'U3' ]

            res = @testCollection.search '', 'name', subs: flds: 'descr', kwords: ''
            chkSearch res, [ 'U1', 'U2', 'U3' ]

            res = @testCollection.search [], 'name', subs: flds: 'descr', kwords: []
            chkSearch res, [ 'U1', 'U2', 'U3' ]

          it 'searches correctly with default keywords', ->
            res = @testCollection.search 'jo', [ 'name', 'email' ]
            chkSearch res, [ 'U1', 'U3' ]

            res = @testCollection.search 'ohn', 'name'
            chkSearch res, []

          it 'searches correctly also in children with default keywords', ->
            res = @testCollection.search '"John Doe" Baby', 'name',
              subs: flds: 'descr'
            chkSearch res, [ 'U1' ]
          
          it 'searches correctly also in children with children specific keywords', ->
            res = @testCollection.search 'j', 'name', subs: flds: 'descr', kwords: 'ba'
            chkSearch res, [ 'U1', 'U2' ]

            res = @testCollection.search [ 'j' ], 'name', subs: flds: 'descr', kwords: [ 'ba' ]
            chkSearch res, [ 'U1', 'U2' ]

            res = @testCollection.search '', 'name', subs: flds: 'descr', kwords: 'baby hello'
            chkSearch res, [ 'U1' ]

            res = @testCollection.search [ '' ], 'name', subs: flds: 'descr', kwords: [ 'baby', 'hello' ]
            chkSearch res, [ 'U1' ]
  ret

