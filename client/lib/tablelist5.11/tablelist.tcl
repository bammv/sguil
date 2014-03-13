#==============================================================================
# Main Tablelist package module.
#
# Copyright (c) 2000-2014  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

package require Tcl 8
package require Tk  8
package require -exact tablelist::common 5.11

package provide tablelist $::tablelist::version
package provide Tablelist $::tablelist::version

::tablelist::useTile 0
::tablelist::createBindings
