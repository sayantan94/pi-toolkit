#!/bin/bash

PIDFILE="/tmp/mom-prism.pid"
LOGFILE="/tmp/mom-prism.log"

case "$1" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
      echo "Mom is already running (PID: $(cat $PIDFILE))"
      exit 1
    fi
    
    cd /Users/sayantbh/Workspace/fintool/pi-toolkit/packages/mom
    nohup node dist/main.js \
      --provider=amazon-bedrock \
      --model=global.anthropic.claude-opus-4-6-v1 \
      --sandbox=docker:mom-prism-sandbox \
      --skip-backfill \
      --channels=XXXXX \
      ~/mom-data > "$LOGFILE" 2>&1 &
    
    echo $! > "$PIDFILE"
    echo "Mom started (PID: $!)"
    ;;
    
  stop)
    if [ ! -f "$PIDFILE" ]; then
      echo "Mom is not running"
      exit 1
    fi
    
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID"
      rm "$PIDFILE"
      echo "Mom stopped (PID: $PID)"
    else
      echo "Mom is not running (stale PID file)"
      rm "$PIDFILE"
    fi
    ;;
    
  status)
    if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
      echo "Mom is running (PID: $(cat $PIDFILE))"
    else
      echo "Mom is not running"
      [ -f "$PIDFILE" ] && rm "$PIDFILE"
    fi
    ;;
    
  logs)
    tail -f "$LOGFILE"
    ;;
    
  restart)
    $0 stop
    sleep 2
    $0 start
    ;;
    
  *)
    echo "Usage: $0 {start|stop|status|logs|restart}"
    exit 1
    ;;
esac
