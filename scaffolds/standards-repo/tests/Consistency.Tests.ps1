# Accepted standards and drafts stay separate, every standard cites its sources, and the pack validates.

BeforeAll {
    $script:Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
}

Describe 'Standards repository' {
    It '<_.Name> is accepted and cites its sources' -ForEach @(Get-ChildItem (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) 'standards') -Filter '*.md' | Where-Object Name -NE 'README.md') {
        $text = Get-Content $_.FullName -Raw
        $text | Should -Match '\*\*Status:\*\* Accepted'
        $text | Should -Match '(?m)^## Sources'
    }

    It 'keeps drafts as drafts, with sources' {
        foreach ($draft in Get-ChildItem (Join-Path $Repo 'drafts') -Filter '*.md' | Where-Object Name -NE 'README.md') {
            $text = Get-Content $draft.FullName -Raw
            $text | Should -Match '\*\*Status:\*\* Draft' -Because $draft.Name
            $text | Should -Match '(?m)^## Sources' -Because $draft.Name
        }
    }

    It 'has a valid Guild pack that never loads drafts' {
        $guild = if ($env:GUILD_ROOT) { $env:GUILD_ROOT } else { Join-Path $Repo '../guild' }
        $manifest = Join-Path $guild 'Guild/Guild.psd1'
        if (-not (Test-Path $manifest)) { Set-ItResult -Inconclusive -Because 'Guild is not available; set GUILD_ROOT'; return }
        Import-Module $manifest -Force
        $pack = Get-GuildPack -Pack (Get-ChildItem (Join-Path $Repo 'guild') -Filter '*.pack.psd1' | Select-Object -First 1).FullName
        @($pack.Knowledge | Where-Object { $_.Path -match '/drafts' }) | Should -BeNullOrEmpty
    }
}
