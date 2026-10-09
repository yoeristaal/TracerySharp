using System;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(TraceryGrammarAsset))]
public sealed class TraceryGrammarAssetEditor : Editor
{
	private SerializedProperty symbols;
	private string previewRule = "#origin#";
	private string previewText;
	private string previewError;

	private void OnEnable()
	{
		symbols = serializedObject.FindProperty("symbols");
		Undo.undoRedoPerformed += ClearPreview;
	}

	private void OnDisable()
	{
		Undo.undoRedoPerformed -= ClearPreview;
	}

	public override void OnInspectorGUI()
	{
		serializedObject.Update();
		EditorGUILayout.LabelField("Grammar symbols", EditorStyles.boldLabel);
		EditorGUILayout.HelpBox("Each symbol has a name and a list of alternative rules. Tags such as #name# reference other symbols.", MessageType.Info);
		for (int i = 0; i < symbols.arraySize; i++)
		{
			var symbol = symbols.GetArrayElementAtIndex(i);
			EditorGUILayout.BeginVertical("box");
			EditorGUILayout.BeginHorizontal();
			EditorGUILayout.PropertyField(symbol.FindPropertyRelative("key"), new GUIContent("Symbol"));
			bool remove = GUILayout.Button("Remove", GUILayout.Width(65));
			EditorGUILayout.EndHorizontal();
			if (remove)
			{
				symbols.DeleteArrayElementAtIndex(i);
				EditorGUILayout.EndVertical();
				break;
			}
			DrawRules(symbol.FindPropertyRelative("rules"));
			EditorGUILayout.EndVertical();
		}
		if (GUILayout.Button("Add Symbol"))
		{
			symbols.InsertArrayElementAtIndex(symbols.arraySize);
			var symbol = symbols.GetArrayElementAtIndex(symbols.arraySize - 1);
			symbol.FindPropertyRelative("key").stringValue = "";
			var rules = symbol.FindPropertyRelative("rules");
			rules.arraySize = 1;
			rules.GetArrayElementAtIndex(0).stringValue = "";
		}
		if (serializedObject.ApplyModifiedProperties()) ClearPreview();

		var asset = (TraceryGrammarAsset)target;
		EditorGUILayout.Space();
		EditorGUILayout.LabelField("Validation", EditorStyles.boldLabel);
		var errors = asset.Validate();
		if (errors.Count == 0) EditorGUILayout.HelpBox("No validation errors found.", MessageType.Info);
		foreach (var error in errors) EditorGUILayout.HelpBox(error.ToString(), MessageType.Error);

		EditorGUILayout.Space();
		EditorGUILayout.LabelField("Preview", EditorStyles.boldLabel);
		EditorGUI.BeginChangeCheck();
		previewRule = EditorGUILayout.TextField("Start rule", previewRule);
		if (EditorGUI.EndChangeCheck()) ClearPreview();
		using (new EditorGUI.DisabledGroupScope(errors.Count > 0))
		{
			if (GUILayout.Button("Generate Preview"))
			{
				ClearPreview();
				try { previewText = asset.Preview(previewRule); }
				catch (Exception cause) { previewError = cause.Message; }
			}
		}
		if (previewError != null) EditorGUILayout.HelpBox(previewError, MessageType.Error);
		if (previewText != null)
			EditorGUILayout.TextArea(previewText, GUILayout.MinHeight(60));
	}

	private static void DrawRules(SerializedProperty rules)
	{
		EditorGUILayout.LabelField("Alternative rules");
		for (int i = 0; i < rules.arraySize; i++)
		{
			EditorGUILayout.BeginHorizontal();
			var rule = rules.GetArrayElementAtIndex(i);
			rule.stringValue = EditorGUILayout.TextArea(rule.stringValue, GUILayout.MinHeight(35));
			bool remove = GUILayout.Button("Remove", GUILayout.Width(65));
			EditorGUILayout.EndHorizontal();
			if (remove)
			{
				rules.DeleteArrayElementAtIndex(i);
				break;
			}
		}
		if (GUILayout.Button("Add Alternative"))
		{
			rules.InsertArrayElementAtIndex(rules.arraySize);
			rules.GetArrayElementAtIndex(rules.arraySize - 1).stringValue = "";
		}
	}

	private void ClearPreview()
	{
		previewText = null;
		previewError = null;
		Repaint();
	}
}
