#!/bin/bash
#############################################################################
#                 __  __  ___ ___          _                                #
#                |  \/  |/ __| _ ) __ _ __| |___  _ _ __                    #
#                | |\/| | (__| _ \/ _` / _| / / || | '_ \                   #
#                |_|  |_|\___|___/\__,_\__|_\_\\_,_| .__/                   #
#                            MINECRAFT BACKUP      |_|                      #
#############################################################################
# MCBackup - A tool to aid Minecraft server backups via bash command line.  #
# Copyright (C) 2012 GrimWorld                                              #
#                                                                           #
# This program is free software: you can redistribute it and/or modify      #
# it under the terms of the GNU General Public License as published by      #
# the Free Software Foundation, either version 3 of the License, or         #
# (at your option) any later version.                                       #
#                                                                           #
# This program is distributed in the hope that it will be useful,           #
# but WITHOUT ANY WARRANTY; without even the implied warranty of            #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             #
# GNU General Public License for more details.                              #
#                                                                           #
# You should have received a copy of the GNU General Public License         #
# along with this program. If not, see <http://www.gnu.org/licenses/>.      #
#                                                                           #
# Designed by CJ for GrimWorld.co                                           #
# 07/01/12 (v0.5) beta                                                      #
#############################################################################

## Default values for settings
ARCHIVE=true
COMPRESSION=false
RESTORE=false
HELP=false
LIST=false
QUIET=false
REMOVE=false

# User Variables!
BACKUP_PATH="/backups"
MINECRAFT_PATH="/minecraft"
WORLD_PREFIX="world"
SERVER_COMMAND=$(cat /minecraft/command.txt)
SCREEN_COMMAND="screen -x"
REMOVE_DAYS=7

BKP_FULL=true
BKP_WORLD=false
BKP_WORLDS=false
BKP_CFG=false
BKP_PLUGINS=false
BKP_DB=false

SHOW_MESSAGES=true

## Preamble
echo "==============================================="
echo "    __  __  ___ ___          _                 "
echo "   |  \/  |/ __| _ ) __ _ __| |___  _ _ __     "
echo "   | |\/| | (__| _ \/ _' / _| / / || | '_ \    "
echo "   |_|  |_|\___|___/\__,_\__|_\_\\_,_| .__/    "
echo "               MINECRAFT BACKUP      |_|       "
echo "-----------------------------------------------"
## Option decoding
for arg in $@
do
	case $arg in
		-a) ARCHIVE=true;;
		-f) BKP_FULL=true;;
		
		-c) BKP_CFG=true; BKP_FULL=false;;
		-d) ARCHIVE=false;;
		-l) LIST=true;;
		-m) SHOW_MESSAGES=false;;
		-p) BKP_PLUGINS=true; BKP_FULL=false;;
		-q) QUIET=true;;
		-r:*) RESTORE=$(echo $arg | awk -F":" '{print $2}');;
		-s) BKP_DB=true; BKP_FULL=false;;
		-w:*) BKP_WORLD=$(echo $arg | awk -F":" '{print $2}'); BKP_FULL=false;;
		-W) BKP_WORLDS=true; BKP_WORLD=false; BKP_FULL=false;;
		-x) REMOVE=true;;
		-z) COMPRESSION=true;;
		
		-h | ? | -r | -w | -*) HELP=true;;
	esac
done

#### MAIN PROGRAM ####
### Functions
## Utility functions
function end() {
	# Parameters: exit code
	# end works identical to exit, but displays a bottom divider in the process
	echo "==============================================="
	exit $1
}

function serverStart() {
	# Blank current line in case something is already typed
	$SCREEN_COMMAND -X stuff "$(printf '\r')"
	if $SHOW_MESSAGES; then
		$SCREEN_COMMAND -X stuff "say Initiating server backup - $(date -u +'%T GMT')$(printf '\r')"
	fi
	$SCREEN_COMMAND -X stuff "save-off$(printf '\r')"
	$SCREEN_COMMAND -X stuff "save-all$(printf '\r')"
}

