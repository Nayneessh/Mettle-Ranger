import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import 'csv_export.dart';

/// Writes a CSV to a temp file and hands it to the OS share sheet — the
/// mechanism behind Settings' "Export" buttons. The file lives in the
/// app's own cache directory, never anywhere shared with other apps by
/// default, until the user explicitly picks a destination from the share
/// sheet themselves.
class ExportService {
  const ExportService();

  Future<void> exportSessions(List<SessionRow> sessions) => _shareCsv(
        fileName: 'mettle_ranger_sessions.csv',
        contents: sessionsToCsv(sessions),
      );

  Future<void> exportBodyCheckIns(List<BodyCheckInRow> checkIns) => _shareCsv(
        fileName: 'mettle_ranger_body.csv',
        contents: bodyCheckInsToCsv(checkIns),
      );

  Future<void> _shareCsv({required String fileName, required String contents}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(contents);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], fileNameOverrides: [fileName]),
    );
  }
}
