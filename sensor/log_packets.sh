#!/bin/sh

SNORT_PATH="/src/snort-1.9.0beta6/src/snort"
LOG_DIR="/snort_data/dailylogs"
INTERFACE="eth0"
PIDFILE="/var/run/snort_log.pid"
PRIORITY="local4.alert"

#
# log_packets logs every packet in binary format. This can obviously use
# a lot of disk space and it is recommended that it be ran on its own
# partition. I plan on adding disk maintenance type stuff later. A filter
# like the example below can be used to cut down on the amount of packets
# logged. 
# Filter example:  A filter like below could be used to ignore outbound
# HTTP tfc.
#tcpdump not \( src net 66.69.118.83/32 and dst port 80 and "tcp[0:2] > 1024" \) and not
#\( src port 80 and dst net 66.69.118.83/32 and "tcp[2:2] > 1024"\)
TZ=GMT
export TZ

start() {
  HOSTNAME=`hostname -s`
  if [ -x $SNORT_PATH ]; then
    if [ ! -d $LOG_DIR ]; then
      mkdir $LOG_DIR
    fi
    today=`date '+%Y-%m-%d'`
    if [ ! -d $LOG_DIR/$today ]; then
      mkdir $LOG_DIR/$today
    fi
    $SNORT_PATH -l $LOG_DIR/$today -b -i $INTERFACE > /dev/null 2>&1 &
    PID=$!
    if [ $? = 0 ]; then
      echo "Success."
      # Depreciated
      #/usr/bin/logger -p $PRIORITY "|||system-info|$HOSTNAME||Start logging...Success.||||||"
      echo $PID > $PIDFILE
    else
      # Depreciated
      #/usr/bin/logger -p $PRIORITY "|||system-info|$HOSTNAME||Start logging...Failed.||||||"
      echo "Failed."
      exit
    fi
  fi 
}

stop() {
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
  HOSTNAME=`hostname -s`
  if [ -f $PIDFILE ]; then
    OLDPID=`cat $PIDFILE`
    echo -n "Starting new process..."
    start
    echo -n "Killing old process..."
    kill $OLDPID
    if [ $? = 0 ]; then
      echo "Success."
      /usr/bin/logger -p $PRIORITY "|||system-info|$HOSTNAME||Stop old logging...Success.||||||"
    else
      echo "Failed."
      /usr/bin/logger -p $PRIORITY "|||system-info|$HOSTNAME||Stop old logging...Failed.||||||"
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
    stop
    ;;
  restart)
    restart
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
esac

DISKSPACE=`/bin/df -k $LOG_DIR | tail -1 | awk '{print $5}'`
/usr/bin/logger -p $PRIORITY "|||system-info|$HOSTNAME||$LOG_DIR: $DISKSPACE||||||"
