// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' show FileSystemException, stderr;

void defaultDriverLogger(String source, String message) {
  try {
    stderr.writeln('$source: $message');
  } on FileSystemException {
    // May encounter IO error: https://github.com/flutter/flutter/issues/69314
  }
}
