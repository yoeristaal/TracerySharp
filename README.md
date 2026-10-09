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

#### Method 2: Load from JSON

Add the JSON file containing your serialized grammar to the `Assets/Resources` directory within your Unity project. Then you can access it in your scripts as follows:

```C#
TextAsset jsonFile = Resources.Load("grammar") as TextAsset; // assuming the file is at Assets/Resources/grammar.json
Grammar grammar = Grammar.LoadFromJSON(jsonFile);
```

You can also use `Grammar.LoadFromJSON(string jsonString)` to load a grammar directly from a JSON string.

#### Method 3: Write a script

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

### Make TracerySharp deterministic

[Much like Tracery itself](https://github.com/galaxykate/tracery/tree/tracery2#making-tracery-deterministic), you can make TracerySharp deterministic by setting `Tracery.Rng` to an instance of `System.Random` [constructed with a specified seed](https://msdn.microsoft.com/en-us/library/ctssatww(v=vs.110).aspx):

```C#
Tracery.Rng = new System.Random(42); // replace 42 with whatever seed you want
```

## Credits

[Tracery](http://tracery.io/) was originally designed and developed by [Kate Compton](http://www.galaxykate.com/).

[Max Kreminski](http://mkremins.github.io/) ported it to C# for use with Unity.

JSON parsing is done with [SimpleJSON](http://wiki.unity3d.com/index.php/SimpleJSON). SimpleJSON was originally developed by Bunny83 and later modified by oPless.
