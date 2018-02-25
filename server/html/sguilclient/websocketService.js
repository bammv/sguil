'use strict';
 
angular.module('MainConsole')
 
.factory('WebSocketService',
    ['$rootScope', '$q', '$filter', 
    function ($rootScope, $q, $filter) {

        var service = {};

        
        service.wsConnect = function() {

            // Cheat to get just the hostname
            var parser = document.createElement('a');
            parser.href = $rootScope.servername;
            $rootScope.cleanName = parser.hostname;

            var ws = new WebSocket($rootScope.servername);
    
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
