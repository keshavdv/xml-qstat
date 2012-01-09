<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE stylesheet [
<!ENTITY  newline "<xsl:text>&#x0a;</xsl:text>">
<!ENTITY  space   "<xsl:text>&#x20;</xsl:text>">
]>
<xsl:stylesheet version="1.0"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:dir="http://apache.org/cocoon/directory/2.0"
>
<!--
Copyright (c) 2009-2012 Mark Olesen

License
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
    process config/config-{SITE}.xml or config/config.xml to produce an index
    of available clusters

    expected input:
     - directory listing of xml files in cache and cache-* directories

    uses external files:
     - config/config-{SITE}.xml
     - config/config.xml

    The {SITE} corresponds to the unqualified server name
-->

<!-- ======================= Imports / Includes =========================== -->
<!-- Include our masthead and templates -->
<xsl:include href="xmlqstat-masthead.xsl"/>
<xsl:include href="xmlqstat-templates.xsl"/>
<!-- Include processor-instruction parsing -->
<xsl:include href="pi-param.xsl"/>

<!-- ======================== Passed Parameters =========================== -->
<xsl:param name="server-info">
  <xsl:call-template name="pi-param">
    <xsl:with-param  name="name"    select="'server-info'"/>
  </xsl:call-template>
</xsl:param>
<xsl:param name="serverName">
  <xsl:call-template name="pi-param">
    <xsl:with-param  name="name"    select="'serverName'"/>
  </xsl:call-template>
</xsl:param>
<xsl:param name="urlExt">
  <xsl:call-template name="pi-param">
    <xsl:with-param  name="name"    select="'urlExt'"/>
  </xsl:call-template>
</xsl:param>


<!-- ======================= Internal Parameters ========================== -->
<!-- configuration parameters -->

<!-- site-specific or generic config -->
<xsl:variable name="config-file">
  <xsl:call-template name="config-file">
    <xsl:with-param  name="dir"   select="'../config/'" />
    <xsl:with-param  name="site"  select="$serverName" />
  </xsl:call-template>
</xsl:variable>

<xsl:variable name="configNode" select="document($config-file)/config"/>

<!-- default cluster enabled if @enabled does not exist or is 'true' -->
<xsl:variable name="defaultClusterAllowed">
  <xsl:choose>
  <xsl:when
      test="not(string-length($configNode/clusters/default/@enabled))
            or $configNode/clusters/default/@enabled = 'true'">
    <xsl:text>true</xsl:text>
  </xsl:when>
  <xsl:otherwise>
    <xsl:text>false</xsl:text>
  </xsl:otherwise>
  </xsl:choose>
</xsl:variable>


<!-- all the directory nodes -->
<xsl:variable name="dirNodes" select="//dir:directory"/>


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
<link rel="icon" type="image/png" href="css/screen/icons/tux.png"/>
&newline;
<title>clusters</title>

&newline;
<!-- load css -->
<link href="css/xmlqstat.css" media="screen" rel="Stylesheet" type="text/css" />
</head>
&newline;

<!-- begin body -->
&newline;
<xsl:comment> Main body content </xsl:comment>
&newline;
<body>

<div id="main">
<!-- Topomost Logo Div -->
<xsl:call-template name="topLogo">
  <xsl:with-param name="config-file" select="$config-file" />
</xsl:call-template>

