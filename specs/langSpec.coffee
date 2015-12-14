define (require) ->
  langutils = require 'langutils'
  Handlebars = require 'handlebars'

  ret =
    test: ->
      describe 'lang', ->
        beforeEach ->
          window.ntConfig = foo: 'bar'

          @strs =
            greet       : 'Hello There!'
            greet_name  : 'Hello #{name}'
            have_things : 'I have #{n thing|things}'
            cfg_me      : 'Chocolate #{cfg.foo}'
            small_html  : 'Hello <b>There</b>!'
            html_enc    : 'Hello <b>There</b>!'
            bye         : 'Bye'
            hi_html     : '<b>Hi</b>'

          @_lang = langutils.preprocess @strs

          @getLang = (str, opts) =>
            langutils.getLang str, @_lang, opts

        it 'gets basic lang', ->
          expect(@getLang 'greet').toEqual 'Hello There!'
          expect(@getLang 'cfg_me').toEqual 'Chocolate bar'

        it 'interpolates lang', ->
          expect(@getLang 'greet', vars: dummy: 1).toEqual 'Hello There!'
          expect(@getLang 'greet_name', vars: name: 'Ripley').toEqual \
            'Hello Ripley'
          expect(@getLang 'have_things', vars: n: 1).toEqual \
            'I have 1 thing'
          expect(@getLang 'have_things', vars: n: 3).toEqual \
            'I have 3 things'
          expect(@getLang 'dummy', default: 'bye').toEqual 'Bye'

        it 'interpolates html', ->
          Handlebars.registerHelper 'lang', (key, opts) =>
            if _.isObject key
              opts = _.omit key, 'key'
              key = key.key

            @getLang key, _.extend hbs: true, opts

          html_noenc = @strs.small_html
          html_enc = $.ntEncodeHtml @strs.small_html

          expect(@getLang 'small', encode: true).toEqual html_noenc
          expect(@getLang 'small_html', encode: true).toEqual html_noenc
          expect(@getLang 'html_enc', encode: true).toEqual html_enc
          expect(@getLang 'html_enc').toEqual html_noenc
          expect(@getLang 'dummy', default: 'hi').toEqual '<b>Hi</b>'

          tpl = "<div>{{lang 'greet'}}</div><p>{{lang vars.myvar}}</p>" +
            "<p>{{lang 'small_html'}}</p><div>{{lang 'html_enc'}}</div>"
          templateFunc = Handlebars.compile tpl
          text = templateFunc vars: myvar: 'cfg_me'

          expect(text).toEqual '<div>Hello There!</div><p>Chocolate bar</p>' +
            "<p>#{html_noenc}</p><div>#{html_enc}</div>"

  ret
