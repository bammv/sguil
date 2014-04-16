# Sguil

Sguil (pronounced sgweel) is built by network security analysts for network security analysts. Sguil's main component is an intuitive GUI that provides access to realtime events, session data, and raw packet captures. Sguil facilitates the practice of Network Security Monitoring and event driven analysis. The Sguil client is written in tcl/tk and can be run on any operating system that supports tcl/tk (including Linux, *BSD, Solaris, MacOS, and Win32).

# Source Code Layout

Files are located in the directory named for where they
will be installed.

## client -- Contains

 * `sguil.tk` -- Analysis GUI client and its conf file. 
 
 * `lib` -- contains some tcl scripts that are needed by the client.

## sensor -- Contains 

 * `snort_agent.tcl` --  a script that runs on the sensor that takes 
   input from barnyard and sends alerts to the sguild server.  It also 
   loads portscan, session, and sensor statistics to the sguild server.
 
 * `sancp_agent.tcl` --  a script that runs on the sensor, reads session
    files from the specified directory and pushes them to sguild for 
    where they are loaded into the DB
 
 * `pcap_agent.tcl` --  a script that runs on the sensor and processes
    requests for packet data from sguild
 
 * `log_packets.sh` -- a shell script that runs a 
   second instance of snort to log all packets 
   for correlation.  Meant to be installed in a
   crontab.
 
 * `./contrib` -- some stuff someone gave us...don't
   ask me how to use it.

## server -- Contains 

 * `sguild` -- The Sguil Server (again a TCL script)
   and its conf file.  This is the brains behind this
   whole mess.  This stuff gets installed on the 
   database server.  
 
       * `sguild.queries` --  Configuration file for Standard
         queries

       * `sguild.access` -- Configuration file for User access-
         control

       * `sguild.email` -- Configuration file for automatic
         emails on alerts from sguild.
 
 * `sql_scripts` -- Scripts to create the sguildb 
   database structure.


## ./doc
A bunch of (hopefully) helpful documents.

## ./contrib
some more stuff, ya got me.

## License

Copyright (C) 2002-2014 Robert (Bamm) Visscher <bamm@sguil.net>

GPLv3 - See LICENSE file for more details

