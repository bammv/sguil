# $Id: SguildEmailEvent.tcl,v 1.2 2004/10/18 15:28:20 shalligan Exp $ #

proc EmailEvent { dataList } {
  global SMTP_SERVER EMAIL_RCPT_TO EMAIL_FROM EMAIL_SUBJECT EMAIL_MSG
  set msg [lindex $dataList 7]
  set sn [lindex $dataList 3]
  set t [lindex $dataList 4]
  set sip [lindex $dataList 8]
  set dip [lindex $dataList 9]
  set sp [lindex $dataList 11]
  set dp [lindex $dataList 12]
  regsub -all {%} $EMAIL_MSG {$} tmpMsg
  set tmpMsg [subst -nobackslashes -nocommands $tmpMsg]
  InfoMessage "Sending Email: $tmpMsg"
  set token [mime::initialize -canonical text/plain -string $tmpMsg]
  if { [info exists EMAIL_SUBJECT] } { mime::setheader $token Subject $EMAIL_SUBJECT }
  smtp::sendmessage $token -recipients $EMAIL_RCPT_TO -servers $SMTP_SERVER -originator $EMAIL_FROM
  mime::finalize $token
  InfoMessage "Email sent to: $EMAIL_RCPT_TO"
}
