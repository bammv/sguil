angular.module('flowTabulatorModule', [])
 .directive('flowtabulator', ['$filter', function ($filter) {

    return {
        restrict: 'E',
        replace: true,
        scope: { 
            flowclick: '&',
            eventrightclick: '&',
            iprightclick: '&',
            flowoptions: '=' ,
            inputId: '@'
        },
        template: '<div id="{{inputId}}"/>',
        link: function (scope, el, attribs) {

            el.tabulator({
                height:"100%", // set height of table (optional)
                layout:"fitDataFill",
                layoutColumnsOnNewData:true,
                selectable: 1,
                columns:[ //Define Table Columns
                    {title:"Host", field:"host", align:"left", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"Flow ID", field:"flow_id", align:"left", sorter:"number", sortable:true, editable:false, visible:true,
                        cellContext:function(e, cell){ scope.eventrightclick({arg1: cell.getData(), arg2: e, arg3: scope.inputId});}
                    },
                    {title:"State", field:"flow.state", align:"left", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"Alerted", field:"flow.alerted", align:"left", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"Flow Start", field:"flow.start", align:"center", sorter:"date", sortable:true, editable:false, visible:true, 
                        mutator:function(value, data, type, mutatorParams, cell){
                            var timestamp = $filter('date')(new Date(value), 'yyyy-MM-dd HH:mm:ss', 'UTC/GMT');
                            return timestamp;
                        }
                    },
                    {title:"Flow End", field:"flow.end", align:"center", sorter:"date", sortable:true, editable:false, visible:true, 
                        mutator:function(value, data, type, mutatorParams, cell){
                            var timestamp = $filter('date')(new Date(value), 'yyyy-MM-dd HH:mm:ss', 'UTC/GMT');
                            return timestamp;
                        }
                    },
                    {title:"SourceIP", field:"src_ip", align:"left", sorter:"string", sortable:true, editable:false, visible:true,
                        cellContext:function(e, cell){ scope.iprightclick({arg1: cell.getData(), arg2: e, arg3: cell.getField(), arg4: scope.inputId});}
                    },
                    {title:"SPt", field:"src_port", align:"right", sorter:"number", sortable:true, editable:false, visible:true},
                    {title:"Dest IP", field:"dest_ip", align:"left", sorter:"string", sortable:true, editable:false, visible:true,
                        cellContext:function(e, cell){ scope.iprightclick({arg1: cell.getData(), arg2: e, arg3: cell.getField(), arg4: scope.inputId});}
                    },
                    {title:"DPt", field:"dest_port", align:"right", sorter:"number", sortable:true, editable:false, visible:true},
                    {title:"Proto", field:"proto", align:"right", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"App Proto", field:"app_proto", align:"right", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"SPkts", field:"flow.pkts_toserver", sorter:"number",visible:true, editable:false, align:"right"},
                    {title:"SBytes", field:"flow.bytes_toserver", sorter:"number",visible:true, editable:false, align:"right"},
                    {title:"DPkts", field:"flow.pkts_toclient", sorter:"number",visible:true, editable:false, align:"right"},
                    {title:"DBytes", field:"flow.bytes_toclient", sorter:"number",visible:true, editable:false, align:"right"}
                ],                

                rowClick:function(e, row){
                    scope.flowclick({arg1: row.getData(), arg2: row.getPosition(true)});
                },

            });
            
            angular.extend(scope.flowoptions, {
                flowselectrow: function(tname, data){
                    //console.log('Selecting: ' + data);
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    myElement.tabulator("selectRow", data);
                },
                flowgetselecteddata: function(tname){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("getSelectedData"); 
                    return data;
                },
                flowsetdata: function(tname, data){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    myElement.tabulator("setData", data); 
                },
                flowaddrow: function(tname, data){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    myElement.tabulator("addRow", data, false);
                },
                flowgetdata: function(tname){
                    var data = "";
                    var myElement = angular.element( document.querySelector('#' + tname) );
                    data = myElement.tabulator("getData"); 
                    return data;
                },
                flowgetselecteddata: function(tname){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("getSelectedData"); 
                    return data;
                },
                flowdownload: function(tname, filename){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("download", "csv", filename);
                    return data;
                },
                flowgetcolumns: function(tname){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("getColumns");
                    return data;
                },
                flowgetcolumndefinitions: function(tname){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("getColumnDefinitions");
                    return data;
                },
                flowtogglecolumn: function(tname, column){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("toggleColumn", column);
                    return data;
                },
                flowaddcolumn: function(tname, item){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("addColumn", item, false );
                    return data;
                }

            });
        }
    };
}]);