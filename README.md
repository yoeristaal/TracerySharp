# TracerySharp

A (heavily WIP) C# port of [Tracery](http://tracery.io/), a text generation library/language/tool originally designed by [Kate Compton](http://www.galaxykate.com/). Primarily intended to be used within [Unity](https://unity3d.com/) games.

## Installation

TracerySharp is still a work in progress.

In Unity, open **Window > Package Manager**, choose **Add package from git URL** from the **+** menu, and enter:

```text
https://github.com/yoeristaal/TracerySharp.git
```

The repository root contains the Unity package manifest (`package.json`), so no `?path=` suffix is needed. The manifest and assembly definitions must be committed and pushed to GitHub before installation from this URL will work.

To use a local checkout, choose **Add package from disk** and select its root `package.json`.

Keep each asset's `.meta` file in version control, including metadata for folders, scripts, assembly definitions, and the package manifest. Git packages are immutable in Unity's cache, so missing metadata causes assets to be ignored. Preserve existing metadata when editing assets and move the matching `.meta` file when moving an asset.

If your own scripts use an assembly definition, add `TracerySharp` to its Assembly Definition References. Scripts in Unity's default assemblies can use the package automatically.

Alternatively, download the `Source` directory and place it in your project's `Assets` folder. Use only one installation method to avoid duplicate classes.

## Usage

### Create a `Grammar`

No matter what you're trying to do, the first step will almost always be to get your hands on a `Grammar` object. There are a few different ways to do this.

#### Method 1: Use the GUI editor

In the Unity editor, select a game object to which you'd like to attach a grammar. Then, in the inspector, click `Add Component > Scripts > Tracery Grammar`. A GUI editor for the grammar will appear. Here, you can add and remove rules, edit existing rules, and test the grammar by viewing examples of generated strings.

Once you're satisfied with your grammar, you can access it in your scripts as follows:

```C#
GameObject go = GameObject.Find("foo"); // the GameObject to which you attached the TraceryGrammar script
Grammar grammar = go.GetComponent<TraceryGrammar>().Grammar;
```

#### Method 2: Use a shared grammar asset

Choose **Assets > Create > Tracery > Grammar** to create a `TraceryGrammarAsset`. In its Inspector, add symbols and alternative rules. Validation errors appear as you edit. Set the preview's start rule (default `#origin#`) and click **Generate Preview** to generate text.

Assign the asset to the **Grammar Asset** field on a `TraceryGrammar` component, or reference it directly from your own scripts:

```C#
using Tracery;
using UnityEngine;

public class DialogueGenerator : MonoBehaviour
{
    [SerializeField] private TraceryGrammarAsset grammarAsset;
    private Grammar grammar;

    private void Awake()
    {
        grammar = grammarAsset.CreateGrammar();
    }

    public string Generate()
    {
        return grammar.Flatten("#origin#");
    }
}
```

The same asset can be assigned in multiple scenes and prefabs. `CreateGrammar()` makes a fresh grammar each time: pushes, pops, and custom modifiers affect that instance, while the asset stays unchanged. Cache the returned grammar when you want to retain runtime changes. A component's `Grammar` property also returns a fresh instance on each access. When its asset field is empty, the component continues to use its inline rules.

`grammarAsset.Validate()` checks the definitions before parsing, including duplicate names, missing symbols, empty lists, and malformed tags. `CreateGrammar()` rejects invalid serialized entries and malformed syntax, but allows unresolved symbol references so your game can supply them after creation. The Inspector preview requires validation to pass, uses a fresh grammar, preserves the game's global random sequence, and limits preview depth, expansion count, and output length. These limits apply only to previews; normal runtime generation retains its existing behavior.

#### Method 3: Load from JSON

Add the JSON file containing your serialized grammar to the `Assets/Resources` directory within your Unity project. Then you can access it in your scripts as follows:

