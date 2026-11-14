package com.cashpilot.qa.unicodeime;

import android.inputmethodservice.InputMethodService;
import android.view.inputmethod.InputConnection;

public final class UnicodeImeService extends InputMethodService {
  private static volatile UnicodeImeService activeInstance;

  @Override
  public void onCreate() {
    super.onCreate();
    activeInstance = this;
  }

  @Override
  public void onDestroy() {
    if (activeInstance == this) {
      activeInstance = null;
    }
    super.onDestroy();
  }

  @Override
  public boolean onEvaluateInputViewShown() {
    return false;
  }

  static boolean replaceFocusedText(String text) {
    final UnicodeImeService service = activeInstance;
    if (service == null) {
      return false;
    }
    final InputConnection connection = service.getCurrentInputConnection();
    if (connection == null) {
      return false;
    }
    return connection.commitText(text, 1);
  }
}
