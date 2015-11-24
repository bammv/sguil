#==============================================================================
# Contains public and private procedures used in tablelist bindings.
#
# Structure of the module:
#   - Public helper procedures
#   - Binding tag Tablelist
#   - Binding tag TablelistWindow
#   - Binding tag TablelistBody
#   - Binding tags TablelistLabel, TablelistSubLabel, and TablelistArrow
#
# Copyright (c) 2000-2015  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

#
# Public helper procedures
# ========================
#

#------------------------------------------------------------------------------
# tablelist::getTablelistColumn
#
# Gets the column number from the path name w of a (sub)label or sort arrow of
# a tablelist widget.
#------------------------------------------------------------------------------
proc tablelist::getTablelistColumn w {
    if {[regexp {^(\..+)\.hdr\.t\.f\.l([0-9]+)(-[it]l)?$} $w dummy win col] ||
	[regexp {^(\..+)\.hdr\.t\.f\.c([0-9]+)$} $w dummy win col]} {
	return $col
    } else {
	return -1
    }
}

#------------------------------------------------------------------------------
# tablelist::getTablelistPath
#
# Gets the path name of the tablelist widget from the path name w of one of its
# descendants.  It is assumed that all of the ancestors of w exist (but w
# itself needn't exist).
#------------------------------------------------------------------------------
proc tablelist::getTablelistPath w {
    return [mwutil::getAncestorByClass $w Tablelist]
}

#------------------------------------------------------------------------------
# tablelist::convEventFields
#
# Gets the path name of the tablelist widget and the x and y coordinates
# relative to the latter from the path name w of one of its descendants and
# from the x and y coordinates relative to the latter.
#------------------------------------------------------------------------------
proc tablelist::convEventFields {w x y} {
    return [mwutil::convEventFields $w $x $y Tablelist]
}

#
# Binding tag Tablelist
# =====================
#

#------------------------------------------------------------------------------
# tablelist::addActiveTag
#
# This procedure is invoked when the tablelist widget win gains the keyboard
# focus.  It moves the "active" tag to the line or cell that displays the
# active item or element of the widget in its body text child.
#------------------------------------------------------------------------------
proc tablelist::addActiveTag win {
    upvar ::tablelist::ns${win}::data data
    set data(ownsFocus) 1

    #
    # Conditionally move the "active" tag to the line
    # or cell that displays the active item or element
    #
    if {![info exists data(dispId)]} {
	moveActiveTag $win
    }
}

#------------------------------------------------------------------------------
# tablelist::removeActiveTag
#
# This procedure is invoked when the tablelist widget win loses the keyboard
# focus.  It removes the "active" tag from the body text child of the widget.
#------------------------------------------------------------------------------
proc tablelist::removeActiveTag win {
    upvar ::tablelist::ns${win}::data data
    set data(ownsFocus) 0

    $data(body) tag remove curRow 1.0 end
    $data(body) tag remove active 1.0 end
}

#------------------------------------------------------------------------------
# tablelist::cleanup
#
# This procedure is invoked when the tablelist widget win is destroyed.  It
# executes some cleanup operations.
#------------------------------------------------------------------------------
proc tablelist::cleanup win {
    #
    # Cancel the execution of all delayed handleMotion, updateKeyToRowMap,
    # adjustSeps, makeStripes, showLineNumbers, stretchColumns, updateColors,
    # updateScrlColOffset, updateHScrlbar, updateVScrlbar, updateView,
    # synchronize, displayItems, moveTo, autoScan, horizAutoScan, forceRedraw,
    # doCellConfig, redisplay, redisplayCol, and destroyWidgets commands
    #
    upvar ::tablelist::ns${win}::data data
    foreach id {motionId mapId sepsId stripesId lineNumsId stretchId colorsId
		offsetId hScrlbarId vScrlbarId viewId syncId dispId moveToId
		afterId redrawId reconfigId} {
	if {[info exists data($id)]} {
	    after cancel $data($id)
	}
    }
    foreach name [array names data *redispId] {
	after cancel $data($name)
    }
    foreach destroyId $data(destroyIdList) {
	after cancel $destroyId
    }

    #
    # If there is a list variable associated with the
    # widget then remove the trace set on this variable
    #
    upvar #0 $data(-listvariable) var
    if {$data(hasListVar) && [info exists var]} {
	trace vdelete var wu $data(listVarTraceCmd)
    }

    #
    # Destroy any existing bindings for data(bodyTag),
    # data(labelTag), and data(editwinTag)
    #
    foreach event [bind $data(bodyTag)] {
	bind $data(bodyTag) $event ""
    }
    foreach event [bind $data(labelTag)] {
	bind $data(labelTag) $event ""
    }
    foreach event [bind $data(editwinTag)] {
	bind $data(editwinTag) $event ""
    }

    #
    # Delete the bitmaps displaying the sort ranks
    # and the images used to display the sort arrows
    #
    for {set rank 1} {$rank < 10} {incr rank} {
	image delete sortRank$rank$win
    }
    for {set col 0} {$col < $data(colCount)} {incr col} {
	set w $data(hdrTxtFrCanv)$col
	foreach shape {triangleUp darkLineUp lightLineUp
		       triangleDn darkLineDn lightLineDn} {
	    catch {image delete $shape$w}
	}
    }

    destroy $data(corner)

    namespace delete ::tablelist::ns$win
    catch {rename ::$win ""}
}

#------------------------------------------------------------------------------
# tablelist::updateCanvases
#
# This procedure handles the events <Activate> and <Deactivate> by configuring
# the canvases displaying sort arrows.
#------------------------------------------------------------------------------
proc tablelist::updateCanvases win {
    upvar ::tablelist::ns${win}::data data
    foreach col $data(arrowColList) {
	configCanvas $win $col
	raiseArrow $win $col
    }
}

