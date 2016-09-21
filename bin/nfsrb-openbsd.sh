#!/usr/bin/env sh

# build NFS root file system for OpenBSD ((pdk)sh version)
#
# should work on:
# * Linux with:
#   * dash as sh
#   * bash as sh (maybe)
# * OpenBSD with:
#   * pdksh as sh
# * NetBSD with
#   * posix shell as sh

:<<COPYRIGHT

Copyright (C) 2014-2016 Frank Scheiner

The program is distributed under the terms of the GNU General Public License

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

COPYRIGHT

################################################################################
# DEFINES
################################################################################

readonly _program="nfsrb-openbsd"

readonly _version="0.8.0"

readonly _exit_usage=64

readonly _true=1
readonly _false=0

# Prior to OpenBSD 5.7, the etc set is separate from the base set
_openBsdDefaultSets="base etc"

# Since OpenBSD 5.7, the etc set is included in the base set
_openBsdDefaultSetsSince57="base"

# Minimum OpenBSD version with signify support for downloads
_signifySupportSince="55"

# Minimum OpenBSD version which was supplied with a hashfile
_hashFileSince="46"

# Signature file name
_signatureFile="SHA256.sig"

# File containing the build date
_buildinfoFile="BUILDINFO"

# File containing the hashes
_hashFile="SHA256"

__GLOBAL__cwd="$PWD"

################################################################################
# FUNCTIONS
################################################################################

usageMsg()
{
	cat 1>&2 <<-USAGE
		Usage: $_program "configurationFile"
	USAGE

	return
}


isValidFileForSignify()
{
	local _openBsdVersionNonDotted="$1"
	local _signatureFile="$2"
	local _file="$3"

	if signify -C -p "/etc/signify/openbsd-${_openBsdVersionNonDotted}-base.pub" -x "$_signatureFile" "$_file" 1>/dev/null 2>&1; then

		return 0
	else
		return 1
	fi
}


isValidFileForSha256()
{
	local _hashFile="$1"
	local _file="$2"

	local _tempHashFile=$( mktemp )
	local _validityCheckReturned=1

	grep "($_file)" "$_hashFile" > "$_tempHashFile"

	if [ $( uname -s ) = "OpenBSD" ]; then

		sha256 -c "$_tempHashFile" 1>/dev/null 2>&1

	elif [ $( uname -s ) = "NetBSD" ]; then

		cksum -c -a SHA256 "$_tempHashFile" 1>/dev/null 2>&1

	elif [ $( uname -s ) = "Linux" ]; then

		sha256sum -c "$_tempHashFile" 1>/dev/null 2>&1
	fi

	_validityCheckReturned=$?

	rm "$_tempHashFile"

	return $_validityCheckReturned
}


downloadFile()
{
	local _file="$1"

	local _ftpReturned=1

	if [ $( uname -s ) = "OpenBSD" ]; then

		ftp -C "$_file"
		_ftpReturned=$?

		if [ $_ftpReturned -eq 0 -o \
		     $_ftpReturned -eq 1 ]; then

			# ftp on OpenBSD exits with 1 if a file was already downloaded
			# completely. Hence let's assume 0 and 1 as sane exit value.
			true
		else
			false
		fi

	elif [ $( uname -s ) = "NetBSD" ]; then

		ftp "$_file"

	elif [ $( uname -s ) = "Linux" ]; then

		# check if wget is available
		if which wget 1>/dev/null 2>&1; then

			wget -4 --progress=bar -c "$_file"

		elif which curl 1>/dev/null 2>&1; then

			# Actually curl should continue to download a partially downloaded file
			# with `-C -`, but during my tests it didn't. even when using `-o` and
			# the file name of the partially downloaded file.
			curl -O -C - "$_file"
		else
			echo "$_program: Neither wget nor curl found." 1>&2
			return 1
		fi
	fi

	return
}


