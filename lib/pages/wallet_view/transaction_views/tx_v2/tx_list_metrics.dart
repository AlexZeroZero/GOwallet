/*
 * This file is part of BitFinite Wallet.
 *
 * Spacing for the wallet view's transaction card.
 */

/// Horizontal inset of every piece of content inside the transactions card.
///
/// One number, because the card holds three different things — transaction
/// rows, day headers, and the truncation notice — each built by a different
/// widget, and each was insetting itself by a different amount. The day header
/// used 4 against the rows' 16, which put "16 AUG" visibly left of the column
/// it labels.
///
/// The rows reach it as [kTxRowOuterGap] + [kTxRowInnerPad], because the row
/// needs its outer gap separately: outside the grouped card each row is its
/// own card and that gap is the space between them.
const double kTxCardInset = 16;

/// The row's outer padding, which is the gap between cards when rows are NOT
/// grouped into one. Inside the grouped card it just contributes to the inset.
const double kTxRowOuterGap = 6;

/// The rest of the row's inset, inside its tap target.
const double kTxRowInnerPad = kTxCardInset - kTxRowOuterGap;

/// Space above a day header, separating it from the group that ended.
///
/// Larger than [kTxHeaderGapBelow] on purpose: a day header belongs to the
/// rows under it, so it has to sit closer to them than to the ones above, or
/// it reads as a footer for the previous day.
const double kTxHeaderGapAbove = 16;

/// Space below a day header, binding it to its own rows.
const double kTxHeaderGapBelow = 2;

/// Gap between the truncation notice and the transactions card below it.
const double kTxNoticeGapBelow = 10;
