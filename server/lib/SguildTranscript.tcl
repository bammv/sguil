# $Id: SguildTranscript.tcl,v 1.22 2013/09/05 00:38:45 bamm Exp $ #

proc InitRawFileArchive { date sensor srcIP dstIP srcPort dstPort ipProto } {
  global LOCAL_LOG_DIR
  # Check to make sure our dirs exists. We use <rootdir>/date/sensorName/*.raw
  if { ! [file exists $LOCAL_LOG_DIR] } {
    if { [catch { file mkdir $LOCAL_LOG_DIR } mkdirError] } {
	# Problem creating LOCAL_LOG_DIR
        LogMessage "Error: Unable to create $LOCAL_LOG_DIR for storing pcap data. $mkdirError"
	
	return -code error $mkdirError
    }
  }
  set dateDir "$LOCAL_LOG_DIR/$date"
  if { ! [file exists $dateDir] } {
    if { [catch { file mkdir $dateDir } mkdirError] } {
	# Problem creating dateDir
        LogMessage "Error: Unable to create $dateDir for storing pcap data.  $mkdirError"
	
	return -code error $mkdirError
    }
  }
  set sensorDir "$dateDir/$sensor"
  if { ![file exists $sensorDir] } {
    if { [catch { file mkdir $sensorDir }  mkdirError] } {
	# Problem creating sensorDir
        LogMessage "Error: Unable to create $sensorDir for storing pcap data.  $mkdirError"
	
	return -code error $mkdirError
    }
  }
  # We always make the highest port the apparent source. This way we don't store
  # two copies of the same raw data.
  if { $srcPort > $dstPort } {
    set rawDataFileName "${srcIP}:${srcPort}_${dstIP}:${dstPort}-${ipProto}.raw"
  } else {
    set rawDataFileName "${dstIP}:${dstPort}_${srcIP}:${srcPort}-${ipProto}.raw"
  }
  return [list $sensorDir $rawDataFileName]
}

proc WiresharkRequest { socketID sensor sensorID timestamp srcIP srcPort dstIP dstPort ipProto force } {
  global NEXT_TRANS_ID transInfoArray LOCAL_LOG_DIR
    # Increment the xscript counter. Gives us a unique way to track the xscript
  incr NEXT_TRANS_ID
  set TRANS_ID $NEXT_TRANS_ID
  set date [lindex $timestamp 0]
  if [catch { InitRawFileArchive $date $sensor $srcIP $dstIP $srcPort $dstPort $ipProto }\
      rawDataFileNameInfo] {
    catch {SendSocket $socketID [list ErrorMessage "Error getting pcap: $rawDataFileNameInfo"]}
    return
  }
  set sensorDir [lindex $rawDataFileNameInfo 0]
  set rawDataFileName [lindex $rawDataFileNameInfo 1]
  # A list of info we'll need when we generate the actual xscript after the rawdata is returned.
  set transInfoArray($TRANS_ID) [list $socketID null $sensorDir wireshark $sensor $timestamp ]
  if { ! [file exists $sensorDir/$rawDataFileName] || $force } {
    # No local archive (first request) or the user has requested we force a check for new data.
    if { ![GetRawDataFromSensor $TRANS_ID $sensor $sensorID $timestamp $srcIP $srcPort $dstIP $dstPort $ipProto $rawDataFileName wireshark] } {
      # This means the sensor_agent for this sensor isn't connected.
      catch {SendSocket $socketID [list ErrorMessage "ERROR: Unable to request rawdata at this time.\
       The sensor $sensor is NOT connected."]}
    }
  } else {
    # The data is archived locally.
    PcapAvailable $sensorDir/$rawDataFileName $TRANS_ID
  }
                                                                                                            
}

# When a request pcap becomes available, notify the client
proc PcapAvailable { fileName TRANS_ID } {

    global transInfoArray pcapKeys

    # Create a session key for the download
    set sKey [RandomString 30]
  
    # Send the client a session key and file name to download
    set clientSocketID [lindex $transInfoArray($TRANS_ID) 0]
    catch {SendSocket $clientSocketID [list PcapAvailable $sKey [file tail $fileName]]}

    set pcapKeys(fileName,$sKey) $fileName
    set pcapKeys(socketID,$sKey) $clientSocketID

}

