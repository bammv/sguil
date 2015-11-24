#==============================================================================
# Contains the implementation of the tablelist widget.
#
# Structure of the module:
#   - Namespace initialization
#   - Private procedure creating the default bindings
#   - Public procedure creating a new tablelist widget
#   - Private procedures implementing the tablelist widget command
#   - Private callback procedures
#
# Copyright (c) 2000-2015  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

#
# Namespace initialization
# ========================
#

namespace eval tablelist {
    #
    # Get the current windowing system ("x11", "win32", "classic", or "aqua")
    #
    variable winSys
    if {[catch {tk windowingsystem} winSys] != 0} {
	switch $::tcl_platform(platform) {
	    unix	{ set winSys x11 }
	    windows	{ set winSys win32 }
	    macintosh	{ set winSys classic }
	}
    }

    #
    # Create aliases for a few tile commands if not yet present
    #
    proc createTileAliases {} {
	if {[string length [interp alias {} ::tablelist::style]] != 0} {
	    return ""
	}

	if {[string length [info commands ::ttk::style]] == 0} {
	    interp alias {} ::tablelist::style      {} ::style
	    if {[string compare $::tile::version "0.7"] >= 0} {
		interp alias {} ::tablelist::styleConfig {} ::style configure
	    } else {
		interp alias {} ::tablelist::styleConfig {} ::style default
	    }
	    interp alias {} ::tablelist::getThemes  {} ::tile::availableThemes
	    interp alias {} ::tablelist::setTheme   {} ::tile::setTheme

	    interp alias {} ::tablelist::tileqt_kdeStyleChangeNotification \
			 {} ::tile::theme::tileqt::kdeStyleChangeNotification
	    interp alias {} ::tablelist::tileqt_currentThemeName \
			 {} ::tile::theme::tileqt::currentThemeName
	    interp alias {} ::tablelist::tileqt_currentThemeColour \
			 {} ::tile::theme::tileqt::currentThemeColour
	} else {
	    interp alias {} ::tablelist::style	      {} ::ttk::style
	    interp alias {} ::tablelist::styleConfig  {} ::ttk::style configure
	    interp alias {} ::tablelist::getThemes    {} ::ttk::themes
	    interp alias {} ::tablelist::setTheme     {} ::ttk::setTheme

	    interp alias {} ::tablelist::tileqt_kdeStyleChangeNotification \
			 {} ::ttk::theme::tileqt::kdeStyleChangeNotification
	    interp alias {} ::tablelist::tileqt_currentThemeName \
			 {} ::ttk::theme::tileqt::currentThemeName
	    interp alias {} ::tablelist::tileqt_currentThemeColour \
			 {} ::ttk::theme::tileqt::currentThemeColour
	}
    }
    if {$usingTile} {
	createTileAliases 
    }

    variable pngSupported [expr {($::tk_version >= 8.6 &&
	![regexp {^8\.6(a[1-3]|b1)$} $::tk_patchLevel]) ||
	($::tk_version >= 8.5 && [catch {package require img::png}] == 0)}]

    variable specialAquaHandling [expr {$usingTile && ($::tk_version >= 8.6 ||
	[regexp {^8\.5\.(9|[1-9][0-9])$} $::tk_patchLevel]) &&
	[lsearch -exact [winfo server .] "AppKit"] >= 0}]

    #
    # Get the scaling percentage (100, 125, 150, or 200)
    #
    proc getScalingPercentage {} {
	variable scaling
	set factor [tk scaling]
	if {$factor < 1.4} {
	    set scaling 100 
	} elseif {$factor < 1.7} {
	    set scaling 125 
	} elseif {$factor < 2.1} {
	    set scaling 150 
	} else {
	    set scaling 200
	}
    }
    getScalingPercentage 

    #
    # The array configSpecs is used to handle configuration options.  The
    # names of its elements are the configuration options for the Tablelist
    # class.  The value of an array element is either an alias name or a list
    # containing the database name and class as well as an indicator specifying
    # the widget(s) to which the option applies: c stands for all children
    # (text widgets and labels), b for the body text widget, l for the labels,
    # f for the frame, and w for the widget itself.
    #
    #	Command-Line Name	 {Database Name		  Database Class      W}
    #	------------------------------------------------------------------------
    #
    variable configSpecs
    array set configSpecs {
	-acceptchildcommand	 {acceptChildCommand	  AcceptChildCommand  w}
	-acceptdropcommand	 {acceptDropCommand	  AcceptDropCommand   w}
	-activestyle		 {activeStyle		  ActiveStyle	      w}
	-arrowcolor		 {arrowColor		  ArrowColor	      w}
	-arrowdisabledcolor	 {arrowDisabledColor	  ArrowDisabledColor  w}
	-arrowstyle		 {arrowStyle		  ArrowStyle	      w}
	-autoscan		 {autoScan		  AutoScan	      w}
	-background		 {background		  Background	      b}
	-bg			 -background
	-borderwidth		 {borderWidth		  BorderWidth	      f}
	-bd			 -borderwidth
	-collapsecommand	 {collapseCommand	  CollapseCommand     w}
	-colorizecommand	 {colorizeCommand	  ColorizeCommand     w}
	-columns		 {columns		  Columns	      w}
	-columntitles		 {columnTitles		  ColumnTitles	      w}
	-cursor			 {cursor		  Cursor	      c}
	-customdragsource	 {customDragSource	  CustomDragSource    w}
	-disabledforeground	 {disabledForeground	  DisabledForeground  w}
	-editendcommand		 {editEndCommand	  EditEndCommand      w}
	-editselectedonly	 {editSelectedOnly	  EditSelectedOnly    w}
	-editstartcommand	 {editStartCommand	  EditStartCommand    w}
	-expandcommand		 {expandCommand		  ExpandCommand       w}
	-exportselection	 {exportSelection	  ExportSelection     w}
	-font			 {font			  Font		      b}
	-forceeditendcommand	 {forceEditEndCommand	  ForceEditEndCommand w}
	-foreground		 {foreground		  Foreground	      b}
	-fg			 -foreground
	-fullseparators		 {fullSeparators	  FullSeparators      w}
	-height			 {height		  Height	      w}
	-highlightbackground	 {highlightBackground	  HighlightBackground f}
	-highlightcolor		 {highlightColor	  HighlightColor      f}
	-highlightthickness	 {highlightThickness	  HighlightThickness  f}
	-incrarrowtype		 {incrArrowType		  IncrArrowType	      w}
	-instanttoggle		 {instantToggle		  InstantToggle	      w}
	-labelactivebackground	 {labelActiveBackground	  Foreground	      l}
	-labelactiveforeground	 {labelActiveForeground	  Background	      l}
	-labelbackground	 {labelBackground	  Background	      l}
	-labelbg		 -labelbackground
	-labelborderwidth	 {labelBorderWidth	  BorderWidth	      l}
	-labelbd		 -labelborderwidth
	-labelcommand		 {labelCommand		  LabelCommand	      w}
	-labelcommand2		 {labelCommand2		  LabelCommand2	      w}
	-labeldisabledforeground {labelDisabledForeground DisabledForeground  l}
	-labelfont		 {labelFont		  Font		      l}
	-labelforeground	 {labelForeground	  Foreground	      l}
	-labelfg		 -labelforeground
	-labelheight		 {labelHeight		  Height	      l}
	-labelpady		 {labelPadY		  Pad		      l}
	-labelrelief		 {labelRelief		  Relief	      l}
	-listvariable		 {listVariable		  Variable	      w}
	-movablecolumns	 	 {movableColumns	  MovableColumns      w}
	-movablerows		 {movableRows		  MovableRows	      w}
	-movecolumncursor	 {moveColumnCursor	  MoveColumnCursor    w}
	-movecursor		 {moveCursor		  MoveCursor	      w}
	-populatecommand	 {populateCommand	  PopulateCommand     w}
	-protecttitlecolumns	 {protectTitleColumns	  ProtectTitleColumns w}
	-relief			 {relief		  Relief	      f}
	-resizablecolumns	 {resizableColumns	  ResizableColumns    w}
	-resizecursor		 {resizeCursor		  ResizeCursor	      w}
	-selectbackground	 {selectBackground	  Foreground	      w}
	-selectborderwidth	 {selectBorderWidth	  BorderWidth	      w}
	-selectforeground	 {selectForeground	  Background	      w}
	-selectmode		 {selectMode		  SelectMode	      w}
	-selecttype		 {selectType		  SelectType	      w}
	-setfocus		 {setFocus		  SetFocus	      w}
	-setgrid		 {setGrid		  SetGrid	      w}
	-showarrow		 {showArrow		  ShowArrow	      w}
	-showeditcursor		 {showEditCursor	  ShowEditCursor      w}
	-showhorizseparator	 {showHorizSeparator	  ShowHorizSeparator  w}
	-showlabels		 {showLabels		  ShowLabels	      w}
	-showseparators		 {showSeparators	  ShowSeparators      w}
	-snipstring		 {snipString		  SnipString	      w}
	-sortcommand		 {sortCommand		  SortCommand	      w}
	-spacing		 {spacing		  Spacing	      w}
	-state			 {state			  State		      w}
	-stretch		 {stretch		  Stretch	      w}
	-stripebackground	 {stripeBackground	  Background	      w}
	-stripebg		 -stripebackground
	-stripeforeground	 {stripeForeground	  Foreground	      w}
	-stripefg		 -stripeforeground
	-stripeheight		 {stripeHeight		  StripeHeight	      w}
	-takefocus		 {takeFocus		  TakeFocus	      f}
	-targetcolor		 {targetColor		  TargetColor	      w}
	-tight			 {tight			  Tight		      w}
	-titlecolumns		 {titleColumns	  	  TitleColumns	      w}
	-tooltipaddcommand	 {tooltipAddCommand	  TooltipAddCommand   w}
	-tooltipdelcommand	 {tooltipDelCommand	  TooltipDelCommand   w}
	-treecolumn		 {treeColumn		  TreeColumn	      w}
	-treestyle		 {treeStyle		  TreeStyle	      w}
	-width			 {width			  Width		      w}
	-xscrollcommand		 {xScrollCommand	  ScrollCommand	      w}
	-yscrollcommand		 {yScrollCommand	  ScrollCommand	      w}
    }

    #
    # Extend the elements of the array configSpecs
    #
    extendConfigSpecs 

    variable configOpts [lsort [array names configSpecs]]

    #
    # The array colConfigSpecs is used to handle column configuration options.
    # The names of its elements are the column configuration options for the
    # Tablelist widget class.  The value of an array element is either an alias
    # name or a list containing the database name and class.
    #
    #	Command-Line Name	{Database Name		Database Class	    }
    #	---------------------------------------------------------------------
    #
    variable colConfigSpecs
    array set colConfigSpecs {
	-align			{align			Align		    }
	-background		{background		Background	    }
	-bg			-background
	-changesnipside		{changeSnipSide		ChangeSnipSide	    }
	-changetitlesnipside	{changeTitleSnipSide	ChangeTitleSnipSide }
	-editable		{editable		Editable	    }
	-editwindow		{editWindow		EditWindow	    }
	-font			{font			Font		    }
	-foreground		{foreground		Foreground	    }
	-fg			-foreground
	-formatcommand		{formatCommand		FormatCommand	    }
	-hide			{hide			Hide		    }
	-labelalign		{labelAlign		Align		    }
	-labelbackground	{labelBackground	Background	    }
	-labelbg		-labelbackground
	-labelborderwidth	{labelBorderWidth	BorderWidth	    }
	-labelbd		-labelborderwidth
	-labelcommand		{labelCommand		LabelCommand	    }
	-labelcommand2		{labelCommand2		LabelCommand2	    }
	-labelfont		{labelFont		Font		    }
	-labelforeground	{labelForeground	Foreground	    }
	-labelfg		-labelforeground
	-labelheight		{labelHeight		Height		    }
	-labelimage		{labelImage		Image		    }
	-labelpady		{labelPadY		Pad		    }
	-labelrelief		{labelRelief		Relief		    }
	-maxwidth		{maxWidth		MaxWidth	    }
	-name			{name			Name		    }
	-resizable		{resizable		Resizable	    }
	-selectbackground	{selectBackground	Foreground	    }
	-selectforeground	{selectForeground	Background	    }
	-showarrow		{showArrow		ShowArrow	    }
	-showlinenumbers	{showLineNumbers	ShowLineNumbers	    }
	-sortcommand		{sortCommand		SortCommand	    }
	-sortmode		{sortMode		SortMode	    }
	-stretchable		{stretchable		Stretchable	    }
	-stripebackground	{stripeBackground	Background	    }
	-stripeforeground	{stripeForeground	Foreground	    }
	-text			{text			Text		    }
	-title			{title			Title		    }
	-valign			{valign			Valign		    }
	-width			{width			Width		    }
	-wrap			{wrap			Wrap		    }
    }

    #
    # Extend some elements of the array colConfigSpecs
    #
    lappend colConfigSpecs(-align)			- left
    lappend colConfigSpecs(-changesnipside)		- 0
    lappend colConfigSpecs(-changetitlesnipside)	- 0
    lappend colConfigSpecs(-editable)			- 0
    lappend colConfigSpecs(-editwindow)			- entry
    lappend colConfigSpecs(-hide)			- 0
    lappend colConfigSpecs(-maxwidth)			- 0
    lappend colConfigSpecs(-resizable)			- 1
    lappend colConfigSpecs(-showarrow)			- 1
    lappend colConfigSpecs(-showlinenumbers)		- 0
    lappend colConfigSpecs(-sortmode)			- ascii
    lappend colConfigSpecs(-stretchable)		- 0
    lappend colConfigSpecs(-valign)			- center
    lappend colConfigSpecs(-width)			- 0
    lappend colConfigSpecs(-wrap)			- 0

    if {$usingTile} {
	unset colConfigSpecs(-labelbackground)
	unset colConfigSpecs(-labelbg)
	unset colConfigSpecs(-labelheight)
    }

    #
    # The array rowConfigSpecs is used to handle row configuration options.
    # The names of its elements are the row configuration options for the
    # Tablelist widget class.  The value of an array element is either an alias
    # name or a list containing the database name and class.
    #
    #	Command-Line Name	{Database Name		Database Class	}
    #	-----------------------------------------------------------------
    #
    variable rowConfigSpecs
    array set rowConfigSpecs {
	-background		{background		Background	}
	-bg			-background
	-font			{font			Font		}
	-foreground		{foreground		Foreground	}
	-fg			-foreground
	-hide			{hide			Hide		}
	-name			{name			Name		}
	-selectable		{selectable		Selectable	}
	-selectbackground	{selectBackground	Foreground	}
	-selectforeground	{selectForeground	Background	}
	-text			{text			Text		}
    }

    #
    # Check whether the -elide text widget tag option is available
    #
    variable canElide
    variable elide
    if {$::tk_version >= 8.3} {
	set canElide 1
	set elide -elide
    } else {
	set canElide 0
	set elide --
    }

    #
    # Extend some elements of the array rowConfigSpecs
    #
    if {$canElide} {
	lappend rowConfigSpecs(-hide)	- 0
    } else {
	unset rowConfigSpecs(-hide)
    }
    lappend rowConfigSpecs(-selectable)	- 1

    #
    # The array cellConfigSpecs is used to handle cell configuration options.
    # The names of its elements are the cell configuration options for the
    # Tablelist widget class.  The value of an array element is either an alias
    # name or a list containing the database name and class.
    #
    #	Command-Line Name	{Database Name		Database Class	}
    #	-----------------------------------------------------------------
    #
    variable cellConfigSpecs
    array set cellConfigSpecs {
	-background		{background		Background	}
	-bg			-background
	-editable		{editable		Editable	}
	-editwindow		{editWindow		EditWindow	}
	-font			{font			Font		}
	-foreground		{foreground		Foreground	}
	-fg			-foreground
	-image			{image			Image		}
	-selectbackground	{selectBackground	Foreground	}
	-selectforeground	{selectForeground	Background	}
	-stretchwindow		{stretchWindow		StretchWindow	}
	-text			{text			Text		}
	-valign			{valign			Valign		}
	-window			{window			Window		}
	-windowdestroy		{windowDestroy		WindowDestroy	}
	-windowupdate		{windowUpdate		WindowUpdate	}
    }

    #
    # Extend some elements of the array cellConfigSpecs
    #
    lappend cellConfigSpecs(-editable)		- 0
    lappend cellConfigSpecs(-editwindow)	- entry
    lappend cellConfigSpecs(-stretchwindow)	- 0
    lappend cellConfigSpecs(-valign)		- center

    #
    # Use a list to facilitate the handling of the command options 
    #
    variable cmdOpts [list \
	activate activatecell applysorting attrib bbox bodypath bodytag \
	canceledediting cancelediting cellattrib cellbbox cellcget \
	cellconfigure cellindex cellselection cget childcount childindex \
	childkeys collapse collapseall columnattrib columncget \
	columnconfigure columncount columnindex columnwidth config \
	configcelllist configcells configcolumnlist configcolumns \
	configrowlist configrows configure containing containingcell \
	containingcolumn cornerlabelpath cornerpath curcellselection \
	curselection depth delete deletecolumns descendantcount editcell \
	editinfo editwinpath editwintag entrypath expand expandall \
	expandedkeys fillcolumn findcolumnname findrowname finishediting \
	formatinfo get getcells getcolumns getformatted getformattedcells \
	getformattedcolumns getfullkeys getkeys hasattrib hascellattrib \
	hascolumnattrib hasrowattrib hidetargetmark imagelabelpath index \
	insert insertchild insertchildlist insertchildren insertcolumnlist \
	insertcolumns insertlist iselemsnipped isexpanded istitlesnipped \
	isviewable itemlistvar labelpath labels labeltag move movecolumn \
	nearest nearestcell nearestcolumn noderow parentkey refreshsorting \
	rejectinput resetsortinfo rowattrib rowcget rowconfigure scan \
	searchcolumn see seecell seecolumn selection separatorpath separators \
	showtargetmark size sort sortbycolumn sortbycolumnlist sortcolumn \
	sortcolumnlist sortorder sortorderlist targetmarkpath targetmarkpos \
	togglecolumnhide togglerowhide toplevelkey unsetattrib \
	unsetcellattrib unsetcolumnattrib unsetrowattrib viewablerowcount \
	windowpath xview yview]

    proc restrictCmdOpts {} {
	variable canElide
	if {!$canElide} {
	    variable cmdOpts
	    foreach opt [list collapse collapseall expand expandall \
			 insertchild insertchildlist insertchildren \
			 togglerowhide] {
		set idx [lsearch -exact $cmdOpts $opt]
		set cmdOpts [lreplace $cmdOpts $idx $idx]
	    }
	}
    }
    restrictCmdOpts 

    #
    # Use lists to facilitate the handling of miscellaneous options
    #
    variable activeStyles  [list frame none underline]
    variable alignments    [list left right center]
    variable arrowStyles   [list flat5x3 flat5x4 flat6x4 flat7x4 flat7x5 \
				 flat7x7 flat8x4 flat8x5 flat9x5 flat9x6 \
				 flat11x6 flat15x8 flatAngle7x4 flatAngle7x5 \
				 flatAngle9x5 flatAngle9x6 flatAngle9x7 \
				 flatAngle10x6 flatAngle10x7 photo7x7 \
				 sunken8x7 sunken10x9 sunken12x11]
    variable arrowTypes    [list up down]
    variable colWidthOpts  [list -requested -stretched -total]
    variable curSelOpts    [list -all -nonhidden -viewable]
    variable expCollOpts   [list -fully -partly]
    variable findOpts      [list -descend -parent]
    variable gapTypeOpts   [list -any -horizontal -vertical]
    variable scanOpts      [list mark dragto]
    variable searchOpts    [list -all -backwards -check -descend -exact \
				 -formatted -glob -nocase -not -numeric \
				 -parent -regexp -start]
    variable selectionOpts [list anchor clear includes set]
    variable selectTypes   [list row cell]
    variable targetOpts    [list before inside]
    variable sortModes     [list ascii asciinocase command dictionary \
				 integer real]
    variable sortOpts      [list -increasing -decreasing]
    variable sortOrders    [list increasing decreasing]
    variable states	   [list disabled normal]
    variable treeStyles    [list adwaita ambiance aqua baghira bicolor1 \
				 bicolor2 bicolor3 bicolor4 classic1 classic2 \
				 classic3 classic4 dust dustSand gtk \
				 klearlooks mate mint newWave oxygen1 oxygen2 \
				 phase plain1 plain2 plain3 plain4 plastik \
				 plastique radiance ubuntu ubuntu2 vistaAero \
				 vistaClassic win7Aero win7Classic winnative \
				 winxpBlue winxpOlive winxpSilver yuyo]
    variable valignments   [list center top bottom]

    proc restrictArrowStyles {} {
	variable pngSupported
	if {!$pngSupported} {
	    variable arrowStyles
	    set idx [lsearch -exact $arrowStyles "photo7x7"]
	    set arrowStyles [lreplace $arrowStyles $idx $idx]
	}
    }
    restrictArrowStyles 

    #
    # The array maxIndentDepths holds the current max.
    # indentation depth for every tree style in use
    #
    variable maxIndentDepths

    #
    # Define the command mapTabs, which returns the string obtained by
    # replacing all \t characters in its argument with \\t, as well as
    # the commands strMap and isInteger, needed because the "string map"
    # and "string is" commands were not available in Tcl 8.0 and 8.1.0
    #
    if {[catch {string map {} ""}] == 0} {
	interp alias {} ::tablelist::mapTabs {} string map {"\t" "\\t"}
	interp alias {} ::tablelist::strMap  {} string map
    } else {
	proc mapTabs str {
	    regsub -all "\t" $str "\\t" str
	    return $str
	}

	proc strMap {charMap str} {
	    foreach {key val} $charMap {
		#
		# We will only need this for noncritical key and str values
		#
		regsub -all $key $str $val str
	    }

	    return $str
	}
    }
    if {[catch {string is integer "0"}] == 0} {
	interp alias {} ::tablelist::isInteger {} string is integer -strict
    } else {
	proc isInteger str {
	    return [expr {[catch {format "%d" $str}] == 0}]
	}
    }

    #
    # Define the command genVirtualEvent, needed because the -data option of the
    # "event generate" command was not available in Tk versions earlier than 8.5
    #
    if {[catch {event generate . <<__>> -data ""}] == 0} {
	proc genVirtualEvent {win event userData} {
	    event generate $win $event -data $userData
	}
    } else {
	proc genVirtualEvent {win event userData} {
	    event generate $win $event
	}
    }

    interp alias {} ::tablelist::configSubCmd \
		 {} ::tablelist::configureSubCmd
    interp alias {} ::tablelist::insertchildSubCmd \
		 {} ::tablelist::insertchildrenSubCmd
}

#
# Private procedure creating the default bindings
# ===============================================
#

