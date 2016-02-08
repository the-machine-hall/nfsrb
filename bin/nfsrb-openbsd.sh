#!/usr/bin/env sh

# build NFS root file system for OpenBSD (pdksh version)

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

readonly _program="build-nfs-root"

readonly _version="0.7.0"

readonly _exit_usage=64

readonly _true=1
readonly _false=0

_openBsdDefaultSets="base etc"

_openBsdDefaultSetsSince57="base"

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
	
	if signify -C -p "/etc/signify/openbsd-${_openBsdVersionNonDotted}-base.pub" \
	           -x "$_signatureFile" "$_file" 1>/dev/null 2>&1; then
	
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

	echo "$_tarCommand" > "$__GLOBAL__cwd/untarFile.log"
	$_tarCommand 1>>"$__GLOBAL__cwd/untarFile.log" 2>&1

	if [ $? -eq 0 ]; then

		rm "$__GLOBAL__cwd/untarFile.log"
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


_openBsdVersionNonDotted=$( echo "$_openBsdVersion" | tr -d '.' )

echo "_openBsdVersionNonDotted: $_openBsdVersionNonDotted"

# Minimum OpenBSD version with signify support for downloads
_minimumOpenBsdVersionNonDotted="55"

# Signature file name
_signatureFile="SHA256.sig"

# File containing the hashes
_hashFile="SHA256"

# Combine default and additional sets
if [ $_openBsdVersionNonDotted -lt 57 ]; then

	_setsToDownload="$_openBsdDefaultSets $_additionalSetsToDownload"
	
else
	_setsToDownload="$_openBsdDefaultSetsSince57 $_additionalSetsToDownload"
fi

_downloadBasePath="${_downloadMirror}/${_openBsdVersion}/${_openBsdPlatform}"

# Save files in the super directory
mkdir -p "$_basePath" && cd "$_basePath/.."

echo "$_program: Now downloading files..."

for _set in $_setsToDownload; do

	_fileName="${_set}${_openBsdVersionNonDotted}.tgz"

	_file="${_downloadBasePath}/${_fileName}"

	downloadFile "$_file"

	if [ ! $? -eq 0 ]; then

		echo -e "$_program: Download failed for "$_file". Cannot continue! Exiting." 1>&2
		exit 1
	fi
done

downloadFile "${_downloadBasePath}/${_kernelToUse}"

if [ ! $? -eq 0 ]; then

	echo -e "$_program: Download failed for "${_downloadBasePath}/${_kernelToUse}". Cannot continue! Exiting." 1>&2
	exit 1
fi

echo "$_program: Finished."

# Perform validity and signature test only, if files are from OpenBSD 5.5 or
# newer and if the signify tool is available.
if test $_openBsdVersionNonDotted -ge $_minimumOpenBsdVersionNonDotted && \
   which signify 1>/dev/null 2>&1; then

	downloadFile "${_downloadBasePath}/${_signatureFile}"

	_invalidFiles=$false

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
else
	downloadFile "${_downloadBasePath}/${_hashFile}"
	
	_invalidFiles=$false
	
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
fi

# Return to base path
cd "$_basePath"

#echo "=> $PWD"

echo -n "$_program: Creating swap file... "
dd if=/dev/zero of=swap bs=1M seek=128 count=0 2>/dev/null && chmod 0600 swap
if [ $? -eq 0 ]; then
	echo "OK"
else
	echo "ERROR: More details in logfile."
	exit 1
fi

mkdir -p "root" && cd "root"
if [ $_openBsdVersionNonDotted -lt 57 ]; then

	for _set in $_setsToDownload; do

		echo -n "$_program: Now extracting ${_set}${_openBsdVersionNonDotted}.tgz... "
		if untarFile ../../${_set}${_openBsdVersionNonDotted}.tgz; then

			echo "OK"
		else
			echo "ERROR. More details in \`"$__GLOBAL__cwd/untarFile.log"'."
			exit 1
		fi
	done
else
	for _set in $_setsToDownload; do

                echo -n "$_program: Now extracting ${_set}${_openBsdVersionNonDotted}.tgz... "
                if untarFile ../../${_set}${_openBsdVersionNonDotted}.tgz; then

	                echo "OK"
		else
			echo "ERROR. More details in \`"$__GLOBAL__cwd/untarFile.log"'."
			exit 1
		fi
        done
	echo -n "$_program: Now extracting builtin etc.tgz... "
	if untarFile ./usr/share/sysmerge/etc.tgz; then

		echo "OK"
	else
		echo "ERROR. More details in \`"$__GLOBAL__cwd/untarFile.log"'."
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
./MAKEDEV all
echo "OK"


cd "$_rootOfFileSystem"


echo -n "$_program: Creating /etc/fstab... "
cat > etc/fstab <<EOF
${_nfsServerAddress}:${_basePath}/root / nfs rw,tcp,nfsv3 0 0
${_nfsServerAddress}:${_basePath}/swap none swap sw,nfsmntpt=/swap,tcp
EOF
echo "OK"


echo -n "$_program: Creating /etc/myname... "
echo "${_hostname}.${_domain}" > etc/myname
echo "OK"


echo -n "Copying /etc/hosts from host... "
cp /etc/hosts etc/hosts
echo "OK"


echo -n "$_program: Creating /etc/hostname.[...]... "
echo "inet $_ipAddress" > "etc/hostname.${_bootNetworkInterface}"
chmod 0640 "etc/hostname.${_bootNetworkInterface}"
echo "OK"


echo -n "$_program: Installing kernel... "
cp ../../${_kernelToUse} .
if [ "${_kernelToUse}" != "bsd" ]; then
	ln -s ${_kernelToUse} bsd
fi
echo "OK"

echo -n "$_program: Placing OpenBSD version number in \`${_rootOfFileSystem}/etc/openbsd_version'... "
echo "$_openBsdVersion" > "$_rootOfFileSystem/etc/openbsd_version"
echo "OK"

exit

