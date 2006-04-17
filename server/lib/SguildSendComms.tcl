# $Id: SguildSendComms.tcl,v 1.4 2006/04/17 18:52:36 bamm Exp $ #

#
# SendSocket: Send command to client
#
proc SendSocket { socketID command } {
  global clientList
  InfoMessage "Sending $socketID: $command"
  if { [catch {puts $socketID $command} sendError] } {
    LogMessage "Error sending \"$command\" to $socketID"
    catch { close $socketID } closeError
    # Remove socket from the client list
    ClientExitClose $socketID
    return -code error -errorinfo $sendError
  }
  catch {flush $socketID} flushError
}
                                                                                                     
#
# SendEvent: Send events to connected clients
#
proc SendEvent { eventDataList } {
  global clientMonitorSockets
  set sensorName [lindex $eventDataList 3]
  if { [info exists clientMonitorSockets($sensorName)] } {
    foreach clientSocket $clientMonitorSockets($sensorName) {
      catch {SendSocket $clientSocket "InsertEvent $eventDataList"} tmpError
    }
  } else {
    InfoMessage "No clients to send alert to."
  }
}

proc SendIncrEvent { eid sensorName count priority} {
  global clientMonitorSockets
  if { [info exists clientMonitorSockets($sensorName)] } {
    foreach clientSocket $clientMonitorSockets($sensorName) {
      catch {SendSocket $clientSocket "IncrEvent $eid $count $priority"} tmpError
    }
  } else {
    InfoMessage "No clients to send msg to."
  }
}
proc SendSystemInfoMsg { sensor msg } {
  global clientList
  if { [info exists clientList] && [llength $clientList] > 0 } {
    foreach clientSocket $clientList {
      catch {SendSocket $clientSocket "InsertSystemInfoMsg $sensor $msg"} tmpError
    }
  } else {
    InfoMessage "No clients to send info msg to."
  }
}

#
# SendSensorList: Sends a list of sensors for the end user to select from.
#
proc SendSensorList { socketID } {
  global sensorList clientMonitorSockets socketInfo sensorUsers
  set query "SELECT DISTINCT(hostname) FROM sensor WHERE active='Y' ORDER BY hostname ASC"
  set sensorList [FlatDBQuery $query]
  if { $sensorList == "" } {
    # No sensors in the DB yet
    set fullSensorList "0none0"
  } else {
    # create a list of sensors and a list of the sensors users
    foreach sensor $sensorList {
      if { ![info exists sensorUsers($sensor)] || $sensorUsers($sensor) == "" } {
        lappend fullSensorList "$sensor unmonitored"
      } else {
        lappend fullSensorList [list $sensor $sensorUsers($sensor)]
      }
    }
  }
  puts $socketID "SensorList $fullSensorList"
}

