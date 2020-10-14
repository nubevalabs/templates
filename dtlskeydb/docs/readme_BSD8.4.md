# install FreeBSD 8.4 using ami from https://www.daemonology.net/freebsd-on-ec2/
# I used ami-15eac450 on an m4.large in N. California

su -
cd

# Get glib and its dependencies
ftp ftp-archive.freebsd.org
anonymous
a@b.c
bin
cd pub/FreeBSD-Archive/ports/amd64/packages-8.4-release/All
get bmake-20130303.tbz
get glib-2.34.3.tbz
get perl-5.14.2_3.tbz
get pcre-8.32.tbz
get libffi-3.0.13.tbz
get libiconv-1.14_1.tbz
get gettext-0.18.1.1_1.tbz
get python27-2.7.3_6.tbz
get ca_root_nss-3.14.3.tbz
get bash-4.2.42.tbz
get curl-7.24.0_2.tbz


pkg_add -fP /usr perl-5.14.2_3.tbz
pkg_add -fP /usr pcre-8.32.tbz
pkg_add -fP /usr libffi-3.0.13.tbz
pkg_add -fP /usr libiconv-1.14_1.tbz
pkg_add -fP /usr gettext-0.18.1.1_1.tbz
pkg_add -fP /usr/local  python27-2.7.3_6.tbz # THIS WAS PREVIOUSLY WRONG
pkg_add -fP /usr glib-2.34.3.tbz
pkg_add -fP /usr ca_root_nss-3.14.3.tbz
pkg_add -fP / bash-4.2.42.tbz
pkg_add -fP /usr curl-7.24.0_2.tbz
ln -s /usr/lib/perl5/5.14.2/mach/CORE/libperl.so /usr/lib/libperl.so

curl -O http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/ports/amd64/packages-8.4-release/All/git-1.8.2.tbz
curl -O http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/ports/amd64/packages-8.4-release/All/expat-2.0.1_2.tbz
curl -O http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/ports/amd64/packages-8.4-release/All/p5-Net-SMTP-SSL-1.01_1.tbz
curl -O http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/ports/amd64/packages-8.4-release/All/p5-Error-0.17019.tbz
curl -O http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/ports/amd64/packages-8.4-release/All/cvsps-2.1_1.tbz


pkg_add -fP /usr expat-2.0.1_2.tbz
pkg_add -fP /usr p5-Net-SMTP-SSL-1.01_1.tbz
pkg_add -fP /usr p5-Error-0.17019.tbz
pkg_add -fP /usr cvsps-2.1_1.tbz
pkg_add -fP /usr git-1.8.2.tbz

mv /usr/bin/perl /usr/bin/perl.old
mv /usr/bin/perl5 /usr/bin/perl5.old
rm /usr/lib/libperl.so

# get newer perl
curl -k -O https://mirror.las.iastate.edu/CPAN/src/perl-5.32.0.tar.xz
tar xzf perl-5.32.0.tar.xz
cd perl-5.32.0
./Configure -d # hit return for all questions
make install
cd


# pip
curl -k -O http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/ports/amd64/packages-8.4-release/All/py27-pip-1.3.1.tbz
pkg_add -fP /usr/local py27-pip-1.3.1.tbz

# get latest curl and latest ca bundle
# scp curl-7.72.0.tar.gz (from below)
tar xzf curl-7.72.0.tar.gz
cd curl-7.72.0
./configure
make install
mv /usr/bin/curl /usr/bin/curl.old
rehash
cd

# install new CA bundle
curl -k -O http://curl.haxx.se/ca/cacert.pem
cp cacert.pem /usr/local/share/certs/ca-root-nss.crt

# install python (old one above has too old of an SSL library)
curl -O https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
tar xzf Python-2.7.18.tgz
cd Python-2.7.18
./configure --prefix=/usr
make install
cd

# install flask and Dtls
pip2 install flask
pip2 install Dtls

# installl openssl 1.0.2 required by Python Dtls
curl -O https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz
tar xzf openssl-1.0.2u.tar.gz
cd openssl-1.0.2u
./config --prefix=/usr shared
make install
cd

# if you need the Nubeva decryptor, you'll need to install openssl 1.1.1 library (just the .a)
# The 2 libraries can co-exist.  Both openssl 1.1.0 and openss 1.1.1
# Build openssl 1.1.1h
curl -O ftp://ftp.openssl.org/source/openssl-1.1.1h.tar.gz
tar xzf openssl-1.1.1h.tar.gz
cd openssl-1.1.1h
./config --prefix=/usr
make
make install
cd


# Grab dtlskeydb.py, nubedge.ca, nubedge.pem, nubedge.key
# modify dtlskeydb.py so the 2 locations where certs/key/ca are loaded match your dir
# run it
python dtlskeydb.py
