#!/bin/sh ******************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    cloning.sh                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: jlejeune <jlejeune@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2014/01/27 18:55:06 by jlejeune          #+#    #+#              #
#    Updated: 2014/01/30 07:57:49 by jlejeune         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Global variables
corrections_regex="s/^.*<h3>.*devez.*noter vos pairs.*projet <a.*>Sujet (.*)<\/a> avant le <span.*>(.*)<\/span><\/h3>.*$/\1 (\2)/p"
correctors_regex="s/^.*<h3>.*devez.*sur votre rendu de <a.*>Sujet (.*)<\/a> \(<span.*>([0-9]+) note.*minimum des ([0-9]+).*\).*$/\1 (\2\/\3 required notes)/p"

# Gets remaining corrections
# returns : No return

clone_remaining_corrections ()
{
	content=""
	project=""
	projects=""
	corrections=""
	response=""
	project_name=""
	echo "-> Connecting to intranet."
	connect_to_intra
	if [ ${?} == 1 ]
	then
		info "-> Loading intranet index page."
		content=`curl -sL -b "${intranet_cookies}" "https://intra.42.fr"`
		i=0
		info "-> Reading page source..."
		while read -r line
		do
			project=`echo "${line}" | sed -nE "${corrections_regex}"`
			if [ ! -z "${project}" ]
			then
				info "-> Found a project : ${project}."
				projects[${i}]="${project}"
				i=`expr ${i} + 1`
			fi
		done <<< "${content}"
		selected=0
		if [ ${i} == 0 ]
		then
			error "-> No peer corrections available."
		else
			if [ ${i} == 1 ]
			then
				info "-> One project present, cloning..."
				corrections=`get_repository 0 "${corrections_regex}"`
			else
				info "-> Multiple projects present, asking..."
				menu "Which project would you like to clone ?" "Please enter your choice : " "${projects[@]}"
				selected=${?}
				corrections=`get_repository ${selected} "${corrections_regex}"`
			fi
			if [ ! -z "${corrections}" ]
			then
				subfolder="."
				ask "-> Would you like to create a subfolder for the git repositories ?" "y"
				response=${?}
				if [ ${response} == 1 ]
				then
					regex="s/^(.*) \(.*\)$/\1/p"
					project_name=`echo "${projects[${selected}]}" | sed -nE "${regex}" | tr '[:upper:]' '[:lower:]'`
					if [ ! -z "${project_name}" ]
					then
						if [ -d "${project_name}" ]
						then
							echo "-> The subfolder is already existing."
						else
							mkdir "${project_name}"
							if [ ! -d "${project_name}" ]
							then
								error "-> Cannot create subfolder, aborting."
							fi
						fi
					else
						error "-> Cannot find project name, aborting."
						return
					fi
				fi
				clone_repositories "${corrections}" "${subfolder}"
			fi
		fi
	fi
}

# Gets git repository for the passed project and filters the corrections
# with the passed regular expression
# $1 : Index of the project on the page
# $2 : Regular expression to filter the corrections
# returns : List of lines containing corrections stuff

get_repository ()
{
	if [ -z "${1}" ] || [ -z "${2}" ]
	then
		echo "usage: get_repositories \"index\" \"regular expression\""
		return
	fi
	i=${1}
	corrections=""
	project=""
	info "-> Reading page source..."
	while read -r line && [ ${i} -gt -3 ]
	do
		if [ ${i} -ge 0 ]
		then
			project=`echo "${line}" | sed -nE "${2}"`
			if [ ! -z "${project}" ]
			then
				info "-> Searched project found."
				i=`expr ${i} - 1`
			fi
		elif [ ${i} == -1 ] && echo "${line}" | grep -q "<ul>"
		then
			info "-> Corrections list beginning."
			i=`expr ${i} - 1`
		elif [ ${i} == -2 ] && echo "${line}" | grep -q "</ul>"
		then
			info "-> Corrections list ending."
			i=`expr ${i} - 1`
		else
			uid=`echo "${line}" | sed -nE "${correction_uid_regex}"`
			if [ ! -z "${uid}" ]
			then
				info "-> Correction found."
				if [ -z "${corrections}" ]
				then
					corrections="${line}"
				else
					corrections="${corrections}\n${line}"
				fi
			fi
		fi
	done <<< "${content}"
	if [ -z "${corrections}" ]
	then
		error "-> There are no corrections for this project."
	else
		echo "${corrections}"
	fi
}