#------------------------------------------------------------------------------
# tablelist::createBindings
#
# Creates the default bindings for the binding tags Tablelist, TablelistWindow,
# TablelistKeyNav, TablelistBody, TablelistLabel, TablelistSubLabel,
# TablelistArrow, and TablelistEdit.
#------------------------------------------------------------------------------
proc tablelist::createBindings {} {
    #
    # Define some Tablelist class bindings
    #
    bind Tablelist <KeyPress> continue
    bind Tablelist <FocusIn> {
	tablelist::addActiveTag %W
	if {[string compare [focus -lastfor %W] %W] == 0} {
	    if {[winfo exists [%W editwinpath]]} {
		focus [set tablelist::ns%W::data(editFocus)]
	    } else {
		focus [%W bodypath]
	    }
	}
    }
    bind Tablelist <FocusOut>		{ tablelist::removeActiveTag %W }
    bind Tablelist <<TablelistSelect>>	{ event generate %W <<ListboxSelect>> }
    bind Tablelist <Destroy>		{ tablelist::cleanup %W }
    variable usingTile
    if {$usingTile} {
	bind Tablelist <Activate>	{ tablelist::updateCanvases %W }
	bind Tablelist <Deactivate>	{ tablelist::updateCanvases %W }
	bind Tablelist <<ThemeChanged>>	{
	    after idle [list tablelist::updateConfigSpecs %W]
	}
    }

    #
    # Define some TablelistWindow class bindings
    #
    bind TablelistWindow <Destroy>	{ tablelist::cleanupWindow %W }

    #
    # Define the binding tags TablelistKeyNav and TablelistBody
    #
    mwutil::defineKeyNav Tablelist
    defineTablelistBody 

    #
    # Define the virtual events <<Button3>> and <<ShiftButton3>>
    #
    event add <<Button3>> <Button-3>
    event add <<ShiftButton3>> <Shift-Button-3>
    variable winSys
    if {[string compare $winSys "classic"] == 0 ||
	[string compare $winSys "aqua"] == 0} {
	event add <<Button3>> <Control-Button-1>
	event add <<ShiftButton3>> <Shift-Control-Button-1>
    }

    #
    # Define some mouse bindings for the binding tag TablelistLabel
    #
    bind TablelistLabel <Enter>		  { tablelist::labelEnter  %W %X %Y %x }
    bind TablelistLabel <Motion>	  { tablelist::labelEnter  %W %X %Y %x }
    bind TablelistLabel <Leave>		  { tablelist::labelLeave  %W %X %x %y }
    bind TablelistLabel <Button-1>	  { tablelist::labelB1Down %W %x 0 }
    bind TablelistLabel <Shift-Button-1>  { tablelist::labelB1Down %W %x 1 }
    bind TablelistLabel <B1-Motion>	{ tablelist::labelB1Motion %W %X %x %y }
    bind TablelistLabel <B1-Enter>	{ tablelist::labelB1Enter  %W }
    bind TablelistLabel <B1-Leave>	{ tablelist::labelB1Leave  %W %x %y }
    bind TablelistLabel <ButtonRelease-1> { tablelist::labelB1Up   %W %X}
    bind TablelistLabel <<Button3>>	  { tablelist::labelB3Down %W 0 }
    bind TablelistLabel <<ShiftButton3>>  { tablelist::labelB3Down %W 1 }
    bind TablelistLabel <Double-Button-1>	{ tablelist::labelDblB1 %W %x 0}
    bind TablelistLabel <Shift-Double-Button-1> { tablelist::labelDblB1 %W %x 1}

    #
    # Define the binding tags TablelistSubLabel and TablelistArrow
    #
    defineTablelistSubLabel 
    defineTablelistArrow 

    #
    # Define the binding tag TablelistEdit if the file tablelistEdit.tcl exists
    #
    catch {defineTablelistEdit}
}

#
# Public procedure creating a new tablelist widget
# ================================================
#

#------------------------------------------------------------------------------
# tablelist::tablelist
#
# Creates a new tablelist widget whose name is specified as the first command-
# line argument, and configures it according to the options and their values
# given on the command line.  Returns the name of the newly created widget.
#------------------------------------------------------------------------------
proc tablelist::tablelist args {
    variable usingTile
    variable configSpecs
    variable configOpts
    variable canElide

    if {[llength $args] == 0} {
	mwutil::wrongNumArgs "tablelist pathName ?options?"
    }

    #
    # Create a frame of the class Tablelist
    #
    set win [lindex $args 0]
    if {[catch {
	if {$usingTile} {
	    ttk::frame $win -style Frame$win.TFrame -class Tablelist \
			    -height 0 -width 0 -padding 0
	} else {
	    tk::frame $win -class Tablelist -container 0 -height 0 -width 0
	    catch {$win configure -padx 0 -pady 0}
	}
    } result] != 0} {
	return -code error $result
    }

    #
    # Create a namespace within the current one to hold the data of the widget
    #
    namespace eval ns$win {
	#
	# The folowing array holds various data for this widget
	#
	variable data
	array set data {
	    arrowWidth		 10
	    arrowHeight		 9
	    hasListVar		 0
	    isDisabled		 0
	    ownsFocus		 0
	    charWidth		 1
	    hdrPixels		 0
	    activeRow		 0
	    activeCol		 0
	    anchorRow		 0
	    anchorCol		 0
	    seqNum		-1
	    freeKeyList		 {}
	    keyList		 {}
	    itemList		 {}
	    itemCount		 0
	    lastRow		-1
	    colList		 {}
	    colCount		 0
	    lastCol		-1
	    treeCol		 0
	    gotConfigureEvent	 0
	    rightX		 0
	    btmY		 0
	    rowTagRefCount	 0
	    cellTagRefCount	 0
	    imgCount		 0
	    winCount		 0
	    indentCount		 0
	    afterId		 ""
	    labelClicked	 0
	    arrowColList	 {}
	    sortColList		 {}
	    sortOrder		 ""
	    editKey		 ""
	    editRow		-1
	    editCol		-1
	    canceled		 0
	    fmtKey		 ""
	    fmtRow		-1
	    fmtCol		-1
	    prevCell		 ""
	    prevCol		-1
	    forceAdjust		 0
	    fmtCmdFlagList	 {}
	    hasFmtCmds		 0
	    scrlColOffset	 0
	    cellsToReconfig	 {}
	    nonViewableRowCount	 0
	    viewableRowList	 {-1}
	    hiddenColCount	 0
	    root-row		-1
	    root-parent		 ""
	    root-children	 {}
	    keyToRowMapValid	 1
	    searchStartIdx	 0
	    keyBeingExpanded	 ""
	    destroyIdList	 {}
	    justEntered		 0
	    inEditWin		 0
	}

	#
	# The following array is used to hold arbitrary
	# attributes and their values for this widget
	#
	variable attribs
    }

    #
    # Initialize some further components of data
    #
    upvar ::tablelist::ns${win}::data data
    foreach opt $configOpts {
	set data($opt) [lindex $configSpecs($opt) 3]
    }
    if {$usingTile} {
	setThemeDefaults
	variable themeDefaults
	set data(currentTheme) [getCurrentTheme]
	set data(themeDefaults) [array get themeDefaults]
	if {[string compare $data(currentTheme) "tileqt"] == 0} {
	    set data(widgetStyle) [tileqt_currentThemeName]
	    if {[info exists ::env(KDE_SESSION_VERSION)] &&
		[string length $::env(KDE_SESSION_VERSION)] != 0} {
		set data(colorScheme) [getKdeConfigVal "General" "ColorScheme"]
	    } else {
		set data(colorScheme) [getKdeConfigVal "KDE" "colorScheme"]
	    }
	} else {
	    set data(widgetStyle) ""
	    set data(colorScheme) ""
	}
    }
    set data(-titlecolumns)	0		;# for Tk versions < 8.3
    set data(-treecolumn)	0		;# for Tk versions < 8.3
    set data(-treestyle)	""		;# for Tk versions < 8.3
    set data(colFontList)	[list $data(-font)]
    set data(listVarTraceCmd)	[list tablelist::listVarTrace $win]
    set data(bodyTag)		body$win
    set data(labelTag)		label$win
    set data(editwinTag)	editwin$win
    set data(body)		$win.body
    set data(bodyFr)		$data(body).f
    set data(bodyFrEd)		$data(bodyFr).e
    set data(rowGap)		$data(body).g
    set data(hdr)		$win.hdr
    set data(hdrTxt)		$data(hdr).t
    set data(hdrTxtFr)		$data(hdrTxt).f
    set data(hdrTxtFrCanv)	$data(hdrTxtFr).c
    set data(hdrTxtFrLbl)	$data(hdrTxtFr).l
    set data(hdrFr)		$data(hdr).f
    set data(hdrFrLbl)		$data(hdrFr).l
    set data(colGap)		$data(hdr).g
    set data(lb)		$win.lb
    set data(sep)		$win.sep
    set data(hsep)		$win.hsep

    #
    # Get a unique name for the corner frame (a sibling of the tablelist widget)
    #
    set data(corner) $win-corner
    for {set n 2} {[winfo exists $data(corner)]} {incr n} {
	set data(corner) $data(corner)$n
    }
    set data(cornerLbl) $data(corner).l

    #
    # Create a child hierarchy used to hold the column labels.  The
    # labels will be created as children of the frame data(hdrTxtFr),
    # which is embedded into the text widget data(hdrTxt) (in order
    # to make it scrollable), which in turn fills the frame data(hdr)
    # (whose width and height can be set arbitrarily in pixels).
    #

    set w $data(hdr)			;# header frame
    tk::frame $w -borderwidth 0 -container 0 -height 0 -highlightthickness 0 \
		 -relief flat -takefocus 0 -width 0
    catch {$w configure -padx 0 -pady 0}
    bind $w <Configure> {
	set tablelist::W [winfo parent %W]
	tablelist::stretchColumnsWhenIdle $tablelist::W
	tablelist::updateScrlColOffsetWhenIdle $tablelist::W
	tablelist::updateHScrlbarWhenIdle $tablelist::W
    }
    pack $w -fill x

    set w $data(hdrTxt)			;# text widget within the header frame
    text $w -borderwidth 0 -highlightthickness 0 -insertwidth 0 \
	    -padx 0 -pady 0 -state normal -takefocus 0 -wrap none
    place $w -relheight 1.0 -relwidth 1.0
    bindtags $w [lreplace [bindtags $w] 1 1]
    tk::frame $data(hdrTxtFr) -borderwidth 0 -container 0 -height 0 \
			      -highlightthickness 0 -relief flat \
			      -takefocus 0 -width 0
    catch {$data(hdrTxtFr) configure -padx 0 -pady 0}
    $w window create 1.0 -window $data(hdrTxtFr)

    set w $data(hdrFr)			;# filler frame within the header frame
    tk::frame $w -borderwidth 0 -container 0 -height 0 -highlightthickness 0 \
		 -relief flat -takefocus 0 -width 0
    catch {$w configure -padx 0 -pady 0}
    place $w -relheight 1.0 -relwidth 1.0

    set w $data(hdrFrLbl)		;# label within the filler frame
    set x 0
    if {$usingTile} {
	ttk::label $w -style TablelistHeader.TLabel -image "" \
		      -padding {1 1 1 1} -takefocus 0 -text "" \
		      -textvariable "" -underline -1 -wraplength 0
	if {[string compare [getCurrentTheme] "aqua"] == 0} {
	    set x -1
	}
    } else {
	tk::label $w -bitmap "" -highlightthickness 0 -image "" \
		     -takefocus 0 -text "" -textvariable "" -underline -1 \
		     -wraplength 0
    }
    place $w -x $x -relheight 1.0 -relwidth 1.0

    set w $data(corner)			;# corner frame (outside the tablelist)
    tk::frame $w -borderwidth 0 -container 0 -height 0 -highlightthickness 0 \
		 -relief flat -takefocus 0 -width 0
    catch {$w configure -padx 0 -pady 0}

    set w $data(cornerLbl)		;# label within the corner frame
    if {$usingTile} {
	ttk::label $w -style TablelistHeader.TLabel -image "" \
		      -padding {1 1 1 1} -takefocus 0 -text "" \
		      -textvariable "" -underline -1 -wraplength 0
    } else {
	tk::label $w -bitmap "" -highlightthickness 0 -image "" \
		     -takefocus 0 -text "" -textvariable "" -underline -1 \
		     -wraplength 0
    }
    place $w -relheight 1.0 -relwidth 1.0

    #
    # Create the body text widget within the main frame
    #
    set w $data(body)
    text $w -borderwidth 0 -exportselection 0 -highlightthickness 0 \
	    -insertwidth 0 -padx 0 -pady 0 -state normal -takefocus 0 -wrap none
    bind $w <Configure> {
	set tablelist::W [winfo parent %W]
	set tablelist::ns${tablelist::W}::data(gotConfigureEvent) 1
	set tablelist::ns${tablelist::W}::data(rightX) [expr {%w - 1}]
	set tablelist::ns${tablelist::W}::data(btmY) [expr {%h - 1}]
	tablelist::makeColFontAndTagLists $tablelist::W
	tablelist::updateViewWhenIdle $tablelist::W
    }
    pack $w -expand 1 -fill both

    #
    # Modify the list of binding tags of the body text widget
    #
    bindtags $w [list $w $data(bodyTag) TablelistBody [winfo toplevel $w] \
		 TablelistKeyNav all]

    #
    # Create the "stripe", "select", "active", "disabled", "redraw",
    # "hiddenRow", "elidedRow", "hiddenCol", and "elidedCol" tags in the body
    # text widget.  Don't use the built-in "sel" tag because on Windows the
    # selection in a text widget only becomes visible when the window gets
    # the input focus.  DO NOT CHANGE the order of creation of these tags!
    #
    $w tag configure stripe -background "" -foreground ""    ;# will be changed
    $w tag configure select -relief raised
    $w tag configure curRow -borderwidth 1 -relief raised
    $w tag configure active -borderwidth ""		     ;# will be changed
    $w tag configure disabled -foreground ""		     ;# will be changed
    $w tag configure redraw -relief sunken
    if {$canElide} {
	$w tag configure hiddenRow -elide 1	;# used for hiding a row
	$w tag configure elidedRow -elide 1	;# used when collapsing a row
	$w tag configure hiddenCol -elide 1	;# used for hiding a column
	$w tag configure elidedCol -elide 1	;# used for horizontal scrolling
    }
    if {$::tk_version >= 8.5} {
	$w tag configure elidedWin -elide 1	;# used for eliding a window
    }

    #
    # Create two frames used to display a gap between two consecutive
    # rows/columns when moving a row/column interactively
    #
    tk::frame $data(rowGap) -borderwidth 1 -container 0 -highlightthickness 0 \
			    -relief sunken -takefocus 0 -height 4
    tk::frame $data(colGap) -borderwidth 1 -container 0 -highlightthickness 0 \
			    -relief sunken -takefocus 0 -width 4

    #
    # Create an unmanaged listbox child, used to handle the -setgrid option
    #
    listbox $data(lb)

    #
    # Create the bitmaps needed to display the sort ranks
    #
    createSortRankImgs $win

    #
    # Take into account that some scripts start by
    # destroying all children of the root window
    #
    variable helpLabel
    if {![winfo exists $helpLabel]} {
	if {$usingTile} {
	    ttk::label $helpLabel -takefocus 0
	} else {
	    tk::label $helpLabel -takefocus 0
	}
    }

    #
    # Configure the widget according to the command-line
    # arguments and to the available database options
    #
    if {[catch {
	mwutil::configureWidget $win configSpecs tablelist::doConfig \
				tablelist::doCget [lrange $args 1 end] 1
    } result] != 0} {
	destroy $win
	return -code error $result
    }

    #
    # Move the original widget command into the current namespace and
    # create an alias of the original name for a new widget procedure
    #
    rename ::$win $win
    interp alias {} ::$win {} tablelist::tablelistWidgetCmd $win

    #
    # Register a callback to be invoked whenever the PRIMARY
    # selection is owned by the window win and someone
    # attempts to retrieve it as a UTF8_STRING or STRING
    #
    selection handle -type UTF8_STRING $win \
	[list ::tablelist::fetchSelection $win]
    selection handle -type STRING $win \
	[list ::tablelist::fetchSelection $win]

    #
    # Set a trace on the array elements data(activeRow),
    # data(avtiveCol), and data(-selecttype)
    #
    foreach name {activeRow activeCol -selecttype} {
	trace variable data($name) w [list tablelist::activeTrace $win]
    }

    return $win
}

#
# Private procedures implementing the tablelist widget command
# ============================================================
#

#------------------------------------------------------------------------------
# tablelist::tablelistWidgetCmd
#
# Processes the Tcl command corresponding to a tablelist widget.
#------------------------------------------------------------------------------
proc tablelist::tablelistWidgetCmd {win args} {
    if {[llength $args] == 0} {
	mwutil::wrongNumArgs "$win option ?arg arg ...?"
    }

    variable cmdOpts
    set cmd [mwutil::fullOpt "option" [lindex $args 0] $cmdOpts]
    return [${cmd}SubCmd $win [lrange $args 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::activateSubCmd
#------------------------------------------------------------------------------
proc tablelist::activateSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win activate index"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    displayItems $win
    set index [rowIndex $win [lindex $argList 0] 0]

    #
    # Adjust the index to fit within the existing viewable items
    #
    adjustRowIndex $win index 1

    set data(activeRow) $index
    return ""
}

#------------------------------------------------------------------------------
# tablelist::activatecellSubCmd
#------------------------------------------------------------------------------
proc tablelist::activatecellSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win activatecell cellIndex"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    displayItems $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 0] {}

    #
    # Adjust the row and column indices to fit
    # within the existing viewable elements
    #
    adjustRowIndex $win row 1
    adjustColIndex $win col 1

    set data(activeRow) $row
    set data(activeCol) $col
    return ""
}

#------------------------------------------------------------------------------
# tablelist::applysortingSubCmd
#------------------------------------------------------------------------------
proc tablelist::applysortingSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win applysorting itemList"
    }

    return [sortList $win [lindex $argList 0]]
}

#------------------------------------------------------------------------------
# tablelist::attribSubCmd
#------------------------------------------------------------------------------
proc tablelist::attribSubCmd {win argList} {
    return [mwutil::attribSubCmd $win "widget" $argList]
}

#------------------------------------------------------------------------------
# tablelist::bboxSubCmd
#------------------------------------------------------------------------------
proc tablelist::bboxSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win bbox index"
    }

    synchronize $win
    displayItems $win
    set index [rowIndex $win [lindex $argList 0] 0]

    upvar ::tablelist::ns${win}::data data
    set w $data(body)
    set dlineinfo [$w dlineinfo [expr {double($index + 1)}]]
    if {$data(itemCount) == 0 || [llength $dlineinfo] == 0} {
	return {}
    }

    set spacing1 [$w cget -spacing1]
    set spacing3 [$w cget -spacing3]
    foreach {x y width height baselinePos} $dlineinfo {}
    incr height -[expr {$spacing1 + $spacing3}]
    if {$height < 0} {
	set height 0
    }
    return [list [expr {$x + [winfo x $w]}] \
		 [expr {$y + [winfo y $w] + $spacing1}] $width $height]
}

#------------------------------------------------------------------------------
# tablelist::bodypathSubCmd
#------------------------------------------------------------------------------
proc tablelist::bodypathSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win bodypath"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(body)
}

#------------------------------------------------------------------------------
# tablelist::bodytagSubCmd
#------------------------------------------------------------------------------
proc tablelist::bodytagSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win bodytag"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(bodyTag)
}

#------------------------------------------------------------------------------
# tablelist::cancelededitingSubCmd
#------------------------------------------------------------------------------
proc tablelist::cancelededitingSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win canceledediting"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(canceled)
}

#------------------------------------------------------------------------------
# tablelist::canceleditingSubCmd
#------------------------------------------------------------------------------
proc tablelist::canceleditingSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win cancelediting"
    }

    synchronize $win
    return [doCancelEditing $win]
}

#------------------------------------------------------------------------------
# tablelist::cellattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::cellattribSubCmd {win argList} {
    if {[llength $argList] < 1} {
	mwutil::wrongNumArgs "$win cellattrib cellIndex ?name? ?value\
			      name value ...?"
    }

    synchronize $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 1] {}
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    return [mwutil::attribSubCmd $win $key,$col [lrange $argList 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::cellbboxSubCmd
#------------------------------------------------------------------------------
proc tablelist::cellbboxSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win cellbbox cellIndex"
    }

    synchronize $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 0] {}
    upvar ::tablelist::ns${win}::data data
    if {$row < 0 || $row > $data(lastRow) ||
	$col < 0 || $col > $data(lastCol)} {
	return {}
    }

    foreach {x y width height} [bboxSubCmd $win $row] {}
    set w $data(hdrTxtFrLbl)$col
    return [list [expr {[winfo rootx $w] - [winfo rootx $win]}] $y \
		 [winfo width $w] $height]
}

#------------------------------------------------------------------------------
# tablelist::cellcgetSubCmd
#------------------------------------------------------------------------------
proc tablelist::cellcgetSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win cellcget cellIndex option"
    }

    synchronize $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 1] {}
    variable cellConfigSpecs
    set opt [mwutil::fullConfigOpt [lindex $argList 1] cellConfigSpecs]
    return [doCellCget $row $col $win $opt]
}

#------------------------------------------------------------------------------
# tablelist::cellconfigureSubCmd
#------------------------------------------------------------------------------
proc tablelist::cellconfigureSubCmd {win argList} {
    if {[llength $argList] < 1} {
	mwutil::wrongNumArgs "$win cellconfigure cellIndex ?option? ?value\
			      option value ...?"
    }

    synchronize $win
    displayItems $win
    variable cellConfigSpecs
    foreach {row col} [cellIndex $win [lindex $argList 0] 1] {}
    return [mwutil::configureSubCmd $win cellConfigSpecs \
	    "tablelist::doCellConfig $row $col" \
	    "tablelist::doCellCget $row $col" [lrange $argList 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::cellindexSubCmd
#------------------------------------------------------------------------------
proc tablelist::cellindexSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win cellindex cellIndex"
    }

    synchronize $win
    return [join [cellIndex $win [lindex $argList 0] 0] ","]
}

#------------------------------------------------------------------------------
# tablelist::cellselectionSubCmd
#------------------------------------------------------------------------------
proc tablelist::cellselectionSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 2 || $argCount > 3} {
	mwutil::wrongNumArgs \
		"$win cellselection option firstCellIndex lastCellIndex" \
		"$win cellselection option cellIndexList"
    }

    synchronize $win
    displayItems $win
    variable selectionOpts
    set opt [mwutil::fullOpt "option" [lindex $argList 0] $selectionOpts]
    set first [lindex $argList 1]

    switch $opt {
	anchor -
	includes {
	    if {$argCount != 2} {
		mwutil::wrongNumArgs "$win cellselection $opt cellIndex"
	    }
	    foreach {row col} [cellIndex $win $first 0] {}
	    return [cellSelection $win $opt $row $col $row $col]
	}

	clear -
	set {
	    if {$argCount == 2} {
		foreach elem $first {
		    foreach {row col} [cellIndex $win $elem 0] {}
		    cellSelection $win $opt $row $col $row $col
		}
	    } else {
		foreach {firstRow firstCol} [cellIndex $win $first 0] {}
		foreach {lastRow lastCol} \
			[cellIndex $win [lindex $argList 2] 0] {}
		cellSelection $win $opt $firstRow $firstCol $lastRow $lastCol
	    }

	    updateColors $win
	    invokeMotionHandler $win
	    return ""
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::cgetSubCmd
#------------------------------------------------------------------------------
proc tablelist::cgetSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win cget option"
    }

    #
    # Return the value of the specified configuration option
    #
    variable configSpecs
    set opt [mwutil::fullConfigOpt [lindex $argList 0] configSpecs]
    return [doCget $win $opt]
}

#------------------------------------------------------------------------------
# tablelist::childcountSubCmd
#------------------------------------------------------------------------------
proc tablelist::childcountSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win childcount nodeIndex"
    }

    synchronize $win
    set key [nodeIndexToKey $win [lindex $argList 0]]
    upvar ::tablelist::ns${win}::data data
    return [llength $data($key-children)]
}

#------------------------------------------------------------------------------
# tablelist::childindexSubCmd
#------------------------------------------------------------------------------
proc tablelist::childindexSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win childindex index"
    }

    synchronize $win
    set row [rowIndex $win [lindex $argList 0] 0 1]
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    set parentKey $data($key-parent)
    return [lsearch -exact $data($parentKey-children) $key]
}

#------------------------------------------------------------------------------
# tablelist::childkeysSubCmd
#------------------------------------------------------------------------------
proc tablelist::childkeysSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win childkeys nodeIndex"
    }

    synchronize $win
    set key [nodeIndexToKey $win [lindex $argList 0]]
    upvar ::tablelist::ns${win}::data data
    return $data($key-children)
}

