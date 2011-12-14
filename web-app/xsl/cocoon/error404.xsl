<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE stylesheet [
<!ENTITY  newline "<xsl:text>&#x0a;</xsl:text>">
<!ENTITY  space   "<xsl:text>&#x20;</xsl:text>">
]>
<xsl:stylesheet version="1.0"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:h="http://apache.org/cocoon/request/2.0"
>
<!--
Copyright 2009-2011 Mark Olesen

    This file is part of xml-qstat.

    xml-qstat is free software: you can redistribute it and/or modify it under
    the terms of the GNU Affero General Public License as published by the
    Free Software Foundation, either version 3 of the License,
    or (at your option) any later version.

    xml-qstat is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with xml-qstat. If not, see <http://www.gnu.org/licenses/>.

Description
    process output from a cocoon request generator:
    In Apache Cocoon
      <map:generate type="request"/>

    extract <h:request target="..." >

    produce a custom "resource not found" page
-->

<!-- ======================= Imports / Includes =========================== -->
<!-- NONE -->

<!-- ======================== Passed Parameters =========================== -->
<xsl:param name="server-info" />
<xsl:param name="serverName" />

<!-- ======================= Internal Parameters ========================== -->
<!-- NONE -->


<!-- ======================= Output Declaration =========================== -->
<xsl:output method="xml" indent="yes" version="1.0" encoding="UTF-8"
    doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
/>


<!-- ============================ Matching ================================ -->
<xsl:template match="/" >
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
&newline;
<title> Resource Not Found </title>
</head>
&newline;

<body>
&newline;

<h1>Resource Not Found</h1>
Cannot resolve resource <b><xsl:value-of select="/h:request/@target"/></b>
<br />
<hr />
&newline;
<xsl:value-of select="$serverName"/> (<xsl:value-of select="$server-info"/>)

&newline;
</body></html>
<!-- end body/html -->
</xsl:template>

</xsl:stylesheet>
<!-- =========================== End of File ============================== -->
