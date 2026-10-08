lines = open("scripts/level_builder.gd").read().split("\n")
row_lens = []
for i, line in enumerate(lines):
    s = line.strip().rstrip(",").rstrip("]")
    if s.startswith('"') and s.endswith('"') and s.count('"') == 2:
        ch = s[1:-1]
        row_lens.append((i+1, len(ch), ch))

for ln, leng, content in row_lens:
    print(f"Row {ln}: length={leng}  {content}")
