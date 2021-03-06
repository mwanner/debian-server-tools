#!/bin/bash
#
# Clean up an email list.
#
# VERSION       :0.4.0
# DATE          :2016-01-28
# AUTHOR        :Viktor Szépe <viktor@szepe.net>
# LICENSE       :The MIT License (MIT)
# URL           :https://github.com/szepeviktor/debian-server-tools
# BASH-VERSION  :4.2+
# DEPENDS       :apt-get install bind9-host netcat-traditional courier-mta
# LOCATION      :/usr/local/bin/mx-check.sh

# Watch job queue
#     watch -n1 'printf "%*s" $(cat $MKTEMP) | tr " " "_"'

# Assumed MTA user
MAIL_GROUP="daemon"

ORIG_LIST="$1"
EMAIL_REGEXP='\b[a-zA-Z0-9._-]\+@[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,8\}\b'
CLEAN_LIST="${ORIG_LIST}.0-clean.txt"
LINES_FAILED="${ORIG_LIST}.0-FAILED-lines.txt"
DOMAIN_LIST="${ORIG_LIST}.1-domains.txt"
SMTP_OK_LIST="${ORIG_LIST}.2-smtp-ok.txt"
IP_OK_LIST="${ORIG_LIST}.2-ip-ok.txt"
SMTP_FAIL_LIST="${ORIG_LIST}.2-FAILED-smtp.txt"
SMTP_DOUBLE_FAIL_LIST="${ORIG_LIST}.3-DBLFAILED-smtp.txt"

Die() {
    local RET="$1"
    shift
    echo -e "$*" 1>&2
    exit "$RET"
}

Progress() {
    echo -n "." 1>&2
}

Progress_failed() {
    echo -n "X" 1>&2
}

# Clean up list
Email_cleanup() {
    local LIST="$1"

    # Search, trim
    #   and convert domain part to lowercase
    LC_ALL=C grep -o "$EMAIL_REGEXP" "$LIST" \
        | LC_ALL=C sed -e 's;^\(.*\)@\(.*\)$;\1@\L\2;'

    # Failed lines
    LC_ALL=C grep -v "$EMAIL_REGEXP" "$LIST" | grep -v "^\s*$" 1>&2
}

# Converts address-per-line files to unique domain list.
Addr2dom() {
    local LIST="$1"

    cut -d "@" -f 2 "$LIST" \
        | sort | uniq
}

Smtp_probe() {
    local MX="$1"
    local -i SMTP_TIMEOUT="$2"
    #local -i SMTP_PID
    local FIFO="$(mktemp --dry-run)"

    mkfifo --mode 600 "$FIFO"

    # Background SMTP process
    echo -n | nc -w "$SMTP_TIMEOUT" "$MX" 25 1> "$FIFO" 2> /dev/null &
    #SMTP_PID="$!"

    # FIFO closes automatically

    if grep -q "^220 " < "$FIFO"; then
        # @TODO Why kill it? "nc -w 5"
        # Avoid default notification in non-interactive shell for SIGTERM
        #trap -- "" SIGTERM
        #kill -9 "$SMTP_PID" > /dev/null 2>&1
        #trap SIGTERM
        rm "$FIFO"
        return 0
    else
        # No valid answer from MX in 5 seconds
        rm "$FIFO"
        return 1
    fi
}

# Ping and SMTP-probe MX-s
Mx_test() {
    local DOMAIN="$1"
    local -i SMTP_TIMEOUT="${2:-5}"
    local RESULT="NO.mx"
    local MX
    local MX_IP
    local MXS

    # Ordered by preference number
    MXS="$(timeout 5 host -t MX "$DOMAIN" 2> /dev/null \
        | grep "is handled by" | sort -k 6 -n)"

    while read MX; do
        RESULT="FAIL.dns"

        [ -z "$MX" ] && continue

        # First IP address
        MX_IP="$(getent ahostsv4 "$MX" | sed -ne '0,/^\(\S\+\)\s\+RAW\b\s*/s//\1/p')"
        [ -z "$MX_IP" ] && continue

        # Already known working
        if [ -f "$IP_OK_LIST" ] && grep -qFx "$MX_IP" "$IP_OK_LIST"; then
            RESULT="OK.smtp"
            break
        fi

        # Ping
        RESULT="FAIL.ping"
        if ping -c 2 -w 3 "$MX_IP" > /dev/null 2>&1; then
            RESULT="OK.ping+FAIL.smtp"
        fi

        # Port
        #if nmap -n -Pn -oG - -p 25 "$MX_IP" | grep -qx "Host: .*Ports: 25/open/tcp//smtp///"
        #RESULT="OK.port+FAIL.smtp"

        # SMTP
        if Smtp_probe "$MX_IP" "$SMTP_TIMEOUT"; then
            # Return only the highest priority and working MX
            RESULT="OK.smtp"
            echo "$MX_IP" >> "$IP_OK_LIST"
            break
        fi
    done <<< "$(echo "$MXS" | grep -o '\S\+\.$')"

    if [ "$RESULT" != "OK.smtp" ]; then
        echo "$RESULT"
        return 1
    fi

    return 0
}

