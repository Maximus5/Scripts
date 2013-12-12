## Purpose
Recently, found nice and handy [ToDoList](http://portableapps.com/apps/office/todolist_portable)
manager tool. But importing (and maintaining) issues from GoogleCode is hard...

### This script allows

  * Importing all issues from your GoogleCode project in your xml ToDoList
  * Downloading your issues to HTML files on your drive
  * Downloading issue attachments to your drive
  * Updating issues "Stars" count in your xml ToDoList
  * Displaying actual (not fixed) issues with priority larger or equal to 8
  * Displaying issues sorted by priority, id, stars or change date
  * Fixing and UnFixing issues (in your xml) from PowerShell prompt
  * Creating new tasks and editing existing

## Usage

How to use this script in ConEmu?

Create new Task in ConEmu settings with

    Command
      powershell -NoProfile -NoExit -Command "Import-Module {FullPath}\List.ps1 -ArgumentList 'Tasks'"
    Task parameters
      /dir {FullPath}

Replace **{FullPath}** with your path, for example **C:\Source\ConEmu**
Script will show not fixed tasks with priority larger or equal to 8

In the powershell prompt you can use commands **Fix** and **UnFix**. Both takes one argument - numeric **ID** from your ToDoList xml file (this is first column of **Tasks**). Also, you may call them with google issue no, just pass it with **-eid** prefix.

    Fix 1234
    UnFix -eid 555

Also, you may run script nightly to retrieve new Issues from GoogleCode and update your ToDo xml file

    powershell -NoProfile -Command "Import-Module {FullPath}\List.ps1 -ArgumentList update"

Use powershell prompt and type commands, **hint** command will show brief list of functions with arguments
