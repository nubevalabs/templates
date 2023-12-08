# Copyright (C) 2020 Nubeva, Inc.  All Rights Reserved
# This is the external facing version
# Version 8/7/2020 protocol version 1

from __future__ import print_function
import sys
import flask
import json
import pprint
import argparse
from flask import request
from sys import platform
from os import path
from werkzeug.serving import WSGIRequestHandler

import ssl
import threading
from socket import socket, AF_INET, SOCK_DGRAM
from dtls import do_patch
do_patch()
from dtls.sslconnection import SSLConnection
from dtls.sslconnection import PROTOCOL_DTLSv1_2
import socket
import redis


#################
# Print Helpers #
#################


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def debugStorebatch(msg):
    if "storebatch" in DEBUG:
        print("\n[DEBUG] {}".format(msg))


def debugFast(msg):
    if "fast" in DEBUG:
        print("\n[DEBUG] {}".format(msg))


##########
# Global #
##########


nver = '2'
NSS_FILE_NAME = "keys.log"
NSS_FILE_PATH = ""
CERTS_PATH = ""
USE_NSSFILE = False

DEBUG = False

# Global keys and hit counts
gkeys={}
ghits = 0

##############
# Init Redis #
##############

redis_client = redis.Redis(host='locahost', port=6379, db=0) 



#########
# Flask #
#########


app = flask.Flask(__name__)


@app.route('/api/1.1/kdb/test/connect', methods=['GET', 'POST'])
def auth():
    content = request.json
    return '{"token":"somebearertoken"}'

@app.route('/api/1.1/dtls/test/connect', methods=['GET', 'POST'])
def auth2():
    content = request.json
    if 'Version' in content and content['Version'] == nver :
        return '{"token":"somebearertoken"}'
    else:
        eprint('Invalid Version, we only support version '+nver)
        return 'Invalid Version, we only support version '+nver, 400


@app.route('/api/1.1/dtls/test/storebatch', methods=['GET', 'POST'])
def storebatch():
    global gkeys
    contents = request.json
    cnt = 0
    for content in contents:
        if 'CR' in content:
            # Store the content in Redis instead of a global dictionary
            redis_client.set(content['CR'], json.dumps(content))
    return ''

@app.route('/dumpkeys', methods=['GET'])
def dumpkeys():
    # Get all keys from Redis
    keys = redis_client.keys('*')
    all_keys = {key: json.loads(redis_client.get(key)) for key in keys}
    return 'Keys Count: ' + str(len(all_keys)) + '\n' + pprint.pformat(all_keys) + '\n'

@app.route('/api/1.1/kdb/test/get', methods=['GET'])
def getkey():
    ret = []
    crs = request.args.getlist('cr')
    for cr in crs:
        # Retrieve from Redis
        data = redis_client.get(cr)
        if data:
            ret.append(json.loads(data))
    rets = json.dumps(ret)
    return rets

########
# Fast #
########


def ssl_ctx_cb(ctx):
    ctx.set_ecdh_curve("prime256v1")

# bin to str...probably not necessary...we could just compare it to an actual str and slam the values by multiplying index by 2
def bintostr(msg):
    r = ""
    i = 0
    for m in msg:
        if i == 48 and len(msg) == 64 and msg[48] == 0 and msg[49] == 0 and msg[50] == 0 and msg[51] == 0: # only 48B long keys
            break
        if i == 32 and len(msg) == 64 and msg[32] == 0 and msg[33] == 0 and msg[34] == 0 and msg[35] == 0: # only 32B long keys
            break
        r += "%02x" % m
        i=i+1
    return r


def readdtls(conn, nssfile_path):
    while True:
        m = conn.read() # m comes in as str...
        message = bytearray(m)
        if message:
            if message[1] == 0xc8: # putkey
                d = {}
                d['CR'] = bintostr(message[70:102])
                if message[3] == 0x03:
                    d['Type'] = '1.2'
                    d['MK'] = bintostr(message[102:150])
                    d['CHTS'] = ''
                    d['SHTS'] = ''
                    d['CETS'] = ''
                    d['CTS0'] = ''
                    d['STS0'] = ''
                    d['XS'] = ''
                else:
                    d['Type'] = '1.3'
                    d['MK']   = ''
                    m2 = message[150:214]
                    if m2[0] != 0 and m2[1] != 0 and m2[2] != 0 and m2[3] != 0: # CETS is most of the time zeros...so we don't keep
                        d['CETS'] = bintostr(m2)
                    d['CHTS'] = bintostr(message[214:278])
                    d['SHTS'] = bintostr(message[278:342])
                    d['CTS0'] = bintostr(message[342:406])
                    d['STS0'] = bintostr(message[406:470])
                    d['XS'] = bintostr(message[470:534])

                if USE_NSSFILE and d['CR'] not in gkeys:
                    debugFast("d: {}".format(d))
                    debugFast("gkeys: {}".format(gkeys))
                    write_to_nss_file(
                        nssfile_path,
                        d['CR'],
                        d['MD'] if d.get('MD', None) else {},   # Windows returns with key and val as None
                        d['Type'],
                        d.get('MK', ""),
                        d.get('CETS', ""),
                        d.get('CHTS', ""),
                        d.get('SHTS', ""),
                        d.get('CTS0', ""),
                        d.get('STS0', ""),
                        d.get('XS', "")
                    )

                debugFast("="*20)
                gkeys[d['CR']] = d
            else:
                m2 = m[:1] + b'\xca' + m[2:]
                conn.write(m2)
        else:
            print ("Exiting dlts read...")
            break