untarFile()
{
	local _tarFile="$1"

	local _tarCommand=""

	if [ $( uname -s ) = "OpenBSD" -o \
	     $( uname -s ) = "NetBSD" ]; then

		_tarCommand="tar -xzpf $_tarFile"

	elif [ $( uname -s ) = "Linux" ]; then

		_tarCommand="tar --numeric-owner -xzpf $_tarFile"
	fi

	echo "$_tarCommand" >"$__GLOBAL__cwd/untarFile.log"
	$_tarCommand 1>>"$__GLOBAL__cwd/untarFile.log" 2>&1

	if [ $? -eq 0 ]; then

		rm "$__GLOBAL__cwd/untarFile.log"
		return 0
	else
		return 1
	fi
}


createSwapFile()
{
	local _swapFile="$1"
	local _swapFileSize="$2"

	local _blockSize="1M"

	if [ $( uname -s ) = "OpenBSD" -o \
	     $( uname -s ) = "Linux" ]; then

		_ddCommand="dd if=/dev/zero of="$_swapFile" bs=1M seek="$_swapFileSize" count=0"

	# NetBSD uses "m" for Mebibyte and cannot create sparse files AFAICS
	elif [ $( uname -s ) = "NetBSD" ]; then

		_ddCommand="dd if=/dev/zero of="$_swapFile" bs=1m seek="$(( $_swapFileSize - 1 ))" count=1"
	fi

	echo "$_ddCommand" >"$__GLOBAL__cwd/swapFileCreation.log"
	$_ddCommand 1>>"$__GLOBAL__cwd/swapFileCreation.log" 2>&1 && chmod 0600 swap

	return
}


getVersionFromSignatureFile()
{
	local _signatureFile="$1"

	local _openBsdVersionNonDotted=""

	_openBsdVersionNonDotted=$( grep '(base' < "$_signatureFile" | sed -e 's/^.* (//' -e 's/) .*$//' | sed -e 's/^base//' -e 's/.tgz//' )

	if [ $? -eq 0 ]; then

		echo $_openBsdVersionNonDotted
		return 0
	else
		return 1
	fi
}


getBuildDateFromBuildinfoFile()
{
	local _buildinfoFile="$1"

	local _buildDate=""

	_buildDate=$( head -1 "$_buildinfoFile" | cut -d ' ' -f 3 )

	if [ $? -eq 0 ]; then

		echo $_buildDate
		return 0
	else
		return 1
	fi
}


