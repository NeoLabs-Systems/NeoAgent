// Saves generated text (an export) as a file the user picks or downloads.
// Resolves to false when the user cancels the save dialog.
export 'text_file_saver_stub.dart'
    if (dart.library.html) 'text_file_saver_web.dart'
    if (dart.library.io) 'text_file_saver_io.dart';
