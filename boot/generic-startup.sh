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

#Resize drive when requested
if [ -f /resizerootfs ] ; then
	echo "generic-board-startup: resizerootfs"
	drive=$(cat /resizerootfs)
	if [ ! "x${drive}" = "x" ] ; then
		if [ "x${drive}" = "x/dev/mmcblk0" ] || [ "x${drive}" = "x/dev/mmcblk1" ] ; then
			resize2fs ${drive}p2 >/var/log/resize.log 2>&1 || true
		else
			resize2fs ${drive} >/var/log/resize.log 2>&1 || true
		fi
	fi
	rm -rf /resizerootfs || true
	sync
fi

	if [ -f "/opt/scripts/boot/${script}" ] ; then
		echo "generic-board-startup: [startup script=/opt/scripts/boot/${script}]"
		/bin/sh /opt/scripts/boot/${script}
	fi
fi

# Copy the config directory to tmpfs
if [ -d "/home/mdadmn/machinekit/configs/jd2" ]; then
	echo "generic-board-startup: setting up config directory"
	cp -r "/home/mdadmn/machinekit/configs/jd2" /tmp/
	# Create the symlink if it doesn't exist already
	if [ ! -L "/home/mdadmn/jd2" ] ; then
		ln -s "/tmp/jd2" "/home/mdadmn/jd2"
	fi
fi

# Apply an update if one is available
if [ -d "/home/mdadmn/update" ]; then
	echo "generic-board-startup: Applying update"
	chmod +x "/home/mdadmn/update/update.sh"
	/bin/bash "/home/mdadmn/update/update.sh"
	rm -rf "/home/mdadmn/update"
fi
