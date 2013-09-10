# $Id: SguildAccess.tcl,v 1.11 2011/03/17 02:39:29 bamm Exp $ #

# Load up the access lists.
proc LoadAccessFile { filename } {
  global CLIENT_ACCESS_LIST SENSOR_ACCESS_LIST
  LogMessage "Loading access list: $filename" 
  set CANYFLAG 0
  set SANYFLAG 0
  for_file line $filename {
    # Ignore comments (#) and blank lines.
    if { ![regexp ^# $line] && ![regexp {^\s*$} $line] } {
      if { [regexp {^\s*client} $line] && $CANYFLAG != "1" } {
        set ipaddr [lindex $line 1]
        if { $ipaddr == "ANY" || $ipaddr == "any" } {
          set CANYFLAG 1
          set CLIENT_ACCESS_LIST ANY
          LogMessage "Client access list set to ALLOW ANY." 
        } else {
          LogMessage "Adding client to access list: $ipaddr"
          lappend CLIENT_ACCESS_LIST $ipaddr
        }
      } elseif { [regexp {^\s*sensor} $line] && $SANYFLAG != "1" } {
        set ipaddr [lindex $line 1]
        if { $ipaddr == "ANY" || $ipaddr == "any" } {
          set SANYFLAG 1
          set SENSOR_ACCESS_LIST ANY
          LogMessage "Sensor access list set to ALLOW ANY." 
        } else {
          LogMessage "Adding sensor to access list: $ipaddr"
          lappend SENSOR_ACCESS_LIST $ipaddr
        }
      } else {
        ErrorMessage "ERROR: Parsing $filename: Format error: $line"
      }
    }
  }
  if {![info exists CLIENT_ACCESS_LIST] || $CLIENT_ACCESS_LIST == "" } {
    ErrorMessage "ERROR: No client access lists found in $filename."
  }
  if {![info exists SENSOR_ACCESS_LIST] || $SENSOR_ACCESS_LIST == "" } {
    ErrorMessage "ERROR: No sensor access lists found in $filename."
  }
                                                                                                                                                       
}

proc ValidateSensorAccess { ipaddr } {
  global SENSOR_ACCESS_LIST
  LogMessage "Validating sensor access: $ipaddr : "
  set RFLAG 0
  if { $SENSOR_ACCESS_LIST == "ANY" } {
    set RFLAG 1
  } elseif { [info exists SENSOR_ACCESS_LIST] && [lsearch -exact $SENSOR_ACCESS_LIST $ipaddr] >= 0 } {
    set RFLAG 1
  }
  return $RFLAG
}
proc ValidateClientAccess { ipaddr } {
  global CLIENT_ACCESS_LIST
  LogMessage "Validating client access: $ipaddr"
  set RFLAG 0
  if { $CLIENT_ACCESS_LIST == "ANY" } {
    set RFLAG 1
  } elseif { [info exists CLIENT_ACCESS_LIST] && [lsearch -exact $CLIENT_ACCESS_LIST $ipaddr] >= 0 } {
    set RFLAG 1
  }
  return $RFLAG
}


proc DelUser { userName USERS_FILE } {

  # DEPRECIATED
  puts "DELETE USER DEPRECIATED"
  return

  set fileID [open $USERS_FILE r]
  set USERFOUND 0
  for_file line $USERS_FILE {
    if { ![regexp ^# $line] && ![regexp ^$ $line] } {
      # User file is boobie deliminated
      set tmpLine $line
      if { $userName == [ctoken tmpLine "(.)(.)"] } {
        set USERFOUND 1
      } else {
        lappend tmpData $line
      }
    } else {
      lappend tmpData $line
    }
  }
  close $fileID
  if { !$USERFOUND } {
    puts "ERROR: User \'$userName\' does NOT exist in $USERS_FILE"
  } else {
    if [catch {open $USERS_FILE w} fileID] {
      puts "ERROR: Could not edit $USERS_FILE: $fileID"
    } else {
      foreach line $tmpData {
        puts $fileID $line
      }
      close $fileID
    }
  }
}

proc AddUser { userName } {

    global MAIN_DB_SOCKETID DBHOST DBUSER DBPORT DBPASS DBNAME

    # Usernames must be alpha-numeric
    if { ![string is alnum $userName] } {

        puts "ERROR: Username must be alpha-numeric"
        return

    }

    # Usernames cannot be longer the 16 chars
    if { [string length $userName] > 16 } {

        puts "ERROR: Username cannot be longer than 16 characters."
        return

    }

    # Check and initialize the DB
    if { $DBPASS == "" } {

        set connectCmd "-host $DBHOST -user $DBUSER -port $DBPORT"

    } else {

        set connectCmd "-host $DBHOST -user $DBUSER -port $DBPORT -password $DBPASS"

    }

    if [catch {eval mysqlconnect $connectCmd} MAIN_DB_SOCKETID] {

        puts "ERROR: Unable to connect to $DBHOST on $DBPORT: Make sure mysql is running."
        puts "$MAIN_DB_SOCKETID"
        exit

    }
 
    # See if the DB we want to use exists
    if { [catch {mysqluse $MAIN_DB_SOCKETID $DBNAME} noDBError] } {

        puts "Error: $noDBError"
        exit

    }

    # Make sure we aren't adding a dupe.
    set dupeCheck [FlatDBQuery "SELECT username FROM user_info WHERE username='$userName'"]
    if { $dupeCheck != "" } { 

        puts "ERROR: User \'$userName\' already exists in $USERS_FILE."
        return

    }

    # Get a passwd
    puts -nonewline "Please enter a passwd for $userName: "
    flush stdout
    exec stty -echo
    set passwd1 [gets stdin]
    exec stty echo
    puts -nonewline "\nRetype passwd: "
    flush stdout
    exec stty -echo
    set passwd2 [gets stdin]
    exec stty echo
    puts ""

    if { $passwd1 != $passwd2} {

        puts "ERROR: Passwords didn't match."
        puts "Database NOT updated."
        return

    }

    set salt [format "%c%c" [GetRandAlphaNumInt] [GetRandAlphaNumInt] ]
    # make a hashed passwd
    set hashPasswd [::sha1::sha1 "${passwd1}${salt}"]

    # Add the user to the DB
    set query "INSERT INTO user_info (username, password) VALUES ('$userName', '${salt}${hashPasswd}')"
    if { [catch {SafeMysqlExec $query} tmpError] } {

        puts "ERROR: Failed to add user: $tmpError"

    } else {

        puts "User \'$userName\' added successfully"

   }

}

proc DisableUser { userName } {

    global MAIN_DB_SOCKETID DBHOST DBUSER DBPORT DBPASS DBNAME

    # Check and initialize the DB
    if { $DBPASS == "" } {

        set connectCmd "-host $DBHOST -user $DBUSER -port $DBPORT"

    } else {

        set connectCmd "-host $DBHOST -user $DBUSER -port $DBPORT -password $DBPASS"

    }

    if [catch {eval mysqlconnect $connectCmd} MAIN_DB_SOCKETID] {

        puts "ERROR: Unable to connect to $DBHOST on $DBPORT: Make sure mysql is running."
        puts "$MAIN_DB_SOCKETID"
        exit

    }

    # See if the DB we want to use exists
    if { [catch {mysqluse $MAIN_DB_SOCKETID $DBNAME} noDBError] } {

        puts "Error: $noDBError"
        exit

    }

    # Make sure the user exists
    set validUser [FlatDBQuery "SELECT username FROM user_info WHERE username='$userName'"]
    if { $validUser == "" } {

        puts "ERROR: User \'$userName\' does not exist."
        return

    }

    # Change the user's passwd hash to "LOCKED"
    set query "UPDATE user_info SET password='LOCKED' WHERE username='$userName'"

    if { [catch {SafeMysqlExec $query} tmpError] } {

        puts "ERROR: Failed to disable user's account: $tmpError"

    } else {

        puts "User account \'$userName\' was disabled successfully"

   }


}

proc ChangeUserPW { userName } {

    global MAIN_DB_SOCKETID DBHOST DBUSER DBPORT DBPASS DBNAME

    # Check and initialize the DB
    if { $DBPASS == "" } {

        set connectCmd "-host $DBHOST -user $DBUSER -port $DBPORT"

    } else {

        set connectCmd "-host $DBHOST -user $DBUSER -port $DBPORT -password $DBPASS"

    }

    if [catch {eval mysqlconnect $connectCmd} MAIN_DB_SOCKETID] {

        puts "ERROR: Unable to connect to $DBHOST on $DBPORT: Make sure mysql is running."
        puts "$MAIN_DB_SOCKETID"
        exit

    }

    # See if the DB we want to use exists
    if { [catch {mysqluse $MAIN_DB_SOCKETID $DBNAME} noDBError] } {

        puts "Error: $noDBError"
        exit

    }

    # Make sure the user exists
    set validUser [FlatDBQuery "SELECT username FROM user_info WHERE username='$userName'"]
    if { $validUser == "" } {

        puts "ERROR: User \'$userName\' does not exist."
        return

    }

    # Get a passwd
    puts -nonewline "Please enter a new passwd for $userName: "
    flush stdout
    exec stty -echo
    set passwd1 [gets stdin]
    exec stty echo
    puts -nonewline "\nRetype passwd: "
    flush stdout
    exec stty -echo
    set passwd2 [gets stdin]
    exec stty echo
    puts ""

    if { $passwd1 != $passwd2} {

        puts "ERROR: Passwords didn't match."
        puts "User's passwd was NOT changed."
        return

    }

    set salt [format "%c%c" [GetRandAlphaNumInt] [GetRandAlphaNumInt] ]
    # make a hashed passwd
    set hashPasswd [::sha1::sha1 "${passwd1}${salt}"]

    # Add the user to the DB
    set query "UPDATE user_info SET password='${salt}${hashPasswd}' WHERE username='$userName'"
    if { [catch {SafeMysqlExec $query} tmpError] } {

        puts "ERROR: Failed to change user's password: $tmpError"

    } else {

        puts "User \'$userName\' passwd was changed successfully"

   }


}

proc ValidUserPassword { username password } {

    # Get the users passwd hash from the DB
    set userHash [FlatDBQuery "SELECT password FROM user_info WHERE username='$username'"]

    # If the hash isn't null, then valid user
    if { $userHash != "" } {

        set tmpSalt [string range $userHash 0 1]
        set tmpHash [string range $userHash 2 end]

    } else { 

        # Username did not match
        return 0

    }

    # Hash the user provided password with salt
    set hashPasswd [::sha1::sha1 ${password}${tmpSalt}]
 
    # Compare the two hashes
    if { $hashPasswd != $tmpHash } {

        return 0

    } else {

        return 1

    }

}

proc LogClientAccess { message } {

    global CLIENT_LOG

    if { [catch {open $CLIENT_LOG a} fileID] } {

        puts "ERROR: Unable to log access -> $message"
        puts "ERROR: $fileID"
        return

    }

    puts $fileID $message
    catch {close $fileID}

}

proc ValidateUser { socketID username password } {

    global USERS_FILE validSockets socketInfo userIDArray

    # Configure the socket
    fileevent $socketID readable {}
    fconfigure $socketID -buffering line

    if { [ValidUserPassword $username $password] } {
    
        # Get a the userid from the db and update the userIDArray
        set userIDArray($socketID) [GetUserID $username]

        # Update the last login info in the DB
        DBCommand\
         "UPDATE user_info SET last_login='[GetCurrentTimeStamp]' WHERE uid=$userIDArray($socketID)"

        # Log the access
        LogClientAccess "[GetCurrentTimeStamp]: $socketID - $username logged in from $socketInfo($socketID)"

        # Mark the socket as valid
        lappend validSockets $socketID

        # Send the client socket its user ID
        catch { SendSocket $socketID [list UserID $userIDArray($socketID)] } tmpError

        # Log message
        SendSystemInfoMsg sguild "User $username logged in from [lindex $socketInfo($socketID) 0]"

        # Update the socket information array
        lappend socketInfo($socketID) $username

    } else {

        #Failed
        set validSockets [ldelete $validSockets $socketID]
        catch {SendSocket $socketID [list UserID INVALID]} tmpError
        SendSystemInfoMsg sguild "User $username denied access from [lindex $socketInfo($socketID) 0]"

    }

    fileevent $socketID readable [list ClientCmdRcvd $socketID]

}

proc ChangePass { socketID username oldpass newpass } {

    if { [ValidUserPassword $username $oldpass] } {

        set salt [format "%c%c" [GetRandAlphaNumInt] [GetRandAlphaNumInt] ]
        # make a hashed passwd
        set hashPasswd [::sha1::sha1 "${newpass}${salt}"]

        DBCommand "UPDATE user_info SET password='${salt}${hashPasswd}' WHERE username='$username'"
        SendSocket $socketID [list PassChange 1 $newpass]

    } else {

        SendSocket $socketID [list PassChange 0 failed]

    }

}
