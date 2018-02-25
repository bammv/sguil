#==============================================================================
# Contains some Tk option database settings.
#
# Copyright (c) 2004-2015  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

#
# Get the current windowing system ("x11", "win32", or
# "aqua") and add some entries to the Tk option database
#
if {[tk windowingsystem] eq "x11"} {
    option add *Font			TkDefaultFont
} else {
    option add *ScrollArea.borderWidth			1
    option add *ScrollArea.relief			sunken
    option add *ScrollArea.Tablelist.borderWidth	0
    option add *ScrollArea.Text.borderWidth		0
    option add *ScrollArea.Text.highlightThickness	0
}
tablelist::setThemeDefaults
if {[tablelist::getCurrentTheme] eq "aqua"} {
    option add *Listbox.selectBackground \
	       $tablelist::themeDefaults(-selectbackground)
    option add *Listbox.selectForeground \
	       $tablelist::themeDefaults(-selectforeground)
} else {
    option add *selectBackground  $tablelist::themeDefaults(-selectbackground)
    option add *selectForeground  $tablelist::themeDefaults(-selectforeground)
}
option add *selectBorderWidth     $tablelist::themeDefaults(-selectborderwidth)
option add *Tablelist.background	white
option add *Tablelist.stripeBackground	#e4e8ec
option add *Tablelist.setGrid		yes
option add *Tablelist.movableColumns	yes
option add *Tablelist.labelCommand	tablelist::sortByColumn
option add *Tablelist.labelCommand2	tablelist::addToSortColumns
