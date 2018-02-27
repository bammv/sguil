proc HttpDate { secs } {

    return [clock format $secs -gmt 1 -format {%a, %d %b %Y %T %Z}]]
}

proc SguildGetContentType { filepath } {

    set m [fileutil::magic::mimetype $filepath]

    # If fileutil can't determine the type, then try by extension.
    # We only server css, js, images
    if { $m == "" } {

        set ext [file extension $filepath]

        switch -exact $ext {

            ".css"	{ set m "text/css" }
            ".js"	{ set m "text/javascript" }
            ".svg"	{ set m "image/svg+xml" }
            default	{ }

        }

    }

    return $m

}

proc SguildHttpRespond {sock filename } {

    fileevent $sock readable ""
    set HTML_PATH {/usr/local/src/sguil.git/sguil/server/html}

    set filepath $HTML_PATH/$filename

    if { [file exists $filepath] } {

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

    } else {

        SguildSendHttpError $sock

    }

}

proc SguildSendHttpError { socketID {msg {}} } {

        set errorMsg "<title>404 ERROR</title>"
        puts $socketID "HTTP/1.0 404"
        puts $socketID "Date: [ [clock seconds]]"
        puts $socketID "Content-Length: [string length $errorMsg]"
        SguildHttpClose $socketID

}

proc SguildHttpFileFinished { socketID fileID filepath bytes {error {}} } {

    # Do we need to do more than this?
    catch {close $fileID}
    SguildHttpClose $socketID 

}

proc SguildHttpParser {sock ip reqstring} {

    array set req $reqstring

    if { $req(path) == "" } { 

        SguildHttpRespond $sock index.html 

    } else {

        SguildHttpRespond $sock $req(path)

    }

}

proc SguildHttpAccept {sock ip port} {

    global DEBUG

    if {[catch {

        gets $sock line

        for {set c 0} {[gets $sock temp]>=0 && $temp ne "\r" && $temp ne ""} {incr c} {

            if {$c == 30} { SguildHttpError $sock "Too many lines from $ip" }

        }

        if {[eof $sock]} { SguildHttpClose $sock }

        if { $line != "" } { 
            foreach {method url version} $line { break }
            switch -exact $method {

                GET { SguildHttpParser $sock $ip [uri::split $url] }
                default { SguildHttpError $sock "Unsupported method $method from $ip" }

            }
        }

     } msg] } {

        if { $DEBUG } { puts "Error in SguildHttpAccept: $msg" }

    }

    catch {close $sock}

}

proc SguildHttpError { socketID msg } {

    catch {close $socketID}

}

proc SguildHttpClose { socketID } {

    catch {close $socketID}

}


proc SguildInitHttps {} {

    global PEM KEY

    package require html
    #package require mimetype

    ::tls::init -certfile $PEM -keyfile $KEY -tls1 1
    ::tls::socket -server SguildHttpAccept 443 

}