```C#
TextAsset jsonFile = Resources.Load("grammar") as TextAsset; // assuming the file is at Assets/Resources/grammar.json
Grammar grammar = Grammar.LoadFromJSON(jsonFile);
```

You can also use `Grammar.LoadFromJSON(string jsonString)` to load a grammar directly from a JSON string.

#### Method 4: Write a script

In a C# script, you can create a `Grammar` object directly using the public constructor. Then you can programmatically populate it with rules using the `PushRules` method:

```C#
Grammar grammar = new Grammar();
grammar.PushRules("origin", new string[]{"Hello, #name#!"});
grammar.PushRules("name", new string[]{"Max", "world"});
```

...but note that this approach can get unwieldy pretty quickly, especially for more complicated grammars.

### Generate strings

Once you've acquired a `Grammar` object, you can use the `Flatten` method to generate a fully expanded string from an initial base string. For example:

```C#
string expanded = grammar.Flatten("#origin#"); // assuming the grammar has a rule named 'origin'
```

TracerySharp is still incomplete, but you should be able to use most of the basic syntax described in the [Tracery tutorial](http://www.crystalcodepalace.com/traceryTut.html).

### Validate a grammar

Call `Validate()` before generating text to check every active rule for missing symbols and empty rule lists:

```C#
foreach (var error in grammar.Validate())
{
    Debug.LogError(error.ToString());
}
```

To check malformed syntax before loading rules, use `Grammar.ValidateRules`:

```C#
var rules = new Dictionary<string, string[]>
{
    { "origin", new[] { "Hello, #name#!", "#unfinished" } }
};

var errors = Grammar.ValidateRules(rules);
if (errors.Count == 0)
{
    var grammar = new Grammar();
    foreach (var pair in rules) grammar.PushRules(pair.Key, pair.Value);
}
else
{
    foreach (var error in errors) Debug.LogError(error.ToString());
}
```

Use `using Tracery;` and `using System.Collections.Generic;` for these examples. Each error exposes `Symbol`, `RuleIndex` (zero-based, or `-1` for a rule-list error), `Rule`, and `Message`. Validation returns all errors it finds without expanding text, consuming randomness, or changing the grammar. An empty string is a valid rule; an empty array is not.

Validation understands escapes and push/POP actions within each rule, including temporary tag pre-actions. It checks each rule against the current grammar independently; symbols supplied only by a caller's actions in another rule may be reported as missing. It does not detect recursion or execute custom nodes and modifiers. Syntax errors during normal loading now throw `FormatException` with the offending rule or tag.

### Make TracerySharp deterministic

[Much like Tracery itself](https://github.com/galaxykate/tracery/tree/tracery2#making-tracery-deterministic), you can make TracerySharp deterministic by setting `Tracery.Rng` to an instance of `System.Random` [constructed with a specified seed](https://msdn.microsoft.com/en-us/library/ctssatww(v=vs.110).aspx):

```C#
Tracery.Rng = new System.Random(42); // replace 42 with whatever seed you want
```

## Development checks

Run `pwsh -File Tests~/ValidateGrammar.ps1` to compile the core and run validation regression checks without Unity. The harness substitutes only `UnityEngine.TextAsset`; it does not verify Unity Editor imports or the custom inspector. The `Tests~` folder is excluded from Unity asset imports.

Run `pwsh -File Tests~/ValidateGrammarAsset.ps1` for grammar asset checks, including independent runtime state, asset validation, component integration, and preview limits. It also compiles all package scripts against minimal Unity API stubs. Confirm asset creation, Inspector editing, undo/redo, and persistence in the Unity Editor separately.

## Credits

[Tracery](http://tracery.io/) was originally designed and developed by [Kate Compton](http://www.galaxykate.com/).

[Max Kreminski](http://mkremins.github.io/) ported it to C# for use with Unity.

JSON parsing is done with [SimpleJSON](http://wiki.unity3d.com/index.php/SimpleJSON). SimpleJSON was originally developed by Bunny83 and later modified by oPless.
