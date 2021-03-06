Ext = window.Ext4 || window.Ext

Ext.require [
  'Rally.test.apps.roadmapplanningboard.helper.TestDependencyHelper'
  'Rally.apps.roadmapplanningboard.plugin.RoadmapScrollable'
  'Rally.apps.roadmapplanningboard.PlanningBoard',
  'Rally.apps.roadmapplanningboard.AppModelFactory'
]

describe 'Rally.apps.roadmapplanningboard.plugin.RoadmapScrollable', ->

  helpers
    createBacklogColumn: (id) ->
      xtype: 'backlogplanningcolumn'
      testId: "#{id}"
      typeNames:
        child:
          name: 'Feature'

    createColumn: (id, date = new Date(), offset = 0) ->
      timeframeRecord = Ext.create Rally.apps.roadmapplanningboard.AppModelFactory.getTimeframeModel(),
        id: "#{id}"
        name: "#{id}"
        startDate: Ext.Date.add(date, Ext.Date.MONTH, offset-1)
        endDate: Ext.Date.add(Ext.Date.add(date, Ext.Date.MONTH, offset), Ext.Date.DAY, -1)
      planRecord = Ext.create Rally.apps.roadmapplanningboard.AppModelFactory.getPlanModel(),
        id: "#{id}"
        name: "#{id}"
        timeframe: timeframeRecord.data

      return {
        xtype: 'timeframeplanningcolumn'
        testId: "#{id}"
        timeframeRecord: timeframeRecord
        planRecord: planRecord
        typeNames:
          child:
            name: 'Feature'
        columnHeaderConfig:
          record: timeframeRecord
          fieldToDisplay: 'name'
          editable: true
        columnConfig: {}
      }

    createCardboard: (config) ->
      roadmapStore = Deft.Injector.resolve('roadmapStore')
      timelineStore = Deft.Injector.resolve('timelineStore')
      config = _.extend
        roadmap: roadmapStore.first()
        timeline: timelineStore.first()
        timeframeColumnCount: 4
        pastColumnCount: 1
        presentColumnCount: 5
        isAdmin: true
        typeNames:
          child:
            name: 'Feature'
      , config

      id = 0
      date = config.date || new Date(Ext.Date.format(new Date(), 'Y-m-d'))

      columns = [
        @createBacklogColumn(id++)
      ]

      columns = columns.concat (@createColumn(num, date, num-config.pastColumnCount) for num in [id...id+(config.pastColumnCount or 0)])
      id += config.pastColumnCount
      columns = columns.concat (@createColumn(num, date, num-config.pastColumnCount) for num in [id...id+(config.presentColumnCount or 0)])

      @cardboard = Ext.create 'Rally.apps.roadmapplanningboard.PlanningBoard',
        _.extend
          buildColumns: ->
            @columns = columns

          renderTo: 'testDiv'

          plugins: [
            ptype: 'rallytimeframescrollablecardboard', timeframeColumnCount: config.timeframeColumnCount
          ]

          slideDuration: 10
        , config

      @plugin = @cardboard.plugins[0]

      @waitForComponentReady(@cardboard)

    scrollBackwards: ->
      @click(className: 'scroll-backwards')

    scrollForwards: ->
      @click(className: 'scroll-forwards')

    getForwardsButton: -> @cardboard.forwardsButton

    getBackwardsButton: -> @cardboard.backwardsButton

    getColumnHeaderCells: ->
      @cardboard.getEl().query('th.card-column')

    getColumnContentCells: ->
      @cardboard.getEl().query('td.card-column')

    clickTheme: ->
      collapseStub = @stub()
      @cardboard.on 'headersizechanged', collapseStub
      @click(css: '.theme-button').then =>
        @once
          condition: ->
            collapseStub.called

    clickAddNewButton: ->
      @click(css: '.scroll-button.right')

    getThemeElements: ->
      _.map(@cardboard.getEl().query('.theme_container'), Ext.get)

    assertButtonIsInColumnHeader: (button, column) ->
      expect(column.getColumnHeader().getEl().getById(button.getEl().id)).not.toBeNull()

  beforeEach ->
    Rally.test.apps.roadmapplanningboard.helper.TestDependencyHelper.loadDependencies()
    @timeframeStore = Deft.Injector.resolve('timeframeStore')
    @planStore = Deft.Injector.resolve('planStore')
    @ajax.whenQuerying('PortfolioItem/Feature').respondWith([])

  describe 'scrollable board setup', ->

    it 'should get a list of scrollable columns', ->
      @createCardboard(pastColumnCount: 0, presentColumnCount: 6).then =>
        expect(@plugin.getScrollableColumns()).toEqual @cardboard.getColumns().slice(1)

    it 'should get the last visible scrollable column', ->
      @createCardboard(pastColumnCount: 0, presentColumnCount: 6).then =>
        expect(@plugin.getLastVisibleScrollableColumn().testId).toEqual '4'

    it 'should get the first visible scrollable column', ->
      @createCardboard(pastColumnCount: 0, presentColumnCount: 6).then =>
        expect(@plugin.getFirstVisibleScrollableColumn().testId).toEqual '1'

    it 'should restrict the number of columns on the component', ->
      @createCardboard(pastColumnCount: 0, presentColumnCount: 6, timeframeColumnCount: 4).then =>
        expect(@plugin.buildColumns().length).toEqual 5 # 4 + 1 backlog

    it 'should not show past timeframes', ->
      @createCardboard(pastColumnCount: 4, presentColumnCount: 4, timeframeColumnCount: 4).then =>
        expect(@plugin.getFirstVisibleScrollableColumn().testId).toEqual '5'

    it 'should show current timeframe if the timeframe ends today', ->
      tomorrow = Ext.Date.add(new Date(), Ext.Date.DAY, 1) # This will actually move a past column to the present columns
      @createCardboard(pastColumnCount: 4, presentColumnCount: 4, date: tomorrow).then =>
        expect(@plugin.getFirstVisibleScrollableColumn().testId).toEqual '4'

    it 'should show a left scroll arrow for past timeframes', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 4, timeframeColumnCount: 4).then =>
        expect(@getBackwardsButton().hidden).toBe false

    it 'should show a right scroll arrow for extra future timeframes', ->
      @createCardboard(pastColumnCount: 0, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        expect(@getForwardsButton().hidden).toBe false

    it 'should not show a left scroll arrow if there are no past timeframes', ->
      @createCardboard(pastColumnCount: 0, presentColumnCount: 4, timeframeColumnCount: 4).then =>
        expect(@getBackwardsButton().hidden).toBe true

    it 'should not show a right scroll arrow if there are no extra future timeframes', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 4, timeframeColumnCount: 4).then =>
        expect(@getForwardsButton().hidden).toBe true

    it 'should fill in extra columns if not enough columns are provided', ->
      @createCardboard(timeframeColumnCount: 2, presentColumnCount: 1).then =>
        expect(@plugin.getScrollableColumns().length).toBe 2

    it 'should not show a forward button when not enough columns are provided', ->
      @createCardboard(timeframeColumnCount: 2, presentColumnCount: 1).then =>
        expect(@getForwardsButton().hidden).toBe true

    it 'should fill in all columns if none are provided', ->
      @createCardboard(timeframeColumnCount: 3, presentColumnCount: 0, pastColumnCount: 0).then =>
        expect(@plugin.getScrollableColumns().length).toBe 3

  describe 'add new column button', ->

    describe 'one present column', ->

      beforeEach ->
        @createCardboard(timeframeColumnCount: 3, presentColumnCount: 1, pastColumnCount: 0)

      describe 'when clicked', ->

        beforeEach ->
          @clickAddNewButton()

        it 'should replace a placeholder column with a new timeframe column', ->
          expect(Ext.ComponentQuery.query('timeframeplanningcolumn').length).toBe 2

        it 'should make the new column be the second timeframe column', ->
          expect(@cardboard.getColumns()[2].columnHeader.down('rallyclicktoeditfieldcontainer').getValue()).toBe 'New Timeframe'

        it 'should not display a forwards scroll button', ->
          expect(@getForwardsButton().isVisible()).toBe false

        it 'should not display a backwards scroll button', ->
          expect(@getBackwardsButton().isVisible()).toBe false

    describe 'with one past column and no present columns', ->

      beforeEach ->
        @createCardboard(timeframeColumnCount: 3, presentColumnCount: 0, pastColumnCount: 1)

      it 'should be rendered in the last column', ->
        @assertButtonIsInColumnHeader @cardboard.addNewColumnButton, @plugin.getLastVisibleScrollableColumn()

      describe 'when clicked', ->

        beforeEach ->
          @clickAddNewButton()

        it 'should add a new column', ->
          expect(Ext.ComponentQuery.query('timeframeplanningcolumn').length).toBe 1

        it 'should make the new column be the first column', ->
          expect(@cardboard.getColumns()[1].columnHeader.down('rallyclicktoeditfieldcontainer').getValue()).toBe 'New Timeframe'

        it 'should put the field in edit mode', ->
          expect(@cardboard.getColumns()[1].columnHeader.down('rallyclicktoeditfieldcontainer').getEditMode()).toBeTruthy()

        it 'should update the timeframe store', ->
          expect(_.last(@timeframeStore.data.items).get('name')).toBe 'New Timeframe'

        it 'should update the plan store', ->
          expect(_.last(@planStore.data.items).get('name')).toBe 'New Plan'

        it 'should not display a forwards scroll button', ->
          expect(@getForwardsButton().isVisible()).toBe false

        describe 'when scrolling backwards', ->
          beforeEach ->
            @scrollBackwards()

          it 'should scroll correctly', ->
            expect(@cardboard.getColumns()[2].columnHeader.down('rallyclicktoeditfieldcontainer').getValue()).toBe 'New Timeframe'

    describe 'with present and future columns', ->

      beforeEach ->
        @createCardboard(timeframeColumnCount: 3, presentColumnCount: 4, pastColumnCount: 0)

      it 'should be undefined', ->
        expect(@cardboard.addNewColumnButton).toBeUndefined()

      describe 'when forward scroll button is clicked', ->

        beforeEach ->
          @scrollForwards()

        it 'should render', ->
          expect(@cardboard.addNewColumnButton.rendered).toBeTruthy()

        describe 'when clicked', ->

          beforeEach ->
            @clickAddNewButton()

          it 'should add a new column', ->
            expect(@plugin.scrollableColumns.length).toBe 5

          it 'should make the new column be the last column', ->
            expect(_.last(@cardboard.getColumns()).columnHeader.down('rallyclicktoeditfieldcontainer').getValue()).toBe 'New Timeframe'

          it 'should put the field in edit mode', ->
            expect(_.last(@cardboard.getColumns()).columnHeader.down('rallyclicktoeditfieldcontainer').getEditMode()).toBeTruthy()

          it 'should update the timeframe store', ->
            expect(_.last(@timeframeStore.data.items).get('name')).toBe 'New Timeframe'

          it 'should update the plan store', ->
            expect(_.last(@planStore.data.items).get('name')).toBe 'New Plan'

  describe 'when back scroll button is clicked', ->

    it 'should scroll backward', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 4, timeframeColumnCount: 4).then =>
        @scrollBackwards().then =>
          expect(@plugin.getFirstVisibleScrollableColumn().timeframeRecord.getId()).toEqual '1'
          expect(@getBackwardsButton().hidden).toBe true

    it 'should contain the same number of columns', ->
      @createCardboard(pastColumnCount: 4, presentColumnCount: 4, timeframeColumnCount: 4).then =>
        @scrollBackwards().then =>
          expect(@plugin.getScrollableColumns().length).toEqual 4

    it 'should show 1 header cell for each column', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollBackwards().then =>
          expect(@getColumnHeaderCells().length).toBe 5 # 4 + 1 backlog

    it 'should show 1 content cell for each column', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollBackwards().then =>
          expect(@getColumnContentCells().length).toBe 5 # 4 + 1 backlog

    it 'should render newly visible column in left-most column', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollBackwards().then =>
          expect(@plugin.getFirstVisibleScrollableColumn().getColumnHeaderCell().dom).toBe @getColumnHeaderCells()[1]
          expect(@plugin.getFirstVisibleScrollableColumn().getContentCell().dom).toBe @getColumnContentCells()[1]

    it 'should re-render scroll buttons', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollBackwards().then =>
          @assertButtonIsInColumnHeader @getForwardsButton(), @plugin.getLastVisibleScrollableColumn()
          @assertButtonIsInColumnHeader @getBackwardsButton(), @plugin.getFirstVisibleScrollableColumn()

    it 'should destroy old scroll buttons', ->
      @createCardboard(pastColumnCount: 2, presentColumnCount: 6, timeframeColumnCount: 4).then =>
        @scrollBackwards().then =>
          expect(@cardboard.getEl().query('.scroll-button').length).toBe 2

    it 'should filter newly added column', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        filterSpy = @spy @cardboard, 'applyLocalFilters'
        @scrollBackwards().then =>
          expect(filterSpy.callCount).toBe 1

    it 'should handle only 1 column', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 1, timeframeColumnCount: 1).then =>
        @scrollBackwards().then =>
          expect(@plugin.getFirstVisibleScrollableColumn().timeframeRecord.getId()).toEqual '1'

    it 'should scroll with placeholder columns', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 1, timeframeColumnCount: 4).then =>
        @scrollBackwards().then =>
          expect(@getColumnContentCells().length).toBe 5 # 2 + 1 backlog

  describe 'when forward scroll button is clicked', ->

    it 'should scroll forward', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollForwards().then =>
          expect(@plugin.getFirstVisibleScrollableColumn().timeframeRecord.getId()).toEqual '3'
          expect(@getForwardsButton().hidden).toBe true

    it 'should contain the same number of columns', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollForwards().then =>
          expect(@plugin.getScrollableColumns().length).toEqual 4

    it 'should show 1 header cell for each column', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollForwards().then =>
          expect(@getColumnHeaderCells().length).toBe 5 # 4 + 1 backlog

    it 'should show 1 content cell for each column', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollForwards().then =>
          expect(@getColumnContentCells().length).toBe 5 # 4 + 1 backlog

    it 'should render newly visible column in right-most column', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollForwards().then =>
          expect(@plugin.getLastVisibleScrollableColumn().getColumnHeaderCell().dom).toBe (_.last @getColumnHeaderCells())
          expect(@plugin.getLastVisibleScrollableColumn().getContentCell().dom).toBe (_.last @getColumnContentCells())

    it 'should re-render scroll buttons', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        @scrollForwards().then =>
          @assertButtonIsInColumnHeader @getForwardsButton(), @plugin.getLastVisibleScrollableColumn()
          @assertButtonIsInColumnHeader @getBackwardsButton(), @plugin.getFirstVisibleScrollableColumn()

    it 'should destroy old scroll buttons', ->
      @createCardboard(pastColumnCount: 2, presentColumnCount: 6, timeframeColumnCount: 4).then =>
        @scrollForwards().then =>
          expect(@cardboard.getEl().query('.scroll-button').length).toBe 2

    it 'should filter newly added column', ->
      @createCardboard(pastColumnCount: 1, presentColumnCount: 5, timeframeColumnCount: 4).then =>
        filterSpy = @spy @cardboard, 'applyLocalFilters'
        @scrollForwards().then =>
          expect(filterSpy.callCount).toBe 1

    it 'should handle only 1 column', ->
      @createCardboard(pastColumnCount: 0, presentColumnCount: 2, timeframeColumnCount: 1).then =>
        @scrollForwards().then =>
          expect(@plugin.getFirstVisibleScrollableColumn().timeframeRecord.getId()).toEqual '2'

    it 'should scroll back and forward again with placeholder columns', ->
      @createCardboard(pastColumnCount: 2, presentColumnCount: 1, timeframeColumnCount: 3).then =>
        @scrollBackwards().then =>
          @scrollForwards().then =>
            expect(@getColumnContentCells().length).toBe 4 # 2 + 1 backlog

  describe 'theme container interactions', ->

    describe 'when scrolling backward', ->

      it 'should show expanded themes', ->
        @createCardboard().then =>
          @scrollBackwards().then =>
            _.each @getThemeElements(), (element) =>
              expect(element.isVisible()).toBe true
              expect(element.query('.field_container').length).toBe 1

      it 'should collapse themes when the theme collapse button is clicked', ->
        @createCardboard().then =>
          @scrollBackwards().then =>
            @clickTheme().then =>
              _.each @getThemeElements(), (element) =>
                expect(element.isVisible()).toBe false

      it 'should expand themes when the theme expand button is clicked', ->
        @createCardboard(showTheme: false).then =>
          @scrollBackwards().then =>
            @clickTheme().then =>
              _.each @getThemeElements(), (element) =>
                expect(element.isVisible()).toBe true
                expect(element.query('.field_container').length).toBe 1

    describe 'when scrolling forward', ->

      it 'should show expanded themes', ->
        @createCardboard().then =>
          @scrollForwards().then =>
            _.each @getThemeElements(), (element) =>
              expect(element.isVisible()).toBe true
              expect(element.query('.field_container').length).toBe 1

      it 'should collapse themes when the theme collapse button is clicked', ->
        @createCardboard().then =>
          @scrollForwards().then =>
            @clickTheme().then =>
              _.each @getThemeElements(), (element) =>
                expect(element.isVisible()).toBe false

      it 'should expand themes when the theme expand button is clicked', ->
        @createCardboard(showTheme: false).then =>
          @scrollForwards().then =>
            @clickTheme().then =>
              _.each @getThemeElements(), (element) =>
                expect(element.isVisible()).toBe true
                expect(element.query('.field_container').length).toBe 1
