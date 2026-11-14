import type {
  NormalizedDate,
  NormalizedDecimal,
} from "./financial_figure_contracts.js";

const digitMap: Readonly<Record<string, string>> = {
  "\u0660": "0",
  "\u0661": "1",
  "\u0662": "2",
  "\u0663": "3",
  "\u0664": "4",
  "\u0665": "5",
  "\u0666": "6",
  "\u0667": "7",
  "\u0668": "8",
  "\u0669": "9",
  "\u06f0": "0",
  "\u06f1": "1",
  "\u06f2": "2",
  "\u06f3": "3",
  "\u06f4": "4",
  "\u06f5": "5",
  "\u06f6": "6",
  "\u06f7": "7",
  "\u06f8": "8",
  "\u06f9": "9",
};

const digitSource = "0-9\\u0660-\\u0669\\u06f0-\\u06f9";
const signSource = "+\\-\\u2212\\ufe63\\uff0d";
const groupingSource = ",_\\u066c \\t\\u00a0\\u202f";
const numericSeparatorSource = `.\\u066b${groupingSource}`;
const strictNumericSeparatorSource = "_\\u066b\\u066c";
const punctuationSeparatorSource = "., \\t\\u00a0\\u202f";
const percentSource = "%\\u066a\\uff05";
const dateSource =
  `[${digitSource}]{4}` +
  `(?:[-/][${digitSource}]{1,2}){2}` +
  `(?:T[${digitSource}]{2}:[${digitSource}]{2}` +
  `(?::[${digitSource}]{2}(?:\\.[${digitSource}]+)?)?` +
  `(?:Z|[+\\-][${digitSource}]{2}:[${digitSource}]{2})?)?`;
const decimalSource =
  `[${signSource}]*` +
  `(?:[${digitSource}]|[.\\u066b\\u066c_](?=[${digitSource}]))` +
  `(?:[${digitSource}]|` +
  `[${strictNumericSeparatorSource}]|` +
  `[${punctuationSeparatorSource}]` +
  `(?=[${numericSeparatorSource}]*[${digitSource}]))*` +
  `(?:[eE][${signSource}]*[${digitSource}]*)?` +
  `(?:[ \\t\\u00a0\\u202f]*[${percentSource}]+)?`;
export const financialFigurePattern = new RegExp(
  `${dateSource}|${decimalSource}`,
  "gu",
);

function asciiDigits(value: string): string {
  return value.replace(
    /[\u0660-\u0669\u06f0-\u06f9]/gu,
    (digit) => digitMap[digit] ?? digit,
  );
}

function canonicalUnsignedInteger(value: string): string {
  return value.replace(/^0+(?=\d)/u, "");
}

export function normalizeDecimal(value: string): NormalizedDecimal | null {
  // Keep the value lexical throughout. Binary floating-point conversion would
  // collapse distinct integers above 2^53 and can reformat exact decimals.
  let candidate = asciiDigits(value.trim())
    .replace(/[\u2212\ufe63\uff0d]/gu, "-")
    .replace(/[\u00a0\u202f]/gu, " ");
  const percentMatch = /[\u066a\uff05%]$/u.test(candidate);
  if (percentMatch) {
    candidate = candidate.slice(0, -1).trimEnd();
  }
  if (candidate.length === 0 || /[eE]/u.test(candidate)) {
    return null;
  }

  let negative = false;
  if (candidate[0] === "+" || candidate[0] === "-") {
    negative = candidate[0] === "-";
    candidate = candidate.slice(1);
  }
  if (
    candidate.length === 0 ||
    /[+\-%\u066a\uff05]/u.test(candidate) ||
    /[^0-9.,_\u066b\u066c ]/u.test(candidate)
  ) {
    return null;
  }

  const asciiDecimalCount = candidate.split(".").length - 1;
  const arabicDecimalCount = candidate.split("\u066b").length - 1;
  if (
    asciiDecimalCount + arabicDecimalCount > 1 ||
    (asciiDecimalCount > 0 && arabicDecimalCount > 0)
  ) {
    return null;
  }
  const decimalSeparator =
    asciiDecimalCount === 1 ? "." : arabicDecimalCount === 1 ? "\u066b" : null;
  const decimalParts =
    decimalSeparator === null
      ? [candidate]
      : candidate.split(decimalSeparator);
  const integerPart = decimalParts[0];
  const fractionalPart = decimalParts[1];
  if (
    integerPart === undefined ||
    integerPart.length === 0 ||
    (decimalSeparator !== null &&
      (fractionalPart === undefined ||
        fractionalPart.length === 0 ||
        !/^\d+$/u.test(fractionalPart)))
  ) {
    return null;
  }

  const groupingCharacters = [",", "_", "\u066c", " "].filter((separator) =>
    integerPart.includes(separator),
  );
  if (groupingCharacters.length > 1) {
    return null;
  }
  const groupingSeparator = groupingCharacters[0];
  let integerDigits: string;
  if (groupingSeparator === undefined) {
    if (!/^\d+$/u.test(integerPart)) {
      return null;
    }
    integerDigits = integerPart;
  } else {
    const groups = integerPart.split(groupingSeparator);
    if (
      groups.length < 2 ||
      !/^[1-9]\d{0,2}$/u.test(groups[0] ?? "") ||
      groups.slice(1).some((group) => !/^\d{3}$/u.test(group))
    ) {
      return null;
    }
    integerDigits = groups.join("");
  }

  const canonicalInteger = canonicalUnsignedInteger(integerDigits);
  const canonicalFraction = fractionalPart?.replace(/0+$/u, "") ?? "";
  const isZero = canonicalInteger === "0" && canonicalFraction.length === 0;
  return {
    canonical: `${negative && !isZero ? "-" : ""}${canonicalInteger}${
      canonicalFraction.length > 0 ? `.${canonicalFraction}` : ""
    }`,
    percent: percentMatch,
  };
}

export function normalizeDate(value: string): NormalizedDate | null {
  const candidate = asciiDigits(value.trim());
  const match =
    /^(\d{4})([-/])(\d{1,2})\2(\d{1,2})(?:T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+\-]\d{2}:\d{2})?)?$/u.exec(
      candidate,
    );
  if (match === null) {
    return null;
  }
  const year = match[1] ?? "";
  const month = (match[3] ?? "").padStart(2, "0");
  const day = (match[4] ?? "").padStart(2, "0");
  if (
    year === "0000" ||
    month < "01" ||
    month > "12" ||
    day < "01" ||
    day > "31"
  ) {
    return null;
  }
  return {
    canonical: `${year}-${month}-${day}`,
    components: [
      canonicalUnsignedInteger(year),
      canonicalUnsignedInteger(month),
      canonicalUnsignedInteger(day),
    ],
  };
}
