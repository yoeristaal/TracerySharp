# Compile the package, including its inspectors, with minimal Unity API stubs.
# These checks exercise asset behavior; they do not simulate Unity serialization or GUI rendering.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('TraceryAssetValidation-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    $stubPath = Join-Path $scratch 'UnityStubs.cs'
    @'
using System;
namespace UnityEngine
{
    public class Object { }
    public class TextAsset : Object { public string text; }
    public class ScriptableObject : Object
    {
        public static T CreateInstance<T>() where T : ScriptableObject, new() { return new T(); }
    }
    public class MonoBehaviour : Object { }
    public class CreateAssetMenuAttribute : Attribute { public string fileName; public string menuName; }
    public class GUIContent { public GUIContent(string text) { } }
    public class GUIStyle { }
    public class GUILayoutOption { }
    public static class GUILayout
    {
        public static int Toolbar(int selected, string[] labels) { return selected; }
        public static void Space(float value) { }
        public static void BeginHorizontal() { }
        public static void EndHorizontal() { }
        public static GUILayoutOption Width(float value) { return null; }
        public static GUILayoutOption MinHeight(float value) { return null; }
        public static bool Button(string text, params GUILayoutOption[] options) { return false; }
        public static bool Button(string text, GUIStyle style, params GUILayoutOption[] options) { return false; }
        public static string TextField(string value, params GUILayoutOption[] options) { return value; }
        public static string TextArea(string value, params GUILayoutOption[] options) { return value; }
        public static void Label(string text) { }
        public static void Label(string text, GUIStyle style) { }
    }
    public static class Debug { public static void LogException(Exception cause) { } }
}
namespace UnityEditor
{
    using UnityEngine;
    public class CustomEditor : Attribute { public CustomEditor(Type type) { } }
    public class Editor
    {
        public Object target;
        public SerializedObject serializedObject = new SerializedObject();
        public virtual void OnInspectorGUI() { }
        public void Repaint() { }
    }
    public class SerializedObject
    {
        public void Update() { }
        public bool ApplyModifiedProperties() { return false; }
        public SerializedProperty FindProperty(string name) { return new SerializedProperty(); }
    }
    public class SerializedProperty
    {
        public int arraySize;
        public string stringValue;
        public SerializedProperty GetArrayElementAtIndex(int index) { return new SerializedProperty(); }
        public SerializedProperty FindPropertyRelative(string name) { return new SerializedProperty(); }
        public void DeleteArrayElementAtIndex(int index) { }
        public void InsertArrayElementAtIndex(int index) { }
        public void ClearArray() { }
    }
    public enum MessageType { Info, Error }
    public static class EditorStyles
    {
        public static GUIStyle boldLabel = new GUIStyle(), miniButton = new GUIStyle(), miniLabel = new GUIStyle();
    }
    public static class EditorGUILayout
    {
        public static void PropertyField(SerializedProperty property, GUIContent label) { }
        public static void LabelField(string text) { }
        public static void LabelField(string text, GUIStyle style) { }
        public static void HelpBox(string text, MessageType type) { }
        public static void BeginVertical(string style) { }
        public static void EndVertical() { }
        public static void BeginHorizontal() { }
        public static void EndHorizontal() { }
        public static void Space() { }
        public static string TextField(string label, string value) { return value; }
        public static string TextArea(string text, params GUILayoutOption[] options) { return text; }
        public static void SelectableLabel(string text, GUIStyle style) { }
    }
    public static class EditorGUI
    {
        public static void BeginChangeCheck() { }
        public static bool EndChangeCheck() { return false; }
        public sealed class DisabledGroupScope : IDisposable
        {
            public DisabledGroupScope(bool disabled) { }
            public void Dispose() { }
        }
    }
    public static class Undo { public static event Action undoRedoPerformed { add { } remove { } } }
}
'@ | Set-Content -LiteralPath $stubPath
    $probePath = Join-Path $scratch 'AssetChecks.cs'
    @'
using System;
using Tracery;
using UnityEngine;

