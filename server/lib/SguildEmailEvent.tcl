# $Id: SguildEmailEvent.tcl,v 1.4 2004/11/22 19:01:02 bamm Exp $ #

proc EmailEvent { dataList } {

    global SMTP_SERVER EMAIL_RCPT_TO EMAIL_FROM EMAIL_SUBJECT EMAIL_MSG

    # These will be used for substitutions as configged by the user in
    # the sguild.conf
    set msg [lindex $dataList 7]
    set sn [lindex $dataList 3]
    set t [lindex $dataList 4]
    set sip [lindex $dataList 8]
    set dip [lindex $dataList 9]
    set shost [GetHostbyAddr $sip]
    set dhost [GetHostbyAddr $dip]
    set sp [lindex $dataList 11]
    set dp [lindex $dataList 12]

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
    if { [info exists tmpSubject] } { mime::setheader $token Subject $tmpSubject }
    smtp::sendmessage $token -recipients $EMAIL_RCPT_TO -servers $SMTP_SERVER -originator $EMAIL_FROM
    mime::finalize $token
    InfoMessage "Email sent to: $EMAIL_RCPT_TO"

}
