# Copyright (C) 2020 Nubeva, Inc.  All Rights Reserved
# This is the external facing version
# Version 8/5/2020 protocol version 1

from __future__ import print_function
import sys
import flask
from flask import request
import ssl
import json
import pprint

from werkzeug.serving import WSGIRequestHandler

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

app = flask.Flask(__name__)
nver = '1'

@app.route('/api/1.1/dtls/test/connect', methods=['GET', 'POST'])
def auth():
    content = request.json
    if 'Version' in content and content['Version'] == nver :
        return '{"token":"somebearertoken"}'
    else:
        eprint('Invalid Version, we only support version '+nver)
        return 'Invalid Version, we only support version '+nver, 400
    
gkeys={}
ghits = 0

@app.route('/api/1.1/dtls/test/storebatch', methods=['GET', 'POST'])
def storebatch():
    global gkeys
    contents = request.json
    cnt = 0
    for content in contents:
        if 'CR' in content:
            gkeys[content['CR']] = content
            cnt = cnt + 1
        else:
            eprint('***** EMPTY POST IN STOREBATCH *****')
        
    eprint('Keys(New): ' + str(len(gkeys)) + '(' + str(cnt) + ')' + ' Hits: ' + str(ghits))
    return ''

@app.route('/dumpkeys', methods=['GET'])
def dumpkeys():
    global gkeys
    return 'Keys Count: ' + str(len(gkeys)) + '\n' + pprint.pformat(gkeys) + '\n'

@app.route('/api/1.1/dtls/test/get', methods=['GET'])
def getkey():
    global gkeys
    global ghits
    
    ret = []
    crs = request.args.getlist('cr')
    found = 0
    for cr in crs:
        if cr in gkeys.keys():
            ret.append(gkeys[cr])
            found = 1
            ghits = ghits + 1
    rets = json.dumps(ret)
    eprint('Keys: ' + str(len(gkeys)) + ' Hits: ' + str(ghits))
    
    return rets

context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
context.load_verify_locations("nubedge.ca")
context.load_cert_chain("nubedge.pem", "nubedge.key")
context.set_ecdh_curve("prime256v1")
WSGIRequestHandler.protocol_version = "HTTP/1.1" # Keep connections alive

import ssl
import threading
from socket import socket, AF_INET, SOCK_DGRAM
from dtls import do_patch
do_patch()
from dtls.sslconnection import SSLConnection
from dtls.sslconnection import PROTOCOL_DTLSv1_2
import socket

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

def readdtls(conn):
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
                gkeys[d['CR']] = d
            else:
                m2 = m[:1] + b'\xca' + m[2:]
                conn.write(m2)
        else:
            print ("Exiting dlts read...")
            break
    
def dtls():
    sck = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sck.bind(("0.0.0.0", 4433))
    scn = SSLConnection(sck, keyfile="nubedge.key", certfile="nubedge.pem", server_side=True, ca_certs="nubedge.ca", do_handshake_on_connect=False, cb_user_config_ssl_ctx=ssl_ctx_cb)
    while True:
        peer_address = scn.listen()
        conn = scn.accept()[0]
        z = threading.Thread(target=readdtls, args=(conn,))
        z.start()

        
x = threading.Thread(target=dtls)
x.start()  # Start DTLS

app.run(host='0.0.0.0', port=4433, ssl_context=context, threaded=True) # Start Flask
