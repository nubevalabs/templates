#!/usr/bin/env bash

set -e

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

if [ $EUID != 0 ]; then
  die 'sudo access required, please rerun the command prefixed with sudo'
fi

while :; do
    echo "$1"
    case $1 in
        --accept-eula)
            EULA_ACCEPTED=true
            ;;
        -b|--baseurl)
            if [ "$2" ]; then
                NUBASEURL=$2
                shift
            else
                die 'ERROR: "--baseurl|-b" requires a value argument.'
            fi
            ;;
        --branch)
            if [ "$2" ]; then
                BRANCH=$2
                shift
            else
                die 'ERROR: "--branch" requires a value argument.'
            fi
            ;;
        -c|--sslcredobj)
            if [ "$2" ]; then
                SSLCREDOBJ=$2
                shift
            else
                die 'ERROR: "--sslcredobj|-s" requires a value argument.'
            fi
            ;;
        -g|--debug)
            if [ "$2" ]; then
                DEBUG=$2
                shift
            else
                die 'ERROR: "--debug|-g" requires a value argument.'
            fi
            ;;
        -m|--disable)
            if [ "$2" ]; then
                DISABLE=$2
                shift
            else
                die 'ERROR: "--disable|-m" requires a value argument.'
            fi
            ;;
        --proxy)
            if [ "$2" ]; then
                PROXY=$2
                shift
            else
                die 'ERROR: "--proxy" requires a value argument.'
            fi
            ;;
        -t|--nutoken)
            if [ "$2" ]; then
                NUTOKEN=$2
                shift
            else
                die 'ERROR: "--nutoken|-t" requires a value argument.'
            fi
            ;;
        -s|--ssl_baseurl)
            if [ "$2" ]; then
                SSLBASEURL=$2
                shift
            else
                die 'ERROR: "--ssl_baseurl|-s" requires a value argument.'
            fi
            ;;
        -u|--noautoupdate)
            NOAUTOUPDATE="--noautoupdate"
            ;;
        -w|--nocloudwatch)
            NOCLOUDWATCH="--nocloudwatch"
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done

if [[ ! $EULA_ACCEPTED ]]; then
  echo "Please accept the EULA to continue."
  exit 1
fi

if [[ -z $NUTOKEN ]]; then
  echo "Please provide a --nutoken value."
  exit 1
fi

if [[ -z $NUBASEURL ]]; then
  echo "Please provide a --baseurl."
  exit 1
fi

if [[ -z $SSLBASEURL ]]; then
  echo "Please provide an --ssl_baseurl."
  exit 1
fi

if [[ -z $SSLCREDOBJ ]]; then
  echo "Please provide an --sslcredobj."
  exit 1
fi

if [[ ! -z $PROXY ]]; then
  export HTTP_PROXY=$PROXY
  export HTTPS_PROXY=$PROXY
fi

NUAGENT_CMD="nuagent --nutoken \$NUTOKEN --baseurl \$NUBASEURL --accept-eula --ssl_baseurl \$SSLBASEURL --sslcredobj \$SSLCREDOBJ" 

if [[ -n $NOCLOUDWATCH ]]; then
  NUAGENT_CMD=$NUAGENT_CMD" $NOCLOUDWATCH"
fi

if [[ -n $NOAUTOUPDATE ]]; then
  NUAGENT_CMD=$NUAGENT_CMD" $NOAUTOUPDATE"
fi

if [[ -n $DEBUG ]]; then
  NUAGENT_CMD=$NUAGENT_CMD" --debug \$DEBUG"
fi

if [[ -n $DISABLE ]]; then
  NUAGENT_CMD=$NUAGENT_CMD" --disable \$DISABLE"
fi

echo "$NUAGENT_CMD"
die 'for now...'


# OS/Distro Detection
# Try lsb_release, fallback with /etc/issue then uname command
echo "Detecting OS distribution"
KNOWN_DISTRIBUTION="(Debian|Ubuntu|RedHat|CentOS|openSUSE|Amazon|Arista|SUSE)"
DISTRIBUTION=$(lsb_release -d 2>/dev/null | grep -Eo $KNOWN_DISTRIBUTION  || grep -Eo $KNOWN_DISTRIBUTION /etc/issue 2>/dev/null || grep -Eo $KNOWN_DISTRIBUTION /etc/Eos-release 2>/dev/null || grep -m1 -Eo $KNOWN_DISTRIBUTION /etc/os-release 2>/dev/null || uname -s)

