#!/bin/bash
############################
#
#Mimi - Mini Mirror
#
#A faux daemon 
#that uses a bash script to 
#run rsync in a contant loop
#to mirror a local directory
#to a remote directory.
#Use this to dev locally instead of 
#on a live server.
#
# Usage:
# mimi start usr_bin
# mimi stop usr_bin
# mimi -h
# mimi -v
#
#
#
#Author: Andrew Druffner andrew@nomstock.com
#https://github.com/ajdruff/mimi
#License: MIT
############################


###########################
#Configuration
###########################
CONFIG_DIR="/usr/local/etc/mimi/"

#how often loop repeats in seconds
DAEMON_LOOP_INTERVAL=5

###########################
#Advanced Configuration
#Devs only
###########################
DEBUG=false;
SIM=false; #starts a 'do nothing' loop instead of running the live loop
FOREGROUND=false; #keeps operation in foreground instead of operating like a daemon.this lets you see output
DAEMON_NAME="mimi"
DAEMON_DESCRIPTION="Mini Mirror - Mirrors a local directory to a remote directory over ssh"
DAEMON_VERSION="0.0.1"
DAEMON_HELP="Usage: mimi [start|stop|restart|status] [JOB] [OPTIONS]
Mirrors a local directory to a directory on a remote server.

start - starts rsync to mirror the directory configured in JOB.conf
stop - stops rsync mirroring
restart - stops and restarts rsync mirroring
status - checks to see if mirror is running

JOB - the base name of the configuration file /usr/local/etc/mimi/JOB.conf

OPTIONS
  -v, --version                 prints version
  -h, --help                    prints help


";
###########################
#End Configuration
###########################

###########################
#Scrub
###########################
#add trailing slash but strip trailing first if exists
CONFIG_DIR=${CONFIG_DIR%/}/

#remove trailing slash
#target_dir=${target_dir%/}


#####################
function version {
#####################

echo "${DAEMON_NAME} v${DAEMON_VERSION} ${DAEMON_DESCRIPTION} ";
exit;
}



###########################
function help {
###########################
echo -e "${DAEMON_HELP}";

exit;
}

###########################
function setTargetDirPerms {
###########################
  #create target directory if needed
  cmd="sudo mkdir -p ${target_dir}";
  ssh "${ssh_connection_string}" "${cmd}"; 
  
#change to final ownership
cmd="sudo chown -R ${final_owner} ${target_dir}";
ssh "${ssh_connection_string}" "${cmd}"; 

#set default permissions
cmd="sudo setfacl -b -d -m ${permissions} ${target_dir}";
ssh "${ssh_connection_string}" "${cmd}"; 

#set permissions
cmd="sudo setfacl -b -R -m ${permissions} ${target_dir}";
ssh "${ssh_connection_string}" "${cmd}"; 



}


###########################
function shutdownCleanup {
###########################
# use the trap pattern to 
# ensure that permissions are correctly
# applied even after exiting


#Starts a Continuous Loop, simulating a daemon
if [ "$SIM" != true ] ; then
setTargetDirPerms
fi

}






###########################
function checkJobArgNotEmpty {
###########################
if [ -z "$JOB" ]; then

echo "Start failed, You must specify a job. Try '${DAEMON_NAME} --help' for more information.";
exit;

fi

}

###########################
function checkConfigFileExists {
###########################
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Start failed. No configuration found for job. Check job name or add a configuration file at  ${CONFIG_FILE}"
exit;
fi
}

###########################
function readConfigFile {
###########################

#read in the variables from the configuration file.
source "${CONFIG_FILE}";
#add trailing slash but strip trailing first if exists
source_dir=${source_dir%/}/

#remove trailing slash
target_dir=${target_dir%/}

}

function startDaemon {


#set cmd to this script file so we can call it recursively
# pass the current job and use the startd private command when calling it recursively
#e.g.: mimi startd devops
#we need to pass the job name so it can retrieve the job variables.
    cmd=$(readlink -f "$0")
    cmd="${cmd} startd ${JOB}"



  #call this script, detach it from current process and place it in background. 
  #see "Start a background process from a script and manage it when the script ends"
  #https://unix.stackexchange.com/a/163816/

if [ "$FOREGROUND" = true ] ; then
$cmd
else
nohup $cmd >/dev/null 2>&1 &
fi
  

  #capture its PID so we can save it to configuration file to use it later when we need to kill it.
  #https://unix.stackexchange.com/a/163816/266882
  bg_pid=$!

}

