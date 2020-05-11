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

      $mdThemingProvider.theme('top-pane')
      .primaryPalette('blue')
      .accentPalette('blue-grey');

      $mdThemingProvider.theme('bottom-pane')
      .primaryPalette('indigo')
      .accentPalette('blue');
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

        /*
        The default assumes all pieces are installed on the same
        host with elastic fronted by an https proxy on port 8443
        */
        var host = $location.host();
        var port = $location.port();
        $rootScope.urlscheme.https = 'https://' + host + ':' + port;
        $rootScope.urlscheme.websocket = 'wss://' + host + ':' + port;
        $rootScope.urlscheme.elastic = 'https://' + host + ':8443';

        // Adjust your URLs if you have a custom install
        // Dev uri's
        //$rootScope.urlscheme.https = 'https://' + host + ':' + port;
        //$rootScope.urlscheme.websocket = 'wss://demo.sguil.net';
        //$rootScope.urlscheme.elastic = 'https://demo.sguil.net:8443';

    }

]);
