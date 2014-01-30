#!/bin/sh ******************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    stalker.sh                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: jlejeune <jlejeune@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2014/01/27 18:04:46 by jlejeune          #+#    #+#              #
#    Updated: 2014/01/30 08:01:16 by jlejeune         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Global variables
correction_uid_regex="s/^.*Sujet [A-Za-z0-9_-]+ (.*)<\/a>.*$/\1/p"
corrector_uid_regex="s/^.*par <a.*>(.*)<\/a>.*$/\1/p"

# Gets informations on people by ids
# returns : No return

stalk_people ()
{
	info "-> Reading ids..."
	echo "-> Enter the ids you want to stalk (separate ids by a space) :"
	echo "-> \c"
	read ids
	while [ -z "${ids}" ]
	do
		error "-> Have you ever seen someone with no id ? O_O"
		echo "-> Enter the ids you want to stalk (separate ids by a space) :"
		echo "-> \c"
		read ids
	done
	echo "-> Connecting to dashboard."
	connect_to_dashboard
	if [ ${?} == 1 ]
	then
		stalk_uids "${ids}"
	fi
}

# Searches informations on the passed uids
# $1 : Uid list (separated by a space)
# returns : No return

stalk_uids ()
{
	if [ -z "${1}" ]
	then
		echo "usage: stalk_uids \"uid list\""
		return
	fi
	info "-> Getting informations on the users."
	for id in ${1}
	do
		url="https://dashboard.42.fr/user/profile/${id}/"
		info "-> Sending request..."
		content=`curl -sL -b "${dashboard_cookies}" "${url}"`
		if echo "${content}" | grep -q "UID"
		then
			info "-> Getting mobile phone..."
			regex="s/^.*<dt>Mobile<\/dt>[[:blank:]]+<dd>([0-9\ _+-]+)<\/dd>.*$/\1/p"
				mobile=`echo "${content}" | tr -d '\n' | sed -nE "${regex}"`
			if [ ! -z "${mobile}" ]
			then
				info "-> Mobile phone found."
				mobile=`echo "${mobile}" | tr -d ' ' | sed 's/+33/0/g' | sed 's/.\{2\}/& /g'`
			else
				info "-> Cannot find mobile phone."
				mobile="not found"
			fi
			info "-> Getting location..."
			regex="s/^.*<dt>Latest location<\/dt>[[:blank:]]+<dd>(e[[:digit:]]+r[[:digit:]]+p[[:digit:]]+)\.42\.fr.*<\/dd>.*$/\1/p"
			location=`echo "${content}" | tr -d '\n' | sed -nE "${regex}"`
			if [ -z "${location}" ]
			then
				info "-> Cannot find location."
				location="offline"
			fi
			info "-> Displaying informations..."
			printf "%12s : %s (%s)\n" "${id}" "${mobile}" "${location}"
		else
			printf "%12s : " "${id}"
			echo "\033[31merror\033[0m"
		fi
	done
}

# Gets phone numbers of corrections
# returns : No return

get_corrections_numbers ()
{
	get_numbers "${corrections_regex}" "${correction_uid_regex}"
}

# Gets phone numbers of correctors
# returns : No return

get_correctors_numbers ()
{
	get_numbers "${correctors_regex}" "${corrector_uid_regex}"
}

# Gets phone numbers
# $1 : Regular expression to discern projects
# $2 : Regular expression to get uids from source code line
# returns : No return

get_numbers ()
{
	if [ -z "${1}" ] || [ -z "${2}" ]
	then
		echo "usage: get_numbers \"projects regex\" \"source lines regex\""
	fi
	echo "-> Connecting to intranet."
	connect_to_intra
	intra=${?}
	echo "-> Connecting to dashboard."
	connect_to_dashboard
	dashboard=${?}
	if [ ${intra} == 1 ] && [ ${dashboard} == 1 ]
	then
		info "-> Loading intranet index page."
		content=`curl -sL -b "${intranet_cookies}" "https://intra.42.fr"`
		info "-> Reading page source..."
		block=0;
		uids=""
		while read -r line
		do
			project=`echo "${line}" | sed -nE "${1}"`
			if [ ${block} == 0 ] && [ ! -z "${project}" ]
			then
				echo "\n-> ${project}"
				block=`expr ${block} + 1`
			fi
			if [ ${block} == 1 ] && echo "${line}" | grep -q "<ul>"
			then
				block=`expr ${block} + 1`
			fi
			if [ ${block} == 2 ]
			then
				if echo "${line}" | grep -q "</ul>"
				then
					block=0
					stalk_uids "${uids}"
					uids=""
				fi
				if echo "${line}" | grep -q "devez"
				then
					uid=`echo "${line}" | sed -nE "${2}"`
					if [ ! -z "${uid}" ]
					then
						if [ -z "${uids}" ]
						then
							uids="${uid}"
						else
							uids="${uids} ${uid}"
						fi
					fi
				fi
			fi
		done <<< "${content}"
	fi
}
