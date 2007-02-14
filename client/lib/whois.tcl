# $Id: whois.tcl,v 1.8 2007/02/14 17:25:41 bamm Exp $ #

proc ClientSocketTimeOut { host port timeout } {
  global WHOIS_CONNECTED
  after $timeout {set WHOIS_CONNECTED timeout}
  if [ catch {socket -async $host $port} socketID ] {
    return -code error "Could not connect to $host"
  }
  fileevent $socketID w {set WHOIS_CONNECTED "connected"}
  tkwait variable WHOIS_CONNECTED
  if {$WHOIS_CONNECTED == "connected"} {
    return $socketID
  } else {
    catch {close $socketID} tmpError
    return -code error "Connection to $host timed out"
  }
}

proc GetServerFromRef { line } {

    
    # Defaults
    set refPort 43
    set refName "arin.whos.net" 

    # Referer should be a whois URL.
    regexp {whois://(.*)} $line match tmpRef

    # Parse hostname:port
    set tmpSplit [split $tmpRef :]
    set refName [lindex $tmpSplit 0]

    # Grab the port if we had one
    if { [llength $tmpSplit] > 1 } { regexp {([0-9]+)} [lindex $tmpSplit 1] match refPort }

    return [list $refName $refPort]
    
}

proc SimpleWhois { ipAddr } {
  # Here is an attempt to do away with third party whois tools.
  # We only lookup by IP addr right now so it shouldn't be a big
  # deal. That's the theory anyway.

  global DEBUG

  set nicSrvr "whois.arin.net"
  set rPort 43
  if {$DEBUG} {puts "Whois request: $ipAddr"}
  
  # Connect to arin first.
  if [catch {ClientSocketTimeOut $nicSrvr $rPort 10000} socketID] {
    return "{ERROR: $socketID}"
  } 
  fconfigure $socketID -buffering line
  if [catch {puts $socketID $ipAddr} tmpPutsError] {
    catch {close $socketID} tmpError
    return "{ERROR: $tmpPutsError}"
  }

  while { ![eof $socketID] && ![catch {gets $socketID data}] } {
    lappend results $data
  }
  catch {close $socketID} tmpError

  set newNicSrvr $nicSrvr

  # Loop thru and see if we see something that looks like a referer
  # Thanks to all the different proxy tools that already did the 
  # work for these regexps :)
  foreach line $results {
    switch -regexp -- $line {
        {ReferralServer}                {set refServer [GetServerFromRef $line]; break }
    	{.*LACNIC.*}			{set newNicSrvr "whois.lacnic.net"}
    	{.*APNIC.*}			{set newNicSrvr "whois.apnic.net"}
    	{.*APNIC-.*}			{set newNicSrvr "whois.apnic.net"}
    	{.*AUNIC-AU.*}			{set newNicSrvr "whois.aunic.net"}
    	{.*NETBLK-RIPE.*}		{set newNicSrvr "whois.ripe.net"}
    	{.*NETBLK-.*-RIPE.*}		{set newNicSrvr "whois.ripe.net"}
    	{.*NET-RIPE.*}			{set newNicSrvr "whois.ripe.net"}
    	{.*-RIPE.*}			{set newNicSrvr "whois.ripe.net"}
    	{.*RIPE-.*}			{set newNicSrvr "whois.ripe.net"}
    	{.*NETBLK-BRAZIL.*}		{set newNicSrvr "whois.nic.br"}
    	{.*whois\.nic\.ad\.jp.*}	{set newNicSrvr "whois.nic.ad.jp"}
    	{.*whois\.telstra.*}		{set newNicSrvr "whois.telstra.net"}
    	{.*rwhois\.exodus.*}		{set newNicSrvr "rwhois.exodus.net"; set rPort 4321}
    	{.*rwhois\.verio.*}		{set newNicSrvr "rwhois.verio.net"}
    	{.*rwhois\.dnai.*}		{set newNicSrvr "rwhois.dnai.com"}
    	{.*rwhois\.digex.*}		{set newNicSrvr "rwhois.digex.net"}
    	{.*rwhois\.internex.*}		{set newNicSrvr "rwhois.internex.net"}
    	{.*rwhois\.concentric.*}	{set newNicSrvr "rwhois.concentric.net"}
    	{.*rwhois\.oar.*}		{set newNicSrvr "rwhois.oar.net"}
    	{.*rwhois\.elan.*}		{set newNicSrvr "rwhois.elan.net"}
    	{.*rwhois\.cais.*}		{set newNicSrvr "rwhois.cais.net"}
    	{.*rwhois\.cogentco.*}		{set newNicSrvr "rwhois.cogentco.com"}
    	{.*rwhois\.beanfield.*}		{set newNicSrvr "rwhois.beanfield.net"}
    	{.*JPNIC*.*}			{set newNicSrvr "whois.nic.ad.jp"}
    	{.*JNIC*.*}			{set newNicSrvr "whois.nic.ad.jp"}
    	{.*whois.nic.or.kr.*}		{set newNicSrvr "whois.nic.or.kr"}
    	default				{ set foo bar }
    }
  }

  if { [info exists refServer] } {
      set newNicSrvr [lindex $refServer 0]
      set rPort [lindex $refServer 1]
  }
  if { $nicSrvr != $newNicSrvr } {
    if [catch {ClientSocketTimeOut $newNicSrvr $rPort 10000} socketID] {
      return "{ERROR: $socketID}"
    } 
    fconfigure $socketID -buffering line
    if [ catch { puts $socketID $ipAddr } sError] {
      close $socketID
      return [list $sError]
    }

    set results ""
    while { ![eof $socketID] && ![catch {gets $socketID data}] } {
      lappend results $data
    }
    catch {close $socketID} tmpError
  } else { 
    # Check to see if we can drill down further from query results like:
    #SBC Internet Services - Southwest SBIS-SBIS-5BLK (NET-66-136-0-0-1) 
    #                              66.136.0.0 - 66.143.255.255
    #ROBERT LEVIN SBC-06614002515229 (NET-66-140-25-152-1) 
    #                              66.140.25.152 - 66.140.25.159
    # ARIN WHOIS database, last updated 2003-06-01 21:05
    # Enter ? for additional hints on searching ARIN's WHOIS database.
    if { [regexp {.*\(.*\) $} [lindex $results 0] ] &&\
         [regexp {(.*)\((.*)\) $} [lindex $results 2] match blkName netBlk] } {
      # Looks like we got one
      lappend results "\n----- Querying Reassigned Block: $blkName ----\n"
      if [catch {ClientSocketTimeOut $nicSrvr $rPort 10000} socketID] {
        return "{ERROR: $socketID}"
      }
      fconfigure $socketID -buffering line
      puts $socketID $netBlk

      while { ![eof $socketID] && ![catch {gets $socketID data}] } {
        lappend results $data
      }
      catch {close $socketID} tmpError
    }
  }
  return $results
}
