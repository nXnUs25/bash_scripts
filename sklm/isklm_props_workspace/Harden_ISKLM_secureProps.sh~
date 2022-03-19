#!/bin/bash
# Name: Harden_ISKLM_secureProps.sh
# Author: Carl Moore
# Modified 2016-06-13
# Description: Adds more secure configurations to the ISKLM configuration file
# Usage: [workspace={script directory} newconfigs={New properties to add} configfile={existing config file location} tmpdir={temporary build directory} logfile={script log directory}] /Harden_ISKLM_secureProps.sh

if [- z "$workspace" ]; then workspace="~/isklm_workspace"
if [ -z "$newconfigs"]; then newconfigs="$workspace/newconfigs.properties"; fi
if [ -z "$configfile"]; then configfile="/opt/IBM/WebSphere/AppServer/products/sklm/config/SKLMConfig.properties"; fi
if [ -z "$tmpdir"]; then tmpdir="/tmp/buildconfig"; fi
if [ -z "$logfile"]; then logfile="/var/log/Harden_ISKLM_secureProps.log"; fi

exec > $logfile 2>&1
mkdir -p $tmpdir
rm -f $tmpdir/*
cp -f $newconfigs $tmpdir/isklm.properties.toadd
cp -f $configfile $tmpdir/isklm.properties.old
tmpold=$tmpdir/isklm.properties.old
tmpnew=$tmpdir/isklmproperties.toadd

cd $tmpdir

echo "Modifying existing configuration file found in $configfile"
echo "Reading new properties... from $newconfigs"

while IFS='' read -r line || [[ -n "$line" ]]
do
	prop=$(echo $line | cut -f1 -d\=)
	val=$(echo $line | cut -f2 -d\=)
	if grep -q $prop $tmpold
	then
	oldval=$(grep $prop $tmpold | cut -f2 -d\=)
	linenum=$(grep -n $prop $tmpold | cut -f1 -d:)
	echo "Found existing property: $prop, currently set to: $oldval, setting to: $val"
	sed -i ''"${linenum}"'s/.*/'"${line}"'/' ${tmpold}
	else
	echo "Found new property $prop, creating and setting to: $val"
	echo $line >> $tmpold
	fi
done < "$newconfigs"

echo "Backing up existing props file as $configfile.orig..."
mv $configfile $configfile.orig
mv $tmpold $configfile
echo "Checking regenerated config file for new values"
while IFS='' read -r line || [[ -n "$line" ]]
do
if grep -q $line $configfile
then
echo "New config $line confirmed"
else
echo "New config $line not found, an error has occurred, review log file at $logfile"
exit
fi
done < "$newconfigs"
echo "Removing temporary directories"
rm -rf $tmpdir
echo "All completed successfully..."
