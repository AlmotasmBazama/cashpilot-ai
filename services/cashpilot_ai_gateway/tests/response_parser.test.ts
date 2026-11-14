import assert from "node:assert/strict";
import { test } from "node:test";
import { unsupportedFinancialFigures } from "../src/groq/response_parser.js";
import type { SanitizedFinancialContext } from "../src/types.js";

function financialContext(
  toolId: string,
  values: Record<string, unknown>,
): SanitizedFinancialContext {
  // Some provenance-negative unit cases intentionally bypass the request
  // schema. The contract suite separately proves that these shapes cannot
  // cross the HTTP boundary.
  return {
    currency: "LYD",
    records: [{ toolId, partial: false, values }],
    assumptions: [],
  } as unknown as SanitizedFinancialContext;
}

test("financial figure grounding accepts exact lexical decimal equivalents", async (t) => {
  const cases = [
    {
      name: "ASCII grouping and insignificant zeroes",
      text: "Income is 1,234.500 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "1234.5",
      }),
    },
    {
      name: "Arabic-Indic digits and Arabic separators",
      text: "Income is \u0661\u066C\u0662\u0663\u0664\u066B\u0665\u0660 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "1234.5",
      }),
    },
    {
      name: "Persian digits and Arabic separators",
      text: "Income is \u06F1\u066C\u06F2\u06F3\u06F4\u066B\u06F5\u06F0 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "1234.5",
      }),
    },
    {
      name: "Unicode minus",
      text: "Cash flow is \u2212\u0661\u066C\u0662\u0663\u0664\u066B\u0665\u0660 LYD.",
      context: financialContext("get_cash_flow_trend", {
        currentNet: "-1234.5",
      }),
    },
    {
      name: "Arabic percent marker",
      text: "The expense change is \u0661\u0662\u066B\u0665\u066A.",
      context: financialContext("get_monthly_comparison", {
        expenseChangePercent: "12.5",
      }),
    },
    {
      name: "integer above the JavaScript safe range",
      text: "Income is 9,007,199,254,740,993 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "9007199254740993",
      }),
    },
    {
      name: "count dimension",
      text: "There are 3 active budgets.",
      context: financialContext("get_budget_summary", {
        activeCount: 3,
      }),
    },
    {
      name: "date dimension",
      text: "The nearest target date is 2026-08-10.",
      context: financialContext("get_goal_summary", {
        nearestTargetDate: "2026-08-10T00:00:00.000Z",
      }),
    },
    {
      name: "nested amount and percent provenance",
      text: "The budget spent 100 LYD and reached 25%.",
      context: financialContext("get_budget_progress", {
        budgets: [{ spent: "100", progressPercent: "25" }],
      }),
    },
  ] as const;

  for (const item of cases) {
    await t.test(item.name, () => {
      assert.deepEqual(
        unsupportedFinancialFigures(item.text, item.context),
        [],
      );
    });
  }
});

test("financial figure grounding rejects non-decimal and malformed forms", async (t) => {
  const cases = [
    {
      name: "unsupported Arabic-Indic value",
      text: "Income is \u0669\u0669\u0669 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "100",
      }),
    },
    {
      name: "distinct integers above 2^53 stay distinct",
      text: "Income is 9007199254740993 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "9007199254740992",
      }),
    },
    {
      name: "scientific notation cannot be assembled from allowed digits",
      text: "Income is 1e9 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "1",
        monthlyExpense: "9",
      }),
    },
    {
      name: "short thousands group",
      text: "Income is 12,34 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "1234",
      }),
    },
    {
      name: "mixed thousands separators",
      text: "Income is 1,234\u066C567 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "1234567",
      }),
    },
    {
      name: "multiple decimal separators",
      text: "Income is 12\u066B5.0 LYD.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "12.5",
      }),
    },
  ] as const;

  for (const item of cases) {
    await t.test(item.name, () => {
      assert.notDeepEqual(
        unsupportedFinancialFigures(item.text, item.context),
        [],
      );
    });
  }
});

test("financial figure grounding keeps tool-field dimension provenance", async (t) => {
  const cases = [
    {
      name: "amount does not authorize a percent",
      text: "The savings rate is 10%.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "10",
      }),
    },
    {
      name: "amount does not authorize a count",
      text: "There are 10 transactions.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "10",
      }),
    },
    {
      name: "amount does not authorize a year",
      text: "The target year is 2026.",
      context: financialContext("get_dashboard_summary", {
        monthlyIncome: "2026",
      }),
    },
    {
      name: "count does not authorize an amount",
      text: "Income is 3 LYD.",
      context: financialContext("get_budget_summary", {
        activeCount: 3,
      }),
    },
    {
      name: "percent does not authorize an amount",
      text: "Income is 12.5 LYD.",
      context: financialContext("get_monthly_comparison", {
        expenseChangePercent: "12.5",
      }),
    },
    {
      name: "field name on the wrong tool has no provenance",
      text: "The expense change is 12.5%.",
      context: financialContext("get_dashboard_summary", {
        expenseChangePercent: "12.5",
      }),
    },
    {
      name: "unknown numeric fields do not become grounded facts",
      text: "Income is 77 LYD.",
      context: financialContext("get_dashboard_summary", {
        arbitraryValue: "77",
      }),
    },
  ] as const;

  for (const item of cases) {
    await t.test(item.name, () => {
      assert.notDeepEqual(
        unsupportedFinancialFigures(item.text, item.context),
        [],
      );
    });
  }
});