#------------------------------------------------------------------------------
# tablelist::collapseSubCmd
#------------------------------------------------------------------------------
proc tablelist::collapseSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win collapse index ?-fully|-partly?"
    }

    synchronize $win
    displayItems $win
    set index [rowIndex $win [lindex $argList 0] 0 1]

    if {$argCount == 1} {
	set fullCollapsion 1
    } else {
	variable expCollOpts
	set opt [mwutil::fullOpt "option" [lindex $argList 1] $expCollOpts]
	set fullCollapsion [expr {[string compare $opt "-fully"] == 0}]
    }

    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $index]
    set col $data(treeCol)
    if {![info exists data($key,$col-indent)]} {
	return ""
    }

    if {[string length $data(-collapsecommand)] != 0} {
	uplevel #0 $data(-collapsecommand) [list $win $index]
    }

    #
    # Set the indentation image to the collapsed one
    #
    set data($key,$col-indent) [strMap \
	{"indented" "collapsed" "expanded" "collapsed"} $data($key,$col-indent)]
    if {[winfo exists $data(body).ind_$key,$col]} {
	$data(body).ind_$key,$col configure -image $data($key,$col-indent)
    }

    if {[llength $data($key-children)] == 0} {
	return ""
    }

    #
    # Elide the descendants of this item
    #
    set fromRow [expr {$index + 1}]
    set toRow [nodeRow $win $key end]
    for {set row $fromRow} {$row < $toRow} {incr row} {
	doRowConfig $row $win -elide 1

	if {$fullCollapsion} {
	    set descKey [lindex $data(keyList) $row]
	    if {[llength $data($descKey-children)] != 0} {
		collapseSubCmd $win [list [keyToRow $win $descKey] -fully]
	    }
	}
    }

    set callerProc [lindex [info level -1] 0]
    if {![string match "collapse*SubCmd" $callerProc]} {
	#
	# Destroy the label and messsage widgets
	# embedded into the descendants just elided
	#
	set widgets {}
	set fromTextIdx [expr {double($fromRow + 1)}]
	set toTextIdx [expr {double($toRow + 1)}]
	foreach {dummy path textIdx} \
		[$data(body) dump -window $fromTextIdx $toTextIdx] {
	    if {[string length $path] != 0} {
		set class [winfo class $path]
		if {[string compare $class "Label"] == 0 ||
		    [string compare $class "Message"] == 0} {
		    lappend widgets $path
		}
	    }
	}
	set destroyId [after 300 [list tablelist::destroyWidgets $win]]
	lappend data(destroyIdList) $destroyId
	set data(widgets-$destroyId) $widgets

	adjustRowIndex $win data(anchorRow) 1

	set activeRow $data(activeRow)
	adjustRowIndex $win activeRow 1
	set data(activeRow) $activeRow

	makeStripes $win
	adjustElidedText $win
	redisplayVisibleItems $win
	updateColors $win
	adjustSepsWhenIdle $win
	updateVScrlbarWhenIdle $win
    }

    return ""
}

#------------------------------------------------------------------------------
# tablelist::collapseallSubCmd
#------------------------------------------------------------------------------
proc tablelist::collapseallSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount > 1} {
	mwutil::wrongNumArgs "$win collapseall ?-fully|-partly?"
    }

    if {$argCount == 0} {
	set fullCollapsion 1
    } else {
	variable expCollOpts
	set opt [mwutil::fullOpt "option" [lindex $argList 0] $expCollOpts]
	set fullCollapsion [expr {[string compare $opt "-fully"] == 0}]
    }

    synchronize $win
    displayItems $win

    upvar ::tablelist::ns${win}::data data
    set col $data(treeCol)

    if {[winfo viewable $win]} {
	purgeWidgets $win
	update idletasks
	if {![array exists ::tablelist::ns${win}::data]} {
	    return ""
	}
    }

    set childIdx 0
    set childCount [llength $data(root-children)]
    foreach key $data(root-children) {
	if {![info exists data($key,$col-indent)]} {
	    incr childIdx
	    continue
	}

	if {[string length $data(-collapsecommand)] != 0} {
	    uplevel #0 $data(-collapsecommand) [list $win [keyToRow $win $key]]
	}

	#
	# Change the indentation image from the expanded to the collapsed one
	#
	set data($key,$col-indent) \
	    [strMap {"expanded" "collapsed"} $data($key,$col-indent)]
	if {[winfo exists $data(body).ind_$key,$col]} {
	    $data(body).ind_$key,$col configure -image $data($key,$col-indent)
	}

	#
	# Elide the descendants of this item
	#
	incr childIdx
	if {[llength $data($key-children)] != 0} {
	    set fromRow [expr {[keyToRow $win $key] + 1}]
	    if {$childIdx < $childCount} {
		set nextChildKey [lindex $data(root-children) $childIdx]
		set toRow [keyToRow $win $nextChildKey]
	    } else {
		set toRow $data(itemCount)
	    }
	    for {set row $fromRow} {$row < $toRow} {incr row} {
		doRowConfig $row $win -elide 1

		if {$fullCollapsion} {
		    set descKey [lindex $data(keyList) $row]
		    if {[llength $data($descKey-children)] != 0} {
			collapseSubCmd $win \
			    [list [keyToRow $win $descKey] -fully]
		    }
		}
	    }

	    #
	    # Destroy the label and messsage widgets
	    # embedded into the descendants just elided
	    #
	    set widgets {}
	    set fromTextIdx [expr {double($fromRow + 1)}]
	    set toTextIdx [expr {double($toRow + 1)}]
	    foreach {dummy path textIdx} \
		    [$data(body) dump -window $fromTextIdx $toTextIdx] {
		if {[string length $path] != 0} {
		    set class [winfo class $path]
		    if {[string compare $class "Label"] == 0 ||
			[string compare $class "Message"] == 0} {
			lappend widgets $path
		    }
		}
	    }
	    set destroyId [after 300 [list tablelist::destroyWidgets $win]]
	    lappend data(destroyIdList) $destroyId
	    set data(widgets-$destroyId) $widgets
	}
    }

    adjustRowIndex $win data(anchorRow) 1

    set activeRow $data(activeRow)
    adjustRowIndex $win activeRow 1
    set data(activeRow) $activeRow

    makeStripes $win
    adjustElidedText $win
    redisplayVisibleItems $win
    updateColors $win
    adjustSepsWhenIdle $win
    updateVScrlbarWhenIdle $win
    return ""
}

#------------------------------------------------------------------------------
# tablelist::columnattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::columnattribSubCmd {win argList} {
    if {[llength $argList] < 1} {
	mwutil::wrongNumArgs "$win columnattrib columnIndex ?name? ?value\
			      name value ...?"
    }

    set col [colIndex $win [lindex $argList 0] 1]
    return [mwutil::attribSubCmd $win $col [lrange $argList 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::columncgetSubCmd
#------------------------------------------------------------------------------
proc tablelist::columncgetSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win columncget columnIndex option"
    }

    set col [colIndex $win [lindex $argList 0] 1]
    variable colConfigSpecs
    set opt [mwutil::fullConfigOpt [lindex $argList 1] colConfigSpecs]
    return [doColCget $col $win $opt]
}

#------------------------------------------------------------------------------
# tablelist::columnconfigureSubCmd
#------------------------------------------------------------------------------
proc tablelist::columnconfigureSubCmd {win argList} {
    if {[llength $argList] < 1} {
	mwutil::wrongNumArgs "$win columnconfigure columnIndex ?option? ?value\
			      option value ...?"
    }

    synchronize $win
    displayItems $win
    variable colConfigSpecs
    set col [colIndex $win [lindex $argList 0] 1]
    return [mwutil::configureSubCmd $win colConfigSpecs \
	    "tablelist::doColConfig $col" "tablelist::doColCget $col" \
	    [lrange $argList 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::columncountSubCmd
#------------------------------------------------------------------------------
proc tablelist::columncountSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win columncount"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(colCount)
}

#------------------------------------------------------------------------------
# tablelist::columnindexSubCmd
#------------------------------------------------------------------------------
proc tablelist::columnindexSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win columnindex columnIndex"
    }

    return [colIndex $win [lindex $argList 0] 0]
}

#------------------------------------------------------------------------------
# tablelist::columnwidthSubCmd
#------------------------------------------------------------------------------
proc tablelist::columnwidthSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win columnwidth columnIndex\
			      ?-requested|-stretched|-total?"
    }

    synchronize $win
    set col [colIndex $win [lindex $argList 0] 1]
    if {$argCount == 1} {
	set opt -requested
    } else {
	variable colWidthOpts
	set opt [mwutil::fullOpt "option" [lindex $argList 1] $colWidthOpts]
    }

    return [colWidth $win $col $opt]
}

#------------------------------------------------------------------------------
# tablelist::configcelllistSubCmd
#------------------------------------------------------------------------------
proc tablelist::configcelllistSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win configcelllist cellConfigSpecList"
    }

    return [configcellsSubCmd $win [lindex $argList 0]]
}

#------------------------------------------------------------------------------
# tablelist::configcellsSubCmd
#------------------------------------------------------------------------------
proc tablelist::configcellsSubCmd {win argList} {
    synchronize $win
    displayItems $win
    variable cellConfigSpecs

    set argCount [llength $argList]
    foreach {cell opt val} $argList {
	if {$argCount == 1} {
	    return -code error "option and value for \"$cell\" missing"
	} elseif {$argCount == 2} {
	    return -code error "value for \"$opt\" missing"
	}
	foreach {row col} [cellIndex $win $cell 1] {}
	mwutil::configureWidget $win cellConfigSpecs \
		"tablelist::doCellConfig $row $col" \
		"tablelist::doCellCget $row $col" [list $opt $val] 0
	incr argCount -3
    }

    return ""
}

#------------------------------------------------------------------------------
# tablelist::configcolumnlistSubCmd
#------------------------------------------------------------------------------
proc tablelist::configcolumnlistSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win configcolumnlist columnConfigSpecList"
    }

    return [configcolumnsSubCmd $win [lindex $argList 0]]
}

#------------------------------------------------------------------------------
# tablelist::configcolumnsSubCmd
#------------------------------------------------------------------------------
proc tablelist::configcolumnsSubCmd {win argList} {
    synchronize $win
    displayItems $win
    variable colConfigSpecs

    set argCount [llength $argList]
    foreach {col opt val} $argList {
	if {$argCount == 1} {
	    return -code error "option and value for \"$col\" missing"
	} elseif {$argCount == 2} {
	    return -code error "value for \"$opt\" missing"
	}
	set col [colIndex $win $col 1]
	mwutil::configureWidget $win colConfigSpecs \
		"tablelist::doColConfig $col" "tablelist::doColCget $col" \
		[list $opt $val] 0
	incr argCount -3
    }

    return ""
}

#------------------------------------------------------------------------------
# tablelist::configrowlistSubCmd
#------------------------------------------------------------------------------
proc tablelist::configrowlistSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win configrowlist rowConfigSpecList"
    }

    return [configrowsSubCmd $win [lindex $argList 0]]
}

#------------------------------------------------------------------------------
# tablelist::configrowsSubCmd
#------------------------------------------------------------------------------
proc tablelist::configrowsSubCmd {win argList} {
    synchronize $win
    displayItems $win
    variable rowConfigSpecs

    set argCount [llength $argList]
    foreach {rowSpec opt val} $argList {
	if {$argCount == 1} {
	    return -code error "option and value for \"$rowSpec\" missing"
	} elseif {$argCount == 2} {
	    return -code error "value for \"$opt\" missing"
	}
	set row [rowIndex $win $rowSpec 0 1]
	mwutil::configureWidget $win rowConfigSpecs \
		"tablelist::doRowConfig $row" "tablelist::doRowCget $row" \
		[list $opt $val] 0
	incr argCount -3
    }

    return ""
}

#------------------------------------------------------------------------------
# tablelist::configureSubCmd
#------------------------------------------------------------------------------
proc tablelist::configureSubCmd {win argList} {
    variable configSpecs
    return [mwutil::configureSubCmd $win configSpecs tablelist::doConfig \
	    tablelist::doCget $argList]
}

#------------------------------------------------------------------------------
# tablelist::containingSubCmd
#------------------------------------------------------------------------------
proc tablelist::containingSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win containing y"
    }

    set y [format "%d" [lindex $argList 0]]
    synchronize $win
    displayItems $win
    return [containingRow $win $y]
}

#------------------------------------------------------------------------------
# tablelist::containingcellSubCmd
#------------------------------------------------------------------------------
proc tablelist::containingcellSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win containingcell x y"
    }

    set x [format "%d" [lindex $argList 0]]
    set y [format "%d" [lindex $argList 1]]
    synchronize $win
    displayItems $win
    return [containingRow $win $y],[containingCol $win $x]
}

#------------------------------------------------------------------------------
# tablelist::containingcolumnSubCmd
#------------------------------------------------------------------------------
proc tablelist::containingcolumnSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win containingcolumn x"
    }

    set x [format "%d" [lindex $argList 0]]
    synchronize $win
    displayItems $win
    return [containingCol $win $x]
}

#------------------------------------------------------------------------------
# tablelist::cornerlabelpathSubCmd
#------------------------------------------------------------------------------
proc tablelist::cornerlabelpathSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win cornerlabelpath"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(cornerLbl)
}

#------------------------------------------------------------------------------
# tablelist::cornerpathSubCmd
#------------------------------------------------------------------------------
proc tablelist::cornerpathSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win cornerpath"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(corner)
}

#------------------------------------------------------------------------------
# tablelist::curcellselectionSubCmd
#------------------------------------------------------------------------------
proc tablelist::curcellselectionSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount > 1} {
	mwutil::wrongNumArgs "$win curcellselection\
			      ?-all|-nonhidden||-viewable?"
    }

    if {$argCount == 0} {
	set constraint 0
    } else {
	variable curSelOpts
	set opt [mwutil::fullOpt "option" [lindex $argList 0] $curSelOpts]
	set constraint [lsearch -exact $curSelOpts $opt]
    }
    

    synchronize $win
    displayItems $win
    return [curCellSelection $win 0 $constraint]
}

#------------------------------------------------------------------------------
# tablelist::curselectionSubCmd
#------------------------------------------------------------------------------
proc tablelist::curselectionSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount > 1} {
	mwutil::wrongNumArgs "$win curselection\
			      ?-all|-nonhidden||-viewable?"
    }

    if {$argCount == 0} {
	set constraint 0
    } else {
	variable curSelOpts
	set opt [mwutil::fullOpt "option" [lindex $argList 0] $curSelOpts]
	set constraint [lsearch -exact $curSelOpts $opt]
    }

    synchronize $win
    displayItems $win
    return [curSelection $win $constraint]
}

#------------------------------------------------------------------------------
# tablelist::deleteSubCmd
#------------------------------------------------------------------------------
proc tablelist::deleteSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win delete firstIndex lastIndex" \
			     "$win delete indexList"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    displayItems $win
    set first [lindex $argList 0]

    if {$argCount == 1} {
	if {[llength $first] == 1} {			;# just to save time
	    set index [rowIndex $win [lindex $first 0] 0]
	    return [deleteRows $win $index $index $data(hasListVar)]
	} elseif {$data(itemCount) == 0} {		;# no items present
	    return ""
	} else {					;# a bit more work
	    #
	    # Sort the numerical equivalents of the
	    # specified indices in decreasing order
	    #
	    set indexList {}
	    foreach elem $first {
		set index [rowIndex $win $elem 0]
		if {$index < 0} {
		    set index 0
		} elseif {$index > $data(lastRow)} {
		    set index $data(lastRow)
		}
		lappend indexList $index
	    }
	    set indexList [lsort -integer -decreasing $indexList]

	    #
	    # Traverse the sorted index list and ignore any duplicates
	    #
	    set prevIndex -1
	    foreach index $indexList {
		if {$index != $prevIndex} {
		    deleteRows $win $index $index $data(hasListVar)
		    set prevIndex $index
		}
	    }
	    return ""
	}
    } else {
	set first [rowIndex $win $first 0]
	set last [rowIndex $win [lindex $argList 1] 0]
	return [deleteRows $win $first $last $data(hasListVar)]
    }
}

#------------------------------------------------------------------------------
# tablelist::deletecolumnsSubCmd
#------------------------------------------------------------------------------
proc tablelist::deletecolumnsSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs \
		"$win deletecolumns firstColumnIndex lastColumnIndex" \
		"$win deletecolumns columnIndexList"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    displayItems $win
    set first [lindex $argList 0]

    if {$argCount == 1} {
	if {[llength $first] == 1} {			;# just to save time
	    set col [colIndex $win [lindex $first 0] 1]
	    set selCells [curCellSelection $win]
	    deleteCols $win $col $col selCells
	    redisplay $win 0 $selCells
	} elseif {$data(colCount) == 0} {		;# no columns present
	    return ""
	} else {					;# a bit more work
	    #
	    # Sort the numerical equivalents of the
	    # specified column indices in decreasing order
	    #
	    set colList {}
	    foreach elem $first {
		lappend colList [colIndex $win $elem 1]
	    }
	    set colList [lsort -integer -decreasing $colList]

	    #
	    # Traverse the sorted column index list and ignore any duplicates
	    #
	    set selCells [curCellSelection $win]
	    set deleted 0
	    set prevCol -1
	    foreach col $colList {
		if {$col != $prevCol} {
		    deleteCols $win $col $col selCells
		    set deleted 1
		    set prevCol $col
		}
	    }
	    if {$deleted} {
		redisplay $win 0 $selCells
	    }
	}
    } else {
	set first [colIndex $win $first 1]
	set last [colIndex $win [lindex $argList 1] 1]
	if {$first <= $last} {
	    set selCells [curCellSelection $win]
	    deleteCols $win $first $last selCells
	    redisplay $win 0 $selCells
	}
    }

    updateViewWhenIdle $win
    return ""
}

#------------------------------------------------------------------------------
# tablelist::depthSubCmd
#------------------------------------------------------------------------------
proc tablelist::depthSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win depth nodeIndex"
    }

    synchronize $win
    set key [nodeIndexToKey $win [lindex $argList 0]]
    return [depth $win $key]
}

#------------------------------------------------------------------------------
# tablelist::descendantcountSubCmd
#------------------------------------------------------------------------------
proc tablelist::descendantcountSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win descendantcount nodeIndex"
    }

    synchronize $win
    set key [nodeIndexToKey $win [lindex $argList 0]]
    return [descCount $win $key]
}

#------------------------------------------------------------------------------
# tablelist::editcellSubCmd
#------------------------------------------------------------------------------
proc tablelist::editcellSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win editcell cellIndex"
    }

    synchronize $win
    displayItems $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 1] {}
    return [doEditCell $win $row $col 0]
}

#------------------------------------------------------------------------------
# tablelist::editinfoSubCmd
#------------------------------------------------------------------------------
proc tablelist::editinfoSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win editinfo"
    }

    upvar ::tablelist::ns${win}::data data
    return [list $data(editKey) $data(editRow) $data(editCol)]
}

#------------------------------------------------------------------------------
# tablelist::editwinpathSubCmd
#------------------------------------------------------------------------------
proc tablelist::editwinpathSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win editwinpath"
    }

    upvar ::tablelist::ns${win}::data data
    if {[winfo exists $data(bodyFrEd)]} {
	return $data(bodyFrEd)
    } else {
	return ""
    }
}

#------------------------------------------------------------------------------
# tablelist::editwintagSubCmd
#------------------------------------------------------------------------------
proc tablelist::editwintagSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win editwintag"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(editwinTag)
}

#------------------------------------------------------------------------------
# tablelist::entrypathSubCmd
#------------------------------------------------------------------------------
proc tablelist::entrypathSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win entrypath"
    }

    upvar ::tablelist::ns${win}::data data
    if {[winfo exists $data(bodyFrEd)]} {
	set class [winfo class $data(bodyFrEd)]
	if {[regexp {^(Mentry|T?Checkbutton|T?Menubutton)$} $class]} {
	    return ""
	} else {
	    return $data(editFocus)
	}
    } else {
	return ""
    }
}

#------------------------------------------------------------------------------
# tablelist::expandSubCmd
#------------------------------------------------------------------------------
proc tablelist::expandSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win expand index ?-fully|-partly?"
    }

    synchronize $win
    displayItems $win
    set index [rowIndex $win [lindex $argList 0] 0 1]

    if {$argCount == 1} {
	set fullExpansion 1
    } else {
	variable expCollOpts
	set opt [mwutil::fullOpt "option" [lindex $argList 1] $expCollOpts]
	set fullExpansion [expr {[string compare $opt "-fully"] == 0}]
    }

    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $index]
    set col $data(treeCol)
    if {![info exists data($key,$col-indent)] ||
	[string match "*indented*" $data($key,$col-indent)]} {
	return ""
    }

    set callerProc [lindex [info level -1] 0]
    if {[string compare $callerProc "doRowConfig"] != 0 &&
	[string length $data(-expandcommand)] != 0} {
	set data(keyBeingExpanded) $key
	uplevel #0 $data(-expandcommand) [list $win $index]
	set data(keyBeingExpanded) ""
    }

    #
    # Set the indentation image to the indented or expanded one
    #
    set childCount [llength $data($key-children)]
    set state [expr {($childCount == 0) ? "indented" : "expanded"}]
    set data($key,$col-indent) [strMap \
	[list "collapsed" $state "expanded" $state] $data($key,$col-indent)]
    if {[string compare $state "indented"] == 0} {
	set data($key,$col-indent) [strMap \
	    {"Act" "" "Sel" ""} $data($key,$col-indent)]
    }
    if {[winfo exists $data(body).ind_$key,$col]} {
	$data(body).ind_$key,$col configure -image $data($key,$col-indent)
    }

    #
    # Unelide the children if appropriate and
    # invoke this procedure recursively on them
    #
    set isViewable [expr {![info exists data($key-elide)] &&
			  ![info exists data($key-hide)]}]
    foreach childKey $data($key-children) {
	set childRow [keyToRow $win $childKey]
	if {$isViewable} {
	    doRowConfig $childRow $win -elide 0
	}
	if {$fullExpansion} {
	    expandSubCmd $win [list $childRow -fully]
	} elseif {[string match "*expanded*" $data($childKey,$col-indent)]} {
	    expandSubCmd $win [list $childRow -partly]
	}
    }

    if {![string match "expand*SubCmd" $callerProc]} {
	makeStripes $win
	adjustElidedText $win
	redisplayVisibleItems $win
	updateColors $win
	adjustSepsWhenIdle $win
	updateVScrlbarWhenIdle $win
    }

    return ""
}

#------------------------------------------------------------------------------
# tablelist::expandallSubCmd
#------------------------------------------------------------------------------
proc tablelist::expandallSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount > 1} {
	mwutil::wrongNumArgs "$win expandall ?-fully|-partly?"
    }

    if {$argCount == 0} {
	set fullExpansion 1
    } else {
	variable expCollOpts
	set opt [mwutil::fullOpt "option" [lindex $argList 0] $expCollOpts]
	set fullExpansion [expr {[string compare $opt "-fully"] == 0}]
    }

    synchronize $win
    displayItems $win

    upvar ::tablelist::ns${win}::data data
    set col $data(treeCol)

    foreach key $data(root-children) {
	if {![info exists data($key,$col-indent)] ||
	    [string match "*indented*" $data($key,$col-indent)]} {
	    continue
	}

	if {[string length $data(-expandcommand)] != 0} {
	    set data(keyBeingExpanded) $key
	    uplevel #0 $data(-expandcommand) [list $win [keyToRow $win $key]]
	    set data(keyBeingExpanded) ""
	}

	#
	# Set the indentation image to the indented or expanded one
	#
	set childCount [llength $data($key-children)]
	set state [expr {($childCount == 0) ? "indented" : "expanded"}]
	set data($key,$col-indent) [strMap \
	    [list "collapsed" $state "expanded" $state] $data($key,$col-indent)]
	if {[string compare $state "indented"] == 0} {
	    set data($key,$col-indent) [strMap \
		{"Act" "" "Sel" ""} $data($key,$col-indent)]
	}
	if {[winfo exists $data(body).ind_$key,$col]} {
	    $data(body).ind_$key,$col configure -image $data($key,$col-indent)
	}

	#
	# Unelide the children and invoke expandSubCmd on them
	#
	foreach childKey $data($key-children) {
	    set childRow [keyToRow $win $childKey]
	    doRowConfig $childRow $win -elide 0
	    if {$fullExpansion} {
		expandSubCmd $win [list $childRow -fully]
	    } elseif {[string match "*expanded*" \
		       $data($childKey,$col-indent)]} {
		expandSubCmd $win [list $childRow -partly]
	    }
	}
    }

    makeStripes $win
    adjustElidedText $win
    redisplayVisibleItems $win
    updateColors $win
    adjustSepsWhenIdle $win
    updateVScrlbarWhenIdle $win
    return ""
}