def dtls(nssfile_path, certs_path, certs_name):
    sck = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sck.bind(("0.0.0.0", 4433))
    # Windows
    scn = SSLConnection(sck, keyfile="{}{}.key".format(certs_path, certs_name),
                        certfile="{}{}.pem".format(certs_path, certs_name),
                        server_side=True,
                        ca_certs="{}{}.ca".format(certs_path, certs_name),
                        do_handshake_on_connect=False,
                        cb_user_config_ssl_ctx=ssl_ctx_cb)
    while True:
        peer_address = scn.listen()
        act = scn.accept()
        if act:
            conn = act[0]
            z = threading.Thread(target=readdtls, args=[conn, nssfile_path])
            z.start()


def write_to_nss_file(file_name, cr, md, key_type, mk, cets, chts, shts, cts0, sts0, xs):
    """Write to nss file of choosing

    :param file_name: File Name to write OR append to
    :param cr: Client Random
    :param md: Metadata - we look for hostname, instance, pid, command
    :param key_type: key type (1.2, 1.3)
    :param mk: master key
    :param cets: client early traffic secret
    :param chts: client handshake traffic secret
    :param shts: server handshake traffic secret
    :param cts0: client traffic secret 0
    :param sts0:  server traffic secret 0
    :param xs: exporter secret
    :return:
    """
    if cr in gkeys:
        return

    # Create metadata line
    entry = "#NU_METADATA {CR} host:{MD_HOSTNAME}, instance:{MD_INSTANCE}, " \
            "pid:{MD_PID}, command:{MD_COMMAND}, type:{TYPE}\n".format(
        CR=cr,
        MD_HOSTNAME=md.get("hostname", ""),
        MD_INSTANCE=md.get("instance", ""),
        MD_PID=md.get("pid", ""),
        MD_COMMAND=md.get("command", ""),
        TYPE=key_type,
    )

    if key_type == "1.2":
        entry += "CLIENT_RANDOM {CR} {MK}\n".format(CR=cr, MK=mk)
    elif key_type == "1.3":
        entry += "CLIENT_EARLY_TRAFFIC_SECRET {CR} {CETS}\n".format(CR=cr, CETS=cets)
        entry += "CLIENT_HANDSHAKE_TRAFFIC_SECRET {CR} {CHTS}\n".format(CR=cr, CHTS=chts)
        entry += "SERVER_HANDSHAKE_TRAFFIC_SECRET {CR} {SHTS}\n".format(CR=cr, SHTS=shts)
        entry += "CLIENT_TRAFFIC_SECRET_0 {CR} {CTS0}\n".format(CR=cr, CTS0=cts0)
        entry += "SERVER_TRAFFIC_SECRET_0 {CR} {STS0}\n".format(CR=cr, STS0=sts0)
        entry += "EXPORTER_SECRET {CR} {XS}\n".format(CR=cr, XS=xs)

    with open(file_name, 'a+') as f:
        f.write(entry)

    return


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="FastKeyDB\nYou can use `--nssfile /host/home/ec2-user/keys.log` for example on EC2 Amazon Linux 2.\n",
        formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--nssfile", dest='nssfile', type=str, help="Path to nsslogfile including filename")
    parser.add_argument("--certs-path", dest='certs_path', type=str,
                        help="Path to certs. Linux Default: /opt/nubevaTools/. Windows Default: C:\\Users\\")
    parser.add_argument("--certs-name", dest='certs_name', type=str, default='nubedge', help="Name for .ca, .key, .pem. Default is nubedge. "
                                                                                             "Ex: nubedge.ca, nubedge.key, nubedge.pem")
    parser.add_argument("--debug", dest='debug', choices=['storebatch', 'fast'], default=[], nargs="*", help="Debug statements")

    args = parser.parse_args()

    args.debug = set(args.debug)
    DEBUG = args.debug

    if args.nssfile:
        try:
            file = open(args.nssfile, 'a+')
        except IOError:
            print("ERROR:: Invalid nssfile path - {} file CANNOT be created!".format(args.nssfile))
            exit(1)
        else:
            file.close()

        # Set global variable for using nss file to true
        USE_NSSFILE = True
        NSS_FILE_PATH = args.nssfile

    if args.certs_path:
        if not path.isdir(args.certs_path):
            print("ERROR:: Invalid certs path - {} directory does NOT exist!".format(args.certs_path))
            exit(1)

        CERTS_PATH = args.certs_path

    # See what the arguments are
    print("Arguments set: [ nssfile: {}, debug: {}, certs-path: {}, certs-name: {} ]".format(args.nssfile, args.debug, args.certs_path, args.certs_name))

    certs_path = ""
    if platform == "linux" or platform == "linux2":
        # linux
        certs_path = "/opt/nubevaTools/" if not CERTS_PATH else CERTS_PATH
    elif platform == "win32":
        # Windows
        certs_path = 'C:\\Users\\' if not CERTS_PATH else CERTS_PATH

    context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
    print("Arguments Default: certs-path: {}, certs-name: {} ]".format(certs_path, args.certs_name))
    context.load_verify_locations("{}{}.ca".format(certs_path, args.certs_name))
    context.load_cert_chain("{}{}.pem".format(certs_path, args.certs_name), "{}{}.key".format(certs_path, args.certs_name))
    context.set_ecdh_curve("prime256v1")
    WSGIRequestHandler.protocol_version = "HTTP/1.1"  # Keep connections alive

    x = threading.Thread(target=dtls, args=[args.nssfile, certs_path, args.certs_name])
    x.start()  # Start DTLS

    app.run(host='0.0.0.0', port=4433, ssl_context=context, threaded=True) # Start Flask