#!/bin/bash
function getData() {
        OBJTYPE=$1 ; # OID.3.y
        OBJID=$2  ; # OID.3.X.y

OBJECT=( $(xe vm-list | grep uuid | sed $OBJID'q;d' |
sed -n 's/uuid ( RO)           : //p') )
        case "$OBJTYPE" in 
		6)
                        RETVAL="String\n"
                        RETVAL="$RETVAL$(xe vm-param-get uuid=$OBJECT param-name=networks | sed -n 's@^.*0/ip: @@p')\n"
                        EXITVAL=0
                        ;;
                5)
                        RETVAL="Integer\n"
                        if [ "$(xe vm-param-get uuid=$OBJECT param-name=power-state)" != "running" ]; then
                                RETVAL="Integer\n0\n"
                                EXITVAL=0
                                RETOID="$MY_OID.1.${OBJECTTYPE}.${OBJECTID}\n"
                                printf "${RETOID}${RETVAL}"
                                exit ${EXITVAL}
                        fi
						#create array of CPU 
						#usage
                        calculation=( $(xe vm-param-get uuid=$OBJECT param-name=VCPUs-utilisation | sed -n 's/[0123456789]: //p' | sed 's/; [0123456789]://gp'))
                        let counter1=0
                        #determine number of CPUs present in system
                        let count=${#calculation[@]}
                        #add all CPU usage and divide by total number of 
                        #CPUs to get average utilization in ##.## 
                        #percentage form
                        let totalUtil=0
                        while [ $counter1 -lt $count ]
                        do
                                totalUtil=$(echo "scale=2; ( $totalUtil + ${calculation[$counter1]} ) " | bc)
                                let counter1=counter1+1
                        done
                        totalUtil=$(echo "scale=2; $totalUtil * 100 / $count" | bc)
                        RETVAL="$RETVAL$totalUtil\n"
                        EXITVAL=0
                        ;;
                4)
                        RETVAL="Integer\n"
                        RETMEM=$(echo "scale=0; $(xe vm-param-get uuid=$OBJECT param-name=memory-actual) / 1024 / 1024" | bc)
                        RETVAL="$RETVAL$RETMEM\n"
                        EXITVAL=0
                        ;;
                3)
                        RETVAL="string\n"
                        RETVAL="$RETVAL$(xe vm-param-get uuid=$OBJECT param-name=power-state)\n"
                        EXITVAL=0
                        ;;
                2)
                        RETVAL="string\n"
                        RETVAL="$RETVAL$(xe vm-param-get uuid=$OBJECT param-name=os-version | sed -n 's/name: //p' | sed -n -e 's/^\([^|]*\)|.*/\1/p')\n"
                        EXITVAL=0
                        ;;
                1)
                        RETVAL="string\n"
                        RETVAL="$RETVAL$(xe vm-param-get uuid=$OBJECT param-name=name-label)\n"
                        EXITVAL=0
                        ;;
        esac
}

function getNext() {
        REQUEST=$1
        # Always start at .3.1.1
        if [ "$REQUEST" == "" ]; then
                REQUEST=".3.1.0"
        fi
        OBJECTID=`echo $REQUEST | awk 'BEGIN { FS="." } ; { print $4 }'`
        OBJECTTYPE=`echo $REQUEST | awk 'BEGIN { FS="." } ; { print $3 }'`
        if [ "$OBJECTID" == "" ]; then
                let OBJECTID=0
        fi
        let OBJECTID=$OBJECTID
        let OBJECTTYPE=$OBJECTTYPE
        # Get next entry
        if [ $OBJECTID -le $(xe vm-list | grep -c uuid) ]; then
                let OBJECTID=${OBJECTID}+1
        fi
		# Get next category if no more lines
        if [ $OBJECTID -gt $(xe vm-list | grep -c uuid) ]; then
                let OBJECTTYPE=${OBJECTTYPE}+1
                let OBJECTID=1
        fi
		# Stop when no more categories
        if [ $OBJECTTYPE -gt ${MAXITEMS} ]; then
                exit 0
        fi
        getData ${OBJECTTYPE} ${OBJECTID}
        RETOID="$MY_OID.1.${OBJECTTYPE}.${OBJECTID}\n"
}

###### Settings ######
MY_OID=".1.3.6.1.4.1.31415.1.5" ;# Set in /etc/snmp/snmpd.conf

# Arguments
REQ_OID="${2#$MY_OID}" ;# Strip MY_OID from requested OID 
REQ_TYPE="$1" ;# n,g(GET),s(SET)

###### MAIN ######

# Obtain vm-stats info
MAXITEMS=6

# Check request
case "${REQ_TYPE}" in
        -n)
                getNext $REQ_OID
                ;;
        -s)
                ### Someone tried to set a value... log for analysis 
                ### logger -t snmp_haproxy -p crit "SET attempted $0 $*"
                exit 0
                ;;
        -g)
                ### GetValue
                REQUEST=$REQ_OID
                OBJECTID=`echo $REQUEST | awk 'BEGIN { FS="." } ; { print $4 }'`
                OBJECTTYPE=`echo $REQUEST | awk 'BEGIN { FS="." } ; { print $3 }'`
                getData ${OBJECTTYPE} ${OBJECTID}
                RETOID="$MY_OID.1.${OBJECTTYPE}.${OBJECTID}\n"
                ;;
        *)
                exit 0
                ;;
esac
 

printf "${RETOID}${RETVAL}"
exit ${EXITVAL}
