#!/bin/bash
set -e
set -u



get_old_version()
{
	touch "$old_version_file"
	cat "$old_version_file"
	while IFS= read -r line
	do
		[[ "$line" =~ ^.+\= ]] || continue
		var_name="${BASH_REMATCH[0]}"
		var_name="${var_name::-1}"
		[[ "$line" =~ \=[0-9.]*$ ]] || continue
		var_value="${BASH_REMATCH[0]}"
		var_value="${var_value:1}"
		old_versions[$var_name]=$var_value
	done < "$old_version_file"

}


get_version()
{
	echo "get version of $game_name"
	test "$last_base_game_name" !=  "$base_game_name" && details_list=$(lgogdownloader --platform l --include i,d --list-details --game ^$base_game_name\$)
	last_base_game_name=$base_game_name
	#find right version
	found_game="false"
	found_linux="false"
	verison="none"
	while IFS= read -r line
	do
		[[ "$line" =~ gamename:\ ${game_name}$ ]] && found_game="true"
		[[ "$found_game"  = "true" && "$line" =~ path:\ /${game_name}/.*\.sh$ ]] && found_linux="true"
		if [[ "$found_linux" = "true" && "$line" =~ version:\ [0-9.]*$ ]]
		then
			verison="$line"
			break
		fi
	done <<< "$details_list"
	if [ "$found_game" = "false" ]
	then
		echo "ERROR: game not found"
		return 1
	elif [ "$found_linux" = "false" ]
	then
		echo "ERROR: Linux version not found"
		return 1
	fi
	[[ "$verison" =~ [0-9.]*$ ]]
	verison="${BASH_REMATCH[0]}"
	return 0
}


do_update()
{
	echo "update package $package_name to $verison"
	mkdir -p "log"
	date > "$logfile"
	echo "update package $package_name to $verison" >> "$logfile"
	set +e
	pkgbuild-update --noconfirm --nodeps --pkgname "$package_name" | tee -a "$logfile"
	success=${PIPESTATUS[0]}
	set -e
	already_updated="false"
	if [[ $success -eq 2 ]]
	then
		 echo "The aur package $package_name has already been updated to $verison"
		 already_updated="true"
		 success=0
	fi
	return "$success"
}


process_game()
{
	verison="none"
	package_name=$1
	base_game_name=$2
	game_name="$base_game_name"
	[[ "$#" -eq 3 ]] && game_name=$3
	logfile="log/$package_name.log"
	if ! get_version
	then
		echo "checking version of $game_name failed. Skip $package_name"
		return
	fi

	if [ "$verison" = "${old_versions[$game_name]:-0}" ]
	then
		echo "no update available for $package_name $verison"
		return
	fi
	if ! do_update
	then
		echo "failed to update package $package_name to $verison"
		set +e
		cat "$logfile" | sendmail -s "failed to update package $package_name to $verison" "$MAIL_RECEIVER"
		set -e
		return
	fi
	if [ "$already_updated" = "false" ]
	then
	echo "update of package $package_name to $verison successfull"
		if [ "${MAIL_AFTER_UPDATE:-false}" = "true" ]
		then
			set +e
			cat "$logfile" | sendmail -s "updated package $package_name to $verison" "$MAIL_RECEIVER"
			set -e
		fi
	fi
	grep -q "^$game_name=.*" "$old_version_file" || echo "$game_name=$verison" >> "$old_version_file"
	sed -i -r "s/^$game_name=.*/$game_name=$verison/" "$old_version_file"
}


#echo "test body" | sendmail -s "test betreff" "test.gog-ci@lukas1818.de"
old_version_file="old_version.txt"
game_file="/games.txt"
if [ "${USE_COOKIE_FOR_LOGIN:-false}" = "false" ]
	then
		set +u
		if [ -z "$GOG_EMAIL" ]
		then
			echo "ERROR: GOG_EMAIL not set"
			exit 1
		fi
		if [ -z "$GOG_PASSWORD" ]
		then
			echo "ERROR: GOG_PASSWORD not set"
			exit 1
		fi
		set -u
	fi
echo "sleep ${START_DELAY:-2h}"
sleep "${START_DELAY:-2h}"
declare -A old_versions
while true
do
	date
	details_list=""
	last_base_game_name=""
	test "${USE_COOKIE_FOR_LOGIN:-false}" = "false" && gog_login
	get_old_version
	while IFS= read -r line
	do
		process_game $line
	done < "$game_file"
	echo "sleep ${INTERVAL:-3h}"
	sleep "${INTERVAL:-3h}"
done