proc SendPcap { socketID sKey } {

    global pcapKeys

    set fileName $pcapKeys(fileName,$sKey)
    if { [catch {open $fileName r} fileID] } {

        # Failed to open file
        catch {SendSocket $pcapKeys(socketID,$sKey) [list ErrorMessage "Failed to open ${fileName}: ${fileID}"]}
        unset pcapKeys(socketID,$sKey)
        unset pcapKeys(fileName,$sKey)
        return

    }

    fconfigure $socketID -translation binary
    fconfigure $fileID -translation binary

    if { [catch {fcopy $fileID $socketID \
      -command [list PcapCopyFinished $fileID $socketID $sKey]} tmpError] } {

        # fcopy failed
        catch {SendSocket $pcapKeys(socketID,$sKey) [list ErrorMessage "Failed to copy ${fileName}: ${tmpError}"]}
        catch {close $socketID}
        unset pcapKeys(socketID,$sKey)
        unset pcapKeys(fileName,$sKey)

    } 

}

proc PcapCopyFinished { fileID socketID sKey bytes {error {}} } {

    global pcapKeys

    # Data copy finished
    catch {close $fileID}
    catch {close $socketID}

    if { [string length $error] != 0 } {

        # Error during copy
        set fileName $pcapKeys(fileName,$sKey)
        catch {SendSocket $pcapKeys(socketID,$sKey) [list ErrorMessage "Failed to copy file ${fileName}: ${error}"]}

    }

    unset pcapKeys(socketID,$sKey)
    unset pcapKeys(fileName,$sKey)

}

proc SendWiresharkData { fileName TRANS_ID } {
  global transInfoArray
                                                                                                            
  set clientSocketID [lindex $transInfoArray($TRANS_ID) 0]
  #puts $clientSocketID "WiresharkDataBase64 [file tail $fileName] [file size $fileName]"
  # Clean up the filename for win32 systems
  regsub -all {:} [file tail $fileName] {_} cleanFileName
  puts $clientSocketID "WiresharkDataPcap $cleanFileName [file size $fileName]"
  set rFileID [open $fileName r]
  fconfigure $rFileID -translation binary
  fconfigure $clientSocketID -translation binary
  fcopy $rFileID $clientSocketID
  fconfigure $clientSocketID -encoding utf-8 -translation {auto crlf}
  if { [catch {close $rFileID} tmpError] } {
    LogMessage "Error closing $fileName: $tmpError"
  }
  # Old stuff if we need to revert back to Base64 file xfers (yuck)
  #sock12 null /snort_data/archive/2004-06-10/gateway wireshark gateway {2004-06-10 17:21:56}
  #SendSocket $clientSocketID [list WiresharkDataBase64 [file tail $fileName] BEGIN]
  #set inFileID [open $fileName r]
  #fconfigure $inFileID -translation binary
  #foreach line [::base64::encode [read -nonewline $inFileID]] {
  #  SendSocket $clientSocketID [list WiresharkDataBase64 [file tail $fileName] $line]
  #}
  #SendSocket $clientSocketID [list WiresharkDataBase64 [file tail $fileName] END]
  #close $inFileID
}

proc AbortXscript { socketID winName } {
  global CANCEL_TRANS_FLAG
  set CANCEL_TRANS_FLAG($winName) 1
  update
}
proc XscriptRequest { socketID sensor sensorID winID timestamp srcIP srcPort dstIP dstPort force } {
  global NEXT_TRANS_ID transInfoArray LOCAL_LOG_DIR TCPFLOW CANCEL_TRANS_FLAG
  # If we don't have TCPFLOW then error to the user and return
  if { ![info exists TCPFLOW] || ![file exists $TCPFLOW] || ![file executable $TCPFLOW] } {
      catch {SendSocket $socketID [list ErrorMessage "ERROR: tcpflow is not installed on the server."]}
      catch {SendSocket $socketID [list XscriptDebugMsg $winID "ERROR: tcpflow is not installed on the server."]}
    return
  }
  # Increment the xscript counter. Gives us a unique way to track the xscript
  incr NEXT_TRANS_ID
  set TRANS_ID $NEXT_TRANS_ID
  set CANCEL_TRANS_FLAG($winID) 0
  set date [lindex $timestamp 0]
  if [catch { InitRawFileArchive $date $sensor $srcIP $dstIP $srcPort $dstPort 6 }\
      rawDataFileNameInfo] {
    catch {SendSocket $socketID\
     [list ErrorMessage "Please pass the following to your sguild administrator:\
      Error from sguild while getting pcap: $rawDataFileNameInfo"]}
    catch {SendSocket $socketID [list XscriptDebugMsg $winID\
     "ErrorMessage Please pass the following to your sguild administrator:\
     Error from sguild while getting pcap: $rawDataFileNameInfo"]}
    catch {SendSocket $socketID [list XscriptMainMsg $winID DONE]}
    return
  }
  set sensorDir [lindex $rawDataFileNameInfo 0]
  set rawDataFileName [lindex $rawDataFileNameInfo 1]
  # A list of info we'll need when we generate the actual xscript after the rawdata is returned.
  set transInfoArray($TRANS_ID) [list $socketID $winID $sensorDir xscript $sensor $timestamp ]
  if { ! [file exists $sensorDir/$rawDataFileName] || $force } {
    # No local archive (first request) or the user has requested we force a check for new data.
    if { ![GetRawDataFromSensor $TRANS_ID $sensor $sensorID $timestamp $srcIP $srcPort $dstIP $dstPort 6 $rawDataFileName xscript] } {
      # This means the sensor_agent for this sensor isn't connected.
      catch {SendSocket $socketID [list ErrorMessage "ERROR: Unable to request xscript at this time.\
       The sensor $sensor is NOT connected."]}
      catch {SendSocket $socketID [list XscriptDebugMsg $winID "ERROR: Unable to request xscript at this time.\
       The sensor $sensor is NOT connected."]}
      catch {SendSocket $socketID [list XscriptMainMsg $winID DONE]}
    }
  } else {
    # The data is archive locally.
    catch {SendSocket $socketID [list XscriptDebugMsg $winID "Using archived data: $sensorDir/$rawDataFileName"]}
    GenerateXscript $sensorDir/$rawDataFileName $socketID $winID $TRANS_ID
  }
}

