#!/bin/bash
START_TIME=$(date +%y%m%d_%H%M%S)
CMDLINE="$0 $@"
EXP_NAME=$(basename $0 .sh)
OUTPUT="exp.log"
OWNER=dbeniamine
RUN=30
EXEC=./bin/is.D
RTNAME=('base' 'numabalance')
declare -A RTCMD
RTCMD=([base]="sysctl kernel.numa_balancing=0" [numabalance]="sysctl kernel.numa_balancing=1")
CONFIGS=('dynamic' 'cyclic' 'tabarnac' 'libnuma' )
declare -A TARGET
TARGET=([dynamic]="$EXEC-dynamic" [cyclic]="$EXEC-cyclic" [tabarnac]="$EXEC-tabarnac"\
	[libnuma]="$EXEC-libnuma 4")
#report error if needed
function testAndExitOnError
{
    err=$?
    if [ $err -ne 0 ]
    then
        echo "ERROR $err : $1"
        exit $err
    fi
}
function dumpInfos
{

    #Echo start time
    echo "Expe started at $START_TIME"
    #Echo args
    echo "#### Cmd line args : ###"
    echo "$CMDLINE"
    echo "EXP_NAME $EXP_NAME"
    echo "OUTPUT $OUTPUT"
    echo "RUN $RUN"
    echo "########################"
    # DUMP environement important stuff
    echo "#### Hostname: #########"
    hostname
    echo "########################"
    echo "##### git log: #########"
    git log | head
    echo "########################"
    echo "#### git diff: #########"
    git diff
    echo "########################"
    lstopo --of txt
    cat /proc/cpuinfo
    echo "########################"


    #DUMPING scripts
    cp -v $0 $EXP_DIR/
    cp -v ./*.sh $EXP_DIR/
    cp -v *.pl $EXP_DIR/
    cp -v *.rmd  $EXP_DIR/
    cp -v Makefile  $EXP_DIR/
}
if [ $(whoami) != "root" ]
then
    echo "This script must be run as root"
    exit 1
fi
# lockmachine "exp in progress"
testAndExitOnError "can't lock machine"
#parsing args
while getopts "ho:e:r:" opt
do
    case $opt in
        h)
            usage
            exit 0
            ;;
        e)
            EXP_NAME=$OPTARG
            ;;
        o)
            OUTPUT=$OPTARG
            ;;
        r)
            RUN=$OPTARG
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
#post init
EXP_DIR="$EXP_NAME"_$(date +%y%m%d_%H%M)
mkdir $EXP_DIR
OUTPUT="$EXP_DIR/$OUTPUT"

#Do the first compilation
cd ../src/module
make
cd -

#Continue but change the OUTPUT
exec > >(tee $OUTPUT) 2>&1
dumpInfos

for run in $(seq 1 $RUN)
do
    echo "RUN : $run"
    #Actual exp
    for runtime in ${RTNAME[@]}
    do
        echo "$runtime"
	${RTCMD[$runtime]}
        LOGDIR="$EXP_DIR/$runtime/run-$run"
        mkdir -p $LOGDIR
        #Actual experiment
        for conf in ${CONFIGS[@]}
        do
            if [ $conf == "libnuma" ] && [ $runtime == "numabalance" ]
	    then
		continue
	    fi		
            echo ${TARGET[$conf]} > $LOGDIR/$conf.log 2> $LOGDIR/$conf.err
            testAndExitOnError "run number $run"
        done
    done
done

#cd $EXP_DIR/
#./parseAndPlot.sh
#cd -
#Echo thermal throttle info
echo "thermal_throttle infos :"
cat /sys/devices/system/cpu/cpu0/thermal_throttle/*
END_TIME=$(date +%y%m%d_%H%M%S)
echo "Expe ended at $END_TIME"
chown -R $OWNER:$OWNER $EXP_DIR
# unlockmachine

