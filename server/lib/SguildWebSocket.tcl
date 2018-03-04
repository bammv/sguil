proc InitWebSocket { WS_PORT } {

    global WS_SERVER_SOCK KEY PEM

    package require websocket
    #::websocket::loglevel debug

    package require json::write
    ::json::write indented 0
    package require json

    ::tls::init -keyfile $KEY -certfile $PEM -tls1 1 -request 0 -require 0

    set WS_SERVER_SOCK [tls::socket -server handleConnect $WS_PORT] 

    ::websocket::server $WS_SERVER_SOCK 
    ::websocket::live $WS_SERVER_SOCK / wsLiveCB 

    # Set up HTTPS to serve the static web content
    SguildInitHttps

}

proc handleConnect {client_socket IP_address port} {

    global clientWebSockets socketInfo DEBUG

    if { $DEBUG} { puts "DEBUG #### WebSocket connected --> $IP_address $port $client_socket" } 

    if { [catch {tls::handshake $client_socket} results] } {

        LogMessage "ERROR: handleConnect: $results"
        #close $client_socket
        ClientExitClose $client_socket
        return

    }

    lappend clientWebSockets $client_socket
    set socketInfo($client_socket) [list $IP_address $port]

    fileevent $client_socket readable [list handleRead $client_socket] 

} 
 
proc handleRead {client_socket} { 

    global WS_SERVER_SOCK clientWebSockets

    if { [eof $client_socket] } {

        # Socket closed
        catch {close $client_socket}
        ClientExitClose $client_socket
        LogMessage "Socket $client_socket closed"

    } else {

        chan configure $client_socket -translation crlf
    
        gets $client_socket line


        while {[gets $client_socket header_line]>=0 && $header_line ne ""} {
    
            if {[regexp -expanded {^( [^\s:]+ ) \s* : \s* (.+)} $header_line -> header_name header_value]} {

                lappend hdrs $header_name $header_value

            } else {

                break

            }

        }

        # Not sure why there isn't a protocol, but the websocket lib blows up if this doesn't exist
        lappend hdrs sec-websocket-protocol {} 
    
        if {[::websocket::test $WS_SERVER_SOCK $client_socket / $hdrs]} { 

            ::websocket::upgrade $client_socket 

        } else {

            #close $client_socket
            set clientWebSockets [ldelete $clientWebSockets $client_socket]
            ClientExitClose $client_socket

        }

    }

}

proc wsLiveCB {client_socket type_of_event {data_received {}}} { 

    global clientWebSockets DEBUG

    #puts "
    #inside wsLiveCB handler
    #=======================
    #client_socket: $client_socket
    #type_of_event: $type_of_event
    #data_received: $data_received\n"

    switch $type_of_event { 
        connect { SguildWebSocketConnect $client_socket $type_of_event $data_received}
        disconnect { 
            SguildWebSocketDisconnect $client_socket
        } 
        text { 
            SguildWebSocketMsgRcvd $client_socket $data_received
        }
        binary {}
        error { LogMessage "WebSocket: error"; ClientExitClose $client_socket }
        close { ClientExitClose $client_socket }
        timeout { ClientExitClose $client_socket }
        error { LogMessage "WebSocket Error: $data_received" }
        timeout { }
        ping {}
        pong {}
    }

}

proc SguildWebSocketConnect { client_socket type_of_event data_received } {

    LogMessage "WebSocket Connect - socket: $client_socket  type_of_event: $type_of_event  data_received: $data_received"

}

proc SguildWebSocketDisconnect { client_socket } {

    global clientWebSockets

    if { [info exists clientWebSockets] } {

        set clientWebSockets [ldelete $clientWebSockets $client_socket]

    }
    ClientExitClose $client_socket

}

