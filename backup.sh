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

# Notify of backup launch
msg "Backup task launched"
msg "===================="

# Read config file
CONFIG_FILE="$DIR/backup.cfg"
msg "Reading configuration file..."
if [ ! -f $CONFIG_FILE ]; then
	error "Backup config file does not exists, please create $CONFIG_FILE"
	exit
fi
source $CONFIG_FILE

# Configure backup directories
msg "Backup Dir			$BACKUP_DIR"
DAILY_BACKUP_DIR="$BACKUP_DIR/daily"
WEEKLY_BACKUP_DIR="$BACKUP_DIR/weekly"
MONTHLY_BACKUP_DIR="$BACKUP_DIR/monthly"

# List directories to backup
for i in "${FILES_DIR[@]}"
do
	msg "Files Dir			$i"
done

# Create backup dir if it does not exist
msg "Checking folders defined in config existance..."
mkdirIfNoExists $BACKUP_DIR
mkdirIfNoExists $FILES_DIR

# Create daily/weekly/monthly backup dirs if they do not exist
msg "Checking backup folders existance..."
for dir in $DAILY_BACKUP_DIR $WEEKLY_BACKUP_DIR $MONTHLY_BACKUP_DIR
do
	mkdirIfNoExists $dir
done

# Create the archive
msg "Archiving files..."
FOLDERS=""
for FOLDER_NAME in "${FILES_DIR[@]}"
do
	FOLDERS+="$FOLDER_NAME "
done
tar -cf $DAILY_BACKUP_DIR/$TODAY.tar $FOLDERS


# Dump databases and add them to the archive
cd $DAILY_BACKUP_DIR
for dbconfig in "${DBS[@]}"
do
	PARTS=(${dbconfig//|/ })
	msg "DB Host			${PARTS[0]}"
	msg "DB User			${PARTS[1]}"
	msg "DB Password		###"
	DB_NAMES=(${PARTS[3]//,/ })
	for dbname in "${DB_NAMES[@]}"
	do
		msg "DB Name			$dbname"
		msg "Dumping database..."
		mysqldump -h ${PARTS[0]} -u ${PARTS[1]} -p${PARTS[2]} $dbname > $dbname.sql
		msg "Adding $dbname database dump to files archive..."
		tar rf "$TODAY.tar" $dbname.sql
		rm -f $dbname.sql
	done
done

# Compress the archive
msg "Zipping archive..."
gzip -f $TODAY.tar

# Rotate backups
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

msg "Backup successful ;)"