if [ $DISTRIBUTION = "Darwin" ]; then
  die "This script does not support installing on the Mac."
elif [ -f /etc/debian_version -o "$DISTRIBUTION" == "Debian" -o "$DISTRIBUTION" == "Ubuntu" ]; then
OS="Debian"
elif [ -f /etc/redhat-release -o "$DISTRIBUTION" == "RedHat" -o "$DISTRIBUTION" == "CentOS" -o "$DISTRIBUTION" == "Amazon" ]; then
OS="RedHat"
# Some newer distros like Amazon may not have a redhat-release file
elif [ -f /etc/system-release -o "$DISTRIBUTION" == "Amazon" ]; then
OS="RedHat"
# Arista is based off of Fedora14/18 but do not have /etc/redhat-release
elif [ -f /etc/Eos-release -o "$DISTRIBUTION" == "Arista" ]; then
OS="RedHat"
# openSUSE and SUSE use /etc/SuSE-release or /etc/os-release
elif [ -f /etc/SuSE-release -o "$DISTRIBUTION" == "SUSE" -o "$DISTRIBUTION" == "openSUSE" ]; then
OS="SUSE"
fi
echo "$OS detected"

set +e

# Verifying Nubeva connectivity
if [[ ! -z $PROXY ]]; then
  CURL_BASECMD="curl -s -L --connect-timeout 2 --proxy $PROXY"
else
  CURL_BASECMD="curl -s -L --connect-timeout 2"
