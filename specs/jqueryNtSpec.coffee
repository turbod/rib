define (require) ->
  _ = require 'underscore'
  jquerynt = require 'jquerynt'

  ret =
    test: ->
      describe 'ntEncodeHtml / ntDecodeHtml', ->
        decPattern = "< Test >  test\n&"
        encPattern = '&lt; Test &gt;&nbsp;&nbsp;test<br/>&amp;'

        it 'ntDecodeHtml Basic', ->
          out = $.ntDecodeHtml encPattern
          expect(out).toEqual decPattern

        it 'ntDecodeHtml Spaces & Newlines', ->
          out = $.ntDecodeHtml '   Test  &nbsp;test<br/> <br>'
          expect(out).toEqual "Test  test"

        it 'ntEncodeHtml Basic', ->
          out = $.ntEncodeHtml decPattern
          expect(out).toEqual encPattern

        it 'ntEncodeHtml Spaces & Newlines', ->
          out = $.ntEncodeHtml "  Test\ntest Test\n"
          expect(out).toEqual '&nbsp;&nbsp;Test<br/>test Test<br/>&nbsp;'

      describe 'ntResult', ->
        it 'ntResult obj', ->
          obj = foo: 'bar'
          expect($.ntResult obj, 'foo').toEqual 'bar'

          obj = foo: -> 'circle'
          expect($.ntResult obj, 'foo').toEqual 'circle'

          obj = foo: (par1, par2) -> par1 + par2
          expect($.ntResult obj, 'foo', 3, 4).toEqual 7

      describe 'ntQuoteMeta', ->
        it 'ntQuoteMeta Basic', ->
          str = $.ntQuoteMeta()
          expect(str).toEqual ''

          str = $.ntQuoteMeta('A1.\\+*?[^]$()')
          expect(str).toEqual 'A1\\.\\\\\\+\\*\\?\\[\\^\\]\\$\\(\\)'

      describe 'ntBrowser', ->
        it 'checks user agent correctly', ->
          data =
            chrome:
              '31' : [
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1650.57 Safari/537.36'
                'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1650.57 Safari/537.36'
              ]

            safari:
              '7' : 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9) AppleWebKit/537.71 (KHTML, like Gecko) Version/7.0 Safari/537.71'

            firefox:
              '25' : [
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:25.0) Gecko/20100101 Firefox/25.0'
                'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:25.0) Gecko/20100101 Firefox/25.0'
              ]

            ie:
              '11' : 'Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E; rv:11.0) like Gecko'
              '10' : 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)'
              '9'  : 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)'
              '8'  : 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729)'

          for browser, versions of data
            for version, ua of versions
              ua = [ ua ] unless $.isArray ua
              for uastr in ua
                expect($.ntBrowser(browser, version, uastr)).toBeTruthy()
                expect($.ntBrowser(browser, version + '+', uastr)).toBeTruthy()
                expect($.ntBrowser(browser, version + '-', uastr)).toBeTruthy()

                prev_version = parseInt(version - 1)
                expect($.ntBrowser(browser, prev_version, uastr)).not.toBeTruthy()
                expect($.ntBrowser(browser, prev_version + '+', uastr)).toBeTruthy()
                expect($.ntBrowser(browser, prev_version + '-', uastr)).not.toBeTruthy()

                next_version = parseInt(version + 1)
                expect($.ntBrowser(browser, next_version, uastr)).not.toBeTruthy()
                expect($.ntBrowser(browser, next_version + '+', uastr)).not.toBeTruthy()
                expect($.ntBrowser(browser, next_version + '-', uastr)).toBeTruthy()

                for b of data
                  crosstest = $.ntBrowser b, null, uastr
                  if b is browser
                    expect(crosstest).toBeTruthy()
                  else
                    expect(crosstest).not.toBeTruthy()

  ret
