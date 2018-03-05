'use strict';

// declare modules
angular.module('MainConsole', []);

angular.module('SguilClient', [
    'MainConsole',
    'ngRoute',
    'ngMaterial',
    'ngAria',
    'tabulator',
    'compile',
    'ui.grid'
])
 
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

        // Update your server name and port here
        $rootScope.servername = 'wss://lazyvranch.sguil.net:4444/';
        $rootScope.connected = 0;
        $rootScope.loggedin = 0;

    }

]);