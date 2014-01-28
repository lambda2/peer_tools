#!/bin/sh ******************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    credentials.sh                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: jlejeune <jlejeune@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2014/01/27 15:31:33 by jlejeune          #+#    #+#              #
#    Updated: 2014/01/28 15:16:25 by jlejeune         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Global variables
config_path="${script_path}/config"
credentials_file="${config_path}/credentials"
login=""
login_encoded=""
password=""
password_encoded=""

# Asks user for credentials
# $1 : Credentials file
# returns : No return

ask_credentials ()
{
	if [ -z "${1}" ]
	then
		echo "usage: ask_credentials \"credentials file\""
		return
	fi
	echo "-> Enter your login : \c"
	read login
	while [ "${login}" = "" ]
	do
		error "-> Login cannot be blank."
		echo "-> Enter your login : \c"
		read login
	done
	echo "-> Enter your password : \c"
	read -s password
	echo
	while [ "${password}" = "" ]
	do
		error "-> Password cannot be blank."
		echo "-> Enter your password : \c"
		read -s password
		echo
	done
	ask "-> Would you like to store the credentials in a file for further use ?" "y"
	if [ ${?} == 1 ]
	then
		caesar=`echo "${password}" | tr '[A-Za-z]' '[N-ZA-Mn-za-m]'`
		if [ ! -d "${config_path}" ]
		then
			mkdir "${config_path}"
			if [ ! -d "${config_path}" ]
			then
				error "-> Unable to create config folder."
				return
			fi
		fi
		echo "login=${login}\npassword=${caesar}" > ${1}
		if [ -f ${1} ]
		then
			success "-> Credentials file created."
		else
			error "-> Error while creating credentials file."
		fi
	else
		success "-> Credentials successfully loaded."
	fi
}

# Gets credentials from credentials file or asks for them
# $1 : Credentials file
# returns : No return

get_credentials ()
{
	if [ -z "${1}" ]
	then
		echo "usage: get_credentials \"credentials file\""
		return
	fi
	if [ -f ${1} ]
	then
		info "-> Enabling read access on credentials file."
		chmod 700 ${1}
	fi
	if [ -f ${1} ]
	then
		info "-> Reading credentials file."
		while read -r line
		do
			if echo "${line}" | grep -q "login"
			then
				login=`echo "${line}" | sed -nE 's/^login=([A-Za-z0-9_-]+)$/\1/p'`
			elif echo "${line}" | grep -q "password"
			then
				password=`echo ${line} | sed -nE 's/^password=(.+)$/\1/p' | tr '[A-Za-z]' '[N-ZA-Mn-za-m]'`
			fi
		done < ${1}
		if [ -z "${login}" ] || [ -z "${password}" ]
		then
			error "-> Error while getting credentials from file."
			ask_credentials "${1}"
		else
			success "-> Credentials successfully loaded from file."
		fi
	else
		echo "-> It appears this is the first time you are using this tool."
		echo "-> You must now enter your credentials."
		ask_credentials "${1}"
	fi
	info "-> Encoding login and password to URL format."
	login_encoded=`echo "${login}" | sed -f "${includes_path}/urlencode.sed"`
	password_encoded=`echo "${password}" | sed -f "${includes_path}/urlencode.sed"`
	if [ -z "${login_encoded}" ] || [ -z "${password_encoded}" ]
	then
		error "-> Error while generating encoded username and/or password."
		exit
	fi
	if [ -f "${credentials_file}" ]
	then
		info "-> Disabling read access on credentials file."
		chmod 000 "${credentials_file}"
	fi
}

# Removes credentials file
# $1 : Credentials file
# return : No return

remove_credentials_file ()
{
	if [ -z "${1}" ]
	then
		echo "usage: remove_credentials_file \"credentials file\""
		return
	fi
	if [ -f ${1} ]
	then
		chmod 700 ${1}
		rm -f ${1}
		if [ -d "${cookies_path}" ]
		then
			rm -rf ${cookies_path}
		fi
		if [ -f "${1}" ]
		then
			error "-> Cannot remove credentials file."
		else
			success "-> Credentials file successfully removed."
			ask "-> Would you like to enter new credentials immediately ?" "y"
			if [ ${?} == 1 ]
			then
				get_credentials "${1}"
			else
				exit
			fi
		fi
	else
		error "-> There is no credentials file."
	fi
}
