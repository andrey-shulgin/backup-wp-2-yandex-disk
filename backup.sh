#!/bin/bash

# Configurable variables
SITENAME="" # Sitename (root folder name on Yandex.Disk server)
OFFSET=2; # Offset in weeks for expired data removal

# Predefined variables
NOW=$(date +"%Y-%m-%d")
CURDAYNUM=$(($(date +%u)-1))
CURYEARMONTH=$(date +%Y-%m)
WEEKBEG=$(date -d'-'$(($CURDAYNUM))' days' +%d.%m); # Begin of current week
WEEKEND=$(date -d'+'$((6-$CURDAYNUM))' days' +%d.%m); # End of current week
WEEKBEGWOZERO=$(date -d'-'$(($CURDAYNUM))' days' +%-d); # Begin of current week without leading zeros
TODAY=$(date +%d); # End of current week without leading zeros
TODAYWOZERO=$(date +%-d); # End of current week without leading zeros
WEEKBEGOFST=$(date -d'-'$OFFSET' week - '$(($CURDAYNUM))' days' +%d.%m); # Begin of offsetted week
WEEKENDOFST=$(date -d'-'$OFFSET' week +'$((6-$CURDAYNUM))' days' +%d.%m); # End of offsetted week
BACKUP_FILE="backup.$NOW"
ROOT_DIR=$PWD

# Reading HOST and DB credentials from wp-config.php
HOSTNAME=`cat wp-config.php | grep WP_HOME | cut -d \' -f 4 | awk -F/ '{print $3}'`
DB_NAME=`cat wp-config.php | grep DB_NAME | cut -d \' -f 4`
DB_USER=`cat wp-config.php | grep DB_USER | cut -d \' -f 4`
DB_PASS=`cat wp-config.php | grep DB_PASSWORD | cut -d \' -f 4`
YA_USER=`cat wp-config.php | grep YA_USER | cut -d \' -f 4`
YA_PASS=`cat wp-config.php | grep YA_PASS | cut -d \' -f 4`
YA_FILES_FOLDER=`cat wp-config.php | grep YA_FILES_FOLDER | cut -d \' -f 4`
YA_DB_FOLDER=`cat wp-config.php | grep YA_DB_FOLDER | cut -d \' -f 4`

# Creating tmp backup folder structure, if not exists
mkdir -p backups/$YA_FILES_FOLDER
mkdir -p backups/$YA_DB_FOLDER

# Checking, if all credentials are correct
if [ -z "$YA_USER" ] || [ -z "$YA_PASS" ] || [ -z "$YA_FILES_FOLDER" ] || [ -z "$YA_DB_FOLDER" ]; then
	printf "Please fill Yandex data (YA_USER, YA_PASS, YA_FILES_FOLDER and YA_DB_FOLDER) in your wp-config.php";
	exit
fi

if [ -z "$HOSTNAME" ]; then
	if [ -z "$SITENAME" ]; 	then
		printf "Please, define WP_HOME variable in your wp-config.php OR fill SITENAME variable in your backup script";
		exit;
	fi
else
	SITENAME=$HOSTNAME
fi

# Creating current week folder structure
curl --user $YA_USER:$YA_PASS -X MKCOL https://webdav.yandex.ru/$SITENAME/
curl --user $YA_USER:$YA_PASS -X MKCOL https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/
curl --user $YA_USER:$YA_PASS -X MKCOL https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_FILES_FOLDER
curl --user $YA_USER:$YA_PASS -X MKCOL https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_DB_FOLDER

cd $ROOT_DIR;

