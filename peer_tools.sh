#!/bin/sh

base=`dirname $0`
credentials=${base}"/credentials"
login=""
password=""
login_url=""
password_url=""
token_url=""

ask () {
	while [ "$yn" = "" ]; do
		if [ "$2" = "y" ]; then
			echo ${1}" [Y/n] : \c"
		elif [ "$2" = "n" ]; then
			echo ${1}" [y/N] : \c"
		else
			echo ${1}" [y/n] : \c"
		fi
		read yn
		yn=`echo $yn | tr '[:upper:]' '[:lower:]'`
		if [ "$yn" = "yes" ] || [ "$yn" = "y" ]; then
			return 1
			break
		elif [ "$yn" = "no" ] || [ "$yn" = "n" ]; then
			return 0
			break
		elif [ "$yn" = "" ] && [ "$2" != "" ]; then
			if [ "$2" = "y" ]; then
				return 1
				break
			elif [ "$2" = "n" ]; then
				return 0
				break
			else
				yn=""
			fi
		else
			yn=""
		fi
	done
}

get_credentials () {
	echo "-> It appears this is the first time you are using this tool."
	echo "-> You must now enter your credentials."

	echo "-> Enter your login : \c"
	read login
	while [ "$login" = "" ]; do
		echo "-> Login cannot be blank."
		echo "-> Enter your login : \c"
		read login
	done

	echo "-> Enter your password : \c"
	read -s password
	echo
	while [ "$password" = "" ]; do
		echo "-> Password cannot be blank."
		echo "-> Enter your password : \c"
		read -s password
		echo
	done
}

check_credentials () {
	if [ -f $credentials ]; then
		chmod 700 $credentials
	fi
	if [ -f $credentials ]; then
		while read -r line; do
			if echo $line | grep -q "login"; then
				login=`echo $line | sed -nE 's/^login=([A-Za-z0-9_-]+)$/\1/p'`
			elif echo $line | grep -q "password"; then
				password=`echo $line | sed -nE 's/^password=(.+)$/\1/p' | tr '[A-Za-z]' '[N-ZA-Mn-za-m]'`
			fi
		done < $credentials
	else
		get_credentials
		ask "-> Would you like to store the credentials in a file for further use ?" "y"
		result=$?
		if [ $result == 1 ]; then
			caesar=`echo $password | tr '[A-Za-z]' '[N-ZA-Mn-za-m]'`
			echo "login="${login}"\npassword="${caesar} > $credentials
			echo "-> Credentials file created."
		fi
		echo
	fi
	login_url=`echo $login | sed -f $base/urlencode.sed`
	password_url=`echo $password | sed -f $base/urlencode.sed`
	if [ -f $credentials ]; then
		chmod 000 $credentials
	fi
}

clone_remaining_corrections () {
	status=0
	attempts=0
	echo "-> Getting remaining corrections from intra..."
	wget -qO- --keep-session-cookies --save-cookies $base/cookies.txt --post-data "login=${login_url}&password=${password_url}" https://intra.42.fr | sed -nE "s/^.*Vous <a href=\"([A-Za-z0-9/_-]+)\">devez noter.*$/\1/p" | while read -r line ; do
		uid=`echo $line | sed -nE "s/^.*[[:digit:]]+-([A-Za-z0-9_-]+)\/$/\1/p"`
		url="https://intra.42.fr"${line}
		repo=${url}"repository?format=json"
		echo "\n--------------- Cloning $uid's repository ---------------\n"
		until [ $status == 1 ] || [ $attempts == 10 ]; do
			success=`wget -qO- --load-cookies $base/cookies.txt $repo`
			if echo $success | grep -q "success"; then
				status=1
			else
				status=0
				attempts=`expr $attempts + 1`
				echo "-> No read access to repository, trying again."
				sleep 1
			fi
		done
		if [ $attempts == 10 ] && [ $status == 0 ]; then
			status=0
			attempts=0
			echo "-> Too many attempts. Switching to next."
			continue
		else
			status=0
			attempts=0
			echo "-> We got read access to repository, let's go !"
		fi
		echo "-> Getting vogsphere link..."
		git=`wget -qO- --load-cookies $base/cookies.txt $url | sed -nE 's/^.*"url_repository":"(.*)".*$/\1/p' | tr -d '\'`
		if [ -d ./$uid ]; then
			echo "-> This repository has already been cloned, deleting..."
			rm -Rf $uid
		fi
		echo "-> Cloning repository..."
		output=`git clone -q $git 2>&1`
		if echo $output | grep -q "You appear to have cloned an empty repository."; then
			echo "-> It appears that this correction will be easy. ;)"
		fi
		if [ -d ./$uid ]; then
			echo "-> Successfully cloned."
		else
			echo "-> Error while cloning."
		fi
	done
	rm -f $base/cookies.txt
	exit
}

