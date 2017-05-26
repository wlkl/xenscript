
#!/bin/bash

#remove previous static scripts if they exsist
rm -f /etc/snmp/procUtil.sh
rm -f /etc/snmp/memTotal.sh
rm -f /etc/snmp/memUsed.sh

#start creation of script for CPU utilization
#setup counters for CPU unique hardware UUID pollers
let counter1=0
let totalCpu=0
#determine number of CPUs present in system
let count=$(xe host-cpu-list | grep -c uuid)
#begin script output
echo >>procUtil.sh '#!/bin/bash'
echo >>procUtil.sh 'querytype=$1'
echo >>procUtil.sh 'oid=$2'
echo >>procUtil.sh ''
echo >>procUtil.sh '# Ignore getnext'
echo >>procUtil.sh 'if [[ $querytype = "-n" ]]; then'
echo >>procUtil.sh 'exit'
echo >>procUtil.sh 'fi'
echo >>procUtil.sh ''
echo >>procUtil.sh '# Refuse sets'
echo >>procUtil.sh 'if [[ $querytype = "-s" ]]; then'
echo >>procUtil.sh 'echo not-writable'
echo >>procUtil.sh 'exit'
echo >>procUtil.sh 'fi'
echo >>procUtil.sh ''
echo >>procUtil.sh '# Handle gets'
echo >>procUtil.sh ''
echo >>procUtil.sh 'echo "$oid"'
echo >>procUtil.sh 'echo integer'
#loop for creating a single query for each CPU in system
for i in $(  xe host-cpu-list host-uuid=$(xe host-list name-label=$(hostname) | sed -n 's/uuid ( RO)                : //p') | sed -n 's/uuid ( RO)           : //p')
do
        echo >>procUtil.sh 'procUtil'$totalCpu'=$(xe host-cpu-param-get uuid='$i' param-name=utilisation)'
        let totalCpu=totalCpu+1
done
#add all CPU usage and divide by total number of CPUs to get average utilization in ##.## percentage form
echo >>procUtil.sh 'totalUtil=$(echo "scale=0; ( \'
let count=count-1
while [ $counter1 -lt $count ]
do
        echo >>procUtil.sh '$procUtil'$counter1' + \'
        let counter1=counter1+1
done
let count=count+1
echo >>procUtil.sh '$procUtil'$counter1' ) * 100 / '$count'" | bc)'
#subtract usage from 100 to report idle percentage
echo >>procUtil.sh 'totalUtil=$(echo "scale=0; 100 - $totalUtil" | bc)'
echo >>procUtil.sh 'echo $totalUtil'

#start creation of Total System RAM poller script
echo >>memTotal.sh '#!/bin/bash'
echo >>memTotal.sh 'querytype=$1'
echo >>memTotal.sh 'oid=$2'
echo >>memTotal.sh ''
echo >>memTotal.sh '# Ignore getnext'
echo >>memTotal.sh 'if [[ $querytype = "-n" ]]; then'
echo >>memTotal.sh 'exit'
echo >>memTotal.sh 'fi'
echo >>memTotal.sh ''
echo >>memTotal.sh '# Refuse sets'
echo >>memTotal.sh 'if [[ $querytype = "-s" ]]; then'
echo >>memTotal.sh 'echo not-writable'
echo >>memTotal.sh 'exit'
echo >>memTotal.sh 'fi'
echo >>memTotal.sh ''
echo >>memTotal.sh '# Handle gets'
echo >>memTotal.sh ''
echo >>memTotal.sh 'echo $oid'
echo >>memTotal.sh 'echo integer'
echo >>memTotal.sh 'mem=$(xe host-list name-label=$(hostname) params=memory-total --minimal)'
echo >>memTotal.sh 'memT=$(($mem/1024))'
echo >>memTotal.sh 'echo $memT'

#start creation of Free System RAM poller script
echo >>memUsed.sh '#!/bin/bash'
echo >>memUsed.sh 'querytype=$1'
echo >>memUsed.sh 'oid=$2'
echo >>memUsed.sh ''
echo >>memUsed.sh '# Ignore getnext'
echo >>memUsed.sh 'if [[ $querytype = "-n" ]]; then'
echo >>memUsed.sh 'exit'
echo >>memUsed.sh 'fi'
echo >>memUsed.sh ''
echo >>memUsed.sh '# Refuse sets'
echo >>memUsed.sh 'if [[ $querytype = "-s" ]]; then'
echo >>memUsed.sh 'echo not-writable'
echo >>memUsed.sh 'exit'
echo >>memUsed.sh 'fi'
echo >>memUsed.sh ''
echo >>memUsed.sh '# Handle gets'
echo >>memUsed.sh ''
echo >>memUsed.sh 'echo "$oid"'
echo >>memUsed.sh 'echo integer'
echo >>memUsed.sh 'memFree=$(xe host-list name-label=$(hostname) params=memory-free --minimal)'
echo >>memUsed.sh 'memTotal=$(xe host-list name-label=$(hostname) params=memory-total --minimal)'
echo >>memUsed.sh 'memUsed=$((($memTotal - $memFree)/1024))'
echo >>memUsed.sh 'echo $memUsed'

#change permissions on scripts so the snmpd account can run them
chmod 755 procUtil.sh memTotal.sh memUsed.sh

#add pass commands to the current snmpd.conf file
echo >>snmpd.conf 'pass .1.3.6.1.4.1.2021.11.11.0 /etc/snmp/procUtil.sh'
echo >>snmpd.conf 'pass .1.3.6.1.2.1.25.2.3.1.5.1 /etc/snmp/memTotal.sh'
echo >>snmpd.conf 'pass .1.3.6.1.2.1.25.2.3.1.5.2 /etc/snmp/memTotal.sh'
echo >>snmpd.conf 'pass .1.3.6.1.2.1.25.2.3.1.6.1 /etc/snmp/memUsed.sh'
echo >>snmpd.conf 'pass .1.3.6.1.2.1.25.2.3.1.6.2 /etc/snmp/memUsed.sh'
echo >>snmpd.conf 'pass .1.3.6.1.4.1.31415.1.5 /etc/snmp/vmTable.sh'
echo >>snmpd.conf 'pass .1.3.6.1.4.1.31416.1.5 /etc/snmp/storage.sh'
