# NFS root file system builder #

The tools in this repo allow to create NFS root file systems for OpenBSD from OpenBSD, NetBSD or GNU/Linux automatically.

## Prerequisites ##

**No** additional prerequisites required for a default OpenBSD installation.

## How to use ##

1. Create a configuration for NFS rootfs creation process (see [`machine-name.conf.example`] for an example)

[`machine-name.conf.example`]: /share/doc/machine-name.conf.example

2. Start the creation process (you need to be `root`!):
   ```
   # /path/to/nfsrb-openbsd.sh machine-name.conf
   nfsrb-openbsd: Now downloading files...
   [...]
   nfsrb-openbsd: Finished.
   nfsrb-openbsd: Signify public keys missing for OpenBSD 6.0 or not running under OpenBSD.
   nfsrb-openbsd: Checking validity of files with SHA256 hashes...
   `base60.tgz' is valid.
   `man60.tgz' is valid.
   `bsd' is valid.
   Finished.
   nfsrb-openbsd: Creating swap file... OK
   nfsrb-openbsd: Now extracting base60.tgz... OK
   nfsrb-openbsd: Now extracting man60.tgz... OK
   nfsrb-openbsd: Now extracting builtin etc.tgz... OK
   nfsrb-openbsd: Now configuring file system... 
   nfsrb-openbsd: Creating devices... nfsrb-openbsd: Only created `/dev/console' as we're not running under OpenBSD. Please use root FS in single user mode and create devices manually (`mount -uw / && cd /dev && ./MAKEDEV all`) before going multi-user.
   nfsrb-openbsd: Creating `/etc/fstab'... OK
   nfsrb-openbsd: Creating `/etc/myname'... OK
   nfsrb-openbsd: Creating `/etc/hosts'... OK
   nfsrb-openbsd: Creating `/etc/mygate'... OK
   nfsrb-openbsd: Creating `/etc/resolv.conf'... OK
   nfsrb-openbsd: `/etc/hostname.fxp0' not created because platform is "i386"
   nfsrb-openbsd: Installing kernel... OK
   nfsrb-openbsd: Placing OpenBSD version number and build date in `/srv/nfs/openbsd/6.0/i386/machine-name/root/etc/openbsd_version'... OK
   nfsrb-openbsd: Placing nfsrb version in `/srv/nfs/openbsd/6.0/i386/machine-name/root/etc/nfsrb_version'... OK
   ```
   > **NOTICE:** For target and host OpenBSD versions since 5.5 file validity can be checked with [`signify(1)`]. The builder uses `signify(1)` on OpenBSD 5.5 and greater and `sha256(1)` on OpenBSD 5.4 and smaller. On other OSes only the hash values are checked.

[`signify(1)`]: http://www.openbsd.org/cgi-bin/man.cgi/OpenBSD-5.5/man1/signify.1?query=signify&manpath=OpenBSD-5.5

3. Precreate OpenSSL/OpenSSH keys for the target system (optional!)
   ```
   # /path/to/gen-keys-openbsd.sh /srv/nfs/machine-name/root/
   gen-keys-openbsd: Warning: Host OS is GNU/Linux. Generating available SSH key types of host OS only.
   gen-keys-openbsd: Generating keys...
   openssl: generating isakmpd/iked RSA key... done
   ssh-keygen: generating openssh keys... dsa ecdsa ed25519 rsa done
   ```
   > **NOTICE:** The key generation on the host comes in handy for slow target machines (e.g. SUN SPARCstation 10 or SPARCclassic) which need a considerable amount of time to create SSH keys. If your host OS is older than the target OS, or if it is NetBSD or GNU/Linux, you can still create the SSH key types that are available on your host OS. On first run the target machine will create the missing keys.

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

