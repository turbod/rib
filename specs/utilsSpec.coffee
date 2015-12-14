define (require) ->
  utils = require 'utils'
  moment = require 'moment'

  ret =
    test: ->
      describe 'utils', ->
        it 'chkEmail', ->
          for str in [ 'jetli123@hero.org',
                       'HiroyukiSanada@Ninja86.jp',
                       'van-damme.dolph_lundgren@some.uni-soldier.com' ]
            out = utils.chkEmail str
            expect(out).toBeTruthy()

          for str in [ 'hello', 'hello@', 'hello@baby', '@baby' ]
            out = utils.chkEmail str
            expect(out).not.toBeTruthy()

        it 'chkIP', ->
          for str in [ '192.168.10.124', '10.2.4.1', '250.0.255.100' ]
            expect(utils.chkIP str).toBeTruthy()

          for str in [ '192', '192.168.10', 'asdf', '123.256.1.1' ]
            expect(utils.chkIP str).not.toBeTruthy()

        it 'chkHost', ->
          for str in [ 'jetli123@hero.org'
                       '@ninja.edu'
                       '!hello'
                       'hello-'
                       [11 .. 32].join('-')
                       [8 .. 72].join('.a') ]
            expect(utils.chkHost str).not.toBeTruthy()

          for str in [ 'test'
                       'google.com'
                       'rambo-online.2rockets.org'
                       [11 .. 31].join('-')
                       [7 .. 71].join('.a') ]
            expect(utils.chkHost str).toBeTruthy()

        it 'extractKeywords', ->
          tests = [
            str : '"John Doe " superhero " Jack  " '
            res : [ 'John Doe', 'superhero', 'Jack' ]
          ,
            str : ' hello   baby  " "hero " '
            res : [ 'hello', 'baby', 'hero', '"' ]
          ,
            str  : 'he is {John Rambo} [ ] super [soldier] "big blade"'
            opts : '"' : '', '[]' : 'job', '{}' : 'name'
            res  :
              ''     : [ 'he', 'is', 'super', 'big blade' ]
              'job'  : [ 'soldier' ]
              'name' : [ 'John Rambo' ]
          ]

          for test in tests
            expect(utils.extractKeywords test.str, test.opts).toEqual test.res

        it 'throwError', ->
          expect ->
            utils.throwError 'test error'
          .toThrow new Error 'test error'

        it 'calcRank', ->
          out = utils.calcRank()
          expect(out).toEqual 1

          out = utils.calcRank 1, 2
          expect(out).toEqual 1.5

          out = utils.calcRank null, 4.5
          expect(out).toEqual 2.25

          out = utils.calcRank 5.25
          expect(out).toEqual 6.25

          expect ->
            utils.calcRank null, '1'
          .toThrow new Error 'Invalid parameters for calcRank'

          expect ->
            utils.calcRank { a: 'b' }
          .toThrow new Error 'Invalid parameters for calcRank'

        describe 'dates & times', ->
          beforeEach ->
            @dbdate = '2014-12-23 13:41:54'
            @dbdate_ms = @dbdate + '.432765'
            @isodate = moment.utc(@dbdate).local().format 'YYYY-MM-DDTHH:mm:ss'
            @isodate_ms = @isodate + '.432'

          it 'date check & helpers', ->
            # getFrac
            expect(utils.getFrac @dbdate_ms).toEqual '.432'
            expect(utils.getFrac @dbdate_ms, prec: 4).toEqual '.4327'
            expect(utils.getFrac @dbdate).toBeUndefined()

            # isValidDbDate
            expect(utils.isValidDbDate @dbdate).toBeTruthy()
            expect(utils.isValidDbDate @dbdate_ms).toBeTruthy()
            expect(utils.isValidDbDate @isodate).not.toBeTruthy()
            expect(utils.isValidDbDate '2005').not.toBeTruthy()

            # isValidIsoDate
            expect(utils.isValidIsoDate @isodate).toBeTruthy()
            expect(utils.isValidIsoDate @isodate_ms).toBeTruthy()
            expect(utils.isValidIsoDate @dbdate).not.toBeTruthy()
            expect(utils.isValidIsoDate @isodate + '.1234').not.toBeTruthy()
            expect(utils.isValidIsoDate '2005').not.toBeTruthy()

            # parseMidnight
            for str in [ '12/12/2013 12:01a', '0:02 12/12/2013', '12/12/12',
                         '12:01', '0:12', '12pm', '12 pm' ]
              expect(utils.parseMidnight str).not.toBeTruthy()

            for str in [ '12/12/2013 12a', '12/12/2013 12am',
                         '12/12/2013 12:00a', '12/12/2013 12:00am',
                         '12/12/2013 12:00:00 a', '12/12/2013 12:00:00 am',
                         '0 12/12/12', '0:0 12/12/12', '00:00:00 12/12/12',
                         '00:00', '00:00:00', '12a', '12am', '12:00 am',
                         '12:00:00 a', '12:00:00 am' ]
              expect(utils.parseMidnight str).toBeTruthy()

          it 'db date parse & convert', ->
            # parseDbDate
            expect(utils.parseDbDate(@dbdate).format 'YYYY-MM-DDTHH:mm:ss')
              .toEqual @isodate
            expect(utils.parseDbDate(@dbdate_ms).format 'YYYY-MM-DDTHH:mm:ss.SSS')
              .toEqual @isodate_ms

            # dbDateToIso
            expect(utils.dbDateToIso @dbdate).toEqual @isodate
            expect(utils.dbDateToIso @dbdate_ms).toEqual @isodate_ms
            expect(utils.dbDateToIso @isodate).toEqual @isodate
            expect(utils.dbDateToIso '2005').toEqual '2005'

            # isoToDbDate
            expect(utils.isoToDbDate @isodate).toEqual @dbdate
            expect(utils.isoToDbDate @isodate_ms).toEqual @dbdate + '.432'
            expect(utils.isoToDbDate @dbdate).toEqual @dbdate
            expect(utils.isoToDbDate '2005').toEqual '2005'

          it 'parse date & time', ->
            # parseDate
            expect(utils.parseDate(@dbdate).format 'YYYY-MM-DDTHH:mm:ss')
              .toEqual @isodate
            expect(utils.parseDate(@isodate).format 'YYYY-MM-DDTHH:mm:ss')
              .toEqual @isodate
            expect(utils.parseDate('16 Feb').format 'YYYY-MM-DD')
              .toEqual moment().format('YYYY') + '-02-16'

            # parseTime
            expect(utils.parseTime('3 pm').format 'HH:mm').toEqual '15:00'
            expect(utils.parseTime('4:12 am').format 'HH:mm').toEqual '04:12'

          it 'format date & time', ->
            # formatDate
            expect(utils.formatDate moment(@isodate), db: true)
              .toEqual @dbdate.split(' ')[0]
            expect(utils.formatDate moment(@isodate), iso: true)
              .toEqual @isodate.split('T')[0]
            expect(utils.formatDate moment(@isodate), time: true, db: true)
              .toEqual @dbdate
            expect(utils.formatDate moment(@isodate), time: true, iso: true)
              .toEqual @isodate

          it 'display smart date', ->
            # today
            time = moment().hours(16).minutes(0)
            expect(utils.formatDateTimeSmart(time)).toEqual '4pm'

            # other day this month
            time.date(if time.date() == 16 then 1 else 16)
            expect(utils.formatDateTimeSmart(time))
              .toEqual "#{time.format('D MMM')} #{time.format('ha')}"

            # other year in january
            time.year(time.year() + 2).month(0)
            expect(utils.formatDateTimeSmart(time))
              .toEqual "#{time.format('D MMM YYYY')} #{time.format('ha')}"

            # within 6 months
            time = moment().minutes(0).subtract('months', 5)
            expect(utils.formatDateTimeSmart(time))
              .toEqual "#{time.format('D MMM')} #{time.format('ha')}"

            # outside 6 months
            time = moment().minutes(0).subtract('months', 7)
            expect(utils.formatDateTimeSmart(time))
              .toEqual "#{time.format('D MMM YYYY')} #{time.format('ha')}"

        describe 'ntConfig tests', ->
          beforeEach ->
            window.ntConfig =
              foo   : '/n/'
              hello : [ 'A', 'B' ]

          it 'getConfig', ->
            cfg = utils.getConfig 'foo'

            expect(cfg).toEqual '/n/'

            cfg = utils.getConfig 'hello'

            expect(cfg).toEqual [ 'A', 'B' ]

          it 'setConfig', ->
            utils.setConfig 'foo', mycfg: 34

            expect(window.ntConfig.foo).toEqual mycfg: 34

            utils.setConfig
              hello1 : 13
              hello2 : [ 'hi', 23 ]

            expect(window.ntConfig.hello1).toEqual 13
            expect(window.ntConfig.hello2).toEqual [ 'hi', 23 ]
            expect(window.ntConfig.hello).toEqual [ 'A', 'B' ]

        describe 'ntStatus tests', ->
          beforeEach ->
            window.ntStatus =
              foo   : '/n/'
              hello : [ 'A', 'B' ]

          it 'getStatus', ->
            cfg = utils.getStatus 'foo'

            expect(cfg).toEqual '/n/'
            expect(window.ntStatus.foo).toBeUndefined()

            cfg = utils.getStatus 'hello'

            expect(cfg).toEqual [ 'A', 'B' ]
            expect(window.ntStatus.hello).toBeUndefined()

          it 'setStatus', ->
            utils.setStatus 'foo', mycfg: 34

            expect(window.ntStatus.foo).toEqual mycfg: 34

            utils.setStatus
              hello1 : 13
              hello2 : [ 'hi', 23 ]

            expect(window.ntStatus.hello1).toEqual 13
            expect(window.ntStatus.hello2).toEqual [ 'hi', 23 ]
            expect(window.ntStatus.hello).toEqual [ 'A', 'B' ]

          it 'delStatus', ->
            utils.delStatus 'foo'

            expect(window.ntStatus.foo).toBeUndefined()

        describe 'maxVersion / isNewerVersion', ->
          it 'maxVersion', ->
            expect(utils.maxVersion('1.2', '1.1.0', '1.3')).toEqual '1.3'
            expect(utils.maxVersion('1.2', '1.8.9', 3, '0.1')).toEqual 3

          it 'isNewerVersion', ->
            expect(utils.isNewerVersion('1.2', '1.4')).toBeTruthy()
            expect(utils.isNewerVersion('1.2.3', '1.2.6')).toBeTruthy()
            expect(utils.isNewerVersion('1.2', '1.2')).not.toBeTruthy()
            expect(utils.isNewerVersion('1.2.3', '1.2.2')).not.toBeTruthy()

  ret
