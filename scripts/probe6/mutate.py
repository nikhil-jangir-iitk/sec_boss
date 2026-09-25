#!/usr/bin/env python3
"""Scratch. Apply one mutation at a time, run the export tests, report from the JUnit XML, restore."""
import glob, subprocess, sys, xml.etree.ElementTree as ET

IMP = "composeApp/src/{}/kotlin/ai/rever/boss/services/importer/"
EXPORT = IMP.format("commonMain") + "BookmarkExport.kt"
ETEST = IMP.format("desktopTest") + "BookmarkExportTest.kt"
EDT = "run from the event thread, the save dialog can still wait on it"

def edit(path, old, new):
    s = open(path, encoding="utf-8").read()
    assert s.count(old) == 1, (path, old[:80], s.count(old))
    open(path, "w", encoding="utf-8").write(s.replace(old, new))

def main_elsewhere(path):
    # Dispatchers.Main replaced by an ordinary thread, the way a leaked setMain would.
    anchor = "    fun `" + EDT + "`() =\n        runTest {\n"
    edit(path, anchor, anchor + "            kotlinx.coroutines.Dispatchers.setMain("
         "java.util.concurrent.Executors.newSingleThreadExecutor().asCoroutineDispatcher())\n")
    s = open(path, encoding="utf-8").read()
    open(path, "w", encoding="utf-8").write(s.replace("import kotlinx.coroutines.test.runTest\n",
        "import kotlinx.coroutines.test.runTest\nimport kotlinx.coroutines.test.setMain\n", 1))

MUTATIONS = [
    ("E1 new test, Main is not the event thread", lambda: main_elsewhere(ETEST), "BookmarkExportTest"),
    ("E1 dev's test, Main is not the event thread",
     lambda: (subprocess.run(["git", "show", "HEAD~2:" + ETEST], check=True, stdout=open(ETEST, "w")), main_elsewhere(ETEST)),
     "BookmarkExportTest"),
    ("E3 default writer is plain writeText",
     lambda: edit(EXPORT, "{ path, text -> File(path).atomicWriteText(text) }", "{ path, text -> File(path).writeText(text) }"),
     "BookmarkExportTest"),
]

def run(cls):
    subprocess.run(["rm", "-rf", "composeApp/build/test-results/desktopTest"])
    r = subprocess.run(["./gradlew", ":composeApp:desktopTest", "--tests", "ai.rever.boss.services.importer." + cls,
                        "-PskipLint", "--offline", "-q"], capture_output=True, text=True)
    tests = fails = 0
    names = []
    for f in glob.glob("composeApp/build/test-results/desktopTest/*.xml"):
        root = ET.parse(f).getroot()
        tests += int(root.get("tests")); fails += int(root.get("failures")) + int(root.get("errors"))
        for tc in root.iter("testcase"):
            for bad in list(tc.findall("failure")) + list(tc.findall("error")):
                names.append(f"{tc.get('name')} :: {(bad.get('message') or '').splitlines()[0][:160]}")
    return r.returncode, tests, fails, names

for label, apply, cls in MUTATIONS:
    apply()
    rc, tests, fails, names = run(cls)
    subprocess.run(["git", "checkout", "--", EXPORT, ETEST], check=True)
    print(f"MUTANT [{label}] gradle={rc} tests={tests} failures={fails}")
    for n in names:
        print("    FAILED", n)
rc, tests, fails, names = run("*")
print(f"RESTORED importer package gradle={rc} tests={tests} failures={fails}")
print("tree clean:", subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout.strip() == "")
