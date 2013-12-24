(function() {
	var Ext = window.Ext4 || window.Ext;

	Ext.define('Rally.apps.buildstatus.BuildStatusViewController', {
		extend: 'Rally.ui.ViewController',

		requires: [

        ],

        mixins: {
            messageable: 'Rally.Messageable'
        },

		observe: {
            view: {

            }
        },

		init: function() {
			this.callParent(arguments);
		}
	});

})();