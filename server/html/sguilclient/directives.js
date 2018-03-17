angular.module('tabulator', [])

    .directive('tabulator', function () {

        //var uniqueId = 1;

        return {
            restrict: 'E',
            replace: true,
            scope: { 
                rowclick: '&',
                eventrightclick: '&',
                priorityrightclick: '&',
                srciprightclick: '&',
                dstiprightclick: '&',
                signaturerightclick: '&',
                options: '=' ,
                inputId: '@',
            },
            template: '<div id="{{inputId}}"/>',
            link: function (scope, el, attribs) {

                //scope.uniqueId = 'eventtable' + uniqueId++;
                //scope.inputId =  inputId;
                console.log('input-id: ' + scope.inputId);

                el.tabulator({
                    height:"450", // set height of table (optional)
                    //fitColumns:true, //fit columns to width of table (optional)
                    layout:"fitColumns",
                    selectable: 1,
                    //pagination:"local",
                    //progressiveRender:true,
                    //progressiveRenderSize:50, 
                    columns:[ //Define Table Columns
                        //{formatter:transcriptIcon, width:40, align:"center", onContext:function(e, cell, val, data){ transcriptMenu(e, cell, val, data)}},
                        {title:"", width:10,field:"priority", align:"center", sorter:"string", sortable:true, editable:false, formatter:function(cell, formatterParams){
                          var r = "";
                          var p = "";
                          var color = 'red';
                          var value = cell.getValue();
                          var data = cell.getData();

                          switch (data.status) {
                              case '0': 
                                  p = 'RT'; 
                                  switch (value) {
                                      case '1': color = 'red'; break;
                                      case '2': color = 'orange'; break;
                                      case '3': color = 'orange'; break;
                                      case '4': color = 'yellow'; break;
                                      case '5': color = 'yellow'; break;
                                      default: color = 'white'; p = value - 10; break;
                                  };
                                  break;
                              case '1': p = 'NA'; color = 'lightblue'; break;
                              case '2': p = 'ES'; color = 'pink'; break;
                              case '11': p = 'C1'; color = '#cc0000'; break;
                              case '12': p = 'C2'; color = '#ff6600'; break;
                              case '13': p = 'C3'; color = '#ff9900'; break;
                              case '14': p = 'C4'; color = '#cc9900'; break;
                              case '15': p = 'C5'; color = '#9999cc'; break;
                              case '16': p = 'C6'; color = '#ffcc00'; break;
                              case '17': p = 'C7'; color = '#cc66ff'; break;
                              default: p = 'UN'; color= 'tan'; break;
                          };

                          r = '<div style="background:' + color + ';width:100%">' + p + '</div>'
                          return r;

                        },
                        cellContext:function(e, cell){ scope.priorityrightclick({arg1: cell.getData(), arg2: e, arg3: scope.inputId});}},
                        {title:"#", width:20, field:"count", align:"center", sorter:"number", sortable:true, editable:false},
                        {title:"Sensor", width:100, field:"sensor", align:"left", sorter:"string", sortable:true, editable:false},
                        {title:"Event ID", width:75, field:"aid", align:"left", sorter:"number", sortable:true, editable:false,
                            cellContext:function(e, cell){ scope.eventrightclick({arg1: cell.getData(), arg2: e, arg3: scope.inputId});}
                        },
                        {title:"Timestamp", width:130, field:"timestamp", align:"center", sorter:"date", sortable:true, editable:false},
                        {title:"SourceIP", width:100, field:"srcip", align:"left", sorter:"string", sortable:true, editable:false,
                            cellContext:function(e, cell){ scope.srciprightclick({arg1: cell.getData(), arg2: e, arg3: scope.inputId});}
                        },
                        {title:"SPt", width:50, field:"sport", align:"right", sorter:"number", sortable:true, editable:false},
                        {title:"DestIP", width:100, field:"dstip", align:"left", sorter:"string", sortable:true, editable:false,
                            cellContext:function(e, cell){ scope.dstiprightclick({arg1: cell.getData(), arg2: e, arg3: scope.inputId});}
                        },
                        {title:"DPt", width:50, field:"dport", align:"right", sorter:"number", sortable:true, editable:false},
                        {title:"P", width:20, field:"proto", align:"right", sorter:"number", sortable:true, editable:false},
                        {title:"Message", field:"msg", align:"left", sorter:"string", sortable:true, editable:false,
                            cellContext:function(e, cell){ scope.signaturerightclick({arg1: cell.getData(), arg2: e, arg3: scope.inputId});}
                        },
                        {title:"Status", field:"status", visible:false},
                        {title:"Category", field:"category", visible:false},
                        {title:"gid", field:"gid", visible:false},
                        {title:"signature_id", field:"signature_id", visible:false},
                        {title:"rev", field:"rev", visible:false},
                        {title:"flowid", field:"flowid", visible:false}
                    ],                

                    rowClick:function(e, row){

                        scope.rowclick({arg1: row.getData()});

                    },

                });
                
                angular.extend(scope.options, {
                    selectrow: function(tname, data){
                        var myElement = angular.element( document.querySelector( '#' + tname ) );
                        myElement.tabulator("selectRow", data);
                    },
                    redraw: function(data){
                        el.tabulator("redraw"); 
                    },
                    getselecteddata: function(tname){
                        var myElement = angular.element( document.querySelector( '#' + tname ) );
                        var data = myElement.tabulator("getSelectedData"); 
                        return data;
                    },
                    getdata: function(tname){
                        var data = "";
                        var myElement = angular.element( document.querySelector('#' + tname) );
                        data = myElement.tabulator("getData"); 
                        console.log('data: ', data)
                        return data;
                    },
                    addrow: function(tname, data){
                        var myElement = angular.element( document.querySelector( '#' + tname ) );
                        myElement.tabulator("addRow", data, false);
                    },
                    deleterow: function(data){
                        var myTables = ['rtevents', 'escalated'];
                        for (var i in myTables) {
                            var myElement = angular.element( document.querySelector( '#' + myTables[i] ) );
                            myElement.tabulator("deleteRow", data); 
                        }
                    },
                    updaterow: function(tname, id, data){
                        var myElement = angular.element( document.querySelector( '#' + tname ) );
                        myElement.tabulator("updateRow", id, data); 
                    },
                    setdata: function(tname, data){
                        var myElement = angular.element( document.querySelector( '#' + tname ) );
                        myElement.tabulator("setData", data); 
                    }
                });
            }
        };
    });

angular.module('compile', [])
  .directive('compile', ['$compile', function ($compile) {
      return function(scope, element, attrs) {
          var ensureCompileRunsOnce = scope.$watch(
            function(scope) {
               // watch the 'compile' expression for changes
              return scope.$eval(attrs.compile);
            },
            function(value) {
              // when the 'compile' expression changes
              // assign it into the current DOM
              element.html(value);

              // compile the new DOM and link it to the current
              // scope.
              // NOTE: we only compile .childNodes so that
              // we don't get into infinite loop compiling ourselves
              $compile(element.contents())(scope);
                
              // Use Angular's un-watch feature to ensure compilation only happens once.
              ensureCompileRunsOnce();
            }
        );
    };
}]);