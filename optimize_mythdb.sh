#!/bin/bash

OPT_MYTHDB='/usr/share/mythtv/contrib/maintenance/optimize_mythdb.pl'
LOG='/var/log/mythtv/optimize_mythdb.log'

echo "Started ${OPT_MYTHDB} on `date`" >> ${LOG}
${OPT_MYTHDB} >> ${LOG}
echo "Finished ${OPT_MYTHDB} on `date`" >> ${LOG}