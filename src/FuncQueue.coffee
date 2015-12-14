define (require) ->
  class FuncQueue
    constructor: (opts) ->
      @queue = []
      @opts = opts || {}

    enqueue: (fn, opts = {}) =>
      @dequeue() if opts.replace ? @opts.replace
      @queue.push
        func     : -> fn.apply opts.scope, opts.params
        deferred : opts.deferred
      @run()
     
    dequeue: =>
      @queue.pop() if @queue.length && (!@running || @queue.length > 1)

    clear: =>
      @queue = if @running then @queue[..0] else []

    stop: =>
      @running = false

    run: =>
      return if @running
      @running = true

      @_process()

    _process: =>
      if !@queue.length
        @stop()
        return

      item = @queue[0]
      result = item.func.call()
      if $.isPlainObject(result) && $.isFunction(result.always)
        result.always =>
          return unless item in @queue
          if (!(@opts.skipWhenNext && @queue.length > 1) ||
              @opts.stopOnError && result.state() is 'rejected') &&
             $.isFunction(dfd = @queue[0].deferred)
            dfd result
          @_done()
      else
        @_done()
            
      $.when(result).then @_next, if @opts.stopOnError then @stop else @_next

    _next: =>
      @_process() if @running

    _done: =>
      @queue.shift()
      @stop() unless @queue.length
