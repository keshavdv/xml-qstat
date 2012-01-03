<xsl:stylesheet version="2.0"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:dir="http://apache.org/cocoon/directory/2.0"
>
<!--
Copyright (c) 2009-2011 Mark Olesen

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
    process output from a directory generator:
    In Apache Cocoon
      <map:generate type="directory"  src=".">
          <map:parameter name="depth" value="2"/>
      </map:generate>

    * keep /^cache(-.+)?$/ directories
    * keep /^*\.xml$/  files
-->

<!-- ======================= Output Declaration =========================== -->
<xsl:output method="xml" indent="yes" version="1.0" encoding="UTF-8"/>

<!-- ============================ Matching ================================ -->

<!-- Identity transform -->
<xsl:template match="node() | @*">
  <xsl:copy>
    <xsl:apply-templates select="node() | @*"/>
  </xsl:copy>
</xsl:template>

<!-- process top-level directory -->
<xsl:template match="/dir:directory">
  <xsl:copy>
    <xsl:apply-templates
        select="*[@name = 'cache' or starts-with(@name, 'cache-')]"
    />
  </xsl:copy>
</xsl:template>


<!-- generally ignore dir:file entries -->
<xsl:template match="dir:file"/>

<!-- but copy through *.xml files -->
<xsl:template match="//dir:file[
    contains(@name, '.xml') and
    not(string-length(substring-after(@name, '.xml')))
    ]">
  <xsl:copy-of select="."/>
</xsl:template>

</xsl:stylesheet>

<!-- =========================== End of File ============================== -->
