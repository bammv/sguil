proc HttpDate { secs } {

    return [clock format $secs -gmt 1 -format {%a, %d %b %Y %T %Z}]]
}

proc SguildGetContentType { filepath } {

    set ext [file extension $filepath]

    switch -exact $ext {

        ".css"	{ set m "text/css" }
        ".js"	{ set m "text/javascript" }
        ".svg"	{ set m "image/svg+xml" }
        default	{ }

    }
    return $m

}

proc SguildHttpRespond {sock ip port filename hdrs} {

    global DEBUG HTML_PATH pcapURLMap clientWebSockets socketInfo WS_SERVER_SOCK

    fileevent $sock readable ""
    #set HTML_PATH {/usr/local/src/sguil.git/sguil/server/html}

    set filepath $HTML_PATH/$filename

    if { [file exists $filepath] } {

        SguildSendHttpFile $sock $filepath

    } else {

        set fileroot [lindex [file split $filename] 0]
        
        if { $fileroot == "ws" } {

            chan configure $sock -translation crlf
            lappend clientWebSockets $sock
            set socketInfo($sock) [list $ip $port]
            if {[::websocket::test $WS_SERVER_SOCK $sock / $hdrs]} {

                ::websocket::upgrade $sock

            } else {

                #close $client_socket
                set clientWebSockets [ldelete $clientWebSockets $sock]
                ClientExitClose $sock

            }

        } elseif { $fileroot == "pcap" } {

            # Second index is the key to the file path
            set fileKey [lindex [file split $filename] 1]
            set filePath $pcapURLMap($fileKey)

            SguildSendHttpFile $sock $filePath

        } else {

            SguildSendHttpError $sock

        }

    }

}

proc SguildSendHttpFile { sock filepath } {

    set bytes [file size $filepath]

    # Get the content type
    set ct [SguildGetContentType $filepath]

    puts $sock "HTTP/1.0 200 Data follows"
    set now [HttpDate [clock seconds]]
    puts $sock "Date: $now"
    if { [catch {file mtime $filepath} mt] } {
        set mt $now
    }
    puts $sock "Last-Modified: $mt"
    puts $sock "Content-Type: $ct"
    puts $sock ""
    if { ![catch {open $filepath r} fileID] } {

        fconfigure $fileID -translation binary -encoding binary
        fconfigure $sock -translation binary -encoding binary -buffering full -buffersize 99999
        fcopy $fileID $sock
        SguildHttpFileFinished $sock $fileID $filepath $bytes

    } else {

        SguildSendHttpError $sock

    }

}

proc SguildSendHttpError { socketID {msg {}} } {

        set errorMsg "<title>404 ERROR</title>"
        puts $socketID "HTTP/1.0 404"
        puts $socketID "Date: [ HttpDate [clock seconds]]"
        puts $socketID "Content-Length: [string length $errorMsg]"
        SguildHttpClose $socketID

}

proc SguildHttpFileFinished { socketID fileID filepath bytes {error {}} } {

    # Do we need to do more than this?
    catch {close $fileID}
    SguildHttpClose $socketID 

}

proc SguildHttpParser {sock ip port reqstring hdrs} {

    array set req $reqstring

    if { $req(path) == "" } { 

        SguildHttpRespond $sock $ip $port index.html $hdrs 

    } else {

        SguildHttpRespond $sock $ip $port $req(path) $hdrs

    }

}

proc SguildHttpAccept {sock ip port} {

    global DEBUG

    if {![catch {gets $sock} line] } {

        chan configure $sock -translation crlf
        while {[gets $sock header_line]>=0 && $header_line ne ""} {

            if {[regexp -expanded {^( [^\s:]+ ) \s* : \s* (.+)} $header_line -> header_name header_value]} {

                lappend hdrs $header_name $header_value

            } else {

                break

            }

        }

        # Things break w/o this
        lappend hdrs sec-websocket-protocol {}

        if {[eof $sock]} { SguildHttpClose $sock }

        if { $line != "" } { 

            if { $DEBUG } { puts "HTTP: Request from $ip -> $line" }

            foreach {method url version} $line { break }
            switch -exact $method {

                GET { SguildHttpParser $sock $ip $port [uri::split $url] $hdrs}
                default { SguildHttpError $sock "Unsupported method $method from $ip" }

            }
        }

     } else {

        if { $DEBUG } { puts "Error in SguildHttpAccept: $line" }
        catch {close $sock}

    }


}

proc SguildHttpError { socketID msg } {

    catch {close $socketID}

}

proc SguildHttpClose { socketID } {

    catch {close $socketID}

}


proc SguildInitHttps {} {

    global PEM KEY CHAIN WS_SERVER_SOCK HTTPS_PORT

    package require html

    if { $CHAIN != "" } {

        ::tls::init -cafile $CHAIN -certfile $PEM -keyfile $KEY -tls1 1 -request 0 -require 0

    } else {

        ::tls::init -certfile $PEM -keyfile $KEY -tls1 1 -request 0 -require 0

    }

    set WS_SERVER_SOCK [::tls::socket -server SguildHttpAccept $HTTPS_PORT]
    ::websocket::server $WS_SERVER_SOCK
    ::websocket::live $WS_SERVER_SOCK * wsLiveCB


}

proc HttpPcapRequest { socketID sensor sensorID aid timestamp srcIP srcPort dstIP dstPort ipProto force } {

    # HttpPcapRequest suricata-int 1 1.14869 {2018-03-20 23:47:57} 192.168.8.79 56489 104.31.75.95 80 0

    global NEXT_TRANS_ID transInfoArray LOCAL_LOG_DIR

    # Increment the xscript counter. Gives us a unique way to track the xscript
    incr NEXT_TRANS_ID
    set TRANS_ID $NEXT_TRANS_ID
    set date [lindex $timestamp 0]

    if [catch { InitRawFileArchive $date $sensor $srcIP $dstIP $srcPort $dstPort $ipProto }\
      rawDataFileNameInfo] {
        catch {SendSocket $socketID [list ErrorMessage "Error getting pcap: $rawDataFileNameInfo"]}
        return
    }

    set sensorDir [lindex $rawDataFileNameInfo 0]
    set rawDataFileName [lindex $rawDataFileNameInfo 1]

    # A list of info we'll need when we generate the actual xscript after the rawdata is returned.
    set transInfoArray($TRANS_ID) [list $socketID $aid $sensorDir http $sensor $timestamp ]


    if { ! [file exists $sensorDir/$rawDataFileName] || $force } {

        # No local archive (first request) or the user has requested we force a check for new data.
        if { ![GetRawDataFromSensor $TRANS_ID $sensor $sensorID $timestamp $srcIP $srcPort $dstIP $dstPort $ipProto $rawDataFileName http] } {

            # This means the sensor_agent for this sensor isn't connected.
            catch {SendSocket $socketID [list ErrorMessage "ERROR: Unable to request rawdata at this time.\
             The sensor $sensor is NOT connected."]}

        }

    } else {

        # The data is archived locally.
        HttpPcapAvailable $sensorDir/$rawDataFileName $TRANS_ID

    }

}

proc HttpPcapAvailable { filename TRANS_ID} {

    global transInfoArray pcapURLMap

    set nfilename "[file rootname $filename].pcap"

    # make a hashed passwd
    set randomHash [::sha1::sha1 [RandomString 20]]

    set pcapURLMap($randomHash) $filename
    

    catch {SendSocket [lindex $transInfoArray($TRANS_ID) 0] [list HttpPcapAvailable [lindex $transInfoArray($TRANS_ID) 1] pcap/$randomHash/[file tail $nfilename]]}

}

