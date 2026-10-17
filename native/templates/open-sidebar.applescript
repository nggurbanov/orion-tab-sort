use framework "Foundation"
use framework "AppKit"
use framework "WebKit"
on hasControllerView(nativeView)
    if nativeView is missing value then return false
    if (nativeView's isKindOfClass:(current application's WKWebView)) as boolean then
        if nativeView's |URL|() is not missing value then
            if (nativeView's |URL|()'s absoluteString() as text) is "chrome-extension://@@EXTENSION_ID@@/sorter.html" then return true
        end if
    end if
    set children to nativeView's subviews()
    repeat with i from 0 to (children's |count|() as integer) - 1
        if my hasControllerView(children's objectAtIndex:i) then return true
    end repeat
    return false
end hasControllerView
set targetWindow to current application's NSApplication's sharedApplication()'s mainWindow()
-- Programmable-button execution can temporarily clear mainWindow.
if targetWindow is missing value then
    set orderedWindows to current application's NSApplication's sharedApplication()'s orderedWindows()
    repeat with i from 0 to (orderedWindows's |count|() as integer) - 1
        set candidate to orderedWindows's objectAtIndex:i
        if (candidate's respondsToSelector:"currentTabView") as boolean then
            set candidateTab to candidate's currentTabView()
            if candidateTab is not missing value then
            if (candidate's isVisible() as boolean) and (candidateTab's URLString() as text) is not "chrome-extension://@@EXTENSION_ID@@/sorter.html" then
                set targetWindow to candidate
                exit repeat
            end if
            end if
        end if
    end repeat
end if
set allWindows to current application's NSApplication's sharedApplication()'s |windows|()
repeat with i from 0 to (allWindows's |count|() as integer) - 1
    set w to allWindows's objectAtIndex:i
    if not ((w's respondsToSelector:"currentTabView") as boolean) then
        if (w's title() as text) is "Разобрать вкладки" then w's orderOut:(missing value)
    end if
end repeat
set sourceText to current application's NSString's stringWithContentsOfFile:"@@RUNTIME_ROOT@@/scripts/install-sorter-bridge.applescript" encoding:4 |error|:(missing value)
set scriptObject to current application's NSAppleScript's alloc()'s initWithSource:sourceText
set {scriptResult, scriptError} to scriptObject's executeAndReturnError:(reference)
if scriptResult is missing value then error (current application's NSDictionary's dictionaryWithDictionary:scriptError)'s description() as text
set holder to current application's NSApplication's sharedApplication()'s mainMenu()'s itemWithTitle:"OrionNativeTreeHostV3R49"
set hostObject to holder's representedObject()
if targetWindow is missing value or not ((targetWindow's respondsToSelector:"currentTabView") as boolean) then error "Open Native Tree Bridge from a browser window"
if (targetWindow's currentTabView()'s URLString() as text) is "chrome-extension://@@EXTENSION_ID@@/sorter.html" then error "Open Native Tree Bridge from the window you want to sort"
if (hostObject's valueForKey:"sidebarView") is missing value then
    set controllerFound to false
    set nativeWindows to current application's NSApplication's sharedApplication()'s |windows|()
    repeat with i from 0 to (nativeWindows's |count|() as integer) - 1
        set w to nativeWindows's objectAtIndex:i
        if (w's respondsToSelector:"currentTabView") as boolean then
            set tabView to w's currentTabView()
            if tabView is not missing value then
                if (tabView's URLString() as text) is "chrome-extension://@@EXTENSION_ID@@/sorter.html" then
                    if my hasControllerView(w's contentView()) then
                        set controllerFound to true
                        exit repeat
                    end if
                end if
            end if
        end if
    end repeat
    if not controllerFound then
        -- Orion registers extension APIs only for its own managed WebViews.
        -- Keep that internal document hidden once its view enters the sidebar.
        -- Dispatch from a separate process after this toolbar event returns.
        -- Nested synchronous self-AppleEvents can leave an unmounted document.
        set createTask to current application's NSTask's alloc()'s init()
        createTask's setLaunchPath:"/usr/bin/osascript"
        createTask's setArguments:{"-e", "tell application \"Orion\" to make new document with properties {URL:\"chrome-extension://@@EXTENSION_ID@@/sorter.html\"}"}
        createTask's setStandardOutput:(current application's NSFileHandle's fileHandleWithNullDevice())
        createTask's setStandardError:(current application's NSFileHandle's fileHandleWithNullDevice())
        createTask's |launch|()
        targetWindow's makeKeyAndOrderFront:(missing value)
    end if
end if
hostObject's setValue:targetWindow forKey:"sidebarWindow"
hostObject's setValue:true forKey:"sidebarRequested"
set currentView to hostObject's valueForKey:"sidebarView"
if currentView is not missing value then currentView's evaluateJavaScript:"if(!window.OrionSorter?.focusCurrentWindow)location.reload();" completionHandler:(missing value)

hostObject's requestConnection:(missing value)
return "Подключаю панель вкладок…"
