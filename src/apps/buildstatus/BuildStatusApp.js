(function() {
    var Ext = window.Ext4 || window.Ext;

    Ext.define('Rally.apps.buildstatus.BuildStatusApp', {
        extend: 'Rally.app.App',
        alias: 'widget.buildstatusapp',

        appName: 'Build Status',

        requires: [
            'Rally.apps.buildstatus.BuildStatusViewController'
        ],

        controller: 'Rally.apps.buildstatus.BuildStatusViewController',

        layout: 'auto',
        cls: 'build-status-app',

        launch: function() {

        }
    });
})();
