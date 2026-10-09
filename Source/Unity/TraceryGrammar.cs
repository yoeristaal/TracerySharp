using UnityEngine;
using Tracery;

[System.Serializable]
public class TraceryGrammar : MonoBehaviour
{
	public TraceryGrammarAsset grammarAsset;
	public Symbol[] symbols = new Symbol[0];

	public Grammar Grammar
	{
		get
		{
			if (grammarAsset != null) return grammarAsset.CreateGrammar();
			Grammar grammar = new Grammar();
			foreach (Symbol s in symbols)
			{
				grammar.PushRules(s.key, s.rules.Split('\n'));
			}
			return grammar;
		}
	}

	[System.Serializable]
	public class Symbol
	{
		public string key;
		public string rules;
	}
}
