angular.module('httpTabulatorModule', [])
 .directive('httptabulator', ['$filter', function ($filter) {

    return {
        restrict: 'E',
        replace: true,
        scope: { 
            httpclick: '&',
            eventrightclick: '&',
            iprightclick: '&',
            httpoptions: '=' ,
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
                    {title:"timestamp", field:"timestamp", align:"left", sorter:"date", sortable:true, editable:false, visible:true, 
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
                    {title:"Proto", field:"http.protocol", align:"left", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"Hostname", field:"http.hostname", align:"left", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"Method", field:"http.http_method", align:"left", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"URL", field:"http.url", align:"left", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"User Agent", field:"http.http_user_agent", align:"left", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"Content Type", field:"http.http_content_type", align:"left", sorter:"string", sortable:true, editable:false, visible:true},
                    {title:"Status", field:"http.status", align:"right", sorter:"number", sortable:true, editable:false, visible:true},
                ],                

                rowClick:function(e, row){
                    scope.httpclick({arg1: row.getData(), arg2: row.getPosition(true)});
                },

            });
            
            angular.extend(scope.httpoptions, {
                httpselectrow: function(tname, data){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    myElement.tabulator("selectRow", data);
                },
                httpgetselecteddata: function(tname){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("getSelectedData"); 
                    return data;
                },
                httpsetdata: function(tname, data){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    myElement.tabulator("setData", data); 
                },
                httpaddrow: function(tname, data){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    myElement.tabulator("addRow", data, false);
                },
                httpgetdata: function(tname){
                    var data = "";
                    var myElement = angular.element( document.querySelector('#' + tname) );
                    data = myElement.tabulator("getData"); 
                    return data;
                },
                httpgetselecteddata: function(tname){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("getSelectedData"); 
                    return data;
                },
                httpdownload: function(tname, filename){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("download", "csv", filename);
                    return data;
                },
                httpgetcolumns: function(tname){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("getColumns");
                    return data;
                },
                httpgetcolumndefinitions: function(tname){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("getColumnDefinitions");
                    return data;
                },
                httptogglecolumn: function(tname, column){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("toggleColumn", column);
                    return data;
                },
                httpaddcolumn: function(tname, item){
                    var myElement = angular.element( document.querySelector( '#' + tname ) );
                    var data = myElement.tabulator("addColumn", item, false );
                    return data;
                }
            });
        }
    };
}]);