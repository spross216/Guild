# The guard test corpus (docs/guard.md section 8). Dot-sourced by Guard.Tests.ps1 at discovery and run time.
#
# GuardBlockCases     Commands that must block under the Bash tool, the PowerShell tool and with no tool name.
#                     A string is the command; a hashtable adds Skip (a tool whose grammar parses the text
#                     as one harmless command, so only the other deliveries are asserted).
# GuardBlockWithAllow Commands that must block even with the -Allow argument given.
# GuardBlockOneTool   Commands that must block under one tool only (the other tool's grammar allows them).
# GuardAllowCases     Commands that must allow under the tool named: Bash, PowerShell, Both (Bash and
#                     PowerShell) or None (no tool name). Allow adds the -Allow argument.
# Most cases come from the repository's earlier guard tests and the two independent QA suites; sections
# below add the verdicts of docs/guard.md 8.1 to 8.3 and the secret-printing reads.

$script:GuardBlockCases = @(
    # From the earlier repository tests and the independent QA suites
    'git commit -m x'
    'git push'
    'git branch feature'
    'git tag v1.0'
    'git -C ../repo checkout main'
    'Remove-Item -Recurse src'
    'Get-Content a.txt | Set-Content b.txt'
    'echo hi > notes.txt'
    'rm -rf build'
    'sed -i s/a/b/ file.txt'
    'curl https://example.com'
    'pwsh -c "Remove-Item x"'
    'bash -c "ls"'
    'gh pr merge 42'
    'gh api repos/o/r/issues -f title=x'
    'az group delete --name rg'
    'aws s3 rm s3://bucket/key'
    'kubectl apply -f deploy.yaml'
    'find . -name "*.tmp" -delete'
    'npm install'
    'Invoke-Expression $code'
    'some-unknown-tool --flag'
    'cat README.md & some-tool -x'
    'cat README.md &some-tool x'
    'cat README.md & touch marker.txt'
    '"rm" -f a.txt'
    '''rm'' -f a.txt'
    '"touch" marker.txt'
    'cat x | "tee" out'
    '"$cmd" -f a'
    '"cat" README.md'
    '$SHELL -c ''x'''
    '$(echo rm) -f a.txt'
    'cat README.md | $SHELL'
    'cat README.md && $X -f a'
    '$HOME/bin/tool x'
    @{ Command = 'echo `touch marker.txt`'; Skip = 'PowerShell' }
    @{ Command = 'echo `rm -f a.txt`'; Skip = 'PowerShell' }
    'echo "`some-tool x`"'
    'echo $(cat README.md; some-tool x)'
    'echo "$(some-tool x)"'
    'Write-Output "$([IO.File]::Delete(''a''))"'
    '$f = [System.IO.File]; $f::Delete(''a.txt'')'
    '$t = ''System.IO.File'' -as [type]; $t::Delete(''a.txt'')'
    '$t = ''System.IO.File'' -as [type]; $t::WriteAllText(''a.txt'', ''x'')'
    '$t = [type]''System.IO.File''; $t::Delete(''a'')'
    '$t = [System.Type]::GetType(''System.IO.File'')'
    '([type]''System.IO.File'')::Delete(''a'')'
    '$m = [IO.File].GetMethod(''Delete'')'
    'Invoke-ScriptAnalyzer -Path src -Fix'
    'Invoke-ScriptAnalyzer -Path src -Fix:$true'
    '$c = New-PesterConfiguration; $c.TestResult.Enabled = $true; Invoke-Pester -Configuration $c'
    '$c = New-PesterConfiguration; $c.CodeCoverage.Enabled = $true; Invoke-Pester -Configuration $c'
    'Invoke-Pester -CI'
    'Invoke-Pester -OutputFile r.xml -OutputFormat NUnitXml'
    'Get-ChildItem | ForEach-Object -MemberName Delete'
    'Get-ChildItem | ForEach-Object Delete'
    '$env:GUILD_HOME = ''x'''
    '$env:PSModulePath += ''x'''
    'if ($true) { $env:PATH = ''x'' }'
    'az vm deallocate -g rg -n get-api'
    'az storage blob upload --name list -f x -c y --account-name z'
    'kubectl set image deploy/get-api app=img'
    'kubectl -n web scale deploy get-api --replicas=0'
    'aws ec2 stop-instances --instance-ids show-1'
    'aws s3api put-object --bucket list-b --key get'
    'gcloud compute instances resize get-api'
    'gh issue comment 1 -b view'
    'gh pr merge list'
    'gcloud compute instances describe web'
    'sort -o out.txt in.txt'
    'sort --output=out.txt in.txt'
    'sort -ro out.txt in.txt'
    'uniq in.txt out.txt'
    'tree -o out.txt'
    'find . -fls out.txt'
    'find . -fprint0 out.txt'
    'find . -fprintf out.txt x'
    'find . -name x -okdir echo {} \;'
    'file -C -m foo'
    'git diff --output=out.txt'
    'git remote set-url origin https://example.invalid/x'
    'git remote remove origin'
    'git remote prune origin'
    'git hash-object -w log.txt'
    'git update-index --add show.txt'
    'git -c core.fsmonitor=x status'
    'git grep -O x'
    'rg --pre some-tool x README.md'
    'rg --pre=some-tool x README.md'
    'less -o out.txt README.md'
    '& ''Remove-Item'' x'
    'rg -n "Remove-Item" guards; Remove-Item x'
    'rg -n "$(Remove-Item x)" guards'
    'rg -n "`Remove-Item x`" guards'
    @{ Command = 'echo "Remove-Item"'; Skip = 'PowerShell' }
    'rg x | & ''Remove-Item'''
    'cat a/b|Remove-Item x'
    'cat a/b;Remove-Item x'
    'Get-Content src/a.ps1 | Set-Content src/b.ps1'
    'git -C ../repo commit -m x'
    'Get-Content x.txt, Remove-Item y'
    'Get-Content x.txt && Remove-Item y'
    '& ./x.ps1'
    './x.ps1'
    '.\scripts\Invoke-Build.ps1'
    'pwsh -File x.ps1'
    'pwsh -NoProfile -File scripts/Invoke-Build.ps1'
    '& "Remove-Item" x'
    '& (''Remove''+''-Item'') x'
    '$c = ''x''; & $c'
    '. ./x.ps1'
    'Get-ChildItem | ForEach-Object { ./x.ps1 }'
    'Get-ChildItem | ForEach-Object { & ./x.ps1 $_ }'
    'Get-ChildItem | ForEach-Object { . ./x.ps1 }'
    'Get-Content (./x.ps1)'
    'Write-Output $(./x.ps1)'
    '$x = ./x.ps1'
    '$x += ./x.ps1'
    'Remove-Item x'
    'Set-Content a.txt hi'
    'Out-File a.txt'
    'Get-Date | Out-File a.txt'
    'Get-Date | Tee-Object -FilePath a.txt'
    'Get-Date > a.txt'
    'Get-Date >> a.txt'
    'pwsh -Command "Get-Date"'
    'pwsh -NoProfile -Command "Get-Date"'
    'pwsh -EncodedCommand abc'
    'powershell.exe -c Get-Date'
    'iex $code'
    'Get-Content x | iex'
    'Start-Process notepad'
    'git push; Get-Date'
    'ForEach-Object { Remove-Item $_ }'
    'Get-ChildItem | ForEach-Object { Remove-Item $_.FullName }'
    'Get-ChildItem | ForEach-Object { rm $_ }'
    'Get-ChildItem | ForEach-Object { sc $_ x }'
    'Get-ChildItem | ForEach-Object { move $_ x }'
    'Get-ChildItem | ForEach-Object { kill $_ }'
    'Get-ChildItem | ForEach-Object { some-tool $_ }'
    '[IO.File]::WriteAllText("a.txt", "x")'
    '[System.IO.File]::Delete("a.txt")'
    '[System.IO.File]::AppendAllText("a.txt", "x")'
    '[IO.Directory]::Delete("d", $true)'
    '[IO.Directory]::CreateDirectory("d")'
    '[IO.StreamWriter]::new("a.txt")'
    '[System.Diagnostics.Process]::Start("notepad")'
    '[Environment]::SetEnvironmentVariable("A", "b")'
    '[scriptblock]::Create("Get-Date").Invoke()'
    '(Get-Item a.txt).Delete()'
    '(Get-Item a.txt).MoveTo("b.txt")'
    '$ExecutionContext.InvokeCommand.InvokeScript($x)'
    '(New-Object Net.WebClient).DownloadFile($u, "a")'
    '$x = Remove-Item a; $x'
    'Get-ChildItem; Set-Location x; Remove-Item y'
    'git push origin main'
    'git add -A'
    'git checkout -b x'
    'git stash'
    'git -C ../repo reset --hard'
    'git --git-dir=.git push'
    'gh pr review 1 --approve'
    'gh run rerun 123'
    'gh api -X POST repos/o/r/issues'
    'az vm start -g rg -n web'
    'az group delete -n rg'
    'aws ec2 terminate-instances --instance-ids i-get1'
    'aws s3 cp ./report.csv s3://bucket/list.csv'
    'kubectl delete pod web-get-1'
    'curl -o out.bin https://example.invalid/x'
    'wget https://example.invalid/x'
    'cat a.txt >> b.txt'
    'cat x &>out.txt'
    'cat x >| out'
    'tee out.txt'
    'sed -i s/a/b/ f'
    'export FOO=bar'
    'FOO=bar some-cmd'
    'pwsh -c "Get-Date"'
    'cmd /c del x'
    'eval "rm x"'
    'cat x | sh'
    'cat x | xargs rm'
    'for f in a; do rm $f; done'
    'find . -name x -exec rm {} \;'
    'cat <(rm x)'
    'echo $(rm -f x)'
    'cat README.md & python3 -c "print(1)"'
    'cat README.md &python3 x'
    '$SHELL -c ''rm x'''
    'rg --pre bash x README.md'
    'rg --pre=sh x README.md'
    'Get-ChildItem | ForEach-Object { ''x'' | Set-Content $_ }'
    'switch (1) { ''a'' { Remove-Item x } }'
    'try { Get-Date } catch { Remove-Item x }'
    'if ($true) { Get-Date } else { Remove-Item x }'
    'Get-Date | ForEach-Object -Process { Remove-Item $_ }'
    '& git push'
    'Get-Content x | & (''Remove'' + ''-Item'')'
    '$c = ''Remove-Item''; .$c x'
    '[IO.File]::WriteAllText(''a'',''b'')'
    '[System.IO.File]::OpenWrite(''a'')'
    '[System.Diagnostics.Process]::Start(''notepad'')'
    'Invoke-WebRequest https://example.invalid'
    'Invoke-RestMethod https://example.invalid'
    'Set-Variable -Name x -Value 1'
    'Get-GuildRepoSurvey -Path . -AsJson | Set-Content x'
    'Install-GuildAgents -Harness claude'
    'Uninstall-GuildAgents -Harness claude'
    'Add-GuildFinding -Title x'
    'New-GuildStandardsRepo -Path x'
    'Get-Content README.md > out.txt'
    'Get-Date *> out.txt'
    '$env:GUILD_HOME = ''C:/x'''
    '$env:PSModulePath = ''C:/x'''
    'gh pr merge 42 --squash'
    'iwr https://example.invalid/x -OutFile x.txt'
    'Invoke-WebRequest -Uri https://example.invalid/x -OutFile x.txt'
    @{ Command = 'echo \"; python3 -c print; echo \"'; Skip = 'PowerShell' }
    @{ Command = 'echo it\''s; python3 -c x; echo \'''; Skip = 'PowerShell' }
    'echo "it''s $(python3 -c x)"'
    'echo "don''t `python3 x`"'
    'echo "it''s $([IO.File]::Delete(''a.txt''))"'
    '"rm".exe -f a.txt'
    '''rm''.exe a.txt'
    '"rm" -eq a.txt'
    '$SHELL.exe -c "touch x"'
    '$SHELL -eq 1 -c "touch x"'
    '(Get-Item README.md).("Delete")()'
    '(Get-Item README.md).("Dele"+"te")()'
    '(Get-Item README.md).PSObject.Methods[''Delete''].Invoke()'
    'Get-Item README.md | ForEach-Object { $_.("Dele"+"te")() }'
    '$f = Get-Item README.md; $f.IsReadOnly = $true'
    '$f = Get-Item README.md; $f.LastWriteTime = Get-Date'
    'Invoke-ScriptAnalyzer -Path guards/Test-GuildReadOnlyCommand.ps1 -Fi'
    'Invoke-Pester ./tests -OutputFi x.xml'
    '$c = New-PesterConfiguration; $c.(''Test''+''Result'').Enabled = $true; Invoke-Pester -Configuration $c'
    'sort --out=sorted.txt in.txt'
    'file --compi -m foo'
    'git --namespace status push origin main'
    'kubectl --as get delete pod web-1'
    'for f in a; do python3 -c x; done'
    'while true; do node x.js; done'
    'if false; then :; else python3 -c x; fi'
    'cat README.md & python3 -c x'
    @{ Command = 'echo `python3 x`'; Skip = 'PowerShell' }
    'Invoke-ScriptAnalyzer -Path guards/Test-GuildReadOnlyCommand.ps1 -Fix'
    # docs/guard.md 8.1 and 8.3, the design's own cases, and secret-printing reads
    'wc -l $(git ls-files)'
    'Remove-Item x'
    'Set-Content a.txt hi'
    'rm -rf build'
    'touch marker.txt'
    'npm install'
    'Set-Variable -Name x -Value 1'
    'Start-Process notepad'
    'some-unknown-tool --flag'
    'python3 -c x'
    'node x.js'
    'Install-GuildAgents -Harness claude'
    'Uninstall-GuildAgents -Harness claude'
    'Add-GuildFinding -Title x'
    'New-GuildStandardsRepo -Path x'
    'New-GuildDecision -Title x'
    'curl https://example.invalid/x'
    'wget https://example.invalid/x'
    'Invoke-WebRequest https://example.invalid'
    'iwr https://example.invalid/x -OutFile x.txt'
    'Invoke-RestMethod https://example.invalid'
    '(New-Object Net.WebClient).DownloadFile($u, "a")'
    'git commit -m x'
    'git push origin main'
    'git add -A'
    'git checkout -b x'
    'git stash'
    'git -C ../repo reset --hard'
    'git branch feature'
    'git tag v1.0'
    'git remote set-url origin https://example.invalid/x'
    'git remote remove origin'
    'git remote prune origin'
    'git hash-object -w log.txt'
    'git update-index --add show.txt'
    'git reflog expire'
    'git config user.name x'
    'git fetch'
    'git pull'
    'git worktree add x'
    'git -c core.fsmonitor=x status'
    'git --git-dir=.git push'
    'git --namespace status push origin main'
    'git diff --output=out.txt'
    'git diff --out=x'
    'git grep -O x'
    'git log --ext-diff'
    'git --paginate log'
    'git help status'
    'git status --help'
    'gh pr merge 42'
    'gh pr review 1 --approve'
    'gh run rerun 123'
    'gh api -X POST repos/o/r/issues'
    'gh issue comment 1 -b view'
    'gh pr view 1 --web'
    'gh pr view 1 -w'
    'gh api repos/o/r'
    'az vm start -g rg -n web'
    'az vm deallocate -g rg -n get-api'
    'az group delete -n rg'
    'az storage blob upload --name list -f x -c y --account-name z'
    'az vm delete list -g rg'
    'aws ec2 stop-instances --instance-ids i-1'
    'aws ec2 terminate-instances --instance-ids i-get1'
    'aws s3 cp ./report.csv s3://bucket/list.csv'
    'aws s3 rm s3://bucket/key'
    'aws s3api put-object --bucket b --key k'
    'aws s3api get-object --bucket b --key k out.bin'
    'kubectl delete pod web-get-1'
    'kubectl apply -f deploy.yaml'
    'kubectl set image deploy/get-api app=img'
    'kubectl -n web scale deploy get-api --replicas=0'
    'kubectl --as get delete pod web-1'
    'kubectl exec web-0 -- ls'
    'kubectl get pods --raw /api'
    'gcloud compute instances resize get-api'
    'gcloud compute instances delete web'
    'echo hi > notes.txt'
    'cat a.txt >> b.txt'
    'cat x &>out.txt'
    'cat x >| out'
    'Get-Date > a.txt'
    'Get-Date >> a.txt'
    'Get-Date *> out.txt'
    'Get-Date | Out-File a.txt'
    'Get-Date | Tee-Object -FilePath a.txt'
    'tee out.txt'
    'cat x 2> out.txt'
    'cat x 2>/tmp/err'
    'cat < README.md'
    'cat README.md & some-tool -x'
    'cat README.md &some-tool x'
    'cat README.md & touch marker.txt'
    'cat a/b;Remove-Item x'
    'bash -c "ls"'
    'pwsh -c "Get-Date"'
    'pwsh -EncodedCommand abc'
    'pwsh -File x.ps1'
    'powershell.exe -c Get-Date'
    'cmd /c del x'
    'eval "rm x"'
    'cat x | sh'
    'cat x | xargs rm'
    'Invoke-Expression $code'
    'iex $code'
    'Get-Content x | iex'
    'for f in a; do rm $f; done'
    'while true; do node x.js; done'
    'if false; then :; else python3 -c x; fi'
    'echo $(rm -f x)'
    'echo "$(some-tool x)"'
    'echo "it''s $(python3 -c x)"'
    'rg "$(python3 -c x)" guards'
    'rg -n "$(Remove-Item x)" guards'
    'echo $(echo $(echo $(echo $(echo $(python3 x)))))'
    'cat <(rm x)'
    '"rm".exe -f a.txt'
    '''rm''.exe a.txt'
    '"rm" -eq a.txt'
    '"rm" -f a.txt'
    '''rm'' -f a.txt'
    '"touch" marker.txt'
    'cat x | "tee" out'
    '$SHELL -c ''x'''
    '$SHELL.exe -c "touch x"'
    '$SHELL -eq 1 -c "touch x"'
    'cat README.md | $SHELL'
    'cat README.md && $X -f a'
    '$HOME/bin/tool x'
    '"$cmd" -f a'
    '$c = ''x''; & $c'
    '$c = ''Remove-Item''; .$c x'
    '& (''Remove''+''-Item'') x'
    'export FOO=bar'
    'FOO=bar some-cmd'
    '$env:GUILD_HOME = ''x'''
    '$env:PSModulePath += ''x'''
    'if ($true) { $env:PATH = ''x'' }'
    'sort --out=sorted.txt in.txt'
    'file --compi -m foo'
    'sed -i s/a/b/ file.txt'
    'sed -n ''1w out'' f'
    'sed s/a/b/ f'
    'less README.md'
    'find . -delete'
    'find . -exec rm {} \;'
    'find . -fprintf out x'
    './x.ps1'
    '.\scripts\Invoke-Build.ps1'
    '& ./x.ps1'
    '. ./x.ps1'
    'ForEach-Object { ./x.ps1 }'
    'ForEach-Object { & ./x.ps1 $_ }'
    'ForEach-Object { . ./x.ps1 }'
    'Get-Content (./x.ps1)'
    'Write-Output $(./x.ps1)'
    '$x = ./x.ps1'
    '$x += ./x.ps1'
    '$f = Get-Item README.md; $f.IsReadOnly = $true'
    '$f = Get-Item README.md; $f.LastWriteTime = Get-Date'
    'Get-Content a.txt | Set-Content b.txt'
    'Get-Content x.txt, Remove-Item y'
    'Get-Content x.txt && Remove-Item y'
    'cat a/b|Remove-Item x'
    'git -C ../repo commit -m x'
    'rg -n "Remove-Item" guards; Remove-Item x'
    'rg x | & ''Remove-Item'''
    '& ''Remove-Item'' x'
    '& "Remove-Item" x'
    'try { Get-Date } catch { Get-Date }'
    'while ($true) { Get-Date }'
    'do { Get-Date } while ($false)'
    'function f { Get-Date }'
    'Get-Date &'
    'Get-ChildItem | ForEach-Object -Parallel { 1 }'
    'switch -File x { default { 1 } }'
    '$x = [type]''System.IO.File'''
    'Get-ChildItem @args'
    '$a, $b = 1, 2'
    '[int]$x = 1'
    '$h = @{}; $h[''k''] = 1'
    '$global:x = 1'
    '$script:x = 1'
    '$PSDefaultParameterValues = @{}'
    '$ErrorView = ''x'''
    '${c:\x} = 1'
    '$function:x = 1'
    'return 1'
    'throw ''x'''
    'exit'
    'Get-Content -- x'
    'Get-Content --% foo'
    '#requires -Version 7'
    'param($a) $a'
    'begin { Get-Date }'
    'using namespace System.IO'
    'class A { }'
    '$x = 1; $x = $x.PSObject'
    'Get-ChildItem | ForEach-Object { $_.PSObject.Methods }'
    '$x = ''a'' -replace ''a'', { ''b'' }'
    '[Environment]::SetEnvironmentVariable(''A'', ''b'')'
    '$x = [IO.File]::OpenRead(''a'')'
    'Get-Content -Path:(Remove-Item x)'
    'Get-Help Get-Content -Online'
    'Import-Module ./x.psd1 -ArgumentList 1'
    'Get-ChildItem | ForEach-Object -MemberName Delete'
    'Test-GuildInstall -Model @{ a = 1 }'
    'Invoke-Pester -Configuration @{ Run = @{ Path = ''x'' } }'
    'if ($true) { $c = New-PesterConfiguration; $c.Run.Path = ''x'' }'
    '$c = New-PesterConfiguration; $c.Run.Exit = $true'
    '$c = New-PesterConfiguration; $c.Debug.WriteDebugMessages = $true'
    '$c = New-PesterConfiguration -Hashtable @{ TestResult = @{ Enabled = $true } }'
    'Invoke-ScriptAnalyzer -Path x -CustomRulePath y'
    'Get-Content -Path x -ErrorAction Stop -OutVariable v'
    'Get-Content x -ev v'
    'Get-Content x -Wait'
    'az keyvault secret show --vault-name v --name n'
    'az keyvault secret download --vault-name v --name n --file f'
    'az keyvault secret backup --vault-name v --name n --file f'
    'az storage account keys list -g rg -n acct'
    'az storage account show-connection-string -g rg -n acct'
    'az webapp config appsettings list -g rg -n app'
    'az functionapp config appsettings list -g rg -n app'
    'az webapp deployment list-publishing-credentials -g rg -n app'
    'az cosmosdb keys list -g rg -n acct'
    'az acr credential show -n reg'
    'az webapp config connection-string list -g rg -n app'
    'aws secretsmanager get-secret-value --secret-id s'
    'aws secretsmanager batch-get-secret-value --secret-id-list s'
    'aws ssm get-parameter --name n --with-decryption'
    'aws ssm get-parameters --names n --with-decryption'
    'aws ssm get-parameters-by-path --path / --with-decryption'
    'aws ssm get-parameter --name n --with-d'
    'aws configure get aws_secret_access_key'
    'aws ec2 get-password-data --instance-id i'
    'aws sts get-session-token'
    'aws ecr get-login-password'
    'gcloud secrets versions access latest --secret s'
    'kubectl get secret db -o yaml'
    'kubectl get secrets -o json'
    'kubectl get secret db -ojson'
    'kubectl get secret db -o jsonpath={.data}'
    'kubectl get secret db --output=yaml'
    'kubectl get -o yaml secret/db'
    'kubectl get secret,pods -o yaml'
    'kubectl describe secret db'
    'kubectl describe secrets'
    'kubectl -n web get secret db -o go-template={{.data}}'
    # Review round: secrets, outfiles, sort.exe, Pester variable tracking, and the rest
    'sort.exe /O out.txt README.md'
    'sort.exe README.md'
    'uniq.exe in out'
    'cat.exe README.md'
    'sort /O out.txt README.md'
    'sort /REC 5 README.md'
    'uniq /X a'
    '$c = New-PesterConfiguration; if ($true) { $c = $h }; Invoke-Pester -Configuration $c'
    '$c = New-PesterConfiguration; foreach ($c in 1..2) { $c }; Invoke-Pester -Configuration $c'
    '$c = New-PesterConfiguration; $null = ($c = $h); Invoke-Pester -Configuration $c'
    '$c = New-PesterConfiguration; $c++; Invoke-Pester -Configuration $c'
    '$c = New-PesterConfiguration; 1 | ForEach-Object { $c = $h }; Invoke-Pester -Configuration $c'
    '$c = New-PesterConfiguration; $c.Run.Path = ''./tests''; if ($true) { $c = $h }; Invoke-Pester -Configuration $c'
    '$c = New-PesterConfiguration; $c = $h; Invoke-Pester -Configuration $c'
    '$c = New-PesterConfiguration; $c += $h; Invoke-Pester -Configuration $c'
    'az containerapp secret list --show-values'
    'az containerapp secret list -g rg -n app --show-values'
    'az containerapp secret show -g rg -n app --secret-name s'
    'az eventgrid topic key list -g rg -n t'
    'az eventgrid domain key list -g rg -n d'
    'az staticwebapp appsettings list -n app'
    'az appconfig credential list -n store'
    'az webpubsub key show -g rg -n n'
    'az communication list-key -g rg -n n'
    'az iot hub policy list --hub-name h'
    'az iot hub policy show --hub-name h -n p'
    'az keyvault secret show-deleted --vault-name v -n n'
    'az apim nv show-secret -g rg --service-name s --named-value-id i'
    'az foo bar list --show-values'
    'az foo bar list --include-values'
    'az foo bar list --include-value'
    'az foo bar list --show-s'
    'az foo bar list --resolve-keyvault'
    'aws eks get-token --cluster-name c'
    'aws sso get-role-credentials --role-name r --account-id 1 --access-token t'
    'aws codeartifact get-authorization-token --domain d'
    'aws ecr-public get-login-password'
    'aws redshift get-cluster-credentials --db-user u --cluster-identifier c'
    'aws redshift-serverless get-credentials --workgroup-name w'
    'aws cognito-identity get-credentials-for-identity --identity-id i'
    'aws ssm get-parameter-history --name n --with-decryption'
    'aws apigateway get-api-key --api-key k --include-value'
    'aws apigateway get-api-keys --include-values'
    'aws glue get-connection --name n'
    'aws glue get-connections'
    'aws lightsail get-instance-access-details --instance-name i'
    'aws cognito-idp describe-user-pool-client --user-pool-id p --client-id c'
    'aws ec2 describe-instances --with-decryption'
    'aws ssm get-parameters-by-path --path / --with-dec'
    'aws secretsmanager get-random-password'
    'aws glacier get-job-output --account-id - --vault-name v --job-id j out.bin'
    'aws apigateway get-export --rest-api-id a --stage-name s --export-type swagger out.json'
    'aws iot-data get-thing-shadow --thing-name t out.json'
    'aws appconfig get-configuration --application a --environment e --configuration c --client-id i out.bin'
    'aws kinesis-video-media get-media --stream-name s --start-selector StartSelectorType=NOW out.mkv'
    'aws lambda get-function --function-name f --no-paginate out.bin'
    'aws ebs get-snapshot-block --snapshot-id s --block-index 0 --block-token t out.bin'
    'kubectl get secret db --template={{.data}}'
    'kubectl get secret db --template ''{{.data}}'''
    'kubectl get secret db --tem x'
    'kubectl get -f s.yaml -o yaml'
    'kubectl get -k dir -o json'
    'kubectl get --filename=s.yaml -o jsonpath=x'
    'kubectl get secrets.v1. -o yaml'
    'kubectl get secret.v1.core db -o yaml'
    'kubectl get secrets.v1.core/db -o yaml'
    'Get-ChildItem | Select-Object -Property $s'
    'Get-ChildItem | Sort-Object $s'
    '''a'' -replace ''a'', $s'
    '''a'' -split $s'
    '(Get-Command Get-Date).ScriptBlock'
    'Get-Item x | ForEach-Object { $_.ScriptBlock }'
    "find . $([char]0x2013)delete"
    "find . $([char]0x2014)delete"
    "find . $([char]0x2015)delete"
    "sort $([char]0x2013)o out.txt in.txt"
    "git $([char]0x2013)c core.fsmonitor=x status"
    "git log $([char]0x2013)-output=x"
    'Get-Command -Name x y'
    'Test-Path -Path x y'
    'Get-Content -Path a b'
    'Invoke-ScriptAnalyzer -Path x -Settings $h'
    'Invoke-ScriptAnalyzer -Path x -Settings (Get-Content s.psd1)'
    'Get-FileHash -Path README.md SHA256'
    'Get-FileHash -LiteralPath README.md SHA256'
    # Review round 3: local secrets, environment, aws and kubectl inversions, and the rest
    'aws glacier get-job-output --account-id - --vault-name v --job-id j --only-show-errors out.bin'
    'aws glacier get-job-output --account-id - --vault-name v --job-id j --no-paginate --only-show-errors out.bin'
    'aws glacier get-job-output --account-id - --vault-name v --job-id j --only-show-errors --debug out.bin'
    'aws glacier get-job-output --account-id - --vault-name v --job-id j --only-show-errors=true out.bin'
    'aws glacier get-job-output --account-id - --vault-name v --job-id j --unknown-flag out.bin'
    'kubectl get secret web -o ''jsonpath-as-json={.data}'''
    'kubectl get secret web -o=''jsonpath-as-json={.data}'''
    'kubectl get secret web --output=''jsonpath-as-json={.data}'''
    'kubectl get secrets/web -o ''jsonpath-as-json={.data}'''
    'kubectl get secret web -o futureformat'
    'kubectl get secret web --output=weird'
    'kubectl get secret web -o'
    'kubectl get -f s.yaml -o futureformat'
    'az apim subscription show -g rg --service-name s --sid x'
    'az webapp deployment list-publishing-profiles -g rg -n app'
    'az iot hub device-identity show --hub-name h -d d'
    'az group show-delete -n x'
    'az vm list-restart -g rg'
    'gcloud compute list-delete'
    'cat ~/.ssh/id_rsa'
    'cat ~/.ssh/config'
    'head -n 3 ~/.aws/credentials'
    'tail ~/.aws/config'
    'cat ~/.azure/accessTokens.json'
    'cat ~/.kube/config'
    'cat ~/.docker/config.json'
    'cat ~/.git-credentials'
    'cat ~/.netrc'
    'cat .env'
    'cat .env.local'
    'cat config/.env.production'
    'cat /proc/self/environ'
    'cat /proc/1234/environ'
    'grep -r password ~/.ssh'
    'rg token ~/.aws'
    'ls ~/.ssh'
    'cat id_rsa'
    'cat ./id_ed25519'
    'cat C:/Users/alice/.ssh/id_rsa'
    'cat ''C:\Users\alice\.ssh\id_rsa'''
    'cat ''%USERPROFILE%\.aws\credentials'''
    'wc -c ~/.npmrc'
    'Get-Content ~/.ssh/id_rsa'
    'Get-Content $HOME/.ssh/id_rsa'
    'Get-Content "$HOME\.ssh\id_rsa"'
    'Get-Content $env:USERPROFILE\.ssh\config'
    'Get-Content -Path "$env:USERPROFILE\.aws\credentials"'
    'Select-String -Path ~/.kube/config -Pattern server'
    'Get-Content C:\Users\alice\.azure\azureProfile.json'
    '[System.IO.File]::ReadAllText("$HOME/.ssh/id_rsa")'
    '$p = ''~/.ssh/id_rsa''; Get-Content $p'
    'Get-Item ~/.git-credentials'
    'Get-ChildItem ~/.ssh'
    'Get-Content .env'
    'Get-ChildItem env:'
    'dir env:'
    'gci env:'
    'Get-Item env:*'
    'Get-ChildItem Env:\'
    'Get-ChildItem -Path env:'
    'Get-ChildItem env:*KEY*'
    'Get-Item env:API_KEY'
    'Get-Content env:SECRET_X'
    'printenv'
    'env'
    'env | sort'
    'set'
    '$env:API_TOKEN'
    'Write-Output $env:MY_SECRET'
    '$env:DB_PASSWORD'
    'Write-Output ${env:AWS_SECRET_ACCESS_KEY}'
    'Write-Output "$env:CONNECTION_STRING"'
    'Write-Output "x $env:github_token"'
    'Write-Output $env:PGPASSWORD'
    'Write-Output $env:USER_PWD'
    'Write-Output $env:SOME_CREDENTIAL'
    '[Environment]::GetEnvironmentVariable(''API_KEY'')'
    '[Environment]::GetEnvironmentVariable($n)'
    'Get-ChildItem | Select-Object -ExpandProperty ScriptBlock'
    'Get-ChildItem | Select-Object -Property ScriptBlock'
    'Get-ChildItem | Format-List -Property ScriptBlock'
    'Get-ChildItem | Sort-Object ScriptBlock'
    'Get-ChildItem | Measure-Object -Property ScriptBlock'
    'Get-Command Get-Date | Select-Object PSObject'
    '$MaximumVariableCount = 1'
    '$MaximumAliasCount = 1'
    '$MaximumFunctionCount = 1'
    '$MaximumDriveCount = 1'
    '$NestedPromptLevel = 1'
    'Get-ChildItem | Select-Object @{ N = ''a''; E = $v }'
    'Get-ChildItem | Select-Object @{ Name = ''a''; Expression = $v }'
    'Measure-Command { Remove-Item x }'
    'Measure-Command { ./x.ps1 }'
    'Measure-Command $s'
    'Measure-Command -Expression $s'
    'Start-Sleep -Seconds 1 -Foo'
    'Start-Sleep -Seconds (Remove-Item x)'
    'git log -oneline*'
    'git log --since=*'
    'rg --glob=*.md x'
    # Review round 4: aws reads that print environment variables
    'aws lambda get-function-configuration --function-name x'
    'aws lambda get-function --function-name f'
    'aws lambda get-function --function-name f --qualifier 1'
    'aws lambda list-functions'
    'aws lambda list-versions-by-function --function-name f'
    'aws ecs describe-task-definition --task-definition t'
    'aws ecs describe-tasks --cluster c --tasks t'
    # Review round 5: Environment provider, 8.3 names, revision paths, engine variables, outfile operations, secret names
    'Get-ChildItem Environment::'
    'gci Environment::'
    'Get-ChildItem Microsoft.PowerShell.Core\Environment::*'
    'Get-ChildItem Environment:: | Select-Object -First 1'
    'Get-Item Environment::GITHUB_TOKEN'
    'Get-ChildItem -LiteralPath Environment::'
    'Get-ChildItem ''Environment::'''
    'Get-ChildItem microsoft.powershell.core\ENVIRONMENT::'
    'Resolve-Path Environment::'
    'Get-Item Environment::GITHUB_PAT'
    'Get-Item Environment::DATABASE_URL'
    'Get-ChildItem Microsoft.PowerShell.Core\Environment::'
    'Get-ChildItem Environment::*KEY*'
    'Get-Content C:/Users/x/GIT-CR~1'
    'cat C:/Users/x/ID_ED2~1'
    'cat C:/Users/SROSS~1/notes.txt'
    'Get-Content C:\Users\x\GIT-CR~1'
    'git show HEAD:.env'
    'git show HEAD:.aws/credentials'
    'git show main:.env.local'
    'git show HEAD:.ssh/id_rsa'
    'git show origin/main:.netrc'
    'git cat-file -p HEAD:.env'
    '$MaximumErrorCount = 1'
    '$ConsoleFileName = ''x'''
    '$maximumerrorcount = 1'
    '$consolefilename = ''x'''
    '$Files = 1'
    '$PSCmdlet = 1'
    '$PSItem = 1'
    '$Event = 1'
    'aws glacier get-job-output --account-id - --vault-name v --job-id j --range-name out.bin'
    'aws ec2 describe-instance-status --include-all-instances out.bin'
    'aws apigateway get-sdk --rest-api-id a --stage-name s --sdk-type javascript out.zip'
    'aws apigateway get-export --rest-api-id a --stage-name s --export-type swagger --accepts application/json out.json'
    'aws glacier get-job-output --account-id - --vault-name v --job-id j --range bytes=0-9 out.bin'
    'aws iot-data get-thing-shadow --thing-name t --shadow-name s out.json'
    'aws mediastore-data get-object --path p out.bin'
    'aws ebs get-snapshot-block --snapshot-id s --block-index 0 --block-token t out.bin'
    'aws codeartifact get-package-version-asset --domain d --repository r --format npm --package p --package-version 1 --asset a out.bin'
    'Get-Item env:GITHUB_PAT'
    'Get-Item env:DATABASE_URL'
    'Get-Item env:REDIS_URL'
    '$env:GITHUB_PAT'
    '$env:DATABASE_URL'
    'Write-Output ${env:REDIS_URL}'
    'Write-Output "$env:CONNECTION_URL"'
    '[Environment]::GetEnvironmentVariable(''DATABASE_URL'')'
    '[Environment]::GetEnvironmentVariable(''GITHUB_PAT'')'
    'Write-Output $env:SESSION_ID'
    'Write-Output $env:AUTH_HEADER'
    'Write-Output $env:MY_COOKIE'
    'aws batch describe-job-definitions'
    'aws batch describe-job-definitions --job-definitions x'
    'aws elasticbeanstalk describe-configuration-settings --application-name a --environment-name e'
    'aws apprunner describe-service --service-arn arn:aws:apprunner:us-east-1:123456789012:service/s/1'
    'kubectl get secret web --outp yaml'
    'kubectl get secret web --out=yaml'
    'kubectl get secret web --o yaml'
    # Review round 6: runs of separators in provider paths, bare 8.3 names
    'Get-ChildItem Microsoft.PowerShell.Core\\Environment::'
    'Get-ChildItem env:\\'
    'Get-ChildItem Environment::\\'
    'Get-ChildItem \\Environment::'
    'Get-ChildItem Microsoft.PowerShell.Core\\\Environment::'
    'Get-ChildItem Microsoft.PowerShell.Core\\Environment::GITHUB_TOKEN'
    'Get-ChildItem Microsoft.PowerShell.Core\\Environment::*'
    'Get-ChildItem Microsoft.PowerShell.Core\Environment::\\'
    'Get-ChildItem env://'
    'Get-ChildItem Environment::\\GITHUB_TOKEN'
    'Set-Location env:; Get-ChildItem'
    'Push-Location Environment::; Get-ChildItem'
    'cat ID_ED2~1'
    'Get-Content ID_ED2~1'
    'cat GIT-CR~1'
    'cat ENV~1'
    'cat SSH~1/id_rsa'
    'git show HEAD:ID_ED2~1'
    'Get-ChildItem Microsoft.PowerShell.Core/Environment::'
    'Get-ChildItem Microsoft.PowerShell.Core//Environment::*'
    'Get-Item Microsoft.PowerShell.Core/Environment::GITHUB_TOKEN'
    # Review round 7: the environment remainder must be one plain variable name
    'Get-ChildItem env:.'
    'Get-ChildItem env:..'
    'Get-ChildItem env:.\.'
    'Get-Item env:.'
    'Get-Item env:.\PATH'
    'Get-Item env:PATH\.'
    'Get-Item env:PATH\..'
    'Get-Item Environment::.'
    'Get-Item env:\.'
    'Get-Item ''env: PATH'''
    'Get-Item env:A\B'
    'Get-ChildItem env:\*'
    'Get-ChildItem Microsoft.PowerShell.Core\Environment::.'
    'Get-Item Microsoft.PowerShell.Core\Environment::PATH\.'
    'Write-Output ${env:.}'
    'Write-Output ${env:A.B}'
    'Write-Output ${env:ProgramFiles(x86)}'
    '[Environment]::GetEnvironmentVariable(''A.B'')'
    '[Environment]::GetEnvironmentVariable(''.'')'
    '[Environment]::GetEnvironmentVariable('''')'
    'Get-ChildItem Foo\Environment::'
    'Get-Item Foo\Environment::PATH'
    'Get-ChildItem x\env:'
    'Get-Item Microsoft.PowerShell.Core:\Environment::PATH'
    'Get-Item "env:PATH`n"'
    'Get-Item "env:`n"'
    'Get-Item "env:PATH`nGITHUB"'
    # Review round 8: glob credential names, local settings file, jq env, more aws secret reads, script-block sinks, search patterns
    'cat .env*'
    'cat .en?'
    'cat .git-cred*'
    'cat .netr?'
    'cat id_r?a'
    'cat ~/.a?s/credentials'
    'cat ~/.aw[s]/credentials'
    'cat .env.*'
    'cat .env.l*'
    'cat .env.x*'
    'cat local.settings.*'
    'cat local.sett?ngs.json'
    'cat .ss?/id_rsa'
    'cat .[e]nv'
    'cat .kub?/config'
    'cat .docke?/config.json'
    'cat ~/.azur*/accessTokens.json'
    'Get-Content .env*'
    'Get-Content .env.*'
    'Get-Content ~/.a?s/credentials'
    'Get-Content ~/.aw[s]/credentials'
    'Get-Content .git-cred*'
    'Get-Content id_r?a'
    'Get-Content *env*'
    'Get-Content ~/*/credentials'
    'Get-Content ./*/id_rsa'
    'Select-String -Path .env* -Pattern x'
    'cat local.settings.json'
    'Get-Content local.settings.json'
    'jq . local.settings.json'
    'cat ./api/local.settings.json'
    'Get-Content C:\work\api\local.settings.json'
    'git show HEAD:local.settings.json'
    'jq -n env'
    'jq -n ''$ENV'''
    'jq ''env'''
    'jq -n ''env.PATH'''
    'jq ''$ENV.HOME'' x.json'
    'jq -n ''{a: env}'''
    'jq --rawfile s ~/.ssh/id_rsa . x.json'
    'jq --slurpfile s .env . x.json'
    'aws ec2 describe-instances --debug'
    'aws ec2 describe-instances --deb'
    'aws appsync list-api-keys --api-id a'
    'aws amplify get-app --app-id a'
    'aws amplify get-branch --app-id a --branch-name b'
    'aws amplify list-apps'
    'aws amplify list-branches --app-id a'
    'aws ec2 describe-instance-attribute --instance-id i --attribute userData'
    'aws ec2 describe-instance-attribute --instance-id i --attribute=userData'
    'aws glue get-job --job-name j'
    'aws glue get-jobs'
    'aws batch describe-jobs --jobs j'
    'aws sagemaker describe-training-job --training-job-name t'
    'aws sagemaker describe-processing-job --processing-job-name p'
    'aws sagemaker describe-model --model-name m'
    'aws sagemaker describe-transform-job --transform-job-name t'
    'aws ec2 describe-launch-template-versions --launch-template-id l'
    'aws ec2 get-launch-template-data --instance-id i'
    'aws autoscaling describe-launch-configurations'
    'aws codebuild batch-get-projects --names p'
    'aws codebuild batch-get-builds --ids b'
    '[regex]::Replace(''a'', ''a'', $s)'
    '[regex]::Replace($x, $p, ''b'')'
    '[regex]::Split($x, $p)'
    'Get-ChildItem | Select-Object -ExpandProperty $p'
    'Get-ChildItem | Select-Object -ExcludeProperty $p'
    'Get-Module | Select-Object -ExpandProperty OnRemove'
    '$m = Get-Module; $m.OnRemove'
    'sort /ox.txt README.md'
    'sort /O:x README.md'
    'uniq /xout'
    # Review round 9: listing versus reading wildcards, jq programs, credentials name
    'cat ~/.aws/*'
    'cat .env*'
    'Get-Content *.env'
    'cat ~/.*/credentials'
    'Get-Content ~/.*/credentials'
    'Get-Content *.json'
    'Get-Content docs/*.json'
    'Select-String -Path *.json -Pattern x'
    'Get-FileHash *.json'
    'cat docs/*.json'
    'jq . docs/*.json'
    'wc -l docs/*.json'
    'sed -n ''1p'' docs/*.json'
    'rg x docs/*.json'
    'Get-Content src/*/credentials'
    'cat credentials'
    'Get-Content credentials'
    'cat ~/*/credentials'
    'cat src/**/credentials'
    'jq -f prog.jq package.json'
    'jq --from-file prog.jq package.json'
    'jq -L ~/.aws ''include "credentials"; .'' package.json'
    'jq ''import "../../.aws/credentials" as c; .'' package.json'
    'jq ''include "x"; import "~/.ssh/id_rsa" as k; .'' package.json'
    'Get-Content src/*'
    'Get-Content *'
    'Select-String -Path src/* -Pattern x'
    'Get-FileHash docs/*'
    'Get-Content src/**'
    'Get-Content ~/y/*'
    # Review round 10: listing fed to a reader, search patterns and pattern files
    'Get-ChildItem -Filter .env* | Get-Content'
    'Get-ChildItem -Filter credentials | Get-Content'
    'Get-ChildItem -Recurse -Include *.env | Get-Content -Raw'
    'Get-ChildItem -Filter .env* | Select-Object -ExpandProperty FullName | Get-Content'
    'Get-ChildItem -Filter *.json | ForEach-Object { Get-Content $_.FullName }'
    'Get-ChildItem *.json | Select-String x'
    'Get-ChildItem * | Get-Content'
    'Get-ChildItem -Filter .env* | Select-String x'
    '$x = Get-ChildItem -Filter .env*; Get-Content $x.FullName'
    'Get-ChildItem ~/.* | Get-Content'
    'rg x .env'
    'rg -e x ~/.ssh/id_rsa'
    'git grep x -- .env'
    'rg --file=.env docs'
    'grep -f ~/.ssh/id_rsa docs'
    'rg -f docs/*.json x'
    'rg -f .env x'
    # Review round 11: per-tool search options, option terminator, attached values, static file readers
    'grep --color KEY .env'
    'egrep --colour KEY .env'
    'git grep --color KEY -- .env'
    'grep -- -e .env'
    'rg -- -e .env'
    'grep -f.env docs'
    'rg -f.env docs'
    'grep -f~/.ssh/id_rsa docs'
    'rg -fid_rsa docs'
    'Get-ChildItem -Force -Filter .env | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }'
    'Get-ChildItem -Filter credentials | ForEach-Object { [System.IO.File]::ReadAllLines($_.FullName) }'
)

$script:GuardBlockOneTool = @(
    @{ Tool = 'PowerShell'; Command = 'git blame -L 1,10 -- README.md' }
    @{ Tool = 'PowerShell'; Command = 'git log --since="2 weeks ago"' }
    @{ Tool = 'PowerShell'; Command = 'git log --format="%h %s"' }
    @{ Tool = 'PowerShell'; Command = 'git log --pretty=format:''%h %s'' -5' }
    @{ Tool = 'Bash'; Command = 'cat ""*' }
    @{ Tool = 'Bash'; Command = 'cat ''''*' }
    @{ Tool = 'Bash'; Command = 'cat -*' }
    @{ Tool = 'Bash'; Command = 'grep x ""*' }
    @{ Tool = 'Bash'; Command = 'grep x ''''?' }




    @{ Tool = 'PowerShell'; Command = 'ls env:' }



)

$script:GuardBlockWithAllow = @(
    @{ Command = 'Test-MyProject -Path .'; Allow = '' }
    @{ Command = 'Test-MyProject -Path . -OutVariable v'; Allow = 'Test-MyProject' }
    @{ Command = 'Test-MyProject -Path . -ov v'; Allow = 'Test-MyProject' }
    @{ Command = 'Test-MyProject -Path . -OutV v'; Allow = 'Test-MyProject' }
    @{ Command = 'Test-MyProject { Remove-Item x }'; Allow = 'Test-MyProject' }
    @{ Command = 'Test-MyProject @args'; Allow = 'Test-MyProject' }
    @{ Command = 'Test-MyProject -Settings @{ a = 1 }'; Allow = 'Test-MyProject' }
    @{ Command = 'Test-MyProject -Path (Remove-Item x)'; Allow = 'Test-MyProject' }
    @{ Command = 'Remove-Item y'; Allow = 'Remove-Item x' }
    @{ Command = './Test-Thing.ps1'; Allow = 'Test-Thing' }
    @{ Command = 'Test-Thing'; Allow = 'Test-Thing -Path' }
    @{ Command = 'pwsh -File x.ps1'; Allow = 'pwsh' }
    @{ Command = 'python3 x'; Allow = 'python3' }
    @{ Command = 'Test-MyProject -Path . > out.txt'; Allow = 'Test-MyProject' }
)

$script:GuardAllowCases = @(
    # From the earlier repository tests and the independent QA suites
    @{ Tool = 'Both'; Command = 'git status' }
    @{ Tool = 'Both'; Command = 'git -C ../repo log --oneline -5' }
    @{ Tool = 'Both'; Command = 'git branch -a' }
    @{ Tool = 'PowerShell'; Command = 'git diff HEAD~1 | Select-String TODO' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content README.md | Select-Object -First 20' }
    @{ Tool = 'Both'; Command = 'rg --files | wc -l' }
    @{ Tool = 'Both'; Command = 'gh run view 123 --log-failed' }
    @{ Tool = 'Both'; Command = 'gh pr diff 42' }
    @{ Tool = 'Both'; Command = 'az webapp list --query "[].name"' }
    @{ Tool = 'Both'; Command = 'kubectl get pods -n web' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-Pester ./tests 2>&1' }
    @{ Tool = 'PowerShell'; Command = '$files = Get-ChildItem src; $files.Count' }
    @{ Tool = 'PowerShell'; Command = '$s = "a" + "b"' }
    @{ Tool = 'PowerShell'; Command = '''text''' }
    @{ Tool = 'PowerShell'; Command = '$files = Get-ChildItem src; $files[0].Name' }
    @{ Tool = 'PowerShell'; Command = '$n = 1; $n -gt 0' }
    @{ Tool = 'PowerShell'; Command = 'for ($i = 0; $i -lt 3; $i++) { Get-Content README.md }' }
    @{ Tool = 'PowerShell'; Command = '$ErrorActionPreference = ''Stop''' }
    @{ Tool = 'Both'; Command = 'az vm list -g rg -o table' }
    @{ Tool = 'Both'; Command = 'az vm show -g rg -n web' }
    @{ Tool = 'Both'; Command = 'az account show' }
    @{ Tool = 'Both'; Command = 'aws ec2 describe-instances' }
    @{ Tool = 'Both'; Command = 'aws s3api list-buckets' }
    @{ Tool = 'Both'; Command = 'gcloud compute instances list' }
    @{ Tool = 'Both'; Command = 'kubectl -n web get pods' }
    @{ Tool = 'Both'; Command = 'kubectl logs web-0 --tail=5' }
    @{ Tool = 'Both'; Command = 'gh pr list --json title -q .[].title' }
    @{ Tool = 'Both'; Command = 'sort README.md | uniq -c' }
    @{ Tool = 'Both'; Command = 'uniq -f 1 README.md' }
    @{ Tool = 'Both'; Command = 'git remote -v' }
    @{ Tool = 'Both'; Command = 'git remote show origin' }
    @{ Tool = 'Both'; Command = 'git remote get-url origin' }
    @{ Tool = 'Both'; Command = 'git log --oneline -5 -- guards' }
    @{ Tool = 'Both'; Command = 'git show HEAD:README.md' }
    @{ Tool = 'Both'; Command = 'git diff --stat' }
    @{ Tool = 'Both'; Command = 'file README.md' }
    @{ Tool = 'Both'; Command = 'tree -L 2' }
    @{ Tool = 'Both'; Command = 'find . -name "*.ps1" -type f' }
    @{ Tool = 'Both'; Command = 'rg -n TODO guards' }
    @{ Tool = 'Both'; Command = 'rg -n "Remove-Item" guards' }
    @{ Tool = 'PowerShell'; Command = 'rg -n ''Set-Content|Out-File'' guards' }
    @{ Tool = 'Both'; Command = 'grep -rn "Set-Content" guards' }
    @{ Tool = 'Both'; Command = 'git grep -n "Set-Content" -- guards' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Path guards/Test-GuildReadOnlyCommand.ps1 -Pattern ''Remove-Item''' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content guards/Test-GuildReadOnlyCommand.ps1 | Select-String ''Invoke-Expression''' }
    @{ Tool = 'Both'; Command = 'rg "a > b" docs' }
    @{ Tool = 'Both'; Command = 'cat scripts/Invoke-Build.ps1' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content ./scripts/Invoke-Build.ps1' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content .\scripts\Invoke-Build.ps1 | Select-Object -First 5' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Path src/Set-Thing.ps1 -Pattern TODO' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Path ''src/Set-Thing.ps1'' -Pattern TODO' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Path Guild/Public -Filter Remove-*.ps1' }
    @{ Tool = 'Both'; Command = 'git -C ../repo log --oneline' }
    @{ Tool = 'Both'; Command = 'git log -- docs/New-Thing.md' }
    @{ Tool = 'PowerShell'; Command = 'Select-String ''{{role:id}}'' docs/spec.md' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem src | Where-Object { $_.Length -gt 10 } | Select-Object Name' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem src | ForEach-Object { Get-Content $_.FullName } | Select-String TODO' }
    @{ Tool = 'PowerShell'; Command = '$n = (Get-ChildItem src).Count' }
    @{ Tool = 'PowerShell'; Command = '$n += (Get-ChildItem src).Count' }
    @{ Tool = 'PowerShell'; Command = '& git status' }
    @{ Tool = 'PowerShell'; Command = '& Get-Content README.md' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content missing.txt 2>$null' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-Pester ./tests 2>&1 | Out-Null' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem | Out-Host' }
    @{ Tool = 'PowerShell'; Command = 'Write-Host "checking"; Get-Date' }
    @{ Tool = 'PowerShell'; Command = 'if (Test-Path README.md) { Get-Content README.md } else { Write-Output none }' }
    @{ Tool = 'PowerShell'; Command = 'foreach ($f in Get-ChildItem src) { Get-Content $f.FullName }' }
    @{ Tool = 'PowerShell'; Command = '[System.IO.File]::ReadAllText("README.md")' }
    @{ Tool = 'PowerShell'; Command = '[IO.File]::Exists("README.md")' }
    @{ Tool = 'PowerShell'; Command = '[IO.Path]::GetFileName("a/b.txt")' }
    @{ Tool = 'PowerShell'; Command = '[regex]::Matches("abc", "b").Count' }
    @{ Tool = 'PowerShell'; Command = '[math]::Max(1, 2)' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content a.json | ConvertFrom-Json | ConvertTo-Json' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Pattern "\d{3}" README.md' }
    @{ Tool = 'Both'; Command = 'cat ./src/Remove-Thing.sh' }
    @{ Tool = 'Both'; Command = 'rg -n "Set-Content" guards' }
    @{ Tool = 'Bash'; Command = 'ls -la guards | head -3' }
    @{ Tool = 'Bash'; Command = 'cat README.md 2>/dev/null' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildContext -Path .' }
    @{ Tool = 'PowerShell'; Command = 'Test-GuildDocs -Path . -Owner architect' }
    @{ Tool = 'PowerShell'; Command = 'New-GuildBrief -Role reviewer -Goal "x" -Path .' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content ./src/Set-Thing.ps1' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-Pester ./tests' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-ScriptAnalyzer -Path guards/Test-GuildReadOnlyCommand.ps1 -Severity Warning' }
    @{ Tool = 'PowerShell'; Command = 'Import-Module ./Guild/Guild.psd1' }
    @{ Tool = 'PowerShell'; Command = 'Import-Module C:/work/guild/Guild/Guild.psd1' }
    @{ Tool = 'PowerShell'; Command = 'Test-GuildInstall -Harness claude' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildContext -Path . | ConvertTo-Json' }
    @{ Tool = 'Bash'; Command = 'cat README.md >/dev/null' }
    @{ Tool = 'Both'; Command = 'cat README.md 2>&1' }
    @{ Tool = 'Both'; Command = 'sed -n ''1,20p'' README.md' }
    @{ Tool = 'Both'; Command = 'git branch --list ''feat*''' }
    @{ Tool = 'Both'; Command = 'rg -n --pre-glob ''*.md'' TODO README.md' }
    @{ Tool = 'Both'; Command = 'git tag --list ''v1*''' }
    @{ Tool = 'Both'; Command = 'aws s3 ls s3://example-bucket' }
    @{ Tool = 'Both'; Command = 'git log --oneline --graph -n 20' }
    @{ Tool = 'Bash'; Command = 'git log --since="2 weeks ago" --author=alice --no-merges' }
    @{ Tool = 'Both'; Command = 'git diff --name-only HEAD~1' }
    @{ Tool = 'Both'; Command = 'git diff main...HEAD -- guards' }
    @{ Tool = 'Both'; Command = 'git show --stat HEAD' }
    @{ Tool = 'Both'; Command = 'git log -p -- guards/Test-GuildReadOnlyCommand.ps1' }
    @{ Tool = 'Bash'; Command = 'git log --format="%h %s"' }
    @{ Tool = 'Bash'; Command = 'git log --pretty=format:''%h %s'' -5' }
    @{ Tool = 'Both'; Command = 'git diff --no-color --stat' }
    @{ Tool = 'Both'; Command = 'git rev-parse --abbrev-ref HEAD' }
    @{ Tool = 'Both'; Command = 'git status --short' }
    @{ Tool = 'Both'; Command = 'git branch --show-current' }
    @{ Tool = 'Both'; Command = 'git diff --cached --name-only' }
    @{ Tool = 'Both'; Command = 'git log origin/main..HEAD --oneline' }
    @{ Tool = 'Bash'; Command = 'git log --grep="guard" -i --oneline' }
    @{ Tool = 'Bash'; Command = 'git blame -L 1,10 -- README.md' }
    @{ Tool = 'Both'; Command = 'git log -S "Split-CommandText" --oneline' }
    @{ Tool = 'Both'; Command = 'git log --name-status -3' }
    @{ Tool = 'Both'; Command = 'git -C ../guild status' }
    @{ Tool = 'PowerShell'; Command = 'git ls-files | rg "\.ps1$"' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-Pester -Path ./tests -Output Detailed' }
    @{ Tool = 'PowerShell'; Command = '$r = Invoke-Pester ./tests -PassThru; $r.FailedCount' }
    @{ Tool = 'PowerShell'; Command = '$c = New-PesterConfiguration; $c.Run.Path = ''./tests''; $c.Run.PassThru = $true; Invoke-Pester -Configuration $c' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-ScriptAnalyzer -Path guards -Severity Warning' }
    @{ Tool = 'PowerShell'; Command = 'Import-PowerShellDataFile ./PSScriptAnalyzerSettings.psd1' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildContext -Path . | ConvertTo-Json -Depth 3' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildRepoSurvey -Path . -AsJson' }
    @{ Tool = 'PowerShell'; Command = 'Test-GuildInstall -Harness claude -Scope Project -Path .' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildFindingSummary -Path .' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildPack' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Recurse -Filter *.ps1 guards | Select-Object -ExpandProperty FullName' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Path guards/*.ps1 -Pattern ''Split-CommandText'' -SimpleMatch' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content README.md -TotalCount 20' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content README.md -Raw' }
    @{ Tool = 'PowerShell'; Command = '$x = Get-Content README.md; $x.Count' }
    @{ Tool = 'PowerShell'; Command = 'Get-FileHash README.md -Algorithm SHA256' }
    @{ Tool = 'PowerShell'; Command = 'ConvertFrom-Json (Get-Content x.json -Raw)' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content README.md | Select-String -Pattern ''Guild'' -Context 2' }
    @{ Tool = 'PowerShell'; Command = 'Test-Path ./x.ps1 -PathType Leaf' }
    @{ Tool = 'PowerShell'; Command = 'Set-Location guards; Get-ChildItem' }
    @{ Tool = 'PowerShell'; Command = 'Write-Host "done"' }
    @{ Tool = 'Both'; Command = 'sed -n ''1,5p'' README.md | head -2' }
    @{ Tool = 'Both'; Command = 'cat README.md | head -20 | tail -5' }
    @{ Tool = 'Bash'; Command = 'sort -rn file.txt' }
    @{ Tool = 'Bash'; Command = 'sort -t, -k2 x.csv' }
    @{ Tool = 'Both'; Command = 'tree -L 2 guards' }
    @{ Tool = 'Both'; Command = 'file -b README.md' }
    @{ Tool = 'Both'; Command = 'find . -name "*.md" -newer README.md' }
    @{ Tool = 'Both'; Command = 'jq ''.name'' package.json' }
    @{ Tool = 'Both'; Command = 'head -n 20 README.md | tail -n 5' }
    # docs/guard.md 8.2
    @{ Tool = 'Bash'; Command = 'head -n 20 README.md | tail -n 5' }
    @{ Tool = 'Bash'; Command = 'cat README.md | head -20 | tail -5' }
    @{ Tool = 'Bash'; Command = 'rg --pre-glob ''*.md'' TODO .' }
    @{ Tool = 'Bash'; Command = 'sed -n ''1,20p'' README.md' }
    @{ Tool = 'Bash'; Command = 'sed -n ''1,5p'' README.md | head -2' }
    @{ Tool = 'Bash'; Command = 'git blame -L 1,10 -- README.md' }
    @{ Tool = 'Bash'; Command = 'cat README.md 2>/dev/null' }
    @{ Tool = 'Bash'; Command = 'cat README.md >/dev/null' }
    @{ Tool = 'Bash'; Command = 'cat README.md 2>&1' }
    @{ Tool = 'Bash'; Command = 'cat README.md 2>&1 | head -3' }
    @{ Tool = 'Bash'; Command = 'cat README.md && ls' }
    @{ Tool = 'Bash'; Command = 'cat README.md || ls' }
    @{ Tool = 'Bash'; Command = 'ls -la guards | head -3' }
    @{ Tool = 'Bash'; Command = 'find . -name "*.md" -newer README.md' }
    @{ Tool = 'Bash'; Command = 'sort -rn file.txt' }
    @{ Tool = 'Bash'; Command = 'sort -t, -k2 x.csv' }
    @{ Tool = 'Bash'; Command = 'tree -L 2 guards' }
    @{ Tool = 'Bash'; Command = 'file -b README.md' }
    @{ Tool = 'Bash'; Command = 'jq ''.name'' package.json' }
    @{ Tool = 'Bash'; Command = 'cat ./src/Remove-Thing.sh' }
    @{ Tool = 'Bash'; Command = 'cat README.md | wc -l' }
    @{ Tool = 'Bash'; Command = 'git log --since="2 weeks ago" --author=alice --no-merges' }
    @{ Tool = 'Bash'; Command = 'git log --format="%h %s"' }
    @{ Tool = 'Bash'; Command = 'git log --pretty=format:''%h %s'' -5' }
    @{ Tool = 'Bash'; Command = 'git log --grep="guard" -i --oneline' }
    @{ Tool = 'Bash'; Command = 'rg -n ''a|b'' guards' }
    @{ Tool = 'Bash'; Command = 'grep -rn "std::string" docs' }
    @{ Tool = 'Both'; Command = 'git status --short' }
    @{ Tool = 'Both'; Command = 'git -C ../guild status' }
    @{ Tool = 'Both'; Command = 'git log --oneline --graph -n 20' }
    @{ Tool = 'Both'; Command = 'git log -p -- guards/Test-GuildReadOnlyCommand.ps1' }
    @{ Tool = 'Both'; Command = 'git log -S "Split-CommandText" --oneline' }
    @{ Tool = 'Both'; Command = 'git log --name-status -3' }
    @{ Tool = 'Both'; Command = 'git log origin/main..HEAD --oneline' }
    @{ Tool = 'Both'; Command = 'git diff --name-only HEAD~1' }
    @{ Tool = 'Both'; Command = 'git diff main...HEAD -- guards' }
    @{ Tool = 'Both'; Command = 'git diff --cached --name-only' }
    @{ Tool = 'Both'; Command = 'git diff --no-color --stat' }
    @{ Tool = 'Both'; Command = 'git show --stat HEAD' }
    @{ Tool = 'Both'; Command = 'git rev-parse --abbrev-ref HEAD' }
    @{ Tool = 'Both'; Command = 'git branch --show-current' }
    @{ Tool = 'Both'; Command = 'git branch --list ''feat*''' }
    @{ Tool = 'Both'; Command = 'git tag --list ''v1*''' }
    @{ Tool = 'Both'; Command = 'git ls-files' }
    @{ Tool = 'Both'; Command = 'aws s3 ls s3://example-bucket' }
    @{ Tool = 'Both'; Command = 'gh pr list --json title -q .[].title' }
    @{ Tool = 'Both'; Command = 'kubectl get secrets' }
    @{ Tool = 'Both'; Command = 'kubectl get secret db -o name' }
    @{ Tool = 'Both'; Command = 'kubectl get secrets -o wide' }
    @{ Tool = 'Both'; Command = 'kubectl get pods -o yaml' }
    @{ Tool = 'Both'; Command = 'kubectl get configmap -o yaml' }
    @{ Tool = 'Both'; Command = 'az keyvault secret list --vault-name v' }
    @{ Tool = 'Both'; Command = 'aws ssm get-parameter --name n' }
    @{ Tool = 'Both'; Command = 'aws ssm describe-parameters' }
    @{ Tool = 'Both'; Command = 'aws secretsmanager list-secrets' }
    @{ Tool = 'Both'; Command = 'aws secretsmanager describe-secret --secret-id s' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-Pester' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-Pester -Path ./tests -Output Detailed' }
    @{ Tool = 'PowerShell'; Command = '$r = Invoke-Pester ./tests -PassThru; $r.FailedCount' }
    @{ Tool = 'PowerShell'; Command = '$c = New-PesterConfiguration; $c.Run.Path = ''./tests''; $c.Run.PassThru = $true; Invoke-Pester -Configuration $c' }
    @{ Tool = 'PowerShell'; Command = '$c = New-PesterConfiguration; $c.Filter.Tag = ''Unit''; $c.Output.Verbosity = ''Detailed''; Invoke-Pester -Configuration $c' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-ScriptAnalyzer -Path guards -Severity Warning' }
    @{ Tool = 'PowerShell'; Command = 'Import-Module ./Guild/Guild.psd1' }
    @{ Tool = 'PowerShell'; Command = 'Import-Module C:/work/guild/Guild/Guild.psd1' }
    @{ Tool = 'PowerShell'; Command = 'Import-PowerShellDataFile ./PSScriptAnalyzerSettings.psd1' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildContext -Path .' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildContext -Path . | ConvertTo-Json -Depth 3' }
    @{ Tool = 'PowerShell'; Command = 'New-GuildBrief -Role reviewer -Goal "x" -Path .' }
    @{ Tool = 'PowerShell'; Command = 'Test-GuildDocs -Path . -Owner architect' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildRepoSurvey -Path . -AsJson' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildFindingSummary -Path .' }
    @{ Tool = 'PowerShell'; Command = 'Get-GuildPack' }
    @{ Tool = 'PowerShell'; Command = 'Test-GuildInstall -Harness claude -Scope Project -Path .' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Recurse -Filter *.ps1 guards | Select-Object -ExpandProperty FullName' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem | Measure-Object' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem | Format-Table' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem | Out-String' }
    @{ Tool = 'PowerShell'; Command = 'ConvertFrom-Json (Get-Content x.json -Raw)' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content README.md -TotalCount 20' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content README.md -Raw' }
    @{ Tool = 'PowerShell'; Command = 'Test-Path ./x.ps1 -PathType Leaf' }
    @{ Tool = 'PowerShell'; Command = 'cat scripts/Invoke-Build.ps1' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Path guards/*.ps1 -Pattern ''x'' -SimpleMatch' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content README.md | Select-String -Pattern ''Guild'' -Context 2' }
    @{ Tool = 'PowerShell'; Command = 'Select-String "std::string" README.md' }
    @{ Tool = 'PowerShell'; Command = 'Get-FileHash README.md -Algorithm SHA256' }
    @{ Tool = 'PowerShell'; Command = '$x = Get-ChildItem src; $x.Count' }
    @{ Tool = 'PowerShell'; Command = '$x = Get-Content README.md; $x.Count' }
    @{ Tool = 'PowerShell'; Command = '$x' }
    @{ Tool = 'PowerShell'; Command = 'Write-Output $env:PATH' }
    @{ Tool = 'PowerShell'; Command = 'Set-Location guards; Get-ChildItem' }
    @{ Tool = 'PowerShell'; Command = 'Write-Host "done"' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem | Select-Object @{ n = ''N''; e = { $_.Name } }' }
    @{ Tool = 'PowerShell'; Command = '$list = @(1, 2, 3); $list[0]' }
    @{ Tool = 'PowerShell'; Command = '[pscustomobject]@{ a = 1 } | ConvertTo-Json' }
    @{ Tool = 'PowerShell'; Command = '1..3 | ForEach-Object { $_ * 2 }' }
    @{ Tool = 'PowerShell'; Command = 'Get-Command Get-Content' }
    @{ Tool = 'PowerShell'; Command = 'Get-Help Get-Content -Examples' }
    @{ Tool = 'PowerShell'; Command = 'git log --oneline -5' }
    @{ Tool = 'PowerShell'; Command = '''a b''.Split('' '')' }
    @{ Tool = 'PowerShell'; Command = '"abc".ToUpper()' }
    @{ Tool = 'PowerShell'; Command = '$PSVersionTable.PSVersion' }
    @{ Tool = 'PowerShell'; Command = 'sort README.md' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content README.md | sort | uniq -c' }
    @{ Tool = 'PowerShell'; Command = '$n = 0; $n++' }
    @{ Tool = 'PowerShell'; Command = '$null = Get-Date' }
    @{ Tool = 'None'; Command = 'git status' }
    @{ Tool = 'PowerShell'; Command = 'Test-MyProject -Path .'; Allow = 'Test-MyProject,Get-MyLog' }
    @{ Tool = 'PowerShell'; Command = 'Test-MyProject -Path . -SkipBuild'; Allow = 'Test-MyProject,Get-MyLog' }
    @{ Tool = 'PowerShell'; Command = 'Get-MyLog -Tail 5 | Select-String ERROR'; Allow = 'Test-MyProject,Get-MyLog' }
    @{ Tool = 'PowerShell'; Command = 'New-GuildDecision -Title x'; Allow = 'New-GuildDecision' }
    @{ Tool = 'PowerShell'; Command = 'New-GuildDecision -Title x -Directory docs/decisions'; Allow = 'New-GuildDecision' }
    # Review round
    @{ Tool = 'PowerShell'; Command = 'Get-FileHash -Path README.md -Algorithm SHA256' }
    @{ Tool = 'Both'; Command = 'az keyvault key list --vault-name v' }
    @{ Tool = 'Both'; Command = 'az keyvault key show --vault-name v -n k' }
    @{ Tool = 'Both'; Command = 'az keyvault secret list-versions --vault-name v -n n' }
    @{ Tool = 'Both'; Command = 'aws glue get-connection --name n --hide-password' }
    @{ Tool = 'Both'; Command = 'aws iam get-account-password-policy' }
    @{ Tool = 'Both'; Command = 'aws iam get-login-profile --user-name u' }
    @{ Tool = 'Both'; Command = 'aws iam get-credential-report' }
    @{ Tool = 'Both'; Command = 'aws iam list-service-specific-credentials' }
    @{ Tool = 'Both'; Command = 'aws ec2 describe-instances --instance-ids i-1' }
    @{ Tool = 'Bash'; Command = 'aws ec2 describe-instances --filters Name=tag:a,Values=b --output json' }
    @{ Tool = 'Both'; Command = 'aws ec2 describe-instances --filters ''Name=tag:a,Values=b'' --output json' }
    @{ Tool = 'Both'; Command = 'aws s3 ls s3://bucket --recursive' }
    @{ Tool = 'Both'; Command = 'kubectl get pods -o yaml' }
    @{ Tool = 'Both'; Command = 'sort README.md' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem | Sort-Object Length' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem | Sort-Object { $_.Length }' }
    @{ Tool = 'PowerShell'; Command = '''a'' -replace ''a'', ''b''' }
    @{ Tool = 'PowerShell'; Command = '''a b'' -split '' ''' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Path x TODO' }
    @{ Tool = 'PowerShell'; Command = 'Select-String TODO -Path x' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Path src *.ps1' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-ScriptAnalyzer -Path x -Settings ./PSScriptAnalyzerSettings.psd1' }
    @{ Tool = 'PowerShell'; Command = 'Invoke-ScriptAnalyzer -Path x -Settings PSGallery' }
    @{ Tool = 'PowerShell'; Command = 'Import-Module ''C:/work/guild/Guild/Guild.psd1''' }
    @{ Tool = 'PowerShell'; Command = 'Import-Module ''C:/work/packs/checks/Tools/Tools.psd1''' }
    # Review round
    @{ Tool = 'PowerShell'; Command = 'Measure-Command { Get-ChildItem src }' }
    @{ Tool = 'PowerShell'; Command = 'Measure-Command { Get-ChildItem src | Where-Object { $_.Length -gt 1 } }' }
    @{ Tool = 'PowerShell'; Command = 'Start-Sleep -Seconds 2' }
    @{ Tool = 'PowerShell'; Command = 'Start-Sleep -Milliseconds 500' }
    @{ Tool = 'PowerShell'; Command = 'Start-Sleep 1' }
    @{ Tool = 'PowerShell'; Command = 'sleep 1' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem | Select-Object @{ N = ''a''; E = { $_.Name } }' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem | Select-Object @{ Name = ''Label''; Expression = ''Name'' }' }
    @{ Tool = 'Both'; Command = 'aws ec2 describe-instances --region us-east-1 --output json' }
    @{ Tool = 'Both'; Command = 'aws ssm get-parameter --name n' }
    @{ Tool = 'Both'; Command = 'aws s3api list-objects-v2 --bucket b --max-items 5' }
    @{ Tool = 'Both'; Command = 'aws sts get-caller-identity --profile p' }
    @{ Tool = 'Both'; Command = 'aws logs describe-log-groups --log-group-name-prefix x' }
    @{ Tool = 'Both'; Command = 'aws iam get-user --user-name u' }
    @{ Tool = 'Both'; Command = 'kubectl get secret web' }
    @{ Tool = 'Both'; Command = 'kubectl get secret web -o name' }
    @{ Tool = 'Both'; Command = 'kubectl get secret web -o wide' }
    @{ Tool = 'Both'; Command = 'kubectl get secret web -o=name' }
    @{ Tool = 'Both'; Command = 'kubectl get secret web --output=wide' }
    @{ Tool = 'Both'; Command = 'az vm list-sizes --location westus' }
    @{ Tool = 'Both'; Command = 'az keyvault secret list-deleted --vault-name v' }
    @{ Tool = 'Both'; Command = 'rg ''--glob=*.md'' TODO .' }
    @{ Tool = 'PowerShell'; Command = 'Write-Output $env:HOME' }
    @{ Tool = 'PowerShell'; Command = 'Get-Item env:PATH' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem env:PATH' }
    @{ Tool = 'PowerShell'; Command = '[Environment]::GetEnvironmentVariable(''PATH'')' }
    @{ Tool = 'Both'; Command = 'cat docs/environment.md' }
    @{ Tool = 'Both'; Command = 'cat .env.example' }
    @{ Tool = 'Both'; Command = 'cat .envrc' }
    @{ Tool = 'Both'; Command = 'cat config/env.example' }
    @{ Tool = 'Both'; Command = 'rg token docs' }
    @{ Tool = 'Both'; Command = 'cat docs/ssh-notes.md' }
    @{ Tool = 'Both'; Command = 'cat ~/notes.md' }
    # Review round 4
    @{ Tool = 'Both'; Command = 'aws lambda list-aliases --function-name f' }
    @{ Tool = 'Both'; Command = 'aws lambda get-alias --function-name f --name n' }
    @{ Tool = 'Both'; Command = 'aws lambda get-policy --function-name f' }
    @{ Tool = 'Both'; Command = 'aws lambda list-tags --resource arn:aws:lambda:us-east-1:123456789012:function:f' }
    @{ Tool = 'Both'; Command = 'aws lambda get-function-concurrency --function-name f' }
    @{ Tool = 'Both'; Command = 'aws ecs describe-services --cluster c --services s' }
    @{ Tool = 'Both'; Command = 'aws ecs list-task-definitions' }
    @{ Tool = 'Both'; Command = 'aws ecs describe-clusters --clusters c' }
    # Review round
    @{ Tool = 'PowerShell'; Command = 'Get-Item Environment::PATH' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem Environment::HOME' }
    @{ Tool = 'PowerShell'; Command = 'Write-Output $env:USERPROFILE' }
    @{ Tool = 'PowerShell'; Command = 'Write-Output $env:GITHUB_PATH' }
    @{ Tool = 'PowerShell'; Command = 'Write-Output $env:GIT_AUTHOR_NAME' }
    @{ Tool = 'PowerShell'; Command = 'Get-Item env:USERPROFILE' }
    @{ Tool = 'PowerShell'; Command = '[Environment]::GetEnvironmentVariable(''HOME'')' }
    @{ Tool = 'PowerShell'; Command = '$files = 1; $files' }
    @{ Tool = 'Both'; Command = 'cat ~/x' }
    @{ Tool = 'Both'; Command = 'git show HEAD~1' }
    @{ Tool = 'Both'; Command = 'git log HEAD~3 --oneline' }
    @{ Tool = 'Both'; Command = 'git show HEAD~1:README.md' }
    @{ Tool = 'Both'; Command = 'git diff HEAD~1 -- docs/x.md' }
    @{ Tool = 'Both'; Command = 'cat docs/a~b.md' }
    @{ Tool = 'Both'; Command = 'git show HEAD:.env.example' }
    @{ Tool = 'Both'; Command = 'git show HEAD:README.md' }
    @{ Tool = 'Both'; Command = 'aws batch describe-job-queues --job-queues q' }
    @{ Tool = 'Both'; Command = 'aws elasticbeanstalk describe-environments --environment-names e' }
    @{ Tool = 'Both'; Command = 'aws elasticbeanstalk describe-applications --application-names a' }
    @{ Tool = 'Both'; Command = 'aws apprunner list-services' }
    @{ Tool = 'Both'; Command = 'aws apprunner list-operations --service-arn arn:aws:apprunner:us-east-1:123456789012:service/s/1' }
    @{ Tool = 'Both'; Command = 'aws glacier get-job-output --account-id - --vault-name v --job-id j' }
    # Review round
    @{ Tool = 'PowerShell'; Command = 'Get-Item Microsoft.PowerShell.Core\\Environment::PATH' }
    @{ Tool = 'PowerShell'; Command = 'Get-Item Environment::\\PATH' }
    @{ Tool = 'Both'; Command = 'git log HEAD~1 --oneline' }
    @{ Tool = 'Both'; Command = 'git log main~2 --oneline' }
    @{ Tool = 'Both'; Command = 'git show HEAD~10' }
    @{ Tool = 'Both'; Command = 'cat ID_ED2~1.PUB' }
    # Review round
    @{ Tool = 'PowerShell'; Command = 'Get-Item env:PATH' }
    @{ Tool = 'PowerShell'; Command = 'Get-Item env:\PATH' }
    @{ Tool = 'PowerShell'; Command = 'Get-Item Environment::PATH' }
    @{ Tool = 'PowerShell'; Command = 'Get-Item Microsoft.PowerShell.Core\Environment::PATH' }
    @{ Tool = 'PowerShell'; Command = 'Write-Output $env:PATH' }
    @{ Tool = 'PowerShell'; Command = 'Write-Output ${env:PATH}' }
    @{ Tool = 'PowerShell'; Command = '[Environment]::GetEnvironmentVariable(''PATH'')' }
    @{ Tool = 'Both'; Command = 'rg ''std::string'' docs' }
    @{ Tool = 'Both'; Command = 'cat docs/notes.md' }
    @{ Tool = 'Both'; Command = 'git show HEAD:README.md' }
    @{ Tool = 'Both'; Command = 'aws s3 ls s3://bucket' }
    # Review round
    @{ Tool = 'PowerShell'; Command = '[regex]::Replace($s, ''a'', ''b'')' }
    @{ Tool = 'PowerShell'; Command = '[regex]::Split($s, '','')' }
    @{ Tool = 'Both'; Command = 'cat local.settings.sample.json' }
    @{ Tool = 'Both'; Command = 'cat docs/local.settings.md' }
    @{ Tool = 'Both'; Command = 'cat .env.exam*' }
    @{ Tool = 'Both'; Command = 'cat docs/*.md' }
    @{ Tool = 'Both'; Command = 'jq .name package.json' }
    @{ Tool = 'Both'; Command = 'jq ''.env'' x.json' }
    @{ Tool = 'Both'; Command = 'jq -r ''.items[] | .env'' x.json' }
    @{ Tool = 'Both'; Command = 'jq --arg a b ''.x'' f.json' }
    @{ Tool = 'Both'; Command = 'jq -n ''1+1''' }
    @{ Tool = 'Both'; Command = 'jq . file.json' }
    @{ Tool = 'Both'; Command = 'jq ''.[0].name'' x.json' }
    @{ Tool = 'Both'; Command = 'jq ''.items[0].env'' x.json' }
    @{ Tool = 'Bash'; Command = 'sort /tmp/x README.md' }
    @{ Tool = 'Both'; Command = 'aws ec2 describe-instance-attribute --instance-id i --attribute instanceType' }
    @{ Tool = 'Both'; Command = 'aws glue get-databases' }
    @{ Tool = 'Both'; Command = 'aws batch describe-job-queues --job-queues q' }
    @{ Tool = 'Bash'; Command = 'grep -rn ''env:'' docs' }
    @{ Tool = 'Bash'; Command = 'rg ''env:'' docs' }
    @{ Tool = 'Both'; Command = 'git grep -n ''env:''' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Pattern ''env:'' README.md' }
    @{ Tool = 'PowerShell'; Command = 'Select-String ''env:'' README.md' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Path README.md -Pattern "env:"' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem src/*.ps1' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Recurse -Filter *.ps1 guards' }
    # Review round
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem src/*' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem *' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem *.json' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem docs/*.json' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Recurse -Filter *.json' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem ~ -Filter credentials -Recurse' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Filter .env*' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Include *.env' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Path ~ -Recurse -Filter id_*' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem credentials' }
    @{ Tool = 'Both'; Command = 'rg -n x guards/*' }
    @{ Tool = 'Bash'; Command = 'cat x ~/y/*' }
    @{ Tool = 'Both'; Command = 'git branch --list ''feat/*''' }
    @{ Tool = 'Both'; Command = 'git tag --list ''v1*''' }
    @{ Tool = 'Both'; Command = 'find . -not -path "./.git/*"' }
    @{ Tool = 'Both'; Command = 'find . -name ''*.json''' }
    @{ Tool = 'Both'; Command = 'find . -iname ''credentials*'' -type f' }
    @{ Tool = 'Both'; Command = 'git ls-files ''*.json''' }
    @{ Tool = 'Bash'; Command = 'ls docs/*.json' }
    @{ Tool = 'Bash'; Command = 'ls credentials' }
    @{ Tool = 'Bash'; Command = 'jq ''import "lib" as l; .'' x.json' }
    @{ Tool = 'Bash'; Command = 'jq ''include "helpers"; .'' x.json' }
    @{ Tool = 'Both'; Command = 'cat docs/credentials.md' }
    @{ Tool = 'PowerShell'; Command = 'Get-Content src/*.md' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Path docs/*.md -Pattern x' }
    # Review round
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem docs -Filter *.md | Select-String -Pattern x' }
    @{ Tool = 'PowerShell'; Command = 'Get-Item README.md | Get-Content' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem docs | Get-Content' }
    @{ Tool = 'PowerShell'; Command = 'foreach ($f in Get-ChildItem src -Filter *.ps1) { Get-Content $f.FullName }' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Recurse | Select-String x' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Filter .env* | Select-Object Name' }
    @{ Tool = 'Both'; Command = 'rg ''.env'' src' }
    @{ Tool = 'Both'; Command = 'rg -e .env src' }
    @{ Tool = 'Both'; Command = 'git grep ''.env'' -- src' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Pattern ''.env'' -Path src' }
    @{ Tool = 'Both'; Command = 'grep -rn ''local.settings.json'' docs' }
    @{ Tool = 'PowerShell'; Command = 'Select-String -Pattern ''~/.ssh/id_rsa'' -Path docs/x.md' }
    @{ Tool = 'Bash'; Command = 'rg ''~/.ssh/id_rsa'' src' }
    @{ Tool = 'Both'; Command = 'rg -f package.json docs' }
    @{ Tool = 'Both'; Command = 'grep -f patterns.txt docs' }
    # Review round
    @{ Tool = 'Both'; Command = 'grep --color KEY docs/x.md' }
    @{ Tool = 'Both'; Command = 'rg --color never KEY docs' }
    @{ Tool = 'Both'; Command = 'grep -- -e docs/x.md' }
    @{ Tool = 'Bash'; Command = 'grep -ffile.txt docs' }
    @{ Tool = 'PowerShell'; Command = 'Get-ChildItem docs -Filter *.md | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }' }
)
