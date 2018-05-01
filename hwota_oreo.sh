#!/bin/bash

printf "\033c" # Clear screen

# Get OS type
case "$OSTYPE" in
  cygwin*)
    OS=Windows
  ;;
  linux*)
    OS=Linux
  ;;
  darwin*)
    OS=OSX
  ;;
  *)
    echo "Unable to identify OS type $OSTYPE..."
    echo "Press ENTER to continue..."
    read
    exit
  ;;
esac

# Get path variables
if [ "$OS" != "Windows" ]; then
  ROOTPATH=`pwd`
  AWK=awk
else
  ROOTPATH=`cygpath -m "$1"`
  AWK=gawk
fi

TOOLPATH=$ROOTPATH/tools/$OS
OEMPATH=$ROOTPATH/oeminfo
RECPATH=$ROOTPATH/recovery
FASTBOOT=$TOOLPATH/fastboot
ADB=$TOOLPATH/adb
UNLOCK_CODE=


##########################################################################################

function check_fastboot {
  if [ "`$FASTBOOT devices 2>&1 | grep fastboot`" != "" ]; then
    echo 1
  else
    echo 0
  fi
}

function wait_fastboot {
  while [ $(check_fastboot) -eq 0 ]
  do
    sleep 1
  done
}

function check_lock {
  if [ "`$FASTBOOT oem lock-state info 2>&1 | grep USER | grep UNLOCKED`" != "" ]; then
   echo 0
  else
   echo 1
  fi
}

function check_adb {
  if [ "`$ADB devices 2>&1 | grep recovery`" != "" ]; then
    echo 1
  else
    echo 0
  fi
}

function wait_adb {
  $ADB kill-server > /dev/null 2>&1
  while [ $(check_adb) -eq 0 ]
  do
    $ADB kill-server > /dev/null 2>&1
    sleep 1
  done
}

function pause {
  if [ "$1" != "" ]; then
    echo $1
  fi
  echo "Press ENTER to continue..."
  read
}

function unlock_device {
  if [ $(check_lock) -eq 1 ]; then
    echo "Before the next step, you need to unlock the loader."
    if [ "$UNLOCK_CODE" = "" ]; then
      echo -n "Enter unlock code:"
      UNLOCK_CODE=$(getkeys)
    else
      echo "Use unlock code $UNLOCK_CODE"
    fi
    echo
    echo "Use the volume buttons to select YES and press the power button"
    $FASTBOOT oem unlock $UNLOCK_CODE
    if [ "$1" != "" ]; then
      echo
      pause "$1"
    fi
  fi
}

function getkeys {
  read keyinput
  echo $keyinput
}

function isnum {
  if [ $(echo "$1" | grep -c '^[0-9]\+$') = 1 ]; then
    echo 1
  else
    echo 0
  fi
}

