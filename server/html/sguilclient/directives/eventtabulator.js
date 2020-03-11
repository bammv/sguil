angular.module('tabulatorModule', [])

.directive('eventtabulator', function () {

    return {
        restrict: 'E',
        replace: true,
        scope: { 
            rowclick: '&',
            eventrightclick: '&',
            countrightclick: '&',
            priorityrightclick: '&',
            iprightclick: '&',
            signaturerightclick: '&',
            eventoptions: '=' ,
            inputId: '@',
        },
        template: '<div id="{{inputId}}"/>',
        link: function (scope, el, attribs) {

            el.tabulator({
                height:"100%", // set height of table (optional)
                layout:"fitColumns",
                layoutColumnsOnNewData:true,
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
                    {title:"#", width:20, field:"count", align:"center", sorter:"number", sortable:true, editable:false,
                        cellContext:function(e, cell){ scope.countrightclick({arg1: cell.getData(), arg2: e, arg3: scope.inputId});}
                    },
                    {title:"Sensor", width:100, field:"sensor", align:"left", sorter:"string", sortable:true, editable:false},
                    {title:"Event ID", width:75, field:"aid", align:"left", sorter:"number", sortable:true, editable:false,
                        cellContext:function(e, cell){ scope.eventrightclick({arg1: cell.getData(), arg2: e, arg3: scope.inputId});}
                    },
                    {title:"Timestamp", width:130, field:"timestamp", align:"center", editable:false, sorter:"datetime", sortable:true, sorterParams:{format:"YYYY-MM-DD hh:mm:ss", alignEmptyValues:"top"}},
                    {title:"SourceIP", width:100, field:"src_ip", align:"left", sorter:"string", sortable:true, editable:false,
                        cellContext:function(e, cell){ scope.iprightclick({arg1: cell.getData(), arg2: e, arg3: cell.getField(), arg4: scope.inputId});}
                    },
                    {title:"SPt", width:50, field:"src_port", align:"right", sorter:"number", sortable:true, editable:false},
                    {title:"DestIP", width:100, field:"dest_ip", align:"left", sorter:"string", sortable:true, editable:false,
                        cellContext:function(e, cell){ scope.iprightclick({arg1: cell.getData(), arg2: e, arg3: cell.getField(), arg4: scope.inputId});}
                    },
                    {title:"DPt", width:50, field:"dest_port", align:"right", sorter:"number", sortable:true, editable:false},
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
                    scope.rowclick({arg1: row.getData(), arg2: row.getPosition(true)});
                },

            });
                
            angular.extend(scope.eventoptions, {
                selectrow: function(tname, data){
                    //console.log('Selecting: ' + data);
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
                getrow: function(tname, index){
                    var myElement = angular.element( document.querySelector('#' + tname) );
                    var data = myElement.tabulator("getRow", index); 
                    return data;
                },
                getdata: function(tname){
                    var data = "";
                    var myElement = angular.element( document.querySelector('#' + tname) );
                    data = myElement.tabulator("getData"); 
                    return data;
                },
                getrowposition: function(tname, index){
                    var data = "";
                    var myElement = angular.element( document.querySelector('#' + tname) );
                    var position = myElement.tabulator("getRowPosition", index, true); 
                    return position;
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
                rowreformat: function(tname, id){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var row = myElement.tabulator("getRow", id);
                    row.reformat();
                },
                setdata: function(tname, data){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    myElement.tabulator("setData", data); 
                },
                setsort: function(tname, column, dir){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    myElement.tabulator("setSort", column, dir); 
                },
                download: function(tname, filename){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("download", "csv", filename);
                    return data;
                }
            });
        }
    };
});