#------------------------------------------------------------------------------
# tablelist::expandedkeysSubCmd
#------------------------------------------------------------------------------
proc tablelist::expandedkeysSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win expandedkeys"
    }

    upvar ::tablelist::ns${win}::data data
    set result {}
    foreach name [array names data "*,$data(treeCol)-indent"] {
	if {[string match "tablelist_*_expanded*Img*" $data($name)]} {
	    set commaPos [string first "," $name]
	    lappend result [string range $name 0 [expr {$commaPos - 1}]]
	}
    }
    return $result
}

#------------------------------------------------------------------------------
# tablelist::fillcolumnSubCmd
#------------------------------------------------------------------------------
proc tablelist::fillcolumnSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win fillcolumn columnIndex text"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    displayItems $win
    set colIdx [colIndex $win [lindex $argList 0] 1]
    set text [lindex $argList 1]

    #
    # Update the item list
    #
    set newItemList {}
    foreach item $data(itemList) {
	set item [lreplace $item $colIdx $colIdx $text]
	lappend newItemList $item
    }
    set data(itemList) $newItemList

    #
    # Update the list variable if present
    #
    condUpdateListVar $win

    #
    # Adjust the columns and make sure the specified
    # column will be redisplayed at idle time
    #
    adjustColumns $win $colIdx 1
    redisplayColWhenIdle $win $colIdx
    updateViewWhenIdle $win
    return ""
}

#------------------------------------------------------------------------------
# tablelist::findcolumnnameSubCmd
#------------------------------------------------------------------------------
proc tablelist::findcolumnnameSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win findcolumnname name"
    }

    set name [lindex $argList 0]
    set nameIsEmpty [expr {[string length $name] == 0}]

    upvar ::tablelist::ns${win}::data data
    for {set col 0} {$col < $data(colCount)} {incr col} {
	set hasName [info exists data($col-name)]
	if {($hasName && [string compare $name $data($col-name)] == 0) ||
	    (!$hasName && $nameIsEmpty)} {
	    return $col
	}
    }

    return -1
}

#------------------------------------------------------------------------------
# tablelist::findrownameSubCmd
#------------------------------------------------------------------------------
proc tablelist::findrownameSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1} {
	mwutil::wrongNumArgs "$win findrowname name ?-descend?\
			      ?-parent nodeIndex?"
    }

    synchronize $win
    set name [lindex $argList 0]
    set nameIsEmpty [expr {[string length $name] == 0}]

    #
    # Initialize some processing parameters
    #
    set parentKey root
    set descend 0						;# boolean

    #
    # Parse the argument list
    #
    variable findOpts
    for {set n 1} {$n < $argCount} {incr n} {
	set arg [lindex $argList $n]
	set opt [mwutil::fullOpt "option" $arg $findOpts]
	switch -- $opt {
	    -descend { set descend 1 }
	    -parent {
		if {$n == $argCount - 1} {
		    return -code error "value for \"$arg\" missing"
		}

		incr n
		set parentKey [nodeIndexToKey $win [lindex $argList $n]]
	    }
	}
    }

    upvar ::tablelist::ns${win}::data data
    set childCount [llength $data($parentKey-children)]
    if {$childCount == 0} {
	return -1
    }

    if {$descend} {
	set fromChildKey [lindex $data($parentKey-children) 0]
	set fromRow [keyToRow $win $fromChildKey]
	set toRow [nodeRow $win $parentKey end]
	for {set row $fromRow} {$row < $toRow} {incr row} {
	    set key [lindex $data(keyList) $row]
	    set hasName [info exists data($key-name)]
	    if {($hasName && [string compare $name $data($key-name)] == 0) ||
		(!$hasName && $nameIsEmpty)} {
		return $row
	    }
	}
    } else {
	for {set childIdx 0} {$childIdx < $childCount} {incr childIdx} {
	    set key [lindex $data($parentKey-children) $childIdx]
	    set hasName [info exists data($key-name)]
	    if {($hasName && [string compare $name $data($key-name)] == 0) ||
		(!$hasName && $nameIsEmpty)} {
		return [keyToRow $win $key]
	    }
	}
    }

    return -1
}

#------------------------------------------------------------------------------
# tablelist::finisheditingSubCmd
#------------------------------------------------------------------------------
proc tablelist::finisheditingSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win finishediting"
    }

    synchronize $win
    return [doFinishEditing $win]
}

#------------------------------------------------------------------------------
# tablelist::formatinfoSubCmd
#------------------------------------------------------------------------------
proc tablelist::formatinfoSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win formatinfo"
    }

    upvar ::tablelist::ns${win}::data data
    return [list $data(fmtKey) $data(fmtRow) $data(fmtCol)]
}

#------------------------------------------------------------------------------
# tablelist::getSubCmd
#------------------------------------------------------------------------------
proc tablelist::getSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win get firstIndex lastIndex" \
			     "$win get indexList"
    }

    synchronize $win
    set first [lindex $argList 0]

    #
    # Get the specified items from the internal list
    #
    upvar ::tablelist::ns${win}::data data
    set result {}
    if {$argCount == 1} {
	foreach elem $first {
	    set row [rowIndex $win $elem 0]
	    if {$row >= 0 && $row < $data(itemCount)} {
		set item [lindex $data(itemList) $row]
		lappend result [lrange $item 0 $data(lastCol)]
	    }
	}

	if {[llength $first] == 1} {
	    return [lindex $result 0]
	} else {
	    return $result
	}
    } else {
	set first [rowIndex $win $first 0]
	set last [rowIndex $win [lindex $argList 1] 0]
	if {$last < $first} {
	    return {}
	}

	#
	# Adjust the range to fit within the existing items
	#
	if {$first < 0} {
	    set first 0
	}
	if {$last > $data(lastRow)} {
	    set last $data(lastRow)
	}

	foreach item [lrange $data(itemList) $first $last] {
	    lappend result [lrange $item 0 $data(lastCol)]
	}
	return $result
    }
}

#------------------------------------------------------------------------------
# tablelist::getcellsSubCmd
#------------------------------------------------------------------------------
proc tablelist::getcellsSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win getcells firstCellIndex lastCellIndex" \
			     "$win getcells cellIndexList"
    }

    synchronize $win
    set first [lindex $argList 0]

    #
    # Get the specified elements from the internal list
    #
    upvar ::tablelist::ns${win}::data data
    set result {}
    if {$argCount == 1} {
	foreach elem $first {
	    foreach {row col} [cellIndex $win $elem 1] {}
	    lappend result [lindex [lindex $data(itemList) $row] $col]
	}

	if {[llength $first] == 1} {
	    return [lindex $result 0]
	} else {
	    return $result
	}
    } else {
	foreach {firstRow firstCol} [cellIndex $win $first 1] {}
	foreach {lastRow lastCol} [cellIndex $win [lindex $argList 1] 1] {}

	foreach item [lrange $data(itemList) $firstRow $lastRow] {
	    foreach elem [lrange $item $firstCol $lastCol] {
		lappend result $elem
	    }
	}
	return $result
    }
}

#------------------------------------------------------------------------------
# tablelist::getcolumnsSubCmd
#------------------------------------------------------------------------------
proc tablelist::getcolumnsSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs \
		"$win getcolumns firstColumnIndex lastColumnIndex" \
		"$win getcolumns columnIndexList"
    }

    synchronize $win
    set first [lindex $argList 0]

    #
    # Get the specified columns from the internal list
    #
    upvar ::tablelist::ns${win}::data data
    set result {}
    if {$argCount == 1} {
	foreach elem $first {
	    set col [colIndex $win $elem 1]
	    set colResult {}
	    foreach item $data(itemList) {
		lappend colResult [lindex $item $col]
	    }
	    lappend result $colResult
	}

	if {[llength $first] == 1} {
	    return [lindex $result 0]
	} else {
	    return $result
	}
    } else {
	set first [colIndex $win $first 1]
	set last [colIndex $win [lindex $argList 1] 1]

	for {set col $first} {$col <= $last} {incr col} {
	    set colResult {}
	    foreach item $data(itemList) {
		lappend colResult [lindex $item $col]
	    }
	    lappend result $colResult
	}
	return $result
    }
}

#------------------------------------------------------------------------------
# tablelist::getformattedSubCmd
#------------------------------------------------------------------------------
proc tablelist::getformattedSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win getformatted firstIndex lastIndex" \
			     "$win getformatted indexList"
    }

    synchronize $win
    set first [lindex $argList 0]

    #
    # Get the specified items from the internal list
    #
    upvar ::tablelist::ns${win}::data data
    set result {}
    if {$argCount == 1} {
	foreach elem $first {
	    set row [rowIndex $win $elem 0]
	    if {$row >= 0 && $row < $data(itemCount)} {
		set item [lindex $data(itemList) $row]
		set key [lindex $item end]
		set item [lrange $item 0 $data(lastCol)]
		lappend result [formatItem $win $key $row $item]
	    }
	}

	if {[llength $first] == 1} {
	    return [lindex $result 0]
	} else {
	    return $result
	}
    } else {
	set first [rowIndex $win $first 0]
	set last [rowIndex $win [lindex $argList 1] 0]
	if {$last < $first} {
	    return {}
	}

	#
	# Adjust the range to fit within the existing items
	#
	if {$first < 0} {
	    set first 0
	}
	if {$last > $data(lastRow)} {
	    set last $data(lastRow)
	}

	set row $first
	foreach item [lrange $data(itemList) $first $last] {
	    set key [lindex $item end]
	    set item [lrange $item 0 $data(lastCol)]
	    lappend result [formatItem $win $key $row $item]
	    incr row
	}
	return $result
    }
}

#------------------------------------------------------------------------------
# tablelist::getformattedcellsSubCmd
#------------------------------------------------------------------------------
proc tablelist::getformattedcellsSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs \
		"$win getformattedcells firstCellIndex lastCellIndex" \
		"$win getformattedcells cellIndexList"
    }

    synchronize $win
    set first [lindex $argList 0]

    #
    # Get the specified elements from the internal list
    #
    upvar ::tablelist::ns${win}::data data
    set result {}
    if {$argCount == 1} {
	foreach elem $first {
	    foreach {row col} [cellIndex $win $elem 1] {}
	    set item [lindex $data(itemList) $row]
	    set key [lindex $item end]
	    set text [lindex $item $col]
	    if {[lindex $data(fmtCmdFlagList) $col]} {
		set text [formatElem $win $key $row $col $text]
	    }
	    lappend result $text
	}

	if {[llength $first] == 1} {
	    return [lindex $result 0]
	} else {
	    return $result
	}
    } else {
	foreach {firstRow firstCol} [cellIndex $win $first 1] {}
	foreach {lastRow lastCol} [cellIndex $win [lindex $argList 1] 1] {}

	set row $firstRow
	foreach item [lrange $data(itemList) $firstRow $lastRow] {
	    set key [lindex $item end]
	    set col $firstCol
	    foreach text [lrange $item $firstCol $lastCol] {
		if {[lindex $data(fmtCmdFlagList) $col]} {
		    set text [formatElem $win $key $row $col $text]
		}
		lappend result $text
		incr col
	    }
	    incr row
	}
	return $result
    }
}

#------------------------------------------------------------------------------
# tablelist::getformattedcolumnsSubCmd
#------------------------------------------------------------------------------
proc tablelist::getformattedcolumnsSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs \
		"$win getformattedcolumns firstColumnIndex lastColumnIndex" \
		"$win getformattedcolumns columnIndexList"
    }

    synchronize $win
    set first [lindex $argList 0]

    #
    # Get the specified columns from the internal list
    #
    upvar ::tablelist::ns${win}::data data
    set result {}
    if {$argCount == 1} {
	foreach elem $first {
	    set col [colIndex $win $elem 1]
	    set fmtCmdFlag [lindex $data(fmtCmdFlagList) $col]
	    set colResult {}
	    set row 0
	    foreach item $data(itemList) {
		set key [lindex $item end]
		set text [lindex $item $col]
		if {$fmtCmdFlag} {
		    set text [formatElem $win $key $row $col $text]
		}
		lappend colResult $text
		incr row
	    }
	    lappend result $colResult
	}

	if {[llength $first] == 1} {
	    return [lindex $result 0]
	} else {
	    return $result
	}
    } else {
	set first [colIndex $win $first 1]
	set last [colIndex $win [lindex $argList 1] 1]

	for {set col $first} {$col <= $last} {incr col} {
	    set fmtCmdFlag [lindex $data(fmtCmdFlagList) $col]
	    set colResult {}
	    set row 0
	    foreach item $data(itemList) {
		set key [lindex $item end]
		set text [lindex $item $col]
		if {$fmtCmdFlag} {
		    set text [formatElem $win $key $row $col $text]
		}
		lappend colResult $text
		incr row
	    }
	    lappend result $colResult
	}
	return $result
    }
}

#------------------------------------------------------------------------------
# tablelist::getfullkeysSubCmd
#------------------------------------------------------------------------------
proc tablelist::getfullkeysSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win getfullkeys firstIndex lastIndex" \
			     "$win getfullkeys indexList"
    }

    synchronize $win
    set first [lindex $argList 0]

    #
    # Get the specified keys from the internal list
    #
    upvar ::tablelist::ns${win}::data data
    set result {}
    if {$argCount == 1} {
	foreach elem $first {
	    set row [rowIndex $win $elem 0]
	    if {$row >= 0 && $row < $data(itemCount)} {
		lappend result [lindex [lindex $data(itemList) $row] end]
	    }
	}

	if {[llength $first] == 1} {
	    return [lindex $result 0]
	} else {
	    return $result
	}
    } else {
	set first [rowIndex $win $first 0]
	set last [rowIndex $win [lindex $argList 1] 0]
	if {$last < $first} {
	    return {}
	}

	#
	# Adjust the range to fit within the existing items
	#
	if {$first < 0} {
	    set first 0
	}
	if {$last > $data(lastRow)} {
	    set last $data(lastRow)
	}

	foreach item [lrange $data(itemList) $first $last] {
	    lappend result [lindex $item end]
	}
	return $result
    }
}

#------------------------------------------------------------------------------
# tablelist::getkeysSubCmd
#------------------------------------------------------------------------------
proc tablelist::getkeysSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win getkeys firstIndex lastIndex" \
			     "$win getkeys indexList"
    }

    synchronize $win
    set first [lindex $argList 0]

    #
    # Get the specified keys from the internal list
    #
    upvar ::tablelist::ns${win}::data data
    set result {}
    if {$argCount == 1} {
	foreach elem $first {
	    set row [rowIndex $win $elem 0]
	    if {$row >= 0 && $row < $data(itemCount)} {
		set item [lindex $data(itemList) $row]
		lappend result [string range [lindex $item end] 1 end]
	    }
	}

	if {[llength $first] == 1} {
	    return [lindex $result 0]
	} else {
	    return $result
	}
    } else {
	set first [rowIndex $win $first 0]
	set last [rowIndex $win [lindex $argList 1] 0]
	if {$last < $first} {
	    return {}
	}

	#
	# Adjust the range to fit within the existing items
	#
	if {$first < 0} {
	    set first 0
	}
	if {$last > $data(lastRow)} {
	    set last $data(lastRow)
	}

	foreach item [lrange $data(itemList) $first $last] {
	    lappend result [string range [lindex $item end] 1 end]
	}
	return $result
    }
}

#------------------------------------------------------------------------------
# tablelist::hasattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::hasattribSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win hasattrib name"
    }

    return [mwutil::hasattribSubCmd $win "widget" [lindex $argList 0]]
}

#------------------------------------------------------------------------------
# tablelist::hascellattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::hascellattribSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win hascellattrib cellIndex name"
    }

    synchronize $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 1] {}
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    return [mwutil::hasattribSubCmd $win $key,$col [lindex $argList 1]]
}

#------------------------------------------------------------------------------
# tablelist::hascolumnattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::hascolumnattribSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win hascolumnattrib columnIndex name"
    }

    set col [colIndex $win [lindex $argList 0] 1]
    return [mwutil::hasattribSubCmd $win $col [lindex $argList 1]]
}

#------------------------------------------------------------------------------
# tablelist::hasrowattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::hasrowattribSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win hasrowattrib index name"
    }

    synchronize $win
    set row [rowIndex $win [lindex $argList 0] 0 1]
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    return [mwutil::hasattribSubCmd $win $key [lindex $argList 1]]
}

#------------------------------------------------------------------------------
# tablelist::hidetargetmarkSubCmd
#------------------------------------------------------------------------------
proc tablelist::hidetargetmarkSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win hidetargetmark"
    }

    upvar ::tablelist::ns${win}::data data
    place forget $data(rowGap)
    return ""
}

#------------------------------------------------------------------------------
# tablelist::imagelabelpathSubCmd
#------------------------------------------------------------------------------
proc tablelist::imagelabelpathSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win imagelabelpath cellIndex"
    }

    synchronize $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 1] {}
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    set w $data(body).img_$key,$col
    if {[winfo exists $w]} {
	return $w
    } else {
	return ""
    }
}

#------------------------------------------------------------------------------
# tablelist::indexSubCmd
#------------------------------------------------------------------------------
proc tablelist::indexSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win index index"
    }

    synchronize $win
    return [rowIndex $win [lindex $argList 0] 1]
}

#------------------------------------------------------------------------------
# tablelist::insertSubCmd
#------------------------------------------------------------------------------
proc tablelist::insertSubCmd {win argList} {
    if {[llength $argList] < 1} {
	mwutil::wrongNumArgs "$win insert index ?item item ...?"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    set index [rowIndex $win [lindex $argList 0] 1]
    return [insertRows $win $index [lrange $argList 1 end] \
	    $data(hasListVar) root $index]
}

#------------------------------------------------------------------------------
# tablelist::insertchildlistSubCmd
#------------------------------------------------------------------------------
proc tablelist::insertchildlistSubCmd {win argList} {
    if {[llength $argList] != 3} {
	mwutil::wrongNumArgs "$win insertchildlist parentNodeIndex childIndex\
			      itemList"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    set parentKey [nodeIndexToKey $win [lindex $argList 0]]
    set childIdx [lindex $argList 1]
    set listIdx [nodeRow $win $parentKey $childIdx]
    set itemList [lindex $argList 2]
    set result [insertRows $win $listIdx $itemList $data(hasListVar) \
		$parentKey $childIdx]

    if {$data(colCount) == 0} {
	return $result
    }

    displayItems $win
    set treeCol $data(treeCol)
    set treeStyle $data(-treestyle)

    #
    # Mark the parent item as expanded if it was just indented
    #
    set depth [depth $win $parentKey]
    if {[info exists data($parentKey,$treeCol-indent)] &&
	[string compare $data($parentKey,$treeCol-indent) \
	 tablelist_${treeStyle}_indentedImg$depth] == 0} {
	set data($parentKey,$treeCol-indent) \
	    tablelist_${treeStyle}_expandedImg$depth
	if {[winfo exists $data(body).ind_$parentKey,$treeCol]} {
	    $data(body).ind_$parentKey,$treeCol configure -image \
		$data($parentKey,$treeCol-indent)
	}
    }

    #
    # Elide the new items if the parent is collapsed or non-viewable
    #
    set itemCount [llength $itemList]
    if {[string compare $parentKey $data(keyBeingExpanded)] != 0 &&
	(([info exists data($parentKey,$treeCol-indent)] && \
	  [string compare $data($parentKey,$treeCol-indent) \
	   tablelist_${treeStyle}_collapsedImg$depth] == 0) || \
	 [info exists data($parentKey-elide)] || \
	 [info exists data($parentKey-hide)])} {
	for {set n 0; set row $listIdx} {$n < $itemCount} {incr n; incr row} {
	    doRowConfig $row $win -elide 1
	}
    }

    #
    # Mark the new items as indented
    #
    incr depth
    variable maxIndentDepths
    if {$depth > $maxIndentDepths($treeStyle)} {
	createTreeImgs $treeStyle $depth
	set maxIndentDepths($treeStyle) $depth
    }
    for {set n 0; set row $listIdx} {$n < $itemCount} {incr n; incr row} {
	doCellConfig $row $treeCol $win -indent \
		     tablelist_${treeStyle}_indentedImg$depth
    }

    return $result
}

#------------------------------------------------------------------------------
# tablelist::insertchildrenSubCmd
#------------------------------------------------------------------------------
proc tablelist::insertchildrenSubCmd {win argList} {
    if {[llength $argList] < 2} {
	mwutil::wrongNumArgs "$win insertchildren parentNodeIndex childIndex\
			      ?item item ...?"
    }

    return [insertchildlistSubCmd $win [list [lindex $argList 0] \
	    [lindex $argList 1] [lrange $argList 2 end]]]
}

#------------------------------------------------------------------------------
# tablelist::insertcolumnlistSubCmd
#------------------------------------------------------------------------------
proc tablelist::insertcolumnlistSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win insertcolumnlist columnIndex columnList"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    displayItems $win
    set arg0 [lindex $argList 0]
    if {[string first $arg0 "end"] == 0 || $arg0 == $data(colCount)} {
	set col $data(colCount)
    } else {
	set col [colIndex $win $arg0 1]
    }

    return [insertCols $win $col [lindex $argList 1]]
}

#------------------------------------------------------------------------------
# tablelist::insertcolumnsSubCmd
#------------------------------------------------------------------------------
proc tablelist::insertcolumnsSubCmd {win argList} {
    if {[llength $argList] < 1} {
	mwutil::wrongNumArgs "$win insertcolumns columnIndex\
		?width title ?alignment? width title ?alignment? ...?"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    displayItems $win
    set arg0 [lindex $argList 0]
    if {[string first $arg0 "end"] == 0 || $arg0 == $data(colCount)} {
	set col $data(colCount)
    } else {
	set col [colIndex $win $arg0 1]
    }

    return [insertCols $win $col [lrange $argList 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::insertlistSubCmd
#------------------------------------------------------------------------------
proc tablelist::insertlistSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win insertlist index itemList"
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled)} {
	return ""
    }

    synchronize $win
    set index [rowIndex $win [lindex $argList 0] 1]
    return [insertRows $win $index [lindex $argList 1] \
	    $data(hasListVar) root $index]
}

#------------------------------------------------------------------------------
# tablelist::iselemsnippedSubCmd
#------------------------------------------------------------------------------
proc tablelist::iselemsnippedSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win iselemsnipped cellIndex fullTextName"
    }

    synchronize $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 1] {}
    set fullTextName [lindex $argList 1]
    upvar 2 $fullTextName fullText

    upvar ::tablelist::ns${win}::data data
    set item [lindex $data(itemList) $row]
    set key [lindex $item end]
    set fullText [lindex $item $col]
    if {[lindex $data(fmtCmdFlagList) $col]} {
	set fullText [formatElem $win $key $row $col $fullText]
    }
    if {[string match "*\t*" $fullText]} {
	set fullText [mapTabs $fullText]
    }

    set pixels [lindex $data(colList) [expr {2*$col}]]
    if {$pixels == 0} {				;# convention: dynamic width
	if {$data($col-maxPixels) > 0 &&
	    $data($col-reqPixels) > $data($col-maxPixels)} {
	    set pixels $data($col-maxPixels)
	}
    }
    if {$pixels == 0 || $data($col-wrap)} {
	return 0
    }

    set text $fullText
    getAuxData $win $key $col auxType auxWidth $pixels
    getIndentData $win $key $col indentWidth
    set cellFont [getCellFont $win $key $col]
    incr pixels $data($col-delta)

    if {[string match "*\n*" $text]} {
	set list [split $text "\n"]
	adjustMlElem $win list auxWidth indentWidth $cellFont $pixels "r" ""
	set text [join $list "\n"]
    } else {
	adjustElem $win text auxWidth indentWidth $cellFont $pixels "r" ""
    }

    return [expr {[string compare $text $fullText] != 0}]
}