function serverFinish() {
	# Parameters: exit code of backup commands
	# Blank current line in case something is already typed
	$SCREEN_COMMAND -X stuff "$(printf '\r')"
	if [ $1 == 0 ]; then cStatus="completed"; else cStatus="failed"; fi
	$SCREEN_COMMAND -X stuff "save-on$(printf '\r')"
	if $SHOW_MESSAGES; then
		$SCREEN_COMMAND -X stuff "say Server backup $cStatus - $(date -u +'%T GMT')$(printf '\r')"
	fi
}

function validateComponents() {
	# This is not necessary right now - will make later
	if [ $RESTORE == false ]; then
		echo ""
	else
		echo ""
	fi
}

function createName() {
	# Append date to backup name and trailing dash
	bkpName=$(date -u +%y%m%d)-
	# Append enabled options to end of filename
	if $ARCHIVE; then bkpName=$bkpName"a"; else bkpName=$bkpName"d"; fi
	if $COMPRESSION; then bkpName=$bkpName"z"; fi
	if $BKP_DB; then bkpName=$bkpName"s"; fi
	if $BKP_CFG; then bkpName=$bkpName"c"; fi
	if $BKP_PLUGINS; then bkpName=$bkpName"p"; fi
	if $BKP_WORLDS; then bkpName=$bkpName"W"; fi
	if $BKP_FULL; then bkpName=$bkpName"f"; fi
	if [ $BKP_WORLD != false ]; then bkpName=$bkpName"w:"$BKP_WORLD; fi
	
	# If file exists, append incrementing number to end
	bkpNameTmp=$bkpName
	i=1
	# While file exists, increment suffic number
	while [ -f $BACKUP_PATH/$bkpNameTmp.tar -o -f $BACKUP_PATH/$bkpNameTmp.tar.gz -o -d $BACKUP_PATH/$bkpNameTmp ];
	do
		bkpNameTmp=$bkpName-$i
		i=$[i+1]
	done
	# Append file extension and store result
	if $ARCHIVE; then bkpName=$bkpNameTmp.tar; fi
	if $COMPRESSION; then bkpName=$bkpName.gz; fi
	if ! $ARCHIVE; then bkpName=$bkpNameTmp/; fi
}

function configureOptions() {
	# Parameters: type: BACKUP or RESTORE
	confType=$1
	
	# Set the working directory
	# This is a crucial step for any 'find' commands to search for specific folders
	if [ $confType == 'BACKUP' ]; then
		cd $MINECRAFT_PATH
	else
		cd $MINECRAFT_PATH
		#cd $BACKUP_PATH/$rName
	fi
	if $ARCHIVE; then echo " +ARCHIVED"; else echo " +FOLDER"; fi
	if $COMPRESSION; then echo " +COMPRESSED"; fi
	if $BKP_CFG; then
		# Tell user what's being backed up
		echo " +CONFIG $confType"
		# Main directory, and everything in plugin directory only
		# Jars are not allowed to be backed up
		# Find matches within the directory cd'd to earlier, strip leading ./
		paths="$paths $(find . -maxdepth 1 -type f ! -iname '*.jar' | sed -e 's/\.\///')"
		paths="$paths $(find ./plugins -type f ! -iname '*.jar' | sed -e 's/\.\///')"
	fi
	if $BKP_DB; then
		echo " +MYSQL $confType"
		paths="$paths mysql"
	fi
	if $BKP_PLUGINS; then
		echo " +PLUGIN $confType"
		paths="$paths plugins"
	fi
	if [ $BKP_WORLD != false ]; then
		echo " +SINGLE WORLD: $BKP_WORLD"
		paths="$paths $BKP_WORLD"
	fi
	if $BKP_WORLDS; then
		echo " +ALL WORLDS"
		# Get all folders starting with world prefix in the pre-defined path
		# Remove unnecessary ./s with sed
		paths="$paths $(find . -maxdepth 1 -type d -name '$WORLD_PREFIX*' | sed -e 's/\.\///')"
	fi
	if $BKP_FULL; then
		echo " +FULL $confType"
		paths=" *"
	fi
}

