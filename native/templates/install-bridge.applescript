use framework "Foundation"
use framework "AppKit"
use framework "WebKit"
use framework "AppleScriptObjC"

on validateRuntime(hostObject)
    if ((hostObject's valueForKey:"controllerURL") as text) is not "chrome-extension://@@EXTENSION_ID@@/sorter.html" then error "A different sorter extension is already loaded; finish it before changing runtime"
    if ((hostObject's valueForKey:"journalPath") as text) is not "@@RUNTIME_ROOT@@/state/native-session-undo.json" then error "A different sorter runtime is already loaded; finish it before changing runtime"
end validateRuntime

on validateLoadedRevision(candidateTitle)
    if candidateTitle starts with "OrionNativeTreeHostV3" and candidateTitle is not "OrionNativeTreeHostV3R49" then error "Another bridge revision is loaded. Finish Undo/capture and restart Orion manually before installing this runtime."
end validateLoadedRevision

set hostBundle to current application's NSBundle's mainBundle()
if (hostBundle's bundleIdentifier() as text) is not "com.kagi.kagimacOS" then error "Run this button inside Orion"
if ((hostBundle's objectForInfoDictionaryKey:"CFBundleShortVersionString") as text) is not "1.1.3" or ((hostBundle's objectForInfoDictionaryKey:"CFBundleVersion") as text) is not "152" then error "Unsupported Orion build; bridge not loaded"
set menuObject to current application's NSApplication's sharedApplication()'s mainMenu()
-- Never silently replace another bridge or discard its Undo/capture state.
repeat with itemIndex from 0 to (menuObject's numberOfItems() as integer) - 1
    set candidateTitle to ((menuObject's itemAtIndex:itemIndex)'s title()) as text
    my validateLoadedRevision(candidateTitle)
end repeat
set holderItem to menuObject's itemWithTitle:"OrionNativeTreeHostV3R49"
if holderItem is missing value then
    set nativeBundle to current application's NSBundle's bundleWithPath:"@@RUNTIME_ROOT@@/native/OrionNativeTreeBridgeV3R49.bundle"
    nativeBundle's loadAppleScriptObjectiveCScripts()
    set hostClass to current application's NSClassFromString("OrionNativeTreeBridgeV3R49")
    if hostClass is missing value then error "Bridge class missing; build the runtime first"
    set hostObject to hostClass's alloc()'s init()
    my validateRuntime(hostObject)
    set holderItem to current application's NSMenuItem's alloc()'s initWithTitle:"OrionNativeTreeHostV3R49" action:(missing value) keyEquivalent:""
    holderItem's setHidden:true
    holderItem's setRepresentedObject:hostObject
    menuObject's addItem:holderItem
else
    set hostObject to holderItem's representedObject()
    my validateRuntime(hostObject)
end if
-- The bridge has no permanent timer or automatic startup helper.
if not ((hostObject's reconnect:(missing value)) as boolean) then error (hostObject's valueForKey:"reconnectError") as text
return "Native sorter connected on demand."
