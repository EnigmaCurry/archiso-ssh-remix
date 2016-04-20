#!/bin/bash

# Remember all hosts seen by name:
declare -A hosts

while true; do
    avahi_hosts=$(avahi-browse _archiso._tcp --resolve -t 2>&1 | grep address | sed -r -n 's/address = \[(.*)\]/\1/p' | sort -u)
    saw_new=n
    for h in $avahi_hosts; do
	if [ "${hosts[$h]}" != "y" ]; then
	    echo `date` - New archiso instance found: $h
	    saw_new=y
	fi
    done
    if [ $saw_new == y ]; then
	echo "--"
    fi

    # Hosts may also have gone away, so reset hosts to just the new hosts:
    unset hosts
    declare -A hosts
    for h in $avahi_hosts; do
	hosts[$h]="y"
    done
    sleep 1
done