#------------------------------------------------------------------------------
# tablelist::isexpandedSubCmd
#------------------------------------------------------------------------------
proc tablelist::isexpandedSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win isexpanded index"
    }

    synchronize $win
    set row [rowIndex $win [lindex $argList 0] 0]
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    set treeCol $data(treeCol)
    if {[info exists data($key,$treeCol-indent)]} {
	return [string match "*expanded*" $data($key,$treeCol-indent)]
    } else {
	return 0
    }
}

#------------------------------------------------------------------------------
# tablelist::istitlesnippedSubCmd
#------------------------------------------------------------------------------
proc tablelist::istitlesnippedSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win istitlesnipped columnIndex fullTextName"
    }

    set col [colIndex $win [lindex $argList 0] 1]
    set fullTextName [lindex $argList 1]
    upvar 2 $fullTextName fullText

    upvar ::tablelist::ns${win}::data data
    set fullText [lindex $data(-columns) [expr {3*$col + 1}]]
    return $data($col-isSnipped)
}

#------------------------------------------------------------------------------
# tablelist::isviewableSubCmd
#------------------------------------------------------------------------------
proc tablelist::isviewableSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win isviewable index"
    }

    synchronize $win
    set row [rowIndex $win [lindex $argList 0] 0 1]
    return [isRowViewable $win $row]
}

#------------------------------------------------------------------------------
# tablelist::itemlistvarSubCmd
#------------------------------------------------------------------------------
proc tablelist::itemlistvarSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win itemlistvar"
    }

    return ::tablelist::ns${win}::data(itemList)
}

#------------------------------------------------------------------------------
# tablelist::labelpathSubCmd
#------------------------------------------------------------------------------
proc tablelist::labelpathSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win labelpath columnIndex"
    }

    set col [colIndex $win [lindex $argList 0] 1]
    upvar ::tablelist::ns${win}::data data
    return $data(hdrTxtFrLbl)$col
}

#------------------------------------------------------------------------------
# tablelist::labelsSubCmd
#------------------------------------------------------------------------------
proc tablelist::labelsSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win labels"
    }

    upvar ::tablelist::ns${win}::data data
    set labelList {}
    for {set col 0} {$col < $data(colCount)} {incr col} {
	lappend labelList $data(hdrTxtFrLbl)$col
    }

    return $labelList
}

#------------------------------------------------------------------------------
# tablelist::labeltagSubCmd
#------------------------------------------------------------------------------
proc tablelist::labeltagSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win labeltag"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(labelTag)
}

#------------------------------------------------------------------------------
# tablelist::moveSubCmd
#------------------------------------------------------------------------------
proc tablelist::moveSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 2 || $argCount > 3} {
	mwutil::wrongNumArgs \
		"$win move sourceIndex targetIndex" \
		"$win move sourceIndex targetParentNodeIndex targetChildIndex"
    }

    synchronize $win
    displayItems $win
    set source [rowIndex $win [lindex $argList 0] 0]
    if {$argCount == 2} {
	set target [rowIndex $win [lindex $argList 1] 1]
	return [moveRow $win $source $target]
    } else {
	set targetParentKey [nodeIndexToKey $win [lindex $argList 1]]
	set targetChildIdx [lindex $argList 2]
	return [moveNode $win $source $targetParentKey $targetChildIdx]
    }
}

#------------------------------------------------------------------------------
# tablelist::movecolumnSubCmd
#------------------------------------------------------------------------------
proc tablelist::movecolumnSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win movecolumn sourceColumnIndex\
			      targetColumnIndex"
    }

    synchronize $win
    displayItems $win
    set arg0 [lindex $argList 0]
    set source [colIndex $win $arg0 1]
    set arg1 [lindex $argList 1]
    upvar ::tablelist::ns${win}::data data
    if {[string first $arg1 "end"] == 0 || $arg1 == $data(colCount)} {
	set target $data(colCount)
    } else {
	set target [colIndex $win $arg1 1]
    }

    return [moveCol $win $source $target]
}

#------------------------------------------------------------------------------
# tablelist::nearestSubCmd
#------------------------------------------------------------------------------
proc tablelist::nearestSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win nearest y"
    }

    set y [format "%d" [lindex $argList 0]]
    synchronize $win
    displayItems $win
    return [rowIndex $win @0,$y 0]
}

#------------------------------------------------------------------------------
# tablelist::nearestcellSubCmd
#------------------------------------------------------------------------------
proc tablelist::nearestcellSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win nearestcell x y"
    }

    set x [format "%d" [lindex $argList 0]]
    set y [format "%d" [lindex $argList 1]]
    synchronize $win
    displayItems $win
    return [join [cellIndex $win @$x,$y 0] ","]
}

#------------------------------------------------------------------------------
# tablelist::nearestcolumnSubCmd
#------------------------------------------------------------------------------
proc tablelist::nearestcolumnSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win nearestcolumn x"
    }

    set x [format "%d" [lindex $argList 0]]
    return [colIndex $win @$x,0 0]
}

#------------------------------------------------------------------------------
# tablelist::noderowSubCmd
#------------------------------------------------------------------------------
proc tablelist::noderowSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win noderow parentNodeIndex childIndex"
    }

    synchronize $win
    set parentKey [nodeIndexToKey $win [lindex $argList 0]]
    set childIdx [lindex $argList 1]
    return [nodeRow $win $parentKey $childIdx]
}

#------------------------------------------------------------------------------
# tablelist::parentkeySubCmd
#------------------------------------------------------------------------------
proc tablelist::parentkeySubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win parentkey nodeIndex"
    }

    synchronize $win
    set key [nodeIndexToKey $win [lindex $argList 0]]
    upvar ::tablelist::ns${win}::data data
    return $data($key-parent)
}

#------------------------------------------------------------------------------
# tablelist::refreshsortingSubCmd
#------------------------------------------------------------------------------
proc tablelist::refreshsortingSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount > 1} {
	mwutil::wrongNumArgs "$win refreshsorting ?parentNodeIndex?"
    }

    synchronize $win
    displayItems $win
    if {$argCount == 0} {
	set parentKey root
    } else {
	set parentKey [nodeIndexToKey $win [lindex $argList 0]]
    }

    upvar ::tablelist::ns${win}::data data
    set sortOrderList {}
    foreach col $data(sortColList) {
	lappend sortOrderList $data($col-sortOrder)
    }

    return [sortItems $win $parentKey $data(sortColList) $sortOrderList]
}

#------------------------------------------------------------------------------
# tablelist::rejectinputSubCmd
#------------------------------------------------------------------------------
proc tablelist::rejectinputSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win rejectinput"
    }

    upvar ::tablelist::ns${win}::data data
    set data(rejected) 1
    return ""
}

#------------------------------------------------------------------------------
# tablelist::resetsortinfoSubCmd
#------------------------------------------------------------------------------
proc tablelist::resetsortinfoSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win resetsortinfo"
    }

    upvar ::tablelist::ns${win}::data data

    foreach col $data(sortColList) {
	set data($col-sortRank) 0
	set data($col-sortOrder) ""
    }

    set whichWidths {}
    foreach col $data(arrowColList) {
	lappend whichWidths l$col
    }

    set data(sortColList) {}
    set data(arrowColList) {}
    set data(sortOrder) {}

    if {[llength $whichWidths] > 0} {
	synchronize $win
	displayItems $win
	adjustColumns $win $whichWidths 1
    }

    return ""
}

#------------------------------------------------------------------------------
# tablelist::rowattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::rowattribSubCmd {win argList} {
    if {[llength $argList] < 1} {
	mwutil::wrongNumArgs "$win rowattrib index ?name? ?value\
			      name value ...?"
    }

    synchronize $win
    set row [rowIndex $win [lindex $argList 0] 0 1]
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    return [mwutil::attribSubCmd $win $key [lrange $argList 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::rowcgetSubCmd
#------------------------------------------------------------------------------
proc tablelist::rowcgetSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win rowcget index option"
    }

    synchronize $win
    set row [rowIndex $win [lindex $argList 0] 0 1]
    variable rowConfigSpecs
    set opt [mwutil::fullConfigOpt [lindex $argList 1] rowConfigSpecs]
    return [doRowCget $row $win $opt]
}

#------------------------------------------------------------------------------
# tablelist::rowconfigureSubCmd
#------------------------------------------------------------------------------
proc tablelist::rowconfigureSubCmd {win argList} {
    if {[llength $argList] < 1} {
	mwutil::wrongNumArgs "$win rowconfigure index ?option? ?value\
			      option value ...?"
    }

    synchronize $win
    displayItems $win
    variable rowConfigSpecs
    set row [rowIndex $win [lindex $argList 0] 0 1]
    return [mwutil::configureSubCmd $win rowConfigSpecs \
	    "tablelist::doRowConfig $row" "tablelist::doRowCget $row" \
	    [lrange $argList 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::scanSubCmd
#------------------------------------------------------------------------------
proc tablelist::scanSubCmd {win argList} {
    if {[llength $argList] != 3} {
	mwutil::wrongNumArgs "$win scan mark|dragto x y"
    }

    set x [format "%d" [lindex $argList 1]]
    set y [format "%d" [lindex $argList 2]]
    variable scanOpts
    set opt [mwutil::fullOpt "option" [lindex $argList 0] $scanOpts]
    synchronize $win
    displayItems $win
    return [doScan $win $opt $x $y]
}

#------------------------------------------------------------------------------
# tablelist::searchcolumnSubCmd
#------------------------------------------------------------------------------
proc tablelist::searchcolumnSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 2} {
	mwutil::wrongNumArgs "$win searchcolumn columnIndex pattern ?options?"
    }

    synchronize $win
    set col [colIndex $win [lindex $argList 0] 1]
    set pattern [lindex $argList 1]

    #
    # Initialize some processing parameters
    #
    set mode -glob		;# possible values: -exact, -glob, -regexp
    set checkCmd ""
    set parentKey root
    set allMatches 0						;# boolean
    set backwards 0						;# boolean
    set descend 0						;# boolean
    set formatted 0						;# boolean
    set noCase 0						;# boolean
    set negated 0						;# boolean
    set numeric 0						;# boolean
    set gotStartRow 0						;# boolean

    #
    # Parse the argument list
    #
    variable searchOpts
    for {set n 2} {$n < $argCount} {incr n} {
	set arg [lindex $argList $n]
	set opt [mwutil::fullOpt "option" $arg $searchOpts]
	switch -- $opt {
	    -all	{ set allMatches 1}
	    -backwards	{ set backwards 1 }
	    -check {
		if {$n == $argCount - 1} {
		    return -code error "value for \"$arg\" missing"
		}

		incr n
		set checkCmd [lindex $argList $n]
	    }
	    -descend	{ set descend 1 }
	    -exact	{ set mode -exact }
	    -formatted	{ set formatted 1 }
	    -glob	{ set mode -glob }
	    -nocase	{ set noCase 1 }
	    -not	{ set negated 1 }
	    -numeric	{ set numeric 1 }
	    -parent {
		if {$n == $argCount - 1} {
		    return -code error "value for \"$arg\" missing"
		}

		incr n
		set parentKey [nodeIndexToKey $win [lindex $argList $n]]
	    }
	    -regexp	{ set mode -regexp }
	    -start {
		if {$n == $argCount - 1} {
		    return -code error "value for \"$arg\" missing"
		}

		incr n
		set startRow [rowIndex $win [lindex $argList $n] 0]
		set gotStartRow 1
	    }
	}
    }

    if {([string compare $mode "-exact"] == 0 && !$numeric && $noCase) ||
	([string compare $mode "-glob"] == 0 && $noCase)} {
	set pattern [string tolower $pattern]
    }

    upvar ::tablelist::ns${win}::data data
    if {[string length $data(-populatecommand)] != 0} {
	#
	# Populate the relevant subtree(s) if necessary
	#
	if {[string compare $parentKey "root"] == 0} {
	    if {$descend} {
		for {set row 0} {$row < $data(itemCount)} {incr row} {
		    populate $win $row 1
		}
	    }
	} else {
	    populate $win [keyToRow $win $parentKey] $descend
	}
    }

    #
    # Build the list of row indices of the matching elements
    #
    set rowList {}
    set useFormatCmd [expr {$formatted && [lindex $data(fmtCmdFlagList) $col]}]
    set childCount [llength $data($parentKey-children)]
    if {$childCount != 0} {
	if {$backwards} {
	    set childIdx [expr {$childCount - 1}]
	    if {$descend} {
		set childKey [lindex $data($parentKey-children) $childIdx]
		set maxRow [expr {[nodeRow $win $childKey end] - 1}]
		if {$gotStartRow && $maxRow > $startRow} {
		    set maxRow $startRow
		}
		set minRow [nodeRow $win $parentKey 0]
		for {set row $maxRow} {$row >= $minRow} {incr row -1} {
		    set item [lindex $data(itemList) $row]
		    set elem [lindex $item $col]
		    if {$useFormatCmd} {
			set key [lindex $item end]
			set elem [formatElem $win $key $row $col $elem]
		    }
		    if {[doesMatch $win $row $col $pattern $elem $mode \
			 $numeric $noCase $checkCmd] != $negated} {
			lappend rowList $row
			if {!$allMatches} {
			    break
			}
		    }
		}
	    } else {
		for {} {$childIdx >= 0} {incr childIdx -1} {
		    set key [lindex $data($parentKey-children) $childIdx]
		    set row [keyToRow $win $key]
		    if {$gotStartRow && $row > $startRow} {
			continue
		    }
		    set elem [lindex [lindex $data(itemList) $row] $col]
		    if {$useFormatCmd} {
			set elem [formatElem $win $key $row $col $elem]
		    }
		    if {[doesMatch $win $row $col $pattern $elem $mode \
			 $numeric $noCase $checkCmd] != $negated} {
			lappend rowList $row
			if {!$allMatches} {
			    break
			}
		    }
		}
	    }
	} else {
	    set childIdx 0
	    if {$descend} {
		set childKey [lindex $data($parentKey-children) $childIdx]
		set fromRow [keyToRow $win $childKey]
		if {$gotStartRow && $fromRow < $startRow} {
		    set fromRow $startRow
		}
		set toRow [nodeRow $win $parentKey end]
		for {set row $fromRow} {$row < $toRow} {incr row} {
		    set item [lindex $data(itemList) $row]
		    set elem [lindex $item $col]
		    if {$useFormatCmd} {
			set key [lindex $item end]
			set elem [formatElem $win $key $row $col $elem]
		    }
		    if {[doesMatch $win $row $col $pattern $elem $mode \
			 $numeric $noCase $checkCmd] != $negated} {
			lappend rowList $row
			if {!$allMatches} {
			    break
			}
		    }
		}
	    } else {
		for {} {$childIdx < $childCount} {incr childIdx} {
		    set key [lindex $data($parentKey-children) $childIdx]
		    set row [keyToRow $win $key]
		    if {$gotStartRow && $row < $startRow} {
			continue
		    }
		    set elem [lindex [lindex $data(itemList) $row] $col]
		    if {$useFormatCmd} {
			set elem [formatElem $win $key $row $col $elem]
		    }
		    if {[doesMatch $win $row $col $pattern $elem $mode \
			 $numeric $noCase $checkCmd] != $negated} {
			lappend rowList $row
			if {!$allMatches} {
			    break
			}
		    }
		}
	    }
	}
    }

    if {$allMatches} {
	return $rowList
    } elseif {[llength $rowList] == 0} {
	return -1
    } else {
	return [lindex $rowList 0]
    }
}

#------------------------------------------------------------------------------
# tablelist::seeSubCmd
#------------------------------------------------------------------------------
proc tablelist::seeSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win see index"
    }

    synchronize $win
    displayItems $win
    set index [rowIndex $win [lindex $argList 0] 0]
    seeRow $win $index
    return ""
}

#------------------------------------------------------------------------------
# tablelist::seecellSubCmd
#------------------------------------------------------------------------------
proc tablelist::seecellSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win seecell cellIndex"
    }

    synchronize $win
    displayItems $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 0] {}
    if {[winfo viewable $win]} {
	return [seeCell $win $row $col]
    } else {
	after idle [list tablelist::seeCell $win $row $col]
	return ""
    }
}

#------------------------------------------------------------------------------
# tablelist::seecolumnSubCmd
#------------------------------------------------------------------------------
proc tablelist::seecolumnSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win seecolumn columnIndex"
    }

    synchronize $win
    displayItems $win
    set col [colIndex $win [lindex $argList 0] 0]
    if {[winfo viewable $win]} {
	return [seeCell $win [rowIndex $win @0,0 0] $col]
    } else {
	after idle [list tablelist::seeCell $win [rowIndex $win @0,0 0] $col]
	return ""
    }
}

#------------------------------------------------------------------------------
# tablelist::selectionSubCmd
#------------------------------------------------------------------------------
proc tablelist::selectionSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 2 || $argCount > 3} {
	mwutil::wrongNumArgs "$win selection option firstIndex lastIndex" \
			     "$win selection option indexList"
    }

    synchronize $win
    displayItems $win
    variable selectionOpts
    set opt [mwutil::fullOpt "option" [lindex $argList 0] $selectionOpts]
    set first [lindex $argList 1]

    switch $opt {
	anchor -
	includes {
	    if {$argCount != 2} {
		mwutil::wrongNumArgs "$win selection $opt index"
	    }
	    set index [rowIndex $win $first 0]
	    return [rowSelection $win $opt $index $index]
	}

	clear -
	set {
	    if {$argCount == 2} {
		foreach elem $first {
		    set index [rowIndex $win $elem 0]
		    rowSelection $win $opt $index $index
		}
	    } else {
		set first [rowIndex $win $first 0]
		set last [rowIndex $win [lindex $argList 2] 0]
		rowSelection $win $opt $first $last
	    }

	    updateColors $win
	    invokeMotionHandler $win
	    return ""
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::separatorpathSubCmd
#------------------------------------------------------------------------------
proc tablelist::separatorpathSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount > 1} {
	mwutil::wrongNumArgs "$win separatorpath ?columnIndex?"
    }

    upvar ::tablelist::ns${win}::data data
    if {$argCount == 0} {
	if {[winfo exists $data(sep)]} {
	    return $data(sep)
	} else {
	    return ""
	}
    } else {
	set col [colIndex $win [lindex $argList 0] 1]
	if {$data(-showseparators)} {
	    return $data(sep)$col
	} else {
	    return ""
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::separatorsSubCmd
#------------------------------------------------------------------------------
proc tablelist::separatorsSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win separators"
    }

    set sepList {}
    foreach w [winfo children $win] {
	if {[regexp {^sep([0-9]+)?$} [winfo name $w]]} {
	    lappend sepList $w
	}
    }

    return [lsort -dictionary $sepList]
}

#------------------------------------------------------------------------------
# tablelist::showtargetmarkSubCmd
#------------------------------------------------------------------------------
proc tablelist::showtargetmarkSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win showtargetmark before|inside index"
    }

    variable targetOpts
    set opt [mwutil::fullOpt "option" [lindex $argList 0] $targetOpts]
    set index [lindex $argList 1]

    upvar ::tablelist::ns${win}::data data
    set w $data(body)

    switch $opt {
	before {
	    set row [rowIndex $win $index 1]
	    if {$data(itemCount) == 0} {
		set y 0
	    } elseif {$row >= $data(itemCount)} {
		set dlineinfo [$w dlineinfo [expr {double($data(itemCount))}]]
		if {[llength $dlineinfo] == 0} {
		    return ""
		}

		set lineY [lindex $dlineinfo 1]
		set lineHeight [lindex $dlineinfo 3]
		set y [expr {$lineY + $lineHeight}]
	    } else {
		if {$row < 0} {
		    set row 0
		}
		set dlineinfo [$w dlineinfo [expr {double($row + 1)}]]
		if {[llength $dlineinfo] == 0} {
		    return ""
		}

		set y [lindex $dlineinfo 1]
	    }

	    place $data(rowGap) -anchor w -y $y -height 4 \
				-width [winfo width $data(hdrTxtFr)]
	}

	inside {
	    set row [rowIndex $win $index 0 1]
	    set dlineinfo [$w dlineinfo [expr {double($row + 1)}]]
	    if {[llength $dlineinfo] == 0} {
		return ""
	    }

	    set lineY [lindex $dlineinfo 1]
	    set lineHeight [lindex $dlineinfo 3]
	    set y [expr {$lineY + $lineHeight/2}]

	    place $data(rowGap) -anchor w -y $y -height $lineHeight -width 6
	}
    }

    raise $data(rowGap)
    return ""
}

#------------------------------------------------------------------------------
# tablelist::sizeSubCmd
#------------------------------------------------------------------------------
proc tablelist::sizeSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win size"
    }

    synchronize $win
    upvar ::tablelist::ns${win}::data data
    return $data(itemCount)
}

#------------------------------------------------------------------------------
# tablelist::sortSubCmd
#------------------------------------------------------------------------------
proc tablelist::sortSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount > 1} {
	mwutil::wrongNumArgs "$win sort ?-increasing|-decreasing?"
    }

    if {$argCount == 0} {
	set order -increasing
    } else {
	variable sortOpts
	set order [mwutil::fullOpt "option" [lindex $argList 0] $sortOpts]
    }

    synchronize $win
    displayItems $win
    return [sortItems $win root -1 [string range $order 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::sortbycolumnSubCmd
#------------------------------------------------------------------------------
proc tablelist::sortbycolumnSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win sortbycolumn columnIndex\
			      ?-increasing|-decreasing?"
    }

    synchronize $win
    displayItems $win
    set col [colIndex $win [lindex $argList 0] 1]
    if {$argCount == 1} {
	set order -increasing
    } else {
	variable sortOpts
	set order [mwutil::fullOpt "option" [lindex $argList 1] $sortOpts]
    }

    return [sortItems $win root $col [string range $order 1 end]]
}

#------------------------------------------------------------------------------
# tablelist::sortbycolumnlistSubCmd
#------------------------------------------------------------------------------
proc tablelist::sortbycolumnlistSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win sortbycolumnlist columnIndexList\
			      ?sortOrderList?"
    }

    synchronize $win
    displayItems $win
    set sortColList {}
    foreach elem [lindex $argList 0] {
	set col [colIndex $win $elem 1]
	if {[lsearch -exact $sortColList $col] >= 0} {
	    return -code error "duplicate column index \"$elem\""
	}
	lappend sortColList $col
    }

    set sortOrderList {}
    if {$argCount == 2} {
	variable sortOrders
	foreach elem [lindex $argList 1] {
	    lappend sortOrderList [mwutil::fullOpt "option" $elem $sortOrders]
	}
    }

    return [sortItems $win root $sortColList $sortOrderList]
}

#------------------------------------------------------------------------------
# tablelist::sortcolumnSubCmd
#------------------------------------------------------------------------------
proc tablelist::sortcolumnSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win sortcolumn"
    }

    upvar ::tablelist::ns${win}::data data
    if {[llength $data(sortColList)] == 0} {
	return -1
    } else {
	return [lindex $data(sortColList) 0]
    }
}

#------------------------------------------------------------------------------
# tablelist::sortcolumnlistSubCmd
#------------------------------------------------------------------------------
proc tablelist::sortcolumnlistSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win sortcolumnlist"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(sortColList)
}

