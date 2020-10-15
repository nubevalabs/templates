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
get curl-7.24.0_2.tbz
get ca_root_nss-3.14.3.tbz
quit

pkg_add -fP /usr/local ca_root_nss-3.14.3.tbz
pkg_add -fP /usr curl-7.24.0_2.tbz

# perl ...to build openssl
curl -k -O https://mirror.las.iastate.edu/CPAN/src/perl-5.32.0.tar.xz
tar xzf perl-5.32.0.tar.xz
cd perl-5.32.0
./Configure -d # keep hitting return for defaults
make install
cd

# installl openssl 1.0.2 required by Python Dtls
curl -k -O https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz
tar xzf openssl-1.0.2u.tar.gz
cd openssl-1.0.2u
./config --prefix=/usr shared
make install
cd

# get latest curl and latest ca bundle
curl -k -O http://curl.mirror.at.stealer.net/download/curl-7.72.0.tar.gz
tar xzf curl-7.72.0.tar.gz
cd curl-7.72.0
./configure
make install
mv /usr/bin/curl /usr/bin/curl.old
rehash
cd

# install new CA bundle
curl -k -O https://curl.haxx.se/ca/cacert.pem
cp cacert.pem /usr/local/share/certs/ca-root-nss.crt


# install python (old one above has too old of an SSL library)
curl -O https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
tar xzf Python-2.7.18.tgz
cd Python-2.7.18
./configure --prefix=/usr
make install
cd

# pip
curl -O https://bootstrap.pypa.io/get-pip.py
python ./get-pip.py

# install flask and Dtls
pip2 install flask
pip2 install Dtls # NOTE: THIS MUST COME BEFORE NEXT

# Take attached freebsd-python-dtls.tgz and replace your dtls sites packages for python
cd /usr/lib/python2.7/site-packages/
tar xzf freebsd-python-dtls.tgz

# Grab dtlskeydb.py, nubedge.ca, nubedge.pem, nubedge.key
# Make sure to grab a new one...for Windows and FreeBSD, small change
# modify dtlskeydb.py so the 2 locations where certs/key/ca are loaded match your dir
# run it
python dtlskeydb.py

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