## Non-executing functions such as help and list
function showHelp() {
	echo "Usage:"
	echo "mcbackup (-options)"
	echo "Default: Full backup to tar archive"
	echo "File names (IDs) are structured as: YYMMDD-OPTIONS(-NUM)"
	echo "All times are UTC/GMT"
	echo "   Option    |          Description            "
	echo "-------------|---------------------------------"
	echo "-a           | Write to archive/tar (default option)"
	echo "-c           | Backup/restore config files"
	echo "-d           | Backup as a folder rather than tar. Cannot use -z"
	echo "-f           | Make full backup (default option)"
	echo "-h           | Show this help page"
	echo "-l           | Show a list of backups and IDs"
	echo "-m           | Hide server 'say' messages"
	echo "-p           | Backup/restore plugins"
	echo "-q           | Do not prompt for confirmation"
	echo "-r:backupID  | Restore from specified backup (will prompt for confirmation)"
	echo "-s           | Backup SQL databases"
	echo "-w:worldName | Backup/restore single world"
	echo "-W           | Backup/restore all worlds"
	echo "-x           | Remove backups older than $REMOVE_DAYS days old"
	echo "-z           | G-Zip Compression"
}

function showList() {
	echo "---------------Available Backups---------------"
	echo "      BackupID      |         Date/Time        "
	echo "--------------------|--------------------------"
	# Get contents of backup folder
	# List all names (before '.') of entries starting with a number
	cd $BACKUP_PATH
	for file in $(dir -x -d *); do
		# Verify if it's a backup ID
		if [[ $file =~ ^[0-9]+- ]]; then
			# Take out part before .
			part=$(echo $file | awk -F"." '{print $1}')
			# Write output
			echo "$(printf '%-19s' $part) | $(date -u -r $file +'%b %d %Y %T GMT')"
		fi
	done
}

## Executing functions (the real stuff)
function createBkp() {
	# Generate an ID tag
	createName
	# Show the backup information
	echo "CREATING BACKUP $BACKUP_PATH/$bkpName"
	echo "FROM $MINECRAFT_PATH WITH OPTIONS"
	# Show option messages
	# Configure paths to backup
	paths=""
	configureOptions "BACKUP"
	# Prompt for continuation
	if ! $QUIET; then
		read -p "ARE YOU SURE YOU WANT TO BACKUP? (Y/N)>" yn
		if [[ ! $yn =~ ^[Yy]$ ]]; then
			echo "---------------BACKUP CANCELLED----------------"
			end 1
		fi
	fi

	# Validate the query
	validateComponents
	
	# Set commands
	if $ARCHIVE; then
		command="tar -cpv"
		if $COMPRESSION; then
			command=$command"z"
		fi
		# Paths starts with a space </protip>
		command=$command"C $MINECRAFT_PATH -f $BACKUP_PATH/$bkpName$paths"
		prep=""
	else
		prep="mkdir $BACKUP_PATH/$bkpName"
		# Make each path an absolute path. Currently, they are all relative
		for path in $paths; do
			path=$MINECRAFT_PATH/$path
		done
		command="cp -av --parents$paths $BACKUP_PATH/$bkpName"
	fi
	# Send server start commands
	serverStart
	
	# Do the work!
	#echo "DEBUG: $command"
	$prep # Extra command
	# Make output appear on single line
	#$command | cut -b1-$(tput cols) | sed -u 'i\\o033[2K' | tr '\n' '\r'; echo
	$command
	status=$?
	
	# Send server finish commands
	serverFinish $status
	
	# Complete
	if [ $status == 0 ]; then cStatus="COMPLETE"; else cStatus="FAILED"; fi
	echo "----------------BACKUP $cStatus----------------"
	# Delete old backups
	if $REMOVE; then
		echo "--------------DELETING OLD BACKUPS-------------"
		if ! $QUIET; then
			echo "ARE YOU SURE YOU WANT TO REMOVE BACKUPS"
			read -p "OLDER THAN $REMOVE_DAYS DAYS? (Y/N)>" yn
			if [[ ! $yn =~ ^[Yy]$ ]]; then
				echo "---------------DELETING CANCELLED--------------"
				end $status
			fi
		fi
		# Remove all files older than $REMOVE_DAYS
		# Get date
		date=$(date -u +%y%m%d)
		date=$(($date-$REMOVE_DAYS))
		cd $BACKUP_PATH
		# Get all backup files
		for file in $(dir -d *); do
			# Verify if it's a backup ID
			if [[ $file =~ ^[0-9]+- ]]; then
				# Take out part before -
				part=$(echo $file | awk -F"-" '{print $1}')
				# Verify age
				if [ $date -gt $part ]; then
					# Remove
					rm -r $file
				fi
			fi
		done
		echo "----------------------DONE---------------------"
	fi
	end $status
}

