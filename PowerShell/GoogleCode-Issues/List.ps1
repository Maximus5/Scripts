param([String]$workmode="tasks",[String]$options="",[String]$aliases="yes",[int]$listpriority=8)

# How to use this script in ConEmu?
# Create new Task in ConEmu settings with
#   Command
#     powershell -NoProfile -NoExit -Command "Import-Module {FullPath}\List.ps1 -ArgumentList 'Tasks'"
#   Task parameters
#     /dir {FullPath}
# Replace {FullPath} with your path, for example C:\Source\ConEmu
# Script will show not fixed tasks with priority larger or equal to 8
# In the powershell prompt you can use commands "Fix" and "UnFix"
# 
# Also, you may run script nightly to retrieve new Issues from GoogleCode and update your ToDo xml file
#   powershell -NoProfile -Command "Import-Module {FullPath}\List.ps1 -ArgumentList update"

$GoogleCodeProjectName = "conemu-maximus5"
$DefaultAuthor = "Maximus"
$Script_Working_path = (Get-Location).Path
$Script_xml_ToDo_path = ($Script_Working_path+"\ConEmu-ToDo.xml")
$Script_xml_Save_path = ($Script_Working_path+"\ConEmu-ToDo.xml")
$Issues_Save_CSV = ($Script_Working_path+"\html_list\Issues-")
$Issues_Save_HTML = ($Script_Working_path+"\html\")
$SkipAutoUpdatePC = "MAX"
#$Editor = "far -e1:1"
$Editor = ""
# Some hrefs
$googlecode_issue_href = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/detail?id=")
$http_prefix = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/detail?id=")
$list_prefix = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/list?can=1&q=&colspec=ID%20Stars%20Type%20Status%20Modified%20Reporter%20Summary&sort=id%20-modified")
$csv_prefix  = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/csv?can=1&q=&colspec=ID%20Stars%20Type%20Status%20Modified%20Reporter%20Summary&sort=id%20-modified")
$last_csv_prefix  = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/csv?can=1&q=&colspec=ID%20Stars%20Type%20Status%20Modified%20Reporter%20Summary&sort=-id%20-modified")
$recent_csv_prefix  = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/csv?can=1&q=&colspec=ID%20Stars%20Type%20Status%20Modified%20Reporter%20Summary&sort=-modified%20-id")
# This task will get new GC issues, just create a task
# named "Imported" in your ToDo list before usage
$xml_path_imported = "/TODOLIST//TASK[@TITLE='Imported']"
# Crash reports will be placed here
$xml_path_crashs = "/TODOLIST/TASK[starts-with(@TITLE,'Crashes')]"
# List of root items
$xml_path_roots = "/TODOLIST/TASK"
# Subtask "Fixed", if not found - fixed tasks
# will be placed in the "Imported" task
$xml_path_importedFixed = "TASK[@TITLE='Fixed']"

# Search these words in the issue text -> Put them in the $xml_path_crashs task
$CrashWords = @("crash","hung","����","����")
# These statuses -> Import as fixed
$FixedWords = @("Duplicate","Fixed","Invalid","WontFix","Done")


# Some helper functions
function IsNumeric($Value)
{
  if ($Value -eq $null) {
    return $FALSE
  }
  return $Value -match "^[\d]+$"
}

function iif ( $c, $a, $b )
{
  if ($c) {
    return $a
  } else {
    return $b
  }
}

function ToDoList-LoadXml
{
  $x = [xml](Get-Content $Script_xml_ToDo_path)
  return $x
}

function ToDoList-SaveXml([xml]$x)
{
  Write-Host -ForegroundColor Green "Saving changes..."
  $x.Save($Script_xml_Save_path)
}

function ToDoList-GetTaskId
{
  Write-Host -ForegroundColor Gray "TaskID (### or 'e###'): " -NoNewline
  $id = (Read-Host)
  return $id
}

# You may get task by "ID" ($i param)
# or by "EXTERNALID" ($eid param) which is GC issue now
function ToDoList-GetTask([String]$i="0",[xml]$x=$null,[int]$eid=0)
{
  if ($x -eq $null) {
    $x = ToDoList-LoadXml
  }

  if (($i -eq 0) -And ($eid -eq 0)) {
    $GetId = ToDoList-GetTaskId
    if ((($GetId.SubString(0,1)) -eq "e") -Or (($GetId.SubString(0,1)) -eq "i")) {
      $eid = [int]($GetId.SubString(1))
    } else {
      $i = [int]$GetId
    }
  } elseif ((($i.SubString(0,1)) -eq "e") -Or (($i.SubString(0,1)) -eq "i")) {
    #tc e1431
    $eid = [int]($i.SubString(1))
    $i = 0
  }

  if ($i -gt 0) {
    $x_path = ("TODOLIST//TASK[@ID='" + $i + "']")
  } elseif ($eid -gt 0) {
    $x_path = ("TODOLIST//TASK[@EXTERNALID='" + $eid + "']")
  } else {
    return $null
  }

  return $x.SelectNodes($x_path)
}

function ToDoList-GetTaskChild([String]$i="0",[String]$node="TAG",[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  $s = $t.SelectSingleNode($node)

  if ($s -ne $null) {
    return $s."#text"
  } else {
    return ""
  }
}

function ToDoList-DumpException($error)
{
  Write-Host -ForegroundColor Red $error.Exception
}

function ToDoList-SetTaskChild([String]$i="0",[String]$node="TAG",[String]$new="",[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  $s = $t.SelectSingleNode($node)

  try {
    if ($s -eq $null) {
      $s = $x.CreateElement($node)
      $s.InnerText = $new
      $v = $t.AppendChild($s)
    } else {
      $s."#text" = $new
    }
    if ($DoSave) {
      ToDoList-SaveXml $x
    } else {
      return
    }
  } catch {
    ToDoList-DumpException $error[0]
  }

  return
}

function ToDoList-GetStars([String]$i="0",[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  $s = $t.SelectSingleNode("CUSTOMATTRIB[@ID='CUST_STARS']")

  if ($s -eq $null) {
    return 0
  } elseif ($s.HasAttribute("VALUE")) {
    if (IsNumeric $s.VALUE) {
      return [int]$s.VALUE
    } else {
      return 0
    }
  } else {
    return 0
  }
}

function ToDoList-SetStars([String]$i="0",[String]$new,[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0,[Boolean]$IncOnly=$FALSE)
{
  $is_modified = $FALSE
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  $s = $t.SelectSingleNode("CUSTOMATTRIB[@ID='CUST_STARS']")

  try {
    # <CUSTOMATTRIB ID="CUST_STARS" VALUE="1"/>
    if ($s -eq $null) {
      $s = $x.CreateElement("CUSTOMATTRIB")
      $v = $s.SetAttribute("ID","CUST_STARS")
      $v = $s.SetAttribute("VALUE",$new)
      $v = $t.AppendChild($s)
      $is_modified = $TRUE
      $script:modified = $TRUE
    } elseif ($s.GetAttribute("VALUE") -ne $new) {
      if ($IncOnly) {
        if (([int]$s.GetAttribute("VALUE")) -ge ([int]$new)) {
          return $FALSE # Do not set lesser
        }
      }
      $v = $s.SetAttribute("VALUE",$new)
      $is_modified = $TRUE
      $script:modified = $TRUE
    }
    if ($DoSave) {
      ToDoList-SaveXml $x
    }
  } catch {
    ToDoList-DumpException $error[0]
  }
  return $is_modified
}

function ToDoList-SetTaskAttr([String]$i="0",[String]$attr="",[String]$new="",[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  if ($attr -eq "stars") {
    ToDoList-SetStars -t $t -x $x -new $new -DoSave $DoSave
  } else {
    try {
      $t.SetAttribute($attr,$new)
      if ($DoSave) {
        ToDoList-SaveXml $x
      }
    } catch {
      ToDoList-DumpException $error[0]
    }
  }
}


function ToDoList-FormatTaskInfo($t)
{
  function pad([String]$str,[int]$pad)
  {
    if ($str -ne $null)
    {
      if ($str.Length -gt $pad-1) {
        $str.Substring(0,$pad-1).PadRight($pad)
      } else {
        $str.PadRight($pad)
      }
    } else {
      "".PadRight($pad)
    }
  }

  $s = $t.ID.PadRight(5) + (pad -str $t.ExternalId -pad 5) + (pad -str $t.Priority -pad 3)
  #if ($t.ExternalId -ne $null) { $s += $t.ExternalId.PadRight(5) } else { $s += "".PadRight(5) }
  #$s += $t.Priority.PadRight(3)
  $s += pad -str ([String](ToDoList-GetStars -t $t)) -pad 3
  #$a = $t.ALLOCATEDBY
  if ($t.STATUS -ne $null) {
    $s += pad -str $t.STATUS -pad 10
  } else {
    $s += pad -str (ToDoList-GetTaskChild -t $t -node "TAG") -pad 10
  }
  $s += pad -str $t.ALLOCATEDBY -pad 12
  #if ($t.ALLOCATEDBY -ne $null) { $s += $t.ALLOCATEDBY.Substring(0,11).PadRight(12) } else { $s += "".PadRight(12) }
  return $s
}

function ToDoList-TaskHasString([System.Xml.XmlElement]$t,[String]$find)
{
  # Ensure that it will be case-insensitive
  $find = $find.ToUpper()
  if (($_.TITLE -ne $null) -And ($_.TITLE.ToUpper().IndexOf($find) -ge 0)) { return $TRUE }
  if (($_.COMMENTS -ne $null) -And ($_.COMMENTS.ToUpper().IndexOf($find) -ge 0)) { return $TRUE }
  if (($_.ALLOCATEDBY -ne $null) -And ($_.ALLOCATEDBY.ToUpper().IndexOf($find) -ge 0)) { return $TRUE }
  return $FALSE
}

#function ToDoList-GetTaskMatch([System.Xml.XmlElement]$t,[int]$priority=8,[String]$find="")

function ToDoList-GetTasks($parm1=8,$parm2="",[xml]$x=$null,[String]$find="",[Boolean]$ShowFixed=$FALSE)
{
  $priority = 8
  $sort = ""

  # simplify cmd line calls
  if ($parm1 -ne "") {
    if (IsNumeric $parm1) {
      $priority = [int]$parm1
    } else {
      $sort = $parm1
      # when sorting by externalid (IssueNO) - show all with priority 5 or higher (by default)
      if ($sort -eq "eid") {
        $priority = 5
      }
    }
  }
  if ($parm2 -ne "") {
    if ($sort -eq "") {
      $sort = $parm2
    }
  }


  Write-Host -ForegroundColor Green -NoNewline "Please wait, loading..."
  if ($x -eq $null) {
    $x = ToDoList-LoadXml
  }

  if ($ShowFixed) { $max_percent = 1000 } else { $max_percent = 99 }


  Write-Host -ForegroundColor Green " filtering, sorting..."

  if ($find -ne "") {
    $local:tasks = $x.SelectNodes("TODOLIST//TASK") `
      | where { [int]$_.PERCENTDONE -le $max_percent} | where {ToDoList-TaskHasString $_ $find} `
      | sort {[int]$_.ID}
  } elseif ($sort -eq "id") {
    $local:tasks = $x.SelectNodes("TODOLIST//TASK") `
      | where { [int]$_.Priority -ge $priority} | where { [int]$_.PERCENTDONE -le $max_percent} `
      | sort {[int]$_.ID}
  } elseif ($sort -eq "eid") {
    $local:tasks = $x.SelectNodes("TODOLIST//TASK") `
      | where { [int]$_.EXTERNALID -ne ""} | where { [int]$_.Priority -ge $priority} | where { [int]$_.PERCENTDONE -le $max_percent} `
      | sort {[int]$_.EXTERNALID},{[int]$_.ID}
  } elseif ($sort -eq "cd") {
    $local:tasks = $x.SelectNodes("TODOLIST//TASK") `
      | where { [int]$_.Priority -ge $priority} | where { [int]$_.PERCENTDONE -le $max_percent} `
      | sort {[double](iif -c ($_.LASTMOD -ne $null) -a $_.LASTMOD -b $_.CreationDate)},{[int]$_.ID}
  } elseif (($sort -eq "st") -or ($sort -eq "Stars")) {
    $local:tasks = $x.SelectNodes("TODOLIST//TASK") `
      | where { [int]$_.Priority -ge $priority} | where { [int]$_.PERCENTDONE -le $max_percent} `
      | sort {[int](ToDoList-GetStars -t $_)},{[int]$_.Priority},{[double](iif -c ($_.LASTMOD -ne $null) -a $_.LASTMOD -b $_.CreationDate)},{[int]$_.ID}
  } else {
    $local:tasks = $x.SelectNodes("TODOLIST//TASK") `
      | where { [int]$_.Priority -ge $priority} | where { [int]$_.PERCENTDONE -le $max_percent} `
      | sort {[int]$_.Priority},{[int](ToDoList-GetStars -t $_)},{[double]$_.CreationDate}
  }

  $local:tasks | ft {ToDoList-FormatTaskInfo $_},"TITLE" -AutoSize -HideTableHeader
  Write-Host "[2A[1;32;45mTotal count:[1;37;45m " $local:tasks.Length "`r`n"

  return
}

function ToDoList-TaskFix([String]$i="0",[xml]$x=$null,[int]$eid=0)
{
  try {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
    
    $t.SetAttribute("PERCENTDONE","100")
    #$t.PERCENTDONE = "100"

    $dt = Get-Date
    $dtOA = [String]$dt.ToOADate() # ex "41604.05045139"
    $dtST = ($dt.ToShortDateString()+" "+$dt.ToShortTimeString())
    $t.SetAttribute("DONEDATE",$dtOA)
    $t.SetAttribute("DONEDATESTRING",$dtST)

    ToDoList-SaveXml $x
    # ToDoList-GetTasks -x $x
  }
  catch {
    ToDoList-DumpException $error[0]
    Write-Host -ForegroundColor Red ("Fix "+$i+" failed!")
  }
}

function ToDoList-TaskUnFix([String]$i="0",[xml]$x=$null,[int]$eid=0)
{
  try {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid

    $t.SetAttribute("PERCENTDONE","0")
    #$t.PERCENTDONE = "0"
    $t.RemoveAttribute("DONEDATE")
    $t.RemoveAttribute("DONEDATESTRING")

    ToDoList-SaveXml $x
    # ToDoList-GetTasks -x $x
  }
  catch {
    ToDoList-DumpException $error[0]
    Write-Host -ForegroundColor Red ("UnFix "+$i+" failed!")
  }
}

function ToDoList-TaskSetInt([String]$i="0",[String]$field="",[String]$value="",[xml]$x=$null,[int]$eid=0,[Boolean]$DoSave=$TRUE,[System.Xml.XmlElement]$t=$null)
{
  try {
    if (($i -eq 0) -And ($eid -eq 0)) {
      $GetId = ToDoList-GetTaskId
      if ((($GetId.SubString(0,1)) -eq "e")) {
        $eid = [int]($GetId.SubString(1))
      } else {
        $i = [int]$GetId
      }
    }

    if (($i -eq 0) -And ($eid -eq 0)) {
      return
    }

    if ($field -eq "") {
      Write-Host -ForegroundColor Gray "Field (Title,PercentDone,Stars,Status,Tag,...): " -NoNewline
      $field = Read-Host
    }

    if ($value -eq "") {
      Write-Host -ForegroundColor Gray "New value: " -NoNewline
      $value = Read-Host
    }

    $field = $field.ToUpper()
    if ($field -eq "PERCENTDONE") {
      if ($value -eq "100") {
        ToDoList-TaskFix -i $i -x $x -eid $eid
      } else {
        ToDoList-TaskUnFix -i $i -x $x -eid $eid
      }
      return
    }
    elseif ($field -eq "STARS") {
      ToDoList-SetStars -i $i -new $value -x $x -DoSave $DoSave -eid $eid
      return
    }

    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }

    if ($t -eq $null) {
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
    }

    if ($t.HasAttribute($field) -Or ($field -eq "STATUS")) {
      $t.SetAttribute($field,$value)
    } elseif ($field -eq "TAG") {
      ToDoList-SetTaskChild -node $field -new $value -x $x -t $t -DoSave $FALSE
    } elseif ($field -eq "COMMENTS") {
      ToDoList-SetComment -new $value -x $x -t $t -DoSave $FALSE
    } else {
      Write-Host -ForegroundColor Red ("Field '"+$field+"' not found in the Task!")
      return
    }

    if ($DoSave) {
    ToDoList-SaveXml $x
    }
    # ToDoList-GetTasks -x $x
  }
  catch {
    ToDoList-DumpException $error[0]
    Write-Host -ForegroundColor Red ("TaskSetInt "+$i+" failed!")
  }
}

function ToDoList-TaskSet()
{
  if ($args.length -eq 0) {
    return ToDoList-TaskSetInt
  } elseif ($args.length -eq 1) {
    $arg0 = [String]$args[0]
    if ((($arg0.SubString(0,1)) -eq "e") -Or (($arg0.SubString(0,1)) -eq "i")) {
      return ToDoList-TaskSetInt -eid ($arg0.SubString(1))
    } else {
      return ToDoList-TaskSetInt $arg0
    }
  } elseif (($args.length -eq 2) -And ($args[0] -eq "-eid")) {
    return ToDoList-TaskSetInt -eid [int]($args[1])
  }

  # Well, not we parse arguments one-by-one
  $i = 0
  $eid = 0
  $idx = 0

  if ($args[0] -eq "-eid") {
    $idx++
    $eid = [int]$args[$idx]
  } elseif ((([String]$args[0]).Substring(0,1) -eq "e") -Or (([String]$args[0]).Substring(0,1) -eq "i")) {
    $eid = [int](([String]$args[0]).Substring(1))
  } else {
    $i = [int]$args[$idx]
  }
  $idx++

  if ($x -eq $null) {
    $x = ToDoList-LoadXml
  }
  $t = ToDoList-GetTask -i $i -x $x -eid $eid

  while ($idx -lt $args.length) {
    if (($idx + 1) -lt $args.length) {
      $newval = $args[($idx+1)]
    } else {
      $newval = ""
    }
    ToDoList-TaskSetInt -i $i -field $args[$idx] -value $newval -x $x -eid $eid -DoSave $FALSE -t $t
    $idx += 2
  }

  ToDoList-SaveXml $x
}

function ToDoList-TaskStatus([String]$i="0",[String]$value="",[xml]$x=$null,[int]$eid=0)
{
  if ($value -eq "") {
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
    if ($t.HasAttribute("STATUS")) {
      $t.STATUS
    } else {
      Write-Host -ForegroundColor Red "No status yet"
    }
  } else {
    ToDoList-TaskSetInt -i $i -field "STATUS" -value $value -x $x -eid $eid
  }
}

#$i = $x.SelectNodes("TODOLIST//TASK")[0]
#$x.SelectNodes("TODOLIST//TASK") | ft
#$x.SelectNodes("TODOLIST//TASK") | ft "ID","EXTERNALID","PERCENTDONE","ALLOCATEDBY","TITLE" -AutoSize
#$x.SelectNodes("TODOLIST//TASK") | sort "EXTERNALID" | ft "ID","EXTERNALID","PERCENTDONE","ALLOCATEDBY","TITLE" -AutoSize
#$x.SelectNodes("TODOLIST//TASK") | where { [int]$_.Priority -ge 8} | where { [int]$_.PERCENTDONE -le 99} | sort {[int]$_.Priority} | ft "ID","EXTERNALID","PRIORITY","PERCENTDONE","ALLOCATEDBY","TITLE" -AutoSize
#$x.SelectNodes("TODOLIST//TASK") | where { [int]$_.Priority -ge 8} | where { [int]$_.PERCENTDONE -le 99} | sort {[int]$_.Priority} | ft {($_.id+"-"+$_.ExternalId), ($_.Priority+" "+$_.AllocatedBy.Substring(0,10)), $_.Title} -AutoSize -HideTableHeader

# Some issues may contains symbols, which xml can't process (Parse error 0xc00ce51f) on "&#x1E;"
# https://code.google.com/p/conemu-maximus5/issues/detail?id=1129
# &lt;a title="" href="/p/conemu-maximus5/wiki/ConEmu"&gt;ConEmu&lt;/a&gt;CD.dll!_memmove&#x1E;() C++
function ToDoList-FormatXmlText($cmt)
{
  $Analogues = @(1, 9786, 2, 9787, 3, 9829, 4, 9830, 5, 9827, 6, 9824, 7, 8226,
    8, 9688, 11, 9794, 12, 9792, 14, 9835, 15, 9788, 16, 9658, 17, 9668, 18, 8597,
    19, 8252,  20, 182,  21, 167, 22, 9632, 23, 8616, 24, 8593, 25, 8595,
    26, 8594, 27, 8592, 28, 8735, 29, 8596, 30, 9650, 31, 9660)
  for ($i=0; $i -lt $Analogues.Length; $i+=2) {
    $cmt = $cmt.Replace([char]($Analogues[$i]), [char]($Analogues[$i+1]))
  }
  return $cmt
}

function ToDoList-CreateWebClient
{
  if ($script:nwc -eq $null)
  {
    $script:nwc = (new-object net.webclient)
    $script:nwc.Encoding = [System.Text.Encoding]::UTF8
  }
  return $script:nwc
}

function ToDoList-RetrieveIssueFiles([int]$eid=0,[String]$issue="")
{
  $nwc = ToDoList-CreateWebClient

  if ($issue -eq "") {
    $issue = ToDoList-RetrieveIssue $eid
  }

  $sEnd = "`">Download</a>"
  $sBegin = "<a href=`""

  $iAttachNo = 0

  $iEnd = $issue.IndexOf($sEnd)
  while ($iEnd -ge 0) {
    $iBegin = $issue.LastIndexOf($sBegin,$iEnd)
    if ($iBegin) {
      $href = $issue.Substring($iBegin+$sBegin.Length, $iEnd-$iBegin-$sBegin.Length)
      $href = $href.Replace("&amp;","&")

      $iAttachNo++

      $sName = ""
      $iFile = $href.IndexOf("&name=")
      if ($iFile -lt 0) { $iFile = $href.IndexOf("?name=") }
      if ($iFile -ge 0) {
        $iFileEnd = $href.IndexOf("&",$iFile+6)
        if ($iFileEnd -gt 0) {
          $sName = $href.Substring($iFile+6, $iFileEnd-$iFile-6)
        } else {
          $sName = $href.Substring($iFile+6)
        }
      }
      if ($sName -eq "") { $sName = ("File_"+$iAttachNo) }

      #Write-Host ("'"+$href+"', FileName='"+$sName+"'")
      $FilePath = ($Issues_Save_HTML + "Issue " + $eid)
      if (-Not (Test-Path $FilePath -pathType container)) {
        mkdir $FilePath | Out-Null
      }

      $FullPath = ($FilePath+"\"+$sName)
      if (-Not (Test-Path $FullPath -pathType leaf)) {
        $nwc.DownloadFile($href,$FullPath)
      }
    }
    $iEnd = $issue.IndexOf("`">Download</a>", $iEnd+$sEnd.Length)
  }

  return
}

function ToDoList-RetrieveIssue([int]$eid=0)
{
  $http = ($http_prefix + $eid)
  $script:IssuePage = ""

  try {
    #Write-Host -NoNewline $http
    $nwc = ToDoList-CreateWebClient
    $nwc.BaseAddress = ""
    $script:IssuePage = $nwc.DownloadString($http)
    $nwc.BaseAddress = $http
  } catch {
    $se = [String]$error[0].Exception
    if ($se.IndexOf("(404)") -ge 0) {
      $script:IssuePage = ("<pre>Issue not found on server!`r`n" + $http + "`r`n" + $error[0].Exception + "</pre>")
    } else {
      ToDoList-DumpException $error[0]
    }
    Write-Host -ForegroundColor Red ($http + " - NOT FOUND")
  }

  return $script:IssuePage
}

function ToDoList-GetCommentExt([int]$eid=0)
{
  $cmt = ""
  $data = ToDoList-RetrieveIssue $eid

  $i1 = $data.IndexOf("<pre>")
  if ($i1 -ge 0) {
    $i2 = $data.IndexOf("</pre>", $i1+6)
    if ($i2 -gt 0) {
      $cmt = $data.Substring($i1+5, $i2-$i1-5).Trim(" `r`n")
      #trick, if DownloadString returns "broken" string for russian texts
      #$cmt = [system.text.encoding]::UTF8.GetString([system.text.encoding]::Default.GetBytes($cmt))
    }
  }

  if ($cmt -eq "") {
    $cmt = ("Issue text not found!`r`n" + $http)
  }

  return ToDoList-FormatXmlText $cmt
}

function ToDoList-ShowComment([String]$i="0",[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  if ($t -ne $null) {
    $s = $t.SelectSingleNode("COMMENTS")
  }

  if ((($s -eq $null) -Or ($s -eq "")) -And ($eid -gt 0)) {
    $s = ToDoList-GetCommentExt -eid $eid
  }

  if (($s -ne $null) -And ($s -ne "")) {
    $cmt = $s."#text"
  } else {
    $cmt = ""
  }

  if (($cmt -eq $null) -Or ($cmt -eq "")) {
    Write-Host -ForegroundColor Red "There is no comments yet"
  } else {
    Write-Host -ForegroundColor Cyan $cmt.Replace('<a title="" href="/p/conemu-maximus5/wiki/ConEmu">ConEmu</a>','ConEmu')
  }
}


function ToDoList-SetComment([String]$i="0",[String]$new,[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  $t.SetAttribute("COMMENTSTYPE","PLAIN_TEXT")

  $s = $t.SelectSingleNode("COMMENTS")
  try {
    # <COMMENTS>������ ��: Win7 Rel x86</COMMENTS>
    #if ($s -eq $null) {
      $sNew = $x.CreateElement("COMMENTS")
      $sNew.InnerText = $new
    if ($s -eq $null) {
        $v = $t.AppendChild($sNew)
      } else {
        $s.InnerText
        $v = $t.ReplaceChild($sNew,$s)
        $v.InnerText
      }
      $script:modified = $TRUE
    #} elseif ($s.InnerText -ne $new) {
    #  $s.InnerText = $new
    #  $script:modified = $TRUE
    #}
    if ($DoSave) {
      ToDoList-SaveXml $x
    } else {
      return
    }
  } catch {
    ToDoList-DumpException $error[0]
  }
}


function ToDoList-UpdateComment([String]$i="0",[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  if ($eid -eq 0) {
    $eid = [int]$t.EXTERNALID
  }

  $cmt = ToDoList-GetCommentExt -eid $eid

  if ($cmt -ne "") {
    ToDoList-SetComment -t $t -x $x -new $cmt -DoSave $DoSave
  }

  return $cmt
}

function ToDoList-PrintUpInfo([String]$id="",[String]$act="",[String]$txt="",[String]$prefix="Issue")
{
  if ($id.Length -lt 5) { $id = $id.PadRight(5) }
  Write-Host -NoNewline -ForegroundColor Green ($prefix+" "+$id+" ")
  Write-Host -NoNewline -ForegroundColor Yellow $act.PadRight(9)
  Write-Host $txt
}

function ToDoList-UpdateTasks([String]$options="")
{
  $script:LastMode = $FALSE
  if ((","+$options+",").IndexOf(",last,") -ge 0) { $script:LastMode = $TRUE }

  Write-Host -ForegroundColor Green "Please wait, updating your todo list..."

  # Load xml file (existing task list)
  $x = ToDoList-LoadXml

  # Find parent tasks
  $imp_root = $x.SelectSingleNode($xml_path_imported)
  $fix_root = $imp_root.SelectSingleNode($xml_path_importedFixed)
  $crash_root = $x.SelectSingleNode($xml_path_crashs)
  if ($imp_root -eq $null) {
    $imp_root = $x.SelectSingleNode($xml_path_roots)
    if ($imp_root -eq $null) {
      Write-Host -ForegroundColor Red "Todo list is empty, create root tasks!"
      return
    }
  }

  
  $script:new_id = [int]($x.SelectNodes("TODOLIST//TASK") | Measure "ID" -Maximum).Maximum


  function SelectParent($csv, $cmt, $imported, $fixed, $crash, $task)
  {
    # Fixed or not?
    $sPercent = "0"
    $FixedWords | foreach { if ($csv.Status -eq $_) { $sPercent = "100" } }
    if ($task.PERCENTDONE -ne $sPercent) {
      $task.SetAttribute("PERCENTDONE",$sPercent)
      $dt = (Get-Date $csv.Modified)
      $task.SetAttribute("DONEDATE",$dt.ToOADate())
      $task.SetAttribute("DONEDATESTRING",($dt.ToShortDateString()+" "+$dt.ToShortTimeString()))
      $script:modified = $TRUE
    }

    $tParent = $null

    if ($crash_root -ne $null)
    {
      $CrashWords | foreach {
        if ($csv.Summary.IndexOf($_) -ge 0) {
           $tParent = $crash_root
        }
        if ($cmt -ne $null) {
          if ($cmt.IndexOf($_) -ge 0) {
            $tParent = $crash_root
          }
        }
      }
      if ($tParent -ne $null) {
        return $tParent
      }
    }

    if ($sPercent -eq "100") {
      if ($fix_root -ne $null) { return $fix_root } else { return $imp_root }
    }

    return $imp_root
  }

  
  function ProcessRow($csv)
  {
    $is_modified = $FALSE

    if (IsNumeric($csv.ID))
    {
      $script:IssuePage = ""

      if ($csv.ID -eq "1360") {
        $i = 0
      }

      #"ProcessRow called"
      $x_path = ("TODOLIST//TASK[@EXTERNALID='" + $csv.ID + "']")
      $tt = $x.SelectSingleNode($x_path)

      $dt = (Get-Date $csv.Modified)
      $dtOA = [String]$dt.ToOADate() # ex "41604.05045139"
      $dtST = ($dt.ToShortDateString()+" "+$dt.ToShortTimeString())

      $force_html = $TRUE

      # This is new issue?
      if ($tt -eq $null) {
        #$new_id = [int]($x.SelectNodes("TODOLIST//TASK") | Measure "ID" -Maximum).Maximum + 1
        $script:new_id++

        #Write-Host $new_id
        $tNew = $x.CreateElement("TASK")
        $tNew.SetAttribute("TITLE",$csv.Summary)
        $tNew.SetAttribute("ID",[String]$script:new_id)
        $tNew.SetAttribute("REFID","0")
        $tNew.SetAttribute("COMMENTSTYPE","PLAIN_TEXT")
        $tNew.SetAttribute("ALLOCATEDBY",$csv.Reporter)
        $tNew.SetAttribute("FILEREFPATH",($googlecode_issue_href+$csv.ID))
        $tNew.SetAttribute("CREATEDBY",$csv.Reporter)
        $tNew.SetAttribute("EXTERNALID",$csv.ID)
        $tNew.SetAttribute("RISK","0")
        #$tNew.SetAttribute("PERCENTDONE",$sPercent) # it will be set in SelectParent function
        $tNew.SetAttribute("PRIORITY","5")
        #$tNew.SetAttribute("PRIORITYCOLOR","15732480")
        #$tNew.SetAttribute("PRIORITYWEBCOLOR","#000FF0")
        $tNew.SetAttribute("CREATIONDATE",$dtOA)
        $tNew.SetAttribute("CREATIONDATESTRING",$dtST)
        $tNew.SetAttribute("LASTMOD",$dtOA)
        $tNew.SetAttribute("LASTMODSTRING",$dtST)

        $lbl = $csv.AllLabels
        if ($lbl.IndexOf("Defect") -ge 0) {
          ToDoList-SetTaskChild -node "TAG" -new "Defect" -x $x -t $tNew -DoSave $FALSE
        } elseif ($lbl.IndexOf("Other") -ge 0) {
          ToDoList-SetTaskChild -node "TAG" -new "Other" -x $x -t $tNew -DoSave $FALSE
        } if ($lbl.IndexOf("Documentation") -ge 0) {
          ToDoList-SetTaskChild -node "TAG" -new "Wiki" -x $x -t $tNew -DoSave $FALSE
        } if ($lbl.IndexOf("Enhancement") -ge 0) {
          ToDoList-SetTaskChild -node "TAG" -new "Enhance" -x $x -t $tNew -DoSave $FALSE
        }

        ToDoList-SetStars -new $csv.Stars -t $tNew -x $x -DoSave $FALSE
        $cmt = ToDoList-UpdateComment -t $tNew -x $x -eid ($csv.ID) -DoSave $FALSE

        # Choose parent task
        $tParent = SelectParent $csv $cmt $imp_root $fix_root $crash_root $tNew

        # And insert new task in ToDoList
        $tApp = $tParent.AppendChild($tNew)

        ToDoList-PrintUpInfo $csv.ID "Created" $csv.Summary

        $is_modified = $TRUE
        #$csv
        #$tApp
        #$tNew

      # or existing one? Update stars and "Fixed" state
      } else {
        $printed = $FALSE

        if (IsNumeric($csv.Stars)) {
          #Write-Host ("Updating stars for "+$csv.ID+" to "+$csv.Stars+" : "+$tt.Title)
          $stars_modified = ToDoList-SetStars -new $csv.Stars -t $tt -x $x -DoSave $FALSE -IncOnly $TRUE
          #"Stars updated"
          if ($stars_modified) {
            ToDoList-PrintUpInfo $csv.ID ("Stars "+$csv.Stars) $csv.Summary
          }
        }

        $sPercent = "0"
        $FixedWords | foreach { if ($csv.Status -eq $_) { $sPercent = "100" } }
        if ($tt.PERCENTDONE -ne $sPercent) {
          $tt.SetAttribute("PERCENTDONE",$sPercent)
          #DONEDATE="41604.05045139" DONEDATESTRING="26.11.2013 1:12"
          # $dt = (Get-Date $csv.Modified)
          # $dtOA = [String]$dt.ToOADate() # ex "41604.05045139"
          # $dtST = ($dt.ToShortDateString()+" "+$dt.ToShortTimeString())
          $tt.SetAttribute("DONEDATE",$dtOA)
          $tt.SetAttribute("DONEDATESTRING",$dtST)
          $is_modified = $TRUE
          ToDoList-PrintUpInfo $csv.ID "Fixed" $csv.Summary
          $printed = $TRUE
        }

        # Date of last modification
        $saveMod = "0"
        if ($tt.HasAttribute("LASTMOD")) { $saveMod = $tt.LASTMOD }
        elseif ($tt.HasAttribute("CREATIONDATE")) { $saveMod = $tt.CREATIONDATE }
        else { $saveMod = "-1" }
        #if ($saveMod -ne $dtOA) {
        if ([math]::Abs(([Double]$saveMod)-([Double]$dtOA)) -gt 0.0000001) {
          $force_html = $TRUE
          $tt.SetAttribute("LASTMOD",$dtOA)
          $tt.SetAttribute("LASTMODSTRING",$dtST)
          $is_modified = $TRUE
          if (-Not $printed) {
            ToDoList-PrintUpInfo $csv.ID "Changed" $csv.Summary
          }
        }
      }

      # Asked to store Issues in html files?
      if ($Issues_Save_HTML -ne "") {
        $WriteIssue = $FALSE
        $file = ($Issues_Save_HTML+"Issue"+$csv.ID+".htm")
        if ($force_html) {
          $WriteIssue = $TRUE
        } elseif (-Not (Test-Path $file)) {
          $WriteIssue = $TRUE
        } elseif ((Get-Item $file).LastWriteTime -lt (Get-Date $csv.Modified)) {
          $WriteIssue = $TRUE
        }

        if ($WriteIssue) {
          if ($script:IssuePage -eq "") {
            $s = ToDoList-RetrieveIssue ([int]($csv.ID))
          }
          if ($script:IssuePage -ne "") {
            Set-Content -Path $file -Value $script:IssuePage -Encoding UTF8

            ToDoList-RetrieveIssueFiles ([int]($csv.ID)) $script:IssuePage
          }
        }
      }
    }

    if ($is_modified) { $script:modified = $TRUE }

    return $is_modified
  }

  $iLastIssueNo = ToDoList-GetLastIssueNo
  if ($iLastIssueNo -eq 0) {
    Write-Host -ForegroundColor Red "No issues yet"
    return
  }

  $nwc = ToDoList-CreateWebClient


  $iPerBlock = 100
  if ($script:LastMode) {
    # in most cases, changes may happens only in the few first issues
    # thats why, retrieving first 100 Issues is almost enough
    $iBlocks = 1
  } else {
    $iBlocks = [int]($iLastIssueNo / $iPerBlock)
  }

  $script:modified = $FALSE
  $NotCompleted = $FALSE

  $script:Completed = $FALSE

  $sAct = ""

  for ($iBlock=0; -Not $script:Completed ; $iBlock++) {
  #for ($iBlock=0; ($iBlock -lt $iBlocks) -Or ($NotCompleted) ; $iBlock++) {
    $sAct = ("Processing issues "+[String]($iBlock*100+1)+"..."+[String]($iBlock*100+$iPerBlock))
    $sStat = "Downloading issues via CSV"
    if ($iBlock -ge $iBlocks) { $iBlocks = $iBlock+1 }
    $iPercent = ($iBlock * 100 / $iBlocks)
    #Write-Progress -Activity $sAct -CurrentOperation  -percentcomplete $iPercent
    Write-Progress -Activity $sAct -Status $sStat -percentcomplete $iPercent

    $NotCompleted = $FALSE
    if ($LastMode) {
      $http = ($recent_csv_prefix + "&num=" + [String]$iPerBlock + "&start=" + [String]($iBlock*$iPerBlock))
    } else {
      $http = ($csv_prefix + "&num=" + [String]$iPerBlock + "&start=" + [String]($iBlock*$iPerBlock))
    }
    $CsvData = $nwc.DownloadString($http)
    if ($CsvData.Length -ge 100) {
      $sStat = "Processing issues"

      if ($Issues_Save_CSV -ne "") {
        Set-Content ($Issues_Save_CSV+[String]($iBlock*100+1)+"-"+[String]($iBlock*100+$iPerBlock)+".csv") $CsvData
      }

      $CSVRows = ConvertFrom-Csv $CsvData
      if (($CSVRows.Length -ge 1) -And (IsNumeric($CSVRows[0].ID))) {
        Write-Progress -Activity $sAct -Status $sStat -percentcomplete $iPercent

        $NotCompleted = ($CSVRows.Length -eq 101)

        $iRow = 0
        #$CSVRows | foreach { # foreach is not so handy as can be...
        for ($iRow = 0; $iRow -lt $CSVRows.Length; $iRow++) {
          $cs = $CSVRows[$iRow]

          if (IsNumeric($cs.ID)) {
            $sStat = ($cs.ID + " - " + (iif -c ($cs.Summary -eq $null) -a "<empty>" -b $cs.Summary ) )

            #Write-Progress -id 1 -Activity "Processing rows" -status $sInfo -percentcomplete ($iRow * 100 / $CSVRows.Length)
            if ($iBlock -ge $iBlocks) { $iBlocks = $iBlock+1 }
            $iPercent = ((($iBlock * 100) + $iRow) * 100 / ($iBlocks * 100))
            if ($iPercent -le 100) {
              Write-Progress -Activity $sAct -Status $sStat -percentcomplete $iPercent
            }
          }

          $is_modified = ProcessRow $cs

          if ($script:LastMode -and -not $is_modified) {
            break
          }
        }
      }

    }

    if ($LastMode -And -Not $is_modified) {
      $script:Completed = $TRUE
    }
    #elseif ((($iBlock+1) -ge $iBlocks) -And (-Not $NotCompleted)) {
    elseif (-Not $NotCompleted) {
      $script:Completed = $TRUE
    }
  }

  Write-Progress -Activity $sAct -Status $sStat -Completed

  if ($script:modified) {
    ToDoList-SaveXml $x
  } else {
    Write-Host -ForegroundColor Green "Nothing was changed!"
  }

  return
}

function ToDoList-GetLastIssueNo()
{
  $LastNo = 0

  try {
    $nwc = ToDoList-CreateWebClient
    $http = ($last_csv_prefix + "&num=10&start=0")
    $CsvData = $nwc.DownloadString($http)
    if ($CsvData.Length -ge 100) {
      $Csv = ConvertFrom-Csv $CsvData
      if (($Csv.Length -ge 1) -And (IsNumeric($Csv[0].ID))) {
        $LastNo = [int]$Csv[0].ID
      }
    }
  } catch {
    ToDoList-DumpException $error[0]
  }

  return $LastNo
}

function ToDoList-GetTasksAll()
{
  ToDoList-GetTasks -parm1 0 -parm2 id -ShowFixed $TRUE
}

function ToDoList-FindTask([String]$find)
{
  ToDoList-GetTasks -parm1 0 -find $find
}

function ToDoList-FindTaskAll([String]$find)
{
  ToDoList-GetTasks -parm1 0 -find $find -ShowFixed $TRUE
}

function ToDoList-CatTask()
{
  if ($x -eq $null) {
    $x = ToDoList-LoadXml
  }

  $rTask = ToDoList-SelectRoot $x
  if ($rTask -eq $null) {
    return
  }

  $local:tasks = $rTask.SelectNodes("TASK") `
      | where { [int]$_.PERCENTDONE -le 99} `
      | sort {[int]$_.Priority},{[int](ToDoList-GetStars -t $_)},{[double]$_.CreationDate}

  $local:tasks | ft {ToDoList-FormatTaskInfo $_},"TITLE" -AutoSize -HideTableHeader
  Write-Host "[2A[1;32;45mTotal count:[1;37;45m " $local:tasks.Length "`r`n"
}

function ToDoList-OpenTask([String]$id="0",[int]$eid=0)
{
  $http = ""
  if ($eid -ne 0) {
    $http = ($googlecode_issue_href + $eid)
  } else {
    $t = ToDoList-GetTask $id
    if ($t.HasAttribute("FILEREFPATH")) {
      $http = $t.FILEREFPATH
    } elseif ($t.HasAttribute("EXTERNALID")) {
      $http = ($googlecode_issue_href + $t.EXTERNALID)
    }
  }

  if ($http -ne "") {
    & start $http
  }
}
function ToDoList-OpenTaskInt($id)
{
  ToDoList-OpenTask $id
}
function ToDoList-OpenTaskExt([int]$eid)
{
  ToDoList-OpenTask ("e"+$eid)
}

function ToDoList-SelectRoot([xml]$x=$null)
{
  function pad([String]$str,[int]$pad)
  {
    if ($str -ne $null)
    {
      if ($str.Length -gt $pad-1) {
        return ($str.Substring(0,$pad-1)+"�")
      } else {
        return $str.PadRight($pad)
      }
    } else {
      return "".PadRight($pad)
    }
  }

  if ($x -eq $null) {
    $x = ToDoList-LoadXml
  }

  $local:tasks = $x.SelectNodes($xml_path_roots)
  if ($local:tasks.length -eq 0) {
    return $null
  }
  
  $local:names = @()
  $local:tasks | foreach {
    $local:names += pad $_.TITLE 35
  }
  $iCount = $local:names.Length
  $i2 = [int]($iCount/2)

  for ($i = 0; $i -lt $i2; $i++) {
    Write-Host -ForegroundColor Yellow (([String]($i+1)).PadRight(3)) -NoNewline

    if (($i + $i2) -lt $iCount) {
      Write-Host -ForegroundColor Green $local:names[$i] -NoNewline
      Write-Host -ForegroundColor Yellow ("   " + ([String]($i+$i2+1)).PadRight(3)) -NoNewline
      Write-Host -ForegroundColor Green $local:names[$i+$i2]
    } else {
      Write-Host -ForegroundColor Green $local:names[$i]
    }
  }

  Write-Host ("Total root tasks: " + $iCount)
  $n = Read-Host -Prompt "Choose parent task # (Return to cancel)"
  if ((IsNumeric $n) -eq $FALSE) {
    return $null
  }
  $i = ([int]$n) - 1
  if (($i -ge 0) -And ($i -lt $iCount)) {
    # --- $local:tasks[(int)$i] �� �������� PS 2.0
    return $local:tasks.Item([int]$i)
  }

  return $null
}

function ToDoList-ReadNumber([String]$prompt="",$min="",$max="")
{
  $n = (Read-Host -Prompt $prompt)

  #while (($n -ne "") -And -Not (IsNumeric $n)) {
  while ($TRUE) {
    if ($n -eq "") {
      return "" # stop
    }
    if (IsNumeric $n) {
      if ((($min -eq "") -Or (([int]$min) -le ([int]$n))) `
          -And (($max -eq "") -Or (([int]$max) -ge ([int]$n)))) {
        return $n # OK
      }
    }
    
    $n = (Read-Host -Prompt $prompt)
  }

  return "" # fail
}

function ToDoList-ReadMultiLine([String]$prompt="",[String]$append_to="")
{
  if ($prompt -ne "") {
    if ($append_to -eq "") {
      Write-Host -ForegroundColor Gray ($prompt + " (press Enter on new line to end): ")
    } else {
      Write-Host -ForegroundColor Gray ($prompt + " (press Enter on new line to end, type '+' (plus sign) on first line to append): ")
    }
  }
  $all = ""
  $n = Read-Host
  while ($n -ne "") {
    if ($all -eq "") {
      if (($n -eq "+") -And ($append_to -ne "")) {
        $all = $append_to
      } else {
        $all = $n
      }
    } else {
      $all += ("`r`n" + $n)
    }
    $n = Read-Host
  }
  return $all
}

function ToDoList-NewTask([xml]$x=$null)
{
  function ReadHost($Prompt)
  {
    Write-Host -ForegroundColor Gray -NoNewline ($Prompt + ": ")
    Read-Host
  }

  if ($x -eq $null) {
    $x = ToDoList-LoadXml
  }

  $script:new_id = ([int](($x.SelectNodes("TODOLIST//TASK") | Measure "ID" -Maximum).Maximum) + 1)

  $dt = Get-Date
  $dtOA = [String]$dt.ToOADate() # ex "41604.05045139"
  $dtST = ($dt.ToShortDateString()+" "+$dt.ToShortTimeString())

  #Write-Host $new_id
  $tNew = $x.CreateElement("TASK")
  $title = ReadHost -Prompt "Summary (Return to cancel)"
  if ($title -eq "") {
    return
  }
  $tNew.SetAttribute("TITLE",$title)
  $tNew.SetAttribute("ID",  [String]$script:new_id)
  $tNew.SetAttribute("REFID","0")
  $tNew.SetAttribute("COMMENTSTYPE","PLAIN_TEXT")
  $tNew.SetAttribute("ALLOCATEDBY", $DefaultAuthor)
  $tNew.SetAttribute("FILEREFPATH", (ReadHost -Prompt "RefPath"))
  $tNew.SetAttribute("CREATEDBY",   $DefaultAuthor)
  #$tNew.SetAttribute("EXTERNALID",  $csv.ID)
  $tNew.SetAttribute("RISK","0")
  $tNew.SetAttribute("PERCENTDONE","0")
  $priority = ToDoList-ReadNumber "Priority (0..10)" 0 10
  if ($priority -eq "") {
    return
  }
  $tNew.SetAttribute("PRIORITY",$priority)
  #$tNew.SetAttribute("PRIORITYCOLOR","15732480")
  #$tNew.SetAttribute("PRIORITYWEBCOLOR","#000FF0")
  $tNew.SetAttribute("CREATIONDATE",$dtOA)
  $tNew.SetAttribute("CREATIONDATESTRING",$dtST)
  $tNew.SetAttribute("LASTMOD",$dtOA)
  $tNew.SetAttribute("LASTMODSTRING",$dtST)

  $tag = ReadHost -Prompt "Tag (Defect/Other/Wiki/Enhance)"
  if (($tag -eq "Defect") -Or ($tag -eq "d")) {
    ToDoList-SetTaskChild -node "TAG" -new "Defect" -x $x -t $tNew -DoSave $FALSE
  } elseif (($tag -eq "Other") -Or ($tag -eq "o")) {
    ToDoList-SetTaskChild -node "TAG" -new "Other" -x $x -t $tNew -DoSave $FALSE
  } elseif (($tag -eq "Wiki") -Or ($tag -eq "w")) {
    ToDoList-SetTaskChild -node "TAG" -new "Wiki" -x $x -t $tNew -DoSave $FALSE
  } elseif (($tag -eq "Enhance") -Or ($tag -eq "e")) {
    ToDoList-SetTaskChild -node "TAG" -new "Enhance" -x $x -t $tNew -DoSave $FALSE
  }

  $stars = ToDoList-ReadNumber "Stars (1+ or Return)" 1
  if ($stars -ne "") {
    ToDoList-SetStars -new $stars -t $tNew -x $x -DoSave $FALSE
  }

  $cmt = ToDoList-ReadMultiLine "Comment"
  if ($cmt -ne "") {
    ToDoList-SetComment -t $tNew -x $x -new $cmt -DoSave $FALSE
  }

  # Choose parent task
  $tParent = $NULL
  while ($tParent -eq $NULL) {
  $tParent = ToDoList-SelectRoot $x
  }

  # And insert new task in ToDoList
  $tApp = $tParent.AppendChild($tNew)

  ToDoList-PrintUpInfo $tApp.ID "Created" $tApp.TITLE "Task"

  ToDoList-SaveXml $x
}

function ToDoList-EditText([String]$Title,[String]$CurText)
{
  if ($Editor -ne "") {
    $file = [System.IO.Path]::GetTempFileName()
    Set-Content $file $CurText

    # debug!
    #Set-Content ($file+".copy") $CurText
    # debug!

    & cmd /c ($Editor + " " + $file)
    cls
    $newText = ((Get-Content $file) -join "`r`n")
    #Set-Content ($file+".out") $newText
    if ($newText -eq $CurText) {
      $newText = ""
    }
    del $file
  } else {
    $newText = ToDoList-ReadMultiLine $Title $CurText
  }
  return $newText
}

function ToDoList-EditTask([String]$i="0",[xml]$x=$null,[int]$eid=0)
{
  if ($x -eq $null) {
    $x = ToDoList-LoadXml
  }

  $t = ToDoList-GetTask -i $i -x $x -eid $eid
  if ($t -eq $null) {
    Write-Host -ForegroundColor Red "Task not found!"
    return
  }

  $dt = Get-Date
  $dtOA = [String]$dt.ToOADate() # ex "41604.05045139"
  $dtST = ($dt.ToShortDateString()+" "+$dt.ToShortTimeString())

  function title($d,$v)
  {
    if ($v -eq $null) { $v = "" }
    Write-Host -ForegroundColor Gray ($d + " (" + [String]$v + "):")
  }

  $is_modified = $FALSE

  title "Summary" $t.TITLE
  $newval = Read-Host
  if (($newval -ne "") -And ($newval -ne $t.TITLE)) {
    $t.SetAttribute("TITLE",$newval)
    $is_modified = $TRUE
  }
  
  title "RefPath" $t.FILEREFPATH
  $newval = Read-Host
  if (($newval -ne "") -And ($newval -ne $t.TITLE)) {
    $t.SetAttribute("FILEREFPATH",$newval)
    $is_modified = $TRUE
  }

  title "Priority" $t.PRIORITY
  $newval = Read-Host
  if (($newval -ne "") -And ($newval -ne $t.TITLE)) {
    $t.SetAttribute("PRIORITY",$newval)
    $is_modified = $TRUE
  }

  title "Tag [Defect/Other/Wiki/Enhance]" $t.TAG
  $tag = Read-Host
  if ($tag -ne "") {
    if (($tag -eq "Defect") -Or ($tag -eq "d")) {
      ToDoList-SetTaskChild -node "TAG" -new "Defect" -x $x -t $t -DoSave $FALSE
    } elseif (($tag -eq "Other") -Or ($tag -eq "o")) {
      ToDoList-SetTaskChild -node "TAG" -new "Other" -x $x -t $t -DoSave $FALSE
    } elseif (($tag -eq "Wiki") -Or ($tag -eq "w")) {
      ToDoList-SetTaskChild -node "TAG" -new "Wiki" -x $x -t $t -DoSave $FALSE
    } elseif (($tag -eq "Enhance") -Or ($tag -eq "e")) {
      ToDoList-SetTaskChild -node "TAG" -new "Enhance" -x $x -t $t -DoSave $FALSE
    }
    $is_modified = $TRUE
  }

  title "Stars" (ToDoList-GetStars -t $t)
  $stars = Read-Host
  if ($stars -ne "") {
    ToDoList-SetStars -new $stars -t $t -x $x -DoSave $FALSE
    $is_modified = $TRUE
  }

  #ToDoList-ShowComment -t $t
  $s = $t.SelectSingleNode("COMMENTS")
  if ($s -ne $null) { $cmt_cur = $s."#text" } else { $cmt_cur = "" }
  Write-Host -ForegroundColor Gray ("Current comment: "+$cmt_cur)
  #$cmt = ToDoList-ReadMultiLine "Comment" $cmt_cur
  $cmt = ToDoList-EditText "Comment" $cmt_cur
  if ($cmt -ne "") {
    $cmt
    ToDoList-SetComment -t $t -x $x -new $cmt -DoSave $FALSE
    $is_modified = $TRUE
  }

  if ($is_modified) {
    $t.SetAttribute("LASTMOD",$dtOA)
    $t.SetAttribute("LASTMODSTRING",$dtST)

    ToDoList-PrintUpInfo $t.ID "Changed" $t.TITLE "Task"

    ToDoList-SaveXml $x
  }
}

function THint()
{
  Write-Host -ForegroundColor Green -NoNewline "Commands: "
  Write-Host -NoNewline "THint"
  Write-Host -ForegroundColor Gray -NoNewline "; "
  Write-Host -NoNewline "TList "
  Write-Host -ForegroundColor Gray -NoNewline "[MinPriority [ID|CD|STars]]; "
  Write-Host -NoNewline "TListAll"
  Write-Host -ForegroundColor Gray -NoNewline "; "
  Write-Host -NoNewline "TCat"
  Write-Host -ForegroundColor Gray -NoNewline "; <"
  Write-Host -NoNewline "TFind"
  Write-Host -ForegroundColor Gray -NoNewline "|"
  Write-Host -NoNewline "TFindAll"
  Write-Host -ForegroundColor Gray "> text"

  ##
  Write-Host -NoNewline "          "
  Write-Host -ForegroundColor Gray -NoNewline "<"
  Write-Host -NoNewline "Task"
  Write-Host -ForegroundColor Gray -NoNewline "|"
  Write-Host -NoNewline "TC"
  Write-Host -ForegroundColor Gray -NoNewline "|"
  Write-Host -NoNewline "TStars"
  Write-Host -ForegroundColor Gray -NoNewline "|"
  Write-Host -NoNewline "TFix"
  Write-Host -ForegroundColor Gray -NoNewline "|"
  Write-Host -NoNewline "TUnFix"
  Write-Host -ForegroundColor Gray "> TaskID | -eid IssueNo; " -NoNewline
  Write-Host -NoNewline "TStat "
  Write-Host -ForegroundColor Gray "TaskID [Status]"

  ###
  Write-Host -NoNewline "          "
  Write-Host -NoNewline "TNew"
  Write-Host -ForegroundColor Gray -NoNewline "; "
  Write-Host -NoNewline "TEdit "
  Write-Host -ForegroundColor Gray -NoNewline "TaskID | -eid IssueNo; "
  Write-Host -NoNewline "TSet "
  Write-Host -ForegroundColor Gray "TaskID FieldName FieldVal"

  ###
  Write-Host -NoNewline "          "
  Write-Host -NoNewline "TUpdate"
  Write-Host -ForegroundColor Gray -NoNewline " [last]; "
  Write-Host -NoNewline "TOpen "
  Write-Host -ForegroundColor Gray -NoNewline "TaskID; "
  Write-Host -NoNewline "IOpen|i "
  Write-Host -ForegroundColor Gray "IssueNo"

  ###
  Write-Host "`r`n"
}

if ($aliases -eq "yes") {
  Set-Alias i        ToDoList-OpenTaskExt
  Set-Alias xml      ToDoList-LoadXml

  Set-Alias IOpen    ToDoList-OpenTaskExt
  Set-Alias TOpen    ToDoList-OpenTaskInt

  Set-Alias TStars   ToDoList-GetStars
  Set-Alias Task     ToDoList-GetTask
  Set-Alias TNew     ToDoList-NewTask
  Set-Alias TEdit    ToDoList-EditTask
  Set-Alias TFind    ToDoList-FindTask
  Set-Alias TFindAll ToDoList-FindTaskAll
  Set-Alias TCat     ToDoList-CatTask
  Set-Alias TList    ToDoList-GetTasks
  Set-Alias TListAll ToDoList-GetTasksAll
  Set-Alias TFix     ToDoList-TaskFix
  Set-Alias TUnFix   ToDoList-TaskUnFix
  Set-Alias TSet     ToDoList-TaskSet
  Set-Alias TStat    ToDoList-TaskStatus
  Set-Alias TC       ToDoList-ShowComment
  Set-Alias TUpdate  ToDoList-UpdateTasks
}

#Task 1425
#UnFix 1425
#Task 1425


if (($workmode -eq "tasks") -Or ($workmode -eq "list")) {
  THint

  if (($workmode -eq "tasks") -And (($SkipAutoUpdatePC -eq "") -Or ($env:COMPUTERNAME -ne "MAX"))) {
    ToDoList-UpdateTasks "last"
  }

  ToDoList-GetTasks -parm1 $listpriority

} elseif ($workmode -eq "update") {
  # Load new Issues from GC and update Stars count in all tasks
  ToDoList-UpdateTasks $options

} elseif ($workmode -eq "test") {
  #ToDoList-SetStars 1425 10
  #$cmt = ToDoList-GetCommentExt 1129
  #$cmt = ToDoList-GetCommentExt 1058
  #$cmt
  #Set-Content ".\1.tmp" $cmt
  #ToDoList-GetLastIssueNo
  #ToDoList-RetrieveIssueFiles 1365
  #ToDoList-GetCommentExt 1129
  #ToDoList-GetTask 1621
}
