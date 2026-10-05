// Engine regression test: types key sequences into the engine and replays its output the
// way OpenKey.mm does (Unicode table, batched sending, browser fix on), then checks the text.
//
//   clang++ -std=c++11 -ISources/OpenKey/engine tests/engine_test.cpp Sources/OpenKey/engine/*.cpp -o /tmp/engine_test && /tmp/engine_test
#include <cstdio>
#include <string>
#include "Engine.h"

// Settings: the first-launch defaults from AppDelegate.m loadDefaultConfig.
int vLanguage = 1, vInputType = 0, vFreeMark = 0, vCodeTable = 0, vCheckSpelling = 1;
int vUseModernOrthography = 0, vQuickTelex = 0, vSwitchKeyStatus = 0, vRestoreIfWrongSpelling = 0;
int vFixRecommendBrowser = 1, vUseMacro = 1, vUseMacroInEnglishMode = 0, vAutoCapsMacro = 0;
int vUseSmartSwitchKey = 1, vUpperCaseFirstChar = 0, vTempOffSpelling = 0, vAllowConsonantZFWJ = 0;
int vQuickStartConsonant = 0, vQuickEndConsonant = 0, vRememberCode = 1, vTempOffOpenKey = 0;

static vKeyHookState* pData;
static std::u16string screen;
static int failures = 0;

static void put(Uint32 keyWithCaps) {
    if ((keyWithCaps & CHAR_MASK) == KEY_DELETE) {
        if (!screen.empty()) screen.pop_back();
    } else {
        screen += (char16_t)keyCodeToCharacter(keyWithCaps);
    }
}

static void press(char c) {
    Uint32 k = c == ' ' ? KEY_SPACE : c == '\b' ? KEY_DELETE : _characterMap.at(c);
    bool caps = k & CAPS_MASK;
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, k & CHAR_MASK, caps ? 1 : 0, false);
    if (pData->code == vDoNothing) { //the key reaches the app
        put(k);
        return;
    }
    int bs = pData->backspaceCount;
    if (vFixRecommendBrowser && pData->extCode != 4) { //SendEmptyCharacter
        screen += u' ';
        bs++;
    }
    if (bs > 0 && bs < MAX_BUFF)
        screen.erase(screen.size() - std::min((size_t)bs, screen.size()));
    for (int i = pData->newCharCount - 1; i >= 0; i--) {
        Uint32 d = pData->charData[i];
        screen += (char16_t)((d & PURE_CHARACTER_MASK) || (d & CHAR_CODE_MASK) ? d : keyCodeToCharacter(d));
    }
    if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession)
        put(k);
    if (pData->code == vRestoreAndStartNewSession)
        startNewSession();
}

// What OpenKey.mm does on a click or a language switch (RequestNewSession).
static void newSession() {
    vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, 0);
    startNewSession();
}

static std::string utf8(const std::u16string& s) {
    std::string out;
    for (char16_t c : s) {
        if (c == 0) { out += "<NUL>"; continue; }
        if (c < 0x80) out += (char)c;
        else if (c < 0x800) { out += (char)(0xC0 | (c >> 6)); out += (char)(0x80 | (c & 0x3F)); }
        else { out += (char)(0xE0 | (c >> 12)); out += (char)(0x80 | ((c >> 6) & 0x3F)); out += (char)(0x80 | (c & 0x3F)); }
    }
    return out;
}

static void check(const char* name, const std::string& got, const std::string& want) {
    if (got != want) {
        failures++;
        printf("FAIL %s: got \"%s\", want \"%s\"\n", name, got.c_str(), want.c_str());
    }
}

static void expect(const char* keys, const char* want) {
    newSession();
    screen.clear();
    for (const char* p = keys; *p; p++) press(*p);
    check(keys, utf8(screen), want);
}

int main() {
    pData = (vKeyHookState*)vKeyInit();

    // regressions: common words keep working
    expect("tieengs Vieetj ", "tiếng Việt ");
    expect("nguowif dduowcj ", "người được ");
    expect("Thuowng thuowr ", "Thương thuở ");
    expect("Dduowngf truwowcs khuyeens quaanf giowf hoafn ", "Đường trước khuyến quần giờ hoàn ");
    expect("coos gawngs chuaarn bij ", "cố gắng chuẩn bị ");

    // N2: a capital T/H must not change where the horn goes
    expect("Thuowr ", "Thuở ");
    expect("THUOWR ", "THUỞ ");

    // N4: the screen follows the engine when a horn is removed, and restores keep the mark
    expect("luowon", "luôn");
    expect("dduowo", "đuô");
    expect("oofo", "òo");
    expect("uwfw", "ùw");

    // N5: đ typed after the vowel
    expect("doatjd ", "đoạt ");
    expect("doaisd ", "đoái ");
    expect("duowmjd ", "đượm ");
    expect("diujd ", "địu ");
    expect("dieengsd ", "điếng ");
    expect("huychs ", "huých ");

    // N7: after a language switch, Backspace must not bring back a word from before it
    newSession();
    screen.clear();
    for (const char* p = "chao "; *p; p++) press(*p);
    newSession();           //switch to English
    screen += u"hello";     //English mode: keys bypass the engine
    newSession();           //switch back
    press('\b');
    press('f');
    check("switch + backspace + f", utf8(screen), "chao hellf");

    printf(failures ? "%d failure(s)\n" : "all passed\n", failures);
    return failures != 0;
}
