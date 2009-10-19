<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE stylesheet [
<!ENTITY  newline "<xsl:text>&#x0a;</xsl:text>">
<!ENTITY  space   "<xsl:text> </xsl:text>">
<!ENTITY  nbsp    "&#xa0;">
]>
<xsl:stylesheet version="1.0"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>
<!--
   | process XML generated by
   |     "qstat -u * -xml -r -f -explain aAcE"
   | to produce
   |   1) a list of active and pending jobs (the default)
   |   2) a detailed list of the queue instances (renderMode = full)
   |   3) a queue summary (renderMode = summary)
   |
-->

<!--
   ============================================================================
   Author : Chris Dagdigian (chris@bioteam.net)
   Author : Mark.Olesen@emconTechnologies.com
   License: Creative Commons
   ============================================================================
-->

<!-- ======================= Imports / Includes =========================== -->
<!-- Include our masthead and templates -->
<xsl:include href="xmlqstat-masthead.xsl"/>
<xsl:include href="xmlqstat-templates.xsl"/>
<!-- Include processor-instruction parsing -->
<xsl:include href="pi-param.xsl"/>


<!-- ======================== Passed Parameters =========================== -->
<xsl:param name="clusterName">
  <xsl:call-template name="pi-param">
    <xsl:with-param  name="name"    select="'clusterName'"/>
  </xsl:call-template>
</xsl:param>
<xsl:param name="timestamp">
  <xsl:call-template name="pi-param">
    <xsl:with-param  name="name"    select="'timestamp'"/>
  </xsl:call-template>
</xsl:param>

<xsl:param name="filterByUser">
  <xsl:call-template name="pi-param">
    <xsl:with-param  name="name"    select="'filterByUser'"/>
  </xsl:call-template>
</xsl:param>

<xsl:param name="renderMode">
  <xsl:call-template name="pi-param">
    <xsl:with-param  name="name"    select="'renderMode'"/>
    <xsl:with-param  name="default" select="'jobs'"/>
  </xsl:call-template>
</xsl:param>

<xsl:param name="menuMode">
  <xsl:call-template name="pi-param">
    <xsl:with-param  name="name"    select="'menuMode'"/>
    <xsl:with-param  name="default" select="'qstatf'"/>
  </xsl:call-template>
</xsl:param>

<xsl:param name="urlExt">
  <xsl:call-template name="pi-param">
    <xsl:with-param  name="name"    select="'urlExt'"/>
  </xsl:call-template>
</xsl:param>

<!-- ======================= Internal Parameters ========================== -->
<!-- configuration parameters -->
<xsl:variable
    name="configFile"
    select="document('../config/config.xml')" />
<xsl:variable
    name="alarmFile"
    select="document('../config/alarm-threshold.xml')" />

<!-- this doesn't seem to be working anyhow -->
<xsl:variable name="enableResourceQueries"/>

<!-- absolute or percent -->
<xsl:param name="showSlotUsage" select="'absolute'"/>

<!-- possibly append ~{clusterName} to urls -->
<xsl:variable name="clusterSuffix">
  <xsl:if test="$clusterName">~<xsl:value-of select="$clusterName"/></xsl:if>
</xsl:variable>

<!-- the date according to the processing-instruction -->
<xsl:variable name="piDate">
  <xsl:call-template name="pi-named-param">
    <xsl:with-param  name="pis"  select="processing-instruction('qstat')" />
    <xsl:with-param  name="name" select="'date'"/>
  </xsl:call-template>
</xsl:variable>


<!-- ========================== Sorting Keys ============================== -->
<xsl:key
    name="queue-summary"
    match="//host/queue"
    use="@name"
/>
<xsl:key
    name="job-summary"
    match="//Queue-List/job_list"
    use="JB_job_number"
/>
<xsl:key
    name="jobTask-summary"
    match="//Queue-List/job_list"
    use="concat(JB_job_number,';',tasks)"
/>


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
<link rel="alternate" type="application/atom+xml" href="feed/overview" title="xmlqstat" />
&newline;

<xsl:choose>
<xsl:when test="$renderMode='full'">
  <link rel="icon" type="image/png" href="css/screen/icons/shape_align_left.png"/>
  <title> queue instances
  <xsl:if test="$clusterName"> @<xsl:value-of select="$clusterName"/></xsl:if>
  </title>
</xsl:when>
<xsl:when test="$renderMode='summary'">
  <link rel="icon" type="image/png" href="css/screen/icons/sum.png"/>
  <title> cluster summary
  <xsl:if test="$clusterName"> @<xsl:value-of select="$clusterName"/></xsl:if>
  </title>
</xsl:when>
<xsl:otherwise>
  <link rel="icon" type="image/png" href="css/screen/icons/lorry.png"/>
  <title> jobs
  <xsl:if test="$clusterName"> @<xsl:value-of select="$clusterName"/></xsl:if>
  </title>
</xsl:otherwise>
</xsl:choose>

&newline;
<xsl:comment> load javascript </xsl:comment>
&newline;
<!-- NB: <script> .. </script> needs some (any) content -->
<script src="javascript/cookie.js" type="text/javascript">
  // Dortch cookies
