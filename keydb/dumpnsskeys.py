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
