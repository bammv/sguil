'use strict';
 
angular.module('MainConsole')
 
.factory('WebSocketService',
    ['$rootScope', '$q', '$filter', '$location', 
    function ($rootScope, $q, $filter, $location) {

        var service = {};

        
        service.wsConnect = function() {

            // Websocket is at wss://hostname:port/ws
            var host = $location.host();
            var port = $location.port();
            var wsUrl = $rootScope.urlscheme.websocket + '/ws';

            var ws = new WebSocket(wsUrl);
    
            ws.onopen = function(){  
                $rootScope.connected = 1;
                console.log("Socket has been opened!");  
            };

            ws.onerror = function(){  
                $rootScope.connected = 0;
                console.log("Socket received an error!");  
            };

            ws.onclose = function(){
                $rootScope.connected = 0;
                console.log("Socket has been closed!");  
            }

            ws.onmessage = function(message) {
                //listener(JSON.parse(message.data));
                service.callback(JSON.parse(message.data));
            };

            service.ws = ws;

            console.log('WebSocket Initialized');

        };
    
        service.listener = function(callback) {
            service.callback = callback;
        };

        service.send = function(message) {
            service.ws.send(message);
        };

        service.close = function(){  

            service.ws.close();
            $rootScope.connected = 0;
            console.log("Socket has been closed!");  

        };
    
        return service;

    }]);
