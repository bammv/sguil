# email.tcl
# EMail 1.7 package       Evan Rempel  erempel@uvic.ca

package provide EMail 1.7

namespace eval ::EMail:: {

  variable Version 1.7

  # --- if this is 1, trace messages will be displayed to the std out.
  variable debug 1

  namespace export Init Send Wait Query GetError Addresses InvalidAddresses Discard

  # --- status of each e-mail connection
  variable EMailTokenState
  array set EMailTokenState {}

  # --- Wait flags.
  variable EMailWaitFlags
  array set EMailWaitFlags {Any 0}
  variable EMailCompleteList {}

  # --- sequential counter to create unique tokens
  variable EMailID 0

  # --- e-mail address to use in the from field of outgoing e-mail
  variable EMailFromAddress ""
  variable EMailHost ""
  variable EMailGateWay ""

}

# set this to 1 if the Trf package is available.
# If set to 0, attachments can not be sent
set ::EMail::enableAttachments 0

if {$::EMail::enableAttachments} then {
 package require Trf 2.0
}

# ------------------------------------------------- EMail::Init ----
# Setup the from address and the host computer name that the
# e-mail is being sent from. The host computer is used in the
# HELO command.
proc ::EMail::Init { address host gateway } {
  variable EMailFromAddress
  variable EMailHost
  variable EMailGateWay

  set EMailFromAddress $address
  set EMailHost $host
  set EMailGateWay $gateway
}

# --------------------------------------------------- EMail::Token ----
# internal routine
# Return the next unique TimeToken
proc ::EMail::Token {} {
  variable EMailID

  return "[namespace current]::[incr EMailID]"
}


# ------------------------------------------------- EMail::Finish ----
proc ::EMail::Finish { token {errormsg ""} } {
  variable debug
  variable $token
  upvar 0 $token state
  variable EMailWaitFlags
  variable EMailCompleteList

  global errorInfo errorCode

  if {$debug} then {
    puts "Finish: $token"
  }
  if {[string length $errormsg] != 0} {
    set state(error) [list $errormsg]
    set state(Status) error
  }
  catch {close $state(sock)}
  catch {after cancel $state(after)}
  catch {after cancel $state(afteropen)}
  if {[info exist state(-command)] && ($state(-command) != "")} {
    if {[catch {eval $state(-command) {$token}} err]} {
      if {[string length $errormsg] == 0} {
        set state(error) [list $err $errorInfo $errorCode]
        set state(Status) error
      }
    }
    unset state(-command)
  }
  set EMailWaitFlags($token) 1
  set EMailWaitFlags(Any) 1
  lappend EMailCompleteList $token
}

# ------------------------------------------------- EMail::Reset ----
proc ::EMail::Reset { token {why Reset} } {
  variable debug
  variable $token
  upvar 0 $token state

  set state(Status) error
  catch {fileevent $state(sock) readable {}}
  catch {fileevent $state(sock) writable {}}
  Finish $token $why
}

# ----------------------------------------- EMail::Continue ----
proc ::EMail::Continue { token index args } {
  variable $token
  upvar 0 $token state

  if {[llength $args] > 0} then {
    foreach handle $args {
      catch {fileevent $state(sock) $handle {}}
    }
  }
  switch $index {
    "afteropen" {
      set state(Status) open
      catch {after cancel $state(afteropen)}
    }
  }
}

