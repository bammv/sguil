# $Id: stdquery.tcl,v 1.10 2007/03/17 02:43:37 bamm Exp $ #

# stdquery.tcl launches a popup containing global and user
# queries. It returns the WHERE clause of the selected 
# query or nothing if no query was selected.

proc StdQuery {} {
  global commentBox whereBox STD_QRY_TYPE RETURN_FLAG1

  # Zero out the query
  set STD_QRY_TYPE "event"
  set RETURN_FLAG1 0
  # Grab the current pointer locations
  set xy [winfo pointerxy .]

  # Create the window
  set stdQryWin [toplevel .stdQryWin]
  wm title $stdQryWin "Standard Queries"
  wm geometry $stdQryWin +[lindex $xy 0]+[lindex $xy 1]

  # File menu contains Add, Delete, and Edit
  set fMenuButton [menubutton $stdQryWin.fMenuButton -text File -underline 0 -menu $stdQryWin.fMenuButton.fMenu]
  set fMenu [menu $fMenuButton.fMenu -tearoff 0]
  $fMenu add command -label "Add Query" -command "UserQryWiz Add $stdQryWin"
  $fMenu add command -label "Delete Query" -command "DelQry $stdQryWin"
  $fMenu add command -label "Edit Query" -command "UserQryWiz Edit $stdQryWin"
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
      $bb add submit -text "Submit" -command "set RETURN_FLAG1 1"
      $bb add qrybld -text "Query Builder" -command "set RETURN_FLAG1 2"
      $bb add abort -text "Abort" -command "set RETURN_FLAG1 0"

    pack $commentBox $whereBox $bb -side top -fill both -expand true

  pack $listsFrame $detailFrame -side left -fill both -expand true
  pack $mainFrame -side top
  
  tkwait variable RETURN_FLAG1
    
  if { $RETURN_FLAG1 == 0 } { destroy $stdQryWin; return }
  regsub -all {\n} [$whereBox get 0.0 end] {} Std_Qry
 

  if { $RETURN_FLAG1 == 2 } { 
      destroy $stdQryWin
      set whereStatement [QryBuild $STD_QRY_TYPE $Std_Qry] 
      if { [lindex $whereStatement 0]=="cancel" } {return}
  }
  if { $RETURN_FLAG1 == 1 } { set whereStatement [list $STD_QRY_TYPE $Std_Qry] }
  
  if { [lindex $whereStatement 0] == "sessions" } {
    destroy $stdQryWin 
    SsnQueryRequest [lindex $whereStatement 1]
  } else {
    destroy $stdQryWin
    DBQueryRequest event [list [lindex $whereStatement 1]]
  }
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
  global USER_QRY_LIST uComment uWhere uType uName
  $win delete 0 end
  ReadQryFile
  if { ![info exists USER_QRY_LIST] } { puts "whoops"; return }
  set cIndex 0
  foreach userQry $USER_QRY_LIST {
    if { [regexp {^(.*)\|\|(.*)\|\|(.*)\|\|(.*)$} $userQry match name comment where type] } {
      $win insert end "$name ($type)"
      set uName($cIndex) $name
      set uComment($cIndex) $comment
      set uWhere($cIndex) $where
      set uType($cIndex) $type
      incr cIndex
    }
  }
}
proc GlobalQuerySelect { listName } {
  global gComment gWhere gType commentBox whereBox STD_QRY_TYPE
  $commentBox clear
  $whereBox clear
  set cIndex [$listName curselection]
  $commentBox insert end $gComment($cIndex)
  $whereBox insert end $gWhere($cIndex)
  set STD_QRY_TYPE $gType($cIndex)  
}
proc UserQuerySelect { listName } {
  global USER_QRY_LIST commentBox whereBox uWhere uComment uType uIndex STD_QRY_TYPE
  $commentBox clear
  $whereBox clear
  set uIndex [$listName curselection]
  #puts "||$uIndex||"
  $commentBox insert end $uComment($uIndex)
  $whereBox insert end $uWhere($uIndex)
  set STD_QRY_TYPE $uType($uIndex)  
}
proc ReadQryFile {} {
    global USER_QRY_FILE USER_QRY_LIST
    set USER_QRY_LIST ""
    if { [file exists $USER_QRY_FILE] } {
	for_file userQry $USER_QRY_FILE {
	    if {![regexp ^# $userQry]} {
		lappend USER_QRY_LIST $userQry
	    }
	}
    } 
}

proc UpdateQryType { win } {
  global STD_QRY_TYPE
    
  set STD_QRY_TYPE [$win get]
 
}
proc UserQryWiz {type stdQryWin} {
  
  set NEW_QUERY ""
    if {$type == "Edit"} {
	if { [string trim [$stdQryWin.mFrame.lFrame.uList getcurselection]] == ""} {
	  
	    InfoMessage "Please Select a User Query to Edit"
	    return
	}
    }

  set xy [winfo pointerxy .]

  set win [toplevel .userQryWiz]
  wm title $win "$type User Query"
  wm geometry $win +[lindex $xy 0]+[lindex $xy 1]
  
  set frame1 [frame $win.frame1]
  set typeWin [optionmenu $frame1.om -labeltext "Type:" -command "UpdateQryType $frame1.om"]
  $typeWin insert end event
  #$typeWin insert end sessions
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
      $winBB add okay -text "Save" -command "SaveUserQry $type $win $stdQryWin"
      $winBB add qryBld -text "Query Builder" -command "InvokeQryBld $win"
      $winBB add cancel -text "Cancel" -command "destroy $win"
  
  # if this is an edit, preload the info from the selected query into the window
  if { $type == "Edit"} {
      global uWhere uType uName uComment uIndex
      $typeWin select $uType($uIndex)
      $nameWin insert end $uName($uIndex)
      $commentWin insert end $uComment($uIndex)
      $whereBox insert end $uWhere($uIndex)
  }
      
  pack $frame1 $commentWin $whereBox $winBB -side top -fill both -expand true

  tkwait window $win

}

proc InvokeQryBld { win } {
    
    set whereTmp [$win.wBox get 0.0 end]
    set tableName [$win.frame1.om get]
    set whereTmp [string trim $whereTmp]   
    if {$whereTmp == ""} {
	set whereTmp "empty"
    }
    set tmpWhereStatement [QryBuild $tableName $whereTmp]
    if { [lindex $tmpWhereStatement 0] != "cancel"} {
	$win.wBox delete 0.0 end
	$win.wBox insert 0.0 [lindex $tmpWhereStatement 1]
	$win.frame1.om select [lindex $tmpWhereStatement 0]
    }
}

proc SaveUserQry {type win stdQryWin} {
    global USER_QRY_FILE USER_QRY_LIST uIndex
    set newName [$win.frame1.ef get]

    # Build the string to add/edit into the list 
    regsub -all {\n} [$win.cBox get 0.0 end] {} newComment
    regsub -all {\n} [$win.wBox get 0.0 end] {} newWhere
    set newTable [$win.frame1.om get]
    set newQry "$newName||$newComment||$newWhere||$newTable"
    
    if { $type == "Add"} {
	lappend USER_QRY_LIST $newQry
    } else {
	set USER_QRY_LIST [lreplace $USER_QRY_LIST $uIndex $uIndex $newQry]
    }

    # Write out the new list of User Queries to the file
    WriteUserQryFile

    destroy $win
    # refresh the list from the file.
    InsertUserQueries $stdQryWin.mFrame.lFrame.uList	
    # refresh the selected User Query
    catch {$stdQryWin.mFrame.lFrame.uList component listbox selection set $uIndex}
   
}    

proc DelQry {stdQryWin} {
    global USER_QRY_LIST uIndex
    
    if { [string trim [$stdQryWin.mFrame.lFrame.uList getcurselection]] == ""} {
	  
            tk_messageBox -type ok -icon info -parent $stdQryWin\
             -message "Please Select a User Query to Delete"
	    return
	}
    set answer [tk_messageBox -message "ARE YOU SURE you want to delete this query?" -type yesno -icon question]
    if {$answer == "yes"} {
	set USER_QRY_LIST [lreplace $USER_QRY_LIST $uIndex $uIndex]
	WriteUserQryFile
	InsertUserQueries $stdQryWin.mFrame.lFrame.uList
	# The following line will produce an error if this is the first User Query added, lets just ignore it.
	catch {$stdQryWin.mFrame.lFrame.uList component listbox selection set $uIndex}
    }
}

proc WriteUserQryFile {} {
    global USER_QRY_FILE USER_QRY_LIST

     if [catch {open $USER_QRY_FILE w} fileID] {
	puts "Error: Could not create/open $USER_QRY_FILE: $fileID"
	exit
    } else {
	puts $fileID "#"
	puts $fileID "# WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING"
	puts $fileID "#"
	puts $fileID "# This file is automatically generated. Please do not edit it by hand."
	puts $fileID "# Doing so could corrupt the file and make it unreadable."
	puts $fileID "#"
	puts $fileID "# WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING"
	puts $fileID "#"
	foreach userQry $USER_QRY_LIST {
	    puts $fileID $userQry
	}
	close $fileID
    }
}