for n in $@
do
    # Backing up database
	if [ $n = "db" ]; then
		printf "Backup database starts\n"
		cd $ROOT_DIR;
		cd backups/db/

		mysqldump "-u"$DB_USER "-p"$DB_PASS $DB_NAME > dump.sql
		printf "Dump created\n"
		tar -czf  $BACKUP_FILE".db.tar.gz" dump.sql
		printf "Dump archived\n"
		rm dump.sql
		printf "Unarchived dump deleted\n"
		curl --progress-bar --connect-timeout 45 --retry 15 --retry-delay 30 --retry-max-time 40 --user $YA_USER:$YA_PASS -T $BACKUP_FILE".db.tar.gz" https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_DB_FOLDER/ | tee /dev/null
		curl --progress-bar --connect-timeout 45 --retry 15 --retry-delay 30 --retry-max-time 40 --user $YA_USER:$YA_PASS -T $BACKUP_FILE".db.tar.gz" https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_DB_FOLDER/backup.db.latest.tar.gz | tee /dev/null
		printf "Dump archive uploaded\n"
		rm $BACKUP_FILE".db.tar.gz"
		printf "Dump archive deleted\n"
	fi

    # Backing up uploads
	if [ $n = "files" ]; then
		cd $ROOT_DIR;

		printf "Backup files starts\n";
		todayfiles=$(find wp-content/uploads/ -type f -mtime 0 | while read LINE; do echo "$LINE" ; done | wc -l);

		if [ $todayfiles -gt 0 ]; then
			printf "Found $todayfiles file(s). Archive the files\n";
			find wp-content/uploads/ -type f -mtime 0 -exec tar -rf backups/files/$BACKUP_FILE".files.tar" "$file" {} \;
			printf "Files archived\n"
			gzip -9 backups/files/$BACKUP_FILE".files.tar"
			printf "Files gziped\n"
			curl --progress-bar --connect-timeout 45 --retry 15 --retry-delay 30 --retry-max-time 40 --user $YA_USER:$YA_PASS -T backups/files/$BACKUP_FILE".files.tar.gz" https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_FILES_FOLDER/ | tee /dev/null
			printf "Files uploaded to backup server\n"
			rm backups/files/$BACKUP_FILE".files.tar.gz"
			printf "Old files backup deleted\n"
		fi
	fi

    # Backing up whole uploads directory and removing previous data
    if [ $n = "fullbackup" ]; then
		printf "Full file backup starts\n"
        cd $ROOT_DIR
        
        printf "Archive the wp-conten/uploads directory\n"
		tar -czf backups/backup.files.full.tar.gz wp-content/uploads
		printf "Directory archived\n"

		printf "Uploading archive to the backup server\n"
		curl --progress-bar --connect-timeout 45 --retry 15 --retry-delay 30 --retry-max-time 40 --user $YA_USER:$YA_PASS -T backups/backup.files.full.tar.gz https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_FILES_FOLDER/ | tee /dev/null
		printf "Archive uploaded\n"
		rm backups/backup.files.full.tar.gz
    fi

    # Restore files from backup
    if [ $n = "restorefiles" ]; then
		cd $ROOT_DIR;
		mkdir -p wp-content/uploads

		printf "Downloading full file backup\n"
		
		EXISTS=$(curl -s --user $YA_USER:$YA_PASS -X PROPFIND https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_FILES_FOLDER/backup.files.full.tar.gz | grep '<d:status>HTTP/1.1 200 OK</d:status>' | wc -l)
		if [ $EXISTS -eq 1 ]; then
			curl --progress-bar --user $YA_USER:$YA_PASS --basic https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_FILES_FOLDER/backup.files.full.tar.gz --output backups/backup.files.full.tar.gz | tee /dev/null

			printf "Extracting files from full file backup\n"
			tar xzf backups/backup.files.full.tar.gz -C $ROOT_DIR
			rm backups/backup.files.full.tar.gz
			printf "Files from full file backup extracted\n"

			printf "Downloading daily backups\n"
			for i in $(seq $WEEKBEGWOZERO $TODAYWOZERO); do
				if [ $TODAYWOZERO -gt 10 ]; then
					FILENAME=backup."$CURYEARMONTH"-"$i".files.tar.gz
				else
					FILENAME=backup."$CURYEARMONTH"-0"$i".files.tar.gz
				fi

				EXISTS=$(curl -s --user $YA_USER:$YA_PASS -X PROPFIND https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_FILES_FOLDER/$FILENAME | grep '<d:status>HTTP/1.1 200 OK</d:status>' | wc -l)
				if [ $EXISTS -eq 1 ]; then
					curl --progress-bar --user $YA_USER:$YA_PASS --basic https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_FILES_FOLDER/$FILENAME --output backups/$FILENAME | tee /dev/null
					printf "Extracting files from backup $FILENAME\n"
					tar xzf backups/$FILENAME
					rm backups/$FILENAME
					printf "Files from backup $FILENAME extracted\n"
				fi
			done
			printf "All files extracted\n"
		else
			printf "Full backup archive not found!\n"
		fi
	fi
	
    # Restore db from backup
    if [ $n = "restoredb" ]; then

		# Checking, if dump file exists on backup server
		EXISTS=$(curl -s --user $YA_USER:$YA_PASS -X PROPFIND https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_DB_FOLDER/backup.db.latest.tar.gz | grep '<d:status>HTTP/1.1 200 OK</d:status>' | wc -l)

		if [ $EXISTS -eq 1 ]; then
			printf "Downloading database dump archive\n"
			curl --progress-bar --user $YA_USER:$YA_PASS --basic https://webdav.yandex.ru/$SITENAME/$WEEKBEG'-'$WEEKEND/$YA_DB_FOLDER/backup.db.latest.tar.gz --output backups/db/backup.db.latest.tar.gz | tee /dev/null
			printf "Database dump downloaded\n"

			printf "Extracting dump from archive\n"
			tar xzf backups/db/backup.db.latest.tar.gz -C backups/db/
			rm backups/db/backup.db.latest.tar.gz
			printf "Database dump extracted\n"
			cd $ROOT_DIR;
			cd backups/db

			read -p "Dump current database before import (just in case)? [y,n]: " dumpcurrent
			case $dumpcurrent in  
			  y|Y) mysqldump "-u"$DB_USER "-p"$DB_PASS $DB_NAME > "backup.sql";;
			esac
			
			printf "Importing data from the last dump\n"
			mysql "-u"$DB_USER "-p"$DB_PASS -e "DROP DATABASE "$DB_NAME"; CREATE DATABASE "$DB_NAME
			mysql "-u"$DB_USER "-p"$DB_PASS $DB_NAME < "dump.sql"
			printf "Data from the last dump imported.\n"
			rm dump.sql

			if [ $dumpcurrent = "y" ] || [ $dumpcurrent = "Y" ]; then
				read -p "Delete database file, dumped before? [y,n]: " deletecurrent
				case $deletecurrent in  
				  y|Y) rm backup.sql; printf "Current dump deleted\n" ;; 
				esac
			fi

			printf "Dump imported to database\n"
		else
			printf "Database dump not found!\n"
		fi
    fi

    # Remove expired backups from server
    if [ $n = "clearexpired" ]; then
		EXISTS=$(curl -s --user $YA_USER:$YA_PASS -X PROPFIND https://webdav.yandex.ru/$SITENAME/$WEEKBEGOFST'-'$WEEKENDOFST/ | grep '<d:status>HTTP/1.1 200 OK</d:status>' | wc -l)
		if [ $EXISTS -eq 1 ]; then
			printf "Removing expired archive on backup server ($WEEKBEGOFST-$WEEKENDOFST)\n"
			curl --user $YA_USER:$YA_PASS -X DELETE https://webdav.yandex.ru/$SITENAME/$WEEKBEGOFST'-'$WEEKENDOFST/
			printf "Expired archive deleted on backup server\n"
		fi
		printf "Full file backup ends\n"
	fi
done
