#!/bin/bash

# Today's date
TODAY=`date +%Y-%m-%d`

# Current backup.sh dir
# http://stackoverflow.com/a/246128
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do 
	SOURCE="$(readlink "$SOURCE")"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
	DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Delete the oldest file in directory $1 if number of files is bigger than $2
function deleteOldestFile {
	FILE_COUNT=$(($2 + 1))
	while [ `ls $1 | wc -l` -ge $FILE_COUNT ]; do
		FILE=`ls $1 | sort -n | head -1`
		rm -f $1/$FILE
	done
}

# Print a message if $DEBUG > 0
function msg {
	if $DEBUG; then
		echo $1
	fi
}

# Prints an error and exits
function error {
	echo $1
	exit
}

# Create a dir if it doesn't exists
function mkdirIfNoExists {
	if [ ! -d $1 ]; then
	   	msg "$1 does not exists"
	    if mkdir $1; then
	    	msg "$1 created"
	    else
	    	msg "$1 can not be created"
	    	exit
	    fi
	else
		msg "$1 exists"
	fi
}

echo "Backup task launched"
echo "===================="

CONFIG_FILE="$DIR/backup.cfg"
msg "Reading configuration file..."
if [ ! -f $CONFIG_FILE ]; then
	error "Backup config file does not exists, please create $CONFIG_FILE"
	exit
fi

source $CONFIG_FILE

DAILY_BACKUP_DIR="$BACKUP_DIR/daily"
WEEKLY_BACKUP_DIR="$BACKUP_DIR/weekly"
MONTHLY_BACKUP_DIR="$BACKUP_DIR/monthly"

for i in "${FILES_DIR[@]}"
do
	msg "Files Dir			$i"
done
msg "Backup Dir			$BACKUP_DIR"
msg "DB Host			$DB_HOST"
for i in "${DB_NAME[@]}"
do
	msg "DB Name			$i"
done
msg "DB User			$DB_USER"
msg "DB Password		####"

msg "Checking folders defined in config existance..."
mkdirIfNoExists $BACKUP_DIR
mkdirIfNoExists $FILES_DIR

msg "Checking backup folders existance..."
for dir in $DAILY_BACKUP_DIR $WEEKLY_BACKUP_DIR $MONTHLY_BACKUP_DIR
do
	mkdirIfNoExists $dir
done

msg "Archiving files..."
FOLDERS=""
for FOLDER_NAME in "${FILES_DIR[@]}"
do
	FOLDERS+="$FOLDER_NAME "
done
tar -cf $DAILY_BACKUP_DIR/$TODAY.tar $FOLDERS

msg "Dumping database..."
cd $DAILY_BACKUP_DIR
for i in "${DB_NAME[@]}"
do
	mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $i > $i.sql
	msg "Adding $i database dump to files archive..."
	tar rf "$TODAY.tar" $i.sql
	rm -f $i.sql
done

msg "Zipping archive..."
gzip -f $TODAY.tar

msg "Rotating backups..."
deleteOldestFile $DAILY_BACKUP_DIR $DAILY_BACKUP_NUMBER

if [ `date +%a` = "Mon" ]; then
	cp $TODAY.tar.gz $WEEKLY_BACKUP_DIR/$TODAY.tar.gz
	deleteOldestFile $WEEKLY_BACKUP_DIR $WEEKLY_BACKUP_NUMBER
fi

if [ `date +%d` = "01" ]; then
	cp $TODAY.tar.gz $MONTHLY_BACKUP_DIR/$TODAY.tar.gz
	deleteOldestFile $MONTHLY_BACKUP_DIR $MONTHLY_BACKUP_NUMBER
fi

echo "Backup successful ;)"


