#!/bin/bash

TYPES="lvm nfs" #list of shared types

function getData() {
   OBJTYPE=$1 ; # OID.3.y
   OBJID=$2 ; # OID.3.X.y

              OBJECT="$(for e in $TYPES; do  xe sr-list type=$e; done | grep uuid | sed $OBJID'q;d' | sed -n 's/uuid ( RO)                : //p')"

 case "$OBJTYPE" in
      4)
                RETVAL="string\n"
                RETVAL="$RETVAL$(echo $OBJECT)\n"
                EXITVAL=0
                ;;
      3)
                RETVAL="string\n"
                RETVAL="$RETVAL$(xe sr-list uuid=$OBJECT params=name-label | sed -n 's/name-label ( RW)    : //p')\n"
                EXITVAL=0
                ;;
      2)
                RETVAL="string\n"
                RETVAL="$RETVAL$(xe sr-list uuid=$OBJECT params=name-description | sed -n 's/name-description ( RW)    : //p')\n"
                EXITVAL=0
                ;;
      1)
                RETVAL="string\n"
                RETVAL="$RETVAL$(xe sr-list uuid=$OBJECT params=type |  sed -n 's/type ( RO)    : //p')\n "
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
        if [ $OBJECTID -le $(xe sr-list | grep -c uuid) ]; then
                let OBJECTID=${OBJECTID}+1
        fi
		# Get next category if no more lines
        if [ $OBJECTID -gt $(xe sr-list | grep -c uuid) ]; then
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
MY_OID=".1.3.6.1.4.1.31416.1.5" ;# Set in /etc/snmp/snmpd.conf
# Arguments
REQ_OID="${2#$MY_OID}" ;# Strip MY_OID from requested OID
REQ_TYPE="$1" ;# n,g(GET),s(SET)
###### MAIN ######
# Obtain vm-stats info
let MAXITEMS=4
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
