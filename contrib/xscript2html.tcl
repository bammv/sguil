#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: xscript2html.tcl,v 1.1 2008/02/21 18:15:04 bamm Exp $ #

# Copyright (C) 2002-2008 Robert (Bamm) Visscher <bamm@sguil.net>
#
# This program is distributed under the terms of version 1.0 of the
# Q Public License.  See LICENSE.QPL for further details.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.


proc DisplayUsage { cmd } {

        puts "Usage: $cmd -i <infile> \[-o <outfile>\]"
        puts "If -o is not specified then .html will appened to the rootname of infile for output."
        exit

}

proc PrintHdrLine { line } {

    global HTML_STATE outFileID

    regsub -all {\<} $line {\&lt;} line
    regsub -all {\>} $line {\&gt;} line

    set i 0
    set lline [split $line \t]
    if { [llength $lline] == 4 } { 
        set ipinfo [lrange $lline 2 end]
        set lline [lreplace $lline 2 end $ipinfo]
    }
    foreach cell $lline {

        if { $cell != "" } {

            if { $i == 0 } { 

                puts $outFileID "<td class=\"hdr\">$cell</td>"

            } else {
    
                if { $cell != "" } {

                    puts $outFileID "<td>$cell</td>"

                }

            }

            incr i

        }

    }
    puts $outFileID "</tr>"
    
}
proc PrintLine { state line } {

    global HTML_STATE outFileID

    if { $HTML_STATE != $state } {

        if { $HTML_STATE == "hdr" } {
            puts $outFileID "</table>"
        } else {
            puts $outFileID "</p>"
        }
        puts $outFileID "<p class=\"$state\">"
        regsub -all {\<} $line {\&lt;} line
        regsub -all {\>} $line {\&gt;} line
        puts $outFileID "${line}<br>"
        
        set HTML_STATE $state

    } else {

        regsub -all {\<} $line {\&lt;} line
        regsub -all {\>} $line {\&gt;} line
        regsub -all {\t} $line {TAB} line
        puts $outFileID "$line<br>"

    }

}

# Load extended tcl
if [catch {package require Tclx} tclxVersion] {
  puts "ERROR: The tclx extension does NOT appear to be installed on this sysem."
  puts "Extended tcl (tclx) is available as a port/package for most linux and BSD systems."
  exit 1
}

set STATE flag
foreach arg $argv {

    switch -- $STATE {
        flag {
            switch -glob -- $arg {
                -i         { set STATE infile }
                -o         { set STATE outfile }
                default          { DisplayUsage $argv0 }
            }
        }
        infile          { set INFILE $arg; set STATE flag }
        outfile         { set OUTFILE $arg; set STATE flag }
        default         { DisplayUsage $argv0 }
    }

}

if { ![info exists INFILE] } { puts "Error: Must specify input file"; DisplayUsage $argv0 }

if { ![info exists OUTFILE] } { set OUTFILE "[file rootname $INFILE].html" }

if { ![file exists $INFILE] || ![file readable $INFILE] } { puts "Error: Unable to open $INFILE or file does not exist."; DisplayUsage $argv0 } 

if [ catch {open $OUTFILE w} outFileID ] { puts "ERROR: $outFileID"; DisplayUsage $argv0  }

puts $outFileID "<html>"

puts $outFileID "<head>"

puts $outFileID "<style type=\"text/css\">"

puts $outFileID "    .hdr"
puts $outFileID "    \{"
puts $outFileID "    background-color:lightgrey;"
puts $outFileID "    padding10px;"
puts $outFileID "    \}"

puts $outFileID "    td.hdr"
puts $outFileID "    \{"
puts $outFileID "    background-color:lightgrey;"
puts $outFileID "    font-weight:bold;"
puts $outFileID "    \}"

puts $outFileID "    .src"
puts $outFileID "    \{"
puts $outFileID "    background-color:lightblue;"
puts $outFileID "    padding10px;"
puts $outFileID "    \}"

puts $outFileID "    .dst"
puts $outFileID "    \{"
puts $outFileID "    background-color:#00BFFF;"
puts $outFileID "    padding10px;"
puts $outFileID "    \}"
puts $outFileID "</style>"

puts $outFileID "</head>"
puts $outFileID "<body>"

set HTML_STATE hdr
puts $outFileID "<table class=\"hdr\">"

for_file line $INFILE {

    if { [regexp {^\s*SRC:} $line] } {

        PrintLine src $line

    } elseif { [regexp {^\s*DST:} $line] } {

        PrintLine dst $line

    } elseif { [regexp {^\s*$} $line] } {

        puts $outFileID "<br>"

    } else {

        PrintHdrLine $line

    }

}

puts $outFileID "</p>"
puts $outFileID "</body>"
puts $outFileID "</html>"
