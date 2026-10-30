#!/usr/bin/env python3
"""Subsets Hahmlet font to only include characters used in Razzia.
Run: python3 tools/subset_fonts.py
"""
import glob, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_IN = os.path.join(ROOT, "assets", "fonts", "Hahmlet.ttf")
FONT_OUT = os.path.join(ROOT, "assets", "fonts", "Hahmlet-Subset.ttf")
CHARS_TXT = os.path.join(ROOT, "assets", "fonts", "used_chars.txt")

def collect_characters():
    chars = set()
    # Add ASCII printable
    for i in range(32, 127):
        chars.add(chr(i))
    # Common symbols, punctuation, quotes, currencies
    chars.update("·…“”‘’—―▶▼▲◀★✦✓💡🃏🎲🤝🚨💰♠♥♦♣$%,./:;!?()[]{}+-*=")
    
    # Collect from gdscript files and i18n
    search_paths = glob.glob(os.path.join(ROOT, "ui", "**", "*.gd"), recursive=True) + \
                   glob.glob(os.path.join(ROOT, "i18n", "**", "*.gd"), recursive=True) + \
                   glob.glob(os.path.join(ROOT, "tools", "i18n", "**", "*.py"), recursive=True)
    
    for p in search_paths:
        try:
            with open(p, "r", encoding="utf-8") as f:
                content = f.read()
                for c in content:
                    chars.add(c)
        except Exception as e:
            pass
            
    # Filter non-whitespace, printable chars
    sorted_chars = sorted(list(c for c in chars if ord(c) >= 32))
    return "".join(sorted_chars)

def main():
    if not os.path.exists(FONT_IN):
        print("Error: %s not found" % FONT_IN)
        sys.exit(1)
        
    chars = collect_characters()
    print("Collected %d unique characters from project" % len(chars))
    
    with open(CHARS_TXT, "w", encoding="utf-8") as f:
        f.write(chars)
        
    cmd = [
        sys.executable, "-m", "fontTools.subset",
        FONT_IN,
        "--text-file=" + CHARS_TXT,
        "--output-file=" + FONT_OUT,
        "--layout-features=*",
        "--name-IDs=*",
        "--notdef-outline"
    ]
    
    print("Running: " + " ".join(cmd))
    res = subprocess.run(cmd)
    if res.returncode == 0:
        orig_sz = os.path.getsize(FONT_IN)
        sub_sz = os.path.getsize(FONT_OUT)
        print("Success! Reduced from %.1f MB to %.1f KB (%.1f%% reduction)" % 
              (orig_sz / 1024 / 1024, sub_sz / 1024, (1.0 - sub_sz / orig_sz) * 100))
    else:
        print("pyftsubset failed with returncode %d" % res.returncode)
        sys.exit(res.returncode)

if __name__ == "__main__":
    main()