get_remaining_corrections_numbers () {
	echo "-> Getting remaining corrections from intra..."
	wget -qO- --post-data "login=${login_url}&password=${password_url}" https://intra.42.fr | sed -n 's/^.*devez noter le groupe [A-Za-z0-9]* [A-Za-z0-9]* \([A-Za-z0-9_+-]*\).*$/\1/p' | while read -r line ; do
	phone=`ldapsearch -Q uid=$line mobile-phone | sed -n 's/^mobile-phone: \([0-9\ _+-]*\)$/\1/p' | tr -d ' ' | sed 's/+33/0/g' | sed 's/.\{2\}/& /g'`
		if [ "$phone" = "" ]; then
			phone="not found"
		fi
		printf "%12s : %s\n" "$line" "$phone"
	done
	exit
}

get_peer_correctors_numbers () {
	echo "-> Getting peer correctors from intra..."
	wget -qO- --post-data "login=${login_url}&password=${password_url}" https://intra.42.fr | sed -n 's/^.*par <a .*>\([A-Za-z0-9_+-]*\)<\/a>.*$/\1/p' | while read -r line ; do
	phone=`ldapsearch -Q uid=$line mobile-phone | sed -n 's/^mobile-phone: \([0-9\ _+-]*\)$/\1/p' | tr -d ' ' | sed 's/+33/0/g' | sed 's/.\{2\}/& /g'`
		if [ "$phone" = "" ]; then
			phone="not found"
		fi
		printf "%12s : %s\n" "$line" "$phone"
	done
	exit
}

get_remaining_corrections_numbers_outside () {
	echo "-> Loading dashboard index..."
	wget -qO /dev/null --keep-session-cookies --save-cookies $base/cookies.txt "https://dashboard.42.fr"
	token=`cat $base/cookies.txt | sed -nE "s/^.*csrftoken[[:blank:]]+(.*)$/\1/p"`
	if [ "$token" = "" ]; then
		echo "-> An error occured while trying to get the CSRF token. Please try again."
		exit
	fi
	token_url=`echo $token | sed -f $base/urlencode.sed`
	echo "-> Connecting to dashboard..."
	content=`wget -qO- --keep-session-cookies --save-cookies $base/cookies.txt --load-cookies $base/cookies.txt --post-data "csrfmiddlewaretoken=${token_url}&username=${login_url}&password=${password_url}&next=" "https://dashboard.42.fr/login/"`
	if echo $content | grep -q "Hello"; then
		echo "-> Getting remaining corrections from intra..."
		wget -qO- --post-data "login=${login_url}&password=${password_url}" https://intra.42.fr | sed -n 's/^.*devez noter le groupe [A-Za-z0-9]* [A-Za-z0-9]* \([A-Za-z0-9_-]*\).*$/\1/p' | while read -r line ; do

			content=`wget -qO- --load-cookies $base/cookies.txt "https://dashboard.42.fr/user/profile/${line}/"`
			if echo $content | grep -q "UID"; then
				mobile=`echo $content | sed -nE "s/^.*<dt>Mobile<\/dt>[[:blank:]]+<dd>([0-9\ _+-]+)<\/dd>.*$/\1/p"`
				if [ "$mobile" = "" ]; then
					mobile="not found"
				else
					mobile=`echo $mobile | tr -d ' ' | sed 's/+33/0/g' | sed 's/.\{2\}/& /g'`
				fi
				online=`echo $content | sed -nE "s/^.*<dt>Latest location<\/dt>[[:blank:]]+<dd>(e[[:digit:]]+r[[:digit:]]+p[[:digit:]]+)\.42\.fr.*<\/dd>.*$/\1/p"`
				if [ "$online" = "" ]; then
					online="offline"
				fi
				printf "%12s : %s (%s)\n" "$line" "$mobile" "$online"
			else
				echo "-> An error occured while trying to get informations of the user. Please try again."
				rm -f $base/cookies.txt
				exit
			fi
		done
	else
		echo "-> An error occured while trying to login to the dashboard. Please try again."
		rm -f $base/cookies.txt
		exit
	fi
	rm -f $base/cookies.txt
	exit
}