public static class AssetChecks
{
    static int checks;
    static void Check(bool condition, string name)
    {
        if (!condition) throw new Exception("Failed: " + name);
        checks++;
    }
    static TraceryGrammarAsset Asset(params TraceryGrammarAsset.Symbol[] symbols)
    {
        var asset = ScriptableObject.CreateInstance<TraceryGrammarAsset>();
        asset.symbols = symbols;
        return asset;
    }
    static TraceryGrammarAsset.Symbol Symbol(string key, params string[] rules)
    {
        return new TraceryGrammarAsset.Symbol { key = key, rules = rules };
    }
    static void Fails(Action action, string message, string name)
    {
        bool failed = false;
        try { action(); } catch (Exception cause) { failed = cause.Message.Contains(message); }
        Check(failed, name);
    }
    public static int Run()
    {
        var defaultAsset = ScriptableObject.CreateInstance<TraceryGrammarAsset>();
        Check(defaultAsset.Validate().Count == 0 && defaultAsset.Preview() == "Hello, world!", "usable defaults");
        var asset = Asset(Symbol("origin", "Hello #name#!"), Symbol("name", "Max"));
        Check(asset.Validate().Count == 0 && asset.Preview() == "Hello Max!", "valid definitions and preview");
        Check(asset.Preview("#name#") == "Max", "custom preview rule");
        var first = asset.CreateGrammar();
        var second = asset.CreateGrammar();
        first.PushRules("name", new[] { "Alice" });
        Check(first.Flatten("#origin#") == "Hello Alice!" && second.Flatten("#origin#") == "Hello Max!", "independent runtime stacks");
        Check(asset.symbols[1].rules[0] == "Max" && asset.Preview() == "Hello Max!", "generation preserves asset definitions");
        var rng = new Random(42);
        Tracery.Tracery.Rng = rng;
        asset.Preview();
        Check(System.Object.ReferenceEquals(rng, Tracery.Tracery.Rng) && rng.Next() == new Random(42).Next(), "preview preserves random generator and state");
        Fails(() => asset.Preview("#missing#"), "missing", "preview reports missing entry symbol");
        Check(System.Object.ReferenceEquals(rng, Tracery.Tracery.Rng), "random generator restored after preview failure");
        var recursive = Asset(Symbol("origin", "#origin#"));
        Fails(() => recursive.Preview(), "expansion limit", "recursive preview is bounded");
        Check(System.Object.ReferenceEquals(rng, Tracery.Tracery.Rng), "random generator restored after recursion failure");
        Fails(() => asset.Preview(new string('a', 16385)), "character limit", "preview root output is bounded");
        Fails(() => Asset(Symbol("origin", new string('a', 16385))).Preview(), "character limit", "preview symbol output is bounded");
        var many = Asset(Symbol("origin", string.Concat(System.Linq.Enumerable.Repeat("#name#", 2049))), Symbol("name", "x"));
        Fails(() => many.Preview(), "expansion limit", "preview total expansion count is bounded");
        var duplicates = Asset(Symbol("origin", "a"), Symbol("origin", "b"));
        Check(duplicates.Validate().Count == 1 && duplicates.Validate()[0].Message.Contains("Duplicate"), "duplicate names reported");
        Fails(() => duplicates.CreateGrammar(), "Duplicate", "duplicate names rejected during creation");
        Check(Asset(Symbol("origin", "#missing#")).Validate().Count == 1, "missing references validated");
        var external = Asset(Symbol("origin", "#external#")).CreateGrammar();
        external.PushRules("external", new[] { "supplied by game" });
        Check(external.Flatten("#origin#") == "supplied by game", "game can supply runtime symbols");
        Check(Asset(Symbol("origin", "#unfinished")).Validate().Count == 1, "malformed syntax validated");
        Fails(() => Asset(Symbol("origin", "#unfinished")).CreateGrammar(), "Symbol 'origin' rule 0", "syntax creation errors identify owning rule");
        Check(Asset(Symbol("origin")).Validate().Count == 1, "empty rules validated");
        Fails(() => Asset(Symbol("origin")).CreateGrammar(), "no rules", "empty rules rejected during creation");
        Check(Asset(Symbol("origin", "")).Preview() == "", "empty-string alternative is valid");
        Check(Asset().Validate().Count == 1, "empty asset validated");
        Check(Asset((TraceryGrammarAsset.Symbol[])null).Validate().Count == 1, "null symbol array validated");
        Check(Asset((TraceryGrammarAsset.Symbol)null).Validate().Count == 1, "null symbol entry validated");
        Check(Asset(Symbol(" ", "text")).Validate().Count == 1, "blank name validated");
        Check(Asset(Symbol("origin", (string[])null)).Validate().Count == 1, "null alternatives validated");
        Check(Asset(Symbol("origin", (string)null)).Validate().Count == 1, "null rule validated once");
        Fails(() => Asset(Symbol("origin", (string)null)).CreateGrammar(), "Symbol 'origin' rule 0", "null rule creation error has context");
        var component = new TraceryGrammar();
        component.grammarAsset = asset;
        Check(component.Grammar.Flatten("#origin#") == "Hello Max!", "component uses assigned asset");
        component.grammarAsset = null;
        component.symbols = new[] { new TraceryGrammar.Symbol { key = "origin", rules = "inline" } };
        Check(component.Grammar.Flatten("#origin#") == "inline", "component preserves inline fallback");
        return checks;
    }
}
'@ | Set-Content -LiteralPath $probePath
    $sources = Get-ChildItem (Join-Path $repo 'Source') -Recurse -Filter *.cs | ForEach-Object { $_.FullName }
    Add-Type -Path (@($sources) + @($stubPath, $probePath))
    Write-Output "Passed $([AssetChecks]::Run()) grammar asset checks; all package scripts compiled with Unity API stubs."
}
finally {
    if ((Split-Path $scratch -Parent) -eq [System.IO.Path]::GetTempPath().TrimEnd('\', '/')) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
