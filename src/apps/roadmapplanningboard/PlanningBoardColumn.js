(function () {
    var Ext = window.Ext4 || window.Ext;

    Ext.define('Rally.apps.roadmapplanningboard.PlanningBoardColumn', {
        extend: 'Rally.ui.cardboard.Column',
        alias: 'widget.planningboardcolumn',

        mixins: {
            maskable: 'Rally.ui.mask.Maskable'
        },
        requires: [
            'Rally.apps.roadmapplanningboard.plugin.OrcaColumnDropController',
            'Rally.ui.filter.view.FilterButton',
            'Rally.ui.filter.view.CustomQueryFilter',
            'Rally.ui.filter.view.ParentFilter'
        ],

        parentFilter: null,
        queryFilter: null,

        config: {
            filterable: false,
            baseQueryFilter: null,
            /**
             * @cfg {Object} Object containing Names and TypePaths of the lowest level portfolio item (eg: 'Feature') and optionally its parent (eg: 'Initiative')
             */
            typeNames: {},
            storeConfig: {
                fetch: ['Value', 'FormattedID', 'Owner', 'Name', 'PreliminaryEstimate', 'DisplayColor']
            },
            dropControllerConfig: {
                ptype: 'orcacolumndropcontroller'
            },
            cardConfig: {
                showIconsAndHighlightBorder: true,
                showPlusIcon: false,
                showColorIcon: true,
                showGearIcon: true,
                showReadyIcon: false,
                showBlockedIcon: false,
                showEditMenuItem: true,
                showCopyMenuItem: false,
                showSplitMenuItem: false,
                showDeleteMenuItem: true,
                showAddChildMenuItem: false,
                showRankMenuItems: false
            },

            /**
             * @cfg {Number} Controls how many cards will be displayed in a column. Overrides default config in Column.js.
             */
            cardLimit: 25
        },

        constructor: function (config) {
            this.mergeConfig(config);
            this.context = this.context || Rally.environment.getContext();
            if (!this.config.context) {
                this.config.context = this.context;
            }
            this.config.storeConfig.autoLoad = !this.filterable;
            if (this.config.baseFilter) {
                this.config.baseFilter = this._createBaseFilter(this.config.baseFilter);
            }
            this.callParent([this.config]);
        },

        _createBaseFilter: function (bf) {
            var baseFilter;
            if (Ext.isArray(bf)) {
                baseFilter = _.reduce(bf, function (result, extFilter) {
                    var filter = new Rally.data.QueryFilter.fromExtFilter(extFilter);
                    return result ? result.and(filter) : filter;
                }, undefined);
            } else {
                baseFilter = new Rally.data.QueryFilter(bf);
            }
            return baseFilter;
        },

        initComponent: function () {
            if (!this.typeNames.child || !this.typeNames.child.name) {
                throw 'typeNames must have a child property with a name';
            }

            if (this.filterable) {
                this.filterButton = this._createFilterButton();
            }

            this.callParent(arguments);

            return this.on('beforerender', function () {
                var cls = 'planning-column';
                this.getContentCell().addCls(cls);
                return this.getColumnHeaderCell().addCls(cls);
            }, this, {
                single: true
            });
        },

        _createFilterButton: function () {
            return Ext.create('Rally.ui.filter.view.FilterButton', {
                cls: 'medium columnfilter',
                stateful: true,
                stateId: this.context.getScopedStateId('filter.' + this.getColumnIdentifier() + '.' + this.context.getWorkspace()._refObjectUUID),
                items: this._getFilterItems(),
                listeners: {
                    filter: {
                        fn: this._initialFilter,
                        single: true,
                        scope: this
                    }
                }
            });
        },

        _getFilterItems: function () {
            var filterItems = [];

            if (this.typeNames.parent) {
                filterItems.push({
                    xtype: 'rallyparentfilter',
                    modelType: this.typeNames.parent.typePath,
                    modelName: this.typeNames.parent.name,
                    storeConfig: {
                        context: {
                            project: null
                        }
                    }
                });
            }

            filterItems.push({
                xtype: 'rallycustomqueryfilter',
                filterHelpId: 194
            });

            return filterItems;
        },

        isMatchingRecord: function () {
            return true;
        },

        _getProgressBarHtml: function () {
            return '<div></div>';
        },

        findCardInfo: function (searchCriteria, includeHiddenCards) {
            var card, index, _i, _len, _ref;

            searchCriteria = searchCriteria.get && searchCriteria.getId() ? searchCriteria.getId() : searchCriteria;
            _ref = this.getCards(includeHiddenCards);
            for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
                card = _ref[index];
                if (card.getRecord().getId() === searchCriteria || card.getEl() === searchCriteria || card.getEl() === Ext.get(searchCriteria)) {
                    return {
                        record: card.getRecord(),
                        index: index,
                        card: card
                    };
                }
            }
            return null;
        },

        destroy: function () {
            var plugin, _i, _len, _ref;

            _ref = this.plugins;
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                plugin = _ref[_i];
                if (plugin !== null) {
                    plugin.destroy();
                }
            }
            return this.callParent(arguments);
        },

        drawHeader: function () {
            this.callParent(arguments);

            if (this.filterable) {
                this.getHeaderTitle().insert(0, this.filterButton);
            }
        },

        getColumnIdentifier: function () {
            Ext.Error.raise('Need to override this to ensure unique identifier for persistence');
        },

        getStoreFilter: function (model) {
            var storeFilter = this.baseFilter;

            if (this.filterable && this.filters) {
                storeFilter = _.reduce(this.filters, function (result, filter) {
                    return result ? result.and(filter) : filter;
                }, storeFilter);
            }

            return storeFilter;
        },

        refreshRecord: function (record, callback) {
            this.store.setFilter(this.getStoreFilter());
            return this.callParent(arguments);
        },

        _initialFilter: function (component, filters) {
            this.filterButton.on('filter', this._onFilter, this);
            this._applyFilters(filters);
            this.config.storeConfig.autoLoad = true;
            this.loadStore();
        },

        _onFilter: function (component, filters) {
            this._applyFilters(filters);
            this.refresh(this.config);
        },

        _applyFilters: function (filters) {
            this.filters = filters;

            if (Ext.isEmpty(this.filters)) {
                this.filterButton.removeCls('primary');
                this.filterButton.addCls('secondary');
            } else {
                this.filterButton.removeCls('secondary');
                this.filterButton.addCls('primary');
            }
        }
    });
})();
