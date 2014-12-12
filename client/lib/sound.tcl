proc LoadSoundTransforms { fileName } {

    global transforms

    for_file line $fileName {

        incr i

        # Filter out commented and empty lines
        if { ![regexp ^# $line] && ![regexp ^$ $line] } {
  
            if { [llength $line] == 2 } { 
    
                set transforms([lindex $line 0]) [lindex $line 1]
    
            } else {
    
                InfoMessage "Error at line $i in $fileName: $line"

            }

        }
    }

}

proc TurnSoundOff { sndButton } {
    global SOUND SOUND_SRVR FESTIVAL_ID
    set SOUND 0
    $sndButton configure -text Off -foreground red
    InfoMessage "Sound has been deactivated."
    if { $SOUND_SRVR == "festival" } {
        catch { close $FESTIVAL_ID} tmpError
        set FESTIVAL_ID ""
    }
}
proc TurnSoundOn { sndButton } {
    global SOUND SOUND_SRVR FESTIVAL_ID tcl_platform
    # Sound is off. Turn it on if we can.
    if { [file exists /dev/speech] } {
        # Looks like speechd is installed
        set SOUND_SRVR speechd
        set SOUND 1
        $sndButton configure -text On -foreground darkgreen
        Speak "Sound has been activated"
    } elseif { $tcl_platform(os) == "Darwin" } {
        set SOUND_SRVR say
        set SOUND 1
        $sndButton configure -text On -foreground darkgreen
        Speak "Sound has been activated"
    } else {
        # See if festival is running or start it if not.
        if [ catch { ConnectToFestival } FESTIVAL_ID ] {
            ErrorMessage\
             "Could not find speechd (/dev/speech) or\
              a festival server. Speech is NOT activated."
        } else {
            set SOUND_SRVR festival
            set SOUND 1
            $sndButton configure -text On -foreground darkgreen
            Speak "Sound has been activated"
        }
    }
}
proc ConnectToFestival {} {
    global DEBUG FESTIVAL_PATH 

    # Check to see if festival is already running.
    if [ catch { socket localhost 1314 } festSocketID ] {
        # Festival isn't running check to see if we have a path to the bin.
        if { [ file exists $FESTIVAL_PATH ] && [ file executable $FESTIVAL_PATH ] } {
            # If so, start it
            catch { eval exec $FESTIVAL_PATH --server & } startUpMsg 
            
            # Festival should be started now.
            # Wait 1 and try and reconnect.
            after 1000
            if [ catch { socket localhost 1314 } festSocketID ] {
                # Hrm. Still can't to festival. Gonna have to just forget it.
                if { $DEBUG } {
                    puts "ERROR: Started festival but still couldn't connect."
                }
                return -code error
            }
        } else {
          # No path to the binary
          if { $DEBUG } {
              puts "ERROR: File $FESTIVAL_PATH does not exist or is not executable."
          }
          return -code error
        }
    }
    return -code ok $festSocketID
}
proc Speak { msg } {
    global SOUND_SRVR FESTIVAL_ID SOUND transforms

    if { [array exists transforms] } {
        foreach pat [array names transforms] { 
            regsub $pat $msg $transforms($pat) msg 
        }
    }

    if { $SOUND_SRVR == "speechd" } {
        set soundFileID [open /dev/speech w]
        puts $soundFileID $msg
        close $soundFileID
    } elseif { $SOUND_SRVR == "festival" } {
        if [ catch { puts $FESTIVAL_ID "(SayText \"$msg\")" } festError ] {
            # Error trying to write to festival. Try to restart it.
            if [ catch { ConnectToFestival } FESTIVAL_ID ] {
                ErrorMessage\
                 "The festival server appears to have died and\
                  cannot be restarted correctly. Speech has been\
                  deactivated."
                set SOUND 0
            }
            
        } else {
            flush $FESTIVAL_ID
        }
    } elseif { $SOUND_SRVR == "say" } {
            if [catch { exec say \"$msg\" & } tmpError] {
                ErrorMessage "Error trying to use say: $tmpError"
                TurnSoundOff
            }
    }
}
