proc SendSensorAgent { socketID msg } {
    
    set RFLAG 1
    if { [catch { puts $socketID $msg } sendError] } {
        catch { close $socketID } tmpError
        CleanUpDisconnectedAgent $socketID
        set RFLAG 0
    }

    return $RFLAG
}
