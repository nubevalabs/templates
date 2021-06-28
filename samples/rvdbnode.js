var AWS = require("aws-sdk");
var request = require('request');
var axios = require('axios');
var config = require('./config.json');

var username = config.arUsername;
var password = config.arPassword;
var instanceIP = config.arInstanceIP;
var authEndpoint = config.arAuthEndpoint;
var createEndpoint = config.arCreateEndpoint;

exports.handler = (event, context, callback) => {

    event.Records.forEach((record) => {
        console.log('Stream record: ', JSON.stringify(record, null, 2));

        if (record.eventName == 'INSERT') {
            // Ignore TLS 1.3 entries
            if (record.dynamodb.NewImage.sslver == "1.3") {
                console.log("TLS 1.3 events currently ignored");
            }

            // Error checking
            if (record.dynamodb.NewImage.clientrandom == null) {
                console.log("Client random not available");
            }
            else if (record.dynamodb.NewImage.masterkey == null) {
                console.log("Master key not available");
            }
            else {
                console.log (record.dynamodb.NewImage.clientrandom.S);
                // var clientRandom = JSON.stringify(record.dynamodb.NewImage.clientrandom.S);
                // var masterKey = JSON.stringify(record.dynamodb.NewImage.masterkey.S);
                var clientRandom = record.dynamodb.NewImage.clientrandom.S;
                var masterKey = record.dynamodb.NewImage.masterkey.S;
                riverbedAuthenticate(clientRandom, masterKey);
            }

        }
    });
    callback(null, `Successfully processed ${event.Records.length} records.`);
};

async function riverbedAuthenticate(clientRandom, masterKey) {
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"; // disable self signed certificate warning

    request.post(
        instanceIP + authEndpoint,
        {
            json:
            {
                "user_credentials": {
                    "username": username,
                    "password": password
                },
                "generate_refresh_token": false
            }
        },
        await function (error, response, body) {
            if (!error && response.statusCode == 201) {
                riverbedCreateKey(clientRandom, masterKey, body["access_token"]);
            }
            else {
                console.log("Riverbed authentication failed");
                console.log(body);
            }
        }
    );
}

function riverbedCreateKey(clientRandom, masterKey, accessToken) {
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"; // disable self signed certificate warning

    let dataParams = {
        "client_random": clientRandom,
        "master_key": masterKey
    };
    let headerParams = {
        "content-type": "application/json",
        "Authorization": "Bearer " + accessToken
    };
    axios({
        method: 'POST',
        url: instanceIP + createEndpoint,
        headers: headerParams,
        data: dataParams
    })
        .then(function (response) {
            console.log(response);
        })
        .catch(function (error) {
            console.log(error);
        });
}
