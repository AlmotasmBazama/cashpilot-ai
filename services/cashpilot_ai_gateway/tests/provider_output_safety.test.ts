import assert from "node:assert/strict";
import { test } from "node:test";
import { hasUnverifiedMutationClaim } from "../src/security/provider_output_safety.js";

test("rejects unverified financial mutation claims in English and Arabic", () => {
  for (const claim of [
    "The expense was saved.",
    "The transfer was completed.",
    "I updated your balance.",
    "Your budget has been created.",
    "Income was recorded.",
    "All done.",
    "That's taken care of.",
    "تم حفظ المصروف.",
    "تم تنفيذ التحويل.",
    "تم تحديث الرصيد.",
    "تمت إضافة الميزانية.",
    "تم تسجيل الدخل.",
    "خلاص، تم.",
    "درناها وخلاص.",
  ]) {
    assert.equal(hasUnverifiedMutationClaim(claim), true, claim);
  }
});

test("allows advice and explicit non-execution statements", () => {
  for (const safeText of [
    "No action was executed.",
    "The budget has not been created.",
    "I can help you create a budget for review.",
    "Review the transfer before saving it.",
    "لم يتم تنفيذ أي إجراء مالي.",
    "راجع المصروف قبل حفظه.",
    "Cash flow is income minus expenses.",
  ]) {
    assert.equal(hasUnverifiedMutationClaim(safeText), false, safeText);
  }
});

test("Arabic Unicode word boundaries allow explanatory يتم and تتم", () => {
  for (const explanation of [
    "يتم إضافة الفائدة إلى أصل المبلغ دورياً.",
    "تتم إضافة الفائدة إلى الرصيد في نهاية كل فترة.",
  ]) {
    assert.equal(
      hasUnverifiedMutationClaim(explanation),
      false,
      explanation,
    );
  }
});

test("Arabic Unicode word boundaries still reject standalone تم and تمت", () => {
  for (const claim of [
    "تم إضافة المصروف.",
    "تمت إضافة المصروف.",
  ]) {
    assert.equal(hasUnverifiedMutationClaim(claim), true, claim);
  }
});