#------------------------------------------------------------------------------
# tablelist::updateConfigSpecs
#
# This procedure handles the virtual event <<ThemeChanged>> by updating the
# theme-specific default values of some tablelist configuration options.
#------------------------------------------------------------------------------
proc tablelist::updateConfigSpecs win {
    #
    # This might be an "after idle" callback; check whether the window exists
    #
    if {![array exists ::tablelist::ns${win}::data]} {
	return ""
    }

    set currentTheme [getCurrentTheme]
    upvar ::tablelist::ns${win}::data data
    if {[string compare $currentTheme $data(currentTheme)] == 0} {
	if {[string compare $currentTheme "tileqt"] == 0} {
	    set widgetStyle [tileqt_currentThemeName]
	    if {[info exists ::env(KDE_SESSION_VERSION)] &&
		[string length $::env(KDE_SESSION_VERSION)] != 0} {
		set colorScheme [getKdeConfigVal "General" "ColorScheme"]
	    } else {
		set colorScheme [getKdeConfigVal "KDE" "colorScheme"]
	    }
	    if {[string compare $widgetStyle $data(widgetStyle)] == 0 &&
		[string compare $colorScheme $data(colorScheme)] == 0} {
		return ""
	    }
	} else {
	    return ""
	}
    }

    #
    # Populate the array tmp with values corresponding to the old theme
    # and the array themeDefaults with values corresponding to the new one
    #
    array set tmp $data(themeDefaults)
    setThemeDefaults

    #
    # Set those configuration options whose values equal the old
    # theme-specific defaults to the new theme-specific ones
    #
    variable themeDefaults
    foreach opt {-background -foreground -disabledforeground -stripebackground
		 -selectbackground -selectforeground -selectborderwidth -font
		 -labelforeground -labelfont -labelborderwidth -labelpady
		 -treestyle} {
	if {[string compare $data($opt) $tmp($opt)] == 0} {
	    doConfig $win $opt $themeDefaults($opt)
	}
    }
    if {[string compare $data(-arrowcolor) $tmp(-arrowcolor)] == 0 &&
	[string compare $data(-arrowstyle) $tmp(-arrowstyle)] == 0} {
	foreach opt {-arrowcolor -arrowdisabledcolor -arrowstyle} {
	    doConfig $win $opt $themeDefaults($opt)
	}
    }
    foreach opt {-background -foreground} {
	doConfig $win $opt $data($opt)	;# sets the bg color of the separators
    }
    updateCanvases $win

    #
    # Destroy and recreate the edit window if present
    #
    if {[set editCol $data(editCol)] >= 0} {
	set editRow $data(editRow)
	saveEditData $win
	destroy $data(bodyFr)
	doEditCell $win $editRow $editCol 1
    }

    #
    # Destroy and recreate the embedded windows
    #
    if {$data(winCount) != 0} {
	for {set row 0} {$row < $data(itemCount)} {incr row} {
	    for {set col 0} {$col < $data(colCount)} {incr col} {
		set key [lindex $data(keyList) $row]
		if {[info exists data($key,$col-window)]} {
		    set val $data($key,$col-window)
		    doCellConfig $row $col $win -window ""
		    doCellConfig $row $col $win -window $val
		}
	    }
	}
    }

    set data(currentTheme) $currentTheme
    set data(themeDefaults) [array get themeDefaults]
    if {[string compare $currentTheme "tileqt"] == 0} {
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

#
# Binding tag TablelistWindow
# ===========================
#

#------------------------------------------------------------------------------
# tablelist::cleanupWindow
#
# This procedure is invoked when a window aux embedded into a tablelist widget
# is destroyed.  It invokes the cleanup script associated with the cell
# containing the window, if any.
#------------------------------------------------------------------------------
proc tablelist::cleanupWindow aux {
    regexp {^(.+)\.body\.frm_(k[0-9]+),([0-9]+)$} $aux dummy win key col
    upvar ::tablelist::ns${win}::data data
    if {[info exists data($key,$col-windowdestroy)]} {
	set row [keyToRow $win $key]
	uplevel #0 $data($key,$col-windowdestroy) [list $win $row $col $aux.w]
    }
}

#
# Binding tag TablelistBody
# =========================
#

#------------------------------------------------------------------------------
# tablelist::defineTablelistBody
#
# Defines the bindings for the binding tag TablelistBody.
#------------------------------------------------------------------------------
proc tablelist::defineTablelistBody {} {
    variable priv
    array set priv {
	x			""
	y			""
	afterId			""
	prevRow			""
	prevCol			""
	prevActExpCollCtrlCell	""
	selection		{}
	selClearPending		0
	selChangePending	0
	justClicked		0
	justReleased		0
	clickedInEditWin	0
	clickedExpCollCtrl	0
    }

    foreach event {<Enter> <Motion> <Leave>} {
	bind TablelistBody $event [format {
	    tablelist::handleMotionDelayed %%W %%x %%y %%X %%Y %%m %s
	} $event]
    }
    bind TablelistBody <Button-1> {
	if {[winfo exists %W]} {
	    foreach {tablelist::W tablelist::x tablelist::y} \
		[tablelist::convEventFields %W %x %y] {}

	    set tablelist::priv(x) $tablelist::x
	    set tablelist::priv(y) $tablelist::y
	    set tablelist::priv(row) [$tablelist::W nearest       $tablelist::y]
	    set tablelist::priv(col) [$tablelist::W nearestcolumn $tablelist::x]
	    set tablelist::priv(justClicked) 1
	    after 300 [list set tablelist::priv(justClicked) 0]
	    set tablelist::priv(clickedInEditWin) 0
	    if {[$tablelist::W cget -setfocus] &&
		[string compare [$tablelist::W cget -state] "normal"] == 0} {
		focus [$tablelist::W bodypath]
	    }
	    if {[tablelist::wasExpCollCtrlClicked %W %x %y]} {
		set tablelist::priv(clickedExpCollCtrl) 1
		if {[string length [$tablelist::W editwinpath]] != 0} {
		    tablelist::doFinishEditing $tablelist::W
		}
	    } else {
		tablelist::condEditContainingCell $tablelist::W \
		    $tablelist::x $tablelist::y
		set tablelist::priv(row) \
		    [$tablelist::W nearest       $tablelist::y]
		set tablelist::priv(col) \
		    [$tablelist::W nearestcolumn $tablelist::x]
		tablelist::condBeginMove $tablelist::W $tablelist::priv(row)
		tablelist::beginSelect $tablelist::W \
		    $tablelist::priv(row) $tablelist::priv(col) 1
	    }
	}
    }
    bind TablelistBody <Double-Button-1> {
	if {[winfo exists %W]} {
	    foreach {tablelist::W tablelist::x tablelist::y} \
		[tablelist::convEventFields %W %x %y] {}

	    if {[$tablelist::W cget -editselectedonly]} {
		tablelist::condEditContainingCell $tablelist::W \
		    $tablelist::x $tablelist::y
	    }
	}
    }
    bind TablelistBody <B1-Motion> {
	if {$tablelist::priv(justClicked)} {
	    continue
	}

	foreach {tablelist::W tablelist::x tablelist::y} \
	    [tablelist::convEventFields %W %x %y] {}

	if {[string length $tablelist::priv(x)] == 0 ||
	    [string length $tablelist::priv(y)] == 0} {
	    set tablelist::priv(x) $tablelist::x
	    set tablelist::priv(y) $tablelist::y
	}
	set tablelist::priv(prevX) $tablelist::priv(x)
	set tablelist::priv(prevY) $tablelist::priv(y)
	set tablelist::priv(x) $tablelist::x
	set tablelist::priv(y) $tablelist::y
	tablelist::condAutoScan $tablelist::W
	if {!$tablelist::priv(clickedExpCollCtrl)} {
	    tablelist::motion $tablelist::W \
		[$tablelist::W nearest       $tablelist::y] \
		[$tablelist::W nearestcolumn $tablelist::x] 1
	    tablelist::condShowTarget $tablelist::W $tablelist::y
	}
    }
    bind TablelistBody <ButtonRelease-1> {
	if {[winfo exists %W]} {
	    foreach {tablelist::W tablelist::x tablelist::y} \
		[tablelist::convEventFields %W %x %y] {}

	    set tablelist::priv(x) ""
	    set tablelist::priv(y) ""
	    after cancel $tablelist::priv(afterId)
	    set tablelist::priv(afterId) ""
	    set tablelist::priv(justReleased) 1
	    after 100 [list set tablelist::priv(justReleased) 0]
	    set tablelist::priv(releasedInEditWin) 0
	    if {!$tablelist::priv(clickedExpCollCtrl)} {
		if {$tablelist::priv(justClicked)} {
		    tablelist::moveOrActivate $tablelist::W \
			$tablelist::priv(row) $tablelist::priv(col) 1
		} else {
		    tablelist::moveOrActivate $tablelist::W \
			[$tablelist::W nearest       $tablelist::y] \
			[$tablelist::W nearestcolumn $tablelist::x] \
			[expr {$tablelist::x >= 0 &&
			       $tablelist::x < [winfo width $tablelist::W] &&
			       $tablelist::y >= [winfo y $tablelist::W.body] &&
			       $tablelist::y < [winfo height $tablelist::W]}]
		}
	    }
	    set tablelist::priv(clickedExpCollCtrl) 0
	    after 100 [list tablelist::condEvalInvokeCmd $tablelist::W]
	}
    }
    bind TablelistBody <Shift-Button-1> {
	foreach {tablelist::W tablelist::x tablelist::y} \
	    [tablelist::convEventFields %W %x %y] {}

	tablelist::beginExtend $tablelist::W \
	    [$tablelist::W nearest       $tablelist::y] \
	    [$tablelist::W nearestcolumn $tablelist::x]
    }
    bind TablelistBody <Control-Button-1> {
	foreach {tablelist::W tablelist::x tablelist::y} \
	    [tablelist::convEventFields %W %x %y] {}

	tablelist::beginToggle $tablelist::W \
	    [$tablelist::W nearest       $tablelist::y] \
	    [$tablelist::W nearestcolumn $tablelist::x]
    }

    bind TablelistBody <Return> {
	tablelist::condEditActiveCell [tablelist::getTablelistPath %W]
    }
    bind TablelistBody <KP_Enter> {
	tablelist::condEditActiveCell [tablelist::getTablelistPath %W]
    }
    bind TablelistBody <Tab> {
	tablelist::nextPrevCell [tablelist::getTablelistPath %W] 1
    }
    bind TablelistBody <Shift-Tab> {
	tablelist::nextPrevCell [tablelist::getTablelistPath %W] -1
    }
    bind TablelistBody <<PrevWindow>> {
	tablelist::nextPrevCell [tablelist::getTablelistPath %W] -1
    }
    bind TablelistBody <plus> {
	tablelist::plusMinus [tablelist::getTablelistPath %W] plus
    }
    bind TablelistBody <minus> {
	tablelist::plusMinus [tablelist::getTablelistPath %W] minus
    }
    bind TablelistBody <KP_Add> {
	tablelist::plusMinus [tablelist::getTablelistPath %W] plus
    }
    bind TablelistBody <KP_Subtract> {
	tablelist::plusMinus [tablelist::getTablelistPath %W] minus
    }

    foreach {virtual event} {
	PrevLine <Up>		 NextLine <Down>
	PrevChar <Left>		 NextChar <Right>
	LineStart <Home>	 LineEnd <End>
	PrevWord <Control-Left>	 NextWord <Control-Right>

	SelectPrevLine <Shift-Up>     SelectNextLine <Shift-Down>
	SelectPrevChar <Shift-Left>   SelectNextChar <Shift-Right>
	SelectLineStart <Shift-Home>  SelectLineEnd <Shift-End>
	SelectAll <Control-slash>     SelectNone <Control-backslash>} {
	if {[llength [event info <<$virtual>>]] == 0} {
	    set eventArr($virtual) $event
	} else {
	    set eventArr($virtual) <<$virtual>>
	}
    }

    bind TablelistBody $eventArr(PrevLine) {
	tablelist::upDown [tablelist::getTablelistPath %W] -1
    }
    bind TablelistBody $eventArr(NextLine) {
	tablelist::upDown [tablelist::getTablelistPath %W] 1
    }
    bind TablelistBody $eventArr(PrevChar) {
	tablelist::leftRight [tablelist::getTablelistPath %W] -1
    }
    bind TablelistBody $eventArr(NextChar) {
	tablelist::leftRight [tablelist::getTablelistPath %W] 1
    }
    bind TablelistBody <Prior> {
	tablelist::priorNext [tablelist::getTablelistPath %W] -1
    }
    bind TablelistBody <Next> {
	tablelist::priorNext [tablelist::getTablelistPath %W] 1
    }
    bind TablelistBody $eventArr(LineStart) {
	tablelist::homeEnd [tablelist::getTablelistPath %W] Home
    }
    bind TablelistBody $eventArr(LineEnd) {
	tablelist::homeEnd [tablelist::getTablelistPath %W] End
    }
    bind TablelistBody <Control-Home> {
	tablelist::firstLast [tablelist::getTablelistPath %W] first
    }
    bind TablelistBody <Control-End> {
	tablelist::firstLast [tablelist::getTablelistPath %W] last
    }
    bind TablelistBody $eventArr(SelectPrevLine) {
	tablelist::extendUpDown [tablelist::getTablelistPath %W] -1
    }
    bind TablelistBody $eventArr(SelectNextLine) {
	tablelist::extendUpDown [tablelist::getTablelistPath %W] 1
    }
    bind TablelistBody $eventArr(SelectPrevChar) {
	tablelist::extendLeftRight [tablelist::getTablelistPath %W] -1
    }
    bind TablelistBody $eventArr(SelectNextChar) {
	tablelist::extendLeftRight [tablelist::getTablelistPath %W] 1
    }
    bind TablelistBody $eventArr(SelectLineStart) {
	tablelist::extendToHomeEnd [tablelist::getTablelistPath %W] Home
    }
    bind TablelistBody $eventArr(SelectLineEnd) {
	tablelist::extendToHomeEnd [tablelist::getTablelistPath %W] End
    }
    bind TablelistBody <Shift-Control-Home> {
	tablelist::extendToFirstLast [tablelist::getTablelistPath %W] first
    }
    bind TablelistBody <Shift-Control-End> {
	tablelist::extendToFirstLast [tablelist::getTablelistPath %W] last
    }
    bind TablelistBody <space> {
	set tablelist::W [tablelist::getTablelistPath %W]

	tablelist::beginSelect $tablelist::W \
	    [$tablelist::W index active] [$tablelist::W columnindex active]
    }
    bind TablelistBody <Select> {
	set tablelist::W [tablelist::getTablelistPath %W]

	tablelist::beginSelect $tablelist::W \
	    [$tablelist::W index active] [$tablelist::W columnindex active]
    }
    bind TablelistBody <Control-Shift-space> {
	set tablelist::W [tablelist::getTablelistPath %W]

	tablelist::beginExtend $tablelist::W \
	    [$tablelist::W index active] [$tablelist::W columnindex active]
    }
    bind TablelistBody <Shift-Select> {
	set tablelist::W [tablelist::getTablelistPath %W]

	tablelist::beginExtend $tablelist::W \
	    [$tablelist::W index active] [$tablelist::W columnindex active]
    }
    bind TablelistBody <Escape> {
	tablelist::cancelSelection [tablelist::getTablelistPath %W]
    }
    bind TablelistBody $eventArr(SelectAll) {
	tablelist::selectAll [tablelist::getTablelistPath %W]
    }
    bind TablelistBody $eventArr(SelectNone) {
	set tablelist::W [tablelist::getTablelistPath %W]

	if {[string compare [$tablelist::W cget -selectmode] "browse"] != 0} {
	    $tablelist::W selection clear 0 end
	    event generate $tablelist::W <<TablelistSelect>>
	}
    }
    foreach pattern {Tab Shift-Tab ISO_Left_Tab hpBackTab} {
	catch {
	    foreach modifier {Control Meta} {
		bind TablelistBody <$modifier-$pattern> [format {
		    mwutil::processTraversal %%W Tablelist <%s>
		} $pattern]
	    }
	}
    }

    variable winSys
    catch {
	if {[string compare $winSys "classic"] == 0 ||
	    [string compare $winSys "aqua"] == 0} {
	    bind TablelistBody <MouseWheel> {
		[tablelist::getTablelistPath %W] yview scroll [expr {-%D}] units
		break
	    }
	    bind TablelistBody <Shift-MouseWheel> {
		[tablelist::getTablelistPath %W] xview scroll [expr {-%D}] units
		break
	    }
	    bind TablelistBody <Option-MouseWheel> {
		[tablelist::getTablelistPath %W] yview scroll \
		    [expr {-10 * %D}] units
		break
	    }
	    bind TablelistBody <Shift-Option-MouseWheel> {
		[tablelist::getTablelistPath %W] xview scroll \
		    [expr {-10 * %D}] units
		break
	    }
	} else {
	    bind TablelistBody <MouseWheel> {
		[tablelist::getTablelistPath %W] yview scroll \
		    [expr {-(%D / 120) * 4}] units
		break
	    }
	    bind TablelistBody <Shift-MouseWheel> {
		[tablelist::getTablelistPath %W] xview scroll \
		    [expr {-(%D / 120) * 4}] units
		break
	    }
	}
    }

    if {[string compare $winSys "x11"] == 0} {
	bind TablelistBody <Button-4> {
	    if {!$tk_strictMotif} {
		[tablelist::getTablelistPath %W] yview scroll -5 units
		break
	    }
	}
	bind TablelistBody <Button-5> {
	    if {!$tk_strictMotif} {
		[tablelist::getTablelistPath %W] yview scroll 5 units
		break
	    }
	}
	bind TablelistBody <Shift-Button-4> {
	    if {!$tk_strictMotif} {
		[tablelist::getTablelistPath %W] xview scroll -5 units
		break
	    }
	}
	bind TablelistBody <Shift-Button-5> {
	    if {!$tk_strictMotif} {
		[tablelist::getTablelistPath %W] xview scroll 5 units
		break
	    }
	}
    }

    foreach event {<Control-Left> <<PrevWord>> <Control-Right> <<NextWord>>
		   <Control-Prior> <Control-Next> <<Copy>>
		   <Button-2> <B2-Motion>} {
	set script [strMap {
	    "%W" "$tablelist::W"  "%x" "$tablelist::x"  "%y" "$tablelist::y"
	} [bind Listbox $event]]

	if {[string length $script] != 0} {
	    bind TablelistBody $event [format {
		if {[winfo exists %%W]} {
		    foreach {tablelist::W tablelist::x tablelist::y} \
			[tablelist::convEventFields %%W %%x %%y] {}
		    %s
		}
	    } $script]
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::invokeMotionHandler
#
# Invokes the procedure handleMotionDelayed for the body of the tablelist
# widget win and the current pointer coordinates.
#------------------------------------------------------------------------------
proc tablelist::invokeMotionHandler win {
    upvar ::tablelist::ns${win}::data data
    set w $data(body)
    set X [winfo pointerx $w]
    set Y [winfo pointery $w]
    if {$X >= 0 && $Y >= 0} {	;# the mouse pointer is on the same screen as w
	set x [expr {$X - [winfo rootx $w]}]
	set y [expr {$Y - [winfo rooty $w]}]
    } else {
	set x -1
	set y -1
    }

    handleMotionDelayed $w $x $y $X $Y "" <Motion>
}

#------------------------------------------------------------------------------
# tablelist::handleMotionDelayed
#
# This procedure is invoked when the mouse pointer enters or leaves the body of
# a tablelist widget or one of its separators, or is moving within it.  It
# schedules the execution of the handleMotion procedure 100 ms later.
#------------------------------------------------------------------------------
proc tablelist::handleMotionDelayed {w x y X Y mode event} {
    set win [getTablelistPath $w]
    upvar ::tablelist::ns${win}::data data
    set data(motionData) [list $w $x $y $X $Y $event]
    if {![info exists data(motionId)]} {
	set data(motionId) [after 100 [list tablelist::handleMotion $win]]
    }

    if {[string compare $event "<Enter>"] == 0 &&
	[string compare $mode "NotifyNormal"] == 0} {
	set data(justEntered) 1
    }
}

#------------------------------------------------------------------------------
# tablelist::handleMotion
#
# Invokes the procedures showOrHideTooltip, updateExpCollCtrl, and updateCursor.
#------------------------------------------------------------------------------
proc tablelist::handleMotion win {
    upvar ::tablelist::ns${win}::data data
    if {[info exists data(motionId)]} {
	after cancel $data(motionId)
	unset data(motionId)
    }

    set data(justEntered) 0

    foreach {w x y X Y event} $data(motionData) {}
    if {![winfo exists $w]} {
	invokeMotionHandler $win
	return ""
    }

    #
    # Get the containing cell from the coordinates relative to the tablelist
    #
    foreach {win _x _y} [convEventFields $w $x $y] {}
    set row [containingRow $win $_y]
    set col [containingCol $win $_x]

    showOrHideTooltip $win $row $col $X $Y
    updateExpCollCtrl $win $w $row $col $x

    #
    # Make sure updateCursor won't change the cursor of an embedded window
    #
    if {[string match "$data(body).frm_k*" $w] &&
	[string compare [winfo parent $w] $data(body)] == 0 &&
	[string compare $event "<Leave>"] != 0} {
	set row -1
	set col -1
    }

    updateCursor $win $row $col
}

#------------------------------------------------------------------------------
# tablelist::showOrHideTooltip
#
# If the pointer has crossed a cell boundary then the procedure removes the old
# tooltip and displays the one corresponding to the new cell.
#------------------------------------------------------------------------------
proc tablelist::showOrHideTooltip {win row col X Y} {
    upvar ::tablelist::ns${win}::data data
    if {[string length $data(-tooltipaddcommand)] == 0 ||
	[string length $data(-tooltipdelcommand)] == 0 ||
	[string compare $row,$col $data(prevCell)] == 0} {
	return ""
    }

    #
    # Remove the old tooltip, if any.  Then, if we are within a
    # cell, display the new tooltip corresponding to that cell.
    #
    event generate $win <Leave>
    catch {uplevel #0 $data(-tooltipdelcommand) [list $win]}
    set data(prevCell) $row,$col
    if {$row >= 0 && $col >= 0} {
	set focus [focus -displayof $win]
	if {[string length $focus] == 0 || [string first $win $focus] != 0 ||
	    [string compare [winfo toplevel $focus] \
	     [winfo toplevel $win]] == 0} {
	    uplevel #0 $data(-tooltipaddcommand) [list $win $row $col]
	    event generate $win <Enter> -rootx $X -rooty $Y
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::updateExpCollCtrl
#
# Activates or deactivates the expand/collapse control under the mouse pointer.
#------------------------------------------------------------------------------
proc tablelist::updateExpCollCtrl {win w row col x} {
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    set indentLabel $data(body).ind_$key,$col

    #
    # Check whether the x coordinate is inside the expand/collapse control
    #
    set inExpCollCtrl 0
    if {[winfo exists $indentLabel]} {
	if {[string compare $w $data(body)] == 0 &&
	    $x < [winfo x $indentLabel] &&
	    [string compare $data($key-parent) "root"] == 0} {
	    set imgName [$indentLabel cget -image]
	    if {[regexp {^tablelist_(.+)_(collapsed|expanded).*Img([0-9]+)$} \
			 $imgName dummy treeStyle mode depth]} {
		#
		# The mouse position is in the tablelist body, to the left
		# of an expand/collapse control of a top-level item:  Handle
		# this like a position inside the expand/collapse control
		#
		set inExpCollCtrl 1
	    }
	} elseif {[string compare $w $indentLabel] == 0} {
	    set imgName [$w cget -image]
	    if {[regexp {^tablelist_(.+)_(collapsed|expanded).*Img([0-9]+)$} \
			 $imgName dummy treeStyle mode depth]} {
		#
		# The mouse position is in an expand/collapse
		# image (which ends with the expand/collapse
		# control):  Check whether it is inside the control
		#
		set baseWidth [image width tablelist_${treeStyle}_collapsedImg]
		if {$x >= [winfo width $w] - $baseWidth - 5} {
		    set inExpCollCtrl 1
		}
	    }
	}
    }

    #
    # Conditionally deactivate the previously activated expand/collapse control
    #
    variable priv
    set prevCellIdx $priv(prevActExpCollCtrlCell)
    if {[string length $prevCellIdx] != 0 &&
	[info exists data($prevCellIdx-indent)] &&
	(!$inExpCollCtrl || [string compare $prevCellIdx $key,$col] != 0) &&
	[winfo exists $data(body).ind_$prevCellIdx]} {
	set data($prevCellIdx-indent) \
	    [strMap {"Act" ""} $data($prevCellIdx-indent)]
	$data(body).ind_$prevCellIdx configure -image $data($prevCellIdx-indent)
	set priv(prevActExpCollCtrlCell) ""
    }

    if {!$inExpCollCtrl || [string compare $prevCellIdx $key,$col] == 0} {
	return ""
    }

    #
    # Activate the expand/collapse control under the mouse pointer
    #
    variable ${treeStyle}_collapsedActImg
    if {[info exists ${treeStyle}_collapsedActImg]} {
	set data($key,$col-indent) [strMap {
	    "SelActImg" "SelActImg" "SelImg" "SelActImg"
	    "ActImg" "ActImg" "Img" "ActImg"
	} $data($key,$col-indent)]
	$indentLabel configure -image $data($key,$col-indent)
	set priv(prevActExpCollCtrlCell) $key,$col
    }
}

#------------------------------------------------------------------------------
# tablelist::updateCursor
#
# Updates the cursor of the body component of the tablelist widget win, over
# the specified cell containing the mouse pointer.
#------------------------------------------------------------------------------
proc tablelist::updateCursor {win row col} {
    upvar ::tablelist::ns${win}::data data
    if {$data(inEditWin)} {
	set cursor $data(-cursor)
    } elseif {$data(-showeditcursor)} {
	if {$data(-editselectedonly) &&
	    ![::$win cellselection includes $row,$col]} {
	    set editable 0
	} else {
	    set editable [expr {$row >= 0 && $col >= 0 &&
			  [isCellEditable $win $row $col]}]
	}

	if {$editable} {
	    if {$row == $data(editRow) && $col == $data(editCol)} {
		set cursor $data(-cursor)
	    } else {
		variable editCursor
		if {![info exists editCursor]} {
		    makeEditCursor 
		}
		set cursor $editCursor
	    }
	} else {
	    set cursor $data(-cursor)
	}

	#
	# Special handling for cell editing with the aid of BWidget
	# ComboBox. Oakley combobox, or Tk menubutton widgets
	#
	if {$data(editRow) >= 0 && $data(editCol) >= 0} {
	    foreach c [winfo children $data(bodyFrEd)] {
		set class [winfo class $c]
		if {([string compare $class "Toplevel"] == 0 ||
		     [string compare $class "Menu"] == 0) &&
		     [winfo ismapped $c]} {
		    set cursor $data(-cursor)
		    break
		}
	    }
	}
    } else {
	set cursor $data(-cursor)
    }

    if {[string compare [$data(body) cget -cursor] $cursor] != 0} {
	$data(body) configure -cursor $cursor
    }
}

#------------------------------------------------------------------------------
# tablelist::makeEditCursor
#
# Creates the platform-specific edit cursor.
#------------------------------------------------------------------------------
proc tablelist::makeEditCursor {} {
    variable editCursor
    variable winSys

    if {[string compare $winSys "win32"] == 0} {
	variable library
	set cursorName "pencil.cur"
	set cursorFile [file join $library scripts $cursorName]
	if {$::tcl_version >= 8.4} {
	    set cursorFile [file normalize $cursorFile]
	}
	set editCursor [list @$cursorFile]

	#
	# Make sure it will work for starpacks, too
	#
	variable helpLabel
	if {[catch {$helpLabel configure -cursor $editCursor}] != 0} {
	    set tempDir $::env(TEMP)
	    file copy -force $cursorFile $tempDir
	    set editCursor [list @[file join $tempDir $cursorName]]
	}
    } else {
	set editCursor pencil
    }
}

#------------------------------------------------------------------------------
# tablelist::wasExpCollCtrlClicked
#
# This procedure is invoked when mouse button 1 is pressed in the body of a
# tablelist widget or in one of its separators.  It checks whether the mouse
# click occurred inside an expand/collapse control.
#------------------------------------------------------------------------------
proc tablelist::wasExpCollCtrlClicked {w x y} {
    foreach {win _x _y} [convEventFields $w $x $y] {}
    set row [containingRow $win $_y]
    set col [containingCol $win $_x]
    upvar ::tablelist::ns${win}::data data
    set key [lindex $data(keyList) $row]
    set indentLabel $data(body).ind_$key,$col
    if {![winfo exists $indentLabel]} {
	return 0
    }

    #
    # Check whether the x coordinate is inside the expand/collapse control
    #
    set inExpCollCtrl 0
    if {[string compare $w $data(body)] == 0 && $x < [winfo x $indentLabel] &&
	[string compare $data($key-parent) "root"] == 0} {
	set imgName [$indentLabel cget -image]
	if {[regexp {^tablelist_(.+)_(collapsed|expanded).*Img([0-9]+)$} \
		     $imgName dummy treeStyle mode depth]} {
	    #
	    # The mouse position is in the tablelist body, to the left
	    # of an expand/collapse control of a top-level item:  Handle
	    # this like a position inside the expand/collapse control
	    #
	    set inExpCollCtrl 1
	}
    } elseif {[string compare $w $indentLabel] == 0} {
	set imgName [$w cget -image]
	if {[regexp {^tablelist_(.+)_(collapsed|expanded).*Img([0-9]+)$} \
		     $imgName dummy treeStyle mode depth]} {
	    #
	    # The mouse position is in an expand/collapse
	    # image (which ends with the expand/collapse
	    # control):  Check whether it is inside the control
	    #
	    set baseWidth [image width tablelist_${treeStyle}_collapsedImg]
	    if {$x >= [winfo width $w] - $baseWidth - 5} {
		set inExpCollCtrl 1
	    }
	}
    }

    if {!$inExpCollCtrl} {
	return 0
    }

    #
    # Save the current vertical position
    #
    set topRow [expr {int([$data(body) index @0,0]) - 1}]

    #
    # Toggle the state of the expand/collapse control
    #
    if {[string compare $mode "collapsed"] == 0} {
	::$win expand $row -partly
    } else {
	::$win collapse $row -partly
    }

    #
    # Restore the saved vertical position
    #
    $data(body) yview $topRow
    updateViewWhenIdle $win

    return 1
}

#------------------------------------------------------------------------------
# tablelist::condEditContainingCell
#
# This procedure is invoked when mouse button 1 is pressed in the body of a
# tablelist widget win or in one of its separators.  If the mouse click
# occurred inside an editable cell and the latter is not already being edited,
# then the procedure starts the interactive editing in that cell.  Otherwise it
# finishes a possibly active cell editing.
#------------------------------------------------------------------------------
proc tablelist::condEditContainingCell {win x y} {
    #
    # Get the containing cell from the coordinates relative to the parent
    #
    set row [containingRow $win $y]
    set col [containingCol $win $x]

    upvar ::tablelist::ns${win}::data data
    if {$data(justEntered) || ($data(-editselectedonly) &&
	![::$win cellselection includes $row,$col])} {
	set editable 0
    } else {
	set editable [expr {$row >= 0 && $col >= 0 &&
		      [isCellEditable $win $row $col]}]
    }

    #
    # The following check is sometimes needed on OS X if
    # editing with the aid of a menubutton is in progress
    #
    variable editCursor
    if {($row != $data(editRow) || $col != $data(editCol)) &&
	$data(-showeditcursor) && [info exists editCursor] &&
	[string compare [$data(body) cget -cursor] $editCursor] != 0} {
	set editable 0
    }

    if {$editable} {
	#
	# Get the coordinates relative to the
	# tablelist body and invoke doEditCell
	#
	set w $data(body)
	incr x -[winfo x $w]
	incr y -[winfo y $w]
	scan [$w index @$x,$y] "%d.%d" line charPos
	doEditCell $win $row $col 0 "" $charPos
    } elseif {$data(editRow) >= 0} {
	#
	# Finish the current editing
	#
	doFinishEditing $win
    }
}

#------------------------------------------------------------------------------
# tablelist::condBeginMove
#
# This procedure is typically invoked on button-1 presses in the body of a
# tablelist widget or in one of its separators.  It begins the process of
# moving the nearest row if the rows are movable and the selection mode is not
# browse or extended.
#------------------------------------------------------------------------------
proc tablelist::condBeginMove {win row} {
    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled) || !$data(-movablerows) || $data(itemCount) == 0 ||
	[string compare $data(-selectmode) "browse"] == 0 ||
	[string compare $data(-selectmode) "extended"] == 0} {
	return ""
    }

    set data(sourceRow) $row
    set sourceKey [lindex $data(keyList) $row]
    set data(sourceEndRow) [nodeRow $win $sourceKey end]
    set data(sourceDescCount) [descCount $win $sourceKey]

    set data(sourceParentKey) $data($sourceKey-parent)
    set data(sourceParentRow) [keyToRow $win $data(sourceParentKey)]
    set data(sourceParentEndRow) [nodeRow $win $data(sourceParentKey) end]

    set topWin [winfo toplevel $win]
    set data(topEscBinding) [bind $topWin <Escape>]
    bind $topWin <Escape> [list tablelist::cancelMove [strMap {"%" "%%"} $win]]
}

#------------------------------------------------------------------------------
# tablelist::beginSelect
#
# This procedure is typically invoked on button-1 presses in the body of a
# tablelist widget or in one of its separators.  It begins the process of
# making a selection in the widget.  Its exact behavior depends on the
# selection mode currently in effect for the widget.
#------------------------------------------------------------------------------
proc tablelist::beginSelect {win row col {checkIfDragSrc 0}} {
    variable priv
    set priv(selClearPending) 0
    set priv(selChangePending) 0

    upvar ::tablelist::ns${win}::data data
    switch $data(-selecttype) {
	row {
	    if {[string compare $data(-selectmode) "multiple"] == 0} {
		if {[::$win selection includes $row]} {
		    if {$checkIfDragSrc && [isDragSrc $win]} {
			set priv(selClearPending) 1
		    } else {
			::$win selection clear $row
		    }
		} else {
		    ::$win selection set $row
		}
	    } else {
		if {[::$win selection includes $row] &&
		    $checkIfDragSrc && [isDragSrc $win]} {
		    set priv(selChangePending) 1
		} else {
		    ::$win selection clear 0 end
		    ::$win selection set $row
		}
		::$win selection anchor $row
		set priv(selection) {}
	    }

	    set priv(prevRow) $row
	}

	cell {
	    if {[string compare $data(-selectmode) "multiple"] == 0} {
		if {[::$win cellselection includes $row,$col]} {
		    if {$checkIfDragSrc && [isDragSrc $win]} {
			set priv(selClearPending) 1
		    } else {
			::$win cellselection clear $row,$col
		    }
		} else {
		    ::$win cellselection set $row,$col
		}
	    } else {
		if {[::$win cellselection includes $row,$col] &&
		    $checkIfDragSrc && [isDragSrc $win]} {
		    set priv(selChangePending) 1
		} else {
		    ::$win cellselection clear 0,0 end
		    ::$win cellselection set $row,$col
		}
		::$win cellselection anchor $row,$col
		set priv(selection) {}
	    }

	    set priv(prevRow) $row
	    set priv(prevCol) $col
	}
    }

    event generate $win <<TablelistSelect>>
}

#------------------------------------------------------------------------------
# tablelist::condAutoScan
#
# This procedure is invoked when the mouse leaves or enters the scrollable part
# of a tablelist widget's body text child while button 1 is down.  It either
# invokes the autoScan procedure or cancels its executon as an "after" command.
#------------------------------------------------------------------------------
proc tablelist::condAutoScan win {
    variable priv
    set w [::$win bodypath]
    set wX [winfo x $w]
    set wY [winfo y $w]
    set wWidth  [winfo width  $w]
    set wHeight [winfo height $w]
    set x [expr {$priv(x) - $wX}]
    set y [expr {$priv(y) - $wY}]
    set prevX [expr {$priv(prevX) - $wX}]
    set prevY [expr {$priv(prevY) - $wY}]
    set minX [minScrollableX $win]

    if {($y >= $wHeight && $prevY < $wHeight) ||
	($y < 0 && $prevY >= 0) ||
	($x >= $wWidth && $prevX < $wWidth) ||
	($x < $minX && $prevX >= $minX)} {
	if {[string length $priv(afterId)] == 0} {
	    autoScan $win
	}
    } elseif {($y < $wHeight && $prevY >= $wHeight) ||
	      ($y >= 0 && $prevY < 0) ||
	      ($x < $wWidth && $prevX >= $wWidth) ||
	      ($x >= $minX && $prevX < $minX)} {
	after cancel $priv(afterId)
	set priv(afterId) ""
    }
}

#------------------------------------------------------------------------------
# tablelist::autoScan
#
# This procedure is invoked when the mouse leaves the scrollable part of a
# tablelist widget's body text child while button 1 is down.  It scrolls the
# child up, down, left, or right, depending on where the mouse left the
# scrollable part of the tablelist's body, and reschedules itself as an "after"
# command so that the child continues to scroll until the mouse moves back into
# the window or the mouse button is released.
#------------------------------------------------------------------------------
proc tablelist::autoScan win {
    if {![array exists ::tablelist::ns${win}::data] || [isDragSrc $win] ||
	[string length [::$win editwinpath]] != 0} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {!$data(-autoscan)} {
	return ""
    }

    variable priv
    set w [::$win bodypath]
    set x [expr {$priv(x) - [winfo x $w]}]
    set y [expr {$priv(y) - [winfo y $w]}]
    set minX [minScrollableX $win]

    if {$y >= [winfo height $w]} {
	::$win yview scroll 1 units
	set ms 50
    } elseif {$y < 0} {
	::$win yview scroll -1 units
	set ms 50
    } elseif {$x >= [winfo width $w]} {
	if {$data(-titlecolumns) == 0} {
	    ::$win xview scroll 2 units
	    set ms 50
	} else {
	    ::$win xview scroll 1 units
	    set ms 250
	}
    } elseif {$x < $minX} {
	if {$data(-titlecolumns) == 0} {
	    ::$win xview scroll -2 units
	    set ms 50
	} else {
	    ::$win xview scroll -1 units
	    set ms 250
	}
    } else {
	return ""
    }

    motion $win [::$win nearest $priv(y)] [::$win nearestcolumn $priv(x)] 1
    if {[string length $tablelist::priv(x)] != 0 &&
	[string length $tablelist::priv(y)] != 0} {
	set priv(afterId) [after $ms [list tablelist::autoScan $win]]
    }
}

#------------------------------------------------------------------------------
# tablelist::minScrollableX
#
# Returns the least x coordinate within the scrollable part of the body of the
# tablelist widget win.
#------------------------------------------------------------------------------
proc tablelist::minScrollableX win {
    upvar ::tablelist::ns${win}::data data
    if {$data(-titlecolumns) == 0} {
	return 0
    } else {
	set sep [::$win separatorpath]
	if {[winfo viewable $sep]} {
	    return [expr {[winfo x $sep] - [winfo x [::$win bodypath]] + 1}]
	} else {
	    return 0
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::motion
#
# This procedure is called to process mouse motion events in the body of a
# tablelist widget or in one of its separators. while button 1 is down.  It may
# move or extend the selection, depending on the widget's selection mode.
#------------------------------------------------------------------------------
proc tablelist::motion {win row col {checkIfDragSrc 0}} {
    if {$checkIfDragSrc && [isDragSrc $win]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    variable priv
    switch $data(-selecttype) {
	row {
	    set prRow $priv(prevRow)
	    if {$row == $prRow} {
		return ""
	    }

	    switch -- $data(-selectmode) {
		browse {
		    ::$win selection clear 0 end
		    ::$win selection set $row
		    set priv(prevRow) $row
		    event generate $win <<TablelistSelect>>
		}
		extended {
		    if {[string length $prRow] == 0} {
			set prRow $row
			::$win selection set $row
		    }

		    if {[::$win selection includes anchor]} {
			::$win selection clear $prRow $row
			::$win selection set anchor $row
		    } else {
			::$win selection clear $prRow $row
			::$win selection clear anchor $row
		    }

		    set ancRow $data(anchorRow)
		    foreach r $priv(selection) {
			if {($r >= $prRow && $r < $row && $r < $ancRow) ||
			    ($r <= $prRow && $r > $row && $r > $ancRow)} {
			    ::$win selection set $r
			}
		    }

		    set priv(prevRow) $row
		    event generate $win <<TablelistSelect>>
		}
	    }
	}

	cell {
	    set prRow $priv(prevRow)
	    set prCol $priv(prevCol)
	    if {$row == $prRow && $col == $prCol} {
		return ""
	    }

	    switch -- $data(-selectmode) {
		browse {
		    ::$win cellselection clear 0,0 end
		    ::$win cellselection set $row,$col
		    set priv(prevRow) $row
		    set priv(prevCol) $col
		    event generate $win <<TablelistSelect>>
		}
		extended {
		    if {[string length $prRow] == 0 ||
			[string length $prCol] == 0} {
			set prRow $row
			set prcol $col
			::$win cellselection set $row,$col
		    }

		    set ancRow $data(anchorRow)
		    set ancCol $data(anchorCol)
		    if {[::$win cellselection includes anchor]} {
			::$win cellselection clear $prRow,$prCol $row,$ancCol
			::$win cellselection clear $prRow,$prCol $ancRow,$col
			::$win cellselection set anchor $row,$col
		    } else {
			::$win cellselection clear $prRow,$prCol $row,$ancCol
			::$win cellselection clear $prRow,$prCol $ancRow,$col
			::$win cellselection clear anchor $row,$col
		    }

		    foreach {rMin1 cMin1 rMax1 cMax1} \
			[normalizedRect $prRow $prCol $row $ancCol] {}
		    foreach {rMin2 cMin2 rMax2 cMax2} \
			[normalizedRect $prRow $prCol $ancRow $col] {}
		    foreach {rMin3 cMin3 rMax3 cMax3} \
			[normalizedRect $ancRow $ancCol $row $col] {}
		    foreach cellIdx $priv(selection) {
			scan $cellIdx "%d,%d" r c
			if {([cellInRect $r $c $rMin1 $cMin1 $rMax1 $cMax1] ||
			     [cellInRect $r $c $rMin2 $cMin2 $rMax2 $cMax2]) &&
			    ![cellInRect $r $c $rMin3 $cMin3 $rMax3 $cMax3]} {
			    ::$win cellselection set $r,$c
			}
		    }

		    set priv(prevRow) $row
		    set priv(prevCol) $col
		    event generate $win <<TablelistSelect>>
		}
	    }
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::condShowTarget
#
# This procedure is called to process mouse motion events in the body of a
# tablelist widget or in one of its separators. while button 1 is down.  It
# visualizes the would-be target position of the clicked row if a move
# operation is in progress.
#------------------------------------------------------------------------------
proc tablelist::condShowTarget {win y} {
    upvar ::tablelist::ns${win}::data data
    if {![info exists data(sourceRow)]} {
	return ""
    }

    set indentImg [doCellCget $data(sourceRow) $data(treeCol) $win -indent]
    set w $data(body)
    incr y -[winfo y $w]
    set textIdx [$w index @0,$y]
    set dlineinfo [$w dlineinfo $textIdx]
    set lineY [lindex $dlineinfo 1]
    set lineHeight [lindex $dlineinfo 3]
    set row [expr {int($textIdx) - 1}]

    if {$::tk_version < 8.3 || [string length $indentImg] == 0} {
	if {$y < $lineY + $lineHeight/2} {
	    set data(targetRow) $row
	    set gapY $lineY
	} else {
	    set y [expr {$lineY + $lineHeight}]
	    set textIdx [$w index @0,$y]
	    set row2 [expr {int($textIdx) - 1}]
	    if {$row2 == $row} {
		set row2 $data(itemCount)
	    }
	    set data(targetRow) $row2
	    set gapY $y
	}
	set data(targetChildIdx) -1
    } else {
	if {$y < $lineY + $lineHeight/4} {
	    set data(targetRow) $row
	    set data(targetChildIdx) -1
	    set gapY $lineY
	} elseif {$y < $lineY + $lineHeight*3/4} {
	    set data(targetRow) $row
	    set data(targetChildIdx) 0
	    set gapY [expr {$lineY + $lineHeight/2}]
	} else {
	    set y [expr {$lineY + $lineHeight}]
	    set textIdx [$w index @0,$y]
	    set row2 [expr {int($textIdx) - 1}]
	    if {$row2 == $row} {
		set row2 $data(itemCount)
	    }
	    set data(targetRow) $row2
	    set data(targetChildIdx) -1
	    set gapY $y
	}
    }

    #
    # Get the key and node index of the potential target parent
    #
    if {$data(targetRow) > $data(lastRow)} {
	if {$data(targetRow) > $data(sourceParentEndRow)} {
	    set targetParentKey root
	    set targetParentNodeIdx root
	} else {
	    set targetParentKey $data(sourceParentKey)
	    set targetParentNodeIdx $data(sourceParentRow)
	}
    } elseif {$data(targetChildIdx) == 0} {
	set targetParentKey [lindex $data(keyList) $data(targetRow)]
	set targetParentNodeIdx $data(targetRow)
    } else {
	set targetParentKey [::$win parentkey $data(targetRow)]
	set targetParentNodeIdx [keyToRow $win $targetParentKey]
	if {$targetParentNodeIdx < 0} {
	    set targetParentNodeIdx root
	}
    }

    if {($data(targetRow) == $data(sourceRow)) ||

	($data(targetRow) == $data(sourceParentRow) &&
	 $data(targetChildIdx) == 0) ||

	($data(targetRow) == $data(sourceEndRow) &&
	 $data(targetChildIdx) < 0) ||

	($data(targetRow) > $data(sourceRow) &&
	 $data(targetRow) <= $data(sourceRow) + $data(sourceDescCount)) ||

	([string compare $data(sourceParentKey) $targetParentKey] != 0 &&
	 ($::tk_version < 8.3 ||
	  ([string length $data(-acceptchildcommand)] != 0 &&
	   ![uplevel #0 $data(-acceptchildcommand) \
	     [list $win $targetParentNodeIdx $data(sourceRow)]]))) ||

	($data(targetChildIdx) < 0 &&
	 [string length $data(-acceptdropcommand)] != 0 &&
	 ![uplevel #0 $data(-acceptdropcommand) \
	   [list $win $data(targetRow) $data(sourceRow)]])} {

	unset data(targetRow)
	unset data(targetChildIdx)
	$w configure -cursor $data(-cursor)
	place forget $data(rowGap)
    } else {
	$w configure -cursor $data(-movecursor)
	if {$data(targetChildIdx) == 0} {
	    place $data(rowGap) -anchor w -y $gapY -height $lineHeight -width 6
	} else {
	    place $data(rowGap) -anchor w -y $gapY -height 4 \
				-width [winfo width $data(hdrTxtFr)]
	}
	raise $data(rowGap)
    }
}

#------------------------------------------------------------------------------
# tablelist::moveOrActivate
#
# This procedure is invoked whenever mouse button 1 is released in the body of
# a tablelist widget or in one of its separators.  It either moves the
# previously clicked row before or after the one containing the mouse cursor,
# or activates the given nearest item or element (depending on the widget's
# selection type).
#------------------------------------------------------------------------------
proc tablelist::moveOrActivate {win row col inside} {
    variable priv
    upvar ::tablelist::ns${win}::data data
    if {$priv(selClearPending) && $inside} {
	switch $data(-selecttype) {
	    row {
		if {$row == $priv(prevRow)} {
		    ::$win selection clear $priv(prevRow)
		}
	    }
	    cell {
		if {$row == $priv(prevRow) && $col == $priv(prevCol)} {
		    ::$win cellselection clear $priv(prevRow),$priv(prevCol)
		}
	    }
	}

	event generate $win <<TablelistSelect>>
	set priv(selClearPending) 0
    } elseif {$priv(selChangePending) && $inside} {
	switch $data(-selecttype) {
	    row {
		if {$row == $priv(prevRow)} {
		    ::$win selection clear 0 end
		    ::$win selection set $priv(prevRow)
		}
	    }
	    cell {
		if {$row == $priv(prevRow) && $col == $priv(prevCol)} {
		    ::$win cellselection clear 0,0 end
		    ::$win cellselection set $priv(prevRow),$priv(prevCol)
		}
	    }
	}

	event generate $win <<TablelistSelect>>
	set priv(selChangePending) 0
    }

    #
    # Return if both <Button-1> and <ButtonRelease-1> occurred in the
    # temporary embedded widget used for interactive cell editing
    #
    if {$priv(clickedInEditWin) && $priv(releasedInEditWin)} {
	return ""
    }

    if {[info exists data(sourceRow)]} {
	set sourceRow $data(sourceRow)
	unset data(sourceRow)
	unset data(sourceEndRow)
	unset data(sourceDescCount)
	unset data(sourceParentKey)
	unset data(sourceParentRow)
	unset data(sourceParentEndRow)
	bind [winfo toplevel $win] <Escape> $data(topEscBinding)
	$data(body) configure -cursor $data(-cursor)
	place forget $data(rowGap)

	if {[info exists data(targetRow)]} {
	    set sourceKey [lindex $data(keyList) $sourceRow]
	    set targetRow $data(targetRow)
	    unset data(targetRow)

	    if {$targetRow > $data(lastRow)} {
		if {[catch {::$win move $sourceRow $targetRow}] == 0} {
		    set targetParentNodeIdx [::$win parentkey $sourceRow]
		} else {
		    ::$win move $sourceRow root end
		    set targetParentNodeIdx root
		}

		set targetChildIdx [::$win childcount $targetParentNodeIdx]
	    } else {
		set targetChildIdx $data(targetChildIdx)
		unset data(targetChildIdx)

		if {$targetChildIdx == 0} {
		    set targetParentNodeIdx [lindex $data(keyList) $targetRow]
		    ::$win expand $targetParentNodeIdx -partly
		    ::$win move $sourceKey $targetParentNodeIdx $targetChildIdx
		} else {
		    set targetParentNodeIdx [::$win parentkey $targetRow]
		    set targetChildIdx [::$win childindex $targetRow]
		    ::$win move $sourceRow $targetParentNodeIdx $targetChildIdx
		}
	    }

	    set userData [list $sourceKey $targetParentNodeIdx $targetChildIdx]
	    genVirtualEvent $win <<TablelistRowMoved>> $userData

	    switch $data(-selecttype) {
		row  { ::$win activate $sourceKey }
		cell { ::$win activatecell $sourceKey,$col }
	    }

	    return ""
	}
    }

    switch $data(-selecttype) {
	row  { ::$win activate $row }
	cell { ::$win activatecell $row,$col }
    }
}

#------------------------------------------------------------------------------
# tablelist::condEvalInvokeCmd
#
# This procedure is invoked when mouse button 1 is released in the body of a
# tablelist widget win or in one of its separators.  If interactive cell
# editing is in progress in a column whose associated edit window has an invoke
# command that hasn't yet been called in the current edit session, then the
# procedure evaluates that command.
#------------------------------------------------------------------------------
proc tablelist::condEvalInvokeCmd win {
    #
    # This is an "after 100" callback; check whether the window exists
    #
    if {![array exists ::tablelist::ns${win}::data]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(editCol) < 0} {
	return ""
    }

    variable editWin
    set name [getEditWindow $win $data(editRow) $data(editCol)]
    if {[string length $editWin($name-invokeCmd)] == 0 || $data(invoked)} {
	return ""
    }

    #
    # Return if both <Button-1> and <ButtonRelease-1> occurred in the
    # temporary embedded widget used for interactive cell editing
    #
    variable priv
    if {$priv(clickedInEditWin) && $priv(releasedInEditWin)} {
	return ""
    }

    #
    # Check whether the edit window is a checkbutton,
    # and return if it is an editable combobox widget
    #
    set isCheckbtn 0
    set w $data(bodyFrEd)
    switch [winfo class $w] {
	Checkbutton -
	TCheckbutton {
	    set isCheckbtn 1
	}
	TCombobox {
	    if {[string compare [$w cget -state] "normal"] == 0} {
		return ""
	    }
	}
	ComboBox -
	Combobox {
	    if {[$w cget -editable]} {
		return ""
	    }
	}
    }

    #
    # Evaluate the edit window's invoke command
    #
    eval [strMap {"%W" "$w"} $editWin($name-invokeCmd)]
    set data(invoked) 1

    #
    # If the edit window is a checkbutton and the value of the
    # -instanttoggle option is true then finish the editing
    #
    if {$isCheckbtn && $data(-instanttoggle)} {
	doFinishEditing $win
    }
}

#------------------------------------------------------------------------------
# tablelist::cancelMove
#
# This procedure is invoked to process <Escape> events in the top-level window
# containing the tablelist widget win during a row move operation.  It cancels
# the action in progress.
#------------------------------------------------------------------------------
proc tablelist::cancelMove win {
    upvar ::tablelist::ns${win}::data data
    if {![info exists data(sourceRow)]} {
	return ""
    }

    unset data(sourceRow)
    unset data(sourceEndRow)
    unset data(sourceDescCount)
    unset data(sourceParentKey)
    unset data(sourceParentRow)
    unset data(sourceParentEndRow)
    catch {unset data(targetRow)}
    catch {unset data(targetChildIdx)}
    bind [winfo toplevel $win] <Escape> $data(topEscBinding)
    $data(body) configure -cursor $data(-cursor)
    place forget $data(rowGap)
}

#------------------------------------------------------------------------------
# tablelist::beginExtend
#
# This procedure is typically invoked on shift-button-1 presses in the body of
# a tablelist widget or in one of its separators.  It begins the process of
# extending a selection in the widget.  Its exact behavior depends on the
# selection mode currently in effect for the widget.
#------------------------------------------------------------------------------
proc tablelist::beginExtend {win row col} {
    if {[string compare [::$win cget -selectmode] "extended"] != 0} {
	return ""
    }

    if {[::$win selection includes anchor]} {
	motion $win $row $col
    } else {
	beginSelect $win $row $col
    }
}

#------------------------------------------------------------------------------
# tablelist::beginToggle
#
# This procedure is typically invoked on control-button-1 presses in the body
# of a tablelist widget or in one of its separators.  It begins the process of
# toggling a selection in the widget.  Its exact behavior depends on the
# selection mode currently in effect for the widget.
#------------------------------------------------------------------------------
proc tablelist::beginToggle {win row col} {
    upvar ::tablelist::ns${win}::data data
    if {[string compare $data(-selectmode) "extended"] != 0} {
	return ""
    }

    variable priv
    switch $data(-selecttype) {
	row {
	    set priv(selection) [::$win curselection]
	    set priv(prevRow) $row
	    ::$win selection anchor $row
	    if {[::$win selection includes $row]} {
		::$win selection clear $row
	    } else {
		::$win selection set $row
	    }
	}

	cell {
	    set priv(selection) [::$win curcellselection]
	    set priv(prevRow) $row
	    set priv(prevCol) $col
	    ::$win cellselection anchor $row,$col
	    if {[::$win cellselection includes $row,$col]} {
		::$win cellselection clear $row,$col
	    } else {
		::$win cellselection set $row,$col
	    }
	}
    }

    event generate $win <<TablelistSelect>>
}

#------------------------------------------------------------------------------
# tablelist::condEditActiveCell
#
# This procedure is invoked whenever Return or KP_Enter is pressed in the body
# of a tablelist widget.  If the selection type is cell and the active cell is
# editable then the procedure starts the interactive editing in that cell.
#------------------------------------------------------------------------------
proc tablelist::condEditActiveCell win {
    upvar ::tablelist::ns${win}::data data
    if {[string compare $data(-selecttype) "cell"] != 0 ||
	[firstViewableRow $win] < 0 || [firstViewableCol $win] < 0} {
	return ""
    }

    set row $data(activeRow)
    set col $data(activeCol)
    if {[isCellEditable $win $row $col]} {
	doEditCell $win $row $col 0
    }
}

#------------------------------------------------------------------------------
# tablelist::plusMinus
#
# Partially expands or collapses the active row if possible.
#------------------------------------------------------------------------------
proc tablelist::plusMinus {win keysym} {
    upvar ::tablelist::ns${win}::data data
    set row $data(activeRow)
    set col $data(treeCol)
    set key [lindex $data(keyList) $row]
    set op ""

    if {[info exists data($key,$col-indent)]} {
	set indentLabel $data(body).ind_$key,$col
	set imgName [$indentLabel cget -image]
	if {[regexp {^tablelist_(.+)_(collapsed|expanded).*Img([0-9]+)$} \
		     $imgName dummy treeStyle mode depth]} {
	    if {[string compare $keysym "plus"] == 0 &&
		[string compare $mode "collapsed"] == 0} {
		set op "expand"
	    } elseif {[string compare $keysym "minus"] == 0 &&
		      [string compare $mode "expanded"] == 0} {
		set op "collapse"
	    }
	}
    }

    if {[string length $op] != 0} {
	#
	# Save the current vertical position
	#
	set topRow [expr {int([$data(body) index @0,0]) - 1}]

	#
	# Toggle the state of the expand/collapse control
	#
	::$win $op $row -partly

	#
	# Restore the saved vertical position
	#
	$data(body) yview $topRow
	updateViewWhenIdle $win
    }
}

#------------------------------------------------------------------------------
# tablelist::nextPrevCell
#
# Does nothing unless the selection type is cell; in this case it moves the
# location cursor (active element) to the next or previous element, and changes
# the selection if we are in browse or extended selection mode.
#------------------------------------------------------------------------------
proc tablelist::nextPrevCell {win amount} {
    upvar ::tablelist::ns${win}::data data
    switch $data(-selecttype) {
	row {
	    # Nothing
	}

	cell {
	    if {$data(editRow) >= 0} {
		return -code break ""
	    }

	    set row $data(activeRow)
	    set col $data(activeCol)
	    set oldRow $row
	    set oldCol $col

	    while 1 {
		incr col $amount
		if {$col < 0} {
		    incr row $amount
		    if {$row < 0} {
			set row $data(lastRow)
		    }
		    set col $data(lastCol)
		} elseif {$col > $data(lastCol)} {
		    incr row $amount
		    if {$row > $data(lastRow)} {
			set row 0
		    }
		    set col 0
		}

		if {$row == $oldRow && $col == $oldCol} {
		    return -code break ""
		} elseif {[isRowViewable $win $row] && !$data($col-hide)} {
		    condChangeSelection $win $row $col
		    return -code break ""
		}
	    }
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::upDown
#
# Moves the location cursor (active item or element) up or down by one line,
# and changes the selection if we are in browse or extended selection mode.
#------------------------------------------------------------------------------
proc tablelist::upDown {win amount} {
    upvar ::tablelist::ns${win}::data data
    if {$data(editRow) >= 0} {
	return ""
    }

    switch $data(-selecttype) {
	row {
	    set row $data(activeRow)
	    set col -1
	}

	cell {
	    set row $data(activeRow)
	    set col $data(activeCol)
	}
    }

    while 1 {
	incr row $amount
	if {$row < 0 || $row > $data(lastRow)} {
	    return ""
	} elseif {[isRowViewable $win $row]} {
	    condChangeSelection $win $row $col
	    return ""
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::leftRight
#
# Partially expands or collapses the active row if possible.  Otherwise, if the
# tablelist widget's selection type is "row" then this procedure scrolls the
# widget's view left or right by the width of the character "0".  Otherwise it
# moves the location cursor (active element) left or right by one column, and
# changes the selection if we are in browse or extended selection mode.
#------------------------------------------------------------------------------
proc tablelist::leftRight {win amount} {
    upvar ::tablelist::ns${win}::data data
    set row $data(activeRow)
    set col $data(treeCol)
    set key [lindex $data(keyList) $row]
    set op ""

    if {[info exists data($key,$col-indent)]} {
	set indentLabel $data(body).ind_$key,$col
	set imgName [$indentLabel cget -image]
	if {[regexp {^tablelist_(.+)_(collapsed|expanded).*Img([0-9]+)$} \
		     $imgName dummy treeStyle mode depth]} {
	    if {$amount > 0 && [string compare $mode "collapsed"] == 0} {
		set op "expand"
	    } elseif {$amount < 0 && [string compare $mode "expanded"] == 0} {
		set op "collapse"
	    }
	}
    }

    if {[string length $op] == 0} {
	switch $data(-selecttype) {
	    row {
		::$win xview scroll $amount units
	    }

	    cell {
		if {$data(editRow) >= 0} {
		    return ""
		}

		set col $data(activeCol)
		while 1 {
		    incr col $amount
		    if {$col < 0 || $col > $data(lastCol)} {
			return ""
		    } elseif {!$data($col-hide)} {
			condChangeSelection $win $row $col
			return ""
		    }
		}
	    }
	}
    } else {
	#
	# Save the current vertical position
	#
	set topRow [expr {int([$data(body) index @0,0]) - 1}]

	#
	# Toggle the state of the expand/collapse control
	#
	::$win $op $row -partly

	#
	# Restore the saved vertical position
	#
	$data(body) yview $topRow
	updateViewWhenIdle $win
    }
}

#------------------------------------------------------------------------------
# tablelist::priorNext
#
# Scrolls the tablelist view up or down by one page.
#------------------------------------------------------------------------------
proc tablelist::priorNext {win amount} {
    upvar ::tablelist::ns${win}::data data
    if {$data(editRow) >= 0} {
	return ""
    }

    ::$win yview scroll $amount pages
    ::$win activate @0,0
    update idletasks
}

#------------------------------------------------------------------------------
# tablelist::homeEnd
#
# If selecttype is row then the procedure scrolls the tablelist widget
# horizontally to its left or right edge.  Otherwise it sets the location
# cursor (active element) to the first/last element of the active row, selects
# that element, and deselects everything else in the widget.
#------------------------------------------------------------------------------
proc tablelist::homeEnd {win keysym} {
    upvar ::tablelist::ns${win}::data data
    switch $data(-selecttype) {
	row {
	    switch $keysym {
		Home { ::$win xview moveto 0 }
		End  { ::$win xview moveto 1 }
	    }
	}

	cell {
	    set row $data(activeRow)
	    switch $keysym {
		Home { set col [firstViewableCol $win] }
		End  { set col [ lastViewableCol $win] }
	    }
	    changeSelection $win $row $col
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::firstLast
#
# Sets the location cursor (active item or element) to the first/last item or
# element in the tablelist widget, selects that item or element, and deselects
# everything else in the widget.
#------------------------------------------------------------------------------
proc tablelist::firstLast {win target} {
    switch $target {
	first {
	    set row [firstViewableRow $win]
	    set col [firstViewableCol $win]
	}

	last {
	    set row [lastViewableRow $win]
	    set col [lastViewableCol $win]
	}
    }

    changeSelection $win $row $col
}

#------------------------------------------------------------------------------
# tablelist::extendUpDown
#
# Does nothing unless we are in extended selection mode; in this case it moves
# the location cursor (active item or element) up or down by one line, and
# extends the selection to that point.
#------------------------------------------------------------------------------
proc tablelist::extendUpDown {win amount} {
    upvar ::tablelist::ns${win}::data data
    if {[string compare $data(-selectmode) "extended"] != 0} {
	return ""
    }

    switch $data(-selecttype) {
	row {
	    set row $data(activeRow)
	    while 1 {
		incr row $amount
		if {$row < 0 || $row > $data(lastRow)} {
		    return ""
		} elseif {[isRowViewable $win $row]} {
		    ::$win activate $row
		    ::$win see active
		    motion $win $data(activeRow) -1
		    return ""
		}
	    }
	}

	cell {
	    set row $data(activeRow)
	    set col $data(activeCol)
	    while 1 {
		incr row $amount
		if {$row < 0 || $row > $data(lastRow)} {
		    return ""
		} elseif {[isRowViewable $win $row]} {
		    ::$win activatecell $row,$col
		    ::$win seecell active
		    motion $win $data(activeRow) $data(activeCol)
		    return ""
		}
	    }
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::extendLeftRight
#
# Does nothing unless we are in extended selection mode and the selection type
# is cell; in this case it moves the location cursor (active element) left or
# right by one column, and extends the selection to that point.
#------------------------------------------------------------------------------
proc tablelist::extendLeftRight {win amount} {
    upvar ::tablelist::ns${win}::data data
    if {[string compare $data(-selectmode) "extended"] != 0} {
	return ""
    }

    switch $data(-selecttype) {
	row {
	    # Nothing
	}

	cell {
	    set row $data(activeRow)
	    set col $data(activeCol)
	    while 1 {
		incr col $amount
		if {$col < 0 || $col > $data(lastCol)} {
		    return ""
		} elseif {!$data($col-hide)} {
		    ::$win activatecell $row,$col
		    ::$win seecell active
		    motion $win $data(activeRow) $data(activeCol)
		    return ""
		}
	    }
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::extendToHomeEnd
#
# Does nothing unless the selection mode is multiple or extended and the
# selection type is cell; in this case it moves the location cursor (active
# element) to the first/last element of the active row, and, if we are in
# extended mode, it extends the selection to that point.
#------------------------------------------------------------------------------
proc tablelist::extendToHomeEnd {win keysym} {
    upvar ::tablelist::ns${win}::data data
    switch $data(-selecttype) {
	row {
	    # Nothing
	}

	cell {
	    set row $data(activeRow)
	    switch $keysym {
		Home { set col [firstViewableCol $win] }
		End  { set col [ lastViewableCol $win] }
	    }

	    switch -- $data(-selectmode) {
		multiple {
		    ::$win activatecell $row,$col
		    ::$win seecell $row,$col
		}
		extended {
		    ::$win activatecell $row,$col
		    ::$win seecell $row,$col
		    if {[::$win selection includes anchor]} {
			motion $win $row $col
		    }
		}
	    }
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::extendToFirstLast
#
# Does nothing unless the selection mode is multiple or extended; in this case
# it moves the location cursor (active item or element) to the first/last item
# or element in the tablelist widget, and, if we are in extended mode, it
# extends the selection to that point.
#------------------------------------------------------------------------------
proc tablelist::extendToFirstLast {win target} {
    switch $target {
	first {
	    set row [firstViewableRow $win]
	    set col [firstViewableCol $win]
	}

	last {
	    set row [lastViewableRow $win]
	    set col [lastViewableCol $win]
	}
    }

    upvar ::tablelist::ns${win}::data data
    switch $data(-selecttype) {
	row {
	    switch -- $data(-selectmode) {
		multiple {
		    ::$win activate $row
		    ::$win see $row
		}
		extended {
		    ::$win activate $row
		    ::$win see $row
		    if {[::$win selection includes anchor]} {
			motion $win $row -1
		    }
		}
	    }
	}

	cell {
	    switch -- $data(-selectmode) {
		multiple {
		    ::$win activatecell $row,$col
		    ::$win seecell $row,$col
		}
		extended {
		    ::$win activatecell $row,$col
		    ::$win seecell $row,$col
		    if {[::$win selection includes anchor]} {
			motion $win $row $col
		    }
		}
	    }
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::cancelSelection
#
# This procedure is invoked to cancel an extended selection in progress.  If
# there is an extended selection in progress, it restores all of the elements
# to their previous selection state.
#------------------------------------------------------------------------------
proc tablelist::cancelSelection win {
    upvar ::tablelist::ns${win}::data data
    if {[string compare $data(-selectmode) "extended"] != 0} {
	return ""
    }

    variable priv
    switch $data(-selecttype) {
	row {
	    if {[string length $priv(prevRow)] == 0} {
		return ""
	    }

	    ::$win selection clear 0 end
	    foreach row $priv(selection) {
		::$win selection set $row
	    }
	    event generate $win <<TablelistSelect>>
	}

	cell {
	    if {[string length $priv(prevRow)] == 0 ||
		[string length $priv(prevCol)] == 0} {
		return ""
	    }

	    ::$win selection clear 0 end
	    foreach cellIdx $priv(selection) {
		::$win cellselection set $cellIdx
	    }
	    event generate $win <<TablelistSelect>>
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::selectAll
#
# This procedure is invoked to handle the "select all" operation.  For single
# and browse mode, it just selects the active item or element.  Otherwise it
# selects everything in the widget.
#------------------------------------------------------------------------------
proc tablelist::selectAll win {
    upvar ::tablelist::ns${win}::data data
    switch $data(-selecttype) {
	row {
	    if {[string compare $data(-selectmode) "single"] == 0 ||
		[string compare $data(-selectmode) "browse"] == 0} {
		::$win selection clear 0 end
		::$win selection set active
	    } else {
		::$win selection set 0 end
	    }
	}

	cell {
	    if {[string compare $data(-selectmode) "single"] == 0 ||
		[string compare $data(-selectmode) "browse"] == 0} {
		::$win cellselection clear 0,0 end
		::$win cellselection set active
	    } else {
		::$win cellselection set 0,0 end
	    }
	}
    }

    event generate $win <<TablelistSelect>>
}

#------------------------------------------------------------------------------
# tablelist::isDragSrc
#
# Checks whether the body component of the tablelist widget win is a BWidget or
# TkDND drag source for mouse button 1.
#------------------------------------------------------------------------------
proc tablelist::isDragSrc win {
    upvar ::tablelist::ns${win}::data data
    set bindTags [bindtags $data(body)]
    return [expr {[info exists data(sourceRow)] || $data(-customdragsource) ||
		  [lsearch -exact $bindTags "BwDrag1"] >= 0 ||
		  [lsearch -exact $bindTags "TkDND_Drag1"] >= 0
    }]
}

#------------------------------------------------------------------------------
# tablelist::normalizedRect
#
# Returns a list of the form {minRow minCol maxRow maxCol}, built from the
# given arguments.
#------------------------------------------------------------------------------
proc tablelist::normalizedRect {row1 col1 row2 col2} {
    if {$row1 <= $row2} {
	set minRow $row1
	set maxRow $row2
    } else {
	set minRow $row2
	set maxRow $row1
    }

    if {$col1 <= $col2} {
	set minCol $col1
	set maxCol $col2
    } else {
	set minCol $col2
	set maxCol $col1
    }

    return [list $minRow $minCol $maxRow $maxCol]
}

#------------------------------------------------------------------------------
# tablelist::cellInRect
#
# Checks whether the cell row,col is contained in the given rectangular range.
#------------------------------------------------------------------------------
proc tablelist::cellInRect {row col minRow minCol maxRow maxCol} {
    return [expr {$row >= $minRow && $row <= $maxRow &&
		  $col >= $minCol && $col <= $maxCol}]
}

#------------------------------------------------------------------------------
# tablelist::firstViewableRow
#
# Returns the index of the first viewable row of the tablelist widget win.
#------------------------------------------------------------------------------
proc tablelist::firstViewableRow win {
    upvar ::tablelist::ns${win}::data data
    for {set row 0} {$row < $data(itemCount)} {incr row} {
	if {[isRowViewable $win $row]} {
	    return $row
	}
    }

    return -1
}

#------------------------------------------------------------------------------
# tablelist::lastViewableRow
#
# Returns the index of the last viewable row of the tablelist widget win.
#------------------------------------------------------------------------------
proc tablelist::lastViewableRow win {
    upvar ::tablelist::ns${win}::data data
    for {set row $data(lastRow)} {$row >= 0} {incr row -1} {
	if {[isRowViewable $win $row]} {
	    return $row
	}
    }

    return -1
}

#------------------------------------------------------------------------------
# tablelist::firstViewableCol
#
# Returns the index of the first non-hidden column of the tablelist widget win.
#------------------------------------------------------------------------------
proc tablelist::firstViewableCol win {
    upvar ::tablelist::ns${win}::data data
    for {set col 0} {$col < $data(colCount)} {incr col} {
	if {!$data($col-hide)} {
	    return $col
	}
    }

    return -1
}

#------------------------------------------------------------------------------
# tablelist::lastViewableCol
#
# Returns the index of the last non-hidden column of the tablelist widget win.
#------------------------------------------------------------------------------
proc tablelist::lastViewableCol win {
    upvar ::tablelist::ns${win}::data data
    for {set col $data(lastCol)} {$col >= 0} {incr col -1} {
	if {!$data($col-hide)} {
	    return $col
	}
    }

    return -1
}

#------------------------------------------------------------------------------
# tablelist::condChangeSelection
#
# Activates the given item or element, and selects it exclusively if we are in
# browse or extended selection mode.
#------------------------------------------------------------------------------
proc tablelist::condChangeSelection {win row col} {
    upvar ::tablelist::ns${win}::data data
    switch $data(-selecttype) {
	row {
	    ::$win activate $row
	    ::$win see active

	    switch -- $data(-selectmode) {
		browse {
		    ::$win selection clear 0 end
		    ::$win selection set active
		    event generate $win <<TablelistSelect>>
		}
		extended {
		    ::$win selection clear 0 end
		    ::$win selection set active
		    ::$win selection anchor active
		    variable priv
		    set priv(selection) {}
		    set priv(prevRow) $data(activeRow)
		    event generate $win <<TablelistSelect>>
		}
	    }
	}

	cell {
	    ::$win activatecell $row,$col
	    ::$win seecell active

	    switch -- $data(-selectmode) {
		browse {
		    ::$win cellselection clear 0,0 end
		    ::$win cellselection set active
		    event generate $win <<TablelistSelect>>
		}
		extended {
		    ::$win cellselection clear 0,0 end
		    ::$win cellselection set active
		    ::$win cellselection anchor active
		    variable priv
		    set priv(selection) {}
		    set priv(prevRow) $data(activeRow)
		    set priv(prevCol) $data(activeCol)
		    event generate $win <<TablelistSelect>>
		}
	    }
	}
    }

    update idletasks
}

#------------------------------------------------------------------------------
# tablelist::changeSelection
#
# Activates the given item or element and selects it exclusively.
#------------------------------------------------------------------------------
proc tablelist::changeSelection {win row col} {
    upvar ::tablelist::ns${win}::data data
    switch $data(-selecttype) {
	row {
	    ::$win activate $row
	    ::$win see active

	    ::$win selection clear 0 end
	    ::$win selection set active
	}

	cell {
	    ::$win activatecell $row,$col
	    ::$win seecell active

	    ::$win cellselection clear 0,0 end
	    ::$win cellselection set active
	}
    }

    event generate $win <<TablelistSelect>>
}

#
# Binding tags TablelistLabel, TablelistSubLabel, and TablelistArrow
# ==================================================================
#

#------------------------------------------------------------------------------
# tablelist::defineTablelistSubLabel
#
# Defines the binding tag TablelistSubLabel (for sublabels of tablelist labels)
# to have the same events as TablelistLabel and the binding scripts obtained
# from those of TablelistLabel by replacing the widget %W with the containing
# label as well as the %x and %y fields with the corresponding coordinates
# relative to that label.
#------------------------------------------------------------------------------
proc tablelist::defineTablelistSubLabel {} {
    foreach event [bind TablelistLabel] {
	set script [strMap {
	    "%W" "$tablelist::W"  "%x" "$tablelist::x"  "%y" "$tablelist::y"
	} [bind TablelistLabel $event]]

	bind TablelistSubLabel $event [format {
	    set tablelist::W \
		[string range %%W 0 [expr {[string length %%W] - 4}]]
	    set tablelist::x \
		[expr {%%x + [winfo x %%W] - [winfo x $tablelist::W]}]
	    set tablelist::y \
		[expr {%%y + [winfo y %%W] - [winfo y $tablelist::W]}]
	    %s
	} $script]
    }
}

#------------------------------------------------------------------------------
# tablelist::defineTablelistArrow
#
# Defines the binding tag TablelistArrow (for sort arrows) to have the same
# events as TablelistLabel and the binding scripts obtained from those of
# TablelistLabel by replacing the widget %W with the containing label as well
# as the %x and %y fields with the corresponding coordinates relative to that
# label.
#------------------------------------------------------------------------------
proc tablelist::defineTablelistArrow {} {
    foreach event [bind TablelistLabel] {
	set script [strMap {
	    "%W" "$tablelist::W"  "%x" "$tablelist::x"  "%y" "$tablelist::y"
	} [bind TablelistLabel $event]]

	bind TablelistArrow $event [format {
	    set tablelist::W \
		[winfo parent %%W].l[string range [winfo name %%W] 1 end]
	    set tablelist::x \
		[expr {%%x + [winfo x %%W] - [winfo x $tablelist::W]}]
	    set tablelist::y \
		[expr {%%y + [winfo y %%W] - [winfo y $tablelist::W]}]
	    %s
	} $script]
    }
}

#------------------------------------------------------------------------------
# tablelist::labelEnter
#
# This procedure is invoked when the mouse pointer enters the header label w of
# a tablelist widget, or is moving within that label.  It updates the cursor,
# displays the tooltip, and activates or deactivates the label, depending on
# whether the pointer is on its right border or not.
#------------------------------------------------------------------------------
proc tablelist::labelEnter {w X Y x} {
    if {![parseLabelPath $w win col]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    configLabel $w -cursor $data(-cursor)

    if {[string length $data(-tooltipaddcommand)] != 0 &&
	[string length $data(-tooltipdelcommand)] != 0 &&
	$col != $data(prevCol)} {
	#
	# Display the tooltip corresponding to this label
	#
	set data(prevCol) $col
	set focus [focus -displayof $win]
	if {[string length $focus] == 0 ||
	    [string first $win $focus] != 0 ||
	    [string compare [winfo toplevel $focus] \
	     [winfo toplevel $win]] == 0} {
	    uplevel #0 $data(-tooltipaddcommand) [list $win -1 $col]
	    event generate $win <Leave>
	    event generate $win <Enter> -rootx $X -rooty $Y
	}
    }

    if {$data(isDisabled)} {
	return ""
    }

    if {[inResizeArea $w $x col] &&
	$data(-resizablecolumns) && $data($col-resizable)} {
	configLabel $w -cursor $data(-resizecursor)
	configLabel $w -active 0
    } else {
	configLabel $w -active 1
    }
}

#------------------------------------------------------------------------------
# tablelist::labelLeave
#
# This procedure is invoked when the mouse pointer leaves the header label w of
# a tablelist widget.  It removes the tooltip and deactivates the label.
#------------------------------------------------------------------------------
proc tablelist::labelLeave {w X x y} {
    if {![parseLabelPath $w win col]} {
	return ""
    }

    #
    # The following code is needed because the event
    # can also occur in a widget placed into the label
    #
    upvar ::tablelist::ns${win}::data data
    set hdrX [winfo rootx $data(hdr)]
    if {$X >= $hdrX && $X < $hdrX + [winfo width $data(hdr)] &&
	$x >= 1 && $x < [winfo width $w] - 1 &&
	$y >= 0 && $y < [winfo height $w]} {
	return ""
    }

    if {[string length $data(-tooltipaddcommand)] != 0 &&
	[string length $data(-tooltipdelcommand)] != 0} {
	#
	# Remove the tooltip, if any
	#
	event generate $win <Leave>
	catch {uplevel #0 $data(-tooltipdelcommand) [list $win]}
	set data(prevCol) -1
    }

    if {$data(isDisabled)} {
	return ""
    }

    configLabel $w -active 0
}

#------------------------------------------------------------------------------
# tablelist::labelB1Down
#
# This procedure is invoked when mouse button 1 is pressed in the header label
# w of a tablelist widget.  If the pointer is on the right border of the label
# then the procedure records its x-coordinate relative to the label, the width
# of the column, and some other data needed later.  Otherwise it saves the
# label's relief so it can be restored later, and changes the relief to sunken.
#------------------------------------------------------------------------------
proc tablelist::labelB1Down {w x shiftPressed} {
    if {![parseLabelPath $w win col]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {$data(isDisabled) ||
	[info exists data(colBeingResized)]} {	;# resize operation in progress
	return ""
    }

    set data(labelClicked) 1
    set data(X) [expr {[winfo rootx $w] + $x}]
    set data(shiftPressed) $shiftPressed

    if {[inResizeArea $w $x col] &&
	$data(-resizablecolumns) && $data($col-resizable)} {
	set data(colBeingResized) $col
	set data(colResized) 0

	set w $data(body)
	set topTextIdx [$w index @0,0]
	set btmTextIdx [$w index @0,[expr {[winfo height $w] - 1}]]
	$w tag add visibleLines "$topTextIdx linestart" "$btmTextIdx lineend"
	set data(topRow) [expr {int($topTextIdx) - 1}]
	set data(btmRow) [expr {int($btmTextIdx) - 1}]

	set w $data(hdrTxtFrLbl)$col
	set labelWidth [winfo width $w]
	set data(oldStretchedColWidth) [expr {$labelWidth - 2*$data(charWidth)}]
	set data(oldColDelta) $data($col-delta)
	set data(configColWidth) [lindex $data(-columns) [expr {3*$col}]]

	if {[lsearch -exact $data(arrowColList) $col] >= 0} {
	    set canvasWidth $data(arrowWidth)
	    if {[llength $data(arrowColList)] > 1} {
		incr canvasWidth 6
	    }
	    set data(minColWidth) $canvasWidth
	} elseif {$data($col-wrap)} {
	    set data(minColWidth) $data(charWidth)
	} else {
	    set data(minColWidth) 0
	}
	incr data(minColWidth)

	set data(focus) [focus -displayof $win]
	set topWin [winfo toplevel $win]
	focus $topWin
	set data(topEscBinding) [bind $topWin <Escape>]
	bind $topWin <Escape> \
	     [list tablelist::escape [strMap {"%" "%%"} $win] $col]
    } else {
	set data(inClickedLabel) 1
	set data(relief) [$w cget -relief]

	if {[info exists data($col-labelcommand)] ||
	    [string length $data(-labelcommand)] != 0} {
	    set data(changeRelief) 1
	    configLabel $w -relief sunken -pressed 1
	} else {
	    set data(changeRelief) 0
	}

	if {$data(-movablecolumns)} {
	    set data(focus) [focus -displayof $win]
	    set topWin [winfo toplevel $win]
	    focus $topWin
	    set data(topEscBinding) [bind $topWin <Escape>]
	    bind $topWin <Escape> \
		 [list tablelist::escape [strMap {"%" "%%"} $win] $col]
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::labelB1Motion
#
# This procedure is invoked to process mouse motion events in the header label
# w of a tablelist widget while button 1 is down.  If this event occured during
# a column resize operation then the procedure computes the difference between
# the pointer's new x-coordinate relative to that label and the one recorded by
# the last invocation of labelB1Down, and adjusts the width of the
# corresponding column accordingly.  Otherwise a horizontal scrolling is
# performed if needed, and the would-be target position of the clicked label is
# visualized if the columns are movable.
#------------------------------------------------------------------------------
proc tablelist::labelB1Motion {w X x y} {
    if {![parseLabelPath $w win col]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {!$data(labelClicked)} {
	return ""
    }

    if {[info exists data(colBeingResized)]} {	;# resize operation in progress
	set width [expr {$data(oldStretchedColWidth) + $X - $data(X)}]
	if {$width >= $data(minColWidth)} {
	    set col $data(colBeingResized)
	    set data(colResized) 1
	    set idx [expr {3*$col}]
	    set data(-columns) [lreplace $data(-columns) $idx $idx -$width]
	    set idx [expr {2*$col}]
	    set data(colList) [lreplace $data(colList) $idx $idx $width]
	    set data($col-lastStaticWidth) $width
	    set data($col-delta) 0
	    redisplayCol $win $col $data(topRow) $data(btmRow)

	    #
	    # Handle the case that the bottom row has become
	    # greater (due to the redisplayCol invocation)
	    #
	    set b $data(body)
	    set btmTextIdx [$b index @0,$data(btmY)]
	    set btmRow [expr {int($btmTextIdx) - 1}]
	    if {$btmRow > $data(lastRow)} {		;# text widget bug
		set btmRow $data(lastRow)
	    }
	    while {$btmRow > $data(btmRow)} {
		$b tag add visibleLines [expr {double($data(btmRow) + 2)}] \
					"$btmTextIdx lineend"
		incr data(btmRow)
		redisplayCol $win $col $data(btmRow) $btmRow
		set data(btmRow) $btmRow

		set btmTextIdx [$b index @0,$data(btmY)]
		set btmRow [expr {int($btmTextIdx) - 1}]
		if {$btmRow > $data(lastRow)} {		;# text widget bug
		    set btmRow $data(lastRow)
		}
	    }

	    #
	    # Handle the case that the top row has become
	    # less (due to the redisplayCol invocation)
	    #
	    set topTextIdx [$b index @0,0]
	    set topRow [expr {int($topTextIdx) - 1}]
	    while {$topRow < $data(topRow)} {
		$b tag add visibleLines "$topTextIdx linestart" \
					"[expr {double($data(topRow))}] lineend"
		incr data(topRow) -1
		redisplayCol $win $col $topRow $data(topRow)
		set data(topRow) $topRow

		set topTextIdx [$b index @0,0]
		set topRow [expr {int($topTextIdx) - 1}]
	    }

	    adjustColumns $win {} 0
	    adjustElidedText $win
	    redisplayVisibleItems $win
	    updateColors $win
	    updateVScrlbarWhenIdle $win
	}
    } else {
	#
	# Scroll the window horizontally if needed
	#
	set hdrX [winfo rootx $data(hdr)]
	if {$data(-titlecolumns) == 0 || ![winfo viewable $data(sep)]} {
	    set leftX $hdrX
	} else {
	    set leftX [expr {[winfo rootx $data(sep)] + 1}]
	}
	set rightX [expr {$hdrX + [winfo width $data(hdr)]}]
	set scroll 0
	if {($X >= $rightX && $data(X) < $rightX) ||
	    ($X < $leftX && $data(X) >= $leftX)} {
	    set scroll 1
	} elseif {($X < $rightX && $data(X) >= $rightX) ||
		  ($X >= $leftX && $data(X) < $leftX)} {
	    after cancel $data(afterId)
	    set data(afterId) ""
	}
	set data(X) $X
	if {$scroll} {
	    horizAutoScan $win
	}

	if {$x >= 1 && $x < [winfo width $w] - 1 &&
	    $y >= 0 && $y < [winfo height $w]} {
	    #
	    # The following code is needed because the event
	    # can also occur in a widget placed into the label
	    #
	    set data(inClickedLabel) 1
	    configLabel $w -cursor $data(-cursor)
	    $data(hdrTxtFrCanv)$col configure -cursor $data(-cursor)
	    if {$data(changeRelief)} {
		configLabel $w -relief sunken -pressed 1
	    }

	    place forget $data(colGap)
	} else {
	    #
	    # The following code is needed because the event
	    # can also occur in a widget placed into the label
	    #
	    set data(inClickedLabel) 0
	    configLabel $w -relief $data(relief) -pressed 0

	    if {$data(-movablecolumns)} {
		#
		# Get the target column index
		#
		set contW [winfo containing -displayof $w $X [winfo rooty $w]]
		if {[parseLabelPath $contW dummy targetCol]} {
		    set master $contW
		    if {$X < [winfo rootx $contW] + [winfo width $contW]/2} {
			set relx 0.0
		    } else {
			incr targetCol
			set relx 1.0
		    }
		} elseif {[string compare $contW $data(colGap)] == 0} {
		    set targetCol $data(targetCol)
		    set master $data(master)
		    set relx $data(relx)
		} elseif {$X >= $rightX || $X >= [winfo rootx $w]} {
		    for {set targetCol $data(lastCol)} {$targetCol >= 0} \
			{incr targetCol -1} {
			if {!$data($targetCol-hide)} {
			    break
			}
		    }
		    incr targetCol
		    set master $data(hdrTxtFr)
		    set relx 1.0
		} else {
		    for {set targetCol 0} {$targetCol < $data(colCount)} \
			{incr targetCol} {
			if {!$data($targetCol-hide)} {
			    break
			}
		    }
		    set master $data(hdrTxtFr)
		    set relx 0.0
		}

		#
		# Visualize the would-be target position
		# of the clicked label if appropriate
		#
		if {$targetCol == $col || $targetCol == $col + 1 ||
		    ($data(-protecttitlecolumns) &&
		     (($col >= $data(-titlecolumns) &&
		       $targetCol < $data(-titlecolumns)) ||
		      ($col < $data(-titlecolumns) &&
		       $targetCol > $data(-titlecolumns))))} {
		    catch {unset data(targetCol)}
		    configLabel $w -cursor $data(-cursor)
		    $data(hdrTxtFrCanv)$col configure -cursor $data(-cursor)
		    place forget $data(colGap)
		} else {
		    set data(targetCol) $targetCol
		    set data(master) $master
		    set data(relx) $relx
		    configLabel $w -cursor $data(-movecolumncursor)
		    $data(hdrTxtFrCanv)$col configure -cursor \
					    $data(-movecolumncursor)
		    place $data(colGap) -in $master -anchor n \
					-bordermode outside \
					-relheight 1.0 -relx $relx
		}
	    }
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::labelB1Enter
#
# This procedure is invoked when the mouse pointer enters the header label w of
# a tablelist widget while mouse button 1 is down.  If the label was not
# previously clicked then nothing happens.  Otherwise, if this event occured
# during a column resize operation then the procedure updates the mouse cursor
# accordingly.  Otherwise it changes the label's relief to sunken.
#------------------------------------------------------------------------------
proc tablelist::labelB1Enter w {
    if {![parseLabelPath $w win col]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {!$data(labelClicked)} {
	return ""
    }

    configLabel $w -cursor $data(-cursor)

    if {[info exists data(colBeingResized)]} {	;# resize operation in progress
	configLabel $w -cursor $data(-resizecursor)
    } else {
	set data(inClickedLabel) 1
	if {$data(changeRelief)} {
	    configLabel $w -relief sunken -pressed 1
	}
    }
}

#------------------------------------------------------------------------------
# tablelist::labelB1Leave
#
# This procedure is invoked when the mouse pointer leaves the header label w of
# a tablelist widget while mouse button 1 is down.  If the label was not
# previously clicked then nothing happens.  Otherwise, if no column resize
# operation is in progress then the procedure restores the label's relief, and,
# if the columns are movable, then it changes the mouse cursor, too.
#------------------------------------------------------------------------------
proc tablelist::labelB1Leave {w x y} {
    if {![parseLabelPath $w win col]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {!$data(labelClicked) ||
	[info exists data(colBeingResized)]} {	;# resize operation in progress
	return ""
    }

    #
    # The following code is needed because the event
    # can also occur in a widget placed into the label
    #
    if {$x >= 1 && $x < [winfo width $w] - 1 &&
	$y >= 0 && $y < [winfo height $w]} {
	return ""
    }

    set data(inClickedLabel) 0
    configLabel $w -relief $data(relief) -pressed 0
}

#------------------------------------------------------------------------------
# tablelist::labelB1Up
#
# This procedure is invoked when mouse button 1 is released, if it was
# previously clicked in a label of the tablelist widget win.  If this event
# occured during a column resize operation then the procedure redisplays the
# column and stretches the stretchable columns.  Otherwise, if the mouse button
# was released in the previously clicked label then the procedure restores the
# label's relief and invokes the command specified by the -labelcommand or
# -labelcommand2 configuration option, passing to it the widget name and the
# column number as arguments.  Otherwise the column of the previously clicked
# label is moved before the column containing the mouse cursor or to its right,
# if the columns are movable.
#------------------------------------------------------------------------------
proc tablelist::labelB1Up {w X} {
    if {![parseLabelPath $w win col]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {!$data(labelClicked)} {
	return ""
    }

    if {[info exists data(colBeingResized)]} {	;# resize operation in progress
	configLabel $w -cursor $data(-cursor)
	if {[winfo exists $data(focus)]} {
	    focus $data(focus)
	}
	bind [winfo toplevel $win] <Escape> $data(topEscBinding)
	set col $data(colBeingResized)
	if {$data(colResized)} {
	    if {$data(-width) <= 0} {
		$data(hdr) configure -width $data(hdrPixels)
		$data(lb) configure -width \
			  [expr {$data(hdrPixels) / $data(charWidth)}]
	    } elseif {[info exists data(stretchableCols)] &&
		      [lsearch -exact $data(stretchableCols) $col] >= 0} {
		set oldColWidth \
		    [expr {$data(oldStretchedColWidth) - $data(oldColDelta)}]
		set stretchedColWidth \
		    [expr {$data(oldStretchedColWidth) + $X - $data(X)}]
		if {$oldColWidth < $data(stretchablePixels) &&
		    $stretchedColWidth >= $data(minColWidth) &&
		    $stretchedColWidth < $oldColWidth + $data(delta)} {
		    #
		    # Compute the new column width,
		    # using the following equations:
		    #
		    # $colWidth = $stretchedColWidth - $colDelta
		    # $colDelta / $colWidth =
		    #    ($data(delta) - $colWidth + $oldColWidth) /
		    #    ($data(stretchablePixels) + $colWidth - $oldColWidth)
		    #
		    set colWidth [expr {
			$stretchedColWidth *
			($data(stretchablePixels) - $oldColWidth) /
			($data(stretchablePixels) + $data(delta) -
			 $stretchedColWidth)
		    }]
		    if {$colWidth < 1} {
			set colWidth 1
		    }
		    set idx [expr {3*$col}]
		    set data(-columns) \
			[lreplace $data(-columns) $idx $idx -$colWidth]
		    set idx [expr {2*$col}]
		    set data(colList) \
			[lreplace $data(colList) $idx $idx $colWidth]
		    set data($col-delta) [expr {$stretchedColWidth - $colWidth}]
		}
	    }
	}
	unset data(colBeingResized)
	$data(body) tag remove visibleLines 1.0 end
	$data(body) tag configure visibleLines -tabs {}

	if {$data(colResized)} {
	    redisplayCol $win $col 0 last
	    adjustColumns $win {} 0
	    stretchColumns $win $col
	    updateColors $win

	    genVirtualEvent $win <<TablelistColumnResized>> $col
	}
    } else {
	if {[info exists data(X)]} {
	    unset data(X)
	    after cancel $data(afterId)
	    set data(afterId) ""
	}
    	if {$data(-movablecolumns)} {
	    if {[winfo exists $data(focus)]} {
		focus $data(focus)
	    }
	    bind [winfo toplevel $win] <Escape> $data(topEscBinding)
	    place forget $data(colGap)
	}

	if {$data(inClickedLabel)} {
	    configLabel $w -relief $data(relief) -pressed 0
	    if {$data(shiftPressed)} {
		if {[info exists data($col-labelcommand2)]} {
		    uplevel #0 $data($col-labelcommand2) [list $win $col]
		} elseif {[string length $data(-labelcommand2)] != 0} {
		    uplevel #0 $data(-labelcommand2) [list $win $col]
		}
	    } else {
		if {[info exists data($col-labelcommand)]} {
		    uplevel #0 $data($col-labelcommand) [list $win $col]
		} elseif {[string length $data(-labelcommand)] != 0} {
		    uplevel #0 $data(-labelcommand) [list $win $col]
		}
	    }
	} elseif {$data(-movablecolumns)} {
	    $data(hdrTxtFrCanv)$col configure -cursor $data(-cursor)
	    if {[info exists data(targetCol)]} {
		set sourceColName [doColCget $col $win -name]
		set targetColName [doColCget $data(targetCol) $win -name]

		moveCol $win $col $data(targetCol)

		set userData \
		    [list $col $data(targetCol) $sourceColName $targetColName]
		genVirtualEvent $win <<TablelistColumnMoved>> $userData

		unset data(targetCol)
	    }
	}
    }

    set data(labelClicked) 0
}

#------------------------------------------------------------------------------
# tablelist::labelB3Down
#
# This procedure is invoked when mouse button 3 is pressed in the header label
# w of a tablelist widget.  If the Shift key was down when this event occured
# then the procedure restores the last static width of the given column;
# otherwise it configures the width of the given column to be just large enough
# to hold all the elements (including the label).
#------------------------------------------------------------------------------
proc tablelist::labelB3Down {w shiftPressed} {
    if {![parseLabelPath $w win col]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {!$data(isDisabled) &&
	$data(-resizablecolumns) && $data($col-resizable)} {
	if {$shiftPressed} {
	    doColConfig $col $win -width -$data($col-lastStaticWidth)
	} else {
	    doColConfig $col $win -width 0
	}

	genVirtualEvent $win <<TablelistColumnResized>> $col
    }
}

#------------------------------------------------------------------------------
# tablelist::labelDblB1
#
# This procedure is invoked when the header label w of a tablelist widget is
# double-clicked.  If the pointer is on the right border of the label then the
# procedure performs the same action as labelB3Down.
#------------------------------------------------------------------------------
proc tablelist::labelDblB1 {w x shiftPressed} {
    if {![parseLabelPath $w win col]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {!$data(isDisabled) && [inResizeArea $w $x col] &&
	$data(-resizablecolumns) && $data($col-resizable)} {
	if {$shiftPressed} {
	    doColConfig $col $win -width -$data($col-lastStaticWidth)
	} else {
	    doColConfig $col $win -width 0
	}

	genVirtualEvent $win <<TablelistColumnResized>> $col
    }
}

#------------------------------------------------------------------------------
# tablelist::escape
#
# This procedure is invoked to process <Escape> events in the top-level window
# containing the tablelist widget win during a column resize or move operation.
# The procedure cancels the action in progress and, in case of column resizing,
# it restores the initial width of the respective column.
#------------------------------------------------------------------------------
proc tablelist::escape {win col} {
    upvar ::tablelist::ns${win}::data data
    set w $data(hdrTxtFrLbl)$col
    if {[info exists data(colBeingResized)]} {	;# resize operation in progress
	configLabel $w -cursor $data(-cursor)
	update idletasks
	if {![array exists ::tablelist::ns${win}::data]} {
	    return ""
	}
	if {[winfo exists $data(focus)]} {
	    focus $data(focus)
	}
	bind [winfo toplevel $win] <Escape> $data(topEscBinding)
	set data(labelClicked) 0
	set col $data(colBeingResized)
	set idx [expr {3*$col}]
	setupColumns $win [lreplace $data(-columns) $idx $idx \
				    $data(configColWidth)] 0
	redisplayCol $win $col $data(topRow) $data(btmRow)
	unset data(colBeingResized)
	$data(body) tag remove visibleLines 1.0 end
	$data(body) tag configure visibleLines -tabs {}
	adjustColumns $win {} 1
	updateColors $win
    } elseif {!$data(inClickedLabel)} {
	configLabel $w -cursor $data(-cursor)
	$data(hdrTxtFrCanv)$col configure -cursor $data(-cursor)
	if {[winfo exists $data(focus)]} {
	    focus $data(focus)
	}
	bind [winfo toplevel $win] <Escape> $data(topEscBinding)
	place forget $data(colGap)
	catch {unset data(targetCol)}
	if {[info exists data(X)]} {
	    unset data(X)
	    after cancel $data(afterId)
	    set data(afterId) ""
	}
	set data(labelClicked) 0
    }
}

#------------------------------------------------------------------------------
# tablelist::horizAutoScan
#
# This procedure is invoked when the mouse leaves the scrollable part of a
# tablelist widget's header frame while button 1 is down.  It scrolls the
# header and reschedules itself as an after command so that the header
# continues to scroll until the mouse moves back into the window or the mouse
# button is released.
#------------------------------------------------------------------------------
proc tablelist::horizAutoScan win {
    if {![array exists ::tablelist::ns${win}::data]} {
	return ""
    }

    upvar ::tablelist::ns${win}::data data
    if {![info exists data(X)]} {
	return ""
    }

    set X $data(X)
    set hdrX [winfo rootx $data(hdr)]
    if {$data(-titlecolumns) == 0 || ![winfo viewable $data(sep)]} {
	set leftX $hdrX
    } else {
	set leftX [expr {[winfo rootx $data(sep)] + 1}]
    }
    set rightX [expr {$hdrX + [winfo width $data(hdr)]}]
    if {$data(-titlecolumns) == 0} {
	set units 2
	set ms 50
    } else {
	set units 1
	set ms 250
    }

    if {$X >= $rightX} {
	::$win xview scroll $units units
    } elseif {$X < $leftX} {
	::$win xview scroll -$units units
    } else {
	return ""
    }

    set data(afterId) [after $ms [list tablelist::horizAutoScan $win]]
}

#------------------------------------------------------------------------------
# tablelist::inResizeArea
#
# Checks whether the given x coordinate relative to the header label w of a
# tablelist widget is in the resize area of that label or of the one to its
# left.
#------------------------------------------------------------------------------
proc tablelist::inResizeArea {w x colName} {
    if {![parseLabelPath $w dummy _col]} {
	return 0
    }


    upvar $colName col
    if {$x >= [winfo width $w] - 5} {
	set col $_col
	return 1
    } elseif {$x < 5} {
	set X [expr {[winfo rootx $w] - 3}]
	set contW [winfo containing -displayof $w $X [winfo rooty $w]]
	return [parseLabelPath $contW dummy col]
    } else {
	return 0
    }
}
