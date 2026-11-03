import 'activity_repository.dart';
import 'receipt_parser.dart';
import 'shopping_list_repository.dart';

typedef ActivitySummaryBuilder = String Function(int count);

/// Applies a reviewed batch of scanned/manually-entered purchase lines:
/// matched lines mark the existing "to buy" item bought, unmatched ones are
/// added as brand-new purchased items. Shared by the receipt scanner and
/// the manual "Add Purchase" form so both write through the same path.
/// Returns how many lines were committed.
Future<int> commitPurchaseMatches({
  required ShoppingListRepository shoppingRepo,
  required ActivityRepository activityRepo,
  required String groupId,
  required List<ScanMatch> matches,
  required List<bool> selected,
  required List<double?> prices,
  required String uid,
  required String paidByName,
  required ActivitySummaryBuilder activitySummary,
  DateTime? boughtAt,
}) async {
  var added = 0;
  for (var i = 0; i < matches.length; i++) {
    if (!selected[i]) continue;
    final match = matches[i];
    final price = prices[i];
    if (match.matchedItem != null) {
      await shoppingRepo.markBought(
        groupId: groupId,
        itemId: match.matchedItem!.id,
        boughtByUid: uid,
        itemName: match.matchedItem!.name,
        price: price,
        paidByName: paidByName,
      );
    } else {
      await shoppingRepo.addPurchasedItem(
        groupId: groupId,
        name: match.line.name,
        category: match.suggestedCategory,
        quantity: match.line.quantity ?? '1',
        unit: match.suggestedUnit,
        addedByUid: uid,
        addedByName: paidByName,
        price: price,
        paidByName: paidByName,
        boughtAt: boughtAt,
      );
    }
    added++;
  }
  if (added > 0) {
    await activityRepo.log(
      groupId: groupId,
      actorName: paidByName,
      summary: activitySummary(added),
    );
  }
  return added;
}
