#!/bin/sh

# $Id: log_packets.sh,v 1.9 2003/11/19 18:18:14 bamm Exp $ #

################################################
#                                              #
# log_packets.sh is just a quick shell script  #
# to make managing a snort process to log all  #
# pcap data traversing a network easy. By      #
# default it logs everything so be sure to     #
# have a lot of disk space available.          #
#                                              #
################################################


####################################################
#                                                  #
#  USAGE: ./log_packets.sh <start|stop|restart>    #
#                                                  #
# Recommendation for crontab:                      #
#                                                  #
# 00 0-23/1 * * * /path/to/log_packets.sh restart  #
#                                                  #
####################################################


# Edit these for your setup

# Path to snort binary
SNORT_PATH="/usr/local/bin/snort"
# Directory to log pcap data to (date dirs will be created in here)
LOG_DIR="/snort_data/dailylogs"
# Interface to 'listen' to.
INTERFACE="eth0"
# Other options
OPTIONS="-u sguil -g sguil -m 122"
# Where to store the pid
PIDFILE="/var/run/snort_log.pid"

#Add BPFs here.
#The below is an example of a filter for ignoring outbound HTTP from my network
# to the world.
#FILTER='not \( src net 67.11.255.148/32 and dst port 80 and "tcp[0:2] > 1024" \) and not \( src port 80 and dst net 67.11.255.148/32 and "tcp[2:2] > 1024"\)'

#Some installs may need these
#LD_LIBRARY_PATH=/usr/local/lib/mysql
#export LD_LIBRARY_PATH

TZ=GMT
export TZ

start() {
  if [ -x $SNORT_PATH ]; then
    if [ ! -d $LOG_DIR ]; then
      mkdir $LOG_DIR
      chmod 777 $LOG_DIR
    fi
    today=`date '+%Y-%m-%d'`
    if [ ! -d $LOG_DIR/$today ]; then
      mkdir $LOG_DIR/$today
      chmod 777 $LOG_DIR/$today
    fi
    if [ -n FILTER ]; then
      eval exec $SNORT_PATH $OPTIONS -l $LOG_DIR/$today -b -i $INTERFACE $FILTER > /tmp/snort.log 2>&1 &
    else
      eval exec $SNORT_PATH $OPTIONS -l $LOG_DIR/$today -b -i $INTERFACE > /tmp/snort.log 2>&1 &
    fi
    PID=$!
    if [ $? = 0 ]; then
      echo "Success."
      echo $PID > $PIDFILE
    else
      echo "Failed."
      exit
    fi
  fi 
}

stopproc() {
  if [ -f $PIDFILE ]; then
    kill `cat $PIDFILE`
    if [ $? = 0 ]; then
      echo "Success."
    else
      echo "Failed."
    fi
    rm -f $PIDFILE
  fi
}

restart() {
  if [ -f $PIDFILE ]; then
    OLDPID=`cat $PIDFILE`
    echo -n "Starting new process..."
    start
    echo -n "Killing old process..."
    kill $OLDPID
    if [ $? = 0 ]; then
      echo "Success."
    else
      echo "Failed."
    fi
  else
    echo "Error: $PIDFILE does not exist."
    echo "Starting new process anyway."
    start
  fi
}

case "$1" in
  start)
    start
    ;;
  stop)
    stopproc
    ;;
  restart)
    restart
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
esac
