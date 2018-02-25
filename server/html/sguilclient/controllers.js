'use strict';
 
angular.module('MainConsole', ['material.svgAssetsCache', 'luegg.directives', 'ui.grid.selection', 'ngSanitize'])
 
.controller('MainConsoleController',
    ['$scope', '$rootScope', '$q', '$filter', '$document', '$location', '$interval', '$mdDialog', '$mdBottomSheet', 'WebSocketService','uiGridConstants', 'SguilClientService',
    function ($scope, $rootScope, $q, $filter, $document, $location, $interval, $mdDialog, $mdBottomSheet, WebSocketService, uiGridConstants, SguilClientService) {

        $scope.eventinfo = {}
        $scope.eventinfo.sig = true;
        $scope.eventinfo.payload = true;
        $scope.eventinfo.msg = "";
        $scope.eventinfo.whois = "none";
        $scope.eventinfo.srcip = "";
        $scope.eventinfo.srcname = "";
        $scope.eventinfo.dstip = "";
        $scope.eventinfo.dstname = "";
        $scope.eventinfo.lookupip = "";
        $scope.sensorNames = [];
        $scope.selected = [];
        $scope.status = '  ';
        $scope.customFullscreen = false;
        $scope.tableOptions = {};
        $scope.currentTableName = "";
        $scope.rtqueue = 0;
        $scope.equeue = 0;
        $scope.eventQuery = [];
        $scope.nextQuery = 0;
        $scope.nextTranscript = 0;
        $scope.queryResults = {};

        $scope.eventWhere = 'WHERE event.timestamp > \'2017-04-26\' AND  event.src_ip = INET_ATON(\'59.45.175.86\')'

        // Keep all pending requests here until they get responses
        var callbacks = {};
        // Create a unique callback ID to map requests to responses
        var currentCallbackId = 0;

        var eventmenu = document.querySelector("#eventid-menu");
        var eventmenuState = 0;
        var prioritymenu = document.querySelector("#priority-menu");
        var prioritymenuState = 0;
        var srcipmenu = document.querySelector("#srcip-menu");
        var srcipmenuState = 0;
        var dstipmenu = document.querySelector("#dstip-menu");
        var dstipmenuState = 0;
        var contextMenuClassName = "context-menu";
        var contextMenuItemClassName = "context-menu__item";
        var contextMenuLinkClassName = "context-menu__link";
        var contextMenuActive = "context-menu--active";
        var taskItemClassName = "task";
        var taskItemInContext;
        var clickCoords;
        var clickCoordsX;
        var clickCoordsY;
        var menuWidth;
        var menuHeight;
        var menuPosition;
        var menuPositionX;
        var menuPositionY;
        var windowWidth;
        var windowHeight;
        var mainTabs = [
            {
                title: 'rtevents',
                content: '<tabulator input-id="rtevents" options="tableOptions" srciprightclick="displaySrcIPMenu(arg1, arg2, arg3)" dstiprightclick="displayDstIPMenu(arg1, arg2, arg3)" priorityrightclick="displayPriorityRightClickMenu(arg1, arg2, arg3)" eventrightclick="displayEventRightClickMenu(arg1, arg2, arg3)" rowclick="rowSelected(arg1)"></tabulator>'
            },{
                title: 'escalated',
                content: '<tabulator input-id="escalated" options="tableOptions" srciprightclick="displaySrcIPMenu(arg1, arg2, arg3)" dstiprightclick="displayDstIPMenu(arg1, arg2, arg3)" priorityrightclick="displayPriorityRightClickMenu(arg1, arg2, arg3)" eventrightclick="displayEventRightClickMenu(arg1, arg2, arg3)" rowclick="rowSelected(arg1)"></tabulator>'
            }
        ]
        $scope.mainTabs = mainTabs;
        $scope.selectedIndex = 0;
            
        // Listener for clicks outside the rcm if it is showing
        document.addEventListener( "click", function(e) {
          
            //console.log('left button');
            var button = e.which || e.button;
            if ( button === 1 ) {
                toggleEventMenuOff();
                togglePriorityMenuOff();
                toggleSrcipMenuOff();
                toggleDstipMenuOff();
            }

        });

        $scope.newTabSelected = function(tableName) {
            $scope.currentTableName = tableName;
            console.log('New Tab: ', tableName)
        }

        $scope.rowSelected = function(data) {
            console.log('Selected :' + data.id);
            $scope.selectedRow = data.id;
            $scope.eventinfo.srcip = data.srcip;
            $scope.eventinfo.dstip = data.dstip;

            if ($scope.currentTableName === 'rtevents') {
                var cmd = {UserSelectedEvent : [data.aid,$scope.userid]}
                sendRequest(cmd, "none");
            }

            // Display data for the new event
            if($scope.eventinfo.sig) {showSignatureInfo(data);};
            if($scope.eventinfo.payload) {showPayloadInfo(data);};
            displayWhoisData();
        }

        // Setup any callbacks before making the request.
        // Set the callback to "none" if no callback required
        var sendRequest = function(request, callbackID) {

          var defer = $q.defer();

          if (callbackID !== "none") {

              //console.log('Setting callback for the cmd: ' + callbackID);
              callbacks[callbackID] = {
                  time: new Date(),
                  cb:defer
              };

          }

          console.log('Sending request: ' + JSON.stringify(request) + ' ' + callbackID);
          WebSocketService.send(JSON.stringify(request));
          if (callbackID !== "none") { return defer.promise; }

        };

        // Make the function wait until the connection is made...
        function waitForSocketConnection(socket, callback){
            setTimeout(
                function () {
                    if (socket.readyState === 1) {
                        console.log("Connection is made")
                        if(callback != null){
                            callback();
                        }
                        return;

                    } else {
                        console.log("Waiting for websocket to finalize...")
                        waitForSocketConnection(socket, callback);
                    }

                }, 1000);
        };

        WebSocketService.listener(function(data) {

          var messageObj = data;
          var cmd = Object.keys(messageObj)[0];

          console.log("Listener received cmd ", messageObj);

          // If an object exists with callback_id in our callbacks object, resolve it
          if(callbacks.hasOwnProperty(cmd)) {

              console.log('Received known callback: ', callbacks[cmd]);
              $rootScope.$apply(callbacks[cmd].cb.resolve(messageObj));
              delete callbacks[cmd];

          } else {

              switch (cmd) {

              case 'InsertEvent':
                  $scope.rtqueue++;
                  InsertEvent('rtevents', messageObj.InsertEvent);
                  break;
              case 'InsertEscalatedEvent':
                  InsertEvent('escalated', messageObj.InsertEscalatedEvent);
                  $scope.equeue++;
                  break;
              case 'InsertQueryResults':
                  InsertQueryResults(messageObj.InsertQueryResults);
                  break;
              case 'IncrEvent':
                  IncrEvent(messageObj.IncrEvent);
                  break;
               case 'DeleteEventIDList':
                  DeleteEvents(messageObj.DeleteEventIDList);
                  break;
               case 'InsertSystemInfoMsg':
                  InsertSystemInfoMsg(messageObj.InsertSystemInfoMsg);
                  break;
               case 'InfoMessage':
                  InfoMessage(messageObj.InfoMessage);
                  break;
               case 'UserMessage':
                  UserMessage(messageObj.UserMessage);
                  break;
               case 'UserSelectedEvent':
                  UserSelectedEvent(messageObj.UserSelectedEvent);
                  break;
               case 'UserUnSelectedEvent':
                  UserUnSelectedEvent(messageObj.UserUnSelectedEvent);
                  break;
               case 'XscriptDebugMsg':
                  XscriptDebugMsg(messageObj.XscriptDebugMsg);
                  break;
               case 'XscriptMainMsg':
                  XscriptMainMsg(messageObj.XscriptMainMsg);
                  break;
              default:
                  console.log('Received Unknown Cmd: ', messageObj);
                  break;

              }

          }

        });

        $scope.PlaySound = function (type) {

            console.log('pew pew');
            var sound = document.getElementById(type);
            sound.play()

        };

        $scope.$watch('eventinfo.whois', function() {
            displayWhoisData();
        });

        var displayWhoisData = function () {

            var whoisElement = angular.element( document.querySelector( '#whoisLog' ) );
            whoisElement.empty();

            if($scope.eventinfo.whois === "none") {
                $scope.eventinfo.lookupip = ""
                return;
            } else if ($scope.eventinfo.whois === "srcip") {
                $scope.eventinfo.lookupip = $scope.eventinfo.srcip;
            } else {
                $scope.eventinfo.lookupip = $scope.eventinfo.dstip;
            }

            if ($scope.eventinfo.lookupip === "") { return; }

            var cmd = { "GetWhoisData" : [$scope.eventinfo.lookupip]}

            sendRequest(cmd, "InsertWhoisData").then(function(data) {

                var results = data.InsertWhoisData[0]

                whoisElement.append(atob(results));
                whoisElement.scrollTop;

            });

        }

        $scope.displayEventRightClickMenu = function(data, e, tableName) {

                e.preventDefault();
                $scope.tableOptions.selectrow(tableName, data.id);
                selectedEvent(data.id, $scope.userid);
                if($scope.eventinfo.sig) {showSignatureInfo(data);};
                if($scope.eventinfo.payload) {showPayloadInfo(data);};
                toggleEventMenuOn();
                positionMenu(e, eventmenu);

        }
        
        $scope.displaySrcIPMenu = function(data, e, tableName) {

                e.preventDefault();
                $scope.tableOptions.selectrow(tableName, data.id);
                selectedEvent(data.id, $scope.userid);
                if($scope.eventinfo.sig) {showSignatureInfo(data);};
                if($scope.eventinfo.payload) {showPayloadInfo(data);};
                toggleSrcipMenuOn();
                positionMenu(e, srcipmenu);
                $scope.eventinfo.srcip = data.srcip;
                $scope.eventinfo.dstip = data.dstip;

        }

        $scope.displayDstIPMenu = function(data, e, tableName) {

                e.preventDefault();
                $scope.tableOptions.selectrow(tableName, data.id);
                selectedEvent(data.id, $scope.userid);
                if($scope.eventinfo.sig) {showSignatureInfo(data);};
                if($scope.eventinfo.payload) {showPayloadInfo(data);};
                toggleDstipMenuOn();
                positionMenu(e, dstipmenu);
                $scope.eventinfo.srcip = data.srcip;
                $scope.eventinfo.dstip = data.dstip;

        }

        $scope.displayPriorityRightClickMenu = function(data, e, tableName) {

                e.preventDefault();
                $scope.tableOptions.selectrow(tableName, data.id);
                selectedEvent(data.id, $scope.userid);
                if($scope.eventinfo.sig) {showSignatureInfo(data);};
                if($scope.eventinfo.payload) {showPayloadInfo(data);};
                togglePriorityMenuOn();
                positionMenu(e, prioritymenu);

        }
        
        function toggleEventMenuOn() {
            if ( eventmenuState !== 1 ) {
                eventmenuState = 1;
                eventmenu.classList.add( contextMenuActive );
            }
         }
        function toggleSrcipMenuOn() {
            if ( srcipmenuState !== 1 ) {
                srcipmenuState = 1;
                srcipmenu.classList.add( contextMenuActive );
            }
         }
        function toggleDstipMenuOn() {
            if ( dstipmenuState !== 1 ) {
                dstipmenuState = 1;
                dstipmenu.classList.add( contextMenuActive );
            }
         }
        function togglePriorityMenuOn() {
            if ( prioritymenuState !== 1 ) {
                prioritymenuState = 1;
                prioritymenu.classList.add( contextMenuActive );
            }
         }
         function toggleEventMenuOff() {
             if ( eventmenuState !== 0 ) {
                 eventmenuState = 0;
                 eventmenu.classList.remove( contextMenuActive );
             }
         }
         function toggleSrcipMenuOff() {
             if ( srcipmenuState !== 0 ) {
                 srcipmenuState = 0;
                 srcipmenu.classList.remove( contextMenuActive );
             }
         }
         function toggleDstipMenuOff() {
             if ( dstipmenuState !== 0 ) {
                 dstipmenuState = 0;
                 dstipmenu.classList.remove( contextMenuActive );
             }
         }
         function togglePriorityMenuOff() {
             if ( prioritymenuState !== 0 ) {
                 prioritymenuState = 0;
                 prioritymenu.classList.remove( contextMenuActive );
             }
         }

         function positionMenu(e, menuname) {
           clickCoords = getPosition(e);
           clickCoordsX = clickCoords.x;
           clickCoordsY = clickCoords.y;

           menuWidth = eventmenu.offsetWidth + 4;
           menuHeight = eventmenu.offsetHeight + 4;
         
           windowWidth = window.innerWidth;
           windowHeight = window.innerHeight;

           if ( (windowWidth - clickCoordsX) < menuWidth ) {
             menuname.style.left = windowWidth - menuWidth + "px";
           } else {
             menuname.style.left = clickCoordsX + "px";
           }

           menuname.style.top = clickCoordsY + "px";

         }

         function getPosition(e) {
             var posx = 0;
             var posy = 0;

             if (!e) var e = window.event;

             if (e.pageX || e.pageY) {
               posx = e.pageX;
               posy = e.pageY;
             } else if (e.clientX || e.clientY) {
               posx = e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft;
               posy = e.clientY + document.body.scrollTop + document.documentElement.scrollTop;
             }

             return {
               x: posx,
               y: posy
             }
          }

        $(window).resize(function(){
            //console.log('Window resized!');
            $scope.tableOptions.redraw();
        });

        $scope.sendMsg = function() {

            var msg = $scope.eventinfo.msg
            $scope.eventinfo.msg = "";
            sendMsg(msg);

        }

        $scope.clickSignature = function() {

            var sigElement = angular.element( document.querySelector( '#eventSignature' ) );

            if ($scope.eventinfo.sig) {

                var data = $scope.tableOptions.getselecteddata($scope.currentTableName);

                if (data.length > 0) {
                    showSignatureInfo(data[0]);
                } else {
                    sigElement.empty();
                }

            } else {

                sigElement.empty();

            }
            
        };

        var showSignatureInfo = function (data) {

            var cmd = {"RuleRequest":[data.aid,data.sensor,data.gid,data.signature_id,data.rev]};

            //[list RuleRequest $event_id $sensorName $genID $sigID $sigRev]
            sendRequest(cmd, "InsertRuleData").then(function(data) {

                var sigElement = angular.element( document.querySelector( '#eventSignature' ) );
                var ruleInfo = data.InsertRuleData[0];

                console.log('Rcvd our RuleRequest callback. ' + ruleInfo);

                sigElement.empty();
                sigElement.append('<br>');
                sigElement.append(ruleInfo);
                
            });

        };

        $scope.clickPayload = function() {

            var hexElement = angular.element( document.querySelector( '#payloadHex' ) );
            var asciiElement = angular.element( document.querySelector( '#payloadAscii' ) );

            if ($scope.eventinfo.payload) {

                var data = $scope.tableOptions.getselecteddata($scope.currentTableName);

                if (data.length > 0) {
                    showPayloadInfo(data[0]);
                } else {
                    hexElement.empty();
                    asciiElement.empty();
                }

            } else {

                hexElement.empty();
                asciiElement.empty();

            }
        };

        var showPayloadInfo = function (data) {

            $scope.asciiRows = [];
            $scope.hexRows = [];

            var cmd = {"GetPayloadData":data.aid.split(".")};
            sendRequest(cmd, "InsertPayloadData").then(function(data) {

                var hexPayload = data.InsertPayloadData[0];
                var payloadLength = hexPayload.length;
                var hexElement = angular.element( document.querySelector( '#payloadHex' ) );
                var asciiElement = angular.element( document.querySelector( '#payloadAscii' ) );

                //console.log('Rcvd our Payload callback. Payload: ' + hexPayload);

                hexElement.empty();
                asciiElement.empty();
                hexElement.append('<br>');
                asciiElement.append('<br>');


                if (payloadLength < 1) {

                    // No payload
                    hexElement.append('No Payload Available<br>');
                    asciiElement.append('No Payload Available<br>');

                } else {

                    var n = 0;
                    var i = 0;
                    var tmpHex = "";
                    var hexRow = "";
                    var tmpInt = "";
                    var asciiRow = "";

                    for(i=0; i < payloadLength; i+=2) {

                        n++;
                        tmpHex = hexPayload.substr(i,2);
                        tmpInt = parseInt(tmpHex,16);

                        if ((tmpInt < 32) || (tmpInt > 126)) {
                            hexRow += tmpHex + " ";
                            asciiRow += ".";
                        } else if (tmpInt == 60) {
                            hexRow += tmpHex + " ";
                            asciiRow += "&lt;";
                        } else if (tmpInt == 62) {
                            hexRow += tmpHex + " ";
                            asciiRow += "&gt;";
                        } else {
                            hexRow += tmpHex + " ";
                            asciiRow += String.fromCharCode(parseInt(tmpHex, 16));
                        }

                        if ((n == 16) && (i < payloadLength)) {
                            hexElement.append(hexRow + '<br>');
                            asciiElement.append(asciiRow + '<br>');
                            n = 0;
                            asciiRow = "";
                            hexRow = "";
                        }

                    }

                    hexElement.append(hexRow + '<br>');
                    asciiElement.append(asciiRow + '<br>');

                };


            });

        };

        $scope.showLoginDialog = function() {

            $mdDialog.show({

                contentElement: '#sguilLogin',
                parent: angular.element(document.body),
                //targetEvent: ev,
                clickOutsideToClose: false

            });

        };

        $scope.showSensorSelectDialog = function() {

            $mdDialog.show({

                contentElement: '#sguilSensorSelect',
                parent: angular.element(document.body),
                //targetEvent: ev,
                clickOutsideToClose: false

            });

        };
 
        
        $scope.login = function () {

            $scope.dataLoading = true;

            WebSocketService.wsConnect();

            var authMsg = { "ValidateUser" : [$scope.username,$scope.password] };

            // Wait until the state of the socket is ready and send the message when it is...
            waitForSocketConnection(WebSocketService.ws, function(){

                sendRequest(authMsg, "UserID").then(function(data) {

                    $scope.userid = data.UserID[0];

                    //console.log('Rcvd our ValidateUser callback. UserID: ' + $scope.userid)
                    if ($scope.userid != "INVALID") {

                        $scope.dataLoading = false;
                        $mdDialog.hide();
                        $scope.showSensorSelectDialog();
                        $scope.sensorselect();

                    } else {

                        console.log('Error logging in: ' + $scope.userid)
                        $scope.error = "Login Failed. Please verify username/password.";
                        $scope.dataLoading = false;

                    }

                }).catch(function() {

                    console.log('Error logging in: ' + data)
                    $scope.error = "An error occurred while loging in.";
                    $scope.dataLoading = false;

                });
            });

        };

        $scope.logout = function () {

            WebSocketService.close();
            $location.path('/logout');

        }

        $scope.sensorselect = function () {
            
            var cmd = {"SendSensorList":"0"};

            sendRequest(cmd, "SensorList").then(function(data) {

                var response = data.SensorList;

                //console.log('Rcvd our SensorList callback. SensorList: ' + response)

                var n = response.length;

                // Loop through each sensor object and extract the name and users
                for (var i=0; i < n; i++) {

                    var sensorArray = response[i];
                    var sensorName = Object.keys(sensorArray)[0];
                    var userArray = sensorArray[sensorName];
                    var sensorUsers = JSON.stringify(userArray);
                    //console.log('Sensor ' + i + ': ' + sensorName);

                    var nn = userArray.length;
                    // Loop through the sensor and get the users
                    var uList = [];
                    for (var ii=0; ii < nn; ii++) {
                        var u = userArray[ii];
                        uList.push(u); 
                        //console.log('  User ' + ii + ': ' + u);
                    }
                    $scope.sensorNames.push(sensorName + ": " + uList.join(" "));

                }
            });
        }

        $scope.monitor = function () {

            // Build a list of sensor names to monitor
            var sensorArray = [];
            for (var i = 0; i < $scope.selected.length; i++) {
                var sensor = $scope.selected[i].split(":");
                sensorArray.push(sensor[0])
            }

            var sensorList = [sensorArray.join(' ')];
            var cmd = {"MonitorSensors":sensorList}
            sendRequest(cmd,"none");
            var cmd = {"SendEscalatedEvents":''}
            sendRequest(cmd,"none");
            $mdDialog.hide();

        }

        $scope.toggle = function (item, list) {
            var idx = list.indexOf(item);
            if (idx > -1) {
                list.splice(idx, 1);
            } else {
                list.push(item);
            }
        };

        $scope.exists = function (item, list) {
            return list.indexOf(item) > -1;
        };

        $scope.isIndeterminate = function() {
            return ($scope.selected.length !== 0 &&
                $scope.selected.length !== $scope.sensorNames.length);
        };

        $scope.isChecked = function() {
            return $scope.selected.length === $scope.sensorNames.length;
        };

        $scope.toggleAll = function() {
            if ($scope.selected.length === $scope.sensorNames.length) {
                $scope.selected = [];
            } else if ($scope.selected.length === 0 || $scope.selected.length > 0) {
                $scope.selected = $scope.sensorNames.slice(0);
            }
        };

        var tick = function() {
            $scope.gmttime = Date.now();
        }
        tick();
        $interval(tick, 1000);

        // Launch login dialog
        $scope.showLoginDialog();


        // Use function keys to trigger status buttons
        $(document).keydown(function(event){

            switch (event.keyCode) {
              case 112: event.preventDefault(); $scope.updateEventStatus(11); break;
              case 113: event.preventDefault(); $scope.updateEventStatus(12); break;
              case 114: event.preventDefault(); $scope.updateEventStatus(13); break;
              case 115: event.preventDefault(); $scope.updateEventStatus(14); break;
              case 116: event.preventDefault(); $scope.updateEventStatus(15); break;
              case 117: event.preventDefault(); $scope.updateEventStatus(16); break;
              case 118: event.preventDefault(); $scope.updateEventStatus(17); break;
              case 119: event.preventDefault(); $scope.updateEventStatus(1); break;
              case 120: event.preventDefault(); $scope.updateEventStatus(2); break;
            }


        });

        // Process InsertEvent Messages from websocket
        //function InsertEvent(msg) {
        function InsertEvent(tableName, msg) {
            /*
            {"timestamp":"2017-03-27T21:31:26.901711+0000",
            "flow_id":162391436034155,
            "in_iface":"eth2",
            "event_type":"alert",
            "src_ip":"192.168.8.8",
            "src_port":36462,
            "dest_ip":"139.162.227.51",
            "dest_port":6667,
            "proto":"TCP",
            "alert":{
              "action":"allowed",
              "gid":1,
              "signature_id":2002026,
              "rev":21,
              "signature":"ET CHAT IRC PRIVMSG command",
              "category":"Misc activity",
              "severity":3},
            "payload":"UElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClRPUElDICNzbm9ydC1ndWkgOklmIHlvdSBjb3VsZCBtYWtlIGNoYW5nZXMgdG8gdGhlIGxheW91dCBvZiB0aGUgU2d1aWwgY29uc29sZSwgd2hhdCB3b3VsZCB0aGV5IGJlPw0KUFJJVk1TRyAjc25vcnQtZ3VpIDpJZiB5b3UgY291bGQgbWFrZSBjaGFuZ2VzIHRvIHRoZSBsYXlvdXQgb2YgdGhlIFNndWlsIGNvbnNvbGUsIHdoYXQgd291bGQgdGhleSBiZT8NClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQUklWTVNHICNzbm9ydC1ndWkgOldvdWxkIHlvdSBsZWF2ZSB0aGUgcGFja2V0IC8gcnVsZSBkYXRhIHdpZGdldHMgYXMgaXMgb3IgbWFrZSB0aGV5IHBvcCB1cCBvbiBkZW1hbmQ\/DQpQUklWTVNHICNzbm9ydC1ndWkgOkRvZXMgYW55b25lIHVzZSB0aGUgSVAgcmVzb2x1dGlvbiAvIGV0YyB0YWJzPw0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBSSVZNU0cgI3Nub3J0LWd1aSA6T3IgaXMgdGhhdCBzdGVhbGluZyB2YWx1YWJsZSByZWFsIGVzdGF0ZT8NClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQpQSU5HIG5pdmVuLmZyZWVub2RlLm5ldA0KUElORyBuaXZlbi5mcmVlbm9kZS5uZXQNClBJTkcgbml2ZW4uZnJlZW5vZGUubmV0DQo=","stream":1,"packet":"ACSyZAAYAAfpTdbbCABFAAA0RE9AAEAGvu7AqAgIi6LjM45uGgu9vAB9Uw\/QtoAQBSy4TQAAAQEICj8\/105+RWJw",
            "packet_info":{"linktype":1}}
            */
            /*
            status[0],priority[1],category[2],sensorName[3],timestamp[4],sid[5],cid[6],signature[7],
            srcip[8],dstip[9],ipproto[10],srcport[11],dstport[12],gid[13],sig_id[14],rev[15],flowid[16],
            flowid[17],count[18]
            0,3,Misc activity,suricata-int,2017-03-27 21:31:26,11,91943,ET CHAT IRC PRIVMSG command,
            192.168.8.8,139.162.227.51,6,36462,6667,1,2002026,21,162391436034155,162391436034155,1
            */
            //console.log('Request to insert event: ' + msg.length + ' ' + msg);
            var aid = msg[5] + '.' + msg[6];
            var newData = {
                status:msg[0],
                priority:msg[1], 
                category:msg[2],
                sensor:msg[3], 
                timestamp:msg[4], 
                aid:aid, 
                id:aid, 
                msg:msg[7],
                srcip:msg[8], 
                dstip:msg[9], 
                proto:msg[10],
                sport:msg[11], 
                dport:msg[12], 
                gid:msg[13],
                signature_id:msg[14],
                rev:msg[15],
                flowid:msg[16]
                //count:msg[18]
              };
            // If count isn't included at element 18, add it
            if (!msg[18]) { 
                newData.count = 1;
            } else {
                newData.count = msg[18];
            };

              //console.log('data -> ' + JSON.stringify(newData));
              //$scope.gridOptions.data.push(newData);
              $scope.tableOptions.addrow(tableName, newData);

        }

        function InsertQueryResults(msg){

            //var tabName = 'Query' + msg[0];
            var tabName = msg[0];

            if (msg[1] !== "done") {

                var aid = msg[5] + "." + msg[6];
                var newData = {
                    status:msg[1],
                    priority:msg[2], 
                    sensor:msg[3], 
                    timestamp:msg[4], 
                    aid:aid, 
                    id:aid, 
                    msg:msg[7],
                    srcip:msg[8], 
                    dstip:msg[9], 
                    proto:msg[10],
                    sport:msg[11], 
                    dport:msg[12], 
                    gid:msg[13],
                    signature_id:msg[14],
                    rev:msg[15],
                    count:"1"

                }

                $scope.queryResults[tabName].push(newData);
                //$scope.tableOptions.addrow(tabName, newData);

            } else {

                console.log('Results -> ', $scope.queryResults[tabName])
                $scope.tableOptions.setdata(tabName, $scope.queryResults[tabName]);

            }

        }

        function UserSelectedEvent(argsArray) {

            var aid_id = argsArray[0];
            var uid = Number(argsArray[1]) + 10;

            $scope.tableOptions.updaterow('rtevents', aid_id, {priority:uid});

        }

        function IncrEvent(argsArray) {

            var aid_id = argsArray[0];
            var newcount = argsArray[1];
            var newpriority = argsArray[2];
        
            $scope.tableOptions.updaterow('rtevents', aid_id, {count:newcount});
        }

        function UserUnSelectedEvent(argsArray) {

            var aid_id = argsArray[0];
            var priority = argsArray[2];

            $scope.tableOptions.updaterow('rtevents', aid_id, {priority:priority});

        }

        function InfoMessage(data) {
            $mdDialog.show(
                $mdDialog.alert()
                  .parent(angular.element(document.querySelector('#SguilConsole')))
                  .clickOutsideToClose(true)
                  //.title('alert title')
                  .textContent(data[0])
                  .ariaLabel('Info Message')
                  .ok('Dismiss')
                  //.targetEvent(ev)
              );
        }

        function InsertSystemInfoMsg(data) {

            var logElement = angular.element( document.querySelector( '#systemLog' ) );
            var user = data[0];
            var msg = data[1];
            var now = $filter('date')(new Date(), 'yyyy-MM-dd HH:mm:ss', 'UTC/GMT');
            logElement.append('[' + now + ']<b> ' + user + ':</b> ' + msg + '<br>');

        }
  
        function UserMessage (data) {

            var chatElement = angular.element( document.querySelector( '#chatLog' ) );
            var user = data[0];
            var now = $filter('date')(new Date(), 'HH:mm:ss', 'UTC/GMT');
            chatElement.append('[' + now + '] <b>' + user + ':</b> ');
            chatElement.append(document.createTextNode(data[1]));
            chatElement.append('<br>');

        }

        function XscriptDebugMsg (data) {

            var logElement = angular.element( document.querySelector( '#systemLog' ) );
            var user = data[0];
            var msg = data[1];
            var now = $filter('date')(new Date(), 'yyyy-MM-dd HH:mm:ss', 'UTC/GMT');
            logElement.append('[' + now + ']<b> ' + user + ':</b> ' + msg + '<br>');

        }
  
        function XscriptMainMsg (data) {

            var tabName = data[0];
            var debugElement = angular.element( document.querySelector('#' + tabName) );

            switch (data[1]) {

                case 'HDR':
                    var container1 = document.createElement("span");
                    var textlabel = document.createTextNode(data[2] + ' ');
                    container1.appendChild(textlabel);
                    container1.style.fontWeight = "bold";
                    debugElement.append(container1);
                    var container2 = document.createElement("span");
                    var text = document.createTextNode(data[3]);
                    container2.appendChild(text);
                    debugElement.append(container2);
                    debugElement.append('<br>');
                    break;
                case 'SRC':
                    var container = document.createElement("span");
                    var text = document.createTextNode(data[1] + ": " + data[2]);
                    container.appendChild(text);
                    container.style.color = "red";
                    debugElement.append(container);
                    debugElement.append('<br>');
                    break;
                case 'DST':
                    var container = document.createElement("span");
                    var text = document.createTextNode(data[1] + ": " + data[2]);
                    container.appendChild(text);
                    container.style.color = "blue";
                    debugElement.append(container);
                    debugElement.append('<br>');
                    break;
                default:
                    console.log('Received Unknown Xscript Msg: ', data);
                    break;

            }

        }
  
        function DeleteEvents(aidList) {

            var a = "";
            for (a = 0; a < aidList.length; a++) {
                var aid_id = aidList[a];
                $scope.tableOptions.deleterow(aid_id);
            }

        }

        function sendMsg(msg) {

            var cmd = {UserMessage:[msg]};
            sendRequest(cmd,"none");

        }

        // Update the alert in sguild
        function phater(comment, status, id) {

            if (id !== "") {
                var cmd = {DeleteEventIDList : [status,comment,id]};
                sendRequest(cmd,"none");
            }

        }

        $scope.removeQuery= function(index){
            $scope.mainTabs.splice(index, 1);
        }

        $scope.eventSearch = function(type) {

            $scope.nextQuery++;
            var tabName = 'Query' + $scope.nextQuery; 
            var newTab = new Object();
            newTab.title = tabName;
            newTab.close = true;
            newTab.content= '<tabulator input-id="' + tabName + '"" options="tableOptions" priorityrightclick="displayPriorityRightClickMenu(arg1, arg2, arg3)" eventrightclick="displayEventRightClickMenu(arg1, arg2, arg3)" rowclick="rowSelected(arg1)"></tabulator>'
            $scope.mainTabs.push(newTab);

            var query = '(SELECT event.status, event.priority, sensor.hostname,  event.timestamp as datetime, event.sid, event.cid, event.signature, INET_NTOA(event.src_ip), INET_NTOA(event.dst_ip), event.ip_proto, event.src_port, event.dst_port, event.signature_gen, event.signature_id,  event.signature_rev FROM event IGNORE INDEX (event_p_key, sid_time) INNER JOIN sensor ON event.sid=sensor.sid WHERE event.timestamp > "2017-04-12" AND event.src_ip = INET_ATON("59.45.175.62") ) UNION ( SELECT event.status, event.priority, sensor.hostname,  event.timestamp as datetime, event.sid, event.cid, event.signature, INET_NTOA(event.src_ip), INET_NTOA(event.dst_ip), event.ip_proto, event.src_port, event.dst_port, event.signature_gen, event.signature_id,  event.signature_rev FROM event IGNORE INDEX (event_p_key, sid_time) INNER JOIN sensor ON event.sid=sensor.sid WHERE event.timestamp > "2017-04-12" AND  event.dst_ip = INET_ATON("59.45.175.62") ) ORDER BY datetime, src_port ASC LIMIT 1000'
            var cmd = {QueryDB:[$scope.nextQuery,query]};
            //sendRequest(cmd,"none");


        }

        // sensor sensorID winID timestamp srcIP srcPort dstIP dstPort force
        $scope.transcriptRequest = function(event) {

            var tableName = $scope.currentTableName
            var data = $scope.tableOptions.getselecteddata(tableName)[0];   
            
            console.log('Transript requested for: ' + data.sensor + ' ' + data.id);
            var splitAid = data.id.split(".");

            $scope.nextTranscript++;
            var tabName = "T" + data.id.replace(".", "_");
            //var tabName = 'Xscript' + $scope.nextTranscript; 
            var newTab = new Object();
            newTab.title = tabName;
            newTab.close = true;
            newTab.content= '<md-content class="md-padding" style="min-height:224px;max-height:450px;height:450px"><div id="' + tabName + '" style="font-size:12px"></div></md-content>'
            $scope.mainTabs.push(newTab);

            console.log('Request -> ' + data.sensor + ' ' + splitAid[0] + ' ' + tabName + ' ' + data.timestamp + ' ' + data.srcip + ' ' + data.sport + ' ' + data.dstip + ' ' + data.dport + ' 1');
            var cmd = {XscriptRequest : [data.sensor,splitAid[0],tabName,data.timestamp,data.srcip,data.sport,data.dstip,data.dport,0]};
            sendRequest(cmd,"none");

        }

        $scope.showEventSearchDialog = function(event, type) {

            var data = $scope.tableOptions.getselecteddata($scope.currentTableName)[0];
            var date = $filter('date')(new Date(data.timestamp),'yyyy-MM-dd');

            console.log('Event Search for: ' + type);
            
            $scope.eventWhere = 'WHERE event.timestamp > \'' + date + '\'';

            if (type === "srcip") {
                $scope.eventWhere += ' AND event.src_ip = INET_ATON(\''+ data.srcip + '\')';
            } else if (type === "dstip") {
                $scope.eventWhere += ' AND event.dst_ip = INET_ATON(\''+ data.dstip + '\')';
            } else {
                var lookupip = $scope.eventinfo.dstip;
            }

            $mdDialog.show({

                //contentElement: '#alertSearch',
                controller: DialogController,
                templateUrl: '/sguilclient/views/alertsearch.tmpl.html',
                parent: angular.element(document.body),
                targetEvent: event,
                scope: $scope,
                preserveScope: true,
                clickOutsideToClose: true

            })
                .then(function() {

                    //console.log('Query: ' + $scope.eventWhere );
                    $scope.nextQuery++;
                    var tabName = 'Query' + $scope.nextQuery; 
                    var newTab = new Object();
                    newTab.title = tabName;
                    newTab.close = true;
                    newTab.content= '<tabulator input-id="' + tabName + '"" options="tableOptions" priorityrightclick="displayPriorityRightClickMenu(arg1, arg2, arg3)" eventrightclick="displayEventRightClickMenu(arg1, arg2, arg3)" rowclick="rowSelected(arg1)"></tabulator>'
                    $scope.mainTabs.push(newTab);

                    var query = '(SELECT \
                                event.status, \
                                event.priority, \
                                sensor.hostname,  \
                                event.timestamp as datetime, \
                                event.sid, \
                                event.cid, \
                                event.signature, \
                                INET_NTOA(event.src_ip), \
                                INET_NTOA(event.dst_ip), \
                                event.ip_proto, \
                                event.src_port, \
                                event.dst_port, \
                                event.signature_gen, \
                                event.signature_id,  \
                                event.signature_rev \
                                FROM event IGNORE INDEX (event_p_key, sid_time) \
                                INNER JOIN sensor ON event.sid=sensor.sid ' +
                                $scope.eventWhere +
                                ') ORDER BY datetime, src_port ASC LIMIT 1000'

                    //var query = '(SELECT event.status, event.priority, sensor.hostname,  event.timestamp as datetime, event.sid, event.cid, event.signature, INET_NTOA(event.src_ip), INET_NTOA(event.dst_ip), event.ip_proto, event.src_port, event.dst_port, event.signature_gen, event.signature_id,  event.signature_rev FROM event IGNORE INDEX (event_p_key, sid_time) INNER JOIN sensor ON event.sid=sensor.sid WHERE event.timestamp > "2017-04-12" AND event.src_ip = INET_ATON("59.45.175.62") ) UNION ( SELECT event.status, event.priority, sensor.hostname,  event.timestamp as datetime, event.sid, event.cid, event.signature, INET_NTOA(event.src_ip), INET_NTOA(event.dst_ip), event.ip_proto, event.src_port, event.dst_port, event.signature_gen, event.signature_id,  event.signature_rev FROM event IGNORE INDEX (event_p_key, sid_time) INNER JOIN sensor ON event.sid=sensor.sid WHERE event.timestamp > "2017-04-12" AND  event.dst_ip = INET_ATON("59.45.175.62") ) ORDER BY datetime, src_port ASC LIMIT 1000'
                    var cmd = {QueryDB:[tabName,query]};
                    $scope.queryResults[tabName] = [];
                    sendRequest(cmd,"none");

                }, function() {
                    console.log('You cancelled the dialog.');
                });

            /*
            2017-04-20 02:40:54 pid(14755)  Client Command Received: QueryDB .eventPane.pane0.childsite.eventTabs.canvas.notebook.cs.page3.cs.query_1.tablelist {( SELECT event.status, event.priority, sensor.hostname,  event.timestamp as datetime, event.sid, event.cid, event.signature, INET_NTOA(event.src_ip), INET_NTOA(event.dst_ip), event.ip_proto, event.src_port, event.dst_port, event.signature_gen, event.signature_id,  event.signature_rev FROM event IGNORE INDEX (event_p_key, sid_time) INNER JOIN sensor ON event.sid=sensor.sid WHERE event.timestamp > '2017-04-12' AND  event.src_ip = INET_ATON('59.45.175.62') ) UNION ( SELECT event.status, event.priority, sensor.hostname,  event.timestamp as datetime, event.sid, event.cid, event.signature, INET_NTOA(event.src_ip), INET_NTOA(event.dst_ip), event.ip_proto, event.src_port, event.dst_port, event.signature_gen, event.signature_id,  event.signature_rev FROM event IGNORE INDEX (event_p_key, sid_time) INNER JOIN sensor ON event.sid=sensor.sid WHERE event.timestamp > '2017-04-12' AND  event.dst_ip = INET_ATON('59.45.175.62') ) ORDER BY datetime, src_port ASC LIMIT 1000}
            */

        }

        function DialogController($scope, $mdDialog) {

            $scope.hide = function() {
              $mdDialog.hide();
            };

            $scope.cancel = function() {
              $mdDialog.cancel();
            };

            $scope.answer = function(answer) {
              $mdDialog.hide(answer);
            };
        }

        $scope.updateEventStatus= function(status) {

            //$scope.PlaySound('pewpew');

            if ($scope.currentTableName !== "") {
                // Can select an alert per tab, make sure we have the right one.
                //var id = $scope.selectedRow;
                var tableName = $scope.currentTableName
                var data = $scope.tableOptions.getselecteddata(tableName)[0];
                var nextID = nextRowID(data.id);
                $scope.tableOptions.selectrow(tableName, nextID);
                $scope.selectedRow = nextID;
                $scope.tableOptions.deleterow(data.id);
                phater('none', status, data.id);
                selectedEvent(nextID, $scope.userid);
                $scope.clickSignature();
                $scope.clickPayload();
            }
        }

        function selectedEvent(id, userid) {

            if ($scope.currentTableName === 'rtevents') {
                //UserSelectedEvent $eventID $USERID
                var cmd = {UserSelectedEvent : [id,userid]}
                sendRequest(cmd, "none");
            }

        }

        function nextRowID(selectedID) {

            var nextID = "";
            var data = $scope.tableOptions.getdata($scope.currentTableName);
        
            // Check to see if there is another row to select 
            if (data.length <= 1) { return }

            var i = 0;
            for (i = 0; i < data.length; i++) {
        
                if (data[i].aid == selectedID) { 
        
                    var j = i + 1;
                    nextID = data[j].aid;
            
                }

            }

            return nextID;
        }

}]);