#!/usr/bin/env bash

# build NFS root file system for OpenBSD

:<<COPYRIGHT

Copyright (C) 2014-2015 Frank Scheiner

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

readonly _version="0.5.0"

readonly _exit_usage=64

readonly _true=1
readonly _false=0

readonly _openBsdDefaultSets=( base
                               etc )

readonly _openBsdDefaultSetsSince57=( base )

################################################################################
# FUNCTIONS
################################################################################

usageMsg()
{
	cat >&2 <<-USAGE
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
	           -x "$_signatureFile" "$_file" &>/dev/null; then
	
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
	
	grep "($_file)" "$_hashFile" > "$_tempHashFile"
	
	if sha256 -c "$_tempHashFile" &>/dev/null; then

		rm "$_tempHashFile"

		return 0
	else
		rm "$_tempHashFile"

		return 1
	fi		
}


downloadFileWithWget()
{
	local _file="$1"
	
	#wget -q -c "$_file"
	wget -4 --progress=bar -c "$_file"
	
	return
}


downloadFileWithFtp()
{
	local _file="$1"

	ftp -C "$_file"

	return
}


downloadFile()
{
	if which wget &>/dev/null; then

		downloadFileWithWget $@
	else
		downloadFileWithFtp $@
	fi
}


################################################################################
# MAIN
################################################################################

if [[ $1 == "" ]]; then

	usageMsg
	exit $_exit_usage
fi

_configurationFile="$1"

. "$_configurationFile"


_openBsdVersionNonDotted=${_openBsdVersion/./} # "55"

# Minimum OpenBSD version with signify support for downloads
_minimumOpenBsdVersionNonDotted="55"

# Signature file name
_signatureFile="SHA256.sig"

# File containing the hashes
_hashFile="SHA256"

# Combine default and additional sets
if [[ $_openBsdVersionNonDotted -lt 57 ]]; then

	_setsToDownload=( "${_openBsdDefaultSets[@]}" "${_additionalSetsToDownload[@]}" )
else
	_setsToDownload=( "${_openBsdDefaultSetsSince57[@]}" "${_additionalSetsToDownload[@]}" )
fi

_downloadBasePath="${_downloadMirror}/${_openBsdVersion}/${_openBsdPlatform}"

# Save files in the super directory
mkdir -p "$_basePath" && cd "$_basePath/.."

echo "Now downloading files..."

for _set in "${_setsToDownload[@]}"; do

	_fileName="${_set}${_openBsdVersionNonDotted}.tgz"
	
	_file="${_downloadBasePath}/${_fileName}"

	# Always download files. Let the downloader detect if file was
	# downloaded completely.
	#if [[ ! -e "$_fileName" ]]; then

		downloadFile "$_file"
	#fi
done

# Always download files. Let the downloader detect if file was downloaded
# completely.
#if [[ ! -e "$_kernelToUse" ]]; then
	downloadFile "${_downloadBasePath}/${_kernelToUse}"
#fi

echo "Finished."

# Perform validity and signature test only, if files are from OpenBSD 5.5 or
# newer and if the signify tool is available.
if test $_openBsdVersionNonDotted -ge $_minimumOpenBsdVersionNonDotted && \
   which signify &>/dev/null; then

	downloadFile "${_downloadBasePath}/${_signatureFile}"

	_invalidFiles=$false

	echo "Checking validity of files with signify..."
	for _set in "${_setsToDownload[@]}"; do
	
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
	
	if [[ $_invalidFiles -eq $_true ]]; then

		echo "Detected invalid files. Cannot continue. Please delete invalid file(s) and try again."
		exit 1
	fi
# Just do validity test
else
	downloadFile "${_downloadBasePath}/${_hashFile}"
	
	_invalidFiles=$false
	
	echo "Checking validity of files with sha256..."
	for _set in "${_setsToDownload[@]}"; do
	
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
	
	if [[ $_invalidFiles -eq $_true ]]; then

		echo "Detected invalid files. Cannot continue. Please delete invalid file(s) and try again."
		exit 1
	fi
fi

# Return to base path
cd "$_basePath"

#echo "=> $PWD"

echo "Creating swap file"
dd if=/dev/zero of=swap bs=1M seek=128 count=0 2>/dev/null
echo "Finished."

mkdir -p "root" && cd "root"
if [[ $_openBsdVersionNonDotted -lt 57 ]]; then

	for _set in "${_setsToDownload[@]}"; do

		echo -n "Now extracting ${_set}${_openBsdVersionNonDotted}.tgz... "
		tar -xzpf ../../${_set}${_openBsdVersionNonDotted}.tgz
		echo "OK"
	done
else
	for _set in "${_setsToDownload[@]}"; do

                echo -n "Now extracting ${_set}${_openBsdVersionNonDotted}.tgz... "
                tar -xzpf ../../${_set}${_openBsdVersionNonDotted}.tgz
                echo "OK"
        done
	echo -n "Now extracting builtin etc.tgz... "
	tar -xzpf ./usr/share/sysmerge/etc.tgz
	echo "OK"
fi
cd ..


_rootOfFileSystem="$PWD/root"

cd "$_rootOfFileSystem"

echo "Now configuring file system... "

# Configure file system
mkdir -p swap


echo -n "Creating devices... "

cd "dev"
./MAKEDEV all
echo "OK"


cd "$_rootOfFileSystem"


echo -n "Creating /etc/fstab... "
cat > etc/fstab <<-EOF
${_nfsServerAddress}:${_basePath}/root / nfs rw,tcp,nfsv3 0 0
${_nfsServerAddress}:${_basePath}/swap none swap sw,nfsmntpt=/swap,tcp
EOF
echo "OK"


echo -n "Creating /etc/myname... "
echo "${_hostname}.${_domain}" > etc/myname
echo "OK"


echo -n "Copying /etc/hosts from host... "
cp /etc/hosts etc/hosts
echo "OK"


echo -n "Creating /etc/hostname.[...]... "
echo "inet $_ipAddress" > "etc/hostname.${_bootNetworkInterface}"
chmod 0640 "etc/hostname.${_bootNetworkInterface}"
echo "OK"


echo -n "Installing kernel... "
cp ../../${_kernelToUse} .
if [[ "${_kernelToUse}" != "bsd" ]]; then
	ln -s ${_kernelToUse} bsd
fi
echo "OK"

echo -n "Placing OpenBSD version number in \`${_rootOfFileSystem}/etc/openbsd_version'... "
echo "$_openBsdVersion" > "$_rootOfFileSystem/etc/openbsd_version"
echo "OK"

exit

