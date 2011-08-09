<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xi="http://www.w3.org/2001/XInclude"
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
    process config/config.xml to generate an appropriate
    xi:include element for querying jobs, which can be expanded later

    this is likely only useful for server-side transformations

    any xml expected - the relevant information is from the config file

    uses external files:
     - config/config.xml
-->

<!-- ======================= Imports / Includes =========================== -->
<!-- Include our templates -->
<xsl:include href="xmlqstat-templates.xsl"/>

<!-- ======================== Passed Parameters =========================== -->
<xsl:param name="clusterName"/>
<xsl:param name="serverName"/>
<xsl:param name="request"/>
<xsl:param name="resource" />
<xsl:param name="baseURL" />

<!-- ======================= Internal Parameters ========================== -->
<!-- configuration parameters -->
<xsl:variable name="serverName-short">
  <xsl:call-template name="unqualifiedHost">
    <xsl:with-param  name="host"    select="$serverName"/>
  </xsl:call-template>
</xsl:variable>

<!-- site-specific or generic config -->
<xsl:variable name="config-file">
  <xsl:call-template name="config-file">
    <xsl:with-param  name="dir"   select="'../../config/'" />
    <xsl:with-param  name="site"  select="$serverName-short" />
  </xsl:call-template>
</xsl:variable>

<xsl:variable name="config" select="document($config-file)/config"/>

<!-- treat a bad clusterName as 'default' -->
<xsl:variable name="name">
  <xsl:choose>
  <xsl:when test="string-length($clusterName)">
    <xsl:value-of select="$clusterName" />
  </xsl:when>
  <xsl:otherwise>
    <xsl:text>default</xsl:text>
  </xsl:otherwise>
  </xsl:choose>
</xsl:variable>


<xsl:variable name="defaultNode" select="$config/clusters/default"/>
<xsl:variable name="clusterNode" select="$config/clusters/cluster[@name=$name]" />


<!-- the cell, a missing value is treated as 'default' -->
<xsl:variable name="cell">
  <xsl:variable name="value">
    <xsl:choose>
    <xsl:when test="$name = 'default'">
      <xsl:value-of select="$defaultNode/@cell" />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$clusterNode/@cell" />
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:choose>
  <xsl:when test="string-length($value)">
    <xsl:value-of select="$value" />
  </xsl:when>
  <xsl:otherwise>
    <xsl:text>default</xsl:text>
  </xsl:otherwise>
  </xsl:choose>
</xsl:variable>


<!-- the root, a missing value is treated as '/bin/false' for some safety -->
<xsl:variable name="root">
  <xsl:variable name="value">
    <xsl:choose>
    <xsl:when test="$name = 'default'">
      <xsl:value-of select="$defaultNode/@root" />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$clusterNode/@root" />
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:choose>
  <xsl:when test="string-length($value)">
    <xsl:value-of select="$value" />
  </xsl:when>
  <xsl:otherwise>
    <xsl:text>/bin/false</xsl:text>
  </xsl:otherwise>
  </xsl:choose>
</xsl:variable>


<!-- the optional baseURL for querying from an external source -->
<xsl:variable name="base">
  <xsl:choose>
  <xsl:when test="$name = 'default'">
    <xsl:value-of select="$defaultNode/@baseURL" />
  </xsl:when>
  <xsl:otherwise>
    <xsl:value-of select="$clusterNode/@baseURL" />
  </xsl:otherwise>
  </xsl:choose>
</xsl:variable>


<!-- define the redirect url -->
<xsl:variable name="redirect">
  <xsl:choose>
  <xsl:when test="string-length($base)">
    <xsl:value-of select="$base" />
  </xsl:when>
  <xsl:otherwise>
    <xsl:value-of select="$baseURL" />
  </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="$resource" />
</xsl:variable>


<!-- ======================= Output Declaration =========================== -->
<xsl:output method="xml" version="1.0" encoding="UTF-8"/>


<!-- ============================ Matching ================================ -->
<xsl:template match="/">

  <xsl:element name="xi:include">
  <xsl:attribute name="href">
    <!-- redirect (likely uses CommandGenerator) -->
    <!--
        | create a qstat query that can be evaluated later via xinclude
        | typically something like
        | http://<server>:<port>/<prefixPath>/redirect.xml/~{sge_cell}/{sge_root}
        |
        | only add ~cell/root if it not being redirected to an external source
        -->
    <xsl:value-of select="$redirect"/>
    <xsl:if test="not(string-length($base))">
      <xsl:text>/~</xsl:text><xsl:value-of select="$cell" />
      <xsl:value-of select="$root"/>
    </xsl:if>
    <xsl:if test="string-length($request)">
      <xsl:text>?</xsl:text>
      <xsl:value-of select="$request"/>
    </xsl:if>
  </xsl:attribute>
  </xsl:element>

</xsl:template>


</xsl:stylesheet>

<!-- =========================== End of File ============================== -->