</script>
<script src="javascript/xmlqstat.js" type="text/javascript">
  // display altering code
</script>
&newline;
<!-- load css -->
<link href="css/xmlqstat.css" media="screen" rel="Stylesheet" type="text/css" />
<style type="text/css">
  /* initially hide elements that rely on javascript */
  #activeJobTableToggle  { visibility: hidden; }
  #pendingJobTableToggle { visibility: hidden; }
</style>

&newline;
</head>

<!--
   | count active jobs/slots for user or everyone
   | we can count the slots directly, since each task is listed separately
   | but we need to count the jobs ourselves
   -->
<xsl:variable name="AJ_total">
  <xsl:choose>
  <xsl:when test="string-length($filterByUser)">
    <xsl:call-template name="count-jobs">
      <xsl:with-param name="nodeList" select="//job_info/queue_info/Queue-List/job_list[JB_owner=$filterByUser]"/>
    </xsl:call-template>
  </xsl:when>
  <xsl:otherwise>
    <xsl:call-template name="count-jobs">
      <xsl:with-param name="nodeList" select="//job_info/queue_info/Queue-List/job_list"/>
    </xsl:call-template>
  </xsl:otherwise>
  </xsl:choose>
</xsl:variable>
<xsl:variable name="AJ_slots">
  <xsl:choose>
  <xsl:when test="string-length($filterByUser)">
    <xsl:value-of select="sum(//job_info/queue_info/Queue-List/job_list[JB_owner=$filterByUser]/slots)"/>
  </xsl:when>
  <xsl:otherwise>
    <xsl:value-of select="sum(//job_info/queue_info/Queue-List/job_list/slots)"/>
  </xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<!--
   | count pending jobs/slots for user or everyone
   | we must count the slots ourselves, since pending job tasks are grouped together
   -->
<xsl:variable name="PJ_total">
  <xsl:choose>
  <xsl:when test="string-length($filterByUser)">
    <xsl:value-of select="count(//job_info/job_info/job_list[JB_owner=$filterByUser])"/>
  </xsl:when>
  <xsl:otherwise>
    <xsl:value-of select="count(//job_info/job_info/job_list)"/>
  </xsl:otherwise>
  </xsl:choose>
</xsl:variable>
<xsl:variable name="PJ_slots">
  <xsl:choose>
  <xsl:when test="string-length($filterByUser)">
    <xsl:call-template name="count-slots">
      <xsl:with-param name="nodeList" select="//job_info/job_info/job_list[JB_owner=$filterByUser]"/>
    </xsl:call-template>
  </xsl:when>
  <xsl:otherwise>
    <xsl:call-template name="count-slots">
      <xsl:with-param name="nodeList" select="//job_info/job_info/job_list"/>
    </xsl:call-template>
  </xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<!--
  CALCULATE TOTAL PERCENTAGE OF JOB SLOTS IN USE CLUSTER-WIDE
-->
<!-- NB: slots_total reported actually includes slots_used -->
<xsl:variable
    name="slotsUsed"
    select="sum(//Queue-List/slots_used)"
    />
<xsl:variable
    name="slotsTotal"
    select=" sum(//Queue-List/slots_total) - sum(//Queue-List/slots_used)"
    />
<xsl:variable
    name="slotsPercent"
    select="($slotsUsed div $slotsTotal)*100"
    />

<!-- END CALCULATE SECTION -->

<!-- TOTAL NUMBER OF QUEUE INSTANCES -->
<xsl:variable name="queueInstances"  select="count(//Queue-List/name)"/>

<!-- COUNT UNUSUAL QUEUE LEVEL STATE INDICATORS -->
<xsl:variable name="QI_state_a"  select="count(//job_info/queue_info/Queue-List[state[.='a']  ])"/>
<xsl:variable name="QI_state_d"  select="count(//job_info/queue_info/Queue-List[state[.='d']  ])"/>
<xsl:variable name="QI_state_o"  select="count(//job_info/queue_info/Queue-List[state[.='o']  ])"/>
<xsl:variable name="QI_state_c"  select="count(//job_info/queue_info/Queue-List[state[.='c']  ])"/>
<xsl:variable name="QI_state_C"  select="count(//job_info/queue_info/Queue-List[state[.='C']  ])"/>
<xsl:variable name="QI_state_D"  select="count(//job_info/queue_info/Queue-List[state[.='D']  ])"/>
<xsl:variable name="QI_state_s"  select="count(//job_info/queue_info/Queue-List[state[.='s']  ])"/>
<xsl:variable name="QI_state_S"  select="count(//job_info/queue_info/Queue-List[state[.='S']  ])"/>
<xsl:variable name="QI_state_E"  select="count(//job_info/queue_info/Queue-List[state[.='E']  ])"/>
<xsl:variable name="QI_state_au" select="count(//job_info/queue_info/Queue-List[state[.='au'] ])"/>

<!--
   | Build a node set of all queues that are not usable for new or pending jobs
   | The intent here is that then we can sum(slots_total) to get the number of
   | job slots that are not usable.
   | This is then used to build the adjusted slot availability percentage
   -->