fi
NUBEVA_ACCESS=$($CURL_BASECMD https://i.nuos.io)

if [[ -z $NUBEVA_ACCESS ]]; then
  echo "Failed to connect to necessary endpoints. Please check internet connectivity."
  if [[ ! -z $PROXY ]]; then
    echo "Please check your proxy settings. Proxy address being used: $PROXY"
    echo "Example curl command using the proxy specified: curl -s -L --connect-timeout 2 --proxy $PROXY https://i.nuos.io"
  fi
  exit 1
fi

set -e

echo "Check if 'jq' package installed"
TMP_PATH=$PATH:/usr/local/bin
JQ_INSTALLED=true;
PATH=$TMP_PATH hash jq 2>/dev/null || { JQ_INSTALLED=false; }

if [[ "$JQ_INSTALLED" = false ]]; then
    echo "Installing 'jq' package"
    {
    MACHINE_TYPE=`uname -m`
    if [[ $MACHINE_TYPE = "x86_64" ]]; then
        $CURL_BASECMD https://i.nuos.io/jq -o /usr/local/bin/jq
    else
        $CURL_BASECMD https://i.nuos.io/jq_32 -o /usr/local/bin/jq
    fi
    chmod +x /usr/local/bin/jq
    } &> /dev/null
    echo "'jq' installed"
else
    echo "'jq' is already installed"
fi

{
[[ $(/sbin/init --version) =~ upstart ]] && IS_UPSTART_INSTALLED=true || IS_UPSTART_INSTALLED=false
[[ $(systemctl) =~ -\.mount ]] && IS_SYSTEMD_INSTALLED=true || IS_SYSTEMD_INSTALLED=false
} &> /dev/null

INSTALLATION_DIR=/nubeva
VERSION_API="${NUBASEURL}bp/nuagent_version"

if [[ -z $BRANCH ]]; then
  if [[ $NUBASEURL =~ "version-test" ]]; then
    BRANCH="master"
  else
    BRANCH="production"
  fi
fi

echo "Check if installation directory exists"
if [[ ! -d "$INSTALLATION_DIR" ]]; then
  echo "Creating $INSTALLATION_DIR"
  mkdir -p $INSTALLATION_DIR
fi

echo "Checking the latest Nubeva agent version"
VERSION_API_RESPONSE=$(curl --silent $VERSION_API -d "{\"nutoken\": \"$NUTOKEN\", \"branch\": \"$BRANCH\", \"os\":\"linux\"}" -H "Content-type: application/json")
NUAGENT_URL=$(echo "$VERSION_API_RESPONSE" | PATH=$TMP_PATH jq .download | sed -e 's/^"//' -e 's/"$//')
NUAGENT_VERSION=$(echo "$VERSION_API_RESPONSE" | PATH=$TMP_PATH jq .version )

NUAGENT_CMD="nuagent --nutoken \$NUTOKEN --baseurl \$NUBASEURL --accept-eula --ssl_baseurl \$SSLBASEURL --sslcredobj \$SSLCREDOBJ --debug \$DEBUG --disable \$disable" 

if [[ -n $NOCLOUDWATCH ]]; then
  NUAGENT_CMD=$NUAGENT_CMD" $NOCLOUDWATCH"
fi

if [[ -n $NOAUTOUPDATE ]]; then
  NUAGENT_CMD=$NUAGENT_CMD" $NOAUTOUPDATE"
fi

if [[ -n $DEBUG ]]; then
  NUAGENT_CMD=$NUAGENT_CMD" --debug \$DEBUG"
fi

if [[ -n $DISABLE ]]; then
  NUAGENT_CMD=$NUAGENT_CMD" --disable \$DISABLE"
fi

echo "Downloading nubeva agent binary version: $NUAGENT_VERSION"
curl --silent -o "$INSTALLATION_DIR/nuagent" "$NUAGENT_URL" > /dev/null

echo "Setting up permissions"
chmod +x "$INSTALLATION_DIR/nuagent"

if [[ $OS = "RedHat" ]]; then
  set +e
  selinuxenabled
  if [[ $? == 0 ]]; then
    echo "Updating SELinux security context for nuagent binary"
    chcon -v -t bin_t /nubeva/nuagent
  fi
  set -e
fi

if [[ $IS_SYSTEMD_INSTALLED == true ]]; then
  echo "Registering agent systemd service"
  if [[ ! -f "/etc/systemd/system/nuagent.service" ]] && [[ -z $PROXY ]]; then
cat >/etc/systemd/system/nuagent.service <<EOL
[Unit]
Description=Nubeva agent service
After=network.target
[Service]
Type=simple
Restart=on-failure
RestartSec=5
User=root
Environment=NUTOKEN="$NUTOKEN"
Environment=NUBASEURL="$NUBASEURL"
Environment=SSLBASEURL="$SSLBASEURL"
Environment=SSLCREDOBJ="$SSLCREDOBJ"
Environment=DEBUG="$DEBUG"
Environment=DISABLE="$DISABLE"

ExecStart=$INSTALLATION_DIR/$NUAGENT_CMD

[Install]
WantedBy=multi-user.target
EOL
  elif [[ ! -f "/etc/systemd/system/nuagent.service" ]] && [[ ! -z $PROXY ]]; then
cat >/etc/systemd/system/nuagent.service <<EOL
[Unit]
Description=Nubeva agent service
After=network.target
[Service]
Type=simple
Restart=on-failure
RestartSec=5
User=root
Environment=NUTOKEN="$NUTOKEN"
Environment=NUBASEURL="$NUBASEURL"
Environment=SSLBASEURL="$SSLBASEURL"
Environment=SSLCREDOBJ="$SSLCREDOBJ"
Environment=DEBUG="$DEBUG"
Environment=DISABLE="$DISABLE"
Environment=HTTP_PROXY=http://$PROXY
Environment=HTTPS_PROXY=http://$PROXY
ExecStart=$INSTALLATION_DIR/$NUAGENT_CMD

[Install]
WantedBy=multi-user.target
EOL
  fi
  systemctl enable nuagent
  systemctl start nuagent
  systemctl daemon-reload
fi

if [[ $IS_UPSTART_INSTALLED == true ]]; then
    echo "Registering agent upstart service"

cat >/etc/init/nuagent.conf <<EOL
# nuagent upstart configuration

# When to start the service
start on startup

# When to stop the service
stop on dbus ok

# Automatically restart process if crashed
respawn

env NUTOKEN="$NUTOKEN"
env NUBASEURL="$NUBASEURL"
env SSLBASEURL="$SSLBASEURL"
env SSLCREDOBJ="$SSLCREDOBJ"
env DEBUG="$DEBUG"
env DISABLE="$DISABLE"

# Start the process
exec $INSTALLATION_DIR/$NUAGENT_CMD
EOL

initctl reload-configuration
initctl start nuagent
fi
