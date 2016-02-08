#!/usr/bin/env sh

# generate OpenSSL/OpenSSH keys for NFS root file system for OpenBSD (pdksh
# version)

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

readonly _program="gen-keys-openbsd"

readonly _version="0.4.0"

readonly _exit_usage=64

readonly _true=1
readonly _false=0

__GLOBAL__cwd="$PWD"

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
	
	if [ "$_keyType" = "rsa1" ]; then
	
		_fileName="ssh_host_key"

	elif [ "$_keyType" = "dsa" ]; then

		_fileName="ssh_host_dsa_key"

	elif [ "$_keyType" = "ecdsa" ]; then

		_fileName="ssh_host_ecdsa_key"

	elif [ "$_keyType" = "ed25519" ]; then

		_fileName="ssh_host_ed25519_key"

	elif [ "$_keyType" = "rsa" ]; then

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

if [ "EMPTY${1}" = "EMPTY" ]; then

	usageMsg
	exit $_exit_usage
fi

_rootOfFileSystem="$1"

if [ ! -d "$_rootOfFileSystem" ]; then

	echo "$_program: \"$_rootOfFileSystem\" is not a directory. Exiting."
	exit 1
	
elif [ ! -d "$_rootOfFileSystem/etc" ]; then

	echo "$_program: No \"etc\" directory found in \"$_rootOfFileSystem\". Please create a file system first. Exiting."
	exit 1
else
	_openbsdVersionTarget=$( cat "$_rootOfFileSystem/etc/openbsd_version" )
	_openbsdVersionTargetNonDotted=$( echo "$_openbsdVersionTarget"  | tr -d '.' ) # "5.5" => "55"
	
	if [ $( uname -s ) = "OpenBSD" ]; then

		_openbsdVersionHost=$( uname -r )
		_openbsdVersionHostNonDotted=$( echo "$_openbsdVersionHost" | tr -d '.' )
		_openbsdVersionNonDotted=$_openbsdVersionTargetNonDotted

		if [ $_openbsdVersionHostNonDotted -lt $_openbsdVersionTargetNonDotted ]; then

			echo "$_program: Warning: Host OS version is smaller than target OS version. Generating available SSH key types of host OS only."
		fi

	elif [ $( uname -s ) = "NetBSD" ]; then

		_openbsdVersionNonDotted=$_openbsdVersionTargetNonDotted
		echo "$_program: Warning: Host OS is NetBSD. Generating available SSH key types of host OS only."

	elif [ $( uname -s ) = "Linux" ]; then

		_openbsdVersionNonDotted=$_openbsdVersionTargetNonDotted
		echo "$_program: Warning: Host OS is GNU/Linux. Generating available SSH key types of host OS only."

	else
		echo "$_program: ERROR: Unknown OS in use. Please generate keys manually if your OS allows this." 1>&2
		exit 1
	fi
fi

echo "$_program: Generating keys..."

# GENERATION OF SSL KEY ########################################################
echo -n "openssl: generating isakmpd/iked RSA key... "

generateOpensslKey "$_rootOfFileSystem"
_generateOpensslKeyReturned=$?

if [ $_generateOpensslKeyReturned -eq 0 ]; then

	echo "done"

elif [ $_generateOpensslKeyReturned -eq 3 ]; then

	echo "not generated, because already existing"

else
	echo "failed"
fi
################################################################################

# GENERATION OF SSH KEYS #######################################################
echo -n "ssh-keygen: generating openssh keys... "

for _keyType in $( getOpensshKeyTypes "$_openbsdVersionNonDotted" ); do

	generateOpensshKey "$_rootOfFileSystem" "$_keyType"
	_generateOpensshKeyReturned=$?

	if [ $_generateOpensshKeyReturned -eq 0 ]; then

		echo -n "${_keyType} "

	elif [ $_generateOpensshKeyReturned -eq 2 ]; then

		# ignore unknown key types
		echo -n "${_keyType} (not generated, because unknown) "

	elif [ $_generateOpensshKeyReturned -eq 3 ]; then

		# ignore existing keys
		echo -n "${_keyType} (not generated, because already existing) "
	else
		echo -n "${_keyType} (failed) "
	fi
done

echo "done"
################################################################################

exit

