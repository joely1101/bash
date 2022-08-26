declare -A HELP
debuglevel=${debuglevel:-2}
do_cmd()
{
    if [ "$debuglevel" = "1" ];then
	echo "cmd:$@"
	eval "$@ 1>/dev/null"
	if [ $? != 0 ];then
		echo "Error!!"
		exit 99
	fi
	echo "done..."

    elif [ "$debuglevel" = "2" ];then
	echo "cmd:$@"
	eval $@
	 if [ $? != 0 ];then
            echo "Error!!"
            exit 99
         fi
	echo "done..."
    else
        eval $@
	 if [ $? != 0 ];then
             echo "Error!!"
             exit 99
         fi
    fi
}
rename_fn()
{
  local a
  a="$(declare -f "$1")" &&
  eval "function $2 ${a#*"()"}" &&
  unset -f "$1";
}
help_add()
{
    HELP["$1"]="$2"
}

help_show()
{
    echo "Help:"
    KEYS=`echo ${!HELP[@]} | tr ' ' '\012' | sort | tr '\012' ' '`
    for key in ${KEYS}
    do
        if [ "${HELP[$key]}" != "" ];then
	    echo "${HELP[$key]}"
	fi
    done    
}
error_out()
{
    echo $@
    exit 99
}