# Copyright (C) 2020 Nubeva, Inc.  All Rights Reserved
# This is the external facing version
# Version 8/7/2020 protocol version 1

from __future__ import print_function
import os
import sys
import time
import flask
import ssl
import json
import random
import string
import pprint
import argparse
import logging
from logging.handlers import RotatingFileHandler

from flask import request, Response, jsonify
from sys import platform
from werkzeug.serving import WSGIRequestHandler

import ssl

#################
# Print Helpers #
#################


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def debugConfig(msg):
    if "config" in DEBUG:
        logging.debug("\n[DEBUG] {}".format(msg))


#########
# Global #
##########


CERTS_PATH = ""
CA_PATH = ""

DEBUG = ["config"]

# Global sensors and decryptors
sensors = {}
decryptors = {}

#########
# Flask #
#########


app = flask.Flask(__name__)

@app.route('/api/1.1/kdb/test/connect', methods=['GET', 'POST'])
def auth():
    content = request.json
    return '{"token":"somebearertoken"}'


####################################
# Sensor & Decryptor Configuration #
####################################
def create_uniqueid_str():
    random_digit = ''.join(random.SystemRandom().choice(string.digits) for _ in range(24))
    return "{TIME}x{RAND}".format(TIME=int(round(time.time() * 1000)), RAND=random_digit)

def get_response(sensor_call):
    if platform == "win32":
        sep = "\\"
    else: 
        sep = "/"

    with open(app.root_path + sep + sensor_call) as f:
        resp = json.load(f)
    debugConfig(resp)
    return resp

@app.route('/version')
def version():
    return "Nubeva Key Server version 1.0"

@app.route('/sensor_login', methods=['POST'])
def login_sensor():
    contents = request.form
    resp = get_response('sensor_login')
    return resp

@app.route('/rx_login', methods=['POST'])
@app.route('/api/1.1/kdb/test/rx_login', methods=['POST'])
def login_rx():
    contents = request.form
    resp = get_response('rx_login')
    return resp

@app.route('/sensor_create', methods=['POST'])
def create_sensor():
    global sensors
    contents = request.form
    sensor_metadata = {
        "InstanceID": request.form.get('InstanceID', "").encode('ascii', 'ignore'),
        "InstanceType": request.form.get('InstanceType', "").encode('ascii', 'ignore'),
        "Location": request.form.get('Location', "").encode('ascii', 'ignore'),
        "PrivateHostname": request.form.get('PrivateHostname', "").encode('ascii', 'ignore'),
        "PublicHostname": request.form.get('PublicHostname', "").encode('ascii', 'ignore'),
        "SecurityGroups": request.form.get('SecurityGroups', "").encode('ascii', 'ignore'),
        "PublicIPv4": request.form.get('PublicIPv4', "").encode('ascii', 'ignore'),
        "AMI": request.form.get('AMI', "").encode('ascii', 'ignore'),
        "SystemHostname": request.form.get('SystemHostname', "").encode('ascii', 'ignore'),
        "OperatingSystem": request.form.get('OperatingSystem', "").encode('ascii', 'ignore'),
        "CPUArch": request.form.get('CPUArch', "").encode('ascii', 'ignore'),
        "CPUModel": request.form.get('CPUModel', "").encode('ascii', 'ignore'),
        "CPUFlags": request.form.get('CPUFlags', "").encode('ascii', 'ignore'),
        "Hypervisor": request.form.get('Hypervisor', "").encode('ascii', 'ignore'),
        "FQDN": request.form.get('FQDN', "").encode('ascii', 'ignore'),
        "IPv4": request.form.get('IPv4', "").encode('ascii', 'ignore'),
        "IPv6": request.form.get('IPv6', "").encode('ascii', 'ignore'),
        "Cloud": request.form.get('Cloud', "").encode('ascii', 'ignore'),
        "AccountId": request.form.get('AccountId', "").encode('ascii', 'ignore'),
        "NetworkId": request.form.get('NetworkId', "").encode('ascii', 'ignore'),
        "AvailabilityZone": request.form.get('AvailabilityZone', "").encode('ascii', 'ignore'),
        "VPCId": request.form.get('VPCId', "").encode('ascii', 'ignore'),
    }
    ip = sensor_metadata['IPv4'].encode('ascii', 'ignore')
    sensors[ip] = sensor_metadata
    resp = get_response('sensor_create')
    return resp

