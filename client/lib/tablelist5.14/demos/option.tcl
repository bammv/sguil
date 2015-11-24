#==============================================================================
# Contains some Tk option database settings.
#
# Copyright (c) 2004-2015  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

#
# Get the current windowing system ("x11", "win32", "classic", or "aqua")
#
if {[catch {tk windowingsystem} winSys] != 0} {
    switch $::tcl_platform(platform) {
	unix      { set winSys x11 }
	windows   { set winSys win32 }
	macintosh { set winSys classic }
    }
}

#
# Add some entries to the Tk option database
#
if {[string compare $winSys "x11"] == 0} {
    #
    # Create the font TkDefaultFont if not yet present
    #
    catch {font create TkDefaultFont -family Helvetica -size -12}

    option add *Font			TkDefaultFont
    option add *selectBackground	#678db2
    option add *selectForeground	white
} else {
    option add *ScrollArea.borderWidth			1
    option add *ScrollArea.relief			sunken
    option add *ScrollArea.Tablelist.borderWidth	0
    option add *ScrollArea.Tablelist.highlightThickness	0
    option add *ScrollArea.Text.borderWidth		0
    option add *ScrollArea.Text.highlightThickness	0
}
option add *Tablelist.background	white
option add *Tablelist.stripeBackground	#e4e8ec
option add *Tablelist.setGrid		yes
option add *Tablelist.movableColumns	yes
option add *Tablelist.labelCommand	tablelist::sortByColumn
option add *Tablelist.labelCommand2	tablelist::addToSortColumns
