import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';

/// A failed save on a screen that is not a sale must not say "Mauzo".
void main() {
  test('saveNotDone is neutral; saveFailed stays for sales', () {
    const sw = Strings('sw');
    const en = Strings('en');
    expect(sw.saveNotDone, 'Haikuhifadhiwa. Jaribu tena.');
    expect(en.saveNotDone, 'Not saved. Try again.');
    expect(sw.saveNotDone, isNot(contains('Mauzo')));
    expect(sw.saveFailed, contains('Mauzo'));
    expect(sw.moreActions, 'Zaidi');
    expect(en.moreActions, 'More');
  });

  test('only a conflict promises an office review', () {
    const sw = Strings('sw');
    final rejected =
        sw.operationProblem('sale', 'item_required', status: 'failed');
    expect(rejected, contains('Haihesabiwi. Mwambie msimamizi wako.'));
    expect(rejected, isNot(contains('ofisi itakagua')));
    final conflict =
        sw.operationProblem('sale', 'item_required', status: 'conflict');
    expect(conflict, contains('ofisi itakagua'));
    expect(sw.operationProblem('sale', null, status: 'failed'),
        contains('Haihesabiwi. Mwambie msimamizi wako.'));
    expect(sw.operationProblem('sale', 'office_rejected', status: 'failed'),
        contains('Haihesabiwi'));
  });

  test('a sale refused as already verified does not say who verified it', () {
    const sw = Strings('sw');
    const en = Strings('en');
    expect(sw.operationProblem('sale_void', 'already_verified', status: 'conflict'),
        contains('Mauzo yalishathibitishwa kabla ombi halijafika.'));
    expect(en.operationProblem('sale_void', 'already_verified', status: 'conflict'),
        contains('The sale was verified before this arrived.'));
    expect(sw.operationProblem('sale_void', 'already_verified'),
        isNot(contains('ofisi')));
  });

  test('acceptance wording says the count was received, not who accepted', () {
    expect(const Strings('sw').acceptedNote, 'Hesabu yako imepokelewa ofisini.');
    expect(const Strings('en').acceptedNote, 'Your count has been received by the office.');
  });

  test('day_locked reads as its own hold reason', () {
    const sw = Strings('sw');
    const en = Strings('en');
    expect(sw.autoHoldReason('day_locked'), isNot(sw.autoHoldReason('new_code')));
    expect(en.autoHoldReason('day_locked'), isNot(en.autoHoldReason('new_code')));
  });
}
