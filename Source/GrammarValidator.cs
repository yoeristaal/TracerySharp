using System;
using System.Collections.Generic;

namespace Tracery
{
	internal static class GrammarValidator
	{
		internal static IReadOnlyList<GrammarValidationError> Validate(IDictionary<string, Stack<TraceryNode[]>> symbols)
		{
			var errors = new List<GrammarValidationError>();
			var available = new Dictionary<string, List<int>>();
			foreach (var pair in symbols)
			{
				var counts = new List<int>();
				foreach (var layer in pair.Value) counts.Insert(0, layer.Length);
				available.Add(pair.Key, counts);
				if (string.IsNullOrWhiteSpace(pair.Key))
					errors.Add(new GrammarValidationError(pair.Key, -1, null, "Symbol name is empty."));
				if (counts.Count == 0 || counts[counts.Count - 1] == 0)
					errors.Add(new GrammarValidationError(pair.Key, -1, null, "Symbol has no rules."));
			}
			foreach (var pair in symbols)
			{
				if (pair.Value.Count == 0) continue;
				var rules = pair.Value.Peek();
				for (int i = 0; i < rules.Length; i++)
				{
					var node = rules[i];
					if (node == null)
						errors.Add(new GrammarValidationError(pair.Key, i, null, "Rule is null."));
					else Visit(node, Copy(available), message =>
						errors.Add(new GrammarValidationError(pair.Key, i, node.Raw, message)));
				}
			}
			return errors.AsReadOnly();
		}

		internal static IReadOnlyList<GrammarValidationError> Validate(IDictionary<string, string[]> rules)
		{
			if (rules == null) throw new ArgumentNullException("rules");
			var errors = new List<GrammarValidationError>();
			var available = new Dictionary<string, List<int>>();
			foreach (var pair in rules)
			{
				int count = pair.Value == null ? 0 : pair.Value.Length;
				available.Add(pair.Key, new List<int> { count });
				if (string.IsNullOrWhiteSpace(pair.Key))
					errors.Add(new GrammarValidationError(pair.Key, -1, null, "Symbol name is empty."));
				if (count == 0)
					errors.Add(new GrammarValidationError(pair.Key, -1, null, "Symbol has no rules."));
			}

			foreach (var pair in rules)
			{
				if (pair.Value == null) continue;
				for (int i = 0; i < pair.Value.Length; i++)
				{
					string raw = pair.Value[i];
					if (raw == null)
					{
						errors.Add(new GrammarValidationError(pair.Key, i, null, "Rule is null."));
						continue;
					}
					try
					{
						Visit(new Parser(raw).Parse(), Copy(available), message =>
							errors.Add(new GrammarValidationError(pair.Key, i, raw, message)));
					}
					catch (FormatException cause)
					{
						errors.Add(new GrammarValidationError(pair.Key, i, raw, cause.Message));
					}
				}
			}
			return errors.AsReadOnly();
		}

		private static Dictionary<string, List<int>> Copy(Dictionary<string, List<int>> source)
		{
			var copy = new Dictionary<string, List<int>>();
			foreach (var pair in source) copy.Add(pair.Key, new List<int>(pair.Value));
			return copy;
		}

		private static void Visit(TraceryNode node, Dictionary<string, List<int>> available, Action<string> report)
		{
			var rule = node as RuleNode;
			if (rule != null)
			{
				foreach (var section in rule.sections) Visit(section, available, report);
				return;
			}
			var action = node as ActionNode;
			if (action != null)
			{
				VisitAction(action.action, available, report);
				return;
			}
			var tag = node as TagNode;
			if (tag == null) return;
			foreach (var preAction in tag.preActions) VisitAction(preAction, available, report);
			List<int> stack;
			if (!available.TryGetValue(tag.key, out stack) || stack.Count == 0)
				report("Tag '" + tag.Raw + "' references missing symbol '" + tag.key + "'.");
			else if (stack[stack.Count - 1] == 0)
				report("Tag '" + tag.Raw + "' references symbol '" + tag.key + "' with no rules.");
			// Match TagNode's undo order; a POP pre-action has no undo.
			foreach (var preAction in tag.preActions)
			{
				var undo = preAction.CreateUndo();
				if (undo != null) VisitAction(undo, available, report);
			}
		}

		private static void VisitAction(NodeAction action, Dictionary<string, List<int>> available, Action<string> report)
		{
			var push = action as PushRulesAction;
			if (push != null)
			{
				// Values are expanded eagerly, before the new symbol becomes available.
				foreach (var rule in push.rules) Visit(rule, available, report);
				List<int> stack;
				if (!available.TryGetValue(push.key, out stack))
				{
					stack = new List<int>();
					available.Add(push.key, stack);
				}
				stack.Add(push.rules.Length);
				return;
			}
			var pop = action as PopRulesAction;
			if (pop != null)
			{
				List<int> stack;
				if (!available.TryGetValue(pop.key, out stack) || stack.Count == 0)
					report("Cannot POP missing symbol '" + pop.key + "'.");
				else stack.RemoveAt(stack.Count - 1);
			}
		}
	}
}
