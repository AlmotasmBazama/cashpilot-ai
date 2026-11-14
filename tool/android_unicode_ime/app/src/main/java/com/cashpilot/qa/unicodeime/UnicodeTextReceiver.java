package com.cashpilot.qa.unicodeime;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Base64;
import java.nio.charset.StandardCharsets;

public final class UnicodeTextReceiver extends BroadcastReceiver {
  @Override
  public void onReceive(Context context, Intent intent) {
    if (!"com.cashpilot.qa.unicodeime.COMMIT_TEXT".equals(intent.getAction())) {
      return;
    }
    final String encoded = intent.getStringExtra("b64");
    if (encoded == null || encoded.length() > 4096) {
      return;
    }
    try {
      final String text = new String(
          Base64.decode(encoded, Base64.NO_WRAP),
          StandardCharsets.UTF_8);
      setResultCode(UnicodeImeService.replaceFocusedText(text) ? 1 : 2);
    } catch (IllegalArgumentException ignored) {
      // Malformed input is rejected without logging the supplied content.
      setResultCode(3);
    }
  }
}
