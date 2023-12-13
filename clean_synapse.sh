#!/bin/bash
#
#  A script to help automate cleaning up your synapse server - at least parts of it.
#
# References:
#https://levans.fr/shrink-synapse-database.html
#https://github.com/matrix-org/synapse/blob/develop/docs/admin_api/purge_history_api.md
#https://github.com/matrix-org/synapse/tree/develop/docs/admin_api

export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
TEMPDIR=$(mktemp -d)

# Order of precedence
# hardcoded API key into script
# $XDG_CONFIG_HOME/synapse_apikey
# literally API_ID=theapiid \ HOMESERVER=homeserverurl
# As positional arguments


API_ID=
HOMESERVER=

if [ -z $API_ID ];then
    if [ -f "${XDG_CONFIG_HOME}/synapse_apikey" ];then
        API_ID=$(head -n 1 "${XDG_CONFIG_HOME}/synapse_apikey" | awk -F '=' '{print $2}')
        HOMESERVER=$(tail -n 1 "${XDG_CONFIG_HOME}/synapse_apikey" | awk -F '=' '{print $2}')
    fi
fi

if [ -z $API_ID ];then
    if [ "$#" -lt 2 ];then
        echo " ./clean_synapse.sh API_ID HOMESERVER_URL"
        echo " The homeserver URL should include https://"
    else
        API_ID="$1"
        HOMESERVER="$2"
    fi
fi

curl --header "Authorization: Bearer ${API_ID}" "${HOMESERVER}/_synapse/admin/v1/rooms?limit=300" > "${TEMPDIR}"/roomlist.json

jq '.rooms[] | select(.joined_local_members == 0) | .room_id' < "${TEMPDIR}"/roomlist.json > "${TEMPDIR}"/to_purge.txt    


#remove empty rooms

rooms_to_remove=$(awk -F '"' '{print $2}' < "${TEMPDIR}"/to_purge.txt)
for room_id in $rooms_to_remove; do 
    if [ -n "$room_id" ];then
        echo -e "\nDeleting ${room_id}!\n"    
        curl --header "Authorization: Bearer ${API_ID}" -X DELETE -H "Content-Type: application/json" -d "{}" "${HOMESERVER}/_synapse/admin/v2/rooms/${room_id}"
    fi
done    

if [ -f "${XDG_CONFIG_HOME}"/synapse_busyrooms.ini ];then
    echo -e "\n#################################################################\nRemoving recent history for busy IRC rooms\n"
    rooms_to_clean=$(awk -F '"' '{print $2}' < "${XDG_CONFIG_HOME}"/synapse_busyrooms.ini)
    ts=$(( $(date --date="1 days ago" +%s)*1000 ))
    for room_id in $rooms_to_clean; do 
    #remove history
        room_id=$(echo $room_id | sed 's/\!/%21/') 
        echo -e "\nRemoving history for $room_id\n"

        curl --header "Authorization: Bearer ${API_ID}" -X POST -H "Content-Type: application/json" -d "{ \"delete_local_events\": true, \"purge_up_to_ts\": $ts }"  "${HOMESERVER}/_synapse/admin/v1/purge_history/${room_id}"  

    # replaced with sed line above
    #the last bit has \${room_id} so the leading ! doesn't escape out

    done
fi

echo -e "\n#################################################################\nRemoving less recent history for all rooms\n"

jq '.rooms[] | select(.joined_local_members != 0) | .room_id' < "${TEMPDIR}"/roomlist.json > "${TEMPDIR}"/history_purge.txt 

rooms_to_clean=$(awk -F '"' '{print $2}' < "${TEMPDIR}"/history_purge.txt)
ts=$(( $(date --date="1 month ago" +%s)*1000 ))

for room_id in $rooms_to_clean; do 
#remove history    
    room_id=$(echo $room_id | sed 's/\!/%21/') 
    echo -e "\nRemoving history for $room_id\n"

    curl --header "Authorization: Bearer ${API_ID}" -X POST -H "Content-Type: application/json" -d "{ \"delete_local_events\": true, \"purge_up_to_ts\": $ts }"  "${HOMESERVER}/_synapse/admin/v1/purge_history/${room_id}"  

# replaced with sed line above
#the last bit has \${room_id} so the leading ! doesn't escape out

done

rm -rf "${TEMPDIR}"
