#!/bin/sh

printInfo(){
echo "
# Custom logger, which read from one or more inputs into on file
- Be careful => input file will we wiped

# INSTALL
wget https://raw.githubusercontent.com/mallumoSK/alpine-logs/refs/heads/main/logs.sh -O /usr/bin/logs && chmod +x /usr/bin/logs
/usr/bin/logs

## Logic:
1. read line from input file
2. delete line from input file
3. write line to output file
4. delete overflow lines from output file

# ARGS:
## Required WATCHER arguments: --watcher, -i
## Required READER arguments: --reader

-  -w, --watcher  work mode as watcher, etc. --watcher alias-name
-  -r, --reader reader mode as reader, etc. --reader alias-name
-  -i, --input  path to input file
-  -p, --prefix line prefix for output file, etc. I (info), E (error) ..., default 'I'
-  -l, --lines  how many lines are cached, default 1000
-  -s, --stream stream mode for reader

-  -ws, --watcher-service 	 create setvice, whitch will be run in background

# Example
## WATCHER:

logs --watcher sample -i /var/log/server.log

## READER:

logs --reader sample
#or
logs --reader sample --stream


## Watcher service:
If sample service has 2 outputs
- /var/log/sample.log
- /var/log/sample.err

These 2 logs will join files 'sample.log' and 'sample.err' into one output

logs --watcher-service sample \
 -i /var/log/sample.log \
 -p \"I\" \
 -l 1000

logs --watcher-service sample \
 -i /var/log/sample.err \
 -p \"E\" \
 -l 1000

# SEE LOGS
logs -r sample

# SEE LOGS LIVE
logs -r sample --stream


"
}

FPREFIX="I"
FHISTORY=1000
FMODE_READER=0
FMODE_WATCHER=0
STREAM_READER=0
CREATE_SERVICE=0

if [ $# -lt 2 ] ; then
	printInfo
	exit 1
fi

while [ $# -gt 0 ]; do
  case $1 in
    -i|--input)
      FPATH="$2"
      shift # past argument
      shift # past value
      ;;
    -r|--reader)
      FMODE_READER=1
      FALIAS="$2"
      shift # past value
      shift # past value
      ;;
    -s|--stream)
      STREAM_READER=1
      shift # past value
      ;;
    -w|--watcher)
      FMODE_WATCHER=1
      FALIAS="$2"
      shift # past value
      shift # past value
      ;;
    -ws|--watcher-service)
      CREATE_SERVICE=1
      FALIAS="$2"
      shift # past value
      shift # past value
      ;;
      
    -p|--prefix)
      FPREFIX="$2"
      shift # past argument
      shift # past value
      ;;
    -l|--lines)
      FHISTORY="$2"
      shift # past argument
      shift # past value
      ;;
#    --default)
#      DEFAULT=YES
#      shift # past argument
#     ;;
    -*|--*)
	  printInfo
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      #POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

#set -- "${POSITIONAL_ARGS[@]}"



WD="/opt/logs"
PIDD="/opt/logs/pid"

PTARGET="$PIDD/p_$FALIAS"
OTARGET="$PIDD/o_$FALIAS"
LOGS_D="$WD/logs"
FTARGET="$LOGS_D/$FALIAS"

createTargetIfNotExists(){
	if [ ! -e "$FTARGET" ]
	then
		mkdir -p $LOGS_D
		mkdir -p $PIDD
		touch "$FTARGET"
		touch "$PTARGET"
		mkfifo "$OTARGET"
	fi
	
	LINES=$(wc -l < "$FTARGET")
	if [ "$LINES" -lt 1 ]
	then
		echo "END" > "$FTARGET"
	fi
}

writeToFifo(){
	PID=$(cat "$PTARGET")
	if [ ! -z $PID ]; then
		PROCCESS=$(ps -o pid | grep "$PID")
		if [ ! -z "$PROCCESS" ]; then
			echo "$1" > "$OTARGET" &
		fi
	fi
}

waitUntilAppearFile(){
	sleep 1
	while true;	do
		if [ -e "$FPATH" ] ; then
			break
		else
			sleep 1
		fi
	done
}

storeLine(){
	LINES=$(wc -l < "$FPATH")
	sleep 1
	if [ $LINES -gt 0 ] ; then
		DT=$(date +"%F'T'%H:%M:%S")
		# shellcheck disable=SC2034
		for i in $(seq $LINES)
		do
			read -r LINE<"$FPATH"
			sed -i '1d' "$FPATH"
			
			LINE="$DT  $LINE"
			
			if [ "${#FPREFIX}" -gt 0 ] ; then
				LINE="$FPREFIX $LINE"
			fi
			
			echo "$LINE" >> "$FTARGET"
			writeToFifo "$LINE"
		done
	fi
}

removeHistory(){
	LINES=$(wc -l < $FTARGET)
	while [ $FHISTORY -lt $LINES ]
	do
		sed -i '1d' $FTARGET
		LINES=$(wc -l < $FTARGET)
	done
}



runWatcher(){
	while true
	do
		waitUntilAppearFile
		storeLine
		removeHistory
	done
}

runReader(){
	if  [ $STREAM_READER -eq 1 ] ; then
		echo "$$" > "$PTARGET"
		cat "$FTARGET"
		while true
			do
			cat "$OTARGET"
			sleep 1
		done
	else
		cat "$FTARGET"
	fi
}

createService(){
		SERVICE_N="logs_$FALIAS.$FPREFIX"
		
		SERVICE_D="$WD/bin/$FALIAS"
		SERVICE_R="$SERVICE_D/run.sh"
		SERVICE_S="$SERVICE_D/$SERVICE_N"
		SERVICE_T="/etc/init.d/$SERVICE_N"
		SERVICE_B="/usr/bin/logs"
		mkdir -p "$SERVICE_D"
		cat "$0" > "$SERVICE_R"
		
line="#!/sbin/openrc-run
name=\"Logger service $FALIAS\"
description=\"Data logging for $FALIAS\"
command=\"/usr/bin/logs\"
command_args=\"-w $FALIAS -i $FPATH -p $FPREFIX -l $FHISTORY\"
command_background=true
pidfile=\"/run/$SERVICE_N.pid\"
output_log=\"/var/log/$SERVICE_N.log\"
error_log=\"/var/log/$SERVICE_N.err\"
"
echo "$line" > "$SERVICE_S"

		if [ ! -e "$SERVICE_T" ] ; then
			ln -s "$SERVICE_S" "$SERVICE_T"
		fi
		
		if [ ! -e $SERVICE_B ] ; then
			ln -s "$SERVICE_R" $SERVICE_B
		fi
		
		chmod +x $SERVICE_B
		chmod +x "$SERVICE_R"
		chmod +rx "$SERVICE_S"
		chmod +x "$SERVICE_T"
		
		rc-update add "$SERVICE_N" default
		rc-service "$SERVICE_N" start
		
		echo "DONE"
}

mainFun(){
	createTargetIfNotExists

	if  [ $FMODE_WATCHER -eq 1 ] ; then
		runWatcher
	elif [ $FMODE_READER -eq 1 ] ; then
		runReader
	elif [ $CREATE_SERVICE -eq 1 ] ; then
		createService
	else
		echo "ERR\nmissing mode $FMODE\n\n"
		printInfo
		exit 1
	fi
}

mainFun

