# excel 4.0.6 (local)

Published `excel` 4.0.6 cannot compile against `archive` 4.
`package:image` 4.5.2 and later require `archive` 4, so this app cannot
take both from pub.

This directory is excel 4.0.6 with two call sites updated for archive 4:

- `ZipDecoder.decodeBuffer` is now `decodeStream` (renamed in archive 4.0.0).
- `ArchiveFile.compress` is now `compression` (`CompressionType`).

Upstream has the same adaptation on `main`, but that tree is the unpublished
5.0.0 release. Staying on 4.0.6 keeps the API this app already uses.

License: MIT, see `LICENSE`. Copyright (C) 2021 - Kawaljeet Singh.