# Conduct the test and append result to logs
Conduct_mx_test() {
    local D="$1"

    if RESULT="$(Mx_test "$D")"; then
        Progress
        echo "$D" >> "$SMTP_OK_LIST"
    else
        Progress_failed
        echo "${D}:${RESULT}" >> "$SMTP_FAIL_LIST"
    fi
}

# Delete message without MX record from the mail queue
Cancel_mailq() {
    local FAILED="$1"
    local D
    local MAILQ="$(mktemp)"

    mailq -batch > "$MAILQ"

    # Find pending mails ID-s
    while read LINE; do
        D="${LINE%%:*}"
        grep "@${D};" "$MAILQ" | cut -d ";" -f 2,4 \
            | while read ID_USER; do
                sudo -u "${ID_USER#*;}" -g "$MAIL_GROUP" -- cancelmsg "${ID_USER%;*}"
            done
    done < "$FAILED"

    rm "$MAILQ"
}

# Don't run without `screen`
[ -n "$STY" ] || Die 99 "Must be running in screen."

# Empty list?
[ -s "$ORIG_LIST" ] || Die 10 "No addresses in the list."

# Clean up the list
[ -f "$CLEAN_LIST" ] || Email_cleanup "$ORIG_LIST" 1> "$CLEAN_LIST" 2> "$LINES_FAILED"
[ -s "$CLEAN_LIST" ] || Die 1 "No addresses in the list after cleanup."

# Extract unique domain names
[ -f "$DOMAIN_LIST" ] || Addr2dom "$CLEAN_LIST" > "$DOMAIN_LIST"
[ -s "$DOMAIN_LIST" ] || Die 2 "No addresses passed the cleanup."

# Test MX-s in batches of 50 (26% load on 1 core)
if ! [ -f "$SMTP_OK_LIST" ]; then
    JOBN="$(mktemp)"
    while read -r D; do
        Conduct_mx_test "$D" &
        jobs -p -r | wc -l > "$JOBN"
        while [ -z "$(cat "$JOBN")" ] || [ "$(cat "$JOBN")" -gt 50 ]; do
            sleep 1
            jobs -p -r | wc -l > "$JOBN"
        done
    done < "$DOMAIN_LIST"
    rm "$JOBN"
fi
[ -s "$SMTP_OK_LIST" ] || Die 3 "None of the MX-s are OK."

# Retest failed MX-s
if [ -s "$SMTP_FAIL_LIST" ]; then
    while read FAILED; do
        D="${FAILED%%:*}"
        #title: domain name echo -n "$(tput tsl)${D}$(tput fsl)"
        if RESULT="$(Mx_test "$D" 30)"; then
            Progress
            # Not failing this time
            echo "$D" >> "$SMTP_OK_LIST"
            ###sed -i -e "/^${D}:/d" "$SMTP_FAIL_LIST"
        else
            Progress_failed
            echo "$D" >> "$SMTP_DOUBLE_FAIL_LIST"
            # Remove addresses with two times failed domains
            sed -i -e "/@${D}$/d" "$CLEAN_LIST"
        fi
    done < "$SMTP_FAIL_LIST"

    [ "$(id --user)" == 0 ] && Cancel_mailq "$SMTP_FAIL_LIST"
fi

# New line
echo

# @TODO remember bad failed IP-s? , merge ok/failed results then separate
