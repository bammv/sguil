# stdquery.tcl launches a popup containing global and user
# queries. It returns the WHERE clause of the selected 
# query or nothing if no query was selected.

proc StdQuery {} {
  global commentBox whereBox STD_QUERY STD_QUERY_TYPE

  # Zero out the query
  set STD_QUERY ""
  set STD_QUERY_TYPE ""
 
  # Grab the current pointer locations
  set xy [winfo pointerxy .]

  # Create the window
  set stdQryWin [toplevel .stdQryWin]
  wm title $stdQryWin "Standard Queries"
  wm geometry $stdQryWin +[lindex $xy 0]+[lindex $xy 1]

  # File menu contains Add, Delete, and Edit
  set fMenuButton [menubutton $stdQryWin.fMenuButton -text File -underline 0 -menu $stdQryWin.fMenuButton.fMenu]
  set fMenu [menu $fMenuButton.fMenu -tearoff 0]
  $fMenu add command -label "Add Query" -command "AddStdUserQuery"
  $fMenu add command -label "Delete Query" -command "DelQuery"
  $fMenu add command -label "Edit Query" -command "EditQuery"
  pack $fMenuButton -side top -anchor w

  # Main Frame
  set mainFrame [frame $stdQryWin.mFrame -background black -borderwidth 1]

  # Lists Frame. Two list allow you to select the std query (user and global).
  set listsFrame [frame $mainFrame.lFrame]
    set globalLists [scrolledlistbox $listsFrame.gList -visibleitems 20x5 -sbwidth 10\
     -labelpos n -labeltext "Global Queries" -vscrollmode static -hscrollmode dynamic\
     -selectioncommand "GlobalQuerySelect $listsFrame.gList"]
    set userLists [scrolledlistbox $listsFrame.uList -visibleitems 20x5 -sbwidth 10\
     -labelpos n -labeltext "User Queries" -vscrollmode static -hscrollmode dynamic\
     -selectioncommand "UserQuerySelect $listsFrame.uList"]
    pack $globalLists $userLists -side top -fill y -expand true

  # Import the global list into the window.
  InsertGlobalQueries $globalLists
  InsertUserQueries $userLists


  # Detail frame contains the query comment, WHERE statement, and buttons
  set detailFrame [frame $mainFrame.dFrame -background lightblue]
    set commentBox [scrolledtext $detailFrame.cBox -visibleitems 70x4 -sbwidth 10\
     -vscrollmode static -hscrollmode dynamic -wrap word -labelpos n\
     -labeltext "Comment"]
    set whereBox [scrolledtext $detailFrame.wBox -visibleitems 70x12 -sbwidth 10\
     -vscrollmode static -hscrollmode dynamic -wrap word -labelpos n\
     -labeltext "Query"]

    set bb [buttonbox $detailFrame.bb]
      $bb add submit -text "Submit" -command "destroy $stdQryWin"
      $bb add abort -text "Abort" -command "set STD_QUERY abort; destroy $stdQryWin"

    pack $commentBox $whereBox $bb -side top -fill both -expand true

  pack $listsFrame $detailFrame -side left -fill both -expand true
  pack $mainFrame -side top
  
  tkwait window $stdQryWin
  return [list $STD_QUERY $STD_QUERY_TYPE]
}
proc InsertGlobalQueries { win } {
  global GLOBAL_QRY_LIST gComment gWhere gType
  set cIndex 0
  foreach globalQry $GLOBAL_QRY_LIST {
    if { [regexp {^(.*)\|\|(.*)\|\|(.*)\|\|(.*)$} $globalQry match name comment where type] } {
      $win insert end "$name ($type)"
      set gComment($cIndex) $comment
      set gWhere($cIndex) $where
      set gType($cIndex) $type
      incr cIndex
    }
  }
}
proc InsertUserQueries { win } {
  global USER_QryList uCommnet uWhere uType
  $win delete 0 end
  if { ![info exists USER_QRY_LIST] } { return }
  set cIndex 0
  foreach userQry $USER_QRY_LIST {
    if { [regexp {^(.*)\|\|(.*)\|\|(.*)\|\|(.*)$} $userQry match name comment where type] } {
      $win insert end "$name ($type)"
      set uComment($cindex) $comment
      set uWhere($cIndex) $where
      set uType($cIndex) $type
      incr cIndex
    }
  }
}
proc GlobalQuerySelect { listName } {
  global gComment gWhere gType commentBox whereBox STD_QUERY STD_QUERY_TYPE
  $commentBox clear
  $whereBox clear
  set cIndex [$listName curselection]
  $commentBox insert end $gComment($cIndex)
  $whereBox insert end $gWhere($cIndex)
  set STD_QUERY $gWhere($cIndex)
  set STD_QUERY_TYPE $gType($cIndex)
}
proc ReadQryFile {} {
  global USER_QRY_FILE USER_QRY_LIST
  set USER_QRY_LIST ""
  if { [file exists $USER_QRY_FILE] } {
    set cIndex 0
    for_file userQry $USER_QRY_FILE {
      lappend USER_QRY_LIST $userQry
    }
  } 
}
proc AddStdUserQuery {} {
  global USER_QRY_FILE
  
  set newQuery [UserQryWiz]
}
proc UserQryWiz {} {

  set NEW_QUERY ""
  
  set xy [winfo pointerxy .]

  set win [toplevel .userQryWiz]
  wm title $win "Add New User Query"
  wm geometry $win +[lindex $xy 0]+[lindex $xy 1]
  
  set frame1 [frame $win.frame1]
  set typeWin [optionmenu $frame1.om -labeltext "Type:" -command "UpdateQryType $win.om"]
  $typeWin insert end event
  $typeWin insert end sessions
  set nameWin [entryfield $frame1.ef -labeltext "Name:" -labelpos w -width 20]
  pack $typeWin -side left
  pack $nameWin -side left -fill x -expand true

  set commentWin [scrolledtext $win.cBox -visibleitems 70x4 -sbwidth 10\
   -vscrollmode static -hscrollmode dynamic -wrap word -labelpos n\
   -labeltext "Comment"]
  set whereBox [scrolledtext $win.wBox -visibleitems 70x12 -sbwidth 10\
   -vscrollmode static -hscrollmode dynamic -wrap word -labelpos n\
   -labeltext "Query"]
  set winBB [buttonbox $win.bb]
      $winBB add okay -text "Add" -command ""
      $winBB add cancel -text "Cancel" -command "destroy $win"

  pack $frame1 $commentWin $whereBox $winBB -side top -fill both -expand true

}

