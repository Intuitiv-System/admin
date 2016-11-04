#!/bin/bash

usage(){
echo -e " -d, --disk : Specify the disk to format. It will be used to extend the LV
       -v, --volume : Specify the logical volume to extend
       -h, --help : Display this help"
}

lvmInstalled=$(dpkg -s lvm2 >/dev/null 2>&1)
test=$(echo $?)
if [[ ${test} = "1" ]]
then
  echo "lvm2 package seems to be not installed. Script will shutdown"
  exit 1

elif [[ $(whoami) != "root" ]]
then
  echo "You have to run this script as root"
  exit 1

else
volumeGroup=$(vgdisplay | grep Name | awk '{print $3}')

  while getopts ":d:v:h" opt; do
    case $opt in
      d | disk) disk="$OPTARG"
        ##test si le disque est partitionné
        if [[ $(/sbin/sfdisk -d ${OPTARG} 2>&1) == "" ]]
          then
          echo "Device not partitioned"
                     
        else
         echo "${OPTARG} is still partitioned use a different disk."
         exit 1
        fi
        ;;
      v | volume) volume="$OPTARG"
        ;;
      h | help) usage
        ;;
    esac
    ##Creating a partition
    (echo g; echo n; echo p; echo 1; echo; echo; echo w) | fdisk ${disk} > /dev/null 2>&1 && echo "One partition created successfuly on ${disk}"
    var="1"
    partition="${disk}""${var}"
    pvcreate ${partition}
    vgextend ${volumeGroup} ${partition}
    lvextend -l +100%FREE /dev/${volumeGroup}/${volume}
    resize2fs /dev/${volumeGroup}/${volume}
  done
fi



exit 0
