define (require) ->
  FuncQueue = require 'FuncQueue'

  makeDfd = ->
    dfd = $.Deferred()
    func : -> dfd
    obj  : dfd

  ret =
    test: ->
      describe 'funcQueue', ->
        beforeEach ->
          @dfds = []
          @dfds.push makeDfd() for i in [0..2]
          @enqueueAll = => @fq.enqueue dfd.func for dfd in @dfds

        describe 'default queue', ->
          beforeEach ->
            @fq = new FuncQueue()

          it 'params', ->
            spyOn @dfds[0], 'func'
            @fq.enqueue @dfds[0].func, params: [ 'x', 2 ]
            
            expect(@dfds[0].func).toHaveBeenCalledWith 'x', 2

          it 'sequential process', ->
            @enqueueAll()

            expect(@fq.running).toBeTruthy()
            expect(@fq.queue.length).toEqual 3

            @dfds[0].obj.resolve()

            expect(@fq.queue.length).toEqual 2
            expect(@fq.running).toBeTruthy()

            @dfds[i].obj.resolve() for i in [1..2]

            expect(@fq.queue.length).toEqual 0
            expect(@fq.running).not.toBeTruthy()

          it 'basic mixed queue', ->
            @fq.enqueue @dfds[0].func
            @fq.enqueue -> 1
            @fq.enqueue @dfds[1].func

            expect(@fq.running).toBeTruthy()
            expect(@fq.queue.length).toEqual 3

            @dfds[0].obj.resolve()
          
            expect(@fq.queue.length).toEqual 1
            expect(@fq.running).toBeTruthy()
                   
            @dfds[1].obj.reject()
          
            expect(@fq.queue.length).toEqual 0
            expect(@fq.running).not.toBeTruthy()

          it 'clear', ->
            @enqueueAll()
            @fq.clear()

            expect(@fq.queue.length).toEqual 1

            @dfds[0].obj.reject()

            expect(@fq.queue.length).toEqual 0

          it 'dequeue', ->
            @enqueueAll()
            @fq.dequeue()

            expect(@fq.queue.length).toEqual 2

            @dfds[0].obj.resolve()

            expect(@fq.queue.length).toEqual 1

            @fq.dequeue()

            expect(@fq.queue.length).toEqual 1

            @fq.stop()
            @fq.dequeue()

            expect(@fq.queue.length).toEqual 0

          it 'stop / run', ->
            @enqueueAll()
            @dfds[0].obj.resolve()
            @fq.stop()
            @dfds[i].obj.resolve() for i in [1..2]

            expect(@fq.queue.length).toEqual 1

            @fq.run()

            expect(@fq.queue.length).toEqual 0

        describe 'replace queue', ->
          beforeEach ->
            @fq = new FuncQueue replace: true

          it 'replace & stop', ->
            @enqueueAll()

            expect(@fq.queue.length).toEqual 2

            @dfds[i].obj.resolve() for i in [0..1]

            expect(@fq.queue.length).toEqual 1

            @fq.stop()
            _dfd = makeDfd()
            @fq.enqueue _dfd.func

            expect(@fq.queue.length).toEqual 1

            @dfds[2].obj.resolve()

            expect(@fq.queue.length).toEqual 1

            _dfd.obj.resolve()

            expect(@fq.queue.length).toEqual 0

        describe 'stopWhenError & skipWhenNext queue', ->
          beforeEach ->
            @fq = new FuncQueue stopOnError: true, skipWhenNext: true

          it 'stop on error', ->
            @enqueueAll()
            @dfds[i].obj.resolve() for i in [0, 2]
          
            expect(@fq.queue.length).toEqual 2

            @dfds[1].obj.reject()

            expect(@fq.queue.length).toEqual 1

            @fq.run()

            expect(@fq.queue.length).toEqual 0

          it 'skip when next', ->
            cb =
              callme0 : -> 0
              callme1 : -> 1
            spyOn cb, 'callme0'
            spyOn cb, 'callme1'
            @fq.enqueue @dfds[0].func, deferred: cb.callme0
            @fq.enqueue @dfds[1].func, deferred: cb.callme1
            @dfds[0].obj.resolve()

            expect(cb.callme0).not.toHaveBeenCalled()

            @dfds[1].obj.resolve()

            expect(cb.callme1).toHaveBeenCalled()

  ret
