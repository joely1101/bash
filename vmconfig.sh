if [ "$EUID" -ne 0 ];then 
    echo "Please run as root"
    exit
fi

src_dir=.

. $src_dir/scripts/cmd.head.sh

###########################################################################
# backup/restore vm config from qcow2.
#########################################################################
gl_needrun=0
gl_vmname=""

state_rollback()
{
   nbdconnect=$1
   diskmount=$2
   vmrunning=$3
  
   if [ "${diskmount}" = "1" ];then
      echo "umount disk"
      umount /dev/nbd5p5
   fi
   if [ "${nbdconnect}" = "1" ];then
      echo "disconnect /dev/nbd5"
      qemu-nbd --disconnect /dev/nbd5
   fi
   if [ "${vmrunning}" = "1" ];then
      echo "virsh start ${gl_vmname}"
      virsh start ${gl_vmname}
   fi
}

mount_vm_config_disk()
{
    vmname=$1
    mntp=$2
    local indisk=$3
    local diskmount=0
    local nbdconnect=0
    if [ -z "${indisk}" ] || [ ! -f "${indisk}" ];then
        #if not shut off
        if ! virsh dominfo ${vmname} &>/dev/null;then
            echo "${vmname} not found"
            return 99
        fi
        
        gl_vmname=${vmname}

        virsh dominfo ${vmname} | grep State | grep -q 'running'
        if [ "$?" = "0" ];then
            gl_needrun=1
            virsh destroy ${vmname}
        fi        
        #
        disk=$(virsh domblklist ${vmname} | grep vda | awk '{print $2}')
        if [ -z "${disk}" ] || [ ! -f ${disk} ];then
            echo "disk (${disk}) not found"
            state_rollback ${nbdconnect} ${diskmount} ${gl_needrun}
            return 99
        fi
    else
        disk=${indisk}
    fi

    modprobe nbd max_part=8
    qemu-nbd --disconnect /dev/nbd5 &>/dev/null
    if ! qemu-nbd --connect=/dev/nbd5 ${disk};then
        echo "qemu-nbd failed"
        state_rollback ${nbdconnect} ${diskmount} ${gl_needrun}
        return 99
    fi
    nbdconnect=1
    sleep 1
    if [ ! -b /dev/nbd5p5 ];then
        echo "block device not found"
        state_rollback ${nbdconnect} ${diskmount} ${gl_needrun}
        return 99
    fi
    mkdir -p ${mntp}
    if ! mount /dev/nbd5p5 ${mntp};then
        echo "mount fail"
        state_rollback ${nbdconnect} ${diskmount} ${gl_needrun}
        return 99
    fi
    return 0
}

umount_vm_config_disk()
{
    state_rollback 1 1 ${gl_needrun} 
}

extract_vm_config()
{
    local VMName=$1
    local diskfile=$2
    local config_tarfile=$(realpath $3)
    local mntdir=/tmp/vmconfig
    mount_vm_config_disk "${VMName}" "${mntdir}" "${diskfile}"
    if [ "$?" = "0" ];then
        #echo "sync/copy files to $configdir"
        #rsync -ah ${mntdir}/ $configdir
        echo "tar files to $config_tarfile"
        cd ${mntdir}
        tar zcf $config_tarfile *
        cd -
        umount_vm_config_disk
        echo "extract file from ${VMName} ${diskfile} success"
    fi
}
inject_vm_config()
{
    local VMName=$1
    local diskfile=$2
    local config_tarfile=$(realpath $3)
    local mntdir=/tmp/vmconfig
    mount_vm_config_disk "${VMName}" "${mntdir}" "${diskfile}"
    if [ "$?" = "0" ];then
        rm -rf ${mntdir}/*
        #rsync -ah ${configdir}/ ${mntdir}
        tar xf $config_tarfile -C ${mntdir}/
        umount_vm_config_disk 
        echo "Inject config file to ${VMName} ${diskfile} success"
    fi
}
cmd_backup()
{
    vmnamedisk=$1
    file=${2:-"./vmconfig.tgz"}
    if [ -z "$vmnamedisk" ];then
        error_out "Invalid argument"
    fi
    if [ -f "${vmnamedisk}" ];then
        extract_vm_config "" "${vmnamedisk}" $file
    else 
        extract_vm_config "${vmnamedisk}" "" $file
    fi

}

cmd_restore()
{
    vmnamedisk=$1
    file=$2
    if [ -z "$vmnamedisk" ];then
        error_out "Invalid argument"
    fi
    if [ -f "${vmnamedisk}" ];then
        inject_vm_config "" "${vmnamedisk}" ${file}
    else 
        extract_vm_config "${vmnamedisk}" "" ${file}
    fi
}
help_add "vmconfig" "vmconfig [ vmname | qcowfile ] confg_tgz_file"

. $src_dir/scripts/cmd.tail.sh