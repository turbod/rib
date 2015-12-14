define (require) ->
  vent = require 'vent'
  utils = require 'utils'

  class Router extends Backbone.Router
    initialize: (opts) ->
      utils.adoptProps @, opts, 'errorView', 'errorViewOpts'
      @viewRoutes = {}

      @addRoute opts?.viewRoutes

      vent.on 'route', @callRoute

    _createRoute: (view, parnames) =>
      ->
        opts = {}
        opts[parname] = arguments[i] for parname, i in parnames if parnames
        vent.trigger 'view:load', view, opts

    addRoute: (view, params) ->
      return unless view

      if _.isObject view
        routes = _.clone view
      else
        routes = {}
        routes[view] = _.clone params

      for v, p of routes
        p.callback = @_createRoute v, p.parnames
        @route p.route, v.toLowerCase(), p.callback

      _.extend @viewRoutes, routes

    checkRoute: (dst) =>
      dst = (dst || '').replace /^\//, ''
      for v, p of @viewRoutes
        if dst is p.route ||
            p.route instanceof RegExp && pars = dst.match p.route
          ret =
            callback : p.callback
            pars     : pars
          break

      ret

    callRoute: (dst) =>
      route_data = @checkRoute dst

      if route_data
        route_data.callback.apply @, (route_data.pars || []).slice(1)
      else if @errorView
        vent.trigger 'view:load', @errorView, @errorViewOpts
