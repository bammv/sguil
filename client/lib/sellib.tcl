####################################################
# Sguil procs that deal with selection and         #
# Multi-selection of events                        #
####################################################
# $Id: sellib.tcl,v 1.5 2005/11/16 22:27:12 bamm Exp $
#
# ReSetMotion: Reset Motion Vars on a button release
#

proc SelectNextEvent { paneName index } {

    global ACTIVE_EVENT

    set listSize [$paneName size]

    if { $listSize == 0 } { set ACTIVE_EVENT 0; return }

    if { $index < $listSize  } {

        $paneName selection set $index
        SelectEventPane $paneName EVENT EVENT

    } elseif { $index > 0 } {

        $paneName selection set [expr $index - 1]
        SelectEventPane $paneName EVENT EVENT

    }

}
