#!/bin/bash
set -e

VERSION=$1
SIGNING_KEY=$2
DEB_LOCATION=$3

SCRIPT_PATH=$( cd $(dirname $0) ; pwd -P )

if [ -z "$VERSION" ]; then
    echo "Version must be provided, e.g. ./publish-debs 0.1"
    exit 1
fi

if [ -z "$SIGNING_KEY" ]; then
    echo "Fully qualified signing key path must be provided, e.g. ./publish-debs 0.1 /keys/whistleflow-key.asc"
    exit 1
fi

if [ -z "$DEB_LOCATION" ]; then
    echo "Fully qualified location of the deb file you want to publish should be provided"
    exit 1
fi


# Aptly is possibly a bit more full featured than we need - it allows a local version of a repository
# Rather than keep this in sync between different developer machines, here we drop everything local before publishing

# Remove any local aptly stuff - || true is there because we don't want this script to fail if there's not existing stuff
aptly repo drop -force gu-securedrop || true
aptly publish drop bullseye s3:whistleflow-repo-code: || true
aptly snapshot drop gu-securedrop-$VERSION || true

# Import key into temporary keyring
gpg --no-default-keyring --keyring gu-securedrop-temporary.gpg --fingerprint
gpg --no-default-keyring  --keyring gu-securedrop-temporary.gpg --import $SIGNING_KEY

# Publish debs to S3
aptly repo create -distribution=bullseye -component=main gu-securedrop
aptly repo add gu-securedrop $DEB_LOCATION
aptly snapshot create gu-securedrop-$VERSION from repo gu-securedrop
aptly publish snapshot -keyring=gu-securedrop-temporary.gpg gu-securedrop-$VERSION s3:whistleflow-repo-code:

# Remove temporary keyring
rm ~/.gnupg/whistleflow-temporary.gpg
