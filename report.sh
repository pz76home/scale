#!/bin/bash


#Spectrum Scale main report script (the path in the for loop is the top level directory). Reports on ondisk, migrated and premigrated capacities

WORKING_DIR=/admin/scripts/report/
OUTPUT_DIR=/admin/scripts/report/output

echo "Test file placement and quota report" > ${WORKING_DIR}report.txt

for DIR in `find /filesystem/top_level_directory/ -maxdepth 1 -mindepth 1 -type d`
do
export BASE=`basename $DIR`

sed 's|DIR|'$DIR'|g; s|BASE|'$BASE'|g' /admin/scripts/report/migrated_policy.txt > ${WORKING_DIR}${BASE}.migrated.txt
sed 's|DIR|'$DIR'|g; s|BASE|'$BASE'|g' /admin/scripts/report/ondisk_policy.txt > ${WORKING_DIR}${BASE}.ondisk.txt
sed 's|DIR|'$DIR'|g; s|BASE|'$BASE'|g' /admin/scripts/report/premig_policy.txt > ${WORKING_DIR}${BASE}.premig.txt

/usr/lpp/mmfs/bin/mmapplypolicy ci-nas -N all -a 8 -f $OUTPUT_DIR -P ${WORKING_DIR}${BASE}.migrated.txt  -I defer

sleep 2

/usr/lpp/mmfs/bin/mmapplypolicy ci-nas -N all -a 8 -f $OUTPUT_DIR -P ${WORKING_DIR}${BASE}.ondisk.txt -I defer

sleep 2

/usr/lpp/mmfs/bin/mmapplypolicy ci-nas -N all -a 8 -f $OUTPUT_DIR -P ${WORKING_DIR}${BASE}.premig.txt -I defer

sleep 1

echo "${DIR} Migrated files information" >> ${WORKING_DIR}report.txt

touch ${OUTPUT_DIR}/list.${BASE}migrated

${WORKING_DIR}capacity.py < ${OUTPUT_DIR}/list.${BASE}migrated >> ${WORKING_DIR}report.txt

echo "${DIR} Ondisk files information" >> ${WORKING_DIR}report.txt

touch ${OUTPUT_DIR}/list.${BASE}ondisk

${WORKING_DIR}capacity.py < ${OUTPUT_DIR}/list.${BASE}ondisk >> ${WORKING_DIR}report.txt

echo "${DIR} Premigrated files information" >> ${WORKING_DIR}report.txt

touch ${OUTPUT_DIR}/list.${BASE}premig

${WORKING_DIR}capacity.py < ${OUTPUT_DIR}/list.${BASE}premig >> ${WORKING_DIR}report.txt

echo "--------------------------------------------------------------------------------------" >> ${WORKING_DIR}report.txt