# Clones repositories from the list given
# $1 : List of lines containing repositories URL
# $2 : The folder where the repositories have to be cloned
# returns : No return

clone_repositories ()
{
	if [ -z "${1}" ] || [ -z "${2}" ]
	then
		echo "usage: \"list of lines\" \"subfolder\""
		return
	fi
	list="${1}"
	subfolder="${2}"
	url_regex="s/^.*Vous <a href=\"([A-Za-z0-9/_-]+)\">devez noter.*$/\1/p"
	url=""
	uid=""
	content=""
	regex=""
	repository=""
	git_clone=""
	while read -r line
	do
		url="https://intra.42.fr`echo "${line}" | sed -nE "${url_regex}"`"
		uid=`echo "${line}" | sed -nE "${correction_uid_regex}"`
		if [ -z "${uid}" ]
		then
			error "-> Cannot find correction's uid."
			continue
		fi
		echo "-> \033[4mCloning ${uid}'s repository\033[0m"
		get_read_access "${url}"
		if [ ${?} == 1 ]
		then
			success "-> We got read access to repository. Cloning..."
			info "-> Getting vogsphere link..."
			content=`curl -sL -b "${intranet_cookies}" ${url}`
			regex="s/^.*\"url_repository\":\"([A-Za-z0-9@.:\/_-]+).*$/\1/p"
			repository=`echo "${content}" | tr -d "\n" | sed -nE "${regex}" | tr -d '\'`
			if [ ! -z "${repository}" ]
			then
				if [ -d "${uid}" ]
				then
					errro "-> This repository has alreade been cloned."
					ask "-> Would you like to reclone it ?" "y"
					if [ ${?} == 1 ]
					then
						info "-> Deleting folder \"${uid}\""
						rm -rf "${uid}"
						if [ -d "${uid}" ]
						then
							error "-> Cannot delete folder, aborting git clone."
							continue
						fi
					fi
				fi
				echo "-> Cloning repository..."
				git_clone=`git clone -q "${repository}" "${subfolder}/${uid}" 2>&1`
				if echo "${git_clone}" | grep -q "You appear to have cloned an empty repository."
				then
					echo "-> It appears that this correction will be ease. ;)"
				fi
				if [ -d "${subfolder}/${uid}" ]
				then
					success "-> Successfully cloned."
				else
					error "-> Error while cloning."
				fi
			else
				error "-> Cannot get vogsphere link to clone the repository."
			fi
		else
			error "-> No read access to this repository. Switching to next..."
		fi
	done <<< "${list}"
}

# Tries to get read access on repository
# $1 : Repository URL
# returns : 1 or 0 if we got read access or not

get_read_access ()
{
	if [ -z "${1}" ]
	then
		echo "usage: \"repository url\""
		return
	fi
	attempts=0
	status=0
	repo_url="${1}"
	content=""
	info "${1}"
	info "-> Getting acccess status."
	until [ ${status} == 1 ] || [ ${attempts} == 10 ]
	do
		info "-> Sending read access request..."
		check_url="${repo_url}repository?format=json"
		content=`curl -sL -b "${intranet_cookies}" "${check_url}"`
		if echo "${content}" | grep -q "success"
		then
			status=1
		else
			status=0
			attempts=`expr ${attempts} + 1`
			echo "-> No read access to repository, trying again."
			sleep 1
		fi
	done
	if [ ${attempts} == 10 ] && [ ${status} == 0 ]
	then
		return 0
	else
		return 1
	fi
}
