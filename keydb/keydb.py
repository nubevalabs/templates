from __future__ import print_function
import sys
import flask
from flask import request
from flask import Response
import ssl
import json
import pprint
#import collections

from werkzeug.serving import WSGIRequestHandler


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


app = flask.Flask(__name__)

@app.route('/api/1.1/kdb/test/connect', methods=['POST'])
def auth():
    return '{"token":"somebearertoken"}'


# TODO: will need to garbage collect
gkeys = {}

# Sample returns
# {'CR': 'fe14a7dc1dcabf5c4f594add05ed5d42b328064eec63a9a86892ab96fbfcc555', 'MK': '6b0b9398e47a4ffcc235b4b5dfc1945393dbc75cf0ada2e9fcde0e9dc0520100c114c7b5ce9e8a3abd7bd8b6972c60f7', 'Type': '1.2', 'CETS': '', 'CHTS': '', 'SHTS': '', 'CTS0': '', 'STS0': '', 'XS': '', 'LastUsed': '2020-03-28T03:59:15', 'MD': {}}

# {'CR': 'c837c21fda56d0cf6bb6a711415e65d0fe3a44fb02301fab5e55d0d325f64ab2', 'MK': '', 'Type': '1.3', 'CETS': '', 'CHTS': '1f606c77314ee6adeb6032bcf1f4bc5cce9fd380e17ddd7427497ab8192744fd6e3b248a2717575e4bf0c72746d153da', 'SHTS': 'e2d7c94970577ccd01886f73972c647c7bd25953252dedd2ede5960d6f9aa077e1ede7f56c93655151a12d4f95fd56af', 'CTS0': '9fc208dbcb74978e83c841029949a9af26e9227c970a9bbae3eb115d6bda2692f5365e6731b068e6a925c3ec469b5fc0', 'STS0': '21721ee99c6dca3347cb6fc782221e9179d5f18f2ded63fc6107f49d5fd8fe8821ae5249079d901b0e2338343dd21cc9', 'XS': 'd90f4429510fd5d1c1c2245f6ce27ff42778a663045332c1edd429e34949e13452dc00300672795a5fd9595dd6a87313', 'LastUsed': '2020-03-28T04:00:49', 'MD': {'hostname': 'ip-172-30-0-203.us-west-1.compute.internal', 'instance': 'i-0e6e475f0bd6eecfd', 'pid': 13860, 'command': 'curl', 'lib': 'osl'}}

# TODO: garbage collect...
#gkeys = collections.OrderedDict()
#gmissed = collections.OrderedDict()
gkeys={}
gmissed={}
ghits = 0

@app.route('/api/1.1/kdb/test/store', methods=['POST'])
def store():
    global gkeys

    #eprint('')
    content = request.json
    #eprint(content) # Prints output
    # content['CR'] gives you the Client Random for example
    if 'CR' in content:
        gkeys[content['CR']] = content
        # eprint(content['CR'] + ' ==== POSTED ==== CNT=' + str(len(gkeys)))
        # eprint(pprint.pformat(gkeys))
        # eprint('==== POSTED ====')
        eprint('Keys: ' + str(len(gkeys)) + ' Hits: ' + str(ghits) + ' Missed: ' + str(len(gmissed)))
    else:
        eprint('***** EMPTY POST *****')
    return ''

@app.route('/api/1.1/kdb/test/storebatch', methods=['POST'])
def storebatch():
    global gkeys

    #eprint('\n\n\n+++++++ STOREBATCH UNUSED ++++++++\n\n\n')
    contents = request.json

    cnt = 0

    for content in contents:
        if 'CR' in content:
            gkeys[content['CR']] = content
            cnt = cnt + 1
            # eprint(content['CR'] + ' ==== POSTED ==== CNT=' + str(len(gkeys)))
            # eprint(pprint.pformat(gkeys))
            # eprint('==== POSTED ====')
        else:
            eprint('***** EMPTY POST IN STOREBATCH *****')

    eprint('Keys(New): ' + str(len(gkeys)) + '(' + str(cnt) + ')' + ' Hits: ' + str(ghits) + ' Missed: ' + str(len(gmissed)))
    return ''

@app.route('/dumpmissed', methods=['GET'])
def dumpmissed():
    global gmissed
#    eprint('Missed Count: ' + str(len(gmissed)))
#    for cr in gmissed:
#        eprint(cr)
    return 'Missed Count: ' + str(len(gmissed)) + '\n' + pprint.pformat(gmissed) + '\n'


@app.route('/dumpkeys', methods=['GET'])
def dumpkeys():
    global gkeys
#    eprint('Keys Count: ' + str(len(gkeys)))
#    eprint(pprint.pformat(gkeys))
    return 'Keys Count: ' + str(len(gkeys)) + '\n' + pprint.pformat(gkeys) + '\n'

# Dump keys is NSS file format
# Do we want to dump TLS 1.3? 
# Do we want to include  TLS 1.3 in the same function? 
@app.route('/dumpnsskeys')
def dumpnsskeys():
    def generate():
        for k in gkeys:
            key = gkeys[k]
            yield("#NU_METADATA " + key["CR"] + " host:" + key["MD"]["hostname"] + ", instance:" + key["MD"]["instance"] + ", pid:" + str(key["MD"]["pid"]) + ", command:" + key["MD"]["command"] + ", type:" + key["Type"] + '\n')
            if (key["Type"] == "1.2"): 
                yield("CLIENT_RANDOM " + k + " " + key["MK"] + '\n')
            else:
                yield("CLIENT_EARLY_TRAFFIC_SECRET " + k + " " + key["CETS"] + '\n')
                yield("CLIENT_HANDSHAKE_TRAFFIC_SECRET " + k + " " + key["CHTS"] + '\n')
                yield("SERVER_HANDSHAKE_TRAFFIC_SECRET " + k + " " + key["SHTS"] + '\n')
                yield("CLIENT_TRAFFIC_SECRET_0 " + k + " " + key["CTS0"] + '\n')
                yield("SERVER_TRAFFIC_SECRET_0 " + k + " " + key["STS0"] + '\n')
                yield("EXPORTER_SECRET " + k + " " + key["XS"] + '\n')

    return Response(generate(), mimetype='text/plain')


@app.route('/api/1.1/kdb/test/get', methods=['GET'])
def getkey():
    global gkeys
    global gmissed
    global ghits

    #eprint('')
    ret = []
    crs = request.args.getlist('cr')
    found = 0
    notfound = 0
    #eprint('Input crs:')
    #eprint(crs)
    for cr in crs:
        if cr in gkeys.keys():
            ret.append(gkeys[cr])
            #eprint(cr + ' **** FOUND KEY ****')
            try:
                del gmissed[cr]
            except KeyError:
                notfound = 1
            found = 1
            ghits = ghits + 1
        else:
            gmissed[cr] = 1
    rets = json.dumps(ret)
    eprint('Keys: ' + str(len(gkeys)) + ' Hits: ' + str(ghits) + ' Missed: ' + str(len(gmissed)))

    return rets

context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
context.load_verify_locations("/opt/nubevaTools/nubedge.ca")
context.load_cert_chain("/opt/nubevaTools/nubedge.pem", "/opt/nubevaTools/nubedge.key")
WSGIRequestHandler.protocol_version = "HTTP/1.1"

# Keep connections alive
# Debug mode does not keep connections alive
#app.run(host='0.0.0.0', port=443, debug=True, ssl_context=context)

app.run(host='0.0.0.0', port=443, ssl_context=context)