proc SguildSendWebSocket { socketID msg } {

    global clientWebSockets

    set objectName [lindex $msg 0]

    switch -exact $objectName {

        DeleteEventIDList 	{ foreach v [lindex $msg 1] { lappend values [json::write string $v] } }
        InsertEvent 		{ foreach v [lindex $msg 1] { lappend values [json::write string $v] } }
        InsertEscalatedEvent 	{ foreach v [lindex $msg 1] { lappend values [json::write string $v] } }
        InsertQueryResults 	{ 
                                    lappend values [json::write string [lindex $msg 1]]
                                    foreach v [lindex $msg 2] { lappend values [json::write string $v] } 
                                }
        SensorList 		{
            			    set v [lrange $msg 1 end]
            			    foreach i $v { 
                			    set o [lindex $i 0]
                			    set str {}
                			    foreach s [lindex $i 1] { lappend str [json::write string $s] }
                			    lappend values [json::write object $o [json::write array {*}$str]]
            			    }
        		  	}
        default { foreach v [lrange $msg 1 end] { lappend values [json::write string $v] } }

    } 

    # The array is our list of "args"
    set a [json::write array {*}$values]
    # The object name is our command
    set o [json::write object $objectName $a]

    if { [catch {::websocket::send $socketID text "$o"} sendError] } { 

        return -code error -errorinfo $sendError

    }

}

proc SguildWebSocketMsgRcvd { socketID jdata } {

    global clientWebSockets validSockets

    # Websocket data comes in via json
    if [catch {json::json2dict $jdata} pdata] {

        LogMessage "Error: Received poorly formatted message from websocket $socketID => $jdata \n $pdata"
        return

    }

    if { [catch {dict keys $pdata} clientCmd] } {

        LogMessage "Error: Failed to parse $pdata: $clientCmd"
        return

    }

    if { [catch {dict get $pdata $clientCmd} values] } {

        LogMessage "Error: Failed to get cmd values for $clientCmd: $values"
        return

    }

    set data "$clientCmd $values"


    # Check to make the client validated itself
    if { $clientCmd != "ValidateUser" && \
         $clientCmd != "PING" && \
         $clientCmd != "VersionInfo" && \
         $clientCmd != "SendPcap" } {

        if { [lsearch -exact $validSockets $socketID] < 0 } {

            catch {SendSocket $socketID \
             [list InfoMessage "Client does not appear to be logged in. Please exit and log back in."]} tmpError
            return

        }

    }

    switch -exact $clientCmd {

      DeleteEventIDList   { $clientCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      EventHistoryRequest { $clientCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      GetCorrelatedEvents { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      GetIcmpData         { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      GetIPData           { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      GetPayloadData      { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      GetTcpData          { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      GetUdpData          { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      MonitorSensors      { $clientCmd $socketID [lindex $data 1] }
      QueryDB             { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      RuleRequest         { $clientCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] \
                            [lindex $data 4] [lindex $data 5] }
      SendSensorList      { $clientCmd $socketID }
      SendEscalatedEvents { $clientCmd $socketID }
      SendDBInfo          { $clientCmd $socketID }
      ValidateUser        { ValidateUser $socketID [lindex $data 1] [lindex $data 2] }
      PING                { ClientPingRcvd $socketID }
      UserMessage         { UserMsgRcvd $socketID [lindex $data 1] }
      SendGlobalQryList   { catch {SendSocket $socketID [list GlobalQryList $GLOBAL_QRY_LIST]} }
      SendReportQryList   { catch {SendSocket $socketID [list ReportQryList $REPORT_QRY_LIST]} }
      ReportRequest       { ReportBuilder $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      GetSancpFlagData    { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      XscriptRequest      { eval $clientCmd $socketID [lrange $data 1 end] }
      WiresharkRequest    { eval $clientCmd $socketID [lrange $data 1 end] }
      SendPcap            { $clientCmd $socketID [lindex $data 1] }
      AbortXscript        { $clientCmd $socketID [lindex $data 1] }
      GetOpenPorts        { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      SendClientSensorStatusInfo { $clientCmd $socketID }
      GetAssetData        { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      GetGenericDetail    { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      VersionInfo         { ClientVersionCheck $socketID [lindex $data 1] }
      QuickScript         { $clientCmd $socketID [lindex $data 1] }
      ChangePass          { $clientCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      AutoCatRequest      { $clientCmd $socketID [lrange $data 1 end] }
      SendAutoCatList     { $clientCmd $socketID }
      EnableAutoCatRule   { $clientCmd $socketID [lindex $data 1] }
      DisableAutoCatRule   { $clientCmd $socketID [lindex $data 1] }
      UserSelectedEvent   { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }
      CliScript           { $clientCmd $socketID [lindex $data 1] }
      GetWhoisData        { $clientCmd $socketID [lindex $data 1] }
      default { InfoMessage "Unrecognized command from $socketID: $data" }

    }


}