###########################
function savePidToConfigFile {
###########################
#save the PID to configuration file (replace or add)
#see superuser, "sed: how to replace line if found or append to end of file if not found?" https://superuser.com/a/590666/417331
  grep -q "^PID=" "${CONFIG_FILE}" && sed "s/^PID=.*/PID=$bg_pid/" -i "${CONFIG_FILE}"  || sed "$ a\PID=$bg_pid" -i "${CONFIG_FILE}" 


}
###########################
function WarnIfDaemonIsRunning {
###########################
if  kill -0 "${PID}" > /dev/null 2>&1; then
   echo "${DAEMON_NAME} is already running for this job, (PID=$PID)"
exit;
fi
}


###########################
function checkDaemonStatus {
###########################
if  kill -0 "${PID}" > /dev/null 2>&1; then
   echo "${DAEMON_NAME} is running for job ${JOB}, (PID=$PID)"
else
 echo "${DAEMON_NAME} has stopped for job ${JOB}, (PID=$PID)"
exit;
fi
}



###########################
function WarnIfDaemonIsStopped {
###########################
if ! kill -0 "${PID}" > /dev/null 2>&1; then
   echo "${DAEMON_NAME} has already stopped for this job, (PID=$PID)"
exit;
fi
}

function stopDaemon {
 kill -15 "${PID}"
}



function removePidFromConfigFile {

sed -i "/$PID/d"  "${CONFIG_FILE}"

}




###########################
function setConfigFile {
###########################
CONFIG_FILE="${CONFIG_DIR}"/"${JOB}".conf;
}



############################
function startDaemonLoop {
############################


#echo "${ssh_connection_string}" ;

#creates target diretory and sets initial permissionis
setTargetDirPerms

#must be owned by sync_owner or will get 'failed to set permissions' error during rsync
ssh "${ssh_connection_string}" "sudo  chown -R ${sync_owner} ${target_dir}"


# rsync every 5 seconds
while true ; do 
rsync --hard-links  --archive --omit-dir-times "${source_dir}" "${ssh_connection_string}":"${target_dir}" --delete  && sleep ${DAEMON_LOOP_INTERVAL};

done

shutdownCleanup;
}

################################
function startSimLoop {
################################

while true ; do 
echo 'hello';


sleep ${DAEMON_LOOP_INTERVAL};

done
}



###########################
# getOpts see https://gist.github.com/cosimo/3760587
###########################
OPTS=`getopt -o vh --long version,help -n 'parse-options' -- "$@"`


#output if failed parsing
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi


eval set -- "$OPTS"


while true; do
  case "$1" in
    -v | --version ) version; shift ;;
    -h | --help )    help; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

while true; do
  case "${1}" in
    start  ) START=true; break ;;
    stop  )    STOP=true; break ;;
    restart  ) RESTART=true; break ;;
    status  )  STATUS=true; break ;;
    startd  )  STARTD=true; break ;;
    * ) break ;;
  esac
done


#set Job
JOB="${2}";

if [ "$DEBUG" = true ] ; then
echo "getOpts Options parsed as : " "$OPTS"
echo START=$START
echo STOP=$STOP
echo RESTART=$RESTART
echo STATUS=$STATUS
echo STARTD=$STARTD
echo JOB="$2"
fi

###########################
# END GetOpts
###########################


###########################
# START
###########################
if [ "$START" = true ] ; then


checkJobArgNotEmpty;
setConfigFile;

checkConfigFileExists;
readConfigFile;

WarnIfDaemonIsRunning;
startDaemon;
savePidToConfigFile;

echo "Started ${DAEMON_NAME} successfully, (PID=$bg_pid)";
exit;
fi


###########################
# STOP
###########################

if [ "$STOP" = true ] ; then


checkJobArgNotEmpty;
setConfigFile
checkConfigFileExists;
readConfigFile;
WarnIfDaemonIsStopped;
stopDaemon;
removePidFromConfigFile;

echo "Stopped ${DAEMON_NAME} successfully";
exit;
fi

###########################
# RESTART
###########################

if [ "$RESTART" = true ] ; then


checkJobArgNotEmpty;
setConfigFile
checkConfigFileExists;
readConfigFile;
WarnIfDaemonIsStopped;
stopDaemon;
removePidFromConfigFile;
startDaemon;
savePidToConfigFile;

echo "Restarted ${DAEMON_NAME} successfully (PID=$PID)";
exit;
fi


###########################
# STATUS
###########################
if [ "$STATUS" = true ] ; then


checkJobArgNotEmpty;
setConfigFile
checkConfigFileExists;
readConfigFile;
checkDaemonStatus;
exit;
fi


###########################
# DAEMON START
###########################
if [ "$STARTD" = true ] ; then


#Starts a Continuous Loop, simulating a daemon
if [ "$SIM" = true ] ; then
startSimLoop
else

# executes cleanup on exit,ctrl-c,etc
trap shutdownCleanup EXIT


checkJobArgNotEmpty;
setConfigFile
checkConfigFileExists;
readConfigFile;
startDaemonLoop
exit;
fi
fi


####################
#
# Main
#
####################