<xsl:variable name="nodeSet-unusableQueues"
    select="//job_info/queue_info/Queue-List[state[.='au']]
    | //job_info/queue_info/Queue-List[state[.='d']]
    | //job_info/queue_info/Queue-List[state[.='adu']]
    | //job_info/queue_info/Queue-List[state[.='E']]"
    />
<xsl:variable name="unusableSlotCount"
    select="sum($nodeSet-unusableQueues/slots_total)" />
<xsl:variable name="nodeSet-unavailableQueues"
    select="//job_info/queue_info/Queue-List[state[.='au']]
    | //job_info/queue_info/Queue-List[state[.='d']]
    | //job_info/queue_info/Queue-List[state[.='E']]
    | //job_info/queue_info/Queue-List[state[.='a']]
    | //job_info/queue_info/Queue-List[state[.='A']]
    | //job_info/queue_info/Queue-List[state[.='D']]"
    />
<xsl:variable name="nodeSet-loadAlarmQueues"
    select="//job_info/queue_info/Queue-List[state[.='a']]
    | //job_info/queue_info/Queue-List[state[.='A']]"
    />
<xsl:variable name="nodeSet-dEauQueues"
    select="//job_info/queue_info/Queue-List[state[.='d']]
    | //job_info/queue_info/Queue-List[state[.='au']]
    | //job_info/queue_info/Queue-List[state[.='E']]"
    />
<xsl:variable name="unavailableQueueInstanceCount"
    select="count($nodeSet-unavailableQueues)"
    />
<xsl:variable name="AdjSlotsPercent"
    select="($slotsUsed div ($slotsTotal - $unusableSlotCount) )*100"
    />
<xsl:variable name="unavailable-all-Percent"
    select="($unavailableQueueInstanceCount div $queueInstances)*100"
    />
<xsl:variable name="unavailable-load-Percent"
    select="(count($nodeSet-loadAlarmQueues) div $queueInstances)*100"
    />
<xsl:variable name="unavailable-dEau-Percent"
    select="(count($nodeSet-dEauQueues) div $queueInstances)*100"
    />



<!-- begin body -->
<body>
&newline;
<xsl:comment> Main body content </xsl:comment>
&newline;

<div id="main">
<!-- Topomost Logo Div and Top Menu Bar -->
<xsl:call-template name="topLogo"/>
<xsl:choose>
<xsl:when test="$menuMode='qstatf'">
  <xsl:call-template name="qstatfMenu">
    <xsl:with-param name="clusterSuffix" select="$clusterSuffix"/>
    <xsl:with-param name="urlExt" select="$urlExt"/>
  </xsl:call-template>
</xsl:when>
<xsl:otherwise>
  <xsl:call-template name="topMenu">
    <xsl:with-param name="urlExt" select="$urlExt"/>
  </xsl:call-template>
</xsl:otherwise>
</xsl:choose>

&newline;
<!-- Top dotted line bar (holds the qmaster host and update time) -->
<xsl:if test="string-length($clusterName) or string-length($piDate)">
  <div class="dividerBarBelow">
    <xsl:value-of select="$clusterName"/>
    &space;
    <!-- replace 'T' in dateTime for easier reading -->
    <xsl:value-of select="translate($piDate, 'T', ' ')"/>
  </div>
</xsl:if>

<xsl:choose>
<xsl:when test="$renderMode='full'">
  &newline;
  <xsl:comment> Queue Instance Information </xsl:comment>
  &newline;

  <!-- queue instances: -->
  <blockquote>
  <table class="listing">
    <tr valign="middle">
      <td>
        <!-- NB: slots_total reported actually includes slots_used -->
        <xsl:variable name="valueUsed"
            select="sum(//Queue-List/slots_used)"
            />
        <xsl:variable name="valueTotal"
            select="sum(//Queue-List/slots_total) - sum(//Queue-List/slots_used)"
            />
        <xsl:variable name="percent"
            select="($valueUsed div $valueTotal)*100"
            />

        <div class="tableCaption">Queue Instance Information</div>
        <div class="tableCaption" id="summaryGraph">
          <!-- summarize slot usage as percent or absolute value -->
          <xsl:choose>
          <xsl:when test="$showSlotUsage='percent'">
            <xsl:call-template name="progressBar">
              <xsl:with-param name="title"
                  select="concat($valueUsed, ' of ', $valueTotal, ' slots in use')"
              />
              <xsl:with-param name="label"
                  select="concat(format-number($percent,'##0.#'), '%')"
              />
              <xsl:with-param name="percent" select="$percent"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="progressBar">
              <xsl:with-param name="label" select="concat($valueUsed, '/', $valueTotal)" />
              <xsl:with-param name="title"
                  select="concat(format-number($percent,'##0.#'), '%')" />
              <xsl:with-param name="percent" select="$percent"/>
            </xsl:call-template>
          </xsl:otherwise>
          </xsl:choose>
        </div>
      </td>
    </tr>
  </table>
  <div id="queueStatusTable">
    <xsl:apply-templates select="//queue_info" />
  </div>
  </blockquote>
