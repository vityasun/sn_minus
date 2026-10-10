#!/usr/bin/env python3
"""Convert GLua syntax to plain Lua 5.1/5.2 (line numbers preserved) for linting.

usage: glua2lua.py SRC_ROOT DST_ROOT
"""
import os
import re
import sys

IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')


def long_bracket(src, i):
    m = re.match(r'\[(=*)\[', src[i:])
    if not m:
        return None
    eq = m.group(1)
    close = ']' + eq + ']'
    j = src.find(close, i + len(m.group(0)))
    if j < 0:
        j = len(src)
    else:
        j += len(close)
    return j


def convert(src):
    out = []
    i = 0
    n = len(src)
    prev_sig = ''  # previous significant token
    while i < n:
        c = src[i]
        two = src[i:i + 2]
        if two == '--':
            j = long_bracket(src, i + 2)
            if j is not None:
                out.append(src[i:j])
                i = j
                continue
            j = src.find('\n', i)
            j = n if j < 0 else j
            out.append(src[i:j])
            i = j
            continue
        if two == '//':
            j = src.find('\n', i)
            j = n if j < 0 else j
            out.append('--' + src[i + 2:j])
            i = j
            continue
        if two == '/*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j
            body = src[i + 2:j]
            out.append('--[==[' + body + ']==]')
            i = j + 2
            continue
        if c == '[':
            j = long_bracket(src, i)
            if j is not None:
                out.append(src[i:j])
                i = j
                prev_sig = 'str'
                continue
        if c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == '\\':
                    j += 1
                elif src[j] == '\n':
                    break
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
            prev_sig = 'str'
            continue
        if two == '!=':
            out.append('~=')
            i += 2
            prev_sig = 'op'
            continue
        if two == '&&':
            out.append(' and ')
            i += 2
            prev_sig = 'op'
            continue
        if two == '||':
            out.append(' or ')
            i += 2
            prev_sig = 'op'
            continue
        if c == '!':
            out.append(' not ')
            i += 1
            prev_sig = 'op'
            continue
        m = IDENT.match(src, i)
        if m:
            word = m.group(0)
            if word == 'continue' and prev_sig not in ('.', ':'):
                out.append('__CONTINUE__()')
            else:
                out.append(word)
            prev_sig = word
            i = m.end()
            continue
        if not c.isspace():
            prev_sig = c
        out.append(c)
        i += 1
    return ''.join(out)


def main():
    src_root, dst_root = sys.argv[1], sys.argv[2]
    for root, _, files in os.walk(src_root):
        for f in files:
            if not f.endswith('.lua'):
                continue
            p = os.path.join(root, f)
            rel = os.path.relpath(p, src_root)
            d = os.path.join(dst_root, rel)
            os.makedirs(os.path.dirname(d), exist_ok=True)
            with open(p, encoding='utf-8', errors='replace') as fh:
                s = fh.read()
            with open(d, 'w', encoding='utf-8') as fh:
                fh.write(convert(s))


if __name__ == '__main__':
    main()
