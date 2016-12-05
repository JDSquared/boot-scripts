#!/bin/sh -e

#Regenerate ssh host keys
if [ -f /etc/ssh/ssh.regenerate ] ; then
	echo "generic-board-startup: regenerating ssh keys"
	systemctl stop sshd
	rm -rf /etc/ssh/ssh_host_* || true

	if [ -e /dev/hwrng ] ; then
		# Mix in the output of the HWRNG to the kernel before generating ssh keys
		dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096 2>/dev/null
		echo "generic-board-startup: if=/dev/hwrng of=/dev/urandom count=1 bs=4096"
	else
		echo "generic-board-startup: WARNING /dev/hwrng wasn't available"
	fi

	dpkg-reconfigure openssh-server
	sync
	if [ -s /etc/ssh/ssh_host_ed25519_key.pub ] ; then
		rm -f /etc/ssh/ssh.regenerate || true
		sync
		systemctl start sshd
	fi
fi

#Regenerate mkuuid and turn on remote access
if [ -f /etc/mkuuid.regenerate ] ; then
	echo "generic-board-startup: regenerating mkuuid"
	UUID=`uuidgen`

	# two machinekit.ini files on install, check for both
	if [ -s /etc/linuxcnc/machinekit.ini ] ; then
		sed -i "s|a42c8c6b-4025-4f83-ba28-dad21114744a|$UUID|" /etc/linuxcnc/machinekit.ini
		sed -i "s|REMOTE=0|REMOTE=1|" /etc/linuxcnc/machinekit.ini

	fi

	if [ -s /home/mdadmn/machinekit/etc/linuxcnc/machinekit.ini ] ; then
		sed -i "s|a42c8c6b-4025-4f83-ba28-dad21114744a|$UUID|" /home/mdadmn/machinekit/etc/linuxcnc/machinekit.ini
		sed -i "s|REMOTE=0|REMOTE=1|" /home/mdadmn/machinekit/etc/linuxcnc/machinekit.ini
	fi

	# Restart mkl if it is running
	rm -f /etc/mkuuid.regenerate || true
	sync

	if ! systemctl is-active mkl.service; then
		systemctl stop mkl.service
		sleep 1
		systemctl start mkl.service
	fi
fi

# Copy the config directory to tmpfs
if [ -d "/home/mdadmn/machinekit/configs/by_machine/jd2" ]; then
	echo "generic-board-startup: setting up config directory"
	cp -r "/home/mdadmn/machinekit/configs/by_machine/jd2" /tmp/
	chown -R mdadmn:mdadmn /tmp/jd2
	# Create the symlink if it doesn't exist already
	if [ ! -L "/home/mdadmn/jd2" ] ; then
		ln -s "/tmp/jd2" "/home/mdadmn/jd2"
		chown -h  mdadmn:mdadmn /home/mdadmn/jd2
	fi
fi

# Check for an update folder
if [ -d "/home/mdadmn/update" ]; then
    chmod +x "/home/mdadmn/update/update.sh"
    /bin/bash "/home/mdadmn/update/update.sh"
    rm -rf "/home/mdadmn/update" || true
	sync
fi

# Timectl setup
echo "generic-board-startup: setting time parameters"
timedatectl set-ntp no
timedatectl set-timezone 'America/New_York'
