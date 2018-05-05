#Spectrum Scale Policy command to produce file list in "/admin/working/" called list.migrated

/usr/lpp/mmfs/bin/mmapplypolicy filesystem -f /admin/working/ -P /admin/scripts/dr_files.txt -I defer

#Spectrum Scale Policy in /admin/scripts/dr_files.txt to create the list.migrated file list which excludes snapshots and HSM migrated files.  

RULE 'exclude system files' list 'migrated' EXCLUDE WHERE PATH_NAME LIKE '/%.SpaceMan%/' OR PATH_NAME LIKE '/%.snapshots%/'
RULE 'exclude hsm migrated files' list 'migrated' WHERE MISC_ATTRIBUTES NOT LIKE '%V%'
