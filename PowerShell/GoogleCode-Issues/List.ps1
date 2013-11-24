param([String]$workmode="tasks",[String]$aliases="yes",[int]$listpriority=8)

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
$Script_Working_path = (Get-Location).Path
$Script_xml_ToDo_path = ($Script_Working_path+"\ConEmu-ToDo.xml")
$Script_xml_Save_path = ($Script_Working_path+"\ConEmu-ToDo.xml")
$Issues_Save_CSV = ($Script_Working_path+"\html_list\Issues-")
$Issues_Save_HTML = ($Script_Working_path+"\html\")
# Some hrefs
$googlecode_issue_href = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/detail?id=")
$http_prefix = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/detail?id=")
$list_prefix = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/list?can=1&q=&colspec=ID%20Stars%20Type%20Status%20Modified%20Reporter%20Summary&sort=id%20-modified")
$csv_prefix  = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/csv?can=1&q=&colspec=ID%20Stars%20Type%20Status%20Modified%20Reporter%20Summary&sort=id%20-modified")
$last_csv_prefix  = ("http://code.google.com/p/" + $GoogleCodeProjectName + "/issues/csv?can=1&q=&colspec=ID%20Stars%20Type%20Status%20Modified%20Reporter%20Summary&sort=-id%20-modified&num=10&start=")
# This task will get new GC issues, just create a task
# named "Imported" in your ToDo list before usage
$xml_path_imported = "/TODOLIST//TASK[@TITLE='Imported']"
# Crash reports will be placed here
$xml_path_crashs = "/TODOLIST/TASK[starts-with(@TITLE,'Crashes')]"
# Subtask "Fixed", if not found - fixed tasks
# will be placed in the "Imported" task
$xml_path_importedFixed = "TASK[@TITLE='Fixed']"

# Search these words in the issue text -> Put them in the $xml_path_crashs task
$CrashWords = @("crash","hung","краш","крэш")
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
  $x.Save($Script_xml_Save_path)
}