get_peer_correctors_numbers_outside () {
	echo "-> Loading dashboard index..."
	wget -qO /dev/null --keep-session-cookies --save-cookies $base/cookies.txt "https://dashboard.42.fr"
	token=`cat $base/cookies.txt | sed -nE "s/^.*csrftoken[[:blank:]]+(.*)$/\1/p"`
	if [ "$token" = "" ]; then
		echo "-> An error occured while trying to get the CSRF token. Please try again."
		exit
	fi
	token_url=`echo $token | sed -f $base/urlencode.sed`
	echo "-> Connecting to dashboard..."
	content=`wget -qO- --keep-session-cookies --save-cookies $base/cookies.txt --load-cookies $base/cookies.txt --post-data "csrfmiddlewaretoken=${token_url}&username=${login_url}&password=${password_url}&next=" "https://dashboard.42.fr/login/"`
	if echo $content | grep -q "Hello"; then
		echo "-> Getting peer correctors from intra..."
		wget -qO- --post-data "login=${login_url}&password=${password_url}" https://intra.42.fr | sed -n 's/^.*par <a .*>\([A-Za-z0-9_-]*\)<\/a>.*$/\1/p' | while read -r line ; do
			content=`wget -qO- --load-cookies $base/cookies.txt "https://dashboard.42.fr/user/profile/${line}/"`
			if echo $content | grep -q "UID"; then
				mobile=`echo $content | sed -nE "s/^.*<dt>Mobile<\/dt>[[:blank:]]+<dd>([0-9\ _+-]+)<\/dd>.*$/\1/p"`
				if [ "$mobile" = "" ]; then
					mobile="not found"
				else
					mobile=`echo $mobile | tr -d ' ' | sed 's/+33/0/g' | sed 's/.\{2\}/& /g'`
				fi
				online=`echo $content | sed -nE "s/^.*<dt>Latest location<\/dt>[[:blank:]]+<dd>(e[[:digit:]]+r[[:digit:]]+p[[:digit:]]+)\.42\.fr.*<\/dd>.*$/\1/p"`
				if [ "$online" = "" ]; then
					online="offline"
				fi
				printf "%12s : %s (%s)\n" "$line" "$mobile" "$online"
			else
				echo "-> An error occured while trying to get informations of the user. Please try again."
				rm -f $base/cookies.txt
				exit
			fi
		done
	else
		echo "-> An error occured while trying to login to the dashboard. Please try again."
		rm -f $base/cookies.txt
		exit
	fi
	rm -f $base/cookies.txt
	exit
}


remove_credentials_file () {
	if [ -f $credentials ]; then
		chmod 700 $credentials
		rm -f $credentials
		echo "Credentials file removed."
		exit
	else
		echo "There is no credentials file."
	fi
}

main () {
	check_credentials
	PS3='-> Please enter your choice : '
	options=("Clone remaining corrections" "Get phone numbers of remaining corrections (ldap - inside 42)" "Get phone numbers of peer correctors (ldap - inside 42)" "Get phone numbers of remaining corrections (dashboard - inside/outside 42)" "Get phone numbers of peer correctors (dashboard - inside/outside 42)" "Remove credentials file" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"Clone remaining corrections")
				clone_remaining_corrections
				;;
			"Get phone numbers of remaining corrections (ldap - inside 42)")
				get_remaining_corrections_numbers
				;;
			"Get phone numbers of peer correctors (ldap - inside 42)")
				get_peer_correctors_numbers
				;;
			"Get phone numbers of remaining corrections (dashboard - inside/outside 42)")
				get_remaining_corrections_numbers_outside
				;;
			"Get phone numbers of peer correctors (dashboard - inside/outside 42)")
				get_peer_correctors_numbers_outside
				;;
			"Remove credentials file")
				remove_credentials_file
				;;
			"Quit")
				break
				;;
			*) echo "Invalid option";;
		esac
	done
}

main
