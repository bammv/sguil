#!/usr/bin/env wish

#==============================================================================
# Demonstrates the interactive tablelist cell editing with the aid of some
# widgets from the tile package and of the Tk core spinbox widget.
#
# Copyright (c) 2005-2015  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

package require tablelist_tile 5.14

wm title . "Serial Line Configuration"

#
# Add some entries to the Tk option database
#
set dir [file dirname [info script]]
source [file join $dir option_tile.tcl]
option add *Tablelist*Spinbox.background		white
option add *Tablelist*Spinbox.readonlyBackground	white

#
# Create the images "checkedImg" and "uncheckedImg", as well as 16 images of
# names like "img#FF0000", displaying colors identified by names like "red"
#
source [file join $dir images.tcl]

#
# Improve the window's appearance by using a tile
# frame as a container for the other widgets
#
set f [ttk::frame .f]

#
# Work around the improper appearance of the tile scrollbars in the aqua theme
#
if {[tablelist::getCurrentTheme] eq "aqua"} {
    interp alias {} ttk::scrollbar {} ::scrollbar
}

#
# Create a tablelist widget with editable columns (except the first one)
#
set tbl $f.tbl
tablelist::tablelist $tbl \
    -columns {0 "No."		  right
	      0 "Available"	  center
	      0 "Name"		  left
	      0 "Baud Rate"	  right
	      0 "Data Bits"	  center
	      0 "Parity"	  left
	      0 "Stop Bits"	  center
	      0 "Handshake"	  left
	      0 "Activation Date" center
	      0 "Activation Time" center
	      0 "Cable Color"	  center} \
    -editstartcommand editStartCmd -editendcommand editEndCmd \
    -height 0 -width 0
if {[$tbl cget -selectborderwidth] == 0} {
    $tbl configure -spacing 1
}
$tbl columnconfigure 0 -sortmode integer
$tbl columnconfigure 1 -name available -editable yes \
    -editwindow ttk::checkbutton -formatcommand emptyStr
$tbl columnconfigure 2 -name lineName  -editable yes -editwindow ttk::entry \
    -sortmode dictionary
$tbl columnconfigure 3 -name baudRate  -editable yes -editwindow ttk::combobox \
    -sortmode integer
if {[info commands ttk::spinbox] eq ""} {
    $tbl columnconfigure 4 -name dataBits -editable yes -editwindow spinbox
} else {
    $tbl columnconfigure 4 -name dataBits -editable yes -editwindow ttk::spinbox
}
$tbl columnconfigure 5 -name parity    -editable yes -editwindow ttk::combobox
$tbl columnconfigure 6 -name stopBits  -editable yes -editwindow ttk::combobox
$tbl columnconfigure 7 -name handshake -editable yes -editwindow ttk::combobox
$tbl columnconfigure 8 -name actDate   -editable yes -editwindow ttk::entry \
    -formatcommand formatDate -sortmode integer
$tbl columnconfigure 9 -name actTime   -editable yes -editwindow ttk::entry \
    -formatcommand formatTime -sortmode integer
$tbl columnconfigure 10 -name color    -editable yes \
    -editwindow ttk::menubutton -formatcommand emptyStr

proc emptyStr   val { return "" }
proc formatDate val { return [clock format $val -format "%Y-%m-%d"] }
proc formatTime val { return [clock format $val -format "%H:%M:%S"] }

#
# Populate the tablelist widget; set the activation
# date & time to 10 minutes past the current clock value
#
set clock [expr {[clock seconds] + 600}]
for {set i 0; set n 1} {$i < 16} {set i $n; incr n} {
    $tbl insert end [list $n [expr {$i < 8}] "Line $n" 9600 8 None 1 XON/XOFF \
	$clock $clock [lindex $colorNames $i]]

    set availImg [expr {($i < 8) ? "checkedImg" : "uncheckedImg"}]
    $tbl cellconfigure end,available -image $availImg
    $tbl cellconfigure end,color -image img[lindex $colorValues $i]
}

set btn [ttk::button $f.btn -text "Close" -command exit]

#
# Manage the widgets
#
pack $btn -side bottom -pady 10
pack $tbl -side top -expand yes -fill both
pack $f -expand yes -fill both

