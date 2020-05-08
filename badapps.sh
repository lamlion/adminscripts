#!/usr/bin/env bash
#
# by Siddharth Dushantha 2020
#
# Description
#  If you are a school IT admin, you have probably told your students not use
#  certain apps (e.g. VPN and Torrenting apps), but of course they install them
#  anyways.
# 
#  With this script, you can feed it a file with a list of bundle identifiers
#  of the app that you dont allow and it will delete it off the student's
#  computer with ease. 
#
#  Dont have the bundle identifier of the app?
#   No problem! Just use the '--get-id' option and either give it the name
#   of the app or the path to the app.

VERSION="2020.05.07"

# Default variables
APP_LIST="badappslist.txt"
LOG_FILE="/Library/Logs/badapps.log"

echo_log(){
    # Summery of this function:
    #  Basically the standard echo, but with date and time and it outputs
    #  the information to both STDOUT and into the LOG_FILE
    echo "[$(date '+%d-%m-%Y %H:%M:%S')] $1" | tee -a $LOG_FILE 
}


delete_bad_apps(){
    # Summery of this function:
    #  This function goes through the list of bundle IDs from APP_LIST
    #  and checks if they are installed. If they are, those apps will get
    #  deleted.

    # Check if the script is running as root because root is 
    # needed in order to delte the apps
    if [ "$EUID" -ne 0 ];then
        echo "Please run as root"
        exit 1
    fi

    echo_log "-- Starting up --"

    if [ ! -f "$LOG_FILE" ];then
        echo_log "ERROR: Cannot find '$LOG_FILE'. Using default: /Library/Logs/badapps.log"
        LOG_FILE="/Library/Logs/badapps.log"
    fi
    echo_log "Log file: $LOG_FILE"

    echo_log "App list: $APP_LIST"
    if [ ! -f "$APP_LIST" ];then
         echo_log "ERROR: Cannot find '$APP_LIST'. Exiting..."
         exit 1
    fi

    # Loop over the bundle IDs in the APP_LIST file
    while read -r BUNDLE_ID; do
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
        fi
    done < "$APP_LIST"
}

usage(){
    printf "%s" "\
usage: badapps [--help] [--get-id \"PATH or APP NAME\"] [--log-file \"FILE\"]
                   [--app-list \"FILE\"] [--version]

optional arguments:
   -h, --help            show this help message and exit
   --get-id              get the bundle identifier of an app (path to app OR app name)
   --log-file            use a custom log file (default:/Library/Logs/badapps.log)
   --app-list            use custom list of app which contains bundle idenifiers (default: badappslist.txt)
   --version             get the current version of this script
"
}

get_bundle_id(){
    # Summery of this function
    #  This function allows you to extract the bundle identifier of apps.
    #  You can either give it the path to an app or just the app name.
    #  
    #  This function is useful if you are creating list of bundle identifiers which you
    #  will then later use to remove from the user's computer with this script

    # If the given argument is a path
    if [ -d "$1" ];then
        DIRECTORY="$1"
        BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$DIRECTORY/Contents/Info.plist" 2>/dev/null)
        
        # This get the exit status of the previous command
        STATUS=$?
        [ "$STATUS" -gt 0 ] && echo "ERROR: '$DIRECTORY' is not a proper directory for an app" && exit 1
        echo "$BUNDLE_ID"

    else
        # assuming that the given argument might be just the name of
        # the app (e.g. Finder)
        APP_NAME="$1"
        BUNDLE_ID=$(osascript -e "id of app \"$APP_NAME\"" 2>/dev/null)

        # This get the exit status of the previous command
        STATUS=$?
        [ "$STATUS" -gt 0 ] && echo "ERROR: The app '$APP_NAME' does not exist" && exit 1
        echo "$BUNDLE_ID"

    fi
}


while [[ "$1" ]]; do
    case "$1" in
        "--get-id") get_bundle_id "$2" && exit;;
        "--app-list") APP_LIST="$2" ;;
        "--log-file") LOG_FILE="$2" ;;
        "--version") echo "$VERSION" && exit ;;
        "--help"|"-h") usage && exit ;;
        -*) echo "ERROR: '$1' is an invalid option. Use '--help' to see options" && exit 1
            ;;
    esac
    shift
done

delete_bad_apps
