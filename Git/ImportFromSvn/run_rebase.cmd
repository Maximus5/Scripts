pause
goto :EOF

git rebase --onto history-old f97ba90 history


rem not sure about, looks line this command was used to import
rem ONLY ConEmu-related commits from local git-svn repository
git remote add hist ../../ConEmu-svn-git
git fetch hist
git checkout -b br/pre-git hist/131105-preview
git subtree split --prefix=trunk/ConEmu-preview --annotate="[svn-preview] " --rejoin -b st/131105-preview


rem and this for older ones
git checkout -b br/130708-alpha hist/130708-alpha
git subtree split --prefix=trunk/ConEmu --annotate="[svn] " --rejoin -b st/130708-alpha