# ------------------------------------------------- EMail::Event ----
 proc ::EMail::Event {token} {
  variable debug
  variable $token
  upvar 0 $token state
  global tcl_patchLevel

  if [::eof $state(sock)] then {
    Reset $token terminated
    return
  }
  set n [gets $state(sock) line]
  if {$debug} then {
    puts "Event: $line"
  }
  # --- if a line was read
  if {$n >= 0} then {
    set ReceiveCode "[string range $line 0 [expr [string length $state(GoodCode)] - 1]]"
    if {$ReceiveCode == "$state(GoodCode)"} then {
      set Process Good
    } else {
      if {$debug} then {
        puts "Event: Expected $state(GoodCode) but got $ReceiveCode"
      }
      set Process Bad
    }
    switch $state(Status) {
      "opening" -
      "open" {
        if {"$Process" == "Bad"} then {
          Reset $token "Opening: $line"
        } else {
          puts $state(sock) "HELO $state(EMailHost)"
          set state(Status) helo
          if {$debug} then {
            puts "Event: Status now $state(Status)"
          }
          set state(GoodCode) "250"
          flush $state(sock)
        }
      }
      "helo" {
        if {"$Process" == "Bad"} then {
          Reset $token "HELO: $line"
        } else {
          puts $state(sock) "MAIL FROM: <$state(EMailFrom)>"
          set state(Status) from
          if {$debug} then {
            puts "Event: Status now $state(Status)"
          }
          set state(GoodCode) "250"
          flush $state(sock)
        }
      }
      "from" {
        if {"$Process" == "Bad"} then {
          Reset $token "MAIL FROM: $line"
        } else {
          puts $state(sock) "RCPT TO: <[lindex $state(RCPT) 0]>"
          flush stdout
          set state(Status) rcpt
          if {$debug} then {
            puts "Event: Status now $state(Status)"
            puts "Event: RCPT <[lindex $state(RCPT) 0]>"
          }
          set state(GoodCode) "250"
          set state(rcptIndex) 0
          set state(RCPTCount) 0
          flush $state(sock)
        }
      }
      "rcpt" {
        if {"$Process" == "Bad"} then {
          lappend state(BadList) [lindex $state(RCPT) $state(rcptIndex)]
        } else {
          incr state(RCPTCount)
        }
        # --- are there more recipients
        if {[incr state(rcptIndex)] < [llength $state(RCPT)]} then {
          puts $state(sock) "RCPT TO: <[lindex $state(RCPT) $state(rcptIndex)]>"
          if {$debug} then {
            puts "Event: RCPT <[lindex $state(RCPT) 0]>"
          }
          set state(Status) rcpt
          set state(GoodCode) "250"
          flush $state(sock)
        } else {
          # --- check for at least one valid recipient
          if {$state(RCPTCount) == 0} then {
            puts $state(sock) "QUIT"
            set state(Status) complete
            if {$debug} then {
              puts "Event: Status now $state(Status)"
            }
            set state(GoodCode) "221"
            flush $state(sock)
          } else {
            puts $state(sock) "DATA"
            set state(Status) data
            if {$debug} then {
              puts "Event: Status now $state(Status)"
            }
            set state(GoodCode) "354"
            flush $state(sock)
          }
        }
      }
      "data" {
        if {"$Process" == "Bad"} then {
          Reset $token "DATA: $line"
        } else {
          puts -nonewline $state(sock) "$state(Headers)"
          if {[llength $state(-files)] > 0} then {
            set state(Boundry) "[clock seconds]-[clock clicks]-$tcl_patchLevel-[expr rand()]"
            puts $state(sock) "MIME-Version: 1.0"
            puts $state(sock) "Content-Type: MULTIPART/MIXED; BOUNDARY=\"$state(Boundry)\"\n"
            puts $state(sock) "--$state(Boundry)"
            puts $state(sock) "Content-Type: TEXT/PLAIN; charset=US-ASCII\n"
            puts $state(sock) "$state(Message)\n"
            foreach file $state(-files) {
              if {! [catch {set fHandle [open "$file" "r"]} msg]} then {
                fconfigure $fHandle -encoding binary -translation binary
                puts $state(sock) "--$state(Boundry)"
                puts $state(sock) "Content-Type: application/octet-stream; name=\"[file tail $file]\""
                puts $state(sock) "Content-Transfer-Encoding: BASE64\n\n"
                if {$debug} then {
                  puts "Attachment: $file ([file size "$file"])"
                }
                base64 -mode encode -in $fHandle -out $state(sock)
                close $fHandle
              } else {
                if {$debug} then {
                  puts "** Attachment fail: $file"
                }
              }
            }      
            puts $state(sock) "--$state(Boundry)--\n"
          } else {
            puts $state(sock) "\n$state(Message)\n"
          }
          set state(Status) quiting
          if {$debug} then {
            puts "Event: Status now $state(Status)"
          }
          set state(GoodCode) "250"
          puts $state(sock) "."
          flush $state(sock)
        }
      }
      "quiting" {
        if {"$Process" == "Bad"} then {
          Reset $token ".: $line"
        } else {
          puts $state(sock) "QUIT"
          set state(Status) complete
          if {$debug} then {
            puts "Event: Status now $state(Status)"
          }
          set state(GoodCode) "221"
          flush $state(sock)
          # if do not want to wait for the SMTP server to acknowlege
          # the quit command, finish the connection.
          # NOTE: this does not comply with RFC 821
          if {$state(-waitquit) == 0} then {
            Finish $token
          }
        }
      }
      "complete" {
        if {"$Process" == "Bad"} then {
          Reset $token "QUIT: $line"
        } else {
          Finish $token
        }
      }
    }
  }
}

