'use strict';

// declare modules
angular.module('MainConsole', []);

angular.module('SguilClient', [
    'MainConsole',
    'ngRoute',
    'ngMaterial',
    'ngAria',
    'tabulatorModule',
    'flowTabulatorModule',
    'httpTabulatorModule',
    'compile',
    'ui.grid'
])
 
.config(function($mdThemingProvider) {
    $mdThemingProvider.theme('blue-grey', 'default')
      .primaryPalette('blue')
  })

.config(['$routeProvider', function ($routeProvider) {

    $routeProvider

        .when('/logout', {
            //controller: 'LogoutController',
            templateUrl: 'sguilclient/views/logout.html',
            hideMenus: true
        })
 
        .when('/sguilclient', {
            controller: 'MainConsoleController',
            templateUrl: 'sguilclient/views/sguilclient.html'
        })

        .otherwise({ redirectTo: '/sguilclient' });
}])
 
.run(['$rootScope', '$location',

    function ($rootScope, $location) {

        $rootScope.urlscheme = {};
        $rootScope.connected = 0;
        $rootScope.loggedin = 0;
        
        // Adjust your URLs if you have a custom install
        var host = $location.host();
        var port = $location.port();
        $rootScope.urlscheme.https = 'https://' + host + ':' + port;
        $rootScope.urlscheme.websocket = 'wss://' + host + ':' + port;
        $rootScope.urlscheme.elastic = 'https://' + host + ':8443';

        //$rootScope.urlscheme.https = 'https://' + host + ':' + port;
        //$rootScope.urlscheme.websocket = 'wss://192.168.8.250';
        //$rootScope.urlscheme.elastic = 'http://192.168.8.250:9200';

    }

]);
