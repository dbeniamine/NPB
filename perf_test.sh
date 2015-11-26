#!/bin/bash
START_TIME=$(date +%y%m%d_%H%M%S)
CMDLINE="$0 $@"
EXP_NAME=$(basename $0 .sh)
OUTPUT="exp.log"
OWNER=dbeniamine
RUN=30
EXEC=./bin/is.D
# State for aff, balancing and interleave
STATES=('off' 'on')
# Affinity
declare -A AFFCMD
AFFCMD=([on]='export GOMP_CPU_AFFINITY=0-63' [off]='unset GOMP_CPU_AFFINITY')
# numa_balancing
declare -A BALANCECMD
BALANCECMD=([off]="sysctl kernel.numa_balancing=0" [on]="sysctl kernel.numa_balancing=1")
#Interleave
declare -A INTERLEAVECMD
INTERLEAVECMD=([on]="numactl -i all" [off]='')
CONFIGS=('dynamic' 'cyclic' 'tabarnac')
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

#Continue but change the OUTPUT
exec > >(tee $OUTPUT) 2>&1
dumpInfos

#Remove me
function res()
{
    num=$(printf "%d\n" 0x$(echo "$1" | md5sum | cut -c 1-4))
    echo "Time in seconds   =                                        $num"
}


for run in $(seq 1 $RUN)
do
    echo "RUN : $run"
    #Actual exp
    for affst in ${STATES[@]}
    do
	${AFFCMD[$affst]}
	echo $GOMP_CPU_AFFINITY
        for balst in ${STATES[@]}
        do
	    ${BALANCECMD[$balst]}
            for interst in ${STATES[@]}
            do
		echo "interleave $interst"
		LOGDIR="$EXP_DIR/affinity-$affst/balancing-$balst/interleave-$interst/run-$run/"
                mkdir -p $LOGDIR
                #Actual experiment
                for conf in ${CONFIGS[@]}
                do
                    #echo ${INTERLEAVECMD[$interst]} $EXEC-$conf > $LOGDIR/$conf.log 2> $LOGDIR/$conf.err
                    meta="$affst-$balst-$interst-$conf"
                    res $meta> $LOGDIR/$conf.log 2> $LOGDIR/$conf.err
                    testAndExitOnError "run number $run"
		done
            done
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