proc GetRawDataFromSensor { TRANS_ID sensor sensorID timestamp srcIP srcPort dstIP dstPort proto filename type } {
  global agentSocketArray connectedAgents transInfoArray
  global pcapSocket

  set RFLAG 1
  set sensorNetName [MysqlGetNetName $sensorID]
  if { $sensorNetName == "unknown" } { return 0 }

  if { [array exists pcapSocket] && [info exists pcapSocket($sensorNetName)]} {
      set pcapSocketID $pcapSocket($sensorNetName)
      InfoMessage "Sending $sensor: RawDataRequest $TRANS_ID $sensor $timestamp $srcIP $dstIP $dstPort $proto $filename $type"

      if { [catch { puts $pcapSocketID\
	      "[list RawDataRequest $TRANS_ID $sensor $timestamp $srcIP $dstIP $srcPort $dstPort $proto $filename $type]" }\
	      sendError] } {
	  catch { close $pcapSocketID } tmpError
	  CleanUpDisconnectedAgent $pcapSocketID
	  set RFLAG 0
      }
      flush $pcapSocketID
      if { $type == "xscript" } {
	  catch {SendSocket [lindex $transInfoArray($TRANS_ID) 0]\
	      [list XscriptDebugMsg [lindex $transInfoArray($TRANS_ID) 1] "Raw data request sent to $sensor."]}
      }
  } else {
      set RFLAG 0
  }
  return $RFLAG
}

proc RawDataFile { socketID fileName TRANS_ID bytes } {

    global agentSensorName transInfoArray

    # xscript or wireshark request
    set type [lindex $transInfoArray($TRANS_ID) 3]

    InfoMessage "Receiving rawdata file $fileName."
    if { $type == "xscript" } {
        catch {SendSocket [lindex $transInfoArray($TRANS_ID) 0]\
         [list XscriptDebugMsg [lindex $transInfoArray($TRANS_ID) 1] "Receiving raw file from sensor."]}
    }

    set outfile [lindex $transInfoArray($TRANS_ID) 2]/$fileName

    if { $type == "xscript" } {

        set callback [list GenerateXscript $outfile [lindex $transInfoArray($TRANS_ID) 0] [lindex $transInfoArray($TRANS_ID) 1] $TRANS_ID]

    } else { 

        set callback [list PcapAvailable $outfile $TRANS_ID]

    }

    puts "DEBUG #### callback -> $callback"

    RcvBinCopy $socketID $outfile $bytes $callback

}

proc XscriptDebugMsg { TRANS_ID msg } {
    global transInfoArray
  
    if [info exists transInfoArray($TRANS_ID)] {
        catch {SendSocket [lindex $transInfoArray($TRANS_ID) 0]\
           [list XscriptDebugMsg [lindex $transInfoArray($TRANS_ID) 1] $msg]}
    }
}

