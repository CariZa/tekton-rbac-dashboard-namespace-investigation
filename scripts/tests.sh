#!/usr/bin/env sh

# unset $CLUSTER_CA

# isSet () {
#     var=$1
#     [ -z "${var}" ] && echo "whaaat"
# }

CLUSTER_CA=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."certificate-authority-data"')

if [ -z "${CLUSTER_CA}" ] || [ "$CLUSTER_CA" = "null" ]; then
    export CLUSTER_CA_LOCATION=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."certificate-authority"')
    export CLUSTER_CA=$(cat $CLUSTER_CA_LOCATION | base64 | tr -d '\n')
fi

echo $CLUSTER_CA

# foo() {
#     echo "meep $1"
# }

# foo 2