#------------------------------------------------------------------------------
# tablelist::sortorderSubCmd
#------------------------------------------------------------------------------
proc tablelist::sortorderSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win sortorder"
    }

    upvar ::tablelist::ns${win}::data data
    if {[llength $data(sortColList)] == 0} {
	return $data(sortOrder)
    } else {
	set col [lindex $data(sortColList) 0]
	return $data($col-sortOrder)
    }
}

#------------------------------------------------------------------------------
# tablelist::sortorderlistSubCmd
#------------------------------------------------------------------------------
proc tablelist::sortorderlistSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win sortorderlist"
    }

    upvar ::tablelist::ns${win}::data data
    set sortOrderList {}
    foreach col $data(sortColList) {
	lappend sortOrderList $data($col-sortOrder)
    }

    return $sortOrderList
}

#------------------------------------------------------------------------------
# tablelist::targetmarkpathSubCmd
#------------------------------------------------------------------------------
proc tablelist::targetmarkpathSubCmd {win argList} {
    if {[llength $argList] != 0} {
	mwutil::wrongNumArgs "$win targetmarkpath"
    }

    upvar ::tablelist::ns${win}::data data
    return $data(rowGap)
}

#------------------------------------------------------------------------------
# tablelist::targetmarkposSubCmd
#------------------------------------------------------------------------------
proc tablelist::targetmarkposSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win targetmarkpos y ?-any|-horizontal|-vertical?"
    }

    set y [format "%d" [lindex $argList 0]]
    if {$argCount == 1} {
	set opt -any
    } else {
	variable gapTypeOpts
	set opt [mwutil::fullOpt "option" [lindex $argList 1] $gapTypeOpts]
    }

    synchronize $win
    displayItems $win

    switch -- $opt {
	-any {
	    set row [containingRow $win $y relOffset]
	    if {$row < 0} {
		set place before
		upvar ::tablelist::ns${win}::data data
		set row [expr {
		    ($y < [winfo y $data(body)]) ? 0 : $data(itemCount)
		}]
	    } elseif {$relOffset < 0.25} {
		set place before
	    } elseif {$relOffset < 0.75} {
		set place inside
	    } else {
		set place before
		if {[isexpandedSubCmd $win $row]} {
		    incr row
		} else {
		    #
		    # Get the containing row's next sibling
		    #
		    set childIdx [childindexSubCmd $win $row]
		    set row [noderowSubCmd $win [list \
			     [parentkeySubCmd $win $row] [incr childIdx]]]
		}
	    }

	    return [list $place $row]
	}

	-horizontal {
	    set row [containingRow $win $y relOffset]
	    if {$row < 0} {
		upvar ::tablelist::ns${win}::data data
		set row [expr {
		    ($y < [winfo y $data(body)]) ? 0 : $data(itemCount)
		}]
	    } elseif {$relOffset >= 0.5} {
		if {[isexpandedSubCmd $win $row]} {
		    incr row
		} else {
		    #
		    # Get the containing row's next sibling
		    #
		    set childIdx [childindexSubCmd $win $row]
		    set row [noderowSubCmd $win [list \
			     [parentkeySubCmd $win $row] [incr childIdx]]]
		}
	    }

	    return [list before $row]
	}

	-vertical {
	    set row [containingRow $win $y]
	    return [list inside $row]
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::togglecolumnhideSubCmd
#------------------------------------------------------------------------------
proc tablelist::togglecolumnhideSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs \
		"$win togglecolumnhide firstColumnIndex lastColumnIndex" \
		"$win togglecolumnhide columnIndexList"
    }

    synchronize $win
    displayItems $win
    set first [lindex $argList 0]

    #
    # Toggle the value of the -hide option of the specified columns
    #
    variable canElide
    if {!$canElide} {
	set selCells [curCellSelection $win]
    }
    upvar ::tablelist::ns${win}::data data
    set colIdxList {}
    if {$argCount == 1} {
	foreach elem $first {
	    set col [colIndex $win $elem 1]
	    set data($col-hide) [expr {!$data($col-hide)}]
	    if {$data($col-hide)} {
		incr data(hiddenColCount)
		if {$col == $data(editCol)} {
		    doCancelEditing $win
		}
	    } else {
		incr data(hiddenColCount) -1
	    }
	    lappend colIdxList $col
	}
    } else {
	set first [colIndex $win $first 1]
	set last [colIndex $win [lindex $argList 1] 1]

	for {set col $first} {$col <= $last} {incr col} {
	    set data($col-hide) [expr {!$data($col-hide)}]
	    if {$data($col-hide)} {
		incr data(hiddenColCount)
		if {$col == $data(editCol)} {
		    doCancelEditing $win
		}
	    } else {
		incr data(hiddenColCount) -1
	    }
	    lappend colIdxList $col
	}
    }

    if {[llength $colIdxList] == 0} {
	return ""
    }

    #
    # Adjust the columns and redisplay the items
    #
    makeColFontAndTagLists $win
    adjustColumns $win $colIdxList 1
    adjustColIndex $win data(anchorCol) 1
    adjustColIndex $win data(activeCol) 1
    if {!$canElide} {
	redisplay $win 0 $selCells
    }
    if {[string compare $data(-selecttype) "row"] == 0} {
	foreach row [curSelection $win] {
	    rowSelection $win set $row $row
	}
    }

    updateViewWhenIdle $win
    genVirtualEvent $win <<TablelistColHiddenStateChanged>> $colIdxList
    return ""
}

#------------------------------------------------------------------------------
# tablelist::togglerowhideSubCmd
#------------------------------------------------------------------------------
proc tablelist::togglerowhideSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount < 1 || $argCount > 2} {
	mwutil::wrongNumArgs "$win togglerowhide firstIndex lastIndex" \
			     "$win togglerowhide indexList"
    }

    synchronize $win
    displayItems $win
    set first [lindex $argList 0]

    #
    # Toggle the value of the -hide option of the specified rows
    #
    set rowIdxList {}
    set count 0
    if {$argCount == 1} {
	foreach elem $first {
	    set row [rowIndex $win $elem 0 1]
	    doRowConfig $row $win -hide [expr {![doRowCget $row $win -hide]}]
	    incr count
	    lappend rowIdxList $row
	}
    } else {
	set firstRow [rowIndex $win $first 0 1]
	set lastRow [rowIndex $win [lindex $argList 1] 0 1]
	for {set row $firstRow} {$row <= $lastRow} {incr row} {
	    doRowConfig $row $win -hide [expr {![doRowCget $row $win -hide]}]
	    incr count
	    lappend rowIdxList $row
	}
    }

    if {$count != 0} {
	makeStripesWhenIdle $win
	showLineNumbersWhenIdle $win
	updateViewWhenIdle $win
	genVirtualEvent $win <<TablelistRowHiddenStateChanged>> $rowIdxList
    }

    return ""
}

#------------------------------------------------------------------------------
# tablelist::toplevelkeySubCmd
#------------------------------------------------------------------------------
proc tablelist::toplevelkeySubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win toplevelkey index"
    }

    synchronize $win
    set row [rowIndex $win [lindex $argList 0] 0 1]
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    return [topLevelKey $win $key]
}

#------------------------------------------------------------------------------
# tablelist::unsetattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::unsetattribSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win unsetattrib name"
    }

    return [mwutil::unsetattribSubCmd $win "widget" [lindex $argList 0]]
}

#------------------------------------------------------------------------------
# tablelist::unsetcellattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::unsetcellattribSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win unsetcellattrib cellIndex name"
    }

    synchronize $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 1] {}
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    return [mwutil::unsetattribSubCmd $win $key,$col [lindex $argList 1]]
}

#------------------------------------------------------------------------------
# tablelist::unsetcolumnattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::unsetcolumnattribSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win unsetcolumnattrib columnIndex name"
    }

    set col [colIndex $win [lindex $argList 0] 1]
    return [mwutil::unsetattribSubCmd $win $col [lindex $argList 1]]
}

#------------------------------------------------------------------------------
# tablelist::unsetrowattribSubCmd
#------------------------------------------------------------------------------
proc tablelist::unsetrowattribSubCmd {win argList} {
    if {[llength $argList] != 2} {
	mwutil::wrongNumArgs "$win unsetrowattrib index name"
    }

    synchronize $win
    set row [rowIndex $win [lindex $argList 0] 0]
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    return [mwutil::unsetattribSubCmd $win $key [lindex $argList 1]]
}

#------------------------------------------------------------------------------
# tablelist::viewablerowcountSubCmd
#------------------------------------------------------------------------------
proc tablelist::viewablerowcountSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount != 0 && $argCount != 2} {
	mwutil::wrongNumArgs "$win viewablerowcount ?firstIndex lastIndex?"
    }

    synchronize $win
    upvar ::tablelist::ns${win}::data data
    if {$argCount == 0} {
	set first 0
	set last $data(lastRow)
    } else {
	set first [rowIndex $win [lindex $argList 0] 0]
	set last [rowIndex $win [lindex $argList 1] 0]
    }
    if {$last < $first} {
	return 0
    }

    #
    # Adjust the range to fit within the existing items
    #
    if {$first < 0} {
	set first 0
    }
    if {$last > $data(lastRow)} {
	set last $data(lastRow)
    }

    return [getViewableRowCount $win $first $last]
}

#------------------------------------------------------------------------------
# tablelist::windowpathSubCmd
#------------------------------------------------------------------------------
proc tablelist::windowpathSubCmd {win argList} {
    if {[llength $argList] != 1} {
	mwutil::wrongNumArgs "$win windowpath cellIndex"
    }

    synchronize $win
    foreach {row col} [cellIndex $win [lindex $argList 0] 1] {}
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    set w $data(body).frm_$key,$col.w
    if {[winfo exists $w]} {
	return $w
    } else {
	return ""
    }
}

