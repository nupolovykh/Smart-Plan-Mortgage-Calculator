---
name: check-validator-sync
description: Check that the mortgage price/monthly-payment formulas in backend/src/MortgageValidator.php and frontend/src/App.tsx haven't drifted apart, and that MortgageValidatorTest.php covers any change. Use before opening a PR that touches either file, or whenever asked to verify the anti-tampering check still matches the UI preview.
---

Per `CLAUDE.md`: the pricing/annuity math is implemented **twice** —
`backend/src/MortgageValidator.php` (authoritative) and inline in
`frontend/src/App.tsx` (`calculatePrice`, `calculateMonthlyPaymentValue`,
for live UI preview). The backend independently recalculates and rejects
a request if the frontend's numbers don't match within tolerance — so if
the two formulas disagree, real users get spuriously rejected ("Price
tampering detected!" / "Incorrect monthly payment!") for legitimate
submissions.

This skill is a manual line-by-line comparison, not a script — the two
implementations are in different languages (PHP vs TypeScript), so there's
nothing to execute and diff. Read both sides and check each invariant below.

## Where to look

| Concern | Backend | Frontend |
|---|---|---|
| Discount/price | `MortgageValidator::calculateExpectedPrice()` | `calculatePrice()`, `App.tsx:58-71` |
| Annuity payment | `MortgageValidator::calculateMonthlyPayment()` | `calculateMonthlyPaymentValue()`, `App.tsx:73-98` |
| Tolerances | `PRICE_TOLERANCE = 1`, `MONTHLY_PAYMENT_TOLERANCE = 2` (`MortgageValidator.php`) | n/a — frontend has no tolerance concept, it's the thing being tolerance-checked |
| Tests | `backend/tests/MortgageValidatorTest.php` | none (no frontend test runner configured) |

## Invariants to check, in order

1. **Discount type branching matches exactly**: `%` → `price * (1 - discount_value / 100)`;
   `rub` → `max(0, price - discount_value)`; no promo/unrecognized type → unchanged
   `price`. Both sides must branch on the same two string literals (`"%"` / `"rub"`)
   and use the same divisor (100).
2. **Loan amount formula matches**: `loanAmount = price - initial_payment - maternal_capital`
   on both sides, with the same "must be > 0" guard (backend throws; frontend returns `0`
   from `calculateMonthlyPaymentValue` when `loanAmount <= 0` — different failure mode by
   design, but the *threshold* must be identical).
3. **Annuity formula matches**: `months = years * 12`; zero-rate special case
   `loanAmount / months`; otherwise `monthlyRate = annualRate / 12 / 100`,
   `pow = (1 + monthlyRate) ^ months`, `payment = loanAmount * (monthlyRate * pow) / (pow - 1)`.
   Both sides must use the same divisors (`12`, `100`) in the same order — reordering
   float division here can shift results past the tolerance on large loan amounts.
4. **Rounding matches**: backend uses `round(x, 2)`, frontend uses `parseFloat(x.toFixed(2))`
   — both round-half-away-from-zero to 2 decimals. If either side's rounding mode changes,
   the `PRICE_TOLERANCE`/`MONTHLY_PAYMENT_TOLERANCE` margins (1 and 2 respectively) are
   what absorb the difference — don't let a rounding change silently rely on tolerance
   creep instead of being caught here.
5. **Tests**: if you changed either formula, confirm `MortgageValidatorTest.php` has a
   case for it — existing coverage: `testCalculateExpectedPriceWithPercentagePromo`,
   `testCalculateExpectedPriceWithAbsolutePromo`, `testCalculateExpectedPriceWithoutPromo`,
   `testCalculateMonthlyPayment`, `testCalculateMonthlyPaymentZeroRate`,
   `testValidateSuccessful`, `testValidatePriceMismatch`, `testValidateLoanAmountTooLow`,
   `testValidateMonthlyPaymentMismatch`, `testValidateWithNullPromoIdInRequest`,
   `testValidateWithMissingPromoIdInRequest`. A formula change with no corresponding
   test change is a red flag, not proof of a bug — say so explicitly rather than silently
   passing.

## Reporting

State plainly: **in sync** or **drifted**, and if drifted, name the exact line(s) and
which invariant above they violate — not a vague "looks mostly fine." If both files
were touched in the same diff, also check whether `PRICE_TOLERANCE`/
`MONTHLY_PAYMENT_TOLERANCE` were widened to paper over a mismatch instead of fixing it;
that's a smell worth calling out even if tests pass.