@app.route('/rx_create', methods=['POST'])
@app.route('/api/1.1/kdb/test/rx_create', methods=['POST'])
def create_rx():
    global decryptors
    contents = request.form
    decryptor_metadata = {
        "AccountId": request.form.get('AccountId', "").encode('ascii', 'ignore'),
        "AMI": request.form.get('AMI', "").encode('ascii', 'ignore'),
        "Cloud": request.form.get('Cloud', "").encode('ascii', 'ignore'),
        "CPUArch": request.form.get('CPUArch', "").encode('ascii', 'ignore'),
        "CPUFlags": request.form.get('CPUFlags', "").encode('ascii', 'ignore'),
        "CPUModel": request.form.get('CPUModel', "").encode('ascii', 'ignore'),
        "FQDN": request.form.get('FQDN', "").encode('ascii', 'ignore'),
        "Hypervisor": request.form.get('Hypervisor', "").encode('ascii', 'ignore'),
        "InstanceID": request.form.get('InstanceID', "").encode('ascii', 'ignore'),
        "InstanceType": request.form.get('InstanceType', "").encode('ascii', 'ignore'),
        "IPv4": request.form.get('IPv4', "").encode('ascii', 'ignore'),
        "Location": request.form.get('Location', "").encode('ascii', 'ignore'),
        "OperatingSystem": request.form.get('OperatingSystem', "").encode('ascii', 'ignore'),
        "PrivateHostname": request.form.get('PrivateHostname', "").encode('ascii', 'ignore'),
        "PublicIPv4": request.form.get('PublicIPv4', "").encode('ascii', 'ignore'),
        "NetworkId": request.form.get('NetworkId', "").encode('ascii', 'ignore'),
        "AvailabilityZone": request.form.get('AvailabilityZone', "").encode('ascii', 'ignore'),
        "VPCId": request.form.get('VPCId', "").encode('ascii', 'ignore'),
    }
    ip = decryptor_metadata['IPv4'].encode('ascii', 'ignore')
    decryptors[ip] = decryptor_metadata
    resp = get_response('rx_create')
    return resp

@app.route('/sensor_get', methods=['POST'])
def get_sensor():
    contents = request.form
    resp = get_response('sensor_get')
    return resp

@app.route('/rx_get', methods=['POST'])
@app.route('/api/1.1/kdb/test/rx_get', methods=['POST'])
def get_rx():
    contents = request.form
    resp = get_response('rx_get')
    return resp

@app.route('/sensors', methods=['GET'])
def sensors_list():
    global sensors
    return 'Sensors Count: ' + str(len(sensors)) + '\n' + pprint.pformat(sensors) + '\n'

@app.route('/decryptors', methods=['GET'])
def decryptors_list():
    global decryptors
    return 'Decryptors Count: ' + str(len(decryptors)) + '\n' + pprint.pformat(decryptors) + '\n'

@app.route('/bp/obj_get', methods=['POST'])
def getobj():
    contents = request.json
    errmsg = {'[ERROR] ': 'Mis-configured signatures server'}
    resp, rstat = errmsg, 200
    return resp, rstat

@app.route('/bp/put_log', methods=['POST'])
@app.route('/api/1.1/kdb/test/put_log', methods=['POST'])
def logput():
    contents = request.json