</xsl:when>
<xsl:when test="$renderMode='summary'">
  &newline;
  <xsl:comment> Cluster Summary </xsl:comment>
  &newline;
  <!-- cluster summary: -->
  <blockquote>
  <table class="listing" width="80%">
    <tr valign="middle">
      <td>
        <div class="tableCaption">GridEngine Cluster Summary</div>
      </td>
    </tr>
  </table>
  <div id="queueStatusTable">
    <table class="listing" width="80%">
    <tr>
      <th>Slot Utilization</th>
      <!-- this element is for icons, reserve a standard width -->
      <td width="16px"/>
      <td>
        <!-- bar graph of total cluster slot utilization -->
        <xsl:call-template name="progressBar">
          <xsl:with-param name="title"
              select="concat('Currently ', $slotsUsed, ' of ', $slotsTotal,
              ' total cluster job slots are in use')"
          />
          <xsl:with-param name="label"
              select="concat(format-number($slotsPercent,'##0.#'), '%')"
          />
          <xsl:with-param name="percent" select="$slotsPercent"/>
        </xsl:call-template>

        <!-- bar graph of adjusted slot utilization -->
        <xsl:variable name="AdjSlotsTotal" select="($slotsTotal - $unusableSlotCount)"/>
        <xsl:call-template name="progressBar">
          <xsl:with-param name="title"
              select="concat('Currently ', $slotsUsed, ' of ', $AdjSlotsTotal,
              ' USABLE cluster job slots are in use')"
          />
          <xsl:with-param name="label"
              select="concat(format-number($AdjSlotsPercent,'##0.#'), '%')"
          />
          <xsl:with-param name="percent" select="$AdjSlotsPercent"/>
        </xsl:call-template>
      </td>

      <td>This cluster has
        <xsl:value-of select="format-number($queueInstances,'###,###,###')"/>
        queue instances offering up
        <xsl:value-of select="format-number($slotsTotal,'###,###,###')"/>
        total job slots.
        There are <xsl:value-of select="$slotsUsed"/> active job slots currently in use.
        With <xsl:value-of select="$unusableSlotCount"/> slots belonging to queue
        instances that are administratively disabled or in an unusable state,
        the adjusted slot utilization percentage is
        <xsl:value-of select="format-number($AdjSlotsPercent,'##0.#') "/>%.
      </td>
    </tr>
    <tr>
      <th>Queue Availability</th>
      <td>
        <xsl:choose>
        <xsl:when test="$unavailable-all-Percent &gt;= 50" >
          <img src="css/screen/icons/exclamation.png" />
        </xsl:when>
        <xsl:when test="$unavailable-all-Percent &gt;= 10" >
          <img src="css/screen/icons/error.png" />
        </xsl:when>
        </xsl:choose>
      </td>
      <td>
        <!-- bar graph of availability -->
        <xsl:call-template name="progressBar">
          <xsl:with-param name="title"
              select="concat($unavailableQueueInstanceCount, ' / ',
              $queueInstances, ' queue instances are unavailable')"
          />
          <xsl:with-param name="label"
              select="concat(format-number($unavailable-all-Percent,'##0.#'), '%')"
          />
          <xsl:with-param name="percent" select="$unavailable-all-Percent"/>
        </xsl:call-template>

        <!-- bar graph of unavailability -->
        <xsl:variable name="unavailableSlots" select="count($nodeSet-loadAlarmQueues)"/>
        <xsl:call-template name="progressBar">
          <xsl:with-param name="title"
              select="concat($unavailableSlots, ' / ',
              $queueInstances, ' queue instances unavailable for LOAD related reasons')"
          />
          <xsl:with-param name="label"
              select="concat(format-number($unavailable-load-Percent,'##0.#'), '%')"
          />
          <xsl:with-param name="percent" select="$unavailable-load-Percent"/>
        </xsl:call-template>

        <!-- bar graph of total cluster slot utilization -->
        <xsl:variable name="unavailable-dEau" select="count($nodeSet-dEauQueues)"/>
        <xsl:call-template name="progressBar">
          <xsl:with-param name="title"
              select="concat($unavailable-dEau, ' / ',
              $queueInstances, ' queue instances unavailable for ALARM, ERROR or ADMIN related reasons')"
          />
          <xsl:with-param name="label"
              select="concat(format-number($unavailable-dEau-Percent,'##0.#'), '%')"
          />
          <xsl:with-param name="percent" select="$unavailable-dEau-Percent"/>
        </xsl:call-template>
      </td>
      <td>
        <xsl:value-of select="format-number($unavailable-all-Percent,'##0.#') "/>%
        of configured grid queue instances are closed to new jobs due to
        load threshold alarms, errors or administrative action.
      </td>
    </tr>
    <tr>
      <th>Queue Alerts</th>
      <td>
        <xsl:choose>
        <xsl:when test="$QI_state_au &gt; 0">
          <img src="css/screen/icons/exclamation.png" />
        </xsl:when>
        <xsl:when test="$QI_state_S &gt; 0">
          <img src="css/screen/icons/exclamation.png" />
        </xsl:when>
        </xsl:choose>
      </td>
      <td colspan="2">
        <ul>
          <xsl:if test="$QI_state_au &gt; 0">
            <li><xsl:value-of select="$QI_state_au"/>
              queue instance(s) report alarm/unreachable state '<em>au</em>'
            </li>
          </xsl:if>
          <xsl:if test="$QI_state_a &gt; 0">
            <li><xsl:value-of select="$QI_state_a"/>
              queue instance(s) report load threshold alarm state '<em>a</em>'
            </li>
          </xsl:if>
          <xsl:if test="$QI_state_d &gt; 0">
            <li><xsl:value-of select="$QI_state_d"/>
              queue instance(s) report admin disabled state '<em>d</em>'
              </li>
          </xsl:if>
          <xsl:if test="$QI_state_S &gt; 0">
            <li><xsl:value-of select="$QI_state_S"/>
              queue instance(s) report subordinate state '<em>S</em>'
            </li>
          </xsl:if>
        </ul>
      </td>
    </tr>

    <!-- active jobs: -->
    <tr>
      <th>Active Jobs</th>
      <td/>
      <td colspan="2">
        <ul>
          <xsl:choose>
          <xsl:when test="$AJ_total &gt; 0">
            <li>
              <xsl:value-of select="$AJ_total"/> active jobs
              (<xsl:value-of select="$AJ_slots"/> slots)
            </li>
          </xsl:when>
          <xsl:otherwise>
            <li>none</li>
          </xsl:otherwise>
          </xsl:choose>
        </ul>
      </td>
    </tr>

    <!-- pending jobs: -->
    <xsl:variable name="state_qw"  select="count(//job_info/job_list[state[.='qw'] ])"/>
    <xsl:variable name="state_hqw" select="count(//job_info/job_list[state[.='hqw'] ])"/>

    <tr>
      <th>Pending Jobs</th>
      <td/>
      <td colspan="2">
        <ul>
          <xsl:choose>
          <xsl:when test="$PJ_total &gt; 0" >
            <li>
              <xsl:value-of select="$PJ_total"/> jobs
              (<xsl:value-of select="$PJ_slots"/> slots)
            </li>
            <ul>
              <xsl:if test="$state_qw &gt; 0" >
                <li><xsl:value-of select="$state_qw"/>
                  jobs reporting state '<em>qw</em>'
                </li>
              </xsl:if>
              <xsl:if test="$state_hqw &gt; 0" >
                <li><xsl:value-of select="$state_hqw"/>
                  jobs reporting state '<em>hqw</em>'
                </li>
              </xsl:if>
            </ul>
          </xsl:when>
          <xsl:otherwise>
            <li>none</li>
          </xsl:otherwise>
          </xsl:choose>
        </ul>
      </td>
    </tr>
  </table>
  </div>
  </blockquote>
