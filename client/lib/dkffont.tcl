namespace eval ::dkfFontSel {

    # Local procedure names (ones that it is a bad idea to refer to
    # outside this namespace/file) are prepended with an apostrophe
    # character.  There are no externally useful variables.

    # First some library stuff that is normally in another namespace

    # Simple (nay, brain-dead) option parser.  Given the list of
    # arguments in arglist and the list of legal options in optlist,
    # parse the options to convert into array values (which are stored
    # in the caller's array named in optarray.  Does not handle errors
    # spectacularly well, and can be replaced by something that does a
    # better job without me feeling to fussed about it!
    proc 'parse_opts {arglist optlist optarray} {
	upvar $optarray options
	set options(foo) {}
	unset options(foo)
	set callername [lindex [info level -1] 0]
	if {[llength $arglist]&1} {
	    return -code error \
		    "Must be an even number of arguments to $callername"
	}
	array set options $arglist
	foreach key [array names options] {
	    if {![string match -?* $key]} {
		return -code error "All parameter keys must start\
			with \"-\", but \"$key\" doesn't"
	    }
	    if {[lsearch -exact $optlist $key] < 0} {
		return -code error "Bad parameter \"$key\""
	    }
	}
    }

    # Capitalise the given word.  Assumes the first capitalisable
    # letter is the first character in the argument.
    proc 'capitalise {word} {
	set cUpper [string toupper [string index $word 0]]
	set cLower [string tolower [string range $word 1 end]]
	return ${cUpper}${cLower}
    }

    # The classic functional operation.  Replaces each element of the
    # input list with the result of running the supplied script on
    # that element.
    proc 'map {script list} {
	set newlist {}
	foreach item $list {
	    lappend newlist [uplevel 1 $script [list $item]]
	}
	return $newlist
    }

    # ----------------------------------------------------------------------
    # Now we start in earnest
    namespace export dkf_chooseFont

    variable Family Helvetica
    variable Size   12
    variable Done   0
    variable Win    {}

    array set Style {
	bold 0
	italic 0
	underline 0
	overstrike 0
    }

    # Get the gap spacing for the frameboxes.  Use a user-specified
    # default if there is one (that is a valid integer) and fall back
    # to measuring/guessing otherwise.
    proc 'get_gap {w} {
	set gap [option get $w lineGap LineGap]
	if {[catch {incr gap 0}]} {
	    # Some cunning font measuring!
	    label $w._testing
	    set font [$w._testing cget -font]
	    set gap [expr {[font metrics $font -linespace]/2+1}]
	    destroy $w._testing
	}
	return $gap
    }


    # Build the user interface (except for the apply button, which is
    # handled by the 'configure_apply procedure...
    proc 'make_UI {w} {
	# Framed regions.  Do this with grid and labels, as that seems
	# to be the most effective technique in practise!
	frame $w.border1 -class DKFChooseFontFrame
	frame $w.border2 -class DKFChooseFontFrame
	frame $w.border3 -class DKFChooseFontFrame
	frame $w.border4 -class DKFChooseFontFrame
	set gap ['get_gap $w]
	grid $w.border1 -row 0 -column 0 -rowspan 4 -columnspan 4 \
		-padx $gap -pady $gap -sticky nsew
	grid $w.border2 -row 0 -column 4 -rowspan 4 -columnspan 3 \
		-padx $gap -pady $gap -sticky nsew
	grid $w.border3 -row 4 -column 0 -rowspan 3 -columnspan 9 \
		-padx $gap -pady $gap -sticky nsew
	grid $w.border4 -row 7 -column 0 -rowspan 3 -columnspan 9 \
		-padx $gap -pady $gap -sticky nsew
	incr gap $gap
	foreach col {0 3 4 6 8} {
	    grid columnconfigure $w $col -minsize $gap
	}
	foreach row {0 3 4 6 7 9} {
	    grid rowconfigure    $w $row -minsize $gap
	}
	grid columnconfigure $w 1 -weight 1
	grid rowconfigure    $w 1 -weight 1
	grid rowconfigure    $w 8 -weight 1


	# Labels for the framed boxes & focus accelerators for their contents
	foreach {subname row col focusWin} {
	    Family 0 1 .family     
	    Style  0 5 .style.sBold
	    Size   4 1 .size.b8    
	    Sample 7 1 .sample.text
	} {
	    set l [label $w.lbl$subname]
	    grid $l -row $row -column $col -sticky w
	    set accel ['get_accel $l]
	    if {[string length $accel]} {
		bind $w <$accel> [list focus $w$focusWin]
	    }
	}


	# Font families
	frame $w.familyBox
	listbox $w.family -exportsel 0 -selectmode browse \
		-xscrollcommand [list $w.familyX set] \
		-yscrollcommand [list $w.familyY set] -width 20
	scrollbar $w.familyX -command [list $w.family xview]
	scrollbar $w.familyY -command [list $w.family yview]
	foreach family ['list_families] {
	    $w.family insert end ['map 'capitalise $family]
	}
	grid $w.familyBox -row 1 -column 1 -rowspan 1 -columnspan 2 \
		-sticky nsew
	grid columnconfigure $w.familyBox 0 -weight 1
	grid rowconfigure    $w.familyBox 0 -weight 1
	grid $w.family  $w.familyY -sticky nsew -in $w.familyBox
	grid $w.familyX            -sticky nsew -in $w.familyBox
	bind $w.family <1> [namespace code {'change_family %W [%W nearest %y]}]
	bindtags $w.family [concat [bindtags $w.family] key$w.family]
	bind key$w.family <Key> [namespace code {'change_family %W active %A}]


	# Font styles.
	frame $w.style
	grid $w.style -row 1 -column 5 -sticky news
	grid columnconfigure $w.style 0 -weight 1
	foreach {fontstyle lcstyle row next prev} {
	    Bold      bold       0 Italic    {}
	    Italic    italic     1 Underline Bold
	    Underline underline  2 Strikeout Italic
	    Strikeout overstrike 3 {}        Underline
	} {
	    set b $w.style.s$fontstyle
	    checkbutton $b -variable [namespace current]::Style($lcstyle) \
		    -command [namespace code 'set_font]
	    grid $b -sticky nsew -row $row
	    grid rowconfigure $w.style $row -weight 1
	    if {[string length $next]} {
		bind $b <Down> [list focus $w.style.s$next]
	    }
	    if {[string length $prev]} {
		bind $b <Up> [list focus $w.style.s$prev]
	    }
	    bind $b <Tab>       "[list focus $w.size.b8];break"
	    bind $b <Shift-Tab> "[list focus $w.family ];break"
	    set accel ['get_accel $b]
	    if {[string length $accel]} {
		bind $w <$accel> "focus $b; $b invoke"
	    }
	    bind $b <Return> "$b invoke; break"
	}


	# Size adjustment.  Common sizes with radio buttons, and an
	# entry for everything else.
	frame $w.size
	grid $w.size -row 5 -column 1 -rowspan 1 -columnspan 7 -sticky nsew
	foreach {size row col u d l r} {
	    8  0 0  {} 10 {} 12
	    10 1 0   8 {} {} 14
	    12 0 1  {} 14  8 18
	    14 1 1  12 {} 10 24
	    18 0 2  {} 24 12 {}
	    24 1 2  18 {} 14 {}
	} {
	    set b $w.size.b$size
	    radiobutton $b -variable [namespace current]::Size -value $size \
		    -command [namespace code 'set_font]
	    grid $b -row $row -column $col -sticky ew
	    #grid columnconfigure $w.size $col -weight 1
	    if {[string length $u]} {bind $b <Up>    [list focus $w.size.b$u]}
	    if {[string length $d]} {bind $b <Down>  [list focus $w.size.b$d]}
	    if {[string length $l]} {bind $b <Left>  [list focus $w.size.b$l]}
	    if {[string length $r]} {bind $b <Right> [list focus $w.size.b$r]}
	    bind $b <Tab>       "[list focus $w.size.entry ];break"
	    bind $b <Shift-Tab> "[list focus $w.style.sBold];break"
	    set accel ['get_accel $b]
	    if {[string length $accel]} {
		bind $w <$accel> "focus $b; $b invoke"
	    }
	    bind $b <Return> "$b invoke; break"
	}
	entry $w.size.entry -textvariable [namespace current]::Size
	grid $w.size.entry -row 0 -column 3 -rowspan 2 -sticky ew
	grid columnconfigure $w.size 3 -weight 1
	bind $w.size.entry <Return> \
		[namespace code {'set_font;break}]


	# Sample text.  Note that this is editable
	frame $w.sample
	grid $w.sample -row 8 -column 1 -columnspan 7 -sticky nsew
	grid propagate $w.sample 0
	entry $w.sample.text -background [$w.sample cget -background]
	$w.sample.text insert 0 [option get $w.sample.text text Text]
	grid $w.sample.text


	# OK, Cancel and (partially) Apply.  See also 'configure_apply
	frame $w.butnframe
	grid $w.butnframe -row 0 -column 7 -rowspan 4 -columnspan 2 \
		-sticky nsew -pady $gap
	foreach {but code} {
	    ok  0
	    can 1
	} {
	    button $w.butnframe.$but -command \
		    [namespace code [list set Done $code]]
	    pack $w.butnframe.$but -side top -fill x -padx [expr {$gap/2}] \
		    -pady [expr {$gap/2}]
	}
	button $w.butnframe.apl
	bind $w.butnframe.ok <Down> [list focus $w.butnframe.can]
	bind $w.butnframe.can <Up> [list focus $w.butnframe.ok]
    }


    # Convenience proc to get the accelerator for a particular window
    # if the user has given one.  Makes it simpler to get this right
    # everywhere it is needed...
    proc 'get_accel {w} {
	option get $w accelerator Accelerator
    }


    # Called when changing the family.  Sets the family to either be
    # the first family whose name starts with the given character (if
    # char is non-empty and not special) or to be the name of the
    # family at the given index of the listbox.
    proc 'change_family {w index {char {}}} {
	variable Family
	if {[string length $char] && ![regexp {[]*?\\[]} $char]} {
	    set idx [lsearch -glob ['list_families] $char*]
	    if {$idx >= 0} {
		set index $idx
		$w activate $idx
		$w selection clear 0 end
		$w selection anchor $idx
		$w selection set $idx
		$w see $idx
	    }
	}
	set Family [$w get $index]
	##DEBUG
	#wm title [winfo toplevel $w] $Family
	'set_font
    }


    # The apply button runs this script when pressed.
    proc 'do_apply {w script} {
	'set_font
	set font [$w.sample.text cget -font]
	uplevel #0 $script [list $font]
    }


    # Based on whether the supplied script is empty or not, install an
    # apply button into the dialog.  This is not part of 'make_UI
    # since it happens at a different stage of initialisation.
    proc 'configure_apply {w script} {
	set b $w.butnframe.apl
	set binding [list $b invoke]
	if {[string length $script]} {
	    # There is a script, so map the button
	    array set packinfo [pack info $w.butnframe.ok]
	    $b configure -command [namespace code [list 'do_apply $w $script]]
	    pack $b -side top -fill x -padx $packinfo(-padx) \
		    -pady $packinfo(-pady)

	    bind $w.butnframe.can <Down> [list focus $w.butnframe.apl]
	    bind $w.butnframe.apl <Up>   [list focus $w.butnframe.can]

	    # Set up accelerator.  Tricky since we want to force a
	    # systematic match with the underline
	    set uline [$b cget -underline]
	    if {$uline>=0} {
		set uchar [string index [$b cget -text] $uline]
		set uchar [string tolower $uchar]
		bind $w <Meta-$uchar> $binding
	    }

	} else {
	    # No script => no button
	    set manager [winfo manager $b]
	    if {[string length $manager]} {
		$manager forget $b

		# Now we must remove the accelerator!  This is tricky
		# since we don't actually know what it is officially
		# bound to...
		foreach bindseq [bind $w] {
		    if {![string compare [bind $w $bindseq] $binding]} {
			bind $w $bindseq {}
			break
		    }
		}

	    }
	}
    }


    # Set the font on the editor window based on the information in
    # the namespace variables.  Returns a 1 if the operation was a
    # failure and 0 if it iwas a success.
    proc 'set_font {} {
	variable Family
	variable Style
	variable Size
	variable Win

	set styles {}
	foreach style {italic bold underline overstrike} {
	    if {$Style($style)} {
		lappend styles $style
	    }
	}
	if {[catch {
	    expr {$Size+0}
	    if {[llength $styles]} {
		$Win configure -font [list $Family $Size $styles]
	    } else {
		$Win configure -font [list $Family $Size]
	    }
	} s]} {
	    bgerror $s
	    return 1
	}
	return 0
    }


    # Get a sorted lower-case list of all the font families defined on
    # the system.  A canonicalisation of [font families]
    proc 'list_families {} {
	lsort [string tolower [font families]]
    }

    # ----------------------------------------------------------------------

    proc dkf_chooseFont {args} {
	variable Family
	variable Style
	variable Size
	variable Done
	variable Win

	array set options {
	    -parent {}
	    -title {Select a font}
	    -initialfont {}
	    -apply {}
	}
	'parse_opts $args [array names options] options
	switch -exact -- $options(-parent) {
	    . - {} {
		set parent .
		set w .__dkf_chooseFont
	    }
	    default {
		set parent $options(-parent)
		set w $options(-parent).__dkf_chooseFont
	    }
	}
	catch {destroy $w}

	toplevel $w -class DKFChooseFont
	wm title $w $options(-title)
	wm transient $w $parent
	wm iconname $w ChooseFont
	wm group $w $parent
	wm protocol $w WM_DELETE_WINDOW {#}

	if {![string length $options(-initialfont)]} {
	    set options(-initialfont) [option get $w initialFont InitialFont]
	}

	set Win $w.sample.text
	'make_UI $w
	bind $w <Return>  [namespace code {set Done 0}]
	bind $w <Escape>  [namespace code {set Done 1}]
	bind $w <Destroy> [namespace code {set Done 1}]
	focus $w.butnframe.ok

	'configure_apply $w $options(-apply)

	foreach style {italic bold underline overstrike} {
	    set Style($style) 0
	}
	foreach {family size styles} $options(-initialfont) {break}
	set Family $family
	set familyIndex [lsearch -exact ['list_families] \
		[string tolower $family]]
	if {$familyIndex<0} {
	    wm withdraw $w
	    tk_messageBox -type ok -icon warning -title "Bad Font Family" \
		    -message "Font family \"$family\" is unknown.  Guessing..."
	    set family [font actual $options(-initialfont) -family]
	    set familyIndex [lsearch -exact ['list_families] \
		    [string tolower $family]]
	    if {$familyIndex<0} {
		return -code error "unknown font family fallback \"$family\""
	    }
	    wm deiconify $w
	}
	$w.family selection set $familyIndex
	$w.family see $familyIndex
	set Size $size
	foreach style $styles {set Style($style) 1}

	'set_font

	wm withdraw $w
	update idletasks
	if {$options(-parent)==""} {
	    set x [expr {([winfo screenwidth $w]-[winfo reqwidth $w])/2}]
	    set y [expr {([winfo screenheigh $w]-[winfo reqheigh $w])/2}]
	} else {
	    set pw $options(-parent)
	    set x [expr {[winfo x $pw]+
                         ([winfo width $pw]-[winfo reqwidth $w])/2}]
	    set y [expr {[winfo y $pw]+
                         ([winfo heigh $pw]-[winfo reqheigh $w])/2}]
	}
	wm geometry $w +$x+$y
	update idletasks
	wm deiconify $w
	tkwait visibility $w
	vwait [namespace current]::Done
	if {$Done} {
	    destroy $w
	    return ""
	}
	if {['set_font]} {
	    destroy $w
	    return ""
	}
	set font [$Win cget -font]
	destroy $w
	return $font
    }

    # ----------------------------------------------------------------------
    # I normally load these from a file, but I inline them here for portability
    foreach {pattern value} {
	*DKFChooseFont.DKFChooseFontFrame.borderWidth	2
	*DKFChooseFont.DKFChooseFontFrame.relief	ridge


	*DKFChooseFont.lblFamily.text	       Family
	*DKFChooseFont.lblFamily.underline     0
	*DKFChooseFont.lblFamily.accelerator   Control-f

	*DKFChooseFont.lblStyle.text	       Style
	*DKFChooseFont.lblStyle.underline      2
	*DKFChooseFont.lblStyle.accelerator    Control-y

	*DKFChooseFont.lblSize.text	       Size
	*DKFChooseFont.lblSize.underline       2
	*DKFChooseFont.lblSize.accelerator     Control-z

	*DKFChooseFont.lblSample.text	       Sample


	*DKFChooseFont.style.Checkbutton.anchor		w

	*DKFChooseFont.style.sBold.text	       Bold
	*DKFChooseFont.style.sBold.underline   0
	*DKFChooseFont.style.sBold.accelerator Control-b

	*DKFChooseFont.style.sItalic.text      Italic
	*DKFChooseFont.style.sItalic.underline   0
	*DKFChooseFont.style.sItalic.accelerator Control-i

	*DKFChooseFont.style.sUnderline.text   Underline
	*DKFChooseFont.style.sUnderline.underline   0
	*DKFChooseFont.style.sUnderline.accelerator Control-u

	*DKFChooseFont.style.sStrikeout.text   Overstrike
	*DKFChooseFont.style.sStrikeout.underline   0
	*DKFChooseFont.style.sStrikeout.accelerator Control-o


	*DKFChooseFont.Label.padX	       1m
	*DKFChooseFont.Label.padY	       1

	*DKFChooseFont.family.height	       1
	*DKFChooseFont.family.width	       12
	*DKFChooseFont.familyX.orient	       horizontal
	*DKFChooseFont.Scrollbar.takeFocus     0

	*DKFChooseFont.size.b8.text	       8
	*DKFChooseFont.size.b10.text	       10
	*DKFChooseFont.size.b12.text	       12
	*DKFChooseFont.size.b14.text	       14
	*DKFChooseFont.size.b18.text	       18
	*DKFChooseFont.size.b24.text	       24
	*DKFChooseFont.size.Radiobutton.anchor w
	*DKFChooseFont.size.Entry.background   white

	*DKFChooseFont.sample.text.text	       ABCabcXYZxyz123
	*DKFChooseFont.sample.text.takeFocus   0
	*DKFChooseFont.sample.text.highlightThickness 0
	*DKFChooseFont.sample.text.borderWidth 0
	*DKFChooseFont.sample.text.relief      flat
	*DKFChooseFont.sample.text.width       0
	*DKFChooseFont.sample.text.cursor      {}
	*DKFChooseFont.sample.height	       40
	*DKFChooseFont.sample.width	       40

	*DKFChooseFont.butnframe.ok.default    active
	*DKFChooseFont.butnframe.ok.text       OK
	*DKFChooseFont.butnframe.can.default   normal
	*DKFChooseFont.butnframe.can.text      Cancel
	*DKFChooseFont.butnframe.apl.default   normal
	*DKFChooseFont.butnframe.apl.text      Apply
	*DKFChooseFont.butnframe.apl.underline 0
    } {
	option add $pattern $value startupFile
    }
    switch $tcl_platform(platform) {
	windows {
	    option add *DKFChooseFont.initialFont {Arial 12 bold} startupFile
	}
	default {
	    foreach {pattern value} {
		*DKFChooseFont*Button.BorderWidth      1
		*DKFChooseFont*Checkbutton.BorderWidth 1
		*DKFChooseFont*Entry.BorderWidth       1
		*DKFChooseFont*Label.BorderWidth       1
		*DKFChooseFont*Listbox.BorderWidth     1
		*DKFChooseFont*Menu.BorderWidth	       1
		*DKFChooseFont*Menubutton.BorderWidth  1
		*DKFChooseFont*Message.BorderWidth     1
		*DKFChooseFont*Radiobutton.BorderWidth 1
		*DKFChooseFont*Scale.BorderWidth       1
		*DKFChooseFont*Scrollbar.BorderWidth   1
		*DKFChooseFont*Text.BorderWidth	       1
		*DKFChooseFont.Scrollbar.width         10
		*DKFChooseFont.initialFont             {Helvetica 12 bold}
	    } {
		option add $pattern $value startupFile
	    }
	}
    }

}
namespace import ::dkfFontSel::dkf_chooseFont

# Is there anything already set up as a standard command?
if {![info exist tk_chooseFont]} {
    # If not, set ourselves up using an alias
    interp alias {} tk_chooseFont {} ::dkfFontSel::dkf_chooseFont
}

# ----------------------------------------------------------------------
# Stuff for testing the font selector
#if {![string compare [info script] $argv0]} {
#    wm deiconify .; update
#    # use after idle here to put errors into a dialog for testing...
#    after idle {puts [dkf_chooseFont -apply puts]}
#}
