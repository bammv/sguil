#!/usr/bin/env wish

#==============================================================================
# Demonstrates some ways of improving the look & feel of a tablelist widget.
#
# Copyright (c) 2002-2015  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

package require tablelist_tile 5.14

wm title . "Tablelist Styles"

#
# Improve the window's appearance by using a tile
# frame as a container for the other widgets
#
set f [ttk::frame .f]

#
# Create, configure, and populate 8 tablelist widgets
#
ttk::frame $f.f
for {set n 0} { $n < 8} {incr n} {
    set tbl $f.f.tbl$n
    tablelist::tablelist $tbl \
	-columntitles {"Label 0" "Label 1" "Label 2" "Label 3"} \
	-background white -stripebackground "" -height 4 -width 40 -stretch all
    if {[$tbl cget -selectborderwidth] == 0} {
	$tbl configure -spacing 1
    }

    switch $n {
	1 {
	    $tbl configure -showseparators yes
	}
	2 {
	    $tbl configure -stripebackground #e4e8ec
	}
	3 {
	    $tbl configure -stripebackground #e4e8ec -showseparators yes
	}
	4 {
	    $tbl columnconfigure 1 -background LightYellow
	    $tbl columnconfigure 3 -background LightCyan
	}
	5 {
	    $tbl configure -showseparators yes
	    $tbl columnconfigure 1 -background LightYellow
	    $tbl columnconfigure 3 -background LightCyan
	}
	6 {
	    $tbl configure -stripebackground #e4e8ec
	    $tbl columnconfigure 1 -background LightYellow \
		-stripebackground #e5e5c9
	    $tbl columnconfigure 3 -background LightCyan \
		-stripebackground #c9e5e5
	}
	7 {
	    $tbl configure -stripebackground #e4e8ec -showseparators yes
	    $tbl columnconfigure 1 -background LightYellow \
		-stripebackground #e5e5c9
	    $tbl columnconfigure 3 -background LightCyan \
		-stripebackground #c9e5e5
	}
    }

    foreach row {0 1 2 3} {
	$tbl insert end \
	     [list "Cell $row,0" "Cell $row,1" "Cell $row,2" "Cell $row,3"]
    }
}

ttk::button $f.close -text "Close" -command exit
ttk::frame $f.bottom -height 10

#
# Manage the widgets
#
grid $f.f.tbl0 $f.f.tbl1 -sticky news -padx 5 -pady 5
grid $f.f.tbl2 $f.f.tbl3 -sticky news -padx 5 -pady 5
grid $f.f.tbl4 $f.f.tbl5 -sticky news -padx 5 -pady 5
grid $f.f.tbl6 $f.f.tbl7 -sticky news -padx 5 -pady 5
grid rowconfigure    $f.f {0 1 2 3} -weight 1
grid columnconfigure $f.f {0 1}     -weight 1
pack $f.bottom $f.close -side bottom
pack $f.f -side top -expand yes -fill both -padx 5 -pady 5
pack $f -expand yes -fill both
