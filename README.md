# Sguil

Sguil (pronounced "sgweel") is a graphical interface to snort 
(www.snort.org), an open source intrusion detection system. 
The actual interface and GUI server are written in tcl/tk 
(www.tcl.tk). Sguil also relies on other open source software 
in order to function properly. 

That list includes: 
 * barnyard
 * mysql (www.mysql.com)
 * ethereal (www.ethereal.com)
 * tcpflow (http://www.circlemud.org/~jelson/software/tcpflow/)
 * awhois.sh (ftp://ftp.weird.com/pub/local/awhois.sh)

Sguil currently functions as an analysis interface and has 
no snort sensor or rule management capabilities. 

We hope to add those features in later releases.

# Source Code Layout

Files are located in the directory named for where they
will be installed.

## client -- Contains

 * `sguil.tk` -- Analysis GUI client and
 its conf file. 
 
 * `lib` -- contains some tcl scripts 
 that are needed by the client.

## sensor -- Contains 

 * `sensor_agent.tcl` --  a script that runs on the sensor that takes 
   input from barnyard and sends alerts to the sguild server.  It also 
   loads portscan, session, and sensor statistics to the sguild server.
 
 * `log_packets.sh` -- a shell script that runs a 
   second instance of snort to log all packets 
   for correlation.  Meant to be installed in a
   crontab.
 
 * `./snort_mods` -- patches to snorts portscan and
   stream4 preprocessors.  Most of the changes in
   these patches are output related and do not 
   effect the functionality of the preprocessor.

 * `./barnyad_mods` -- A barnyard output plugin (op_sguil.{c,h}) and 
   a patch to integrate it. NOTE: Barnyard-0.2.0 includes the sguil output
   plugin.
 
 * `./contrib` -- some stuff someone gave us...don't
   ask me how to use it.

## server -- Contains 

 * `sguild` -- The Sguil Server (again a TCL script)
   and its conf file.  This is the brains behind this
   whole mess.  This stuff gets installed on the 
   database server.  
 
 * `sguild.users` -- a text file with
   username:password pairs.  This is only for history
   tracking at this point.  There is no authentication. 
 
 * `xscriptd` -- A TCL script that takes requests from 
   the client for correlation data, goes and gets the 
   packets off of the sensor, and then sends them to 
   the client.

       * `autocat.conf`  -- Configuration file for sguild auto-
         categorization.

       * `sguild.reports` -- Configuration file for canned 
         sensor report queries

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

Copyright (C) 2002-2010 Robert (Bamm) Visscher <bamm@sguil.net>

GPLv3 - See LICENSE file for more details