# ------------------------------------------------- EMail::Send ----
# EMail::Send ToList CCList BCCList Subject Message options
#   Send the 
proc ::EMail::Send { ToList CCList BCCList Subject Message args } {
  variable Version
  variable debug
  variable enableAttachments
  variable EMailFromAddress
  variable EMailHost
  variable EMailGateWay

  set token [EMail::Token]
  variable $token
  upvar 0 $token state

  array set state {
    -connectwait     0
    -timeout         0
    -blocksize       1024
    -files           ""
    -waitquit        1
    error            ""
    RCPT             ""
    Message          ""
    GoodCode         "220"
    Status           "new"
    BadList          ""
    Boundry          ""
  }
  set state(EMailHost)     $EMailHost
  set state(EMailFrom)     $EMailFromAddress


  set options {-command -connectwait -timeout -waitquit}
  if {$enableAttachments} then {
    lappend options -files
  }
  set usage [join $options ", "]
  regsub -all -- - $options {} options
  set pat ^-([join $options |])$
  foreach {flag value} $args {
    if [regexp $pat $flag] {
      # Validate numbers
      if {[info exists state($flag)] && \
          [regexp {^[0-9]+$} $state($flag)] && \
          ![regexp {^[0-9]+$} $value]} {
        return -code error "Bad value for $flag ($value), must be integer"
      }
      set state($flag) $value
    } else {
      return -code error "Unknown option $flag, can be: $usage"
    }
  }

  # --- create the entire recipient list
  set state(RCPT) ""
  if {[llength $ToList] > 0} then {
    set state(RCPT) [concat $state(RCPT) $ToList]
  }
  if {[llength $CCList] > 0} then {
    set state(RCPT) [concat $state(RCPT) $CCList]
  }
  if {[llength $BCCList] > 0} then {
    set state(RCPT) [concat $state(RCPT) $BCCList]
  }

  # --- assemble the visible destination headers
  set To ""
  set count 0
  foreach rcpt $ToList {
    incr count
    if {$count <= 1} then {
      append To "To: $rcpt"
    } else {
      append To ",\n    $rcpt"
    }
  }
  set CCTo ""
  set count 0
  foreach rcpt $CCList {
    incr count
    if {$count <= 1} then {
      append CCTo "CC: $rcpt"
    } else {
      append CCTo ",\n    $rcpt"
    }
  }

  # --- assemble the visible headers
  set Headers ""
  append Headers "X-Mailer: TCL EMail Library $Version\n"
  if {[string length $To] > 0} then {
    append Headers "$To\n"
  }
  if {[string length $CCTo] > 0} then {
   append Headers "$CCTo\n"
  }
  append Headers "From: $EMailFromAddress\n"
  append Headers "Subject: $Subject\n"
  set timestamp [clock format [clock seconds] -format "%c" -gmt true]
  append Headers "Date: $timestamp -0000\n"
  set state(Headers) "$Headers"

  # --- place the message into the token state variable
  set state(Message) "$Message"

  # --- open up the connection
  if {[catch {set state(sock) [socket -async $EMailGateWay 25]} msg]} then {
    EMail::Reset $token connectwait
  } else {

    # --- start the connection timer
    if {$state(-connectwait) > 0} {
      set state(afteropen) [after $state(-connectwait) [list EMail::Reset $token connectwait]]
      fileevent $state(sock) writable [list EMail::Continue $token afteropen writable]
    }

    # start the processing timer
    if {$state(-timeout) > 0} {
      set state(after) [after $state(-timeout) [list EMail::Reset $token timeout]]
    }
  
    # Send data in cr-lf format, but accept any line terminators
  
    fconfigure $state(sock) -translation {auto crlf} -buffersize $state(-blocksize)
  
    # The following is disallowed in safe interpreters, but the socket
    # is already in non-blocking mode in that case.
  
    catch {fconfigure $state(sock) -blocking off}
    set state(Status)      "opening"
    set state(GoodCode)   "220"
    fileevent $state(sock) readable [list EMail::Event $token]
  
    if {! [info exists state(-command)]} {
      Wait $token
    }
  }
  return $token
}