</xsl:when>
<xsl:otherwise>
  &newline;
  <xsl:comment> Active Jobs </xsl:comment>
  &newline;

  <blockquote>
  <xsl:choose>
  <xsl:when test="$AJ_total &gt; 0">
    <!-- active jobs: -->
    <table class="listing">
      <tr>
      <td valign="middle">
        <div class="tableCaption">
          <xsl:value-of select="$AJ_total"/> active jobs
          <xsl:if test="string-length($filterByUser)">
            for <xsl:value-of select="$filterByUser"/>
          </xsl:if>
          (<xsl:value-of select="$AJ_slots"/> slots)
        </div>
        <!-- show/hide the activeJobTable via javascript -->
        <xsl:call-template name="toggleElementVisibility">
          <xsl:with-param name="name" select="'activeJobTable'"/>
        </xsl:call-template>
      </td>
      </tr>
    </table>
    <div id="activeJobTable">
      <table class="listing">
        <tr>
        <th>jobId</th>
        <th>owner</th>
        <th>name</th>
        <th>slots</th>
        <th>tasks</th>
        <th>queue</th>
        <th><acronym title="priority">startTime</acronym></th>
        <th>state</th>
        </tr>

  <!--
     | potential bug here
     | we need to research all possible non-pending states that could be reported
     | as we currently only catch items marked as running or transferring
     -->

       <!-- select running or transferring jobs -->
        <xsl:for-each select="//job_list[@state='running'] | //job_list[@state='transferring']">
          <!-- sorted by job number and by task-->
          <xsl:sort select="JB_job_number"/>
          <xsl:sort select="tasks"/>
          <xsl:variable name="jobIdent" select="concat(JB_job_number,';',tasks)"/>
          <xsl:variable name="thisNode" select="generate-id(.)"/>
          <xsl:variable name="allNodes" select="key('jobTask-summary', $jobIdent)"/>
          <xsl:variable name="firstNode" select="generate-id($allNodes[1])"/>

          <xsl:if test="$thisNode = $firstNode">
            <xsl:apply-templates select="." mode="summary"/>
          </xsl:if>
        </xsl:for-each>
      </table>
    </div>
  </xsl:when>
  <xsl:otherwise>
    <!-- no active jobs -->
    <div class="skipTableFormat">
      <img alt="*" src="css/screen/list_bullet.png" />
      no active jobs
      <xsl:if test="string-length($filterByUser)">
        for user <em><xsl:value-of select="$filterByUser"/></em>
      </xsl:if>
    </div>
  </xsl:otherwise>
  </xsl:choose>
  </blockquote>

  &newline;
  <xsl:comment> Pending Jobs </xsl:comment>
  &newline;

  <blockquote>
  <xsl:choose>
  <xsl:when test="$PJ_total &gt; 0">
    <!-- pending jobs: -->
    <table class="listing">
      <tr>
      <td valign="middle">
        <div class="tableCaption">
          <xsl:value-of select="$PJ_total"/> pending jobs
          <xsl:if test="string-length($filterByUser)">
            for <xsl:value-of select="$filterByUser"/>
          </xsl:if>
          (<xsl:value-of select="$PJ_slots"/> slots)
        </div>
        <!-- show/hide the pendingJobTable via javascript -->
        <xsl:call-template name="toggleElementVisibility">
          <xsl:with-param name="name" select="'pendingJobTable'"/>
        </xsl:call-template>
      </td>
      </tr>
    </table>
    <div id="pendingJobTable">
      <table class="listing">
        <tr>
        <th>jobId</th>
        <th>owner</th>
        <th>name</th>
        <th>slots</th>
        <th>tasks</th>
        <th><acronym title="submissionTime">priority</acronym></th>
        <th>state</th>
        </tr>
      <xsl:for-each select="//job_list[@state='pending']">
        <!-- sorted by job number -->
        <xsl:sort select="./JB_job_number"/>
        <xsl:apply-templates select="."/>
      </xsl:for-each>
      </table>
    </div>
  </xsl:when>
  <xsl:otherwise>
    <!-- no pending jobs -->
    <div class="skipTableFormat">
      <img alt="*" src="css/screen/list_bullet.png" />
      no pending jobs
      <xsl:if test="string-length($filterByUser)">
        for user <em><xsl:value-of select="$filterByUser"/></em>
      </xsl:if>
    </div>
  </xsl:otherwise>
  </xsl:choose>
  </blockquote>

