# NFS root file system builder #

The tools in this repo allow to create NFS root file systems for OpenBSD from an OpenBSD host automatically.

## Prerequisites ##

**No** additional prerequisites required for a default OpenBSD installation.

## How to use ##

1. Create a configuration for NFS rootfs creation process (see [`machine-name.conf.example`] for an example)

[`machine-name.conf.example`]: /share/doc/machine-name.conf.example

2. Start the creation process (you need to be `root`!):
   ```
   # /path/to/nfsrb-openbsd.sh machine-name.conf
   Now downloading files...
   [...]
   Checking validity of files with sha256...
   `base56.tgz' is valid.
   `etc56.tgz' is valid.
   `man56.tgz' is valid.
   `bsd.mp' is valid.
   Finished.
   Creating swap file
   Finished.
   Now extracting base56.tgz... OK
   Now extracting etc56.tgz... OK
   Now extracting man56.tgz... OK
   Now configuring file system... 
   Creating devices... OK
   Creating /etc/fstab... OK
   Creating /etc/myname... OK
   Copying /etc/hosts from host... OK
   Creating /etc/hostname.[...]... OK
   Installing kernel... OK
   Placing OpenBSD version number in `/srv/nfs/machine-name/root/etc/openbsd_version'... OK
   ```
   > **NOTICE:** For target and host OpenBSD versions since 5.5 file validity can be checked with [`signify`]. The builder uses `signify` on OpenBSD 5.5 and greater and `sha256` on OpenBSD 5.4 and smaller.

[`signify`]: http://www.openbsd.org/cgi-bin/man.cgi/OpenBSD-5.5/man1/signify.1?query=signify&manpath=OpenBSD-5.5

3. Precreate OpenSSL/OpenSSH keys for the target system (optional!)
   ```
   # /path/to/gen-keys-openbsd.sh /srv/nfs/machine-name/root/
   Warning: Host OS version is smaller than target OS version. Using available SSH key types of host OS only.
   openssl: generating isakmpd/iked RSA key... OK
   ssh-keygen: generating openssh keys... rsa1 dsa ecdsa rsa OK
   ```
   > **NOTICE:** The key generation on the host comes in handy for slow target machines (e.g. SUN SPARCstation 10) which need a considerable amount of time to create SSH keys. If your host OS is older than the target OS, you can still create the SSH key types that are available on your host OS. On first run the target machine will create the missing keys.

## License ##

(GPLv3)

Copyright (C) 2014-2016 Frank Scheiner

The software is distributed under the terms of the GNU General Public License

This software is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a [copy] of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

[copy]: /COPYING

