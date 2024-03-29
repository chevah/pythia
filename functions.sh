#!/usr/bin/env bash
#
# Shared code for all binary-dist scripts.
#

# Check if debugging environment variable is set and initialize with 0 if not.
DEBUG="${DEBUG-0}"

# shellcheck disable=SC2034 # Only used through compgen.
help_text_help="Show help for a command."
command_help() {
    local command="${1:-}"
    local help_command="help_$command"
    # Test for a valid help method, otherwise call general help.
    set +o errexit
    if type "$help_command" &> /dev/null; then
        "$help_command"
    else
        echo "Available commands are:"
        for help_text in $(compgen -A variable help_text_); do
            command_name="${help_text#help_text_}"
            echo -e "    $command_name\t${!help_text}"
        done
    fi
    set -o errexit
}

#
# Main command selection.
#
# Select functions which are made public.
#
select_command() {
    local command="${1:-}"
    case "$command" in
        "")
            command_help
            exit 99
            ;;
        *)
            shift
            # Test for a valid command, otherwise call general help.
            call_command="command_$command"
            set +o errexit
            if type "$call_command" &> /dev/null; then
                "$call_command" "$@"
            else
                command_help
                (>&2 echo -e "\nUnknown command: $command.")
                exit 98
            fi
            set -o errexit
            ;;
    esac
}


exit_on_error() {
    error_code="$1"
    exit_code="$2"
    if [ "$error_code" -ne 0 ]; then
        exit "$exit_code"
    fi
}


execute() {
    if [ "$DEBUG" -ne 0 ]; then
        (>&2 echo -e "\tExecuting:" "$@")
    fi

    #Make sure $@ is called in quotes as otherwise it will not work.
    "$@"
    exit_code="$?"
    if [ "$DEBUG" -ne 0 ]; then
        (>&2 echo -e "\tExit code was: $exit_code")
    fi
    if [ "$exit_code" -ne 0 ]; then
        (>&2 echo "PWD :" "$(pwd)")
        (>&2 echo "Fail:" "$@")
        exit 97
    fi
}
