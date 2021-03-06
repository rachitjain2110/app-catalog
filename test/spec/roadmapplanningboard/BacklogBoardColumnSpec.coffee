Ext = window.Ext4 || window.Ext

Ext.require [
  'Rally.apps.roadmapplanningboard.BacklogBoardColumn'
  'Rally.apps.roadmapplanningboard.AppModelFactory'
  'Rally.test.apps.roadmapplanningboard.helper.TestDependencyHelper'
]

describe 'Rally.apps.roadmapplanningboard.BacklogBoardColumn', ->
  beforeEach ->
    Rally.test.apps.roadmapplanningboard.helper.TestDependencyHelper.loadDependencies()

    store = Deft.Injector.resolve('featureStore')
    _.each(store.data.getRange(), (record) ->
      record.set('ActualEndDate', null)
    )

    @target = 'testDiv'
    @backlogColumn = Ext.create 'Rally.apps.roadmapplanningboard.BacklogBoardColumn',
      renderTo: @target
      contentCell: @target
      headerCell: @target
      store: store
      planStore: Deft.Injector.resolve('planStore')
      lowestPIType: 'PortfolioItem/Feature'
      roadmap: Deft.Injector.resolve('roadmapStore').getById('roadmap-id-1')
      typeNames:
        child:
          name: 'Feature'

    return @backlogColumn

  afterEach ->
    Deft.Injector.reset()
    @backlogColumn?.destroy()

  it 'has a backlog filter', ->
    expect(@backlogColumn.getCards().length).toBe(5)

  it 'will filter by roadmap in addition to feature and plans', ->
    planStore = Ext.create 'Rally.data.Store',
      model: Rally.apps.roadmapplanningboard.AppModelFactory.getPlanModel()
      proxy:
        type: 'memory'
      data: []

    store = Rally.test.apps.roadmapplanningboard.mocks.StoreFixtureFactory.getFeatureStoreFixture()
    _.each(store.data.getRange(), (record) ->
      record.set('ActualEndDate', null)
    )

    column = Ext.create 'Rally.apps.roadmapplanningboard.BacklogBoardColumn',
      renderTo: @target
      contentCell: @target
      headerCell: @target
      store: store
      planStore: planStore
      lowestPIType: 'feature'
      typeNames:
        child:
          name: 'Feature'

    expect(column.getCards().length).toBe(10)

    column.destroy()

  it 'should have a null filter for actual end date', ->
    filter = @backlogColumn.getStoreFilter()
    expect(filter.operator).toBe '='
    expect(filter.property).toBe 'ActualEndDate'
    expect(filter.value).toBe 'null'

