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
    } else if ((keyWithCaps & CHAR_MASK) == KEY_RETURN) {
        screen += u'\n';
    } else {
        screen += (char16_t)keyCodeToCharacter(keyWithCaps);
    }
}

static char16_t decode(Uint32 d) {
    return (char16_t)((d & PURE_CHARACTER_MASK) || (d & CHAR_CODE_MASK) ? d : keyCodeToCharacter(d));
}

// shortcut: Cmd/Ctrl/Option held (OpenKey.mm passes it as both otherControlKey and shortcutKey)
static void pressKey(Uint32 k, bool shortcut = false) {
    bool caps = k & CAPS_MASK;
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, k & CHAR_MASK, caps ? 1 : 0, shortcut, shortcut);
    if (pData->code == vDoNothing) { //the key reaches the app
        put(k);
        return;
    }
    if (pData->code == vReplaceMaro) { //handleMacro
        int bs = pData->backspaceCount;
        if (vFixRecommendBrowser) {
            screen += u'\u202F';
            bs++;
        }
        screen.erase(screen.size() - std::min((size_t)bs, screen.size()));
        for (Uint32 d : pData->macroData) screen += decode(d);
        put(k); //the key that triggered it
        return;
    }
    int bs = pData->backspaceCount;
    if (vFixRecommendBrowser && pData->extCode != 4) { //SendEmptyCharacter
        screen += u' ';
        bs++;
    }
    if (bs > 0 && bs < MAX_BUFF)
        screen.erase(screen.size() - std::min((size_t)bs, screen.size()));
    for (int i = pData->newCharCount - 1; i >= 0; i--)
        screen += decode(pData->charData[i]);
    if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession)
        put(k);
    if (pData->code == vRestoreAndStartNewSession)
        startNewSession();
}

static void press(char c) {
    pressKey(c == ' ' ? KEY_SPACE : c == '\b' ? KEY_DELETE : c == '\n' ? KEY_RETURN : _characterMap.at(c));
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

    // macros: the macro key must match what the screen shows
    addMacro("hoàn", "hoàn thành");
    addMacro("c", "hello");
    addMacro("oo", "ok");
    addMacro("abc", "XYZ");
    addMacro("ko", "không");
    addMacro("vn", "Việt Nam");
    addMacro("hn", "Hà Nội");
    expect("hoafn ", "hoàn thành ");          // K2: mark moved by checkGrammar(-1)
    expect("ooo ", "ok ");                     // K2: a restore ("ô" + o -> "oo")
    vQuickTelex = 1;
    expect("cc ", "ch ");                      // K2: Quick Telex "cc" is "ch", not macro "c"
    vQuickTelex = 0;
    expect("q ab`\b\bc ", "q ac ");           // G8: no expansion, nothing deleted before "ac"
    expect("ab`\bc ", "XYZ ");                // G8: the deleted punctuation leaves the key
    expect("k \bo ", "không ");                // G7: Backspace over Space brings the key back
    addMacro("a.", "A-dot");
    expect("a.,\b ", "A-dot ");               // G8: Backspace inside a punctuation run keeps the word
    expect("vn\nhn ", "Việt Nam\nHà Nội ");   // N6: a Return expansion no longer blocks the next one
    newSession();
    screen.clear();
    for (const char* p = "ko"; *p; p++) press(*p);
    pressKey(KEY_RETURN, true);
    check("ko + Cmd+Return", utf8(screen), "ko\n"); // N13: a shortcut does not expand

    // N19: after a code table change the keys still match, so the macro can be deleted
    addMacro("đc", "được");
    vCodeTable = 2;
    onTableCodeChange();
    check("đc found after table change", hasMacro("đc") ? "yes" : "no", "yes");
    check("đc deleted after table change", deleteMacro("đc") ? "yes" : "no", "yes");
    vCodeTable = 0;
    onTableCodeChange();

    // K1: stored data is parsed within its size, names longer than one length byte are refused
    const Byte truncated[] = {1, 0, 5, 'a'};
    initMacroMap(truncated, sizeof truncated);
    check("truncated macro data", hasMacro("a") ? "yes" : "no", "no");
    const Byte badSwitch[] = {1, 0, 200, 'x'};
    initSmartSwitchKey(badSwitch, sizeof badSwitch);
    check("300-byte name refused", addMacro(std::string(300, 'a'), "x") ? "added" : "refused", "refused");
    addMacro("ok", "fine");
    std::vector<Byte> saved;
    getMacroSaveData(saved);
    initMacroMap(saved.data(), (int)saved.size());
    check("macro data round trip", hasMacro("ok") ? "yes" : "no", "yes");

    // N25: import strips CR, skips only a ';' header line and survives a line that is not UTF-8
    std::string path = std::string(getenv("TMPDIR") ? getenv("TMPDIR") : "/tmp") + "/openkey_macro_test.txt";
    FILE* f = fopen(path.c_str(), "wb");
    fputs(";header\r\nbtw:by the way\r\nbad:\xff\xfe\r\n", f);
    fclose(f);
    readFromFile(path, false);
    std::vector<std::vector<Uint32>> keys; std::vector<std::string> names, contents;
    getAllMacro(keys, names, contents);
    check("CRLF import", names.size() == 1 ? contents[0] : "?", "by the way");
    f = fopen(path.c_str(), "wb");
    fputs("a:b\n", f);
    fclose(f);
    readFromFile(path, false);
    check("headerless import", hasMacro("a") ? "yes" : "no", "yes");
    remove(path.c_str());
    initMacroMap(NULL, 0);

    // N24: the convert tool keeps the case unless a case option is set
    struct { bool allCaps, removeMark; const char* in; const char* want; } conv[] = {
        {false, false, "Hà Nội, Việt Nam", "Hà Nội, Việt Nam"},
        {true,  false, "HÀ nội", "HÀ NỘI"},
        {false, true,  "Hà Nội", "Ha Noi"},
    };
    for (auto& c : conv) {
        convertToolFromCode = convertToolToCode = 0;
        convertToolToAllCaps = c.allCaps;
        convertToolRemoveMark = c.removeMark;
        check(c.in, convertUtil(c.in), c.want);
    }
    convertToolToAllCaps = convertToolRemoveMark = false;
    // N23: the last character is encoded like the others (it was pushed as one packed table
    // value; for CP1258 "đã" that was a lone surrogate and the UTF-8 conversion threw)
    convertToolFromCode = 0; convertToolToCode = 3;
    check("compound cá", convertUtil("cá"), "ca\xCC\x81");
    for (Uint8 table : {2, 4}) {
        convertToolFromCode = 0; convertToolToCode = table;
        bool bytes = true;
        for (wchar_t c : utf8ToWideString(convertUtil("đã"))) bytes = bytes && c < 0x100;
        check(table == 2 ? "VNI đã is single bytes" : "CP1258 đã is single bytes", bytes ? "yes" : "no", "yes");
    }
    // and a word ending in a marked letter survives a round trip through the 2-unit tables
    for (Uint8 table : {2, 3, 4}) { //VNI Windows, Unicode compound, CP1258
        convertToolFromCode = 0; convertToolToCode = table;
        std::string encoded = convertUtil("cá đã Hà");
        convertToolFromCode = table; convertToolToCode = 0;
        check(table == 2 ? "round trip VNI" : table == 3 ? "round trip compound" : "round trip CP1258",
              convertUtil(encoded), "cá đã Hà");
    }

    printf(failures ? "%d failure(s)\n" : "all passed\n", failures);
    return failures != 0;
}