</xsl:otherwise>
</xsl:choose>


<!-- bottom status bar with rendered time -->
<xsl:call-template name="bottomStatusBar">
  <xsl:with-param name="timestamp" select="$timestamp" />
</xsl:call-template>

&newline;
</div>
</body>
&newline;
<xsl:comment> javascript tricks after loading body </xsl:comment>
&newline;
<script type="text/javascript">
   // hide elements based on the cookie values
   hideDivFromCookie("activeJobTable");
   hideDivFromCookie("pendingJobTable");

   // expose toggle elements that rely on javascript
   document.getElementById("activeJobTableToggle").style.visibility = "visible";
   document.getElementById("pendingJobTableToggle").style.visibility = "visible";
</script>

</html>
<!-- end body/html -->
</xsl:template>


<!--
  host information: header
-->
<xsl:template match="//queue_info">
  <div class="queueInfoDiv" id="queueInfoTable">
  <table class="listing">
    <tr>
      <th>queue</th>
      <th>instance</th>
      <th>
        <acronym
            title="Defines if the queue supports (B)atch, (I)nteractive or (P)arallel job types"
        >type</acronym>
      </th>
      <th>usage</th>
      <th><acronym title="normalized cpu load">load</acronym></th>
      <th>system</th>
      <th>status</th>
    </tr>
  <xsl:for-each select="./Queue-List">
    <!-- for unsorted queue instances: comment-out this xsl:sort -->
    <xsl:sort select="name"/>
    <xsl:variable name="qinstance" select="name"/>
    <xsl:variable name="qname"     select="substring-before(name,'@')"/>

    <tr>
      <!-- queue -->
      <td>
        <xsl:value-of select="$qname"/>
      </td>

      <!-- instance: unqualified host -->
      <td>
        <xsl:call-template name="unqualifiedHost">
          <xsl:with-param name="host" select="substring-after(name,'@')"/>
        </xsl:call-template>
      </td>

      <!-- queue type -->
      <td>
        <xsl:value-of select="qtype"/>
      </td>

      <!-- usage -->
      <!-- NB: slots_total reported actually includes slots_used -->
      <xsl:variable name="valueUsed0"  select="slots_used"/>
      <xsl:variable name="valueTotal0" select="slots_total - slots_used"/>
      <td width="100px" align="left">
        <xsl:if test="$valueUsed0 &gt; -1">
          <xsl:call-template name="progressBar">
            <xsl:with-param name="label"   select="concat($valueUsed0, '/',
$valueTotal0)" />
            <xsl:with-param name="percent" select="($valueUsed0 div
