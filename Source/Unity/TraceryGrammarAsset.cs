using System;
using System.Collections.Generic;
using System.Linq;
using Tracery;
using UnityEngine;

/// <summary>Reusable grammar definitions. Each CreateGrammar call creates independent runtime state.</summary>
[CreateAssetMenu(fileName = "TraceryGrammar", menuName = "Tracery/Grammar")]
public sealed class TraceryGrammarAsset : ScriptableObject
{
	public Symbol[] symbols = { new Symbol { key = "origin", rules = new[] { "Hello, world!" } } };

	[Serializable]
	public sealed class Symbol
	{
		public string key;
		public string[] rules;
	}

	/// <summary>Checks serialized definitions, including duplicate names and malformed rules.</summary>
	public IReadOnlyList<GrammarValidationError> Validate()
	{
		var errors = new List<GrammarValidationError>();
		var definitions = GetDefinitions(errors);
		errors.AddRange(Grammar.ValidateRules(definitions));
		return errors.AsReadOnly();
	}

	/// <summary>Creates a fresh grammar. Add game-specific rules and modifiers to the returned instance.</summary>
	public Grammar CreateGrammar()
	{
		return CreateGrammar(null);
	}

	/// <summary>Generates an isolated, bounded preview without consuming the game's random sequence.</summary>
	public string Preview(string rule = "#origin#")
	{
		var previousRandom = Tracery.Tracery.Rng;
		try
		{
			Tracery.Tracery.Rng = new System.Random();
			string text = CreateGrammar(new PreviewBudget()).Flatten(rule);
			if (text.Length > 16384)
				throw new InvalidOperationException("Preview exceeds the 16384 character limit.");
			return text;
		}
		finally
		{
			Tracery.Tracery.Rng = previousRandom;
		}
	}

	private Grammar CreateGrammar(PreviewBudget budget)
	{
		var errors = new List<GrammarValidationError>();
		var definitions = GetDefinitions(errors);
		if (errors.Count > 0)
			throw new InvalidOperationException(string.Join("\n", errors.Select(error => error.ToString()).ToArray()));
		var grammar = new Grammar();
		foreach (var pair in definitions)
		{
			if (pair.Value.Length == 0)
				throw new FormatException("Symbol '" + pair.Key + "' has no rules.");
			var nodes = new TraceryNode[pair.Value.Length];
			for (int i = 0; i < nodes.Length; i++)
			{
				try
				{
					if (pair.Value[i] == null) throw new FormatException("Rule is null.");
					var node = Tracery.Tracery.ParseRule(pair.Value[i]);
					nodes[i] = budget == null ? node : new PreviewNode(node, budget);
				}
				catch (FormatException cause)
				{
					throw new FormatException("Symbol '" + pair.Key + "' rule " + i + ": " + cause.Message, cause);
				}
			}
			grammar.PushRules(pair.Key, nodes);
		}
		return grammar;
	}

	private Dictionary<string, string[]> GetDefinitions(List<GrammarValidationError> errors)
	{
		var definitions = new Dictionary<string, string[]>();
		if (symbols == null || symbols.Length == 0)
		{
			errors.Add(new GrammarValidationError("", -1, null, "Grammar asset has no symbols."));
			return definitions;
		}
		for (int index = 0; index < symbols.Length; index++)
		{
			var symbol = symbols[index];
			if (symbol == null || string.IsNullOrWhiteSpace(symbol.key))
			{
				errors.Add(new GrammarValidationError("", -1, null, "Symbol entry " + index + " has no name."));
				continue;
			}
			if (definitions.ContainsKey(symbol.key))
			{
				errors.Add(new GrammarValidationError(symbol.key, -1, null, "Duplicate symbol at entry " + index + "."));
				continue;
			}
			var rules = symbol.rules ?? new string[0];
			definitions.Add(symbol.key, rules);
		}
		return definitions;
	}

	private sealed class PreviewBudget
	{
		internal int Depth;
		internal int Expansions;
	}

	private sealed class PreviewNode : TraceryNode
	{
		private readonly TraceryNode node;
		private readonly PreviewBudget budget;

		internal PreviewNode(TraceryNode node, PreviewBudget budget) : base(node.Raw)
		{
			this.node = node;
			this.budget = budget;
		}

		public override string Flatten(Grammar grammar)
		{
			if (budget.Depth >= 64 || ++budget.Expansions > 2048)
				throw new InvalidOperationException("Preview expansion limit reached. Check for recursive rules.");
			budget.Depth++;
			try
			{
				string text = node.Flatten(grammar);
				if (text.Length > 16384)
					throw new InvalidOperationException("Preview exceeds the 16384 character limit.");
				return text;
			}
			finally { budget.Depth--; }
		}
	}
}
