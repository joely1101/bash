argc=0
all_argv="$@"
__callback="cmd"
for arg;do
	echo "$arg" | grep -q " \|\.\|:\|-\|_"
	if [ "$?" == "0" ];then
		break
	fi
	__callback=${__callback}_${arg}
	argc=$((argc+1))
done
#echo "$__callback"
#echo "$argc"

#__callback="cmd_${all_argv// /_}"
for ((i=0;i<$argc;i++));do
    shfinum=$((argc-i))
    if [[ `declare -Ff $__callback` ]];then
        shift $shfinum
#        echo "call $__callback '$@'"
        $__callback "$@"
        exit $?
    else
        __callback=${__callback%_*}
#        echo "not foun try ===>$__callback"
    fi
done
if [ $# -eq 0 ];then
    help_show
else
    echo "Command not found !! Try $0 help"
fi