$valueTotal0)*100"/>
          </xsl:call-template>
        </xsl:if>
      </td>

      <!-- load -->
      <!-- CPU normalized load average and (optional) graph load vs alarm threshold -->
      <xsl:choose>
      <xsl:when test="resource[@name='load_avg'] and resource[@name='num_proc']">
        <!-- load_avg and num_proc available: calculate np_load_avg -->
        <xsl:variable name="valueUsed"
            select="format-number(
                (resource[@name='load_avg'] div resource[@name='num_proc']),
                '##0.00')
            "
        />

        <!-- get alarm threshold for this queue or queue instance -->
        <xsl:variable
            name="qiThresh"
            select="$alarmFile/alarmThreshold/qi[@name=$qinstance]/@np_load_avg"
        />
        <xsl:variable
            name="qThresh"
            select="$alarmFile/alarmThreshold/q[@name=$qname]/@np_load_avg"
        />

        <xsl:variable name="valueTotal">
          <xsl:choose>
          <xsl:when test="$qiThresh"><xsl:value-of select="$qiThresh"/></xsl:when>
          <xsl:when test="$qThresh"><xsl:value-of select="$qThresh"/></xsl:when>
          <xsl:otherwise>0</xsl:otherwise>
          </xsl:choose>
        </xsl:variable>

        <xsl:choose>
        <xsl:when test="$valueTotal &gt; 0">
          <xsl:variable name="alarmPercent" select="($valueUsed div $valueTotal)*100"/>

          <td width="100px" align="center">
            <xsl:choose>
            <xsl:when test="$alarmPercent &gt;= 100">
            <xsl:call-template name="progressBar">
              <xsl:with-param name="title"   select="concat('threshold=',$valueTotal)" />
              <xsl:with-param name="label"   select="$valueUsed" />
              <xsl:with-param name="percent" select="100"/>
              <xsl:with-param name="class"   select="'alarmBar'"/>
            </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
            <xsl:call-template name="progressBar">
              <xsl:with-param name="title"   select="concat('threshold=',$valueTotal)" />
              <xsl:with-param name="label"   select="$valueUsed" />
              <xsl:with-param name="percent" select="$alarmPercent"/>
            </xsl:call-template>
            </xsl:otherwise>
            </xsl:choose>
          </td>

        </xsl:when>
        <xsl:otherwise>
          <!-- no threshold for this queue instance -->
          <td width="100px" align="center"><xsl:value-of select="$valueUsed"/></td>
        </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <!-- missing load_avg or num_proc -->
        <td class="emphasisCode" align="center">unknown</td>
      </xsl:otherwise>
      </xsl:choose>


      <!-- arch -->
      <td>
        <xsl:value-of select="arch"/>
      </td>

      <!-- state -->
      <xsl:variable name="state" select="state"/>
      <td>
        <xsl:call-template name="queue-state-icon">
          <xsl:with-param name="state" select="$state"/>
        </xsl:call-template>
        &space;
        <xsl:call-template name="queue-state-explain">
          <xsl:with-param name="state" select="$state"/>
        </xsl:call-template>
      </td>

    </tr>

    <!--
    <xsl:template match="Queue-List" mode="sortByQueue">
    -->
  </xsl:for-each>
  </table>
  </div>
</xsl:template>



<xsl:template match="Queue-List/resource">
  <xsl:value-of select="@name"/>=<xsl:value-of select="."/>
  <br/>
</xsl:template>


<xsl:template match="job_list[@state='pending']">
<!-- per user sort: BEGIN -->
<xsl:if test="not(string-length($filterByUser)) or JB_owner=$filterByUser">
&newline; <xsl:comment>Begin Pending Job Row</xsl:comment> &newline;
  <tr>
    <!-- jobId: link owner names to "jobinfo?jobId" -->
    <td>
      <xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:text>jobinfo</xsl:text>
          <xsl:value-of select="$clusterSuffix"/>
          <xsl:value-of select="$urlExt"/>?<xsl:value-of select="JB_job_number"/>
        </xsl:attribute>
        <xsl:attribute name="title">details for job <xsl:value-of select="JB_job_number"/></xsl:attribute>
        <xsl:value-of select="JB_job_number"/>
      </xsl:element>
    </td>

    <!-- owner: link owner names to "jobs?user={owner}" -->
    <td>
      <xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:text>jobs</xsl:text>
          <xsl:value-of select="$clusterSuffix"/>
          <xsl:value-of select="$urlExt"/>?user=<xsl:value-of select="JB_owner"/>
        </xsl:attribute>
        <xsl:attribute name="title">view jobs owned by user <xsl:value-of select="JB_owner"/></xsl:attribute>
        <xsl:value-of select="JB_owner"/>
      </xsl:element>
    </td>

    <!-- jobName -->
    <td>
      <xsl:call-template name="shortName">
        <xsl:with-param name="name" select="JB_name"/>
      </xsl:call-template>
    </td>

    <!-- slots -->
    <td>
      <xsl:value-of select="slots"/>
    </td>

    <!-- tasks -->
    <td>
      <xsl:value-of select="tasks"/>
    </td>

    <!-- priority with submissionTime -->
    <td>
      <xsl:element name="acronym">
        <xsl:attribute name="title">
          <xsl:value-of select="JB_submission_time"/>
        </xsl:attribute>
        <xsl:value-of select="JAT_prio" />
      </xsl:element>
    </td>

    <!-- state -->
    <td>
<!-- disable icons in pending state column until we can make them smaller
      <xsl:choose>
      <xsl:when test="state='qw'">
        <acronym title="Pending (qw)">
          <img src="css/screen/icons/time.png" />
        </acronym>
      </xsl:when>
      <xsl:when test="state='hqw'">
        <acronym title="Pending with hold state (hqw)">
          <img src="css/screen/icons/time_add.png" />
        </acronym>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="state"/>
      </xsl:otherwise>
      </xsl:choose>
