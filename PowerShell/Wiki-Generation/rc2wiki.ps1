$path = split-path -parent $MyInvocation.MyCommand.Definition
# https://github.com/Maximus5/ConEmu/raw/alpha/src/ConEmu/ConEmu.rc
$conemu_rc_file = ($path + "\..\..\ConEmu\src\ConEmu\ConEmu.rc")
# https://github.com/Maximus5/ConEmu/raw/alpha/src/ConEmu/ConEmu.rc2
$conemu_rc2_file = ($path + "\..\..\ConEmu\src\ConEmu\ConEmu.rc2")
# https://github.com/Maximus5/ConEmu/raw/alpha/src/ConEmu/Hotkeys.cpp"
$conemu_hotkeys_file = ($path + "\..\..\ConEmu\src\ConEmu\Hotkeys.cpp")
# https://github.com/Maximus5/ConEmu/raw/alpha/src/ConEmu/Status.cpp
$conemu_status_file = ($path + "\..\..\ConEmu\src\ConEmu\Status.cpp")

$dest = ($path + "\test\")
$dest_wiki = ($path + "\..\ce-test-wiki\wiki\")

#$img_path = "http://conemu-maximus5.googlecode.com/svn/files/"
$wiki_img_path = "http://ce-test-wiki.googlecode.com/svn/files/"
$md_img_path = "http://ce-test-wiki.googlecode.com/svn/files/"

$linedelta = 7


$KeysFriendly = @()
$KeysFriendly += @{ Key = "VK_LWIN" ; Name = "Win" }
$KeysFriendly += @{ Key = "VK_APPS" ; Name = "Apps" }
$KeysFriendly += @{ Key = "VK_CONTROL" ; Name = "Ctrl" }
$KeysFriendly += @{ Key = "VK_LCONTROL" ; Name = "RCtrl" }
$KeysFriendly += @{ Key = "VK_RCONTROL" ; Name = "LCtrl" }
$KeysFriendly += @{ Key = "VK_MENU" ; Name = "Alt" }
$KeysFriendly += @{ Key = "VK_LMENU" ; Name = "RAlt" }
$KeysFriendly += @{ Key = "VK_RMENU" ; Name = "LAlt" }
$KeysFriendly += @{ Key = "VK_SHIFT" ; Name = "Shift" }
$KeysFriendly += @{ Key = "VK_LSHIFT" ; Name = "RShift" }
$KeysFriendly += @{ Key = "VK_RSHIFT" ; Name = "LShift" }
$KeysFriendly += @{ Key = "VK_OEM_3/*~*/" ; Name = "'~'" }
$KeysFriendly += @{ Key = "192/*VK_тильда*/" ; Name = "'~'" }
$KeysFriendly += @{ Key = "VK_UP" ; Name = "UpArrow" }
$KeysFriendly += @{ Key = "VK_DOWN" ; Name = "DownArrow" }
$KeysFriendly += @{ Key = "VK_LEFT" ; Name = "LeftArrow" }
$KeysFriendly += @{ Key = "VK_RIGHT" ; Name = "RightArrow" }
$KeysFriendly += @{ Key = "VK_SPACE" ; Name = "Space" }
$KeysFriendly += @{ Key = "VK_RETURN" ; Name = "Enter" }
$KeysFriendly += @{ Key = "VK_PAUSE" ; Name = "Pause" }
$KeysFriendly += @{ Key = "VK_LBUTTON" ; Name = "LeftMouseButton" }
$KeysFriendly += @{ Key = "VK_RBUTTON" ; Name = "RightMouseButton" }
$KeysFriendly += @{ Key = "VK_MBUTTON" ; Name = "MiddleMouseButton" }
$KeysFriendly += @{ Key = "VK_ESCAPE" ; Name = "Esc" }
$KeysFriendly += @{ Key = "VK_WHEEL_DOWN" ; Name = "WheelDown" }
$KeysFriendly += @{ Key = "VK_WHEEL_UP" ; Name = "WheelUp" }
$KeysFriendly += @{ Key = "VK_INSERT" ; Name = "Ins" }
$KeysFriendly += @{ Key = "VK_TAB" ; Name = "Tab" }
$KeysFriendly += @{ Key = "VK_HOME" ; Name = "Home" }
$KeysFriendly += @{ Key = "VK_END" ; Name = "End" }
$KeysFriendly += @{ Key = "0xbd/* -_ */" ; Name = "'-_'" }
$KeysFriendly += @{ Key = "0xbb/* =+ */" ; Name = "'+='" }
$KeysFriendly += @{ Key = "VK_DELETE" ; Name = "Delete" }
$KeysFriendly += @{ Key = "VK_PRIOR" ; Name = "PageUp" }
$KeysFriendly += @{ Key = "VK_NEXT" ; Name = "PageDown" }
$KeysFriendly += @{ Key = "CEHOTKEY_ARRHOSTKEY" ; Name = "Win(configurable)" }

#$KeysFriendly.Length

function FriendlyKeys($token)
{
  #Write-Host $token
  if (($token -eq "0") -Or ($token -eq "")) { return "" }
  $mk = "MakeHotKey("
  if ($token.StartsWith($mk)) {
    $token = $token.SubString($mk.Length).Trim().TrimEnd(")").Replace(",","|")
  }
  for ($i = 0; $i -lt $KeysFriendly.Length; $i++) {
    $k = $KeysFriendly[$i]["Key"]
    $n = $KeysFriendly[$i]["Name"]
    #Write-Host ($k + " - " + $n)
    $token = $token.Replace($k,$n)
  }
  $token = $token.Replace("VK_","")
  #$token = $token.Replace("VK_LWIN","Win").Replace("VK_CONTROL","Ctrl").Replace("VK_LCONTROL","LCtrl").Replace("VK_RCONTROL","RCtrl")
  #$token = $token.Replace("VK_MENU","Alt").Replace("VK_LMENU","LAlt").Replace("VK_RMENU","RAlt")
  #$token = $token.Replace("VK_SHIFT","Shift").Replace("VK_LSHIFT","LShift").Replace("VK_RSHIFT","RShift")
  #$token = $token.Replace("VK_APPS","Apps").Replace("VK_LSHIFT","LShift").Replace("VK_RSHIFT","RShift")
  $i = $token.IndexOf("|")
  if ($i -gt 0) {
    $token = ($token.SubString($i+1)+"|"+$token.SubString(0,$i))
  }
  return $token
}

function SplitHotkey($line)
{
  $i = 0
  $hk = @{}
  while (($i -lt 8) -And ($line -ne "")) {
    $i++

    if ($i -eq 5) {
      $l = $line.IndexOf("MakeHotKey(")
      if ($l -ge 0) {
        $l = $line.IndexOf("),")
        if ($l -gt 0) { $l++ }
      } else {
        $l = $line.IndexOf(",")
      }
    } elseif ($i -eq 8) {
      $l = $line.Length
    } else {
      $l = $line.IndexOf(",")
    }
    if ($l -eq -1) { $l = $line.Length }

    $token = $line.SubString(0,$l).Trim()
    if ($l -lt $line.Length) { $line = $line.SubString($l+1).Trim() } else { $line = "" }

    if ($i -eq 1) {
      $hk.Add("Id",$token)
    } elseif ($i -eq 2) {
      $hk.Add("Type",$token.SubString(4))
    } elseif ($i -eq 3) {
      if ($token -ne "NULL") { $hk.Add("Disable",$token) }
    } elseif ($i -eq 5) {
      $hk.Add("Hotkey",(FriendlyKeys $token))
    } elseif ($i -eq 8) {
      $sb = "lstrdup(L`""
      $se = "`")"
      $b = $token.IndexOf($sb)
      $e = $token.IndexOf($se,$b+$sb.Length)
      if ($e -gt 0) {
        $hk.Add("Macro",$token.SubString($b+$sb.Length,$e-$b-$sb.Length))
      }
    }
  }

  #if ($hk.ContainsKey("Disable")) { $d = "Possible" } else { $d = "" }
  #if ($hk.ContainsKey("Hotkey")) { $k = $hk["Hotkey"] } else { $k = "" }
  #Write-Host ($hk["Id"].PadRight(25) + "`t" + $d.PadRight(10) + "`t" + $k.PadRight(30) + "`t" + $hk["Macro"])

  return $hk
}

function ParseHotkeys($hkln)
{
  $hk_lines = $hkln `
    | Where { $_.IndexOf("`t`t{vk") -eq 0 } `
    | Where { $_.IndexOf("vkGuiMacro") -eq -1 } `
    | Where { $_.IndexOf("vkConsole_") -eq -1 } # NEED TO BE ADDED MANUALLY !!!

  $hotkeys = @()

  $hk_lines | foreach-object {
    $l = $_.LastIndexOf("}")
    if ($l -gt 0) {
      $line = $_.SubString(0,$l).Trim([char]9).Trim('{')
      $hk = SplitHotkey $line
      $hotkeys += $hk
    }
  }

  return $hotkeys
}

function FindLine($l, $rcln, $cmp)
{
  #Write-Host "'"+$l+"'"
  #Write-Host "'"+$cmp+"'"
  #Write-Host "'"+$rcln+"'"
  $n = $cmp.length
  #Write-Host "'"+$n+"'"
  while ($l -lt $rcln.length) {
    if ($rcln[$l].length -ge $n) {
      $left = $rcln[$l].SubString(0,$n)
      if (($left -eq $cmp)) {
        break
      }
    }
    $l++
  }
  if ($l -ge $rcln.length) {
    Write-Host -ForegroundColor Red ("Was not found: С" + $cmp + "Т")
    return -1
  }
  return $l
}

function ParseLine($ln)
{
  $type = $ln.SubString(0,15).Trim()
  $title = ""
  $id = ""
  $x = -1; $y = -1; $width = -1; $height = -1

  # RTEXT|LTEXT|CTEXT   "Size:",IDC_STATIC,145,15,20,8
  # GROUPBOX     "Quake style",IDC_STATIC,4,201,319,29
  # CONTROL      "Close,after,paste ""C:\\"" /dir",cbHistoryDontClose,"Button",BS_AUTOCHECKBOX | WS_TABSTOP,7,190,153,8
  # CONTROL      "Show && store current window size and position",cbUseCurrentSizePos, "Button",BS_AUTOCHECKBOX | WS_TABSTOP,11,13,258,8
  # CONTROL      "",IDC_ATTACHLIST,"SysListView32",LVS_REPORT | LVS_SHOWSELALWAYS | LVS_ALIGNLEFT | WS_BORDER | WS_TABSTOP,4,4,310,159
  # PUSHBUTTON   "Add default tasks...",cbAddDefaults,9,179,93,14
  # EDITTEXT     tCmdGroupName,109,12,81,12,ES_AUTOHSCROLL
  # COMBOBOX     lbExtendFontBoldIdx,65,9,26,30,CBS_DROPDOWNLIST | CBS_SORT | WS_VSCROLL | WS_TABSTOP
  # LISTBOX      lbHistoryList,7,16,311,116,LBS_NOINTEGRALHEIGHT | WS_VSCROLL | WS_TABSTOP

  $left = $ln.SubString(16).Trim()
  if ($left.SubString(0,3) -eq "`"`",") {
    $left = $left.SubString(2).Trim()
  } elseif ($left.SubString(0,1) -eq "`"") {
    # "Quake,style",IDC_STATIC...
    # "Show && store",cbUseCurrentSizePos...
    # "Close,after,paste ""C:\\"" /dir",cbHistoryDontClose...
    $i = $left.IndexOf("`"",1)
    while ($i -gt 0) {
      $i2 = $left.IndexOf("`"",$i+1)
      if ($i2 -eq ($i+1)) {
        $i = $left.IndexOf("`"",$i2+1)
      } else {
        break
      }
    }
    if ($i -le 1) {
      Write-Host -ForegroundColor Red ("Invalid string, bad token: "+$ln)
      return
    }
    $title = $left.SubString(1,$i-1).TrimEnd(':').Replace("&&",[String][char]1).Replace("&","").Replace([String][char]1,"&").Replace("\\","\").Replace("`"`"","`"")
    $left = $left.SubString($i).Trim()
    #Write-Host $left
  }

  $arr = $left.Split(",")

  # RTEXT|LTEXT|CTEXT   "Size:",IDC_STATIC,145,15,20,8
  # GROUPBOX     "Quake style",IDC_STATIC,4,201,319,29
  # PUSHBUTTON   "Add default tasks...",cbAddDefaults,9,179,93,14
  if (($type -eq "RTEXT") -Or ($type -eq "LTEXT") -Or ($type -eq "CTEXT") -Or ($type -eq "GROUPBOX") -Or ($type -eq "PUSHBUTTON")) {
    #Write-Host $type + $text + $arr
    $id = $arr[1]; $i = 2
    $x = [int]($arr[$i]); $y = [int]($arr[$i+1]); $width = [int]($arr[$i+2]); $height = [int]($arr[$i+3])
  }
  # CONTROL      "Close,after,paste ""C:\\"" /dir",cbHistoryDontClose,"Button",BS_AUTOCHECKBOX | WS_TABSTOP,7,190,153,8
  # CONTROL      "Show && store current window size and position",cbUseCurrentSizePos, "Button",BS_AUTOCHECKBOX | WS_TABSTOP,11,13,258,8
  # CONTROL      "",IDC_ATTACHLIST,"SysListView32",LVS_REPORT | LVS_SHOWSELALWAYS | LVS_ALIGNLEFT | WS_BORDER | WS_TABSTOP,4,4,310,159
  elseif ($type -eq "CONTROL") {
    #Write-Host $type + $text + $arr
    $id = $arr[1]; $i = 4
    $x = [int]($arr[$i]); $y = [int]($arr[$i+1]); $width = [int]($arr[$i+2]); $height = [int]($arr[$i+3])
    #if ($id -eq "cbCmdTaskbarCommands") { Write-Host ("CONTROL: "+$id+" - '"+$arr[2]+"' - "+$arr[3]) }
    $class = ($arr[2]).Trim().Trim('"')
    if ($class -eq "SysListView32") {
      $type = "LVS_REPORT"
    }
    elseif ($class -eq "msctls_trackbar32") {
      $type = "TRACKBAR"
    }
    elseif ($class -eq "Button") {
      #if ($id -eq "cbCmdTaskbarCommands") { Write-Host ("Button: "+$id+" - "+$arr[3]) }
      if ((($arr[3]).Contains("CHECKBOX")) -Or (($arr[3]).Contains("AUTO3STATE"))) {
        $type = "CHECKBOX"
      } elseif (($arr[3]).IndexOf("RADIO") -gt 0) {
        $type = "RADIOBUTTON"
      }
    }
    #if ($id -eq "cbCmdTaskbarCommands") { Write-Host ("Type->" + $type) }
  }
  # EDITTEXT     tCmdGroupName,109,12,81,12,ES_AUTOHSCROLL
  # COMBOBOX     lbExtendFontBoldIdx,65,9,26,30,CBS_DROPDOWNLIST | CBS_SORT | WS_VSCROLL | WS_TABSTOP
  # LISTBOX      lbHistoryList,7,16,311,116,LBS_NOINTEGRALHEIGHT | WS_VSCROLL | WS_TABSTOP
  else {
    if ($type -eq "EDITTEXT") { $type = "EDIT" }
    elseif (($type -eq "COMBOBOX") -And ($arr.Length -gt 5)) {
      if ($arr[5].Contains("CBS_DROPDOWNLIST")) { $type = "DROPDOWNBOX" }
    }
    # Write-Host $type + $text + $arr
    $id = $arr[0]; $i = 1
    $x = [int]($arr[$i]); $y = [int]($arr[$i+1]); $width = [int]($arr[$i+2]); $height = [int]($arr[$i+3])
  }

  $y2 = $y
  if ($type -ne "GROUPBOX") {
    $y2 = ($y + [int]($height / 2))
  }

  #if ($id -eq "IDC_STATIC") {
  #  $id = ""
  #}

  return @{Type=$type;Title=$title;Id=$id;X=$x;Y=$y;Width=$width;Height=$height;Y2=$y2}
}

function WriteWiki($items_arg, $hints, $hotkeys, $dlgid, $name, $flname)
{
  $script:items = $items_arg

  $file_wiki = ($dest_wiki + $flname[0].Replace("-","") + ".wiki")
  $file_md = ($dest + $flname[0].Replace("-","") + ".md")
  $file_table = ($path + "\tables\" + $flname[0].Replace("-","") + ".wiki")

  $wiki_automsg = "#summary This page was generated automatically from ConEmu sources`r`n"
  $md_automsg = "`r`n`r`n*This page was generated automatically from ConEmu sources*`r`n`r`n"

  # <img src="http://conemu-maximus5.googlecode.com/svn/files/ConEmuAnsi.png" title="ANSI X3.64 and Xterm 256 colors in ConEmu">

  $script:wiki = ($wiki_automsg + "<wiki:comment> $dlgid </wiki:comment>`r`n")
  $script:md = $md_automsg
  $script:table = $md_automsg

  $script:wiki += ("=Settings: " + $name + "=`r`n")
  $script:md += ("# Settings: " + $name + "`r`n")
  $script:table += ("=Settings: " + $name + "=`r`n")

  # Screenshots
  for ($i = 0; $i -lt $flname.Length; $i++) {
    $img = ("<img src=`"" + $wiki_img_path + $flname[$i] + ".png`" title=`"ConEmu Settings: " + $name + "`">`r`n`r`n")
    $script:wiki += $img
    $script:table += $img
    $img = ("<img src=`"" + $md_img_path + $flname[$i] + ".png`" title=`"ConEmu Settings: " + $name + "`">`r`n`r`n")
    $script:md += $img
  }

  $script:table += "|| CtrlType || Text || ID || Position || Desription ||`r`n"

  $script:ctrl_type = ""
  $script:ctrl_name = ""
  $script:ctrl_alt = ""
  $script:ctrl_desc = ""
  $script:list = @()
  $script:descs = @()
  $script:radio = $FALSE
  $script:track = $FALSE
  $script:dirty = $FALSE
  $script:wasgroup = $FALSE

  function EscWiki($txt)
  {
    return $txt.Replace("<","``<``").Replace(">","``>``").Replace("*","``*``")
  }
  function EscMd($txt)
  {
    return $txt
  }
  function ReplaceRN($txt)
  {
    return $txt.Replace("\n"," ").Replace("`r`n"," ").Replace("`r"," ").Replace("`n"," ")
  }

  function DumpWiki()
  {
    if ($script:dirty) {
      $label = ""
      $alt = ""
      $desc = ""

      $add_wiki = ""
      $add_md   = ""

      if ($script:radio) {

        if ($script:ctrl_alt -ne "") {
          $add_wiki += ("*" + (EscWiki $script:ctrl_alt) + "*`r`n")   # Bold
          $add_md   += ("**" + (EscMd $script:ctrl_alt) + "**`r`n`r`n") # Bold
        }
        for ($i = 0; $i -lt $script:list.Length; $i++) {
          $add_wiki += ("  * *" + (EscWiki $script:list[$i]) + "*")   # Bold
          $add_md   += ("  * **" + (EscMd $script:list[$i]) + "**") # Bold
          if ($script:descs[$i] -ne "") {
            $add_wiki += (" " + (EscWiki $script:descs[$i]))
            $add_md   += (" " + (EscMd $script:descs[$i]))
          }
          $add_wiki += "`r`n"
          $add_md   += "`r`n"
        }

      } else {

        $desc = $script:ctrl_desc

        if (($script:ctrl_type.Contains("TEXT")) -And ($desc -eq ""))  {
          $desc = $script:ctrl_type
        }
        elseif ($script:ctrl_name -ne "") {
          $label = ReplaceRN $script:ctrl_name
          if ($script:ctrl_alt -ne "") { $alt = ReplaceRN $script:ctrl_alt }
        }
        elseif ($script:ctrl_alt -ne "") {
          $label = ReplaceRN $script:ctrl_alt
        }
        else {
          if ($script:ctrl_type -eq "EDIT") {
            $script:ctrl_name = "Edit box"
          }
        }

        if ($label -ne "") {
          if ($script:wasgroup) {
            StartGroup $label
          } else {
            $add_wiki += ("*" + (EscWiki $label) + "* ")   # Bold
            $add_md   += ("**" + (EscMd $label) + "** ") # Bold
          }
        }

        if ($alt -ne "") {
          $add_wiki += ("_(" + (EscWiki $alt) + ")_ ") # Italic
          $add_md   += ("*(" + (EscMd $alt) + ")* ") # Italic
        }

        if (($desc -ne "") -And ($desc -ne $label) -And ($desc -ne $alt)) {
          $add_wiki += (EscWiki $desc)
          $add_md   += (EscMd $desc)
        }

      }

      if ($add_wiki -ne "") {
        #Write-Host -ForegroundColor Gray $add_wiki
        $script:wiki += $add_wiki
      }
      if ($add_md -ne "") {
        # Write-Host -ForegroundColor Gray $add_md
        $add_md += $add_md
      }
    }

    $script:wiki += "`r`n`r`n"
    $script:md   += "`r`n`r`n"

    $script:ctrl_type = ""
    $script:ctrl_name = ""
    $script:ctrl_alt = ""
    $script:ctrl_desc = ""
    $script:list = @()
    $script:descs = @()
    $script:radio = $FALSE
    $script:track = $FALSE
    $script:dirty = $FALSE
    $script:wasgroup = $FALSE
  }

  function StartGroup($grptxt)
  {
    if ($grptxt -eq "") { $grptxt = "Group" }
    ### googlecode wiki
    $script:wiki += ("==" + (EscWiki $grptxt) + "==`r`n`r`n")
    #$script:ctrl_alt = ""
    ### github md
    $script:md += ("## "+ (EscMd $grptxt) + "`r`n`r`n")
    # clean
    $script:wasgroup = $FALSE
  }

  function GetHint($item)
  {
    $hint = ""
    if (($item.Id -ne "") -And ($hints.ContainsKey($item.Id))) {
      $hint = ReplaceRN $hints[$item.Id]
    }
    return $hint
  }

  $script:wasgroup = $FALSE

  function AddTable()
  {
    # For debugging (information separate wiki file)
    $script:table += ("|| " + $script:items[$i].Type + " || " + $script:items[$i].Title + " || " + `
      $script:items[$i].Id + " || (" + $script:items[$i].Y2 + ":" + [int]($script:items[$i].Y2/$linedelta) + ") " + `
      $script:items[$i].x+","+$script:items[$i].y+","+$script:items[$i].Width+","+$script:items[$i].Height + `
      " || " + (GetHint $script:items[$i]) + `
      " ||`r`n")
  }

  function ParseGroupbox($sgTitle,$iFrom,$xFrom,$xTo,$yTo)
  {
    #Write-Host ("  GroupBox: " + $sgTitle + " iFrom=" + $iFrom + " x={" + $xFrom + ".." + $xTo + "} yTo=" + $yTo)
    $iDbg = 0

    for ($i = $iFrom; $i -lt $script:items.length; $i++) {

      if (($script:items[$i].x -lt $xFrom) -Or (($script:items[$i].x + $script:items[$i].Width) -gt $xTo) -Or (($script:items[$i].y + $script:items[$i].Height) -gt $yTo)) {
        continue # outside of processed GroupBox
      }

      #Write-Host ("    Item: " + $script:items[$i].Id + " " + $script:items[$i].Type + " " + $script:items[$i].Title)

      if ($script:items[$i].Type -eq "GROUPBOX") {
        # If any is pending...
        DumpWiki
        # Process current group
        $script:wasgroup = ($script:items[$i].Title.Trim() -eq "")
        if ($script:wasgroup) {
          # That is last element???
          if (($i+1) -ge $script:items.length) { $script:wasgroup = $FALSE }
          # If next element is BELOW group Y
          elseif (($script:items[$i].y) -lt ($script:items[$i+1].y)) { $script:wasgroup = $FALSE }
        }
        # Start new heading
        if (-Not $script:wasgroup) {
          StartGroup $script:items[$i].Title
        }

        # For debugging (information separate wiki file)
        AddTable

        $script:items[$i].Id = ""

        ParseGroupbox $script:items[$i].Title ($i+1) $script:items[$i].x ($script:items[$i].x + $script:items[$i].Width) ($script:items[$i].y + $script:items[$i].Height)

        continue
      }

      if ($script:items[$i].Id -eq "") {
        continue # already processed
      }

      if (($script:ctrl_type.Contains("TEXT")) -And ($script:items[$i].Type.Contains("TEXT"))) {
        DumpWiki
      } elseif (($script:radio) -And (-Not $script:items[$i].Type.Contains("RADIO"))) {
        DumpWiki
      }

      # For debugging (information separate wiki file)
      AddTable

      if ($script:items[$i].Type.Contains("TEXT")) {
        $txt = $script:items[$i].Title.Trim()
        if (($txt -eq "") -Or ($txt.CompareTo("x") -eq 0)) {
          continue
        }
        $hint = (GetHint $script:items[$i])
        if ($hint -ne "") {
          Write-Host -ForegroundColor Red ("Hint skipped: " + $hint)
        }
        DumpWiki
        # Static text
        $script:dirty = $TRUE
        $script:ctrl_type = $script:items[$i].Type
        $script:ctrl_alt = $script:items[$i].Title
      }
      elseif ($script:items[$i].Type -eq "RADIOBUTTON") {
        if ((-Not $script:ctrl_type.Contains("TEXT")) -And ($script:ctrl_type -ne "RADIOBUTTON")) {
          DumpWiki
        }
        # Radio buttons
        $script:dirty = $TRUE
        $script:radio = $TRUE
        $script:ctrl_type = $script:items[$i].Type
        $script:list += $script:items[$i].Title
        $script:descs += (GetHint $script:items[$i])
      }
      elseif ($script:items[$i].Type -eq "CHECKBOX") {
        if (($script:dirty) -And (-Not $script:ctrl_type.Contains("TEXT"))) {
          DumpWiki
        }
        # Check box
        $script:dirty = $TRUE
        $script:ctrl_type = $script:items[$i].Type
        $script:ctrl_name = $script:items[$i].Title
        $script:ctrl_desc = (GetHint $script:items[$i])
      }
      elseif ($script:items[$i].Type.Contains("BOX")) {
        if (-Not $script:ctrl_type.Contains("TEXT")) {
          DumpWiki
        }
        # Combo or list box
        $script:dirty = $TRUE
        $script:ctrl_type = $script:items[$i].Type
        $script:ctrl_name = $script:items[$i].Title
        $script:ctrl_desc = (GetHint $script:items[$i])
        if ($script:items[$i].Type -eq "DROPDOWNBOX") {
          # TODO : ListBox items (retrieve from sources) ?
        }
      }
      elseif ($script:items[$i].Type -eq "TRACKBAR") {
        if (-Not $script:ctrl_type.Contains("TEXT")) {
          DumpWiki
        }
        # Trackbar (may be followed by text)
        # Transparent .. Opaque
        # Darkening: ... [255]
        $script:dirty = $TRUE
        $script:ctrl_type = $script:items[$i].Type
        $script:track = $TRUE
        $script:ctrl_desc = (GetHint $script:items[$i])
      }
      elseif ($script:items[$i].Type -eq "EDIT") {
        if (($script:dirty) -And (-Not $script:ctrl_type.Contains("TEXT"))) {
          DumpWiki
        }
        $script:dirty = $TRUE
        $script:ctrl_type = $script:items[$i].Type
        #if ($script:ctrl_name -eq "") { $script:ctrl_name = "Edit box" }
        $script:ctrl_desc = (GetHint $script:items[$i])
      }
      elseif ($script:items[$i].Type.Contains("BUTTON")) {
        DumpWiki
        if ($script:items[$i].Title.Trim().Trim('.').Length -ge 1) {
          $script:dirty = $TRUE
          $script:ctrl_type = $script:items[$i].Type
          $script:ctrl_name = $script:items[$i].Title
          $script:ctrl_desc = (GetHint $script:items[$i])
        }
      }
      else {
        if (-Not $script:ctrl_type.Contains("TEXT")) {
          DumpWiki
        }
        $hint = (GetHint $script:items[$i])
        if ($hint -ne "") {
          $script:dirty = $TRUE
          $script:ctrl_type = $script:items[$i].Type
          $script:ctrl_desc = $hint
        }
      }

      $script:items[$i].Id = ""
    }

    DumpWiki
  }

  ParseGroupbox "" 0 0 9999 9999

  if ($dlgid -eq "IDD_SPG_KEYS") {
    ### googlecode wiki && github md
    $apps = "_Apps_ key is a key between RWin and RCtrl."
    $script:wiki += ("`r`n`r`n==Hotkeys list==`r`n" + "*Note* "+$apps+"`r`n`r`n|| *Hotkey* || *GuiMacro* || *Description* ||`r`n")
    $script:md   += ("`r`n`r`n## Hotkeys list`r`n"  + "*Note* "+$apps+"`r`n`r`nHotkey | GuiMacro | Description`r`n")
    $script:md += ":---|:---|:---`r`n"
    #Write-Host $hotkeys
    for ($i = 0; $i -lt $hotkeys.Length; $i++) {
      $hk = $hotkeys[$i]
      if ($hk.ContainsKey("Disable")) { $d = " (may be disabled)" } else { $d = "" }
      if ($hk["Hotkey"] -ne "") { $k = ("``"+$hk["Hotkey"].Replace("|","+")+"``") } else { $k = "_No default_" }
      if (($hk.ContainsKey("Macro")) -And ($hk["Macro"] -ne "")) { $g = ("``"+$hk["Macro"]+"``") } else { $g = "" }
      $h = ""
      if ($hints.ContainsKey($hk["Id"])) {
        $h = ReplaceRN $hints[$hk["Id"]]
      }
      #Write-Host ($hk["Id"].PadRight(25) + "`t" + $d.PadRight(20) + "`t" + $k.PadRight(30) + "`t" + $hk["Macro"])
      $script:wiki += ("|| " + $k + " || " + $g + " || " + (EscWiki $h) + $d + " ||`r`n")
      $script:md += ($k + " | " + $hk["Macro"] + " | " + (EscMd $h) + $d + "`r`n")
    }
  }

  Set-Content -Path $file_table -Value $script:table -Encoding UTF8
  # googlecode wiki
  Set-Content -Path $file_wiki -Value $script:wiki -Encoding UTF8
  # github md
  Set-Content -Path $file_md -Value $script:md -Encoding UTF8
}

function ParseDialog($rcln, $hints, $hotkeys, $dlgid, $name, $flname)
{
  $l = FindLine 0 $rcln ($dlgid + " ")
  if ($l -le 0) { return }

  $b = FindLine $l $rcln "BEGIN"
  if ($b -le 0) { return }
  $e = FindLine $b $rcln "END"
  if ($e -le 0) { return }

  $supported = "|GROUPBOX|CONTROL|RTEXT|LTEXT|CTEXT|PUSHBUTTON|EDITTEXT|COMBOBOX|LISTBOX|"

  $ln = ""
  $items_arg = @()

  Write-Host -ForegroundColor Green ("Dialog: " + $name)
  for ($l = ($b+1); $l -lt $e; $l++) {
    if ($rcln[$l].Length -le 22) {
      continue
    }
    if ($rcln[$l].SubString(0,8) -eq "        ") {
      if ($ln -ne "") {
        $ln += " " + $rcln[$l].Trim()
      }
    } else {
      if ($ln -ne "") {
        $h = ParseLine $ln
        $items_arg += $h
      }
      $ln = ""
      $ctrl = $rcln[$l].SubString(0,20).Trim()
      if ($supported.Contains("|"+$ctrl+"|")) {
        $ln = $rcln[$l].Trim()
      } else {
        Write-Host -ForegroundColor Red ("Unsupported control type: "+$ctrl)
      }
    }
  }
  if ($ln -ne "") {
    $h = ParseLine $ln
    $items_arg += $h
  }

  Write-Host ("  Controls: " + $items_arg.Count)

  WriteWiki ($items_arg | sort {((1000*[int]($_.Y2/$linedelta))+[int]$_.X)}) $hints $hotkeys $dlgid $name $flname.Split(",")
}

function ParseHints($rc2ln)
{
  $l = FindLine 0 $rc2ln "STRINGTABLE"
  if ($l -le 0) { return }
  $b = FindLine $l $rc2ln "BEGIN"
  if ($b -le 0) { return }
  $e = FindLine $b $rc2ln "END"
  if ($e -le 0) { return }

  $hints = @{}

  for ($l = ($b+1); $l -lt $e; $l++) {
    $ln = $rc2ln[$l].Trim()
    $s = $ln.IndexOf(" ")
    if ($s -gt 1) {
      $name = $ln.SubString(0, $s)
      $text = $ln.SubString($s).Trim()
      $text = $text.SubString(1,$text.Length-2)

      $s = $text.IndexOf("\")
      while ($s -ge 0) {
        $v = $text.SubString($s,2)
        if ($v -eq "\r") { $r = "`r" }
        elseif ($v -eq "\n") { $r = "`n" }
        elseif ($v -eq "\t") { $r = "`t" }
        elseif ($v -eq "\\") { $r = "\" }
        else { $r = $e }

        $text = $text.Remove($s,2).Insert($s,$r)
        $s = $text.IndexOf("\",$s+$r.length)
      }

      if ($text -ne "") {
        $hints.Add($name,$text.Replace("`"`"","`""))
      }
    }
  }

  return $hints
}

$page_id = @()
$page_nm = @()
$page_fl = @()

$page_id += "IDD_SPG_MAIN";        $page_nm += "Main";          $page_fl += "Settings-Main"
$page_id += "IDD_SPG_WNDSIZEPOS";  $page_nm += " Size & Pos";   $page_fl += "Settings-SizePos"
$page_id += "IDD_SPG_SHOW";        $page_nm += " Appearance";   $page_fl += "Settings-Appearance"
$page_id += "IDD_SPG_TASKBAR";     $page_nm += " Task bar";     $page_fl += "Settings-TaskBar"
$page_id += "IDD_SPG_UPDATE";      $page_nm += " Update";       $page_fl += "Settings-Update"
$page_id += "IDD_SPG_STARTUP";     $page_nm += "Startup";       $page_fl += "Settings-Startup"
$page_id += "IDD_SPG_CMDTASKS";    $page_nm += " Tasks";        $page_fl += "Settings-Tasks"
$page_id += "IDD_SPG_COMSPEC";     $page_nm += " ComSpec";      $page_fl += "Settings-Comspec"
$page_id += "IDD_SPG_FEATURE";     $page_nm += "Features";      $page_fl += "Settings-Features"
$page_id += "IDD_SPG_CURSOR";      $page_nm += " Text cursor";  $page_fl += "Settings-TextCursor"
$page_id += "IDD_SPG_COLORS";      $page_nm += " Colors";       $page_fl += "Settings-Colors,Settings-Colors2"
$page_id += "IDD_SPG_TRANSPARENT"; $page_nm += " Transparency"; $page_fl += "Settings-Transparency"
$page_id += "IDD_SPG_TABS";        $page_nm += " Tabs";         $page_fl += "Settings-TabBar"
$page_id += "IDD_SPG_STATUSBAR";   $page_nm += " Status bar";   $page_fl += "Settings-StatusBar"
$page_id += "IDD_SPG_APPDISTINCT"; $page_nm += " App distinct"; $page_fl += "Settings-AppDistinct,Settings-AppDistinct2"
$page_id += "IDD_SPG_INTEGRATION"; $page_nm += "Integration";   $page_fl += "Settings-Integration"
$page_id += "IDD_SPG_DEFTERM";     $page_nm += " Default term"; $page_fl += "Settings-DefTerm"
$page_id += "IDD_SPG_KEYS";        $page_nm += "Keys & Macro";  $page_fl += "Settings-Hotkeys"
$page_id += "IDD_SPG_CONTROL";     $page_nm += " Controls";     $page_fl += "Settings-Controls"
$page_id += "IDD_SPG_MARKCOPY";    $page_nm += " Mark/Copy";    $page_fl += "Settings-MarkCopy"
$page_id += "IDD_SPG_PASTE";       $page_nm += " Paste";        $page_fl += "Settings-Paste"
$page_id += "IDD_SPG_HIGHLIGHT";   $page_nm += " Highlight";    $page_fl += "Settings-Highlight"
$page_id += "IDD_SPG_FEATURE_FAR"; $page_nm += "Far Manager";   $page_fl += "Settings-Far"
$page_id += "IDD_SPG_FARMACRO";    $page_nm += " Far macros";   $page_fl += "Settings-Far-Macros"
$page_id += "IDD_SPG_VIEWS";       $page_nm += " Views";        $page_fl += "Settings-Far-View"
$page_id += "IDD_SPG_INFO";        $page_nm += "Info";          $page_fl += "Settings-Info"
$page_id += "IDD_SPG_DEBUG";       $page_nm += " Debug";        $page_fl += "Settings-Debug"


# Query source files
Write-Host -NoNewLine ("Reading: " + $conemu_rc_file)
$rcln  = Get-Content $conemu_rc_file
Write-Host (" Lines: " + $rcln.Length)
Write-Host -NoNewLine ("Reading: " + $conemu_rc2_file)
$rc2ln = Get-Content $conemu_rc2_file
Write-Host (" Lines: " + $rc2ln.Length)
Write-Host -NoNewLine ("Reading: " + $conemu_hotkeys_file)
$hkln  = Get-Content $conemu_hotkeys_file
Write-Host (" Lines: " + $hkln.Length)

# Preparse hints and hotkeys
$hints   = ParseHints   $rc2ln
$hotkeys = ParseHotkeys $hkln
#$hints

$toc_wiki = ""

# Parse sources and write wiki/md pages
for ($p = 0; $p -lt $page_id.length; $p++) {
  ParseDialog $rcln $hints $hotkeys $page_id[$p] $page_nm[$p].Trim() $page_fl[$p]

  if ($page_nm[$p].StartsWith(" ")) { $toc_wiki += "  " }
  $toc_wiki += ("  * [" + $page_fl[$p].Split(",")[0].Replace("-","") + " " + $page_nm[$p].Trim() + "]`r`n")
}

Set-Content -Path ($dest_wiki + "TableOfContents.wiki") -Value $toc_wiki -Encoding UTF8