# ----------------------------------------------------- EMail::Wait ---
# EMail::Wait  (EMailToken | Any)
#   Wait for the specified email interaction to complete.
#   If argument is Any, return as soon as any single one completes
#   If the specified e-mail transaction has already completed, this
#   routine returns immediately
#   Returns the EMailToken of the completed transaction
#
# WARNING: It is possible to use a -command callback to process e
#   completed mail token. Then use the "Wait Any" command to retieve the
#   same mail token and attempt to process it again. When using a call
#   back to process completed mail tokens, you should call the Discard routine
#   prior to attempting to use the Wait Any routine.

proc ::EMail::Wait { EMailToken } {
  variable debug
  variable EMailWaitFlags
  variable EMailCompleteList

  if {("$EMailToken" == "Any")} {
    if {[llength $EMailCompleteList] == 0} {
      if {$debug} then {
        puts "Wait: Waiting for Any"
      }
      vwait EMail::EMailWaitFlags(Any)
    }
    set EMailTemp [lindex $EMailCompleteList 0]
    set EMailCompleteList [lrange $EMailCompleteList 1 end]
    return $EMailTemp      
  } else {
    if {(![info exist EMailWaitFlags($EMailToken)]) || ($EMailWaitFlags($EMailToken) != 1)} {
      if {$debug} then {
        puts "Wait: Waiting for $EMailToken"
      }
      vwait EMail::EMailWaitFlags($EMailToken)
    }
    set EMailTemp [lsearch -exact $EMailCompleteList $EMailToken]
    if {$EMailTemp != -1} then {
      set EMailCompleteList [lreplace $EMailCompleteList $EMailTemp $EMailTemp]
    }
    return $EMailToken
  }
}

# ---------------------------------------------------- EMail::Query ---
#  EMail::Query     Token 
#
proc ::EMail::Query { token } {
  variable $token
  upvar 0 $token state

  if {[info exist state]} then {
    return $state(Status)
  } else {
    return unknown
  }
}

# ---------------------------------------------------- EMail::Addresses ---
#  EMail::Addresses     Token 
#
proc ::EMail::Addresses { token } {
  variable $token
  upvar 0 $token state

  if {[info exist state] && [info exist state(RCPT)]} then {
    return $state(RCPT)
  } else {
    return ""
  }
}

# ---------------------------------------------------- EMail::InvalidAddresses ---
#  EMail::InvalidAddresses     Token 
#
proc ::EMail::InvalidAddresses { token } {
  variable $token
  upvar 0 $token state

  if {[info exist state] && [info exist state(BadList)]} then {
    return $state(BadList)
  } else {
    return ""
  }
}

# ---------------------------------------------------- EMail::GetError ---
#  EMail::GetError     Token 
#
proc ::EMail::GetError { token } {
  variable $token
  upvar 0 $token state

  if {[info exist state]} then {
    return $state(error)
  } else {
    return unknown
  }
}

# ---------------------------------------------------- EMail::Discard ---
#  EMail::Discard     Token 
#
proc ::EMail::Discard { token } {
  variable EMailWaitFlags
  variable EMailCompleteList
  variable $token
  upvar 0 $token state

  if {[info exist state]} then {
    catch {close $state(sock)}
    catch {after cancel $state(after)}
    catch {after cancel $state(afteropen)}
    if {[info exist EMailWaitFlags($token)] && ($EMailWaitFlags($token) > 0)} then {
      incr EMailWaitFlags(Any) -1
    }
    catch {unset state}
    set EMailTemp [lsearch -exact $EMailCompleteList $token]
    if {$EMailTemp != -1} then {
      set EMailCompleteList [lreplace $EMailCompleteList $EMailTemp $EMailTemp]
    }
    return 0
  } else {
    return unknown
  }
}