function format_str {
  strlen=${#1}
  count=$2
  remain=$(( count - strlen ))
  echo -n "$1"
  printf '%*s' "$remain"
}

function list_config {
  echo
  echo "****************************************"
  echo "* $(format_str 'Model:  '$MODEL 37)*"
  echo "* $(format_str 'Build:  '$BUILD 37)*"
if [ "$UPDATE_TYPE" = "1" ]; then
  echo "* Source: SDCard HWOTA directory       *"
else
  echo "* Source: Script update directory      *"
fi
if [ "$UPDATE_TYPE" = "1" ]; then
  echo "* Update: Same brand update            *"
else
  echo "* $(format_str 'Update: Rebrand to '`echo $REBRAND | $AWK -F "/" '{print $NF}' | $AWK -F "." '{print $1}'` 37)*"
fi
  echo "****************************************"
  pause
}

##########################################################################################

echo 
echo "****************************************"
echo "*                                      *"
echo "* Written by mankindtw with ХDA        *"
echo "* Modified by jccultima123 for Oreo    *"
echo "* EMUI 8 REQUIRED!!                    *"
echo "*                                      *"
echo "****************************************"
echo 

if [ "`echo $ROOTPATH | grep ' '`" != "" ]; then
  pause "This script does not support a directory with space ."
  exit
fi

if [ ${#ROOTPATH} -gt 200 ]; then
  pause "The path is too long, extract the script package on a shorter path."
  exit
fi


pause "Hold down the volume button minus and connect the USB cable to boot into the fastboot mode."
wait_fastboot

# Get product, model, and build
PRODUCT=`$FASTBOOT oem get-product-model 2>&1 | grep bootloader | $AWK '{ print $2 }'`
MODEL=`echo $PRODUCT | $AWK -F "-" '{ print $1 }'`
BUILD=`$FASTBOOT oem get-build-number 2>&1 | grep bootloader | $AWK -F ":" '{ print $2 }' | $AWK -F "\r" '{ print $1 }'`

unlock_device "After the phone is ready, turn off the power and use the Volume keys minus + USB cable to boot into the fastboot mode."
wait_fastboot

TWRP_FILE=`cd $RECPATH/$MODEL; ls | grep -i twrp_oreo`
TWRP=$RECPATH/$MODEL/$TWRP_FILE
echo
echo "Replacing the E_repair runoff in TWRP, wait..."
#$FASTBOOT flash erecovery_ramdisk $TWRP
$FASTBOOT flash recovery_ramdisk $TWRP # erecovery not working
echo
pause "Hold down the volume keys plus and on to load into TWRP."
pause "Wait for the device to boot into TWRP."

wait_adb

while [ 1 ]
do
echo 
echo "******************************************"
echo "* Upgrade options :                      *"
echo "* 1. From the SD card                    *"
echo "* 2. Using the script (not working, atm) *"
echo "******************************************"
echo -n "Select: "
UPDATE_SOURCE=$(getkeys)
if [ $(isnum $UPDATE_SOURCE) -eq 1 ] && [ "$UPDATE_SOURCE" -gt "0" ] && [ "$UPDATE_SOURCE" -lt "3" ]; then
  break
fi
echo "Wrong select..."
done

  # update some vars for oreo
  RECOVERY_FILE=${MODEL}_RECOVERY_NoCheck_OREO.img
  RECOVERY2_FILE=${MODEL}_RECOVERY2_NoCheck_OREO.img
  RECOVERY=$RECPATH/$MODEL/$RECOVERY_FILE
  RECOVERY2=$RECPATH/$MODEL/$RECOVERY2_FILE
  RECOVERY_TMP=/tmp/$RECOVERY_FILE
  RECOVERY2_TMP=/tmp/$RECOVERY2_FILE
  UPDATE_FILE=update.zip
  UPDATE_DATA_FILE=update_data_public.zip
  UPDATE_HW_FILE=update_all_hw.zip

if [ "$UPDATE_SOURCE" -eq "1" ]; then # SDCard
  SOURCE_PATH=
  SOURCE_UPDATE=
  SOURCE_UPDATE_DATA=
  SOURCE_UPDATE_HW=
  # TARGET_PATH=/sdcard/HWOTA #old
  TARGET_PATH=/sdcard/HWOTA8
  TARGET_UPDATE=$TARGET_PATH/$UPDATE_FILE
  TARGET_UPDATE_DATA=$TARGET_PATH/$UPDATE_DATA_FILE
  TARGET_UPDATE_HW=$TARGET_PATH/$UPDATE_HW_FILE
else # internal
  SOURCE_PATH=$ROOTPATH/update
  SOURCE_UPDATE=$SOURCE_PATH/$UPDATE_FILE
  SOURCE_UPDATE_DATA=$SOURCE_PATH/$UPDATE_DATA_FILE
  SOURCE_UPDATE_HW=$SOURCE_PATH/$UPDATE_HW_FILE
  # TARGET_PATH=/data/update/HWOTA
  TARGET_PATH=/data/update/HWOTA8
  TARGET_UPDATE=$TARGET_PATH/$UPDATE_FILE
  TARGET_UPDATE_DATA=$TARGET_PATH/$UPDATE_DATA_FILE
  TARGET_UPDATE_HW=$TARGET_PATH/$UPDATE_HW_FILE
fi


while [ 1 ]
do
  echo 
  echo "****************************************"
  echo "* What would you like to do?           *"
  echo "* 1. Change firmware?                  *"
  echo "* 2. Change location? (May not work!)  *"
  echo "****************************************"
  echo -n "Select: "
  UPDATE_TYPE=$(getkeys)
  if [ $(isnum $UPDATE_TYPE) -eq 1 ] && [ "$UPDATE_TYPE" -gt "0" ] && [ "$UPDATE_TYPE" -lt "3" ]; then
    break
  fi
  echo "Wrong select..."
done

if [ "$UPDATE_TYPE" = "1" ]; then
  list_config
fi

if [ "$UPDATE_TYPE" = "2" ]; then
  idx=0
  flist=($(ls $OEMPATH/$MODEL/* | sort))
  fsize=${#flist[@]}
  while [ 1 ]
  do
    idx=1
    echo 
    echo "****************************************"
    echo "* File replacement oeminfo:                *"
    for oem in "${flist[@]}"
    do
      echo -e "* $(format_str $idx.' '`echo $oem | $AWK -F "/" '{print $NF}' | $AWK -F "." '{print $1}'` 37)*"
      idx=$(( idx + 1 ))
    done
    echo "****************************************"
    echo -n "Select: "
    rb=$(getkeys)
    if [ $(isnum $rb) -eq 1 ] && [ "$rb" -gt "0" ] && [ "$rb" -lt "$(( fsize + 1 ))" ]; then
      break
    fi
    echo "Make a choice..."
  done
  REBRAND=${flist[$(( rb - 1 ))]}
  list_config
  echo 
  echo  "Replacing the oeminfo file with the selected one, please wait ..."
  $ADB push $REBRAND /tmp/oeminfo
  $ADB shell "dd if=/tmp/oeminfo of=/dev/block/platform/hi_mci.0/by-name/oeminfo"
  $ADB reboot bootloader
  wait_fastboot
  echo
  unlock_device "Wait for the device to boot into TWRP."
fi

echo
echo "Wait for the files to load. Neither of which you do not need to press!!!."
echo

wait_adb

if [ "$UPDATE_SOURCE" = "2" ]; then
  $ADB shell "rm -fr $TARGET_PATH > /dev/null 2>&1"
  $ADB shell "mkdir $TARGET_PATH > /dev/null 2>&1"
  echo "Copying is in progress ...."
  $ADB push $SOURCE_UPDATE $TARGET_UPDATE
  echo
  echo "Copying is in progress ...."
  $ADB push $SOURCE_UPDATE_DATA $TARGET_UPDATE_DATA
  echo
  echo "Copying is in progress ...."
  $ADB push $SOURCE_UPDATE_HW $TARGET_UPDATE_HW
fi


echo
echo "Copying recovery files, please be patient and wait...."
$ADB push $RECOVERY $RECOVERY_TMP
$ADB push $RECOVERY2 $RECOVERY2_TMP
#$ADB shell "dd if=$RECOVERY_TMP of=/dev/block/mmcblk0p29 bs=1048576"
$ADB shell "dd if=$RECOVERY_TMP of=/dev/block/bootdevice/by-name/recovery_ramdisk"
#$ADB shell "dd if=$RECOVERY2_TMP of=/dev/block/mmcblk0p22 bs=1048576"
$ADB shell "dd if=$RECOVERY2_TMP of=/dev/block/bootdevice/by-name/erecovery_ramdisk" # a.k.a. recovery2
$ADB shell "echo --update_package=$TARGET_UPDATE > /cache/recovery/command"
$ADB shell "echo --update_package=$TARGET_UPDATE_DATA >> /cache/recovery/command"
$ADB shell "echo --update_package=$TARGET_UPDATE_HW >> /cache/recovery/command"
$ADB reboot recovery

echo
pause "Done! The system update should start automatically."




