#!/bin/sh

SNORT_PATH="/usr/local/bin/snort"
LOG_DIR="/snort_data/dailylogs"
INTERFACE="ed0"
PIDFILE="/var/run/snort_log.pid"
LD_LIBRARY_PATH=/usr/local/lib/mysql
export LD_LIBRARY_PATH
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
    $SNORT_PATH -l $LOG_DIR/$today -b -i $INTERFACE > /tmp/snort.log 2>&1 &
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
    stop
    ;;
  restart)
    restart
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
esac
