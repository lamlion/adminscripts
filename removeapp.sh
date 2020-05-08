#!/usr/bin/env bash
#
# by Siddharth Dushantha 2020
#
#
# Description
#  This script lets you delete a single app or a list of app with ease
#  through the commandline.
#

VERSION="2020.06.07"

LOG_FILE="/Library/Logs/removeapps.log"
BUNDLE_ID="$1"
APP_LIST=""

echo_log(){
    # Summery of this function:
    #  Basically the standard echo, but with date and time and it outputs
    #  the information to both STDOUT and into the LOG_FILE
    echo "[$(date '+%d-%m-%Y %H:%M:%S')] $1" | tee -a $LOG_FILE 
}


remove_app(){
    APP_PATH=$(mdfind kMDItemCFBundleIdentifier = "$BUNDLE_ID")
    APP_NAME=$(echo "$APP_PATH" | perl -n -e'/\/(?!.*\/)(.*)\.app/ && print $1')

    # Check if app exists
    if [ ! -z "$APP_PATH" ];then
        # Checking if the app is running because if it is we have to kill/quit it
        # before we can delete the app. If we delete the app while it is running
        # the user will encounter issues where the app freezes and cant quit it.
        if [ ! -z "$(pgrep "$APP_NAME")" ];then
            echo_log "$APP_NAME is running"
            echo_log "Killing $APP_NAME"
            killall "$APP_NAME"
            echo_log "$APP_NAME has been killed"
        fi

        echo_log "Removing $APP_PATH"
        rm -rf "$APP_PATH"
        echo_log "$APP_NAME has been removed"
    else
        echo_log "ERROR: No app was found with '$BUNDLE_ID' as a bundle identifier"

        # If you provided a APP_LIST then do not exit because we can just check
        # the next bundle identifier in the file, but you did not provide an
        # APP_LIST, which means you only want to delete one app, then exit
        # because there is nothing else to do.
        [ -z "$APP_LIST" ] && exit 1
    fi

}


usage(){
    printf "%s" "\
usage: badapps [--help] [--log-file \"FILE\"] [--app-list \"FILE\"] [--version]

optional arguments:
   -h, --help            show this help message and exit
   --log-file            use a custom log file (default:/Library/Logs/removeapps.log)
   --app-list            list of apps which contains bundle idenifiers
   --version             get the current version of this script
"
}


main(){
    # Check if the script is running as root because root is 
    # needed in order to delte the apps
    if [ "$EUID" -ne 0 ];then
        echo "Please run as root"
        exit 1
    fi

    echo_log "-- Starting up --"

    if [ ! -z "$APP_LIST" ];then
        echo_log "App list provided: $APP_LIST"

        # Loop over all the bundle IDs in the given file
        # and remove them
        while read -r BUNDLE_ID; do
            remove_app "$BUNDLE_ID"
        done < "$APP_LIST"

    elif [ ! -z "$BUNDLE_ID" ];then
        echo_log "Bundle ID provided: $BUNDLE_ID"
        remove_app "$BUNDLE_ID"

    else
        echo_log "ERROR: Please provide a bundle identifier or file with a list of bundle identifiers"
        exit 1
    fi
}

while [[ "$1" ]]; do
    case "$1" in
        "--app-list") APP_LIST="$2" ;;
        "--log-file") LOG_FILE="$2" ;;
        "--version") echo "$VERSION" && exit ;;
        "--help"|"-h") usage && exit ;;
        -*) echo "ERROR: '$1' is an invalid option. Use '--help' to see options" && exit 1
            ;;
    esac
    shift
done

main