-->
      <xsl:value-of select="state"/>
    </td>
  </tr>

  <!-- output info about any resources that were specifically requested ... -->
  <xsl:if test="hard_request">
    &newline;
    <tr class="emphasisCode">
      <td colspan="8" align="right">
        hard request:
        <xsl:apply-templates select="hard_request"/>
      </td>
    </tr>
  </xsl:if>

</xsl:if>   <!-- per user sort: END -->
</xsl:template>


<!-- Hard Resource Request Strings -->
<xsl:template match="hard_request">
  <xsl:value-of select="@name"/>=<xsl:value-of select="."/>
  &space;
</xsl:template>

<xsl:template match="Queue-List/job_list" mode="summary">
<xsl:if test="not(string-length($filterByUser)) or JB_owner=$filterByUser">

  <xsl:variable name="jobId"  select="JB_job_number" />
  <xsl:variable name="taskId" select="tasks" />
  <xsl:variable name="nodeList">
    <xsl:choose>
    <xsl:when test="$taskId">
      <xsl:value-of
          select="../../Queue-List/job_list/slots[../JB_job_number = $jobId and ../tasks = $taskId]"
      />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of
          select="../../Queue-List/job_list/slots[../JB_job_number = $jobId]"
      />
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- count siblings -->
  <xsl:variable name="nInstances">
    <xsl:choose>
    <xsl:when test="$taskId">
      <xsl:value-of
          select="count(../../Queue-List/job_list/slots[../JB_job_number = $jobId and ../tasks = $taskId])"
      />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of
          select="count(../../Queue-List/job_list/slots[../JB_job_number = $jobId])"
      />
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="slots">
    <xsl:choose>
    <xsl:when test="$taskId">
      <xsl:value-of
          select="sum(../../Queue-List/job_list/slots[../JB_job_number = $jobId and ../tasks = $taskId])"
      />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of
          select="sum(../../Queue-List/job_list/slots[../JB_job_number = $jobId])"
      />
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <tr>
    <!-- jobId: link owner names to "jobinfo?jobId" -->
    <td>
      <xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:text>jobinfo</xsl:text>
          <xsl:value-of select="$clusterSuffix"/>
          <xsl:value-of select="$urlExt"/>?<xsl:value-of select="JB_job_number"/>
        </xsl:attribute>
        <xsl:attribute name="title">details for job <xsl:value-of select="JB_job_number"/></xsl:attribute>
        <xsl:value-of select="JB_job_number"/>
      </xsl:element>
    </td>

    <!-- owner: link owner names to "jobs?user={owner}" -->
    <td>
      <xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:text>jobs</xsl:text>
          <xsl:value-of select="$clusterSuffix"/>
          <xsl:value-of select="$urlExt"/>?user=<xsl:value-of select="JB_owner"/>
        </xsl:attribute>
        <xsl:attribute name="title">view jobs owned by user <xsl:value-of select="JB_owner"/></xsl:attribute>
        <xsl:value-of select="JB_owner"/>
      </xsl:element>
    </td>

    <!-- jobName -->
    <td>
      <xsl:call-template name="shortName">
        <xsl:with-param name="name" select="JB_name"/>
      </xsl:call-template>
    </td>

    <!-- slots -->
    <td>
      <xsl:value-of select="$slots"/>
    </td>

    <!-- tasks -->
    <td>
      <xsl:value-of select="tasks"/>
    </td>

    <!-- queue instance: take the first one even if it is not the master -->
    <td>
      <xsl:choose>
      <xsl:when test="$nInstances &gt; 1">
        <xsl:element name="acronym">
          <xsl:attribute name="title">
            <xsl:for-each select="../../Queue-List/name[../job_list/JB_job_number = $jobId]">
              <xsl:call-template name="unqualifiedQueue">
                <xsl:with-param name="queue" select="."/>
              </xsl:call-template>
              &space;
            </xsl:for-each>
          </xsl:attribute>
          <xsl:call-template name="unqualifiedQueue">
            <xsl:with-param name="queue" select="../name"/>
          </xsl:call-template>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="unqualifiedQueue">
          <xsl:with-param name="queue" select="../name"/>
        </xsl:call-template>
      </xsl:otherwise>
      </xsl:choose>
    </td>

    <!-- startTime with priority -->
    <td>
      <xsl:element name="acronym">
        <xsl:attribute name="title">
          <xsl:value-of select="JAT_prio"/>
        </xsl:attribute>
        <xsl:value-of select="JAT_start_time" />
      </xsl:element>
    </td>

    <!-- state -->
    <td>
      <xsl:choose>
      <xsl:when test="state='r'">r</xsl:when>
      <xsl:when test="state='S'">
        <acronym title="Job in (S)ubordinate suspend state">
          <img alt="" src="css/screen/icons/error.png" />
        </acronym>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="state"/>
      </xsl:otherwise>
      </xsl:choose>
    </td>
  </tr>
</xsl:if>
</xsl:template>


</xsl:stylesheet>

<!-- =========================== End of File ============================== -->
