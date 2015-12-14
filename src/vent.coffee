define (require) ->
  _ = require 'underscore'
  Backbone = require 'backbone'

  _.extend {}, Backbone.Events
