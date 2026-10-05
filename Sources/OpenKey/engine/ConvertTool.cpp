//
//  ConvertTool.cpp
//  OpenKey
//
//  Created by Tuyen on 9/4/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//
#include <locale>
#include <codecvt>
#include "ConvertTool.h"
#include "Engine.h"
#include <iostream>
#include <memory.h>

//option
bool convertToolDontAlertWhenCompleted = false;
bool convertToolToAllCaps = false;
bool convertToolToAllNonCaps = false;
bool convertToolToCapsFirstLetter = false;
bool convertToolToCapsEachWord = false;
bool convertToolRemoveMark = false;
Uint8 convertToolFromCode = 0;
Uint8 convertToolToCode = 0;
int convertToolHotKey = 0;

static vector<Uint8> _breakCode = {'.', '?', '!'};

static bool findKeyCode(const Uint32& charCode, const Uint8& code, int& j, int& k) {
    //find character which has tone/mark
    for (map<Uint32, vector<Uint16>>::iterator it = _codeTable[code].begin(); it != _codeTable[code].end(); ++it) {
        for (int z = 0; z < it->second.size(); z++) {
            if (charCode == it->second[z]) {
                j = it->first;
                k = z;
                return true;
            }//end if
        }
    }
    return false;
}

static Uint16 getUnicodeCompoundMarkIndex(const Uint16& mark) {
    for (int i = 0; i < 5; i++) {
        if (mark == _unicodeCompoundMark[i]) {
            return ((i + 1) << 13);
        }
    }
    return 0;
}

//a table entry j/k (even k = upper case, odd k = lower case) in the target table and case;
//with no case option the letter keeps its case
static Uint16 convertedChar(const int& j, int k, const bool& upper, const bool& lower) {
    if (upper && k % 2 != 0)
        k--;
    else if (lower && k % 2 == 0)
        k++;
    if (convertToolRemoveMark) {
        Uint16 plain = keyCodeToCharacter((Uint8)j);
        return k % 2 == 0 ? towupper(plain) : plain;
    }
    return _codeTable[convertToolToCode][j][k];
}

//append a table value in the target table's encoding (VNI/1258 use 2 bytes, compound a combining mark)
static void pushConverted(vector<wchar_t>& out, const Uint16& target) {
    if (convertToolToCode == 2 || convertToolToCode == 4) { //VNI, VN Locale 1258
        out.push_back((Uint8)target);
        if (HIBYTE(target) > 32)
            out.push_back(target>>8);
    } else if (convertToolToCode == 3 && (target >> 13) > 0) { //Unicode Compound
        out.push_back(target & 0x1FFF);
        out.push_back(_unicodeCompoundMark[(target>>13) - 1]);
    } else {
        out.push_back(target);
    }
}

string convertUtil(const string& sourceString) {
    wstring data = utf8ToWideString(sourceString);
    Uint16 t = 0, target;
    int j, k, p;
    vector<wchar_t> _temp;
    bool hasBreak = false;
    bool shouldUpperCase = false;
    if (convertToolToCapsFirstLetter || convertToolToCapsEachWord)
        shouldUpperCase = true;
    if (convertToolToAllNonCaps)
        shouldUpperCase = false;
    const bool changeCase = convertToolToAllCaps || convertToolToAllNonCaps || convertToolToCapsFirstLetter || convertToolToCapsEachWord;
    bool upper, lower;
    
    for (int i = 0; i < data.size(); i++) {
        p = 0;
        upper = convertToolToAllCaps || shouldUpperCase;
        lower = !upper && changeCase;
        //find char with tone/mark
        if (i < data.size() - 1) {
            switch (convertToolFromCode) {
                case 2: //VNI
                case 4: //1258
                    t = (Uint16)data[i] | (data[i+1] << 8);
                    p = 1;
                    break;
                case 3:{ //Unicode Compound
                    target = getUnicodeCompoundMarkIndex(data[i+1]);
                    if (target > 0){
                        t = (Uint16)data[i] | target;
                        p = 1;
                    } else {
                        t = (Uint16)data[i];
                    }
                    break;
                }
                default:
                    t = (Uint16)data[i];
                    break;
            }
            
            if (findKeyCode(t, convertToolFromCode, j, k)) {
                i += p;
                pushConverted(_temp, convertedChar(j, k, upper, lower));
                shouldUpperCase = false;
                hasBreak = false;
                continue;
            }
        }
        
        //find primary keycode first
        t = (Uint16)data[i];
        if (findKeyCode(t, convertToolFromCode, j, k)) {
            //encode as above: a one-unit match (e.g. the last character) used to be pushed as a raw table value
            pushConverted(_temp, convertedChar(j, k, upper, lower));
            shouldUpperCase = false;
            hasBreak = false;
            continue;
        }
        
        //if dont find => normal char
        if (upper)
            _temp.push_back(towupper(data[i]));
        else if (lower)
            _temp.push_back(towlower(data[i]));
        else
            _temp.push_back(data[i]);
        
        if (t == '\n' || (hasBreak && t == ' ')) {
            if (convertToolToCapsFirstLetter || convertToolToCapsEachWord)
                shouldUpperCase = true;
        } else if (t == ' ' && convertToolToCapsEachWord) {
            shouldUpperCase = true;
        } else if (std::find(_breakCode.begin(), _breakCode.end(), t) != _breakCode.end()) {
            hasBreak = true;
        } else {
            shouldUpperCase = false;
            hasBreak = false;
        }
    }
    _temp.push_back(0);
    wstring str(_temp.begin(), _temp.end());
    return wideStringToUtf8(str);
}

