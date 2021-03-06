Ext = window.Ext4 || window.Ext

Ext.require [
  'Rally.apps.iterationtrackingboard.IterationTrackingBoardApp'
  'Rally.util.DateTime'
  'Rally.app.Context',
  'Rally.domain.Subscription'
]

describe 'Rally.apps.iterationtrackingboard.IterationTrackingBoardApp', ->

  helpers
    createApp: (config)->
      now = new Date(1384305300 * 1000);
      tomorrow = Rally.util.DateTime.add(now, 'day', 1)
      nextDay = Rally.util.DateTime.add(tomorrow, 'day', 1)
      dayAfter = Rally.util.DateTime.add(nextDay, 'day', 1)
      @iterationData = [
        {Name:'Iteration 1', _ref:'/iteration/0', StartDate: now, EndDate: tomorrow}
        {Name:'Iteration 2', _ref:'/iteration/2', StartDate: nextDay, EndDate: dayAfter}
      ]

      @IterationModel = Rally.test.mock.data.WsapiModelFactory.getIterationModel()
      @iterationRecord = new @IterationModel @iterationData[0]

      @app = Ext.create('Rally.apps.iterationtrackingboard.IterationTrackingBoardApp', Ext.apply(
        context: Ext.create('Rally.app.Context',
          initialValues:
            timebox: @iterationRecord
            project:
              _ref: @projectRef
        ),
        renderTo: 'testDiv'
      , config))

      @waitForComponentReady(@app)

    getIterationFilter: ->
      iteration = @iterationData[0]

      [
        { property: 'Iteration.Name', operator: '=', value: iteration.Name }
        { property: "Iteration.StartDate", operator: '=', value: Rally.util.DateTime.toIsoString(iteration.StartDate) }
        { property: "Iteration.EndDate", operator: '=', value: Rally.util.DateTime.toIsoString(iteration.EndDate) }
      ]

    stubRequests: ->
      @ajax.whenQueryingAllowedValues('userstory', 'ScheduleState').respondWith(["Defined", "In-Progress", "Completed", "Accepted"]);

      @ajax.whenQuerying('artifact').respondWith [{
        RevisionHistory: {
          _ref: '/revisionhistory/1'
        }
      }]

    toggleToBoard: ->
      @app.gridboard.setToggleState('board')

    toggleToGrid: ->
      @app.gridboard.setToggleState('grid')

    stubFeatureToggle: (toggles) ->
      stub = @stub(Rally.app.Context.prototype, 'isFeatureEnabled');
      stub.withArgs(toggle).returns(true) for toggle in toggles
      stub

  beforeEach ->
    @ajax.whenReading('project').respondWith {
      TeamMembers: []
      Editors: []
    }

    @stubRequests()

    @tooltipHelper = new Helpers.TooltipHelper this

  afterEach ->
    @app?.destroy()

  describe 'when blank slate is not shown', ->
    it 'should show field picker in settings ', ->
      @createApp(isShowingBlankSlate: -> false).then =>
        @app.showFieldPicker = true
        expect(Ext.isObject(_.find(@app.getSettingsFields(), name: 'cardFields'))).toBe true

  describe 'when blank slate is shown', ->
    it 'should not show field picker in settings ', ->
      @createApp(isShowingBlankSlate: -> true).then =>
        @app.showFieldPicker = true
        expect(Ext.isEmpty(_.find(@app.getSettingsFields(), name: 'cardFields'))).toBe true

  it 'resets view on scope change', ->
    @createApp().then =>
      removeStub = @stub(@app, 'remove')

      newScope = Ext.create('Rally.app.TimeboxScope',
        record: new @IterationModel @iterationData[1]
      )

      @app.onTimeboxScopeChange newScope

      @waitForCallback(removeStub).then =>
        expect(removeStub).toHaveBeenCalledOnce()
        expect(removeStub).toHaveBeenCalledWith 'gridBoard'

        expect(@app.down('#gridBoard')).toBeDefined()

  it 'fires contentupdated event after board load', ->
    contentUpdatedHandlerStub = @stub()
    @createApp(
      listeners:
        contentupdated: contentUpdatedHandlerStub
    ).then =>
      contentUpdatedHandlerStub.reset()
      @app.gridboard.fireEvent('load')

      expect(contentUpdatedHandlerStub).toHaveBeenCalledOnce()

  it 'should include PortfolioItem in columnConfig.additionalFetchFields', ->
    @createApp().then =>
      expect(@app.gridboard.getGridOrBoard().columnConfig.additionalFetchFields).toContain 'PortfolioItem'

  it 'should have a default card fields setting', ->
    @createApp().then =>
      expect(@app.getSetting('cardFields')).toBe 'Parent,Tasks,Defects,Discussion,PlanEstimate'

  it 'should enable bulk edit when toggled on', ->
    @stubFeatureToggle ['EXT4_GRID_BULK_EDIT', 'ITERATION_TRACKING_BOARD_GRID_TOGGLE']
    @createApp().then =>
      @toggleToGrid()
      expect(@app.down('#gridBoard').getGridOrBoard().enableBulkEdit).toBe true

  it 'should filter the grid to the currently selected iteration', ->
    @stubFeatureToggle ['ITERATION_TRACKING_BOARD_GRID_TOGGLE']
    requestStub = @stubRequests()

    @createApp().then =>
      @toggleToGrid()

      expect(requestStub).toBeWsapiRequestWith filters: @getIterationFilter()

  it 'should filter the board to the currently selected iteration', ->
    @stubFeatureToggle ['ITERATION_TRACKING_BOARD_GRID_TOGGLE']
    requests = @stubRequests()

    @createApp().then =>
      @toggleToBoard()

      expect(request).toBeWsapiRequestWith(filters: @getIterationFilter()) for request in requests

  it 'should show a treegrid when treegrid toggled on', ->
    @stubFeatureToggle ['ITERATION_TRACKING_BOARD_GRID_TOGGLE', 'F2903_USE_ITERATION_TREE_GRID']

    @createApp().then =>
      @toggleToGrid()
      expect(@app.down('rallytreegrid')).not.toBeNull()
      expect(@app.down('rallygrid')).toBeNull()

  it 'should show a regular grid when treegrid toggled off', ->
    @stubFeatureToggle ['ITERATION_TRACKING_BOARD_GRID_TOGGLE']

    @createApp().then =>
      @toggleToGrid()
      expect(@app.down('rallygrid')).not.toBeNull()
      expect(@app.down('rallytreegrid')).toBeNull()

  describe '#getSettingsFields', ->

    describe 'when user is opted into beta tracking experience', ->

      it 'should have grid and board fields', ->
        @stubFeatureToggle ['ITERATION_TRACKING_BOARD_GRID_TOGGLE']

        @createApp().then =>
          settingsFields = @app.getSettingsFields()

          expect(_.find(settingsFields, {settingsType: 'grid'})).toBeTruthy()
          expect(_.find(settingsFields, {settingsType: 'board'})).toBeTruthy()

    describe 'when user is NOT opted into beta tracking experience', ->

      it 'should not have grid and board fields when BETA_TRACKING_EXPERIENCE is disabled', ->
        @createApp().then =>
          settingsFields = @app.getSettingsFields()

          expect(_.find(settingsFields, {settingsType: 'grid'})).toBeFalsy()
          expect(_.find(settingsFields, {settingsType: 'board'})).toBeTruthy()

  describe '#_getGridColumns', ->
    helpers
      _getDefaultCols: ->
        ['FormattedID', 'Name', 'ScheduleState', 'Blocked', 'PlanEstimate', 'TaskStatus', 'TaskEstimateTotal', 'TaskRemainingTotal', 'Owner', 'DefectStatus', 'Discussion']

    describe 'with the F2903_USE_ITERATION_TREE_GRID toggle on', ->
      beforeEach ->
        @stubFeatureToggle ['ITERATION_TRACKING_BOARD_GRID_TOGGLE', 'F2903_USE_ITERATION_TREE_GRID']

      it 'returns the default columns with the FormattedID removed when given no input', ->
        @createApp().then =>
          cols = @app._getGridColumns()
          expectedColumns = _.remove(@_getDefaultCols(), (col) ->
            col != 'FormattedID'
          )

          expect(cols).toEqual expectedColumns

      it 'returns the input columns with the FormattedID removed', ->
        @createApp().then =>
          cols = @app._getGridColumns(['used1', 'used2', 'FormattedID'])

          expect(cols).toEqual ['used1', 'used2']

    describe 'with the F2903_USE_ITERATION_TREE_GRID toggle off', ->
      it 'always returns the default columns when given no input', ->
        @createApp().then =>
          cols = @app._getGridColumns()

          expect(cols).toEqual @_getDefaultCols()

      it 'always returns the default columns when given column input', ->
        @createApp().then =>
          cols = @app._getGridColumns(['ignored1', 'ignored2'])

          expect(cols).toEqual @_getDefaultCols()

  describe 'with the TREE_GRID_COLUMN_FILTERING toggle on', ->
    beforeEach ->
      @stubFeatureToggle ['TREE_GRID_COLUMN_FILTERING', 'ITERATION_TRACKING_BOARD_GRID_TOGGLE', 'F2903_USE_ITERATION_TREE_GRID']

    it 'shows column menu trigger on hover for filterable column', ->
      @createApp().then =>
        @toggleToGrid()
        nameColumnHeaderSelector = '.btid-grid-header-name'
        @mouseOver(css: nameColumnHeaderSelector).then =>
          expect(@app.getEl().down("#{nameColumnHeaderSelector} .#{Ext.baseCSSPrefix}column-header-trigger").isVisible()).toBe true

    it 'has filter menu item for filterable column', ->
      @createApp().then =>
        @toggleToGrid()
        formattedIdColumnHeaderSelector = ".#{Ext.baseCSSPrefix}column-header:nth-child(3)"
        @mouseOver(css: formattedIdColumnHeaderSelector).then =>
          @click(css: "#{formattedIdColumnHeaderSelector} .#{Ext.baseCSSPrefix}column-header-trigger").then =>
            expect(Ext.getBody().down('.rally-grid-column-menu .filters-label')).not.toBeNull

  describe 'with the TREE_GRID_COLUMN_FILTERING toggle off', ->
    beforeEach ->
      @stubFeatureToggle ['ITERATION_TRACKING_BOARD_GRID_TOGGLE', 'F2903_USE_ITERATION_TREE_GRID']

    it 'does not show column menu trigger on hover for filterable column', ->
      @createApp().then =>
        @toggleToGrid()
        nameColumnHeaderSelector = '.btid-grid-header-name'
        @mouseOver(css: nameColumnHeaderSelector).then =>
          expect(@app.getEl().down("#{nameColumnHeaderSelector} .#{Ext.baseCSSPrefix}column-header-trigger")).toBeNull

  describe 'model types', ->

    beforeEach ->
      @stubFeatureToggle ['ITERATION_TRACKING_BOARD_GRID_TOGGLE', 'F2903_USE_ITERATION_TREE_GRID']

    it 'should include test sets in UE', ->
      @stub(Rally.domain.Subscription::, 'isUnlimitedEdition').returns true
      @createApp().then =>
        @toggleToGrid()
        expect(@app.modelNames).toContain 'Test Set'
        expect(@app.allModelNames).toContain 'Test Set'
        expect(@app.down('rallytreegrid').getStore().parentTypes).toContain 'TestSet'

    it 'should not include test sets in UE', ->
      @stub(Rally.domain.Subscription::, 'isUnlimitedEdition').returns false
      @createApp().then =>
        @toggleToGrid()
        expect(@app.modelNames).not.toContain 'Test Set'
        expect(@app.allModelNames).not.toContain 'Test Set'
        expect(@app.down('rallytreegrid').getStore().parentTypes).not.toContain 'TestSet'