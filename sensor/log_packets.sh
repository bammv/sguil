#!/bin/sh
# $Id: log_packets.sh,v 1.25 2006/03/09 15:51:47 bamm Exp $ #

################################################
#                                              #
# log_packets.sh is just a quick shell script  #
# to make managing a snort process to log all  #
# pcap data traversing a network easy. By      #
# default it logs everything so be sure to     #
# have a lot of disk space available.          #
#                                              #
################################################


##############################################################
#                                                            #
#  USAGE: ./log_packets.sh <start|stop|restart|cleandisk>    #
#                                                            #
# Recommendation for crontab:                                #
#                                                            #
# 00 * * * * /path/to/log_packets.sh restart                 #
#                                                            #
##############################################################


# Edit these for your setup

# Sensors hostname.
# Note: If running multiple snort instances, then this must be different
#       for each instance (ie sensor1, sensor2, sensor-eth0, sensor-eth1, etc)
HOSTNAME="myhost"
# Path to snort binary
SNORT_PATH="/usr/local/bin/snort"
# Directory to log pcap data to (date dirs will be created in here)
# Note: The path $HOSTNAME/dailylogs, will be appended to this.
LOG_DIR="/snort_data"
# Percentage of disk to try and maintain
MAX_DISK_USE=90
# Interface to 'listen' to.
INTERFACE="eth0"
# Other options to use when starting snort
#OPTIONS="-u sguil -g sguil -m 122"
# Where to store the pid
PIDFILE="/var/run/snort_log-${HOSTNAME}.pid"
# How do we run ps
PS="ps awx"
# Where is grep
GREP="/usr/bin/grep"
#Add BPFs here.
#The below is an example of a filter for ignoring outbound HTTP from my network
# to the world.
#FILTER='not \( src net 67.11.255.148/32 and dst port 80 and "tcp[0:2] > 1024" \) and not \( src port 80 and dst net 67.11.255.148/32 and "tcp[2:2] > 1024"\)'

#Some installs may need these
#LD_LIBRARY_PATH=/usr/local/lib/mysql
#export LD_LIBRARY_PATH

TZ=GMT
export TZ

# Make sure our default logging dir is there.
if [ ! -d $LOG_DIR/$HOSTNAME ]; then
  mkdir $LOG_DIR/$HOSTNAME
  chmod 777 $LOG_DIR/$HOSTNAME
fi
if [ ! -d $LOG_DIR/$HOSTNAME/dailylogs ]; then
  mkdir $LOG_DIR/$HOSTNAME/dailylogs
  chmod 777 $LOG_DIR/$HOSTNAME/dailylogs
fi
LOG_DIR="$LOG_DIR/$HOSTNAME/dailylogs"

start() {
 if [ ! -f $PIDFILE ]; then 
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
    if [ -n "$FILTER" ]; then
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
 else
  echo "log_packets.sh already running." 
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
    # we need to nuke PIDFILE so that when we call start, it doesn't exit cause it thinks we are already running.
    rm $PIDFILE
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
    echo "Checking for old process with ps."
    res=`$PS | $GREP "$SNORT_PATH" | $GREP "$LOG_DIR" | $GREP -v grep | awk '{print $1}'`
    if [ $res ]; then
	echo "Old log packets proccess found at pid $res, killing."
	kill $res
	if [ $? = 0 ]; then
	    echo "Success."
	    echo "Starting new process."
	    start
	else
	    echo "Failed."
	fi
    else
	echo "No old processes found."
	echo "Starting new process anyway."
	start
    fi
  fi
}

# This func checks the current space being used by LOG_DIR
# and rm's data as necessary.
cleandisk() {
  echo "Checking disk space (limited to ${MAX_DISK_USE}%)..."
  # grep, awk, tr...woohoo!
  CUR_USE=`df -P $LOG_DIR | grep -v -i filesystem | awk '{print $5}' | tr -d %`
  echo "  Current Disk Use: ${CUR_USE}%"
  if [ $CUR_USE -gt $MAX_DISK_USE ]; then
    # If we are here then we passed our disk limit
    # First find the oldest DIR
    cd $LOG_DIR
    # Can't use -t on the ls since the mod time changes each time we
    # delete a file. Good thing we use YYYY-MM-DD so we can sort.
    OLDEST_DIR=`ls | sort | head -1`
    if [ -z $OLDEST_DIR ] || [ $OLDEST_DIR = ".." ] || [ $OLDEST_DIR = "." ]; then
      # Ack, we rm'd all of our raw data files/dirs.
      echo "ERROR: No pcap directories found in $LOG_DIR."
      echo "Something else must be hogging the diskspace."
    else
      cd $LOG_DIR/$OLDEST_DIR
      OLDEST_FILE=`ls -t | tail -1`
      if [ $OLDEST_FILE ]; then
        echo "  Removing file: $OLDEST_DIR/$OLDEST_FILE"
        rm -f $OLDEST_FILE
      else
        echo "  Removing empty dir: $OLDEST_DIR"
        cd ..; rmdir $LOG_DIR/$OLDEST_DIR
      fi
      # Run cleandisk again as rm'ing one file might been enough
      # but we wait 5 secs in hopes any open writes are done.
      sync
      echo "  Waiting 5 secs for disk to sync..."
      sleep 5
      cleandisk
    fi
  else
    echo "Done."
  fi
}

case "$1" in
  start)
    start
    cleandisk
    ;;
  stop)
    stopproc
    ;;
  restart)
    restart
    cleandisk
    ;;
  cleandisk)
    cleandisk
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|cleandisk}"
esac
