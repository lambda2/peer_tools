#!/bin/sh ******************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    connection.sh                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: jlejeune <jlejeune@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2014/01/27 16:50:38 by jlejeune          #+#    #+#              #
#    Updated: 2014/01/28 15:18:43 by jlejeune         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Global variables
cookies_path="${script_path}/cookies"
intranet_cookies="${cookies_path}/intranet.cookies"
dashboard_cookies="${cookies_path}/dashboard.cookies"

# Connects to intranet
# returns : 1 or 0 if the connection is successfull or not

connect_to_intra ()
{
	if [ ! -d "${cookies_path}" ]
	then
		info "-> Cookies folder not existing."
		mkdir "${cookies_path}"
		if [ ! -d "${cookies_path}" ]
		then
			error "-> Error while creating cookies directory."
			exit
		fi
	fi
	if [ -f "${intranet_cookies}" ]
	then
		info "-> Checking cookies last modification..."
		current_time=`date +%s`
		file_time=`stat -f "%m" ${intranet_cookies}`
		max_time=`expr 12 \\* 60 \\* 60` # 12 hours
		diff=`expr ${current_time} - ${file_time}`
		if [ ${diff} -ge ${max_time} ]
		then
			error "-> Last connection was more than 12h, reconnecting..."
			rm -f ${intranet_cookies}
		fi
	fi
	info "-> Connecting to intranet..."
	if [ -f "${intranet_cookies}" ]
	then
		info "-> Connection with available cookies."
		content=`curl -sL -b "${intranet_cookies}" "https://intra.42.fr"`
	else
		info "-> Connection with new cookies."
		post_data="login=${login_encoded}&password=${password_encoded}&remind=on"
		content=`curl -sL -c "${intranet_cookies}" -d "${post_data}" "https://intra.42.fr"`
	fi
	if echo "${content}" | grep -q "Bienvenue" && [ -f "${intranet_cookies}" ]
	then
		success "-> Connected to intranet."
		return 1
	else
		error "-> Error while connecting to intranet. Check your credentials."
		return 0
	fi
}

connect_to_dashboard ()
{
	if [ ! -d "${cookies_path}" ]
	then
		info "-> Cookies folder not existing."
		mkdir "${cookies_path}"
		if [ ! -d "${cookies_path}" ]
		then
			error "-> Error while creating cookies directory."
			exit
		fi
	fi
	if [ -f "${dashboard_cookies}" ]
	then
		info "-> Checking cookies last modification..."
		current_time=`date +%s`
		file_time=`stat -f "%m" ${dashboard_cookies}`
		max_time=`expr 12 \\* 60 \\* 60` # 12 hours
		diff=`expr ${current_time} - ${file_time}`
		if [ ${diff} -ge ${max_time} ]
		then
			error "-> Last connection was more than 12h, reconnecting..."
			rm -f ${dashboard_cookies}
		fi
	fi
	info "-> Loading dashboard index..."
	if [ -f "${dashboard_cookies}" ]
	then
		info "-> Loading with available cookies."
		content=`curl -sL -b "${dashboard_cookies}" "https://dashboard.42.fr"`
	else
		info "-> Loading with new cookies."
		content=`curl -sL -c "${dashboard_cookies}" "https://dashboard.42.fr"`
		if [ ! -f "${dashboard_cookies}" ]
		then
			error "-> Error while connecting to dashboard. No cookies."
			exit
		fi
		info "-> Getting CSRF token."
		token=`cat "${dashboard_cookies}" | sed -nE 's/^.*csrftoken[[:blank:]]+(.*)$/\1/p'`
		if [ -z "${token}" ]
		then
			error "-> Error while connecting to dashboard. No CSRF token."
		fi
		info "-> Encoding CSRF token."
		token_encoded=`echo "${token}" | sed -f "${includes_path}/urlencode.sed"`
		info "-> Connecting to dashboard..."
		post_data="csrfmiddlewaretoken=${token_encoded}&username=${login_encoded}&password=${password_encoded}&next="
		info "-> Sending request..."
		content=`curl -sL -c "${dashboard_cookies}" -b "${dashboard_cookies}" -d "${post_data}" "https://dashboard.42.fr/login/"`
	fi
	if echo "${content}" | grep -q "Hello" && [ -f "${dashboard_cookies}" ]
	then
		success "-> Connected to dashboard."
		return 1
	else
		error "-> Error while connecting to dashboard. Check your credentials."
		return 0
	fi
}

# Removes available cookies
# returns : No return

remove_cookies ()
{
	if [ -d "${cookies_path}" ]
	then
		rm -rf "${cookies_path}"
		if [ -d "${cookies_path}" ]
		then
			error "-> Cannot remove cookies."
		else
			success "-> Cookies successfully removed."
		fi
	else
		error "-> There are no cookies."
	fi
}
