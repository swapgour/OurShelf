import 'activity_repository.dart';
import 'pantry_repository.dart';
import 'receipt_parser.dart';
import 'shopping_list_repository.dart';

typedef ActivitySummaryBuilder = String Function(int count);

/// Applies a reviewed batch of scanned/manually-entered purchase lines:
/// matched lines mark the existing "to buy" item bought, unmatched ones are
/// added as brand-new purchased items. Shared by the receipt scanner and
/// the manual "Add Purchase" form so both write through the same path.
/// Every committed line also tops up Pantry — same as ticking an item
/// bought from the shopping list does — so a logged/scanned purchase shows
/// up in stock too, not just on the list.
/// Returns how many lines were committed.
Future<int> commitPurchaseMatches({
  required ShoppingListRepository shoppingRepo,
  required ActivityRepository activityRepo,
  required PantryRepository pantryRepo,
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
    String name;
    String category;
    String unit;
    if (match.matchedItem != null) {
      name = match.matchedItem!.name;
      category = match.matchedItem!.category;
      unit = match.matchedItem!.unit;
      await shoppingRepo.markBought(
        groupId: groupId,
        itemId: match.matchedItem!.id,
        boughtByUid: uid,
        itemName: name,
        price: price,
        paidByName: paidByName,
      );
    } else {
      name = match.line.name;
      category = match.suggestedCategory;
      unit = match.suggestedUnit;
      await shoppingRepo.addPurchasedItem(
        groupId: groupId,
        name: name,
        category: category,
        quantity: match.line.quantity ?? '1',
        unit: unit,
        addedByUid: uid,
        addedByName: paidByName,
        price: price,
        paidByName: paidByName,
        boughtAt: boughtAt,
      );
    }
    await pantryRepo.topUpFromPurchase(
      groupId: groupId,
      name: name,
      category: category,
      unit: unit,
    );
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
