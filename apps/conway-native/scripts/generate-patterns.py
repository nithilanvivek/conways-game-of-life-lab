#!/usr/bin/env python3
"""Build-time catalog generator; no app requires Python at runtime."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
patterns = json.loads((root/'shared/patterns.json').read_text())
q = lambda value: json.dumps(value, ensure_ascii=False)
(root/'macos/Patterns.swift').write_text('import Foundation\nstruct LifePattern: Identifiable { let name: String; let category: String; let detail: String; let rows: [String]; var id: String { name } }\nlet patterns: [LifePattern] = [\n'+',\n'.join('LifePattern(name: %s, category: %s, detail: %s, rows: [%s])'%(q(p['name']),q(p['category']),q(p['detail']),', '.join(map(q,p['rows']))) for p in patterns)+'\n]\n')
(root/'windows/Patterns.cs').write_text('namespace Nithi.Life;\npublic record Pattern(string Name, string Category, string Detail, string[] Rows);\npublic static class Catalog { public static readonly Pattern[] All = [\n'+',\n'.join('new(%s, %s, %s, [%s])'%(q(p['name']),q(p['category']),q(p['detail']),', '.join(map(q,p['rows']))) for p in patterns)+'\n]; }\n')
(root/'chromeos/app/src/main/java/land/nithi/life/Patterns.java').write_text('package land.nithi.life;\npublic final class Patterns { public static final String[][] DATA = {\n'+',\n'.join('{%s}'%', '.join(map(q,[p['name'],p['category'],p['detail']]+p['rows'])) for p in patterns)+'\n}; }\n')
(root/'linux/patterns.h').write_text('/* Generated from shared/patterns.json. */\ntypedef struct { const char *name, *category, *detail; int height; const char *rows[13]; } Pattern;\nstatic const Pattern patterns[] = {\n'+',\n'.join('{%s, %s, %s, %d, {%s}}'%(q(p['name']),q(p['category']),q(p['detail']),len(p['rows']),', '.join(map(q,p['rows']))) for p in patterns)+'\n};\n#define PATTERN_COUNT (sizeof(patterns)/sizeof(patterns[0]))\n')
