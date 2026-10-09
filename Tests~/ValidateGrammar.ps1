# Run from any directory with PowerShell 7: pwsh -File Tests~/ValidateGrammar.ps1
# Unity ignores folders ending in ~, so this harness is not imported into games.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('TraceryValidation-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    # The core only needs TextAsset; compile against a stub to run without Unity.
    $stubPath = Join-Path $scratch 'UnityStub.cs'
    Set-Content -LiteralPath $stubPath -Value 'namespace UnityEngine { public class TextAsset { public string text; } }'
    $sources = Get-ChildItem (Join-Path $repo 'Source') -Recurse -Filter *.cs |
        Where-Object { $_.FullName -notmatch '[\\/]Unity[\\/]' } |
        ForEach-Object { $_.FullName }
    $probePath = Join-Path $scratch 'ValidationChecks.cs'
    @'
using System;
using System.Collections.Generic;
using Tracery;

public static class ValidationChecks
{
    static int checks;
    static void Check(bool condition, string name)
    {
        if (!condition) throw new Exception("Failed: " + name);
        checks++;
    }
    static Dictionary<string, string[]> Rules(params string[] origin)
    {
        return new Dictionary<string, string[]> { { "origin", origin } };
    }
    public static int Run()
    {
        var valid = Rules("Hello #name.capitalize#!", "");
        valid.Add("name", new[] { "Max" });
        Check(Grammar.ValidateRules(valid).Count == 0, "valid grammar and empty-string rule");
        var errors = Grammar.ValidateRules(Rules("#missing# and #other#"));
        Check(errors.Count == 2 && errors[0].Symbol == "origin" && errors[0].RuleIndex == 0 &&
            errors[0].Rule == "#missing# and #other#" && errors[0].Message.Contains("missing"), "missing symbols and error context");
        Check(Grammar.ValidateRules(Rules()).Count == 1, "empty rule list");
        Check(Grammar.ValidateRules(new Dictionary<string, string[]> { { "origin", null } }).Count == 1, "null rule list");
        Check(Grammar.ValidateRules(Rules((string)null)).Count == 1, "null rule");
        foreach (var raw in new[] { "#", "#unfinished", "##", "#.s#", "#name.#", "[name", "[name]", "[:value]", "#[name:Max]" })
            Check(Grammar.ValidateRules(Rules(raw)).Count == 1, "malformed rule: " + raw);
        Check(Grammar.ValidateRules(Rules(@"\#literal\# \[literal]")).Count == 0, "escaped syntax");
        Check(Grammar.ValidateRules(Rules("[name:Max]#name#[name:POP]")).Count == 0, "push and POP");
        Check(Grammar.ValidateRules(Rules("#[name:Max]name#")).Count == 0, "tag pre-action");
        Check(Grammar.ValidateRules(Rules("#[name:Max]name# #name#")).Count == 1, "temporary symbol scope");
        Check(Grammar.ValidateRules(Rules("[name:#missing#]#name#")).Count == 1, "missing reference in action value");
        Check(Grammar.ValidateRules(Rules("[name:#name#]#name#")).Count == 1, "action values expanded before push");
        Check(Grammar.ValidateRules(Rules("[name:POP]")).Count == 1, "POP missing symbol");
        var emptyTarget = Rules("#name#");
        emptyTarget.Add("name", new string[0]);
        Check(Grammar.ValidateRules(emptyTarget).Count == 2, "empty referenced symbol");
        var grammar = Grammar.LoadFromJSON("{\"origin\":[\"Hello #name#!\"],\"name\":[\"Max\"]}");
        Check(grammar.Validate().Count == 0 && grammar.Flatten("#origin#") == "Hello Max!", "JSON loading and generation");
        grammar.PushRules("origin", new[] { "[name:POP]#name#" });
        grammar.PushRules("name", new[] { "extra" });
        Check(grammar.Validate().Count == 0, "POP exposes existing lower stack layer");
        Check(grammar.Flatten("#name#") == "extra", "validation does not mutate grammar");
        grammar.PopRules("origin");
        grammar.PushRules("literal", new TraceryNode[] { new PlaintextNode("#not-a-tag#", "#not-a-tag#") });
        Check(grammar.Validate().Count == 0, "plaintext nodes are not reparsed");
        Tracery.Tracery.Rng = new Random(42);
        grammar.Validate();
        Check(Tracery.Tracery.Rng.Next() == new Random(42).Next(), "validation does not consume randomness");
        grammar.PushRules("empty", new string[0]);
        Check(grammar.Validate().Count == 1, "instance validates empty lists");
        grammar.PopRules("empty");
        Check(grammar.Validate().Count == 1, "instance validates exhausted stacks");
        bool rejected = false;
        try { Grammar.ValidateRules(null); } catch (ArgumentNullException) { rejected = true; }
        Check(rejected, "null dictionary rejected");
        bool format = false;
        try { grammar.PushRules("bad", new[] { "##" }); } catch (FormatException) { format = true; }
        Check(format, "normal loading reports malformed tags");
        return checks;
    }
}
'@ | Set-Content -LiteralPath $probePath
    Add-Type -Path (@($sources) + @($stubPath, $probePath))
    Write-Output "Passed $([ValidationChecks]::Run()) grammar validation checks."
}
finally {
    # Only remove the uniquely named temporary directory created above.
    if ((Split-Path $scratch -Parent) -eq [System.IO.Path]::GetTempPath().TrimEnd('\', '/')) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
