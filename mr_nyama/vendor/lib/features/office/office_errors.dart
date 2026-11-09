import '../../core/api/office_repository.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/l10n/strings.dart';

/// Converts office API and authentication failures into user-facing copy.
String officeErrorText(Strings strings, Object error) => switch (error) {
      SupplyError(:final code) => strings.supplyRefusal(code),
      OfficeError(kind: OfficeErrorKind.duplicate) => strings.duplicatePhone,
      OfficeError(kind: OfficeErrorKind.forbidden) => strings.notAllowed,
      OfficeError(kind: OfficeErrorKind.ownRecord) => strings.ownRecordRefused,
      OfficeError(kind: OfficeErrorKind.lead, :final detail?) =>
        strings.leadRefusal(detail),
      OfficeError(kind: OfficeErrorKind.refused, :final detail?) =>
        strings.serverRefused(detail),
      OfficeError(kind: OfficeErrorKind.notFound) => strings.personNotFound,
      OfficeError(kind: OfficeErrorKind.refused) => strings.errorBody,
      OfficeError() => strings.phoneInvalid,
      AuthFailure() => strings.failure(error),
      _ => strings.errorBody,
    };