<!-- Top Menu Bar -->
&newline; <xsl:comment> Top Menu Bar </xsl:comment> &newline;
<div id="menu">
  <a href="#" title="clusters" class="leftSpace"><img
      src="css/screen/icons/house.png"
      alt="[home]"
  /></a>

  <img alt=" | " src="css/screen/icon_divider.png" />
  <a href="config" title="config"><img
      src="css/screen/icons/folder_wrench.png"
      alt="[config]"
  /></a>

  <img alt=" | " src="css/screen/icon_divider.png" />
  <a href="cache" title="cache files"><img
      src="css/screen/icons/folder_page.png"
      alt="[cache files]"
  /></a>

  <img alt=" | " src="css/screen/icon_divider.png" />
  <a href="xsl" title="xsl transformations"><img
      src="css/screen/icons/folder_table.png"
      alt="[xsl files]"
  /></a>

  <img alt=" | " src="css/screen/icon_divider.png" />
  <a href="info/rss-feeds.html" title="RSS feeds (under development)"><img
      src="css/screen/icons/feed.png" alt="[rss feeds]"
  /></a>

  <img alt=" | " src="css/screen/icon_divider.png" />
  <a href="http://olesenm.github.com/xml-qstat/index.html"
      title="about"><img
      src="css/screen/icons/information.png"
      alt="[about]"
  /></a>

  <img alt=" | " src="css/screen/icon_divider.png" />
  <a href="" title="reload"><img
      src="css/screen/icons/arrow_refresh_small.png"
      alt="[reload]"
  /></a>

</div>
&newline;

<!-- <div class="dividerBarBelow">
</div>
-->

&newline;

<!-- cluster selection -->
<blockquote>
&newline; <xsl:comment> cluster selection: table header </xsl:comment> &newline;
<table class="listing">
  <tr valign="middle">
    <td>
      <div class="tableCaption">Grid Engine Clusters</div>
    </td>
  </tr>
</table>
&newline;

<!--
  list of available clusters
 -->
<table class="listing" style="text-align:left;">
<tr>
  <th>name</th>
  <th>
    <abbr title="Render cached qhost/qlicserver/qstat xml files, when possible - files are typically generated by qlicserver.">
    cached query
    </abbr>
  </th>
  <th>
    <abbr title="Render 'qstat -f' output: use cached xml files if available, or query qmaster directly.">
    qstat -f query (cached or direct)
    </abbr>
  </th>
  <th>root</th>
  <th>cell</th>
</tr>

<xsl:for-each select="$configNode/clusters/cluster">
  <!-- sorted by cluster name -->
  <xsl:sort select="name"/>
  <xsl:apply-templates select="."/>
</xsl:for-each>

<!-- add default cluster -->
<xsl:if test="$defaultClusterAllowed = 'true'">
  <xsl:choose>
  <xsl:when test="$configNode/clusters/default">
    <xsl:apply-templates select="$configNode/clusters/default"/>
  </xsl:when>
  <xsl:otherwise>
    <xsl:call-template name="addClusterLinks">
      <xsl:with-param name="unnamed" select="'default'"/>
      <xsl:with-param name="name" select="'default'"/>
      <xsl:with-param name="root" select="'SGE_ROOT'"/>
    </xsl:call-template>
  </xsl:otherwise>
  </xsl:choose>
</xsl:if>

&newline;
</table>
</blockquote>
&newline;
<xsl:if test="string-length($server-info)">
  <xsl:call-template name="bottomStatusBar">
    <xsl:with-param name="timestamp" select="$server-info"/>
  </xsl:call-template>
</xsl:if>
</div>

</body></html>
<!-- end body/html -->
</xsl:template>


<xsl:template match="cluster">
  <!-- enabled if @enabled does not exist or is 'true' -->
  <xsl:if test="not(string-length(@enabled)) or @enabled = 'true'" >
    <xsl:call-template name="addClusterLinks">
      <xsl:with-param name="name" select="@name"/>
      <xsl:with-param name="root" select="@root"/>
      <xsl:with-param name="cell" select="@cell"/>
      <xsl:with-param name="base" select="@baseURL"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<xsl:template match="default">
  <xsl:variable name="root">
    <xsl:choose>
    <xsl:when test="@root">
      <xsl:value-of select="@root"/>
    </xsl:when>
    <xsl:otherwise>SGE_ROOT</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:call-template name="addClusterLinks">
    <xsl:with-param name="unnamed" select="'default'"/>
    <xsl:with-param name="name" select="'default'"/>
    <xsl:with-param name="root" select="$root"/>
    <xsl:with-param name="cell" select="@cell"/>
    <xsl:with-param name="base" select="@baseURL"/>
  </xsl:call-template>
