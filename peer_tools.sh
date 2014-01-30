#!/bin/sh ******************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    peer_tools.sh                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: jlejeune <jlejeune@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2014/01/27 04:41:11 by jlejeune          #+#    #+#              #
#    Updated: 2014/01/30 18:38:48 by jlejeune         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Global variables
script_path=`dirname ${0}`
includes_path="${script_path}/includes"
version="2"
verbose=0

. "${includes_path}/utils.sh"
. "${includes_path}/credentials.sh"
. "${includes_path}/connection.sh"
. "${includes_path}/stalker.sh"
. "${includes_path}/cloning.sh"

main ()
{
	success "-> Peer Tools v${version} - Hello !"
	if [ ${verbose} == 1 ]
	then
		info "-> Verbose mode enabled."
	fi
	get_credentials "${credentials_file}"
	check_updates 1
	echo
	while [ 42 ]
	do
		options=(
			"Clone remaining corrections"
			"Get phone numbers of remaining corrections"
			"Get phone numbers of remaining correctors"
			"Stalk people with their ids"
			"Clean corrections folders"
			"Remove .git folder in correction folders"
			"Remove credentials file"
			"Remove cookies"
			"Check for updates"
			"Quit"
		)
		reply=(
			"clone_remaining_corrections"
			"get_corrections_numbers"
			"get_correctors_numbers"
			"stalk_people"
			"recursive_fclean"
			"remove_git_folders"
			"remove_credentials_file ${credentials_file}"
			"remove_cookies"
			"check_updates"
			"bye_bye"
		)
		menu "Choose your option" "Please enter your choice : " "${options[@]}"
		choice=${?}
		echo
		${reply[${choice}]}
		echo
	done
}

while getopts "v" option
do
	case "${option}" in
	v)
		verbose=1
		;;
	[?])
		echo "usage: ${0} [-v]"
		exit 1
		;;
	esac
done

trap 'echo ; bye_bye ; exit' 1 2 15

main