#    logging.debug(contents)
    content = {"nextSequenceToken": "anyrandomstring-{}".format(time.time())}
    return "", 200

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Example Usage:\n\n\t"
                    "Windows: python configserver.py --certs-path C:\\Users\\Administrator\\Downloads\\\n\n\t"
                    "Linux: python keyserver.py --certs-path /home/ec2-user/fastkey/",
        formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--ca-path", dest='ca_path', type=str,
                        help="Path to CA cert. Linux Default: /opt/nubevaTools/ca. Windows Default: C:\\Users\\")
    parser.add_argument("--certs-path", dest='certs_path', type=str,
                        help="Path to certs. Linux Default: /opt/nubevaTools/certs. Windows Default: C:\\Users\\")
    parser.add_argument("--certs-name", dest='certs_name', type=str, default='nubedge', help="Name for .ca, .key, .pem. Default is nubedge. "
                                                                                             "Ex: nubedge.ca, nubedge.key, nubedge.pem")
    parser.add_argument("--debug", dest='debug', choices=['config'], default=[], nargs="*", help="Debug statements")

    args = parser.parse_args()

    logdir = "{}/logs".format(app.root_path)
    if not os.path.isdir(logdir):
        os.mkdir(logdir, 0o777)

    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    fh = logging.handlers.RotatingFileHandler("{}/keyserver.log".format(logdir), maxBytes=100000000, backupCount=10)
    fh.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    fh.setFormatter(formatter)
    logger.addHandler(ch)
    logger.addHandler(fh)

    args.debug = set(args.debug)
    DEBUG = args.debug

    if args.certs_path:
        if not os.path.isdir(args.certs_path):
            print("ERROR:: Invalid certs path - {} directory does NOT exist!".format(args.certs_path))
            exit(1)

        CERTS_PATH = args.certs_path

    if args.ca_path:
        if not path.isdir(args.ca_path):
            print("ERROR:: Invalid ca path - {} directory does NOT exist!".format(args.ca_path))
            exit(1)

        CA_PATH = args.ca_path

    # See what the arguments are
    logging.info("Arguments set: [ ca-path: {}, certs-path: {} ]".format(args.ca_path, args.certs_path))

    certs_path = ""
    ca_path = ""
    if platform == "linux" or platform == "linux2":
        # linux
        certs_path = "/opt/nubevaTools/certs/" if not CERTS_PATH else CERTS_PATH
        ca_path = "/opt/nubevaTools/ca/" if not CA_PATH else CA_PATH
    elif platform == "win32":
        # Windows
        certs_path = 'C:\\Users\\' if not CERTS_PATH else CERTS_PATH
        ca_path = 'C:\\Users\\' if not CA_PATH else CA_PATH

    # pause at begining if paths aren't present- give k8s a chance to load them
    i = 0
    ca_cert_file = "{}{}.ca".format(ca_path, args.certs_name)
    server_cert_file = "{}{}.pem".format(certs_path, args.certs_name)
    server_key_file = "{}{}.key".format(certs_path, args.certs_name)
    if not os.path.isfile(ca_cert_file) or not os.path.isfile(server_cert_file) or not os.path.isfile(server_key_file):
        time.sleep(1)
        i=i+1
        if i >= 10:
           eprint("Error, cannot find cert file ca: {}:{}, server: {}:{}, key:{}:{}".format(ca_cert_file, os.path.isfile(ca_cert_file), server_cert_file, os.path.isfile(server_cert_file), server_key_file, os.path.isfile(server_key_file)))
           os.exit(1)

    logging.info("Arguments set: [ ca: {}, pem: {} key: {} ]".format(ca_cert_file, server_cert_file, server_key_file))

    context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
    context.load_verify_locations(ca_cert_file)
    context.load_cert_chain(server_cert_file, server_key_file)
    context.set_ecdh_curve("prime256v1")
    WSGIRequestHandler.protocol_version = "HTTP/1.1"  # Keep connections alive

    app.run(host='0.0.0.0', port=4443, ssl_context=context) # Start Flask