</xsl:template>


<xsl:template name="hasCacheFile">
  <xsl:param name="cacheDir" />
  <xsl:param name="fileBase" />
  <xsl:param name="fileQualifier" select="'.xml'"/>

  <xsl:variable name="plainName" select="concat($fileBase, '.xml')" />
  <xsl:variable name="fqName" select="concat($fileBase, $fileQualifier)" />

  <xsl:if test="
     $dirNodes[@name='cache']/dir:file[@name = $fqName]
     or
     $dirNodes[@name=$cacheDir]/dir:file[@name = $plainName]
     ">true</xsl:if>

</xsl:template>



<xsl:template name="addClusterLinks">
  <xsl:param name="unnamed" />
  <xsl:param name="name" />
  <xsl:param name="root" />
  <xsl:param name="cell" />
  <xsl:param name="base" />

  <xsl:variable name="clusterNode" select="$configNode/clusters/cluster[@name=$name]" />

  <!-- cache dir qualified with cluster name -->
  <xsl:variable name="fqCacheDir">
    <xsl:choose>
    <xsl:when test="string-length($name) and not(string-length($unnamed))">
      <xsl:text>cache-</xsl:text><xsl:value-of select="$name"/>
    </xsl:when>
    <xsl:otherwise>
       <xsl:text>NONE</xsl:text>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- cache dir qualified with cluster name -->
  <xsl:variable name="fileQualifier">
    <xsl:if test="string-length($name) and not(string-length($unnamed))">
      <xsl:text>~</xsl:text><xsl:value-of select="$name"/>
    </xsl:if>
    <xsl:text>.xml</xsl:text>
  </xsl:variable>

  <xsl:variable name="clusterDir">
    <xsl:text>cluster/</xsl:text>
    <xsl:choose>
    <xsl:when test="string-length($name)">
      <xsl:value-of select="$name"/>
    </xsl:when>
    <xsl:otherwise>
       <xsl:text>default</xsl:text>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- can disable full query (qstatf output) depending on local settings -->
  <xsl:variable name="fullqueryEnabled">
    <xsl:choose>
    <xsl:when test="$clusterNode/qstatf">
      <xsl:choose>
      <xsl:when test="
          not(string-length($clusterNode/qstatf/@enabled))
          or $clusterNode/qstatf/@enabled = 'true'">
        <xsl:text>true</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>false</xsl:text>
      </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>true</xsl:text>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="qhost_exists">
    <xsl:choose>
    <xsl:when test="string-length($base)">
      <xsl:text>true</xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="hasCacheFile">
        <xsl:with-param name="cacheDir"      select="$fqCacheDir"/>
        <xsl:with-param name="fileQualifier" select="$fileQualifier"/>
        <xsl:with-param name="fileBase"      select="'qhost'"/>
      </xsl:call-template>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- enable qlicserver button depending on local/global settings -->
  <xsl:variable name="qlicserverEnabled">
    <xsl:choose>
    <xsl:when test="$clusterNode/qlicserver">
      <!-- local setting exists -->
      <xsl:choose>
      <xsl:when test="
          not(string-length($clusterNode/qlicserver/@enabled))
          or $clusterNode/qlicserver/@enabled = 'true'">
        <xsl:text>true</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>false</xsl:text>
      </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:when test="$configNode/qlicserver">
      <!-- global setting exists -->
      <xsl:choose>
      <xsl:when test="
          not(string-length($configNode/qlicserver/@enabled))
          or $configNode/qlicserver/@enabled = 'true'">
        <xsl:text>true</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>false</xsl:text>
      </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>false</xsl:text>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="qlicserver_exists">
    <xsl:if test="$qlicserverEnabled = 'true'">
      <xsl:call-template name="hasCacheFile">
        <xsl:with-param name="cacheDir"      select="$fqCacheDir"/>
        <xsl:with-param name="fileQualifier" select="$fileQualifier"/>
        <xsl:with-param name="fileBase"      select="'qlicserver'"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:variable>

  <xsl:variable name="qstat_exists">
    <xsl:choose>
    <xsl:when test="string-length($base)">
      <xsl:text>true</xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="hasCacheFile">
        <xsl:with-param name="cacheDir"      select="$fqCacheDir"/>
        <xsl:with-param name="fileQualifier" select="$fileQualifier"/>
        <xsl:with-param name="fileBase"      select="'qstat'"/>
      </xsl:call-template>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="qstatf_exists">
    <xsl:call-template name="hasCacheFile">
      <xsl:with-param name="cacheDir"      select="$fqCacheDir"/>
      <xsl:with-param name="fileQualifier" select="$fileQualifier"/>
      <xsl:with-param name="fileBase"      select="'qstatf'"/>
    </xsl:call-template>
  </xsl:variable>


  &newline;
  <xsl:comment> cluster: <xsl:value-of select="$name"/> </xsl:comment>
  &newline;
  <tr>
  <!-- cluster name -->
  <td>
    <xsl:choose>
    <xsl:when test="string-length($qstat_exists)">
      <!-- link to cluster/XXX/jobs -->
      <xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:value-of select="$clusterDir"/>
          <xsl:text>/jobs</xsl:text>
          <xsl:value-of select="$urlExt"/>
        </xsl:attribute>
        <xsl:choose>
        <xsl:when test="$unnamed">
          <xsl:attribute name="title">default (unnamed) cluster</xsl:attribute>
          <xsl:value-of select="$unnamed"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="title">jobs</xsl:attribute>
          <xsl:value-of select="$name"/>
        </xsl:otherwise>
        </xsl:choose>
      </xsl:element>
    </xsl:when>
    <xsl:otherwise>
      <xsl:choose>
      <xsl:when test="$unnamed">
        <abbr title="default (unnamed) cluster">
          <xsl:value-of select="$unnamed"/>
        </abbr>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$name"/>
      </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
    </xsl:choose>
  </td>
  <td>
    <xsl:choose>
    <xsl:when test="
         string-length($qhost_exists)
      or string-length($qlicserver_exists)
      or string-length($qstat_exists)
      ">

      &space;
      <xsl:if test="string-length($qstat_exists)">
        <!-- jobs -->
        <xsl:element name="a">
          <xsl:attribute name="title">jobs</xsl:attribute>
          <xsl:attribute name="href">
            <xsl:value-of select="$clusterDir"/>
            <xsl:text>/jobs</xsl:text>
            <xsl:value-of select="$urlExt"/>
          </xsl:attribute>
          <img border="0"
              src="css/screen/icons/lorry_flatbed.png"
              alt="[jobs]"
          />
        </xsl:element>
      </xsl:if>

      <xsl:if test="string-length($qhost_exists)">
        <!-- queues?view=summary -->
        &space;
        <xsl:element name="a">
          <xsl:attribute name="title">queue summary</xsl:attribute>
          <xsl:attribute name="href">
            <xsl:value-of select="$clusterDir"/>
            <xsl:text>/queues</xsl:text>
            <xsl:value-of select="$urlExt"/>?view=summary</xsl:attribute>
          <img border="0"
              src="css/screen/icons/sum.png"
              alt="[queue instances]"
          />
        </xsl:element>

        <!-- queues?view=free -->
        &space;
        <xsl:element name="a">
          <xsl:attribute name="title">queues free</xsl:attribute>
          <xsl:attribute name="href">
            <xsl:value-of select="$clusterDir"/>
            <xsl:text>/queues</xsl:text>
            <xsl:value-of select="$urlExt"/>?view=free</xsl:attribute>
          <img border="0"
              src="css/screen/icons/tick.png"
              alt="[queues free]"
          />
        </xsl:element>

        <!-- queues?view=warn -->
        &space;
        <xsl:element name="a">
          <xsl:attribute name="title">queue warnings</xsl:attribute>
          <xsl:attribute name="href">
            <xsl:value-of select="$clusterDir"/>
            <xsl:text>/queues</xsl:text>
            <xsl:value-of select="$urlExt"/>?view=warn</xsl:attribute>
          <img border="0"
              src="css/screen/icons/error.png"
              alt="[warn queue]"
          />
        </xsl:element>

        <!-- queues -->
        &space;
        <xsl:element name="a">
          <xsl:attribute name="title">queue listing</xsl:attribute>
          <xsl:attribute name="href">
            <xsl:value-of select="$clusterDir"/>
            <xsl:text>/queues</xsl:text>
            <xsl:value-of select="$urlExt"/>
          </xsl:attribute>
          <img border="0"
              src="css/screen/icons/shape_align_left.png"
              alt="[queue instances]"
          />
        </xsl:element>
      </xsl:if>

      <xsl:if test="string-length($qlicserver_exists)">
        <!-- resources -->
        &space;
        <xsl:element name="a">
          <xsl:attribute name="title">resources</xsl:attribute>
          <xsl:attribute name="href">
            <xsl:value-of select="$clusterDir"/>
            <xsl:text>/resources</xsl:text>
            <xsl:value-of select="$urlExt"/>
          </xsl:attribute>
          <img border="0"
              src="css/screen/icons/database_key.png"
              alt="[resources]"
          />
        </xsl:element>
      </xsl:if>

      <!-- job details -->
      <!-- disabled for now: can be fairly resource-intensive
      &space;
      <xsl:element name="a">
        <xsl:attribute name="title">job details</xsl:attribute>
        <xsl:attribute name="href">
          <xsl:value-of select="$clusterDir"/>
          <xsl:text>/jobinfo</xsl:text>
          <xsl:value-of select="$urlExt"/>
        </xsl:attribute>
        <img border="0"
            src="css/screen/icons/magnifier_zoom_in.png"
            alt="[job details]"
        />
      </xsl:element>
      -->

      <!-- list cache files -->
      &space;
      <xsl:element name="a">
        <xsl:attribute name="title">cached files</xsl:attribute>
        <xsl:attribute name="href">
          <xsl:value-of select="$clusterDir"/>
          <xsl:text>/cache</xsl:text>
        </xsl:attribute>
        <img border="0"
            src="css/screen/icons/folder_page.png"
            alt="[cache]"
        />
      </xsl:element>

    </xsl:when>
    <xsl:otherwise>
    no cache
    </xsl:otherwise>
    </xsl:choose>
  </td>

  <td>
    <!-- everything using qstat -f output (cached or direct) -->
    <xsl:if test="$fullqueryEnabled = 'true'">
      <!-- jobs -->
      &space;
      <xsl:element name="a">
        <xsl:attribute name="title">jobs</xsl:attribute>
        <xsl:attribute name="href">jobs~<xsl:value-of select="$name"/>
          <xsl:value-of select="$urlExt"/>
        </xsl:attribute>
        <img border="0"
            src="css/screen/icons/lorry.png"
            alt="[xmlqstat]"
        />
      </xsl:element>

      <!-- queues?view=summary -->
      &space;
      <xsl:element name="a">
        <xsl:attribute name="title">queue summary</xsl:attribute>
        <xsl:attribute name="href">queues~<xsl:value-of select="$name"/>
          <xsl:value-of select="$urlExt"/>?view=summary</xsl:attribute>
        <img border="0"
            src="css/screen/icons/sum.png"
            alt="[queue instances]"
        />
      </xsl:element>

      <!-- queues?view=free -->
      &space;
      <xsl:element name="a">
        <xsl:attribute name="title">queues free</xsl:attribute>
        <xsl:attribute name="href">queues~<xsl:value-of select="$name"/>
          <xsl:value-of select="$urlExt"/>?view=free</xsl:attribute>
        <img border="0"
            src="css/screen/icons/tick.png"
            alt="[queues free]"
        />
      </xsl:element>

      <!-- queues?view=warn -->
      &space;
      <xsl:element name="a">
        <xsl:attribute name="title">queue warnings</xsl:attribute>
        <xsl:attribute name="href">queues~<xsl:value-of select="$name"/>
          <xsl:value-of select="$urlExt"/>?view=warn</xsl:attribute>
        <img border="0"
            src="css/screen/icons/error.png"
            alt="[warn queue]"
        />
      </xsl:element>

      <!-- queues: using qstat -f output (cached or direct) -->
      &space;
      <xsl:element name="a">
        <xsl:attribute name="title">queue listing</xsl:attribute>
        <xsl:attribute name="href">queues~<xsl:value-of select="$name"/>
          <xsl:value-of select="$urlExt"/>
        </xsl:attribute>
        <img border="0"
            src="css/screen/icons/shape_align_left.png"
            alt="[queue instances]"
        />
      </xsl:element>

      <!-- report: using qstat -f output (cached or direct) -->
      &space;
      <xsl:element name="a">
        <xsl:attribute name="title">cluster report</xsl:attribute>
        <xsl:attribute name="href">report~<xsl:value-of select="$name"/>
          <xsl:value-of select="$urlExt"/>
        </xsl:attribute>
        <img border="0"
            src="css/screen/icons/report.png"
            alt="[cluster report]"
        />
      </xsl:element>

      <!-- resources -->
      <xsl:if test="string-length($qlicserver_exists)">
        &space;
        <xsl:element name="a">
          <xsl:attribute name="title">resources</xsl:attribute>
          <xsl:attribute name="href">resources~<xsl:value-of select="$name"/>
            <xsl:value-of select="$urlExt"/>
          </xsl:attribute>
          <img border="0"
              src="css/screen/icons/database_key.png"
              alt="[resources]"
          />
        </xsl:element>
      </xsl:if>

      <!-- view qstat -f xml : (cached or direct) -->
      &space;
      <xsl:choose>
      <xsl:when test="string-length($qstatf_exists)">
        <xsl:element name="a">
          <xsl:attribute name="title">cached qstat -f query</xsl:attribute>
          <xsl:attribute name="href">qstatf~<xsl:value-of select="$name"/>.xml</xsl:attribute>
          <img border="0"
              src="css/screen/icons/folder_page.png"
              alt="[cached qstat -f]"
          />
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="a">
          <xsl:attribute name="title">qstat -f -xml</xsl:attribute>
          <xsl:attribute name="href">qstatf~<xsl:value-of select="$name"/>.xml</xsl:attribute>
          <img border="0"
              src="css/screen/icons/tag.png"
              alt="[qstat -f -xml]"
          />
        </xsl:element>
      </xsl:otherwise>
      </xsl:choose>
    </xsl:if>

  </td>

  <xsl:choose>
  <xsl:when test="string-length($base)">
    <!--
       | misuse sge root for URL
       | but don't supply href since it may not point anywhere useful
       -->
    <td>
      <xsl:element name="a">
        <xsl:attribute name="title">
          <xsl:value-of select="$base"/>
        </xsl:attribute>
        <xsl:text>http://</xsl:text>
      </xsl:element>
    </td>
    <!-- sge cell -->
    <td>
    </td>
  </xsl:when>
  <xsl:otherwise>
    <!-- sge root -->
    <td>
      <xsl:value-of select="$root"/>
    </td>
    <!-- sge cell -->
    <td>
      <xsl:value-of select="$cell"/>
    </td>
  </xsl:otherwise>
  </xsl:choose>

  </tr>
</xsl:template>


</xsl:stylesheet>

<!-- =========================== End of File ============================== -->
