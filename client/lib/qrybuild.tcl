proc QryBuild {} {
    global RETURN_FLAG
    set RETURN_FLAG 0

    # Grab the current pointer locations
    set xy [winfo pointerxy .]
    
    # Create the window
    set qryBldWin [toplevel .qryBldWin]
    wm title $qryBldWin "Query Builder"
    wm geometry $qryBldWin +[lindex $xy 0]+[lindex $xy 1]
    
    set mlst [list Tables Functions]
    
    # Main Frame
    set mainFrame [frame $qryBldWin.mFrame -background black -borderwidth 1]

    
    
    set editFrame [frame $mainFrame.eFrame]
      set editBox [scrolledtext $editFrame.eBox -textbackground white -vscrollmode dynamic \
		-sbwidth 10 -hscrollmode none -wrap word -visibleitems 80x10 -textfont ourFixedFont \
		-labeltext "Edit Where Clause"]
      $editBox insert end "WHERE event.sid = sensor.sid AND "
      set bb2 [buttonbox $editFrame.bb]
    $bb2 add Submit -text "Submit" -command "set RETURN_FLAG 1"
      pack $editBox $bb2 -side top -fill y -expand true



    set selectFrame [frame $mainFrame.sFrame]
    set itemList [combobox $selectFrame.iList -editable true -dropdown false] 
    set catList [combobox $selectFrame.cList -labeltext Items -editable true -selectioncommand "updateItemList $selectFrame"]
    set metaList [combobox $selectFrame.mList -labeltext Categories -editable false -selectioncommand "updateCatList $selectFrame"]
    
  
      set bb [buttonbox $selectFrame.bb]
    $bb add add -text "Add" -command "addToEditBox $editBox $itemList"
      pack $metaList $catList $itemList $bb -side top -fill y -expand true
    
    
    pack $selectFrame $editFrame -side left -fill y -expand true
    eval $metaList insert list 0 $mlst
    pack $mainFrame -side top

    




    tkwait variable RETURN_FLAG
    set returnWhere 0
    if {$RETURN_FLAG} {
	set returnWhere "[$editBox get 0.0 end]"
	puts $returnWhere
    }
    destroy $qryBldWin
    return $returnWhere  
}


proc updateCatList { selectFrame } {
    global tableList 
     
    $selectFrame.cList delete list 0 end
    $selectFrame.cList delete entry 0 end
    
    set funcList [list Common Strings Comparision]
    set sel [$selectFrame.mList get]

    if {$sel == "Tables"} { 
	eval $selectFrame.cList insert list 0 $tableList
    } else {
	eval $selectFrame.cList insert list 0 $funcList
    }
}
    
proc updateItemList { selectFrame} {
    global  tableColumnArray
    
    $selectFrame.iList delete list 0 end
    $selectFrame.iList delete entry 0 end
    
    eval set sel [$selectFrame.cList get]
    
    if { [$selectFrame.mList get] == "Tables" } {
	eval $selectFrame.iList insert list 0 $tableColumnArray($sel)
    } else {
	# SQL and other Functions listed here
    }
}

proc addToEditBox { editBox itemList } {

    set addText [lindex [$itemList get] 0]
    
    $editBox insert end "$addText "
}