# You may get task by "ID" ($i param)
# or by "EXTERNALID" ($eid param) which is GC issue now
function ToDoList-GetTask([int]$i=0,[xml]$x=$null,[int]$eid=0)
{
  if ($x -eq $null) {
    $x = ToDoList-LoadXml
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

function ToDoList-GetTaskChild([int]$i=0,[String]$node="TAG",[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[int]$eid=0)
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

function ToDoList-SetTaskChild([int]$i=0,[String]$node="TAG",[String]$new="",[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0)
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

function ToDoList-GetStars([int]$i=0,[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  $s = $t.SelectSingleNode("CUSTOMATTRIB[@ID='CUST_STARS']")

  if ($s -eq $null) {
    0
  } elseif ($s.HasAttribute("VALUE")) {
    $s.VALUE
  } else {
    0
  }
}

function ToDoList-SetStars([int]$i=0,[String]$new,[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0)
{
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
      $script:modified = $TRUE
    } elseif ($s.GetAttribute("VALUE") -ne $new) {
      $v = $s.SetAttribute("VALUE",$new)
      $script:modified = $TRUE
    }
    if ($DoSave) {
      ToDoList-SaveXml $x
    } else {
      return
    }
  } catch {
    ToDoList-DumpException $error[0]
  }
}

function ToDoList-SetTaskAttr([int]$id=0,[String]$attr="",[String]$new="",[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $id -x $x -eid $eid
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
  $s += pad -str (ToDoList-GetTaskChild -t $t -node "TAG") -pad 10
  $s += pad -str $t.ALLOCATEDBY -pad 12
  #if ($t.ALLOCATEDBY -ne $null) { $s += $t.ALLOCATEDBY.Substring(0,11).PadRight(12) } else { $s += "".PadRight(12) }
  return $s
}

function ToDoList-GetTasks([xml]$x=$null,[int]$priority=8)
{
  Write-Host -ForegroundColor Green "Please wait, loading, filtering, sorting..."
  if ($x -eq $null) {
    $x = ToDoList-LoadXml
  }
  #$x.SelectNodes("TODOLIST//TASK") | where { [int]$_.Priority -ge 8} | where { [int]$_.PERCENTDONE -le 99} | sort {[int]$_.Priority} | ft "ID","EXTERNALID","PRIORITY",{Stars -t $_},"ALLOCATEDBY","TITLE" -AutoSize -HideTableHeader
  #$x.SelectNodes("TODOLIST//TASK") | where { [int]$_.Priority -ge 8} | where { [int]$_.PERCENTDONE -le 99} | sort {[int]$_.Priority},{[double]$_.CreationDate} | ft "ID","EXTERNALID","PRIORITY",{Stars -t $_},"ALLOCATEDBY","TITLE" -AutoSize -HideTableHeader
  $x.SelectNodes("TODOLIST//TASK") | where { [int]$_.Priority -ge $priority} | where { [int]$_.PERCENTDONE -le 99} | sort {[int]$_.Priority},{[int](ToDoList-GetStars -t $_)},{[double]$_.CreationDate} | ft {ToDoList-FormatTaskInfo $_},"TITLE" -AutoSize -HideTableHeader
}

function ToDoList-TaskFix([int]$i,[xml]$x=$null,[int]$eid=0)
{
  try {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
    $t.PERCENTDONE = "100"
    ToDoList-SaveXml $x
    ToDoList-GetTasks -x $x
  }
  catch {
    ToDoList-DumpException $error[0]
    Write-Host -ForegroundColor Red ("Fix "+$i+" failed!")
  }
}

function ToDoList-TaskUnFix([int]$i,[xml]$x=$null,[int]$eid=0)
{
  try {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
    $t.PERCENTDONE = "0"
    ToDoList-SaveXml $x
    ToDoList-GetTasks -x $x
  }
  catch {
    ToDoList-DumpException $error[0]
    Write-Host -ForegroundColor Red ("Fix "+$i+" failed!")
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

function ToDoList-GetComment([int]$i=0,[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[int]$eid=0)
{
  if ($t -eq $null) {
    if ($x -eq $null) {
      $x = ToDoList-LoadXml
    }
    $t = ToDoList-GetTask -i $i -x $x -eid $eid
  }

  if (($t -ne $null) -And (IsNumeric($t.EXTERNALID))) {
    $s = $t.SelectSingleNode("COMMENTS")
  }

  if ((($s -eq $null) -Or ($s -eq "")) -And ($eid -gt 0)) {
    $s = ToDoList-GetCommentExt -eid $eid
  }

  if (($s -eq $null) -Or ($s -eq "")) {
    Write-Host -ForegroundColor Red "There is no comments yet"
    return ""
  } else {
    return $s."#text"
  }
}


function ToDoList-SetComment([int]$i=0,[String]$new,[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0)
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
    # <COMMENTS>Версия ОС: Win7 Rel x86</COMMENTS>
    if ($s -eq $null) {
      $s = $x.CreateElement("COMMENTS")
      $s.InnerText = $new
      $v = $t.AppendChild($s)
      $script:modified = $TRUE
    } elseif ($s."#text" -ne $new) {
      $s."#text" = $new
      $script:modified = $TRUE
    }
    if ($DoSave) {
      ToDoList-SaveXml $x
    } else {
      return
    }
  } catch {
    ToDoList-DumpException $error[0]
  }
}


function ToDoList-UpdateComment([int]$i=0,[xml]$x=$null,[System.Xml.XmlElement]$t=$null,[Boolean]$DoSave=$TRUE,[int]$eid=0)
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

function ToDoList-UpdateTasks
{
  Write-Host -ForegroundColor Green "Please wait, updating your todo list..."

  # Load xml file (existing task list)
  $x = ToDoList-LoadXml

  # Find parent tasks
  $imp_root = $x.SelectSingleNode($xml_path_imported)
  $fix_root = $imp_root.SelectSingleNode($xml_path_importedFixed)
  $crash_root = $x.SelectSingleNode($xml_path_crashs)
  if ($imp_root -eq $null) {
    $imp_root = $x.SelectSingleNode("/TODOLIST/TASK")
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
    $task.SetAttribute("PERCENTDONE",$sPercent)

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
    if (IsNumeric($csv.ID))
    {
      $script:IssuePage = ""

      #"ProcessRow called"
      $x_path = ("TODOLIST//TASK[@EXTERNALID='" + $csv.ID + "']")
      $tt = $x.SelectSingleNode($x_path)

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
        $tNew.SetAttribute("PERCENTDONE",$sPercent)
        $tNew.SetAttribute("PRIORITY","5")
        #$tNew.SetAttribute("PRIORITYCOLOR","15732480")
        #$tNew.SetAttribute("PRIORITYWEBCOLOR","#000FF0")
        $dt = (Get-Date $csv.Modified)
        $tNew.SetAttribute("CREATIONDATE",$dt.ToOADate())
        $tNew.SetAttribute("CREATIONDATESTRING",($dt.ToShortDateString()+" "+$dt.ToShortTimeString()))

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

        $script:modified = $TRUE
        #$csv
        #$tApp
        #$tNew

      # or existing one? Update stars and "Fixed" state
      } elseif (IsNumeric($csv.Stars)) {
        #Write-Host ("Updating stars for "+$csv.ID+" to "+$csv.Stars+" : "+$tt.Title)
        ToDoList-SetStars -new $csv.Stars -t $tt -x $x -DoSave $FALSE
        #"Stars updated"
      }

      # Asked to store Issues in html files?
      if ($Issues_Save_HTML -ne "") {
        $WriteIssue = $FALSE
        $file = ($Issues_Save_HTML+"Issue"+$csv.ID+".htm")
        if (-Not (Test-Path $file)) {
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

    #powershell bug? Can't change value of the parent scope variable?
    return #$script:new_id
  }

  $iLastIssueNo = ToDoList-GetLastIssueNo
  if ($iLastIssueNo -eq 0) {
    Write-Host -ForegroundColor Red "No issues yet"
    return
  }

  $nwc = ToDoList-CreateWebClient


  $iPerBlock = 100
  $iBlocks = [int]($iLastIssueNo / $iPerBlock)

  $script:modified = $FALSE
  $NotCompleted = $FALSE

  for ($iBlock=0; (($iBlock -lt $iBlocks) -Or ($NotCompleted)) ; $iBlock++) {
    $sAct = ("Processing issues "+[String]($iBlock*100+1)+"..."+[String]($iBlock*100+$iPerBlock))
    $sStat = "Downloading issues via CSV"
    if ($iBlock -ge $iBlocks) { $iBlocks = $iBlock+1 }
    $iPercent = ($iBlock * 100 / $iBlocks)
    #Write-Progress -Activity $sAct -CurrentOperation  -percentcomplete $iPercent
    Write-Progress -Activity $sAct -Status $sStat -percentcomplete $iPercent

    $NotCompleted = $FALSE
    $http = ($csv_prefix + "&num=" + [String]$iPerBlock + "&start=" + [String]($iBlock*$iPerBlock))
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
        $CSVRows | foreach {
          if (IsNumeric($_.ID)) {
            $sStat = ($_.ID + " - " + (iif -c ($_.Summary -eq $null) -a "<empty>" -b $_.Summary ) )

            #Write-Progress -id 1 -Activity "Processing rows" -status $sInfo -percentcomplete ($iRow * 100 / $CSVRows.Length)
            if ($iBlock -ge $iBlocks) { $iBlocks = $iBlock+1 }
            $iPercent = ((($iBlock * 100) + $iRow) * 100 / ($iBlocks * 100))
            if ($iPercent -le 100) {
              Write-Progress -Activity $sAct -Status $sStat -percentcomplete $iPercent
            }
          }

          #$new_id = ProcessRow $_
          ProcessRow $_
          #$script:new_id
          #$new_id
          $iRow++
        }
      }
    }
  }

  if ($script:modified) {
    Write-Host -ForegroundColor Green "Saving changes..."
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
    $http = ($last_csv_prefix + "0")
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


if ($aliases -eq "yes") {
  Set-Alias Stars ToDoList-GetStars
  Set-Alias Task  ToDoList-GetTask
  Set-Alias Tasks ToDoList-GetTasks
  Set-Alias Fix   ToDoList-TaskFix
  Set-Alias UnFix ToDoList-TaskUnFix
  Set-Alias cmt   ToDoList-GetComment
  Set-Alias xml   ToDoList-LoadXml
}

#Task 1425
#UnFix 1425
#Task 1425

if ($workmode -eq "tasks") {
  ToDoList-GetTasks -priority $listpriority

} elseif ($workmode -eq "update") {
  # Load new Issues from GC and update Stars count in all tasks
  ToDoList-UpdateTasks

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
