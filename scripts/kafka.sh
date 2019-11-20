#!/bin/bash
#/etc/init.d/kafka
KAFKA_ROOT_PATH=
KAFKA_PATH=$KAFKA_ROOT_PATH/bin
KAFKA_PROCESS_NAME=kafka
# Check that networking is up.
#[ ${NETWORKING} = "no" ] && exit 0

PATH=$PATH:$KAFKA_PATH

# See how we were called.
case "$1" in
  start)
        # Start daemon.
        pid=`ps ax | grep -i 'kafka.Kafka' | grep -v grep | awk '{print $1}'`
        if [ -n "$pid" ]
          then
            echo "Kafka is already running"
        else
          echo "Starting $KAFKA_PROCESS_NAME"
          $KAFKA_PATH/kafka-server-start.sh -daemon $KAFKA_ROOT_PATH/config/server.properties
        fi
        ;;
  stop)
        echo "Shutting down $KAFKA_PROCESS_NAME"
        $KAFKA_PATH/kafka-server-stop.sh
        ;;
  restart)
        $0 stop
        sleep 2
        $0 start
        ;;
  status)
        pid=`ps ax | grep -i 'kafka.Kafka' | grep -v grep | awk '{print $1}'`
        if [ -n "$pid" ]
          then
          echo "Kafka is Running as PID: $pid"
        else
          echo "Kafka is not Running"
        fi
        ;;
  *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
esac

exit 0