#------------------------------------------------------------------------------
# editStartCmd
#
# Applies some configuration options to the edit window; if the latter is a
# combobox, the procedure populates it.
#------------------------------------------------------------------------------
proc editStartCmd {tbl row col text} {
    set w [$tbl editwinpath]

    switch [$tbl columncget $col -name] {
	lineName {
	    #
	    # Set an upper limit of 20 for the number of characters
	    #
	    $w configure -invalidcommand bell -validate key \
			 -validatecommand {expr {[string length %P] <= 20}}
	}

	baudRate {
	    #
	    # Populate the combobox and allow no more
	    # than 6 digits in its entry component
	    #
	    $w configure -values {50 75 110 300 1200 2400 4800 9600 19200 38400
				  57600 115200 230400 460800 921600}
	    $w configure -invalidcommand bell -validate key -validatecommand \
		{expr {[string length %P] <= 6 && [regexp {^[0-9]*$} %S]}}
	}

	dataBits {
	    #
	    # Configure the spinbox
	    #
	    $w configure -from 5 -to 8 -state readonly
	}

	parity {
	    #
	    # Populate the combobox and make it non-editable
	    #
	    $w configure -values {None Even Odd Mark Space} -state readonly
	}

	stopBits {
	    #
	    # Populate the combobox and make it non-editable
	    #
	    $w configure -values {1 1.5 2} -state readonly
	}

	handshake {
	    #
	    # Populate the combobox and make it non-editable
	    #
	    $w configure -values {XON/XOFF RTS/CTS None} -state readonly
	}

	actDate {
	    #
	    # Set an upper limit of 10 for the number of characters
	    # and allow only digits and the "-" character in it
	    #
	    $w configure -invalidcommand bell -validate key -validatecommand \
		{expr {[string length %P] <= 10 && [regexp {^[0-9-]*$} %S]}}
	}

	actTime {
	    #
	    # Set an upper limit of 8 for the number of characters
	    # and allow only digits and the ":" character in it
	    #
	    $w configure -invalidcommand bell -validate key -validatecommand \
		{expr {[string length %P] <= 8 && [regexp {^[0-9:]*$} %S]}}
	}

	color {
	    #
	    # Populate the menu and make sure the menubutton will display the
	    # color name rather than $text, which is "", due to -formatcommand
	    #
	    set menu [$w cget -menu]
	    foreach name $::colorNames {
		$menu add radiobutton -compound left \
		    -image img$::colors($name) -label $name
	    }
	    $menu entryconfigure 8 -columnbreak 1
	    return [$tbl cellcget $row,$col -text]
	}
    }

    return $text
}

#------------------------------------------------------------------------------
# editEndCmd
#
# Performs a final validation of the text contained in the edit window and gets
# the cell's internal contents.
#------------------------------------------------------------------------------
proc editEndCmd {tbl row col text} {
    switch [$tbl columncget $col -name] {
	available {
	    #
	    # Update the image contained in the cell
	    #
	    set img [expr {$text ? "checkedImg" : "uncheckedImg"}]
	    $tbl cellconfigure $row,$col -image $img
	}

	baudRate {
	    #
	    # Check whether the baud rate is an integer in the range 50..921600
	    #
	    if {![regexp {^[0-9]+$} $text] || $text < 50 || $text > 921600} {
		bell
		tk_messageBox -title "Error" -icon error -message \
		    "The baud rate must be an integer in the range 50..921600"
		$tbl rejectinput
	    }
	}

	actDate {
	    #
	    # Get the activation date in seconds from the last argument 
	    #
	    if {[catch {clock scan $text} actDate] != 0} {
		bell
		tk_messageBox -title "Error" -icon error -message "Invalid date"
		$tbl rejectinput
		return ""
	    }

	    #
	    # Check whether the activation clock value is later than the
	    # current one; if this is the case then make sure the cells
	    # "actDate" and "actTime" will have the same internal value
	    #
	    set actTime [$tbl cellcget $row,actTime -text]
	    set actClock [clock scan [formatTime $actTime] -base $actDate]
	    if {$actClock <= [clock seconds]} {
		bell
		tk_messageBox -title "Error" -icon error -message \
		    "The activation date & time must be in the future"
		$tbl rejectinput
	    } else {
		$tbl cellconfigure $row,actTime -text $actClock
		return $actClock
	    }
	}

	actTime {
	    #
	    # Get the activation clock value in seconds from the last argument 
	    #
	    set actDate [$tbl cellcget $row,actDate -text]
	    if {[catch {clock scan $text -base $actDate} actClock] != 0} {
		bell
		tk_messageBox -title "Error" -icon error -message "Invalid time"
		$tbl rejectinput
		return ""
	    }

	    #
	    # Check whether the activation clock value is later than the
	    # current one; if this is the case then make sure the cells
	    # "actDate" and "actTime" will have the same internal value
	    #
	    if {$actClock <= [clock seconds]} {
		bell
		tk_messageBox -title "Error" -icon error -message \
		    "The activation date & time must be in the future"
		$tbl rejectinput
	    } else {
		$tbl cellconfigure $row,actDate -text $actClock
		return $actClock
	    }
	}

	color {
	    #
	    # Update the image contained in the cell
	    #
	    $tbl cellconfigure $row,$col -image img$::colors($text)
	}
    }

    return $text
}