proc GenerateXscript { fileName clientSocketID winName TRANS_ID } {
  global transInfoArray TCPFLOW LOCAL_LOG_DIR P0F P0F_PATH CANCEL_TRANS_FLAG
  set NODATAFLAG 1
  # We don't have a really good way for make xscripts yet and are unable
  # to figure out the true src. So we assume the low port was the server
  # port. We can get that info from the file name.
  # Filename example: 208.185.243.68:6667_67.11.255.148:3470-6.raw
  regexp {^(.*):(.*)_(.*):(.*)-([0-9]+)\.raw$} [file tail $fileName] allMatch srcIP srcPort dstIP dstPort ipProto
                                                                                                            
  set srcMask [TcpFlowFormat $srcIP $srcPort $dstIP $dstPort]
  set dstMask [TcpFlowFormat $dstIP $dstPort $srcIP $srcPort]
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName HDR]}
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName "Sensor Name:\t[lindex $transInfoArray($TRANS_ID) 4]"]}
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName "Timestamp:\t[lindex $transInfoArray($TRANS_ID) 5]"]}
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName "Connection ID:\t$winName"]}
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName "Src IP:\t\t$srcIP\t([GetHostbyAddr $srcIP])"]}
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName "Dst IP:\t\t$dstIP\t([GetHostbyAddr $dstIP])"]}
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName "Src Port:\t\t$srcPort"]}
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName "Dst Port:\t\t$dstPort"]}
  if {$P0F} {
    if { ![file exists $P0F_PATH] || ![file executable $P0F_PATH] } {
      catch {SendSocket $clientSocketID [list XscriptDebugMsg $winName "Cannot find p0f in: $P0F_PATH"]}
      catch {SendSocket $clientSocketID [list XscriptDebugMsg $winName "OS fingerprint has been disabled"]}
    } else {
      set p0fID [open "| $P0F_PATH -q -s $fileName"]
      while { [gets $p0fID data] >= 0 } {
        catch {SendSocket $clientSocketID [list XscriptMainMsg $winName "OS Fingerprint:\t$data"]}
      }
      catch {close $p0fID} closeError
    }
  }
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName " "]}
  if  [catch {open "| $TCPFLOW -c -r $fileName"} tcpflowID] {
    LogMessage "ERROR: tcpflow: $tcpflowID"
    catch {SendSocket $clientSocketID [list XscriptDebugMsg $winName "ERROR: tcpflow: $tcpflowID"]}
    catch {close $tcpflowID}
    return
  }
  set state SRC
  while { [gets $tcpflowID data] >= 0 } {
    set NODATAFLAG 0
    if { [regsub ^$srcMask:\  $data {} data] > 0 } {
      set state SRC
    } elseif { [regsub ^$dstMask:\  $data {} data] > 0 } {
      set state DST
    }
    catch {SendSocket $clientSocketID [list XscriptMainMsg $winName $state]}
    SendSocket $clientSocketID [list XscriptMainMsg $winName $data]
    update
    if { $CANCEL_TRANS_FLAG($winName) } { break }
  }
  if [catch {close $tcpflowID} closeError] {
    catch {SendSocket $clientSocketID [list XscriptDebugMsg $winName "ERROR: tcpflow: $closeError"]}
  }
  if {$NODATAFLAG} {
    catch {SendSocket $clientSocketID [list XscriptMainMsg $winName "No Data Sent."]}
  }
  catch {SendSocket $clientSocketID [list XscriptMainMsg $winName DONE]}

  unset transInfoArray($TRANS_ID)
  unset CANCEL_TRANS_FLAG($winName)

}

proc TcpFlowFormat { srcIP srcPort dstIP dstPort } {
  set tmpSrcIP [split $srcIP .]
  set tmpDstIP [split $dstIP .]
  set tmpData [eval format "%03i.%03i.%03i.%03i.%05i-%03i.%03i.%03i.%03i.%05i" $tmpSrcIP $srcPort $tmpDstIP $dstPort]
  return $tmpData
}

proc QuickScript { clientSocketID alertID } {

    global eventIDArray

    # Need to get right info.
    if { [info exists eventIDArray($alertID)] } {

        set sensor [lindex $eventIDArray($alertID) 3]
        set timestamp [lindex $eventIDArray($alertID) 4]
        set sensorID [lindex $eventIDArray($alertID) 5]
        set message [lindex $eventIDArray($alertID) 7]
        set srcIP [lindex $eventIDArray($alertID) 8]
        set dstIP [lindex $eventIDArray($alertID) 9]
        set srcPort [lindex $eventIDArray($alertID) 11]
        set dstPort [lindex $eventIDArray($alertID) 12]
        XscriptRequest $clientSocketID $sensor $sensorID foo $timestamp $srcIP $srcPort $dstIP $dstPort 0

    } else {
    
        catch {SendSocket $clientSocketID [list XscriptMainMsg foo "Unable to find alert $alertID in RealTime array"]}
        catch {SendSocket $clientSocketID [list XscriptMainMsg foo DONE]}

    }

}