function restoreBkp() {
	# Set actual filename of backup
	rName=false
	if [ -f $BACKUP_PATH/$RESTORE.tar ]; then
		rName=$RESTORE.tar
		ARCHIVE=true
	fi
	if [ -f $BACKUP_PATH/$RESTORE.tar.gz ]; then
		rName=$RESTORE.tar.gz
		COMPRESSION=true
	fi
	if [ -d $BACKUP_PATH/$RESTORE ]; then
		rName=$RESTORE/
		ARCHIVE=false
	fi
	# If the filename isn't set, it doesn't exist
	if [ $rName == false ]; then
		echo "FILE DOES NOT EXIST"
		showList
		end 1
	fi
	# Display restore information
	bkpDate=$(date -u -r $BACKUP_PATH/$rName +"%b %d %Y %T GMT")
	echo "RESTORING BACKUP $BACKUP_PATH/$rName"
	echo "MODIFIED $bkpDate"
	echo "TO $MINECRAFT_PATH WITH OPTIONS"
	# Show option messages
	# Configure paths to backup
	paths=""
	configureOptions "RESTORE"
	# Prompt for continuation
	if ! $QUIET; then
		read -p "ARE YOU SURE YOU WANT TO RESTORE? (Y/N)>" yn
		if [[ ! $yn =~ ^[Yy]$ ]]; then
			echo "---------------RESTORE CANCELLED----------------"
			end 1
		fi
	fi
	
	# Set commands
	if $ARCHIVE; then
		command="tar -xpv"
		if $COMPRESSION; then
			command=$command"z"
		fi
		# Paths starts with a space </protip>
		command=$command"C $MINECRAFT_PATH -f $BACKUP_PATH/$rName$paths"
		prep=""
	else
		# Make each path an absolute path. Currently, they are all relative
		for path in $paths; do
			path=$BACKUP_PATH/$rName/$path
		done
		command="cp -afv --parents$paths $MINECRAFT_PATH"
	fi
	
	# Shut down server for maintenance
	if $SHOW_MESSAGES; then
		$SCREEN_COMMAND -X stuff "say Rolling back to: $(date -u -r $rName +'%b %d %Y %T GMT')$(printf '\r')"
		$SCREEN_COMMAND -X stuff "say 30 seconds remaining - please log out$(printf '\r')"
		echo "RESTORE IN 30 SECONDS (Ctrl+C to cancel)"
		sleep 10
		$SCREEN_COMMAND -X stuff "say 20 seconds remaining - please log out$(printf '\r')"
		echo "RESTORE IN 20 SECONDS"
		sleep 10
		$SCREEN_COMMAND -X stuff "say 10 seconds remaining - please log out$(printf '\r')"
		echo "RESTORE IN 10 SECONDS"
		sleep 10
	fi
	# Service stop
	service minecraft stop
	# Normal stop
	$SCREEN_COMMAND -X stuff "stop$(printf '\r')"
	
	# Do the work!
	#echo "DEBUG: $command"
	$command
	status=$?
	
	# Restart server
	# Service start
	service minecraft start
	# Normal start
	#$SERVER_COMMAND
	
	# Complete
	if [ $status == 0 ]; then cStatus="COMPLETE"; else cStatus="FAILED"; fi
	echo  "----------------RESTORE $cStatus----------------"
	end $status
}

## Main program loop
if $HELP; then
	showHelp
	end 1
fi
if $LIST; then
	showList
	end 0
fi
if [ $RESTORE == false ]; then
	createBkp
else
	restoreBkp
fi
end 1