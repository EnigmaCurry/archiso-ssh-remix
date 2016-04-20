#!/bin/bash
avahi-browse -p -a --resolve | awk -F ';' '/archiso/{print $8}'