#------------------------------------------------------------------------------
# tablelist::xviewSubCmd
#------------------------------------------------------------------------------
proc tablelist::xviewSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount != 1 || [lindex $argList 0] != 0} {
	synchronize $win
	displayItems $win
    }
    upvar ::tablelist::ns${win}::data data

    switch $argCount {
	0 {
	    #
	    # Command: $win xview
	    #
	    if {$data(-titlecolumns) == 0} {
		return [$data(hdrTxt) xview]
	    } else {
		set scrlWindowWidth [getScrlWindowWidth $win]
		if {$scrlWindowWidth <= 0} {
		    return [list 0 0]
		}

		set scrlContentWidth [getScrlContentWidth $win 0 $data(lastCol)]
		if {$scrlContentWidth == 0} {
		    return [list 0 1]
		}

		set scrlXOffset \
		    [scrlColOffsetToXOffset $win $data(scrlColOffset)]
		set fraction1 [expr {$scrlXOffset/double($scrlContentWidth)}]
		set fraction2 [expr {($scrlXOffset + $scrlWindowWidth)/
				     double($scrlContentWidth)}]
		if {$fraction2 > 1.0} {
		    set fraction2 1.0
		}
		return [list [format "%g" $fraction1] [format "%g" $fraction2]]
	    }
	}

	1 {
	    #
	    # Command: $win xview <units>
	    #
	    set units [format "%d" [lindex $argList 0]]
	    if {$data(-titlecolumns) == 0} {
		foreach w [list $data(hdrTxt) $data(body)] {
		    $w xview moveto 0
		    $w xview scroll $units units
		}
	    } else {
		changeScrlColOffset $win $units
		updateColors $win
	    }
	    return ""
	}

	default {
	    #
	    # Command: $win xview moveto <fraction>
	    #	       $win xview scroll <number> units|pages
	    #
	    set argList [mwutil::getScrollInfo $argList]
	    if {$data(-titlecolumns) == 0} {
		foreach w [list $data(hdrTxt) $data(body)] {
		    eval [list $w xview] $argList
		}
	    } else {
		if {[string compare [lindex $argList 0] "moveto"] == 0} {
		    #
		    # Compute the new scrolled column offset
		    #
		    set fraction [lindex $argList 1]
		    set scrlContentWidth \
			[getScrlContentWidth $win 0 $data(lastCol)]
		    set pixels [expr {int($fraction*$scrlContentWidth + 0.5)}]
		    set scrlColOffset [scrlXOffsetToColOffset $win $pixels]

		    #
		    # Increase the new scrolled column offset if necessary
		    #
		    if {$pixels + [getScrlWindowWidth $win] >=
			$scrlContentWidth} {
			incr scrlColOffset
		    }

		    changeScrlColOffset $win $scrlColOffset
		} else {
		    set number [lindex $argList 1]
		    if {[string compare [lindex $argList 2] "units"] == 0} {
			changeScrlColOffset $win \
			    [expr {$data(scrlColOffset) + $number}]
		    } else {
			#
			# Compute the new scrolled column offset
			#
			set scrlXOffset \
			    [scrlColOffsetToXOffset $win $data(scrlColOffset)]
			set scrlWindowWidth [getScrlWindowWidth $win]
			set deltaPixels [expr {$number*$scrlWindowWidth}]
			set pixels [expr {$scrlXOffset + $deltaPixels}]
			set scrlColOffset [scrlXOffsetToColOffset $win $pixels]

			#
			# Adjust the new scrolled column offset if necessary
			#
			if {$number < 0 &&
			    [getScrlContentWidth $win $scrlColOffset \
			     $data(lastCol)] -
			    [getScrlContentWidth $win $data(scrlColOffset) \
			     $data(lastCol)] > -$deltaPixels} {
			    incr scrlColOffset
			}
			if {$scrlColOffset == $data(scrlColOffset)} {
			    if {$number < 0} {
				incr scrlColOffset -1
			    } elseif {$number > 0} {
				incr scrlColOffset
			    }
			}

			changeScrlColOffset $win $scrlColOffset
		    }
		}
		updateColors $win
	    }
	    variable winSys
	    if {[string compare $winSys "aqua"] == 0 && [winfo viewable $win]} {
		#
		# Work around a Tk bug on Mac OS X Aqua
		#
		if {[winfo exists $data(bodyFr)]} {
		    lower $data(bodyFr)
		    raise $data(bodyFr)
		}
	    }
	    return ""
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::yviewSubCmd
#------------------------------------------------------------------------------
proc tablelist::yviewSubCmd {win argList} {
    set argCount [llength $argList]
    if {$argCount != 1 || [lindex $argList 0] != 0} {
	synchronize $win
	displayItems $win
    }
    upvar ::tablelist::ns${win}::data data
    set w $data(body)

    switch $argCount {
	0 {
	    #
	    # Command: $win yview
	    #
	    set totalViewableCount \
		[expr {$data(itemCount) - $data(nonViewableRowCount)}]
	    if {$totalViewableCount == 0} {
		return [list 0 1]
	    }
	    set topTextIdx [$w index @0,0]
	    set btmTextIdx [$w index @0,$data(btmY)]
	    set topRow [expr {int($topTextIdx) - 1}]
	    set btmRow [expr {int($btmTextIdx) - 1}]
	    if {$btmRow > $data(lastRow)} {		;# text widget bug
		set btmRow $data(lastRow)
	    }
	    foreach {x y width height baselinePos} [$w dlineinfo $topTextIdx] {}
	    if {$y < 0} {
		incr topRow	;# top row incomplete in vertical direction
	    }
	    foreach {x y width height baselinePos} [$w dlineinfo $btmTextIdx] {}
	    set y2 [expr {$y + $height}]
	    if {[string compare [$w index @0,$y] [$w index @0,$y2]] == 0} {
		incr btmRow -1	;# btm row incomplete in vertical direction
	    }
	    set upperViewableCount \
		[getViewableRowCount $win 0 [expr {$topRow - 1}]]
	    set winViewableCount [getViewableRowCount $win $topRow $btmRow]
	    set fraction1 [expr {$upperViewableCount/
				 double($totalViewableCount)}]
	    set fraction2 [expr {($upperViewableCount + $winViewableCount)/
				 double($totalViewableCount)}]
	    return [list [format "%g" $fraction1] [format "%g" $fraction2]]
	}

	1 {
	    #
	    # Command: $win yview <units>
	    #
	    set units [format "%d" [lindex $argList 0]]
	    set row [viewableRowOffsetToRowIndex $win $units]
	    $w yview $row
	    adjustElidedText $win
	    redisplayVisibleItems $win
	    updateColors $win
	    adjustSepsWhenIdle $win
	    updateVScrlbarWhenIdle $win
	    return ""
	}

	default {
	    #
	    # Command: $win yview moveto <fraction>
	    #	       $win yview scroll <number> units|pages
	    #
	    set argList [mwutil::getScrollInfo $argList]
	    if {[string compare [lindex $argList 0] "moveto"] == 0} {
		set data(fraction) [lindex $argList 1]
		if {![info exists data(moveToId)]} {
		    set data(moveToId) [after 1 [list tablelist::moveTo $win]]
		}
		return ""
	    } else {
		set number [lindex $argList 1]
		if {[string compare [lindex $argList 2] "units"] == 0} {
		    set topRow [expr {int([$w index @0,0]) - 1}]
		    set upperViewableCount \
			[getViewableRowCount $win 0 [expr {$topRow - 1}]]
		    set offset [expr {$upperViewableCount + $number}]
		    set row [viewableRowOffsetToRowIndex $win $offset]
		    $w yview $row
		} else {
		    set absNumber [expr {abs($number)}]
		    for {set n 0} {$n < $absNumber} {incr n} {
			set topRow [expr {int([$w index @0,0]) - 1}]
			set btmRow [expr {int([$w index @0,$data(btmY)]) - 1}]
			if {$btmRow > $data(lastRow)} {	;# text widget bug
			    set btmRow $data(lastRow)
			}
			set upperViewableCount \
			    [getViewableRowCount $win 0 [expr {$topRow - 1}]]
			set winViewableCount \
			    [getViewableRowCount $win $topRow $btmRow]
			set delta [expr {$winViewableCount - 2}]
			if {$number < 0} {
			    set delta [expr {(-1)*$delta}]
			}
			set offset [expr {$upperViewableCount + $delta}]
			set row [viewableRowOffsetToRowIndex $win $offset]
			$w yview $row
		    }
		}

		adjustElidedText $win
		redisplayVisibleItems $win
		updateColors $win
		adjustSepsWhenIdle $win
		updateVScrlbarWhenIdle $win
		return ""
	    }
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::cellSelection
#
# Processes the tablelist cellselection subcommand.
#------------------------------------------------------------------------------
proc tablelist::cellSelection {win opt firstRow firstCol lastRow lastCol} {
    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled) && [string compare $opt "includes"] != 0} {
	return ""
    }

    switch $opt {
	anchor {
	    #
	    # Adjust the row and column indices to fit
	    # within the existing viewable elements
	    #
	    adjustRowIndex $win firstRow 1
	    adjustColIndex $win firstCol 1

	    set data(anchorRow) $firstRow
	    set data(anchorCol) $firstCol
	    return ""
	}

	clear {
	    #
	    # Adjust the row and column indices
	    # to fit within the existing elements
	    #
	    if {$data(itemCount) == 0 || $data(colCount) == 0} {
		return ""
	    }
	    adjustRowIndex $win firstRow
	    adjustColIndex $win firstCol
	    adjustRowIndex $win lastRow
	    adjustColIndex $win lastCol

	    #
	    # Swap the indices if necessary
	    #
	    if {$lastRow < $firstRow} {
		set tmp $firstRow
		set firstRow $lastRow
		set lastRow $tmp
	    }
	    if {$lastCol < $firstCol} {
		set tmp $firstCol
		set firstCol $lastCol
		set lastCol $tmp
	    }

	    set fromTextIdx [expr {$firstRow + 1}].0
	    set toTextIdx [expr {$lastRow + 1}].end

	    #
	    # Find the (partly) selected lines of the body text widget
	    # in the text range specified by the two cell indices
	    #
	    set w $data(body)
	    variable canElide
	    variable elide
	    set selRange [$w tag nextrange select $fromTextIdx $toTextIdx]
	    while {[llength $selRange] != 0} {
		set selStart [lindex $selRange 0]
		set line [expr {int($selStart)}]
		set row [expr {$line - 1}]
		set key [lindex $data(keyList) $row]

		#
		# Deselect the relevant elements of the row
		#
		findTabs $win $line $firstCol $lastCol firstTabIdx lastTabIdx
		set textIdx1 $firstTabIdx
		for {set col $firstCol} {$col <= $lastCol} {incr col} {
		    if {$data($col-hide) && !$canElide} {
			continue
		    }

		    set textIdx2 \
			[$w search $elide "\t" $textIdx1+1c $lastTabIdx+1c]+1c
		    $w tag remove select $textIdx1 $textIdx2
		    set textIdx1 $textIdx2
		}

		set selRange \
		    [$w tag nextrange select "$selStart lineend" $toTextIdx]
	    }

	    updateColorsWhenIdle $win
	    return ""
	}

	includes {
	    variable canElide
	    if {$firstRow < 0 || $firstRow > $data(lastRow) || \
		$firstCol < 0 || $firstCol > $data(lastCol) ||
		($data($firstCol-hide) && !$canElide)} {
		return 0
	    }

	    findTabs $win [expr {$firstRow + 1}] $firstCol $firstCol \
		     tabIdx1 tabIdx2
	    if {[lsearch -exact [$data(body) tag names $tabIdx2] select] < 0} {
		return 0
	    } else {
		return 1
	    }
	}

	set {
	    #
	    # Adjust the row and column indices
	    # to fit within the existing elements
	    #
	    if {$data(itemCount) == 0 || $data(colCount) == 0} {
		return ""
	    }
	    adjustRowIndex $win firstRow
	    adjustColIndex $win firstCol
	    adjustRowIndex $win lastRow
	    adjustColIndex $win lastCol

	    #
	    # Swap the indices if necessary
	    #
	    if {$lastRow < $firstRow} {
		set tmp $firstRow
		set firstRow $lastRow
		set lastRow $tmp
	    }
	    if {$lastCol < $firstCol} {
		set tmp $firstCol
		set firstCol $lastCol
		set lastCol $tmp
	    }

	    set w $data(body)
	    variable canElide
	    variable elide
	    for {set row $firstRow; set line [expr {$firstRow + 1}]} \
		{$row <= $lastRow} {set row $line; incr line} {
		#
		# Check whether the row is selectable
		#
		set key [lindex $data(keyList) $row]
		if {[info exists data($key-selectable)]} {
		    continue
		}

		#
		# Select the relevant elements of the row
		#
		findTabs $win $line $firstCol $lastCol firstTabIdx lastTabIdx
		set textIdx1 $firstTabIdx
		for {set col $firstCol} {$col <= $lastCol} {incr col} {
		    if {$data($col-hide) && !$canElide} {
			continue
		    }

		    set textIdx2 \
			[$w search $elide "\t" $textIdx1+1c $lastTabIdx+1c]+1c
		    $w tag add select $textIdx1 $textIdx2
		    set textIdx1 $textIdx2
		}
	    }

	    #
	    # If the selection is exported and there are any selected
	    # cells in the widget then make win the new owner of the
	    # PRIMARY selection and register a callback to be invoked
	    # when it loses ownership of the PRIMARY selection
	    #
	    if {$data(-exportselection) &&
		[llength [$w tag nextrange select 1.0]] != 0} {
		selection own -command \
			[list ::tablelist::lostSelection $win] $win
	    }

	    updateColorsWhenIdle $win
	    return ""
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::colWidth
#
# Processes the tablelist columnwidth subcommand.
#------------------------------------------------------------------------------
proc tablelist::colWidth {win col opt} {
    upvar ::tablelist::ns${win}::data data
    set pixels [lindex $data(colList) [expr {2*$col}]]
    if {$pixels == 0} {				;# convention: dynamic width
	set pixels $data($col-reqPixels)
	if {$data($col-maxPixels) > 0} {
	    if {$pixels > $data($col-maxPixels)} {
		set pixels $data($col-maxPixels)
	    }
	}
    }

    switch -- $opt {
	-requested { return $pixels }
	-stretched { return [expr {$pixels + $data($col-delta)}] }
	-total {
	    return [expr {$pixels + $data($col-delta) + 2*$data(charWidth)}]
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::containingRow
#
# Processes the tablelist containing subcommand.
#------------------------------------------------------------------------------
proc tablelist::containingRow {win y {relOffsetName ""}} {
    upvar ::tablelist::ns${win}::data data
    if {$data(itemCount) == 0} {
	return -1
    }

    set row [rowIndex $win @0,$y 0]
    set w $data(body)
    incr y -[winfo y $w]
    if {$y < 0} {
	return -1
    }

    set dlineinfo [$w dlineinfo [expr {double($row + 1)}]]
    set lineY [lindex $dlineinfo 1]
    set lineHeight [lindex $dlineinfo 3]
    if {[llength $dlineinfo] != 0 && $y < $lineY + $lineHeight} {
	if {[string length $relOffsetName] != 0} {
	    upvar $relOffsetName relOffset
	    if {$y == $lineY + $lineHeight -1} {
		set relOffset 1.0
	    } else {
		set relOffset [expr {double($y - $lineY) / $lineHeight}]
	    }
	}
	return $row
    } else {
	return -1
    }
}

#------------------------------------------------------------------------------
# tablelist::containingCol
#
# Processes the tablelist containingcolumn subcommand.
#------------------------------------------------------------------------------
proc tablelist::containingCol {win x} {
    upvar ::tablelist::ns${win}::data data
    if {$x < [winfo x $data(body)]} {
	return -1
    }

    set col [colIndex $win @$x,0 0]
    if {$col < 0} {
	return -1
    }

    set lbl $data(hdrTxtFrLbl)$col
    if {$x + [winfo rootx $win] < [winfo width $lbl] + [winfo rootx $lbl]} {
	return $col
    } else {
	return -1
    }
}

#------------------------------------------------------------------------------
# tablelist::curCellSelection
#
# Processes the tablelist curcellselection subcommand.  Meaning of the last
# optional argument: 0: all; 1: nonhidden only; 2: viewable only.
#------------------------------------------------------------------------------
proc tablelist::curCellSelection {win {getKeys 0} {constraint 0}} {
    variable canElide
    variable elide
    upvar ::tablelist::ns${win}::data data

    #
    # Find the (partly) selected lines of the body text widget
    #
    set result {}
    set w $data(body)
    for {set selRange [$w tag nextrange select 1.0]} \
	{[llength $selRange] != 0} \
	{set selRange [$w tag nextrange select $selEnd]} {
	foreach {selStart selEnd} $selRange {}
	set line [expr {int($selStart)}]
	set row [expr {$line - 1}]
	if {$getKeys || $constraint != 0} {
	    set key [lindex $data(keyList) $row]
	}
	if {($constraint == 1 && [info exists data($key-hide)]) ||
	    ($constraint == 2 && ([info exists data($key-hide)] ||
	     [info exists data($key-elide)]))} {
	    continue
	}

	#
	# Get the index of the column starting at the text position selStart
	#
	set textIdx $line.0
	for {set col 0} {$col < $data(colCount)} {incr col} {
	    if {$data($col-hide) && !$canElide} {
		continue
	    }

	    if {[$w compare $selStart == $textIdx] ||
		[$w compare $selStart == $textIdx+1c] ||
		[$w compare $selStart == $textIdx+2c]} {
		set firstCol $col
		break
	    } else {
		set textIdx [$w search $elide "\t" $textIdx+1c $selEnd]+1c
	    }
	}

	#
	# Process the columns, starting at the found one
	# and ending just before the text position selEnd
	#
	set textIdx [$w search $elide "\t" $textIdx+1c $selEnd]+1c
	for {set col $firstCol} {$col < $data(colCount)} {incr col} {
	    if {$data($col-hide) && !$canElide} {
		continue
	    }

	    if {$constraint == 0 || !$data($col-hide)} {
		if {$getKeys} {
		    lappend result $key $col
		} else {
		    lappend result $row,$col
		}
	    }
	    if {[$w compare $textIdx == $selEnd]} {
		break
	    } else {
		set textIdx [$w search $elide "\t" $textIdx+1c $selEnd]+1c
	    }
	}
    }

    return $result
}

#------------------------------------------------------------------------------
# tablelist::curSelection
#
# Processes the tablelist curselection subcommand.  Meaning of the optional
# argument: 0: all; 1: nonhidden only; 2: viewable only.
#------------------------------------------------------------------------------
proc tablelist::curSelection {win {constraint 0}} {
    #
    # Find the (partly) selected lines of the body text widget
    #
    set result {}
    upvar ::tablelist::ns${win}::data data
    set w $data(body)
    set selRange [$w tag nextrange select 1.0]
    while {[llength $selRange] != 0} {
	set selStart [lindex $selRange 0]
	set row [expr {int($selStart) - 1}]
	if {$constraint == 0} {
	    lappend result $row
	} else {
	    set key [lindex $data(keyList) $row]
	    if {($constraint == 1 && ![info exists data($key-hide)]) ||
		($constraint == 2 && ![info exists data($key-hide)] &&
		 ![info exists data($key-elide)])} {
		lappend result $row
	    }
	}

	set selRange [$w tag nextrange select "$selStart lineend"]
    }

    return $result
}

#------------------------------------------------------------------------------
# tablelist::deleteRows
#
# Processes the tablelist delete subcommand.
#------------------------------------------------------------------------------
proc tablelist::deleteRows {win first last updateListVar} {
    #
    # Adjust the range to fit within the existing items
    #
    if {$first < 0} {
	set first 0
    }
    upvar ::tablelist::ns${win}::data data \
	  ::tablelist::ns${win}::attribs attribs
    if {$last > $data(lastRow)} {
	set last $data(lastRow)
    }
    if {$last < $first} {
	return ""
    }

    #
    # Increase the last index if necessary, to make sure that all
    # descendants of the corresponding item will get deleted, too
    #
    set lastKey [lindex $data(keyList) $last]
    set last [expr {[nodeRow $win $lastKey end] - 1}]
    set count [expr {$last - $first + 1}]

    #
    # Check whether the width of any dynamic-width
    # column might be affected by the deletion
    #
    set w $data(body)
    if {$count == $data(itemCount)} {
	set colWidthsChanged 1				;# just to save time
	set data(seqNum) -1
	set data(freeKeyList) {}
    } else {
	variable canElide
	set colWidthsChanged 0
	set snipStr $data(-snipstring)
	set row 0
	set itemListRange [lrange $data(itemList) $first $last]
	foreach item $itemListRange {
	    #
	    # Format the item
	    #
	    set key [lindex $item end]
	    set dispItem [lrange $item 0 $data(lastCol)]
	    if {$data(hasFmtCmds)} {
		set dispItem [formatItem $win $key $row $dispItem]
	    }
	    if {[string match "*\t*" $dispItem]} {
		set dispItem [mapTabs $dispItem]
	    }

	    set col 0
	    foreach text $dispItem {pixels alignment} $data(colList) {
		if {($data($col-hide) && !$canElide) || $pixels != 0} {
		    incr col
		    continue
		}

		getAuxData $win $key $col auxType auxWidth
		getIndentData $win $key $col indentWidth
		set cellFont [getCellFont $win $key $col]
		set elemWidth \
		    [getElemWidth $win $text $auxWidth $indentWidth $cellFont]
		if {$elemWidth == $data($col-elemWidth) &&
		    [incr data($col-widestCount) -1] == 0} {
		    set colWidthsChanged 1
		    break
		}

		incr col
	    }

	    if {$colWidthsChanged} {
		break
	    }

	    incr row
	}
    }

    #
    # Delete the given items from the body text widget.  Interestingly,
    # for a large number of items it is much more efficient to delete
    # the lines in chunks than to invoke a global delete command.
    #
    for {set toLine [expr {$last + 2}]; set fromLine [expr {$toLine - 50}]} \
	{$fromLine > $first} {set toLine $fromLine; incr fromLine -50} {
	$w delete [expr {double($fromLine)}] [expr {double($toLine)}]
    }
    set rest [expr {$count % 50}]
    $w delete [expr {double($first + 1)}] [expr {double($first + $rest + 1)}]

    if {$last == $data(lastRow)} {
	#
	# Work around a peculiarity of the text widget:  Hide
	# the newline character that ends the line preceding
	# the first deleted one if it was hidden before
	#
	set textIdx [expr {double($first)}]
	foreach tag {elidedRow hiddenRow} {
	    if {[lsearch -exact [$w tag names $textIdx] $tag] >= 0} {
		$w tag add $tag $first.end
	    }
	}
    }

    #
    # Unset the elements of data corresponding to the deleted items
    #
    for {set row $first} {$row <= $last} {incr row} {
	set item [lindex $data(itemList) $row]
	set key [lindex $item end]
	if {$count != $data(itemCount)} {
	    lappend data(freeKeyList) $key
	}

	foreach opt {-background -foreground -name -selectable
		     -selectbackground -selectforeground} {
	    if {[info exists data($key$opt)]} {
		unset data($key$opt)
	    }
	}

	if {[info exists data($key-font)]} {
	    unset data($key-font)
	    incr data(rowTagRefCount) -1
	}

	set isElided [info exists data($key-elide)]
	set isHidden [info exists data($key-hide)]
	if {$isElided} {
	    unset data($key-elide)
	}
	if {$isHidden} {
	    unset data($key-hide)
	}
	if {$isElided || $isHidden} {
	    incr data(nonViewableRowCount) -1
	}

	if {$count != $data(itemCount)} {
	    #
	    # Remove the key from the list of children of its parent
	    #
	    set parentKey $data($key-parent)
	    if {[info exists data($parentKey-children)]} {
		set childIdx [lsearch -exact $data($parentKey-children) $key]
		set data($parentKey-children) \
		    [lreplace $data($parentKey-children) $childIdx $childIdx]

		#
		# If the parent's list of children has become empty
		# then set its indentation image to the indented one
		#
		set col $data(treeCol)
		if {[llength $data($parentKey-children)] == 0 &&
		    [info exists data($parentKey,$col-indent)]} {
		    collapseSubCmd $win [list $parentKey -partly]
		    set data($parentKey,$col-indent) [strMap \
			{"collapsed" "indented" "expanded" "indented"
			 "Act" "" "Sel" ""} $data($parentKey,$col-indent)]
		    if {[winfo exists $data(body).ind_$parentKey,$col]} {
			$data(body).ind_$parentKey,$col configure -image \
			    $data($parentKey,$col-indent)
		    }
		}
	    }
	}

	foreach prop {-row -parent -children} {
	    unset data($key$prop)
	}

	foreach name [array names attribs $key-*] {
	    unset attribs($name)
	}

	for {set col 0} {$col < $data(colCount)} {incr col} {
	    foreach opt {-background -foreground -editable -editwindow
			 -selectbackground -selectforeground -valign
			 -windowdestroy -windowupdate} {
		if {[info exists data($key,$col$opt)]} {
		    unset data($key,$col$opt)
		}
	    }

	    if {[info exists data($key,$col-font)]} {
		unset data($key,$col-font)
		incr data(cellTagRefCount) -1
	    }

	    if {[info exists data($key,$col-image)]} {
		unset data($key,$col-image)
		incr data(imgCount) -1
	    }

	    if {[info exists data($key,$col-window)]} {
		unset data($key,$col-window)
		unset data($key,$col-reqWidth)
		unset data($key,$col-reqHeight)
		incr data(winCount) -1
	    }

	    if {[info exists data($key,$col-indent)]} {
		unset data($key,$col-indent)
		incr data(indentCount) -1
	    }
	}

	foreach name [array names attribs $key,*-*] {
	    unset attribs($name)
	}
    }

    if {$count == $data(itemCount)} {
	set data(root-children) {}
    }

    #
    # Delete the given items from the internal list
    #
    set data(itemList) [lreplace $data(itemList) $first $last]
    set data(keyList) [lreplace $data(keyList) $first $last]
    incr data(itemCount) -$count

    #
    # Delete the given items from the list variable if needed
    #
    if {$updateListVar} {
	upvar #0 $data(-listvariable) var
	trace vdelete var wu $data(listVarTraceCmd)
	set var [lreplace $var $first $last]
	trace variable var wu $data(listVarTraceCmd)
    }

    #
    # Update the key -> row mapping at idle time if needed
    #
    if {$last != $data(lastRow)} {
	set data(keyToRowMapValid) 0
	if {![info exists data(mapId)]} {
	    set data(mapId) \
		[after idle [list tablelist::updateKeyToRowMap $win]]
	}
    }

    incr data(lastRow) -$count

    #
    # Update the indices anchorRow and activeRow
    #
    if {$first <= $data(anchorRow)} {
	incr data(anchorRow) -$count
	if {$data(anchorRow) < $first} {
	    set data(anchorRow) $first
	}
	adjustRowIndex $win data(anchorRow) 1
    }
    if {$last < $data(activeRow)} {
	set activeRow $data(activeRow)
	incr activeRow -$count
	adjustRowIndex $win activeRow 1
	set data(activeRow) $activeRow
    } elseif {$first <= $data(activeRow)} {
	set activeRow $first
	adjustRowIndex $win activeRow 1
	set data(activeRow) $activeRow
    }

    #
    # Update data(editRow) if the edit window is present
    #
    if {$data(editRow) >= 0} {
	set data(editRow) [keyToRow $win $data(editKey)]
    }

    #
    # Adjust the heights of the body text widget
    # and of the listbox child, if necessary
    #
    if {$data(-height) <= 0} {
	set viewableRowCount \
	    [expr {$data(itemCount) - $data(nonViewableRowCount)}]
	$w configure -height $viewableRowCount
	$data(lb) configure -height $viewableRowCount
    }

    #
    # Invalidate the list of row indices indicating the
    # viewable rows, adjust the columns if necessary, and
    # schedule some operations for execution at idle time
    #
    set data(viewableRowList) {-1}
    if {$colWidthsChanged} {
	adjustColumns $win allCols 1
    }
    makeStripesWhenIdle $win
    showLineNumbersWhenIdle $win
    updateViewWhenIdle $win

    return ""
}

#------------------------------------------------------------------------------
# tablelist::deleteCols
#
# Processes the tablelist deletecolumns subcommand.
#------------------------------------------------------------------------------
proc tablelist::deleteCols {win first last selCellsName} {
    upvar ::tablelist::ns${win}::data data \
	  ::tablelist::ns${win}::attribs attribs $selCellsName selCells

    #
    # Delete the data and attributes corresponding to the given range
    #
    for {set col $first} {$col <= $last} {incr col} {
	if {$data($col-hide)} {
	    incr data(hiddenColCount) -1
	}
	deleteColData $win $col
	deleteColAttribs $win $col
	set selCells [deleteColFromCellList $selCells $col]
    }

    #
    # Shift the elements of data and attribs corresponding to the
    # column indices > last to the left by last - first + 1 positions
    #
    for {set oldCol [expr {$last + 1}]; set newCol $first} \
	{$oldCol < $data(colCount)} {incr oldCol; incr newCol} {
	moveColData data data imgs $oldCol $newCol
	moveColAttribs attribs attribs $oldCol $newCol
	set selCells [replaceColInCellList $selCells $oldCol $newCol]
    }

    #
    # Update the item list
    #
    set newItemList {}
    foreach item $data(itemList) {
	set item [lreplace $item $first $last]
	lappend newItemList $item
    }
    set data(itemList) $newItemList

    #
    # Update the list variable if present
    #
    condUpdateListVar $win

    #
    # Set up and adjust the columns, and rebuild some columns-related lists
    #
    setupColumns $win \
	[lreplace $data(-columns) [expr {3*$first}] [expr {3*$last + 2}]] 1
    makeColFontAndTagLists $win
    makeSortAndArrowColLists $win
    adjustColumns $win {} 1
    updateViewWhenIdle $win

    #
    # Reconfigure the relevant column labels
    #
    for {set col $first} {$col < $data(colCount)} {incr col} {
	reconfigColLabels $win imgs $col
    }

    #
    # Update the indices anchorCol and activeCol
    #
    set count [expr {$last - $first + 1}]
    if {$first <= $data(anchorCol)} {
	incr data(anchorCol) -$count
	if {$data(anchorCol) < $first} {
	    set data(anchorCol) $first
	}
	adjustColIndex $win data(anchorCol) 1
    }
    if {$last < $data(activeCol)} {
	incr data(activeCol) -$count
	adjustColIndex $win data(activeCol) 1
    } elseif {$first <= $data(activeCol)} {
	set data(activeCol) $first
	adjustColIndex $win data(activeCol) 1
    }
}

#------------------------------------------------------------------------------
# tablelist::insertRows
#
# Processes the tablelist insert and insertlist subcommands.
#------------------------------------------------------------------------------
proc tablelist::insertRows {win index argList updateListVar parentKey \
			    childIdx} {
    set argCount [llength $argList]
    if {$argCount == 0} {
	return {}
    }

    upvar ::tablelist::ns${win}::data data
    if {$index < $data(itemCount)} {
	displayItems $win
    }

    if {$index < 0} {
	set index 0
    } elseif {$index > $data(itemCount)} {
	set index $data(itemCount)
    }

    set childCount [llength $data($parentKey-children)]
    if {$childIdx < 0} {
	set childIdx 0
    } elseif {$childIdx > $childCount} {	;# e.g., if $childIdx is "end"
	set childIdx $childCount
    }

    #
    # Insert the items into the internal list
    #
    set result {}
    set appendingItems [expr {$index == $data(itemCount)}]
    set appendingChildren [expr {$childIdx == $childCount}]
    set row $index
    foreach item $argList {
	#
	# Adjust the item
	#
	set item [adjustItem $item $data(colCount)]

	#
	# Insert the item into the list variable if needed
	#
	if {$updateListVar} {
	    upvar #0 $data(-listvariable) var
	    trace vdelete var wu $data(listVarTraceCmd)
	    if {$appendingItems} {
		lappend var $item    		;# this works much faster
	    } else {
		set var [linsert $var $row $item]
	    }
	    trace variable var wu $data(listVarTraceCmd)
	}

	#
	# Get a free key for the new item
	#
	if {[llength $data(freeKeyList)] == 0} {
	    set key k[incr data(seqNum)]
	} else {
	    set key [lindex $data(freeKeyList) 0]
	    set data(freeKeyList) [lrange $data(freeKeyList) 1 end]
	}

	#
	# Insert the extended item into the internal list
	#
	lappend item $key
	if {$appendingItems} {
	    lappend data(itemList) $item	;# this works much faster
	    lappend data(keyList) $key		;# this works much faster
	} else {
	    set data(itemList) [linsert $data(itemList) $row $item]
	    set data(keyList) [linsert $data(keyList) $row $key]
	}

	array set data \
	      [list $key-row $row  $key-parent $parentKey  $key-children {}]

	#
	# Insert the key into the parent's list of children
	#
	if {$appendingChildren} {
	    lappend data($parentKey-children) $key    ;# this works much faster
	} else {
	    set data($parentKey-children) \
		[linsert $data($parentKey-children) $childIdx $key]
	}

	lappend data(rowsToDisplay) $row
	lappend result $key

	incr row
	incr childIdx
    }
    incr data(itemCount) $argCount
    set data(lastRow) [expr {$data(itemCount) - 1}]

    #
    # Update the key -> row mapping at idle time if needed
    #
    if {!$appendingItems} {
	set data(keyToRowMapValid) 0
	if {![info exists data(mapId)]} {
	    set data(mapId) \
		[after idle [list tablelist::updateKeyToRowMap $win]]
	}
    }

    if {![info exists data(dispId)]} {
	#
	# Arrange for the inserted items to be displayed at idle time
	#
	set data(dispId) [after idle [list tablelist::displayItems $win]]
    }

    #
    # Update the indices anchorRow and activeRow
    #
    if {$index <= $data(anchorRow)} {
	incr data(anchorRow) $argCount
	adjustRowIndex $win data(anchorRow) 1
    }
    if {$index <= $data(activeRow)} {
	set activeRow $data(activeRow)
	incr activeRow $argCount
	adjustRowIndex $win activeRow 1
	set data(activeRow) $activeRow
    }

    #
    # Update data(editRow) if the edit window is present
    #
    if {$data(editRow) >= 0} {
	set data(editRow) [keyToRow $win $data(editKey)]
    }

    return $result
}

#------------------------------------------------------------------------------
# tablelist::displayItems
#
# This procedure is invoked either as an idle callback after inserting some
# items into the internal list of the tablelist widget win, or directly, upon
# execution of some widget commands.  It displays the inserted items.
#------------------------------------------------------------------------------
proc tablelist::displayItems win {
    #
    # Nothing to do if there are no items to display
    #
    upvar ::tablelist::ns${win}::data data
    if {![info exists data(dispId)]} {
	return ""
    }

    #
    # Here we are in the case that the procedure was scheduled for
    # execution at idle time.  However, it might have been invoked
    # directly, before the idle time occured; in this case we should
    # cancel the execution of the previously scheduled idle callback.
    #
    after cancel $data(dispId)	;# no harm if data(dispId) is no longer valid
    unset data(dispId)

    #
    # Insert the items into the body text widget
    #
    variable canElide
    variable snipSides
    set w $data(body)
    set widgetFont $data(-font)
    set snipStr $data(-snipstring)
    set padY [expr {[$w cget -spacing1] == 0}]
    set wasEmpty [expr {[llength $data(rowsToDisplay)] == $data(itemCount)}]
    set isEmpty $wasEmpty
    foreach row $data(rowsToDisplay) {
	set line [expr {$row + 1}]
	set item [lindex $data(itemList) $row]
	set key [lindex $item end]

	#
	# Format the item
	#
	set dispItem [lrange $item 0 $data(lastCol)]
	if {$data(hasFmtCmds)} {
	    set dispItem [formatItem $win $key $row $dispItem]
	}
	if {[string match "*\t*" $dispItem]} {
	    set dispItem [mapTabs $dispItem]
	}

	if {$isEmpty} {
	    set isEmpty 0
	} else {
	    $w insert $line.0 "\n"
	}
	if {$data(nonViewableRowCount) != 0} {
	    $w tag remove elidedRow $line.0
	    $w tag remove hiddenRow $line.0
	}
	set multilineData {}
	set col 0
	if {$data(hasColTags)} {
	    set insertArgs {}
	    foreach text $dispItem \
		    colFont $data(colFontList) \
		    colTags $data(colTagsList) \
		    {pixels alignment} $data(colList) {
		if {$data($col-hide) && !$canElide} {
		    incr col
		    continue
		}

		#
		# Update the column width or clip the element if necessary
		#
		set multiline [string match "*\n*" $text]
		if {$pixels == 0} {		;# convention: dynamic width
		    if {$multiline} {
			set list [split $text "\n"]
			set textWidth [getListWidth $win $list $colFont]
		    } else {
			set textWidth \
			    [font measure $colFont -displayof $win $text]
		    }
		    if {$data($col-maxPixels) > 0} {
			if {$textWidth > $data($col-maxPixels)} {
			    set pixels $data($col-maxPixels)
			}
		    }
		    if {$textWidth == $data($col-elemWidth)} {
			incr data($col-widestCount)
		    } elseif {$textWidth > $data($col-elemWidth)} {
			set data($col-elemWidth) $textWidth
			set data($col-widestCount) 1
		    }
		}
		if {$pixels != 0} {
		    incr pixels $data($col-delta)

		    if {$data($col-wrap) && !$multiline} {
			if {[font measure $colFont -displayof $win $text] >
			    $pixels} {
			    set multiline 1
			}
		    }

		    if {$multiline} {
			set list [split $text "\n"]
			set snipSide \
			    $snipSides($alignment,$data($col-changesnipside))
			if {$data($col-wrap)} {
			    set snipSide ""
			}
			set text [joinList $win $list $colFont \
				  $pixels $snipSide $snipStr]
		    }
		}

		lappend insertArgs "\t\t" $colTags
		if {$multiline} {
		    lappend multilineData $col $text $colFont $pixels $alignment
		}
		incr col
	    }

	    #
	    # Insert the item into the body text widget
	    #
	    if {[llength $insertArgs] != 0} {
		eval [list $w insert $line.0] $insertArgs
	    }

	} else {
	    set insertStr ""
	    foreach text $dispItem {pixels alignment} $data(colList) {
		if {$data($col-hide) && !$canElide} {
		    incr col
		    continue
		}

		#
		# Update the column width or clip the element if necessary
		#
		set multiline [string match "*\n*" $text]
		if {$pixels == 0} {		;# convention: dynamic width
		    if {$multiline} {
			set list [split $text "\n"]
			set textWidth [getListWidth $win $list $widgetFont]
		    } else {
			set textWidth \
			    [font measure $widgetFont -displayof $win $text]
		    }
		    if {$data($col-maxPixels) > 0} {
			if {$textWidth > $data($col-maxPixels)} {
			    set pixels $data($col-maxPixels)
			}
		    }
		    if {$textWidth == $data($col-elemWidth)} {
			incr data($col-widestCount)
		    } elseif {$textWidth > $data($col-elemWidth)} {
			set data($col-elemWidth) $textWidth
			set data($col-widestCount) 1
		    }
		}
		if {$pixels != 0} {
		    incr pixels $data($col-delta)

		    if {$data($col-wrap) && !$multiline} {
			if {[font measure $widgetFont -displayof $win $text] >
			    $pixels} {
			    set multiline 1
			}
		    }

		    if {$multiline} {
			set list [split $text "\n"]
			set snipSide \
			    $snipSides($alignment,$data($col-changesnipside))
			if {$data($col-wrap)} {
			    set snipSide ""
			}
			set text [joinList $win $list $widgetFont \
				  $pixels $snipSide $snipStr]
		    }
		}

		append insertStr "\t\t"
		if {$multiline} {
		    lappend multilineData $col $text $widgetFont \
					  $pixels $alignment
		}
		incr col
	    }

	    #
	    # Insert the item into the body text widget
	    #
	    $w insert $line.0 $insertStr
	}

	#
	# Embed the message widgets displaying multiline elements
	#
	foreach {col text font pixels alignment} $multilineData {
	    findTabs $win $line $col $col tabIdx1 tabIdx2
	    set msgScript [list ::tablelist::displayText $win $key \
			   $col $text $font $pixels $alignment]
	    $w window create $tabIdx2 -align top -pady $padY -create $msgScript
	    $w tag add elidedWin $tabIdx2
	}
    }
    unset data(rowsToDisplay)

    #
    # Adjust the heights of the body text widget
    # and of the listbox child, if necessary
    #
    if {$data(-height) <= 0} {
	set viewableRowCount \
	    [expr {$data(itemCount) - $data(nonViewableRowCount)}]
	$w configure -height $viewableRowCount
	$data(lb) configure -height $viewableRowCount
    }

    #
    # Check whether the width of any column has changed
    #
    set colWidthsChanged 0
    set col 0
    foreach {pixels alignment} $data(colList) {
	if {$pixels == 0} {			;# convention: dynamic width
	    if {$data($col-elemWidth) > $data($col-reqPixels)} {
		set data($col-reqPixels) $data($col-elemWidth)
		set colWidthsChanged 1
	    }
	}
	incr col
    }

    #
    # Invalidate the list of row indices indicating the
    # viewable rows, adjust the columns if necessary, and
    # schedule some operations for execution at idle time
    #
    set data(viewableRowList) {-1}
    if {$colWidthsChanged} {
	adjustColumns $win {} 1
    }
    makeStripesWhenIdle $win
    showLineNumbersWhenIdle $win
    updateViewWhenIdle $win

    activeTrace $win data activeRow w
    if {$wasEmpty} {
	$w xview moveto [lindex [$data(hdrTxt) xview] 0]
    }
}

#------------------------------------------------------------------------------
# tablelist::insertCols
#
# Processes the tablelist insertcolumns and insertcolumnlist subcommands.
#------------------------------------------------------------------------------
proc tablelist::insertCols {win colIdx argList} {
    set argCount [llength $argList]
    if {$argCount == 0} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data \
	  ::tablelist::ns${win}::attribs attribs

    #
    # Check the syntax of argList and get the number of columns to be inserted
    #
    variable alignments
    set count 0
    for {set n 0} {$n < $argCount} {incr n} {
	#
	# Check the column width
	#
	format "%d" [lindex $argList $n]    ;# integer check with error message

	#
	# Check whether the column title is present
	#
	if {[incr n] == $argCount} {
	    return -code error "column title missing"
	}

	#
	# Check the column alignment
	#
	set alignment left
	if {[incr n] < $argCount} {
	    set next [lindex $argList $n]
	    if {[isInteger $next]} {
		incr n -1
	    } else {
		mwutil::fullOpt "alignment" $next $alignments
	    }
	}

	incr count
    }

    #
    # Shift the elements of data and attribs corresponding to the
    # column indices >= colIdx to the right by count positions
    #
    set selCells [curCellSelection $win]
    for {set oldCol $data(lastCol); set newCol [expr {$oldCol + $count}]} \
	{$oldCol >= $colIdx} {incr oldCol -1; incr newCol -1} {
	moveColData data data imgs $oldCol $newCol
	moveColAttribs attribs attribs $oldCol $newCol
	set selCells [replaceColInCellList $selCells $oldCol $newCol]
    }

    #
    # Update the item list
    #
    set emptyStrs {}
    for {set n 0} {$n < $count} {incr n} {
	lappend emptyStrs ""
    }
    set newItemList {}
    foreach item $data(itemList) {
	set item [eval [list linsert $item $colIdx] $emptyStrs]
	lappend newItemList $item
    }
    set data(itemList) $newItemList

    #
    # Update the list variable if present
    #
    condUpdateListVar $win

    #
    # Set up and adjust the columns, and rebuild some columns-related lists
    #
    setupColumns $win \
	[eval [list linsert $data(-columns) [expr {3*$colIdx}]] $argList] 1
    makeColFontAndTagLists $win
    makeSortAndArrowColLists $win
    set limit [expr {$colIdx + $count}]
    set colIdxList {}
    for {set col $colIdx} {$col < $limit} {incr col} {
	lappend colIdxList $col
    }
    adjustColumns $win $colIdxList 1

    #
    # Redisplay the items
    #
    redisplay $win 0 $selCells

    #
    # Reconfigure the relevant column labels
    #
    for {set col $limit} {$col < $data(colCount)} {incr col} {
	reconfigColLabels $win imgs $col
    }

    #
    # Update the indices anchorCol and activeCol
    #
    if {$colIdx <= $data(anchorCol)} {
	incr data(anchorCol) $argCount
	adjustColIndex $win data(anchorCol) 1
    }
    if {$colIdx <= $data(activeCol)} {
	incr data(activeCol) $argCount
	adjustColIndex $win data(activeCol) 1
    }

    updateViewWhenIdle $win
    return ""
}

#------------------------------------------------------------------------------
# tablelist::doScan
#
# Processes the tablelist scan subcommand.
#------------------------------------------------------------------------------
proc tablelist::doScan {win opt x y} {
    upvar ::tablelist::ns${win}::data data
    set w $data(body)
    incr x -[winfo x $w]
    incr y -[winfo y $w]

    if {$data(-titlecolumns) == 0} {
	set textIdx [$data(body) index @0,$y]
	set row [expr {int($textIdx) - 1}]
	$w scan $opt $x $y
	$data(hdrTxt) scan $opt $x 0

	if {[string compare $opt "dragto"] == 0} {
	    adjustElidedText $win
	    redisplayVisibleItems $win
	    updateColors $win
	    adjustSepsWhenIdle $win
	    updateVScrlbarWhenIdle $win
	}
    } elseif {[string compare $opt "mark"] == 0} {
	$w scan mark 0 $y

	set data(scanMarkX) $x
	set data(scanMarkXOffset) \
	    [scrlColOffsetToXOffset $win $data(scrlColOffset)]
    } else {
	set textIdx [$data(body) index @0,$y]
	set row [expr {int($textIdx) - 1}]
	$w scan dragto 0 $y

	#
	# Compute the new scrolled x offset by amplifying the
	# difference between the current horizontal position and
	# the place where the scan started (the "mark" position)
	#
	set scrlXOffset \
	    [expr {$data(scanMarkXOffset) - 10*($x - $data(scanMarkX))}]
	set maxScrlXOffset [scrlColOffsetToXOffset $win \
			    [getMaxScrlColOffset $win]]
	if {$scrlXOffset > $maxScrlXOffset} {
	    set scrlXOffset $maxScrlXOffset
	    set data(scanMarkX) $x
	    set data(scanMarkXOffset) $maxScrlXOffset
	} elseif {$scrlXOffset < 0} {
	    set scrlXOffset 0
	    set data(scanMarkX) $x
	    set data(scanMarkXOffset) 0
	}

	#
	# Change the scrolled column offset and adjust the elided text
	#
	changeScrlColOffset $win [scrlXOffsetToColOffset $win $scrlXOffset]
	adjustElidedText $win
	redisplayVisibleItems $win
	updateColors $win
	adjustSepsWhenIdle $win
	updateVScrlbarWhenIdle $win
    }

    return ""
}

#------------------------------------------------------------------------------
# tablelist::populate
#
# Helper procedure invoked in searchcolumnSubCmd.
#------------------------------------------------------------------------------
proc tablelist::populate {win index fully} {
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $index]
    set col $data(treeCol)
    if {![info exists data($key,$col-indent)] ||
	[string match "*indented*" $data($key,$col-indent)]} {
	return ""
    }

    if {[llength $data($key-children)] == 0} {
	uplevel #0 $data(-populatecommand) [list $win $index]
    }

    if {$fully} {
	#
	# Invoke this procedure recursively on the children
	#
	foreach childKey $data($key-children) {
	    populate $win [keyToRow $win $childKey] 1
	}
    }

    return ""
}

#------------------------------------------------------------------------------
# tablelist::doesMatch
#
# Helper procedure invoked in searchcolumnSubCmd.
#------------------------------------------------------------------------------
proc doesMatch {win row col pattern value mode numeric noCase checkCmd} {
    switch -- $mode {
	-exact {
	    if {$numeric} {
		set result [expr {$pattern == $value}]
	    } else {
		if {$noCase} {
		    set value [string tolower $value]
		}
		set result [expr {[string compare $pattern $value] == 0}]
	    }
	}

	-glob {
	    if {$noCase} {
		set value [string tolower $value]
	    }
	    set result [string match $pattern $value]
	}

	-regexp {
	    if {$noCase} {
		set result [regexp -nocase $pattern $value]
	    } else {
		set result [regexp $pattern $value]
	    }
	}
    }

    if {!$result || [string length $checkCmd] == 0} {
	return $result
    } else {
	return [uplevel #0 $checkCmd [list $win $row $col $value]]
    }
}

#------------------------------------------------------------------------------
# tablelist::seeRow
#
# Processes the tablelist see subcommand.
#------------------------------------------------------------------------------
proc tablelist::seeRow {win index} {
    #
    # Adjust the index to fit within the existing items
    #
    adjustRowIndex $win index
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $index]
    if {$data(itemCount) == 0 || [info exists data($key-hide)]} {
	return ""
    }

    #
    # Expand as many ancestors as needed
    #
    while {[info exists data($key-elide)]} {
	set key $data($key-parent)
	expandSubCmd $win [list $key -partly]
    }

    #
    # Bring the given row into the window and restore
    # the horizontal view in the body text widget
    #
    $data(body) see [expr {double($index + 1)}]
    $data(body) xview moveto [lindex [$data(hdrTxt) xview] 0]

    updateView $win
    return ""
}

#------------------------------------------------------------------------------
# tablelist::seeCell
#
# Processes the tablelist seecell subcommand.
#------------------------------------------------------------------------------
proc tablelist::seeCell {win row col} {
    #
    # This might be an "after idle" callback; check whether the window exists
    #
    if {![array exists ::tablelist::ns${win}::data]} {
	return ""
    }

    #
    # Adjust the row and column indices to fit within the existing elements
    #
    adjustRowIndex $win row
    adjustColIndex $win col
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    if {[info exists data($key-hide)] ||
	($data(colCount) != 0 && $data($col-hide))} {
	return ""
    }

    #
    # Expand as many ancestors as needed
    #
    while {[info exists data($key-elide)]} {
	set key $data($key-parent)
	expandSubCmd $win [list $key -partly]
    }

    set b $data(body)
    if {$data(colCount) == 0} {
	$b see [expr {double($row + 1)}]
	return ""
    }

    #
    # Force any geometry manager calculations to be completed first
    #
    update idletasks
    if {![array exists ::tablelist::ns${win}::data]} {
	return ""
    }

    #
    # If the tablelist is empty then insert a temporary row
    #
    set h $data(hdrTxt)
    if {$data(itemCount) == 0} {
	variable canElide
	for {set n 0} {$n < $data(colCount)} {incr n} {
	    if {!$data($n-hide) || $canElide} {
		$b insert end "\t\t"
	    }
	}

	$b xview moveto [lindex [$h xview] 0]
    }

    if {$data(-titlecolumns) == 0} {
	findTabs $win [expr {$row + 1}] $col $col tabIdx1 tabIdx2
	set nextIdx [$b index $tabIdx2+1c]
	set alignment [lindex $data(colList) [expr {2*$col + 1}]]
	set lX [winfo x $data(hdrTxtFrLbl)$col]
	set rX [expr {$lX + [winfo width $data(hdrTxtFrLbl)$col] - 1}]

	switch $alignment {
	    left {
		#
		# Bring the cell's left edge into view
		#
		$b see $tabIdx1
		$h xview moveto [lindex [$b xview] 0]

		#
		# Shift the view in the header text widget until the right
		# edge of the cell becomes visible but finish the scrolling
		# before the cell's left edge would become invisible
		#
		while {![isHdrTxtFrXPosVisible $win $rX]} {
		    $h xview scroll 1 units
		    if {![isHdrTxtFrXPosVisible $win $lX]} {
			$h xview scroll -1 units
			break
		    }
		}
	    }

	    center {
		#
		# Bring the cell's left edge into view
		#
		$b see $tabIdx1
		set winWidth [winfo width $h]
		if {[winfo width $data(hdrTxtFrLbl)$col] > $winWidth} {
		    #
		    # The cell doesn't fit into the window:  Bring its
		    # center into the window's middle horizontal position
		    #
		    $h xview moveto \
		       [expr {double($lX + $rX - $winWidth)/2/$data(hdrPixels)}]
		} else {
		    #
		    # Shift the view in the header text widget until
		    # the right edge of the cell becomes visible
		    #
		    $h xview moveto [lindex [$b xview] 0]
		    while {![isHdrTxtFrXPosVisible $win $rX]} {
			$h xview scroll 1 units
		    }
		}
	    }

	    right {
		#
		# Bring the cell's right edge into view
		#
		$b see $nextIdx
		$h xview moveto [lindex [$b xview] 0]

		#
		# Shift the view in the header text widget until the left
		# edge of the cell becomes visible but finish the scrolling
		# before the cell's right edge would become invisible
		#
		while {![isHdrTxtFrXPosVisible $win $lX]} {
		    $h xview scroll -1 units
		    if {![isHdrTxtFrXPosVisible $win $rX]} {
			$h xview scroll 1 units
			break
		    }
		}
	    }
	}

	$b xview moveto [lindex [$h xview] 0]

    } else {
	#
	# Bring the cell's row into view
	#
	$b see [expr {double($row + 1)}]

	set scrlWindowWidth [getScrlWindowWidth $win]

	if {($col < $data(-titlecolumns)) ||
	    (!$data($col-elide) &&
	     [getScrlContentWidth $win $data(scrlColOffset) $col] <=
	     $scrlWindowWidth)} {
	    #
	    # The given column index specifies either a title column or
	    # one that is fully visible; restore the horizontal view
	    #
	    $b xview moveto [lindex [$h xview] 0]
	} elseif {$data($col-elide) ||
		  [winfo width $data(hdrTxtFrLbl)$col] > $scrlWindowWidth} {
	    #
	    # The given column index specifies either an elided column or one
	    # that doesn't fit into the window; shift the horizontal view to
	    # make the column the first visible one among all scrollable columns
	    #
	    set scrlColOffset 0
	    for {incr col -1} {$col >= $data(-titlecolumns)} {incr col -1} {
		if {!$data($col-hide)} {
		    incr scrlColOffset
		}
	    }
	    changeScrlColOffset $win $scrlColOffset
	} else {
	    #
	    # The given column index specifies a non-elided
	    # scrollable column; shift the horizontal view
	    # repeatedly until the column becomes visible
	    #
	    set scrlColOffset [expr {$data(scrlColOffset) + 1}]
	    while {[getScrlContentWidth $win $scrlColOffset $col] >
		   $scrlWindowWidth} {
		incr scrlColOffset
	    }
	    changeScrlColOffset $win $scrlColOffset
	}
    }

    #
    # Delete the temporary row if any
    #
    if {$data(itemCount) == 0} {
	$b delete 1.0 end
    }

    updateView $win
    return ""
}

#------------------------------------------------------------------------------
# tablelist::rowSelection
#
# Processes the tablelist selection subcommand.
#------------------------------------------------------------------------------
proc tablelist::rowSelection {win opt first last} {
    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled) && [string compare $opt "includes"] != 0} {
	return ""
    }

    switch $opt {
	anchor {
	    #
	    # Adjust the index to fit within the existing viewable items
	    #
	    adjustRowIndex $win first 1

	    set data(anchorRow) $first
	    return ""
	}

	clear {
	    #
	    # Swap the indices if necessary
	    #
	    if {$last < $first} {
		set tmp $first
		set first $last
		set last $tmp
	    }

	    set fromTextIdx [expr {$first + 1}].0
	    set toTextIdx [expr {$last + 1}].end
	    $data(body) tag remove select $fromTextIdx $toTextIdx

	    updateColorsWhenIdle $win
	    return ""
	}

	includes {
	    set w $data(body)
	    set line [expr {$first + 1}]
	    set selRange [$w tag nextrange select $line.0 $line.end]
	    return [expr {[llength $selRange] > 0}]
	}

	set {
	    #
	    # Swap the indices if necessary and adjust
	    # the range to fit within the existing items
	    #
	    if {$last < $first} {
		set tmp $first
		set first $last
		set last $tmp
	    }
	    if {$first < 0} {
		set first 0
	    }
	    if {$last > $data(lastRow)} {
		set last $data(lastRow)
	    }

	    set w $data(body)
	    variable canElide
	    variable elide
	    for {set row $first; set line [expr {$first + 1}]} \
		{$row <= $last} {set row $line; incr line} {
		#
		# Check whether the row is selectable
		#
		set key [lindex $data(keyList) $row]
		if {![info exists data($key-selectable)]} {
		    $w tag add select $line.0 $line.end
		}
	    }

	    #
	    # If the selection is exported and there are any selected
	    # cells in the widget then make win the new owner of the
	    # PRIMARY selection and register a callback to be invoked
	    # when it loses ownership of the PRIMARY selection
	    #
	    if {$data(-exportselection) &&
		[llength [$w tag nextrange select 1.0]] != 0} {
		selection own -command \
			[list ::tablelist::lostSelection $win] $win
	    }

	    updateColorsWhenIdle $win
	    return ""
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::moveTo
#
# Adjusts the view in the tablelist window win so that the non-hidden item
# given by data(fraction) appears at the top of the window.  
#------------------------------------------------------------------------------
proc tablelist::moveTo win {
    upvar ::tablelist::ns${win}::data data
    if {[info exists data(moveToId)]} {
	after cancel $data(moveToId)
	unset data(moveToId)
    }

    set totalViewableCount \
	[expr {$data(itemCount) - $data(nonViewableRowCount)}]
    set offset [expr {int($data(fraction)*$totalViewableCount + 0.5)}]
    set row [viewableRowOffsetToRowIndex $win $offset]

    set w $data(body)
    set topTextIdx [$w index @0,0]
    set topRow [expr {int($topTextIdx) - 1}]
    foreach {x y width height baselinePos} [$w dlineinfo $topTextIdx] {}
    if {$y < 0} {
	incr topRow	;# top row incomplete in vertical direction
    }

    if {$row != $topRow} {
	$w yview $row
	updateView $win
    }

    return ""
}

#
# Private callback procedures
# ===========================
#

#------------------------------------------------------------------------------
# tablelist::fetchSelection
#
# This procedure is invoked when the PRIMARY selection is owned by the
# tablelist widget win and someone attempts to retrieve it as a STRING.  It
# returns part or all of the selection, as given by offset and maxChars.  The
# string which is to be (partially) returned is built by joining all of the
# selected viewable elements of the (partly) selected viewable rows together
# with tabs and the rows themselves with newlines.
#------------------------------------------------------------------------------
proc tablelist::fetchSelection {win offset maxChars} {
    upvar ::tablelist::ns${win}::data data
    if {!$data(-exportselection)} {
	return ""
    }

    set selection ""
    set prevRow -1
    foreach cellIdx [curCellSelection $win 0 2] {
	scan $cellIdx "%d,%d" row col
	if {$row != $prevRow} {
	    if {$prevRow != -1} {
		append selection "\n"
	    }

	    set prevRow $row
	    set item [lindex $data(itemList) $row]
	    set key [lindex $item end]
	    set isFirstCol 1
	}

	set text [lindex $item $col]
	if {[lindex $data(fmtCmdFlagList) $col]} {
	    set text [formatElem $win $key $row $col $text]
	}

	if {!$isFirstCol} {
	    append selection "\t"
	}
	append selection $text

	set isFirstCol 0
    }

    return [string range $selection $offset [expr {$offset + $maxChars - 1}]]
}

#------------------------------------------------------------------------------
# tablelist::lostSelection
#
# This procedure is invoked when the tablelist widget win loses ownership of
# the PRIMARY selection.  It deselects all items of the widget with the aid of
# the rowSelection procedure if the selection is exported.
#------------------------------------------------------------------------------
proc tablelist::lostSelection win {
    upvar ::tablelist::ns${win}::data data
    if {$data(-exportselection)} {
	rowSelection $win clear 0 $data(lastRow)
	event generate $win <<TablelistSelectionLost>>
    }
}

#------------------------------------------------------------------------------
# tablelist::activeTrace
#
# This procedure is executed whenever the array element data(activeRow),
# data(activeCol), or data(-selecttype) is written.  It moves the "active" tag
# to the line or cell that displays the active item or element of the widget in
# its body text child if the latter has the keyboard focus.
#------------------------------------------------------------------------------
proc tablelist::activeTrace {win varName index op} {
    #
    # Conditionally move the "active" tag to the line
    # or cell that displays the active item or element
    #
    upvar ::tablelist::ns${win}::data data
    if {$data(ownsFocus) && ![info exists data(dispId)]} {
	moveActiveTag $win
    }
}

#------------------------------------------------------------------------------
# tablelist::listVarTrace
#
# This procedure is executed whenever the global variable specified by varName
# is written or unset.  It makes sure that the contents of the widget will be
# synchronized with the value of the variable at idle time, and that the
# variable is recreated if it was unset.
#------------------------------------------------------------------------------
proc tablelist::listVarTrace {win varName index op} {
    upvar ::tablelist::ns${win}::data data
    switch $op {
	w {
	    if {![info exists data(syncId)]} {
		#
		# Arrange for the contents of the widget to be synchronized
		# with the value of the variable ::$varName at idle time
		#
		set data(syncId) [after idle [list tablelist::synchronize $win]]
	    }
	}

	u {
	    #
	    # Recreate the variable ::$varName by setting it according to
	    # the value of data(itemList), and set the trace on it again
	    #
	    if {[string length $index] != 0} {
		set varName ${varName}($index)
	    }
	    set ::$varName {}
	    foreach item $data(itemList) {
		lappend ::$varName [lrange $item 0 $data(lastCol)]
	    }
	    trace variable ::$varName wu $data(listVarTraceCmd)
	}
    }
}