nonDottedToDotted()
{
	local _openBsdVersionNonDotted="$1"

	local _openBsdVersion=""

	local _length=${#_openBsdVersionNonDotted}

	_openBsdVersion=$( echo $_openBsdVersionNonDotted | cut -c 1-$(( _length - 1 )) ).$( echo $_openBsdVersionNonDotted | cut -c $_length)

	if [ $? -eq 0 ]; then

		echo $_openBsdVersion
		return 0
	else
		return 1
	fi
}


################################################################################
# MAIN
################################################################################

if [ "EMPTY${1}" = "EMPTY" ]; then

	usageMsg
	exit $_exit_usage
fi

_configurationFile="$1"

if [ -e "$PWD/$_configurationFile" ]; then

	_configurationFile="./$_configurationFile"
fi

. "$_configurationFile"

# TODO:
# Check at least that needed variables have some content.

_downloadBasePath="${_downloadMirror}/${_openBsdVersion}/${_openBsdPlatform}"

echo "$_program: Now downloading files..."

# For snapshots create per build date directory structures
if [ $_openBsdVersion = "snapshots" ]; then

	# Get build date
	_file="${_downloadBasePath}/${_buildinfoFile}"

	if ! downloadFile "$_file"; then

		echo -e "$_program: Download failed for "$_file". Cannot continue! Exiting." 1>&2
		exit 1
	fi

	_buildDate=$( getBuildDateFromBuildinfoFile "./${_buildinfoFile}" )

	if [ $? -ne 0 ]; then

		echo -e "$_program: Couldn't get build date from \`$PWD/${_buildinfoFile}'. Cannot continue! Exiting." 1>&2
		exit 1
	fi
	_basePath="${_basePathPrefix}/openbsd/${_openBsdVersion}/${_buildDate}/${_openBsdPlatform}/${_hostname}"
else
	# Get build date
	_file="${_downloadBasePath}/${_buildinfoFile}"

	# Older OpenBSD versions do not have the "BUILDINFO" file, so just detemine the buildinfo if
	# this file could be downloaded successfully.
	if downloadFile "$_file"; then

		_buildDate=$( getBuildDateFromBuildinfoFile "./${_buildinfoFile}" )
	fi

	_basePath="${_basePathPrefix}/openbsd/${_openBsdVersion}/${_openBsdPlatform}/${_hostname}"
fi

# Save files in the super directory
mkdir -p "$_basePath" && cd "$_basePath/.."

if [ $_openBsdVersion = "snapshots" ]; then

	mv "${__GLOBAL__cwd}/${_buildinfoFile}" .

	# currently - February 2016 - snapshot versions are > OpenBSD 5.5, so
	# always have a signature file
	_file="${_downloadBasePath}/${_signatureFile}"

	if ! downloadFile "$_file"; then

		echo -e "$_program: Download failed for "$_file". Cannot continue! Exiting." 1>&2
		exit 1
	fi

	_openBsdVersionNonDotted=$( getVersionFromSignatureFile "$_signatureFile" )

	_file="${_downloadBasePath}/${_hashFile}"

	if ! downloadFile "$_file"; then

		echo -e "$_program: Download failed for "$_file". Cannot continue! Exiting." 1>&2
		exit 1
	fi
else
	_openBsdVersionNonDotted=$( echo "$_openBsdVersion" | tr -d '.' )

	if [ $_openBsdVersionNonDotted -ge $_signifySupportSince ]; then

		_file="${_downloadBasePath}/${_signatureFile}"

		if ! downloadFile "$_file"; then

			echo -e "$_program: Download failed for "$_file". Cannot continue! Exiting." 1>&2
			exit 1
		fi

		_file="${_downloadBasePath}/${_hashFile}"

		if ! downloadFile "$_file"; then

			echo -e "$_program: Download failed for "$_file". Cannot continue! Exiting." 1>&2
			exit 1
		fi
	elif [ $_openBsdVersionNonDotted -ge $_hashFileSince ]; then
		_file="${_downloadBasePath}/${_hashFile}"

		if ! downloadFile "$_file"; then

			echo -e "$_program: Download failed for "$_file". Cannot continue! Exiting." 1>&2
			exit 1
		fi
	else
		:
	fi
fi

# Combine default and additional sets
if [ $_openBsdVersionNonDotted -lt 57 ]; then

	_setsToDownload="$_openBsdDefaultSets $_additionalSetsToDownload"
else
	_setsToDownload="$_openBsdDefaultSetsSince57 $_additionalSetsToDownload"
fi

for _set in $_setsToDownload; do

	_fileName="${_set}${_openBsdVersionNonDotted}.tgz"

	_file="${_downloadBasePath}/${_fileName}"

	if ! downloadFile "$_file"; then

		echo -e "$_program: Download failed for "$_file". Cannot continue! Exiting." 1>&2
		exit 1
	fi
done

if ! downloadFile "${_downloadBasePath}/${_kernelToUse}"; then

	echo -e "$_program: Download failed for "${_downloadBasePath}/${_kernelToUse}". Cannot continue! Exiting." 1>&2
	exit 1
fi

echo "$_program: Finished."

# Perform validity and signature test only, if files are from OpenBSD 5.5 or
# newer and if the signify tool is available.
_invalidFiles=$_false

if [ $_openBsdVersionNonDotted -ge $_signifySupportSince -a \
     -e "/etc/signify/openbsd-$_openBsdVersionNonDotted-base.pub" ] && \
   which signify 1>/dev/null 2>&1; then

	echo "$_program: Checking validity of files with signify..."
	for _set in $_setsToDownload; do

		_fileName="${_set}${_openBsdVersionNonDotted}.tgz"

		_file="${_downloadBasePath}/${_fileName}"

		# check validity
		if ! isValidFileForSignify "$_openBsdVersionNonDotted" "$_signatureFile" "$_fileName"; then

			echo "\`${_fileName}' is invalid."
			_invalidFiles=$_true
		else
			echo "\`${_fileName}' is valid."
		fi
	done

	if ! isValidFileForSignify "$_openBsdVersionNonDotted" "$_signatureFile" "$_kernelToUse"; then

		echo "\`${_kernelToUse}' is invalid."
		_invalidFiles=$_true
	else
		echo "\`${_kernelToUse}' is valid."
	fi

	echo "Finished."

	if [ $_invalidFiles -eq $_true ]; then

		echo "$_program: Detected invalid files. Cannot continue. Please delete invalid file(s) and try again."
		exit 1
	fi

# Just do validity test
elif [ $_openBsdVersionNonDotted -ge $_hashFileSince ]; then
	echo "$_program: Signify public keys missing for OpenBSD $_openBsdVersion or not running under OpenBSD."
	echo "$_program: Checking validity of files with SHA256 hashes..."
	for _set in $_setsToDownload; do

		_fileName="${_set}${_openBsdVersionNonDotted}.tgz"

		_file="${_downloadBasePath}/${_fileName}"

		# check validity
		if ! isValidFileForSha256 "$_hashFile" "$_fileName"; then

			echo "\`${_fileName}' is invalid."
			_invalidFiles=$_true
		else
			echo "\`${_fileName}' is valid."
		fi
	done

	if ! isValidFileForSha256 "$_hashFile" "$_kernelToUse"; then

		echo "\`${_kernelToUse}' is invalid."
		_invalidFiles=$_true
	else
		echo "\`${_kernelToUse}' is valid."
	fi

	echo "Finished."

	if [ $_invalidFiles -eq $_true ]; then

		echo "$_program: Detected invalid files. Cannot continue. Please delete invalid file(s) and try again."
		exit 1
	fi
else
	:
fi

# Return to base path
cd "$_basePath"

#echo "=> $PWD"

echo -n "$_program: Creating swap file... "

createSwapFile "$_basePath/swap" "$_swapFileSize"

if [ $? -eq 0 ]; then

	rm "$__GLOBAL__cwd/swapFileCreation.log"
	echo "OK"
else
	echo "ERROR. More details in \`$__GLOBAL__cwd/swapFileCreation.log'."
	exit 1
fi

mkdir -p "root" && cd "root"

if [ $_openBsdVersionNonDotted -lt 57 ]; then

	for _set in $_setsToDownload; do

		echo -n "$_program: Now extracting ${_set}${_openBsdVersionNonDotted}.tgz... "
		if untarFile ../../${_set}${_openBsdVersionNonDotted}.tgz; then

			echo "OK"
		else
			echo "ERROR. More details in \`$__GLOBAL__cwd/untarFile.log'."
			exit 1
		fi
	done

else
	for _set in $_setsToDownload; do

                echo -n "$_program: Now extracting ${_set}${_openBsdVersionNonDotted}.tgz... "
                if untarFile ../../${_set}${_openBsdVersionNonDotted}.tgz; then

	                echo "OK"
		else
			echo "ERROR. More details in \`$__GLOBAL__cwd/untarFile.log'."
			exit 1
		fi
        done
	echo -n "$_program: Now extracting builtin etc.tgz... "

	# the position of the builtin etc set changes/d with OpenBSD 5.9
	if [ $_openBsdVersionNonDotted -lt 59 ]; then

		_builtinEtcSet="./usr/share/sysmerge/etc.tgz"
	else
		_builtinEtcSet="./var/sysmerge/etc.tgz"
	fi

	if untarFile "$_builtinEtcSet"; then

		echo "OK"
	else
		echo "ERROR. More details in \`$__GLOBAL__cwd/untarFile.log'."
		exit 1
	fi
fi

cd ..

_rootOfFileSystem="$PWD/root"

cd "$_rootOfFileSystem"

echo "$_program: Now configuring file system... "

# Configure file system
mkdir -p swap && chmod 0700 swap

echo -n "$_program: Creating devices... "
cd "dev"
if [ $( uname -s ) = "OpenBSD" ]; then

	./MAKEDEV all
	echo "OK"
else
	mknod console c 0 0 && chmod og-r console
	echo "$_program: Only created \`/dev/console' as we're not running under OpenBSD. Please use root FS in single user mode and create devices manually (\`mount -uw / && cd /dev && ./MAKEDEV all\`) before going multi-user."
fi

cd "$_rootOfFileSystem"


echo -n "$_program: Creating \`/etc/fstab'... "
cat > etc/fstab <<-EOF
	${_nfsServerAddress}:${_basePath}/root / nfs rw,tcp,nfsv3 0 0
	${_nfsServerAddress}:${_basePath}/swap none swap sw,nfsmntpt=/swap,tcp
EOF
echo "OK"


echo -n "$_program: Creating \`/etc/myname'... "
echo "${_hostname}.${_domain}" > etc/myname
echo "OK"


echo -n "$_program: Creating \`/etc/hosts'... "
cat > etc/hosts <<-EOF
	127.0.0.1       localhost
	::1             localhost6

	${_ipAddress} ${_hostname}.${_domain} ${_hostname}
EOF
echo "OK"


echo -n "$_program: Creating \`/etc/mygate'... "
echo "$_gatewayAddress" > etc/mygate
echo "OK"


echo -n "$_program: Creating \`/etc/resolv.conf'... "
cat > etc/resolv.conf <<-EOF
	nameserver ${_dnsServerAddress}
	domain ${_domain}
	search ${_domain}
EOF
echo "OK"

# Do not create this file on the OpenBSD platform "i386", as there the
# existence of this file prevented a successful network boot during all
# my tests
if [ "$_openBsdPlatform" != "i386" ]; then
	echo -n "$_program: Creating \`/etc/hostname.${_bootNetworkInterface}'... "
	echo "inet $_ipAddress" > "etc/hostname.${_bootNetworkInterface}"
	chmod 0640 "etc/hostname.${_bootNetworkInterface}"
	echo "OK"
else
	echo "$_program: \`/etc/hostname.${_bootNetworkInterface}' not created because platform is \"i386\""
fi


echo -n "$_program: Installing kernel... "
cp ../../${_kernelToUse} .
if [ "${_kernelToUse}" != "bsd" ]; then
	ln -s ${_kernelToUse} bsd
fi
echo "OK"

# This is needed for gen-keys-openbsd to be able to generate the correct
# keys depending on the version of the target OS. In addition its also
# useful to quickly determine the version of the target OS if it is not
# running and if it is not stored in a directory hierarchy that shows
# the version.
echo -n "$_program: Placing OpenBSD version number and build date in \`${_rootOfFileSystem}/etc/openbsd_version'... "
echo "$( nonDottedToDotted $_openBsdVersionNonDotted ) ($_buildDate)" > "$_rootOfFileSystem/etc/openbsd_version"
echo "OK"

# Place info about the used nfsrb version in "/etc/nfsrb"
echo -n "$_program: Placing nfsrb version in \`${_rootOfFileSystem}/etc/nfsrb_version'... "
echo "$_version" > "${_rootOfFileSystem}/etc/nfsrb_version"
echo "OK"

exit

