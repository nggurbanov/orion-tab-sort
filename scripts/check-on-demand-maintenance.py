#!/usr/bin/env python3
"""Run the shipped OnDemand timer handlers in an isolated script-class fixture."""
from pathlib import Path
import plistlib
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
engine = (root / "native/Bridge.applescript").read_text()
handlers = engine[engine.index("    on requestConnection:"):engine.index("    on findViews(")]
loader = (root / "native/templates/install-bridge.applescript").read_text()
sidebar = (root / "native/templates/open-sidebar.applescript").read_text()
assert "timerWithTimeInterval:1 target:hostObject" not in loader
assert "set qaBundle" not in sidebar
assert 'selector:"captureDeadlineFired:"' in engine
assert 'my armCaptureWatchdog:(missing value)\n        senderView' in engine

with tempfile.TemporaryDirectory(prefix="orion-on-demand-maintenance-") as directory:
    base = Path(directory)
    resources = base / "WatchdogFixture.bundle/Contents/Resources"
    resources.mkdir(parents=True)
    (resources.parent / "Info.plist").write_bytes(plistlib.dumps({
        "CFBundleIdentifier": "local.orion.on-demand-maintenance-test", "CFBundleName": "OnDemandWatchdogFixture",
        "CFBundlePackageType": "BNDL", "NSAppleScriptEnabled": True,
    }))
    source = """script OnDemandWatchdogFixture
    property parent : class "NSObject"
    property captureToken : missing value
    property captureDeadline : missing value
    property captureWatchdogTimer : missing value
    property reconnectTimer : missing value
    property reconnectError : ""
    property sidebarView : missing value
    property sidebarRequested : false
    property connectionAttempts : 0
    property reconnectCalls : 0
    property cancellations : 0
    on reconnect:ignored
        set my reconnectCalls to my reconnectCalls + 1
        return true
    end reconnect:
    on cancelCapture(payload)
        if not (((payload's objectForKey:"token")'s isEqual:my captureToken) as boolean) then error "Wrong capture restored"
        set my cancellations to my cancellations + 1
        set my captureToken to missing value
        return true
    end cancelCapture
""" + handlers + "\nend script\n"
    path = resources / "OnDemandWatchdogFixture.applescript"
    path.write_text(source)
    subprocess.run(["osacompile", "-l", "AppleScript", "-o", str(path.with_suffix(".scpt")), str(path)], check=True)
    runner = base / "run.applescript"
    runner.write_text('''use framework "Foundation"
use framework "AppKit"
use framework "AppleScriptObjC"
set bundleObject to current application's NSBundle's bundleWithPath:"BUNDLE"
bundleObject's loadAppleScriptObjectiveCScripts()
set fixture to (current application's NSClassFromString("OnDemandWatchdogFixture"))'s alloc()'s init()
fixture's setValue:"A" forKey:"captureToken"
fixture's setValue:(current application's NSDate's dateWithTimeIntervalSinceNow:0.02) forKey:"captureDeadline"
fixture's armCaptureWatchdog:(missing value)
current application's NSRunLoop's mainRunLoop()'s runUntilDate:(current application's NSDate's dateWithTimeIntervalSinceNow:0.1)
if (fixture's valueForKey:"cancellations") as integer is not 1 then error "Deadline did not restore exactly once"
fixture's setValue:"B" forKey:"captureToken"
fixture's setValue:(current application's NSDate's dateWithTimeIntervalSinceNow:0.2) forKey:"captureDeadline"
fixture's armCaptureWatchdog:(missing value)
set armedTimer to fixture's valueForKey:"captureWatchdogTimer"
set staleTimer to current application's NSTimer's timerWithTimeInterval:1 target:fixture selector:"captureDeadlineFired:" userInfo:"A" repeats:false
fixture's captureDeadlineFired:staleTimer
if not (((fixture's valueForKey:"captureWatchdogTimer")'s isEqual:armedTimer) as boolean) then error "Stale callback cleared new watchdog"
fixture's setValue:(missing value) forKey:"captureToken"
fixture's armCaptureWatchdog:(missing value)
current application's NSRunLoop's mainRunLoop()'s runUntilDate:(current application's NSDate's dateWithTimeIntervalSinceNow:0.3)
if (fixture's valueForKey:"cancellations") as integer is not 1 then error "Completed capture restored twice"
fixture's setValue:true forKey:"sidebarRequested"
fixture's requestConnection:(missing value)
current application's NSRunLoop's mainRunLoop()'s runUntilDate:(current application's NSDate's dateWithTimeIntervalSinceNow:5.4)
if (fixture's valueForKey:"connectionAttempts") as integer is not 20 then error "Connection retries were not bounded"
if (fixture's valueForKey:"reconnectTimer") is not missing value then error "Connection timer remained active"
set finishedCalls to fixture's valueForKey:"reconnectCalls"
current application's NSRunLoop's mainRunLoop()'s runUntilDate:(current application's NSDate's dateWithTimeIntervalSinceNow:0.6)
if (fixture's valueForKey:"reconnectCalls") as integer is not (finishedCalls as integer) then error "Idle polling continued"
fixture's setValue:false forKey:"sidebarRequested"
fixture's requestConnection:(missing value)
if (fixture's valueForKey:"reconnectTimer") is not missing value then error "Connected panel started a poller"
return "OnDemand shipped handlers: deadline restoration, stale timer, completed capture, bounded retries, idle quiescence and no-poll reconnect passed."
'''.replace("BUNDLE", str(resources.parent.parent)))
    result = subprocess.run(["osascript", str(runner)], text=True, capture_output=True, timeout=20, check=True)
    print(result.stdout.strip())
