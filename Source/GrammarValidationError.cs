namespace Tracery
{
	/// <summary>A validation error with its owning symbol and zero-based rule index.</summary>
	public sealed class GrammarValidationError
	{
		public string Symbol { get; private set; }
		/// <summary>Zero-based index, or -1 for an error affecting the symbol's rule list.</summary>
		public int RuleIndex { get; private set; }
		public string Rule { get; private set; }
		public string Message { get; private set; }

		internal GrammarValidationError(string symbol, int ruleIndex, string rule, string message)
		{
			Symbol = symbol;
			RuleIndex = ruleIndex;
			Rule = rule;
			Message = message;
		}

		public override string ToString()
		{
			return "Symbol '" + Symbol + "'" + (RuleIndex < 0 ? "" : " rule " + RuleIndex) + ": " + Message;
		}
	}
}
