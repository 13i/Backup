#!/bin/bash

TODAY=`date +%Y-%m-%d`

# Delete the oldest file in directory $1 if number of files is bigger than $2
function deleteOldestFile {
	FILE_COUNT=$(($2 + 1))
	while [ `ls $1 | wc -l` -ge $FILE_COUNT ]; do
		FILE=`ls $1 | sort -n | head -1`
		rm -f $1/$FILE
	done
}

echo "Backup task launched"
echo "===================="

echo "Reading configuration file..."
if [ ! -f ./backup.cfg ]; then
	echo "Backup config file does not exists, please create backup.cfg"
	exit
fi

source "./backup.cfg"

DAILY_BACKUP_DIR="$BACKUP_DIR/daily"
WEEKLY_BACKUP_DIR="$BACKUP_DIR/weekly"
MONTHLY_BACKUP_DIR="$BACKUP_DIR/monthly"

echo "Files Dir			$FILES_DIR"
echo "Backup Dir		$BACKUP_DIR"
echo "DB Host			$DB_HOST"
echo "DB Name			$DB_NAME"
echo "DB User			$DB_USER"
echo "DB Password		****"

echo "Checking folders defined in config existance..."
if [ ! -d $BACKUP_DIR ]; then
	echo "Backup directory does not exists : $BACKUP_DIR"
	exit
fi
if [ ! -d $FILES_DIR ]; then
	echo "Files directory does not exists : $FILES_DIR"
	exit
fi

echo "Checking backup folders existance..."
for dir in $DAILY_BACKUP_DIR $WEEKLY_BACKUP_DIR $MONTHLY_BACKUP_DIR
do
	if [ ! -d $dir ]; then
		echo "$dir created"
	    mkdir -p $dir
	fi
done

echo "Archiving files..."
cd $FILES_DIR
tar cf $DAILY_BACKUP_DIR/$TODAY.tar *

echo "Dumping database..."
cd $DAILY_BACKUP_DIR
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME > database.sql

echo "Adding database dump to files archive..."
tar rvf $TODAY.tar database.sql
rm -f database.sql

echo "Zipping archive..."
gzip -f $TODAY.tar

echo "Rotating backups..."
deleteOldestFile $DAILY_BACKUP_DIR $DAILY_BACKUP_NUMBER

if [ `date +%a` == "Mon" ]; then
	cp $TODAY.tar.gz $WEEKLY_BACKUP_DIR/$TODAY.tar.gz
	deleteOldestFile $WEEKLY_BACKUP_DIR $WEEKLY_BACKUP_NUMBER
fi

if [ `date +%d` = "01" ]; then
	cp $TODAY.tar.gz $MONTHLY_BACKUP_DIR/$TODAY.tar.gz
	deleteOldestFile $MONTHLY_BACKUP_DIR $MONTHLY_BACKUP_NUMBER
fi

echo "Backup successful ;)"

