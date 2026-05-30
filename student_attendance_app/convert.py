import codecs
import os

source = r"C:\Users\parth\.gemini\antigravity\brain\c09affe9-3399-450a-a25a-be89a00fb9d7\scratch\yesterday_scanner.dart"
target = r"C:\Users\parth\.gemini\antigravity\brain\c09affe9-3399-450a-a25a-be89a00fb9d7\yesterday_scanner_screen.md"

with codecs.open(source, 'r', encoding='utf-16le') as f:
    content = f.read()

with codecs.open(target, 'w', encoding='utf-8') as f:
    f.write("```dart\n")
    f.write(content)
    f.write("\n```")
