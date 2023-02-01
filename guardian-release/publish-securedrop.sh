#!/bin/bash
set -e

VERSION=$1
DEB_LOCATION=$2

SCRIPT_PATH=$( cd $(dirname $0) ; pwd -P )

print_usage_and_exit () {
  cat << EOF
Usage: SIGNING_KEY_SECRET_ID=<id> publish-securedrop.sh VERSION DEB_LOCATION

e.g. SIGNING_KEY_SECRET_ID=my-secret ./publish-securedrop.sh 100.8.1 securedrop.deb
EOF
  exit 1
}

if [ -z "$VERSION" ]; then
    echo "Version must be provided"
    print_usage_and_exit
    exit 1
fi

if [ -z "$DEB_LOCATION" ]; then
    echo "Fully qualified location of the deb file you want to publish should be provided"
    print_usage_and_exit
    exit 1
fi

if [ -z "$SIGNING_KEY_SECRET_ID" ]; then
  echo "$SIGNING_KEY_SECRET_ID environment variable must be set"
  print_usage_and_exit
fi


REPO_NAME="gu-securedrop"
SNAPSHOT_NAME="$REPO_NAME-$VERSION"
KEYRING="temp-keyring.gpg"
# Aptly is possibly a bit more full featured than we need - it allows a local version of a repository
# Rather than keep this in sync between different developer machines, here we drop everything local before publishing

# Remove any local aptly stuff - || true is there because we don't want this script to fail if there's not existing stuff
aptly repo drop -force "$REPO_NAME" || true
aptly publish drop bullseye s3:s3-endpoint: || true
aptly snapshot drop "$SNAPSHOT_NAME" || true

# Fetch signing key
aws secretsmanager get-secret-value --region eu-west-1 --secret-id "$SIGNING_KEY_SECRET_ID" | jq .SecretString -r > /home/admin/private.asc

# Import key into temporary keyring
gpg --no-default-keyring --keyring "$KEYRING" --fingerprint
gpg --no-default-keyring --pinentry loopback --keyring "$KEYRING" --import /home/admin/private.asc

rm /home/admin/private.asc

# Publish debs to S3
aptly repo create -distribution=bullseye -component=main "$REPO_NAME"
aptly repo add "$REPO_NAME" "$DEB_LOCATION"
aptly snapshot create "$SNAPSHOT_NAME" from repo "$REPO_NAME"
aptly publish snapshot -config=$SCRIPT_PATH/aptly.conf -keyring="$KEYRING" "$SNAPSHOT_NAME" s3:s3-endpoint:

# Remove temporary keyring
rm ~/.gnupg/temp-keyring.gpg
