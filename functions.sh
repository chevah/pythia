#!/usr/bin/env bash
#
# Shared code for all binary-dist scripts.
#

# Check if debugging environment variable is set and initialize with 0 if not.
if [ -z "$DEBUG" ] ; then
    DEBUG=0
fi

help_text_help=\
"Show help for a command."
command_help() {
    local command=$1
    local help_command="help_$command"
    # Test for a valid help method, otherwise call general help.
    type $help_command &> /dev/null
    if [ $? -eq 0 ]; then
        $help_command
    else
        echo "Available commands are:"
        for help_text in `compgen -A variable help_text_`
        do
            command_name=${help_text#help_text_}
            echo -e "    $command_name\t${!help_text}"
        done
    fi
}

#
# Main command selection.
#
# Select fuctions which are made public.
#
select_command() {
    local command=$1
    shift
    case $command in
        "")
            command_help
            exit 99
            ;;
        *)
            # Test for a valid command, otherwise call general help.
            call_command="command_$command"
            type $call_command &> /dev/null
            if [ $? -eq 0 ]; then
                $call_command $@
            else
                command_help
                echo ""
                (>&2 echo "Unknown command: ${command}.")
                exit 98
            fi
        ;;
    esac
}


exit_on_error() {
    error_code=$1
    exit_code=$2
    if [ $error_code -ne 0 ]; then
        exit $exit_code
    fi
}


execute() {
    if [ $DEBUG -ne 0 ]; then
        echo "        Executing:" $@
    fi

    #Make sure $@ is called in quotes as otherwise it will not work.
    "$@"
    exit_code=$?
    if [ $DEBUG -ne 0 ]; then
        echo "        Exit code was: $exit_code"
    fi
    if [ $exit_code -ne 0 ]; then
        echo "PWD :" $(pwd)
        (>&2 echo "Fail:" $@)
        exit 97
    fi
}
