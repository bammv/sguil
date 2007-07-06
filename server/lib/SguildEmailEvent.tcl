# $Id: SguildEmailEvent.tcl,v 1.8 2007/07/06 15:19:12 bamm Exp $ #

proc EmailEvent { dataList } {

    global SMTP_SERVER EMAIL_RCPT_TO EMAIL_FROM EMAIL_SUBJECT EMAIL_MSG

    # dataList
    # 0 1 trojan-activity sensorname {2007-07-05 15:06:30} 1 1710072 
    # {BLEEDING-EDGE Malware MyWebSearch Toolbar Posting Activity Report} 
    # 192.168.1.1 10.1.1.1 6 2665 80 1 2003617 1 629 629 1

    # These will be used for substitutions as configged by the user in
    # the sguild.conf
    set msg [lindex $dataList 7]
    set sn [lindex $dataList 3]
    set eid "[lindex $dataList 5].[lindex $dataList 6]"
    set t [lindex $dataList 4]
    set sip [lindex $dataList 8]
    set dip [lindex $dataList 9]
    set shost [GetHostbyAddr $sip]
    set dhost [GetHostbyAddr $dip]
    set sp [lindex $dataList 11]
    set dp [lindex $dataList 12]
    set sig_id [lindex $dataList 14]
    set class [lindex $dataList 2]

    # Do the subs
    regsub -all {%} $EMAIL_MSG {$} tmpMsg
    if { [info exists EMAIL_SUBJECT] } {
      regsub -all {%} $EMAIL_SUBJECT {$} tmpSubject
    }
    set tmpMsg [subst -nobackslashes -nocommands $tmpMsg]
    set tmpSubject [subst -nobackslashes -nocommands $tmpSubject]

    # Build and send the email
    InfoMessage "Sending Email: $tmpMsg"
    set token [mime::initialize -canonical text/plain -string $tmpMsg]
    if { [info exists tmpSubject] } { mime::setheader $token Subject $tmpSubject } else { mime::setheader $token Subject "Sguil Event" }
    smtp::sendmessage $token -recipients $EMAIL_RCPT_TO -servers $SMTP_SERVER -originator $EMAIL_FROM
    mime::finalize $token
    InfoMessage "Email sent to: $EMAIL_RCPT_TO"

}
