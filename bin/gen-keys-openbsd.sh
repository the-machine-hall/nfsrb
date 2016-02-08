#!/usr/bin/env sh

# generate OpenSSL/OpenSSH keys for NFS root file system for OpenBSD (pdksh
# version)

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

readonly _program="generate-keys"

readonly _version="0.3.0"

readonly _exit_usage=64

readonly _true=1
readonly _false=0

################################################################################
# FUNCTIONS
################################################################################

usageMsg()
{
	cat 1>&2 <<-USAGE
	Usage: $_program "rootOfFileSystem"
	USAGE
	
	return
}


# From `/etc/rc`
generateOpensslKey()
{
	local _baseDir="$1"
	
	umask 0077

	# Don't overwrite existing key files
	if [ -s "${_baseDir}/etc/isakmpd/private/local.key" ]; then

		return 3
	fi

	if openssl genrsa -out "${_baseDir}/etc/isakmpd/private/local.key" 2048 \
	                  1>/dev/null 2>&1; then
	    
		openssl rsa -out "${_baseDir}/etc/isakmpd/local.pub" \
		            -in "${_baseDir}/etc/isakmpd/private/local.key" \
		            -pubout 1>/dev/null 2>&1		
		return
	else
		return 1
	fi
}


generateOpensshKey()
{
	local _baseDir="$1"
	local _keyType="$2"

	local _keyFile=$( getFileNameForKeyType $_keyType )
	
	umask 0077
	
	# Don't overwrite existing key files
	if [ -s "${_baseDir}/etc/ssh/$_keyFile" ]; then

		return 3
	fi

	if ssh-keygen -q -t "$_keyType" -N "" -f "${_baseDir}/etc/ssh/$_keyFile" 1>"$__GLOBAL__cwd/_sshKeygenOutput" 2>&1; then

		chmod og+r "${_baseDir}/etc/ssh/${_keyFile}.pub"
		rm "$__GLOBAL__cwd/_sshKeygenOutput"
		return 0
	else
		if grep "unknown key type" "$__GLOBAL__cwd/_sshKeygenOutput" 1>/dev/null 2>&1; then

			return 2
		else
			return 1
		fi
	fi
}


getOpensshKeyTypes()
{
	local _openbsdVersionNonDotted="$1"
	
	local _opensshKeyTypes54="rsa1 dsa ecdsa rsa"
                              
	local _opensshKeyTypes55="rsa1 dsa ecdsa ed25519 rsa"

	local _opensshKeyTypes56="$_opensshKeyTypes55"

	local _opensshKeyTypes57="$_opensshKeyTypes55"

	local _opensshKeyTypes58="dsa ecdsa ed25519 rsa"

	local _opensshKeyTypes59="$_opensshKeyTypes58"

	if [ $_openbsdVersionNonDotted -eq 54 ]; then

		_opensshKeyTypes="$_opensshKeyTypes54"
	
	elif [ $_openbsdVersionNonDotted -eq 55 ]; then

		_opensshKeyTypes="$_opensshKeyTypes55"

	elif [ $_openbsdVersionNonDotted -eq 56 ]; then

		_opensshKeyTypes="$_opensshKeyTypes56"

	elif [ $_openbsdVersionNonDotted -eq 57 ]; then

		_opensshKeyTypes="$_opensshKeyTypes57"

	elif [ $_openbsdVersionNonDotted -eq 58 ]; then

		_opensshKeyTypes="$_opensshKeyTypes58"

	elif [ $_openbsdVersionNonDotted -eq 59 ]; then

		_opensshKeyTypes="$_opensshKeyTypes59"
	else
		return 1
	fi
	
	echo "$_opensshKeyTypes"
	return 0
}


getFileNameForKeyType()
{
	local _keyType="$1"
	
	local _fileName=""
	
	if [[ "$_keyType" == "rsa1" ]]; then
	
		_fileName="ssh_host_key"

	elif [[ "$_keyType" == "dsa" ]]; then

		_fileName="ssh_host_dsa_key"

	elif [[ "$_keyType" == "ecdsa" ]]; then

		_fileName="ssh_host_ecdsa_key"

	elif [[ "$_keyType" == "ed25519" ]]; then

		_fileName="ssh_host_ed25519_key"

	elif [[ "$_keyType" == "rsa" ]]; then

		_fileName="ssh_host_rsa_key"
	else
		return 1
	fi
	
	echo "$_fileName"
	
	return 0
}


################################################################################
# MAIN
################################################################################

if [[ $1 == "" ]]; then
	usageMsg
	exit $_exit_usage
fi

_rootOfFileSystem="$1"

if [[ ! -d "$_rootOfFileSystem" ]]; then

	echo "\"$_rootOfFileSystem\" is not a directory. Exiting."
	exit 1
	
elif [[ ! -d "$_rootOfFileSystem/etc" ]]; then

	echo "No \"etc\" directory found in \"$_rootOfFileSystem\". Please create a file system first. Exiting."
	exit 1
else
	_openbsdVersionTarget=$( cat "$_rootOfFileSystem/etc/openbsd_version" )
	_openbsdVersionNonDottedTarget=$( echo "$_openbsdVersionTarget"  | tr -d '.' ) # "55"
	
	_openbsdVersionHost=$( uname -r )
	_openbsdVersionNonDottedHost=$( echo "$_openbsdVersionHost" | tr -d '.' )
	
	if [[ $_openbsdVersionNonDottedHost -lt $_openbsdVersionNonDottedTarget ]]; then
		_openbsdVersionNonDotted=$_openbsdVersionNonDottedHost
		echo "Warning: Host OS version is smaller than target OS version. Using available SSH key types of host OS only."
	else
		_openbsdVersionNonDotted=$_openbsdVersionNonDottedTarget
	fi		
fi

echo -n "openssl: generating isakmpd/iked RSA key... "
if generateOpensslKey "$_rootOfFileSystem"; then

	echo "OK"
else
	echo "failed"
fi


echo -n "ssh-keygen: generating openssh keys... "

for _keyType in $( getOpensshKeyTypes "$_openbsdVersionNonDotted" ); do

	if generateOpensshKey "$_keyType" "${_rootOfFileSystem}/etc/ssh/$( getFileNameForKeyType $_keyType )"; then

		echo -n "${_keyType} "
	else
		echo -n "${_keyType} failed "
	fi
done

echo "OK"

exit

