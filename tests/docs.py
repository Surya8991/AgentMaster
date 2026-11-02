"""Check published counts against the routing source and dependency manifest."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
read = lambda name: (root / name).read_text(encoding="utf-8")
source = read("skills/agent-master/SKILL.md")
section = source.split("## Step 1: Classify the Task", 1)[1].split("###", 1)[0]
categories = len(re.findall(r"^\| \*\*", section, re.M))
repos = {line.split("|")[0] for line in read("repos.manifest").splitlines()
         if line.strip() and not line.lstrip().startswith("#")}
readme = read("README.md")
table = readme.split("## Routing Table", 1)[1].split("### Smart Tiebreakers", 1)[0]
assert len(re.findall(r"^\| \*\*", table, re.M)) == categories, "README routing rows drifted"
assert f"### {categories} Categories" in readme, "README category count drifted"
assert f"Categories-{categories}-" in readme, "README badge drifted"
assert f"full profile uses {len(repos)} dependency repositories" in readme, "README repository count drifted"
assert f"from {len(repos)} dependency repositories" in read("ONBOARDING.md"), "Onboarding count drifted"
print(f"PASS: documentation matches {categories} routing categories and {len(repos)} dependency repositories")
