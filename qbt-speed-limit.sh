#!/bin/bash

set -e

#The total QBT transfer bytes (rx+tx) per interval before triggering the alternative speed limit
XFRMAX=$(( 20 * 1073741824 ))

#XFRFILE contains the number of bytes transferred at the start of the interval
#  Generate using the --save parameter
XFRFILE='qbt-xfr.save'

#QBT server protocol, name, and port
QBTSERVER='http://localhost:8080'

#WebUI API root for QBT versions 4.1+
QBTAPIROOT='/api/v2'


INFO=$(curl -s -X GET "${QBTSERVER}${QBTAPIROOT}/transfer/info")

xfrNow=$(echo $INFO | jq -r '[.dl_info_data,.up_info_data] | add')
printf "%-10s: %18s\n" 'xfrNow' "$xfrNow"

if [ "$1" = "--save" ]; then
  echo 'Saving current data transfer.'
  echo $xfrNow >$XFRFILE
  exit 0
fi

xfrStart=`cat $XFRFILE`
printf "%-10s: %18s\n" 'xfrStart' "$xfrStart"

xfrLimit=$((xfrStart + XFRMAX))
printf "%-10s: %18s\n" 'xfrLimit' "$xfrLimit"

#Limit Mode is 1 if alternative speed limits are enabled, 0 otherwise.
limitMode=$(curl -s -X GET "${QBTSERVER}${QBTAPIROOT}/transfer/speedLimitsMode")
printf "%-10s: %18s\n" 'limitMode' "$limitMode"



if [ $xfrNow -gt $xfrLimit ]
  then
  echo 'Transfer limit exceeded.'
  if [ $limitMode -eq 0 ]
  then
    curl -s -X POST "${QBTSERVER}${QBTAPIROOT}/transfer/toggleSpeedLimitsMode"
    echo 'Toggled to alternative speed limit.'
  else
    echo 'No change required.  Already at alternative limit.'
  fi
else
  printf "Under transfer limit [%s]\n" "$(( 100 * ( $xfrNow - $xfrStart ) / $XFRMAX ))%"
  if [ $limitMode -eq 1 ]
  then
    curl -s -X POST "${QBTSERVER}${QBTAPIROOT}/transfer/toggleSpeedLimitsMode"
    echo 'Toggled to global limit.'
  else
    echo 'No change required.  Already at global limit.'
  fi
fi
