script OrionNativeTreeBridgeV3R48
    property parent : class "NSObject"
    property directNativeMode : false
    property capturedPinnedObjects : missing value
    property selectionWrapperToken : missing value
    property nativeObjectUUIDs : missing value
    property nativeScopeUUIDs : missing value
    property controllerURL : "chrome-extension://@@EXTENSION_ID@@/sorter.html"
    property sidebarWindow : missing value
    property sidebarView : missing value
    property sidebarSourceWindow : missing value
    property sidebarRequested : false
    property lastHeartbeat : missing value
    property identityRequestedAt : missing value
    property persistentIdentity : missing value
    property nativeUUIDBindings : missing value
    property exposureCandidates : missing value
    property recoveryCapture : false
    property captureActiveHistory : missing value
    property captureToken : missing value
    property captureDeadline : missing value
    property captureRows : missing value
    property captureWrappers : missing value
    property captureExpanded : missing value
    property captureRootExpanded : missing value
    property captureScrollPoint : missing value
    property captureBindingIDs : missing value
    property selectedIdentity : missing value
    property identityViews : missing value
    property identityHistories : missing value
    property contextItems : missing value
    property beforeSnapshot : missing value
    property appliedSnapshot : missing value
    property attachedControllers : missing value
    property reconnectTimer : missing value
    property connectionAttempts : 0
    property captureWatchdogTimer : missing value
    property reconnecting : false
    property reconnectError : ""
    property sessionKey : missing value
    property journalPath : "@@RUNTIME_ROOT@@/state/native-session-undo.json"

    -- Bounded connection work only; never poll an idle browser.
    on requestConnection:ignored
        my reconnect:(missing value)
        if not my sidebarRequested then my refreshController()
        if my reconnectTimer is not missing value then my reconnectTimer's invalidate()
        set my reconnectTimer to missing value
        set my connectionAttempts to 0
        if not my sidebarRequested then return true
        set my reconnectTimer to current application's NSTimer's timerWithTimeInterval:0.25 target:me selector:"connectionRetry:" userInfo:(missing value) repeats:true
        current application's NSRunLoop's mainRunLoop()'s addTimer:my reconnectTimer forMode:(current application's NSRunLoopCommonModes)
        return true
    end requestConnection:

    on connectionRetry:timerRef
        set my connectionAttempts to my connectionAttempts + 1
        my reconnect:(missing value)
        if not my sidebarRequested then my refreshController()
        if not my sidebarRequested or my connectionAttempts >= 20 then
            timerRef's invalidate()
            set my reconnectTimer to missing value
            if my sidebarRequested then set my reconnectError to "Panel connection timed out; click Native Tree Bridge to retry"
        end if
    end connectionRetry:

    on armCaptureWatchdog:ignored
        if my captureWatchdogTimer is not missing value then my captureWatchdogTimer's invalidate()
        set my captureWatchdogTimer to missing value
        if my captureToken is missing value or my captureDeadline is missing value then return
        set waitTime to my captureDeadline's timeIntervalSinceNow() as real
        if waitTime < 0.001 then set waitTime to 0.001
        set my captureWatchdogTimer to current application's NSTimer's timerWithTimeInterval:waitTime target:me selector:"captureDeadlineFired:" userInfo:my captureToken repeats:false
        current application's NSRunLoop's mainRunLoop()'s addTimer:my captureWatchdogTimer forMode:(current application's NSRunLoopCommonModes)
    end armCaptureWatchdog:

    on captureDeadlineFired:timerRef
        if my captureWatchdogTimer is not missing value then
            if not ((my captureWatchdogTimer's isEqual:timerRef) as boolean) then return
        end if
        set expectedToken to timerRef's userInfo()
        set my captureWatchdogTimer to missing value
        if my captureToken is missing value then return
        if not ((expectedToken's isEqual:my captureToken) as boolean) then return
        try
            my cancelCapture(current application's NSDictionary's dictionaryWithObject:expectedToken forKey:"token")
        on error errorText
            set my reconnectError to "Capture restoration failed: " & errorText
        end try
    end captureDeadlineFired:

    on refreshController()
        if my sidebarView is missing value then return
        my sidebarView's evaluateJavaScript:"(()=>{const r=document.getElementById('read'),f=document.getElementById('refresh');if(r?.disabled&&f&&!f.disabled){location.reload();}else{window.OrionSorter?.focusCurrentWindow?.();}})();" completionHandler:(missing value)
    end refreshController

    on findViews(nativeView, wantedClass)
        if nativeView is missing value then return {}
        set resultViews to {}
        if (nativeView's isKindOfClass:wantedClass) as boolean then set end of resultViews to nativeView
        set childViews to nativeView's subviews()
        repeat with childIndex from 0 to (childViews's |count|() as integer) - 1
            set childView to childViews's objectAtIndex:childIndex
            set resultViews to resultViews & my findViews(childView, wantedClass)
        end repeat
        return resultViews
    end findViews

    on mountSidebar()
        if not my sidebarRequested or my sidebarWindow is missing value then return
        if my sidebarView is missing value then
            set nativeWindows to current application's NSApplication's sharedApplication()'s |windows|()
            repeat with i from 0 to (nativeWindows's |count|() as integer) - 1
                set sourceWindow to nativeWindows's objectAtIndex:i
                if (sourceWindow's respondsToSelector:"currentTabView") as boolean then
                    set sourceTabView to sourceWindow's currentTabView()
                    if sourceTabView is not missing value then
                    if (sourceTabView's URLString() as text) is controllerURL then
                        repeat with v in my findViews(sourceWindow's contentView(), current application's WKWebView)
                            if v's |URL|() is not missing value then
                                if (v's |URL|()'s absoluteString() as text) is controllerURL then
                                    set my sidebarView to contents of v
                                    set my sidebarSourceWindow to sourceWindow
                                end if
                            end if
                        end repeat
                    end if
                    end if
                end if
            end repeat
        end if
        if my sidebarView is missing value then return
        set attachedWindow to sidebarView's |window|()
        if attachedWindow is not missing value then
            if (attachedWindow's isEqual:sidebarWindow) as boolean then

                set my sidebarRequested to false
                return
            end if
        end if
        repeat with textView in my findViews(sidebarWindow's contentView(), current application's NSTextView)
            if (textView's |string|() as text) contains "Подключаю панель вкладок…" then
                set scrollView to textView's enclosingScrollView()
                if scrollView is missing value then error "Sidebar scroll container missing"
                set clipBounds to scrollView's contentView()'s |bounds|()
                scrollView's setDocumentView:sidebarView
                sidebarView's setFrame:clipBounds
                sidebarView's setAutoresizingMask:18
                scrollView's setHasVerticalScroller:false
                scrollView's setHasHorizontalScroller:false
                if my sidebarSourceWindow is not missing value then
                    sidebarSourceWindow's orderOut:(missing value)
                    sidebarSourceWindow's setExcludedFromWindowsMenu:true
                end if
                sidebarWindow's makeKeyAndOrderFront:(missing value)

                set my sidebarRequested to false
                return
            end if
        end repeat
    end mountSidebar

    on reconnect:ignoredTimer
        if my reconnecting then return false
        set my reconnecting to true
        try
        if my captureToken is not missing value then
            if (my captureDeadline's timeIntervalSinceNow() as real) < 0 then
                my cancelCapture(current application's NSDictionary's dictionaryWithObject:my captureToken forKey:"token")
            end if
        end if
        my mountSidebar()
        if my attachedControllers is missing value then set my attachedControllers to current application's NSHashTable's weakObjectsHashTable()
        -- NSWindow is scriptable: NSArray-to-list coercion can send Apple Events.
        set nativeWindows to current application's NSApplication's sharedApplication()'s orderedWindows()
        repeat with windowIndex from 0 to (nativeWindows's |count|() as integer) - 1
            set nativeWindow to nativeWindows's objectAtIndex:windowIndex
            repeat with webView in my findViews(nativeWindow's contentView(), current application's WKWebView)
                if webView's |URL|() is not missing value then
                    if (webView's |URL|()'s absoluteString() as text) is controllerURL then
                        set contentController to webView's configuration()'s userContentController()
                        if not ((my attachedControllers's containsObject:contentController) as boolean) then
                            contentController's addScriptMessageHandler:me |name|:"orionNativeTreeBridgeV3"
                            my attachedControllers's addObject:contentController
                        end if
                    end if
                end if
            end repeat
        end repeat
        if my lastHeartbeat is missing value or (my lastHeartbeat's timeIntervalSinceNow() as real) < -5 then
            set nowDate to current application's NSDate's |date|()
            set processInfo to current application's NSProcessInfo's processInfo()
            set processID to processInfo's processIdentifier()
            set epochTime to nowDate's timeIntervalSince1970()
            set heartbeatObject to current application's NSDictionary's dictionaryWithObjects:{processID, epochTime, "V3R48", "on-demand"} forKeys:{"pid", "timestamp", "host", "mode"}
            set heartbeatData to current application's NSJSONSerialization's dataWithJSONObject:heartbeatObject options:0 |error|:(missing value)
            heartbeatData's writeToFile:"@@RUNTIME_ROOT@@/state/bridge-heartbeat.json" options:1 |error|:(missing value)
            set my lastHeartbeat to current application's NSDate's |date|()
        end if
        set my reconnectError to ""
        set my reconnecting to false
        return true
        on error errorText number errorNumber
            set my reconnectError to errorText & " (" & errorNumber & ")"
            set my reconnecting to false
            return false
        end try
    end reconnect:

    on jsonText(valueObject)
        set jsonData to current application's NSJSONSerialization's dataWithJSONObject:valueObject options:6 |error|:(missing value)
        if jsonData is missing value then error "Cannot encode native state"
        return (current application's NSString's alloc()'s initWithData:jsonData encoding:4) as text
    end jsonText

    on collectRows(sourceObject, outlineView, parentItem, depth)
        if depth > 32 then error "Native depth guard"
        set rows to {}
        set childCount to (sourceObject's outlineView:outlineView numberOfChildrenOfItem:parentItem) as integer
        if childCount > 2000 then error "Native size guard"
        repeat with childIndex from 0 to childCount - 1
            set nativeItem to sourceObject's outlineView:outlineView child:childIndex ofItem:parentItem
            if not ((nativeItem's respondsToSelector:"URLString") as boolean) then error "Unexpected item inside Open Tabs"
            set end of rows to {nativeItem, parentItem, childIndex}
            set rows to rows & my collectRows(sourceObject, outlineView, nativeItem, depth + 1)
        end repeat
        if (count of rows) > 2000 then error "Native size guard"
        return rows
    end collectRows

    on openRoot(sourceObject, outlineView)
        set matches to {}
        set rootCount to (sourceObject's outlineView:outlineView numberOfChildrenOfItem:(missing value)) as integer
        if rootCount > 16 then error "Section guard"
        repeat with rootIndex from 0 to rootCount - 1
            set rootItem to sourceObject's outlineView:outlineView child:rootIndex ofItem:(missing value)
            if (rootItem's description() as text) is "Orion.VerticalTabsViewController.Section.openTabs" then set end of matches to rootItem
        end repeat
        if (count of matches) is not 1 then error "Expected one Open Tabs section"
        return item 1 of matches
    end openRoot

    on pageView(nativeWindow, pageURL)
        set matches to {}
        repeat with webView in my findViews(nativeWindow's contentView(), current application's WKWebView)
            if webView's |URL|() is not missing value then
                if (webView's |URL|()'s absoluteString()'s isEqualToString:pageURL) as boolean then
                    if not ((webView's isHiddenOrHasHiddenAncestor()) as boolean) then set end of matches to contents of webView
                end if
            end if
        end repeat
        if (count of matches) is 0 and (pageURL as text) is "orion://newtab/" then return missing value
        if (count of matches) is not 1 then error "Cannot identify one visible active page"
        return item 1 of matches
    end pageView

    on pageHistory(webView, pageURL)
        if webView is missing value then return current application's NSDictionary's dictionaryWithObjects:{pageURL, true} forKeys:{"current", "nativePage"}
        set backURLs to current application's NSMutableArray's array()
        set backItems to webView's backForwardList()'s backList()
        repeat with i from 0 to (backItems's |count|() as integer) - 1
            backURLs's addObject:((backItems's objectAtIndex:i)'s |URL|()'s absoluteString())
        end repeat
        set forwardURLs to current application's NSMutableArray's array()
        set forwardItems to webView's backForwardList()'s forwardList()
        repeat with i from 0 to (forwardItems's |count|() as integer) - 1
            forwardURLs's addObject:((forwardItems's objectAtIndex:i)'s |URL|()'s absoluteString())
        end repeat
        return current application's NSDictionary's dictionaryWithObjects:{backURLs, forwardURLs, webView's |URL|()'s absoluteString()} forKeys:{"back", "forward", "current"}
    end pageHistory

    on capture(payload)
        set my directNativeMode to false
        set hostBundle to current application's NSBundle's mainBundle()
        set hostID to hostBundle's bundleIdentifier() as text
        set hostVersion to (hostBundle's objectForInfoDictionaryKey:"CFBundleShortVersionString") as text
        set hostBuild to (hostBundle's objectForInfoDictionaryKey:"CFBundleVersion") as text
        if hostID is not "com.kagi.kagimacOS" or hostVersion is not "1.1.3" or hostBuild is not "152" then error "Unsupported Orion build; native mutations disabled"
        if my beforeSnapshot is not missing value then error "Undo the previous sort before selecting another scope"
        if my captureToken is not missing value then error "Complete or cancel the pending identity capture first"
        set my nativeUUIDBindings to missing value
        set my exposureCandidates to missing value
        set my contextItems to missing value
        set my persistentIdentity to missing value
        if my sessionKey is missing value then set my sessionKey to current application's NSUUID's UUID()'s UUIDString()
        set oldData to current application's NSData's dataWithContentsOfFile:journalPath
        if oldData is not missing value then
            set oldJournal to current application's NSJSONSerialization's JSONObjectWithData:oldData options:0 |error|:(missing value)
            if oldJournal is missing value then error "Unreadable recovery journal; refusing to overwrite it"
            if ((oldJournal's objectForKey:"phase") as text) is in {"prepared", "applied", "undoing", "rollingBack"} then
                -- Reading does not replace the unfinished journal. Apply remains blocked until explicit resolution.
            end if
        end if
        set metadata to payload's objectForKey:"tabs"
        set windowID to payload's objectForKey:"windowId"
        if metadata is missing value or windowID is missing value then error "Missing selected window"
        if not ((metadata's isKindOfClass:(current application's NSArray)) as boolean) then error "Invalid tab list"
        if (metadata's |count|() as integer) < 1 or (metadata's |count|() as integer) > 2000 then error "Unsupported tab count"
        set wanted to current application's NSMutableDictionary's dictionary()
        set ids to current application's NSMutableSet's |set|()
        set indexes to current application's NSMutableIndexSet's indexSet()
        set pins to current application's NSMutableArray's array()
        set metaMap to current application's NSMutableDictionary's dictionary()
        set openCount to 0
        set activeMeta to missing value
        repeat with i from 0 to (metadata's |count|() as integer) - 1
            set tabMeta to metadata's objectAtIndex:i
            set tabURL to tabMeta's objectForKey:"url"
            set tabID to tabMeta's objectForKey:"id"
            set tabIndex to tabMeta's objectForKey:"index"
            if tabURL is missing value or tabID is missing value or tabIndex is missing value then error "Missing tab identity"
            if not ((tabURL's isKindOfClass:(current application's NSString)) as boolean) or (tabURL's |length|() as integer) is 0 then error "Invalid tab URL"
            if not ((tabID's isKindOfClass:(current application's NSNumber)) as boolean) or not ((tabIndex's isKindOfClass:(current application's NSNumber)) as boolean) then error "Invalid tab identity type"
            if not ((tabIndex's isEqualToNumber:(current application's NSNumber's numberWithInteger:(tabIndex's integerValue()))) as boolean) then error "Non-integer tab index"
            set tabRank to tabIndex's integerValue() as integer
            if tabRank < 0 or tabRank > 2000 then error "Tab index outside supported range"
            if (ids's containsObject:tabID) as boolean or (indexes's containsIndex:tabRank) as boolean then error "Duplicate extension ID or index"
            if not (((tabMeta's objectForKey:"windowId")'s isEqualToNumber:windowID) as boolean) then error "Cross-window metadata"
            ids's addObject:tabID
            indexes's addIndex:tabRank
            if (tabMeta's objectForKey:"active") as boolean then
                if activeMeta is not missing value then error "Expected one active tab"
                set activeMeta to tabMeta
            end if
            if (tabMeta's objectForKey:"pinned") as boolean then
                pins's addObject:tabMeta
            else
                set openCount to openCount + 1
                set urlTabs to wanted's objectForKey:tabURL
                if urlTabs is missing value then
                    set urlTabs to current application's NSMutableArray's array()
                    wanted's setObject:urlTabs forKey:tabURL
                end if
                urlTabs's addObject:tabMeta
                metaMap's setObject:tabMeta forKey:(tabID's stringValue())
            end if
        end repeat
        if activeMeta is missing value then error "Expected one active tab"
        if openCount < 1 then error "No movable tabs"
        set matches to {}
        set nativeWindows to current application's NSApplication's sharedApplication()'s orderedWindows()
        repeat with w from 0 to (nativeWindows's |count|() as integer) - 1
            set nativeWindow to nativeWindows's objectAtIndex:w
            if (nativeWindow's respondsToSelector:"currentTabView") as boolean then
                set wrappers to nativeWindow's orderedTabViews()
                -- Restored/suspended tabs make extension indexes differ from
                -- native indexes. Scope is the unique native URL superset with
                -- the same active URL, never an assumed index correspondence.
                set candidateActiveView to nativeWindow's currentTabView()
                set orderMatches to false
                if candidateActiveView is not missing value then set orderMatches to (candidateActiveView's URLString()'s isEqualToString:(activeMeta's objectForKey:"url")) as boolean
                if orderMatches then
                    repeat with outlineView in my findViews(nativeWindow's contentView(), current application's NSOutlineView)
                        set sourceObject to outlineView's dataSource()
                        if (current application's NSStringFromClass(sourceObject's |class|()) as text) is "Orion.VerticalTabsViewController" then
                            set rootItem to my openRoot(sourceObject, outlineView)
                            set rows to my collectRows(sourceObject, outlineView, rootItem, 0)
                            if (count of rows) >= openCount then
                                set counts to current application's NSMutableDictionary's dictionary()
                                set allMatch to true
                                repeat with nativeRow in rows
                                    set u to (item 1 of nativeRow)'s URLString()
                                    set n to counts's objectForKey:u
                                    if n is missing value then set n to current application's NSNumber's numberWithInteger:0
                                    counts's setObject:(current application's NSNumber's numberWithInteger:((n's integerValue() as integer) + 1)) forKey:u
                                end repeat
                                repeat with u in (wanted's allKeys() as list)
                                    set n to counts's objectForKey:u
                                    if n is missing value then
                                        set allMatch to false
                                    else if (n's integerValue() as integer) < ((wanted's objectForKey:u)'s |count|() as integer) then
                                        set allMatch to false
                                    end if
                                end repeat
                                if allMatch then set end of matches to {nativeWindow, contents of outlineView, sourceObject, rootItem, rows, wrappers's |copy|(), counts}
                            end if
                        end if
                    end repeat
                end if
            end if
        end repeat
        if (count of matches) is not 1 then error "Selected group cannot be matched uniquely to a native window"
        set {nativeWindow, outlineView, sourceObject, rootItem, rows, wrappers, nativeCounts} to item 1 of matches
        set itemMap to current application's NSMutableDictionary's dictionary()
        repeat with nativeRow in rows
            set nativeItem to item 1 of nativeRow
            set urlTabs to wanted's objectForKey:(nativeItem's URLString())
            if urlTabs is not missing value then
            if (urlTabs's |count|() as integer) is 1 and ((nativeCounts's objectForKey:(nativeItem's URLString()))'s integerValue() as integer) is 1 then
                set tabMeta to urlTabs's objectAtIndex:0
                itemMap's setObject:nativeItem forKey:((tabMeta's objectForKey:"id")'s stringValue())
            end if
            end if
        end repeat
        set bindingIDs to current application's NSMutableArray's array()
        repeat with i from 0 to (metadata's |count|() as integer) - 1
            set tabMeta to metadata's objectAtIndex:i
            if not ((tabMeta's objectForKey:"pinned") as boolean) then
                if ((nativeCounts's objectForKey:(tabMeta's objectForKey:"url"))'s integerValue() as integer) > 1 then bindingIDs's addObject:(tabMeta's objectForKey:"id")
            end if
        end repeat
        set activeView to nativeWindow's currentTabView()
        set activeWebView to my pageView(nativeWindow, activeView's URLString())
        set scopeObject to current application's NSDictionary's dictionaryWithObjects:{windowID, current application's NSUUID's UUID()'s UUIDString()} forKeys:{"windowId", "groupKey"}
        set my contextItems to {nativeWindow, outlineView, sourceObject, rootItem, itemMap, metaMap, pins, scopeObject, activeView, activeWebView}
        set my identityViews to current application's NSMutableDictionary's dictionary()
        set my identityHistories to current application's NSMutableDictionary's dictionary()
        if (bindingIDs's |count|() as integer) is 0 then
            my assignNativeOnly()
            return my snapshot()
        end if
        set my captureActiveHistory to my pageHistory(activeWebView, activeView's URLString())
        -- Retain native objects in Cocoa containers, never nested AppleScript
        -- property references (which can remain unevaluated OSA specifiers).
        set my captureRows to current application's NSMutableArray's array()
        repeat with rowRef in rows
            set rowValues to contents of rowRef
            set retainedItem to contents of item 1 of rowValues
            set retainedParent to contents of item 2 of rowValues
            set retainedIndex to current application's NSNumber's numberWithInteger:(item 3 of rowValues)
            my captureRows's addObject:(current application's NSDictionary's dictionaryWithObjects:{retainedItem, retainedParent, retainedIndex} forKeys:{"item", "parent", "index"})
        end repeat
        set my captureWrappers to wrappers
        set my captureExpanded to current application's NSMutableArray's array()
        repeat with nativeRow in rows
            my captureExpanded's addObject:(current application's NSNumber's numberWithBool:(outlineView's isItemExpanded:(item 1 of nativeRow)))
        end repeat
        set my captureRootExpanded to outlineView's isItemExpanded:rootItem
        set clipBounds to outlineView's enclosingScrollView()'s contentView()'s |bounds|()
        set my captureScrollPoint to current application's NSValue's valueWithPoint:(item 1 of clipBounds)
        set my captureBindingIDs to bindingIDs
        set my selectedIdentity to missing value
        set my captureToken to current application's NSUUID's UUID()'s UUIDString()
        set my captureDeadline to current application's NSDate's dateWithTimeIntervalSinceNow:30
        return current application's NSDictionary's dictionaryWithObjects:{my captureToken, bindingIDs} forKeys:{"captureToken", "bindingIDs"}
    end capture

    on checkCapture(payload)
        if my captureToken is missing value then error "No identity capture is pending"
        if not (((payload's objectForKey:"token")'s isEqualToString:my captureToken) as boolean) then error "Identity capture token mismatch"
        set {nativeWindow, outlineView, sourceObject, rootItem} to my contextItems
        if not ((current application's NSApplication's sharedApplication()'s |windows|()'s containsObject:nativeWindow) as boolean) then error "Capture window closed"
        if not ((sourceObject's isEqual:(outlineView's dataSource())) as boolean) then error "Native controller changed during identification"
        set wrappers to nativeWindow's orderedTabViews()
        if not ((wrappers's isEqualToArray:my captureWrappers) as boolean) then error "Tab wrappers or order changed during identification"
        set rows to my collectRows(sourceObject, outlineView, rootItem, 0)
        if (count of rows) is not (my captureRows's |count|() as integer) then error "Native tab set changed during identification"
        repeat with i from 1 to count of rows
            set liveRow to item i of rows
            set originalRow to my captureRows's objectAtIndex:(i - 1)
            if not (((item 1 of liveRow)'s isEqual:(originalRow's objectForKey:"item")) as boolean) or not (((item 2 of liveRow)'s isEqual:(originalRow's objectForKey:"parent")) as boolean) or (item 3 of liveRow) is not ((originalRow's objectForKey:"index") as integer) then error "Tree changed during identification"
        end repeat
        set my captureDeadline to current application's NSDate's dateWithTimeIntervalSinceNow:30
    end checkCapture

    on selectIdentity(payload)
        my checkCapture(payload)
        if my selectedIdentity is not missing value then error "Confirm the previous identity first"
        set tabID to payload's objectForKey:"id"
        if not ((my captureBindingIDs's containsObject:tabID) as boolean) then error "Identity outside duplicate scope"
        set tabMeta to (item 6 of my contextItems)'s objectForKey:(tabID's stringValue())
        if ((item 5 of my contextItems)'s objectForKey:(tabID's stringValue())) is not missing value then error "Identity already bound"
        -- The client activates the actual WebExtension ID after this reply,
        -- then confirms it through a fresh tabs.query before native binding.
        set my selectedIdentity to tabID
        return current application's NSDictionary's dictionaryWithObject:tabID forKey:"selectedID"
    end selectIdentity

    on confirmIdentity(payload)
        my checkCapture(payload)
        set tabID to payload's objectForKey:"id"
        if my selectedIdentity is missing value then error "Select a native identity first"
        if not ((tabID's isEqualToNumber:my selectedIdentity) as boolean) or not (((payload's objectForKey:"activeId")'s isEqualToNumber:tabID) as boolean) then error "Extension did not confirm the selected ID"
        set {nativeWindow, outlineView, sourceObject, rootItem, itemMap, metaMap} to my contextItems
        set keyText to tabID's stringValue()
        set tabMeta to metaMap's objectForKey:keyText
        set wrapper to nativeWindow's currentTabView()
        if not ((my captureWrappers's containsObject:wrapper) as boolean) then error "Selected wrapper is not an original object"
        if not ((wrapper's URLString()'s isEqualToString:(tabMeta's objectForKey:"url")) as boolean) then error "Active wrapper URL mismatch"
        set selectedRow to outlineView's selectedRow() as integer
        if selectedRow < 0 then error "Selected duplicate has no native row"
        set nativeItem to outlineView's itemAtRow:selectedRow
        if not ((nativeItem's respondsToSelector:"URLString") as boolean) then error "Selected row is not a tab"
        if not ((nativeItem's URLString()'s isEqualToString:(tabMeta's objectForKey:"url")) as boolean) then error "Selected duplicate URL mismatch"
        set found to false
        repeat with i from 0 to (my captureRows's |count|() as integer) - 1
            set originalRow to my captureRows's objectAtIndex:i
            if ((originalRow's objectForKey:"item")'s isEqual:nativeItem) as boolean then set found to true
        end repeat
        if not found then error "Selected item is outside the retained Open Tabs objects"
        if my keyForItem(nativeItem, itemMap) is not missing value then error "Two extension IDs resolved to one native object"
        set webView to my pageView(nativeWindow, nativeItem's URLString())
        if webView is not missing value then my identityViews's setObject:webView forKey:keyText
        my identityHistories's setObject:(my pageHistory(webView, nativeItem's URLString())) forKey:keyText
        itemMap's setObject:nativeItem forKey:keyText
        set my selectedIdentity to missing value
        return current application's NSDictionary's dictionaryWithObject:tabID forKey:"boundID"
    end confirmIdentity

    on restoreCaptureUI()
        if my captureToken is missing value then return
        set {nativeWindow, outlineView, sourceObject, rootItem, ignoredItems, ignoredMeta, ignoredPins, ignoredScope, activeView} to my contextItems
        if not ((current application's NSApplication's sharedApplication()'s |windows|()'s containsObject:nativeWindow) as boolean) then error "Original capture window is closed"
        if not ((nativeWindow's orderedTabViews()'s containsObject:activeView) as boolean) then error "Original active tab no longer exists"
        nativeWindow's setCurrentTabView:activeView
        if not ((nativeWindow's currentTabView()'s isEqual:activeView) as boolean) then error "Original active tab restoration failed"
        repeat with i from (my captureRows's |count|() as integer) - 1 to 0 by -1
            set nativeItem to (my captureRows's objectAtIndex:i)'s objectForKey:"item"
            if (outlineView's rowForItem:nativeItem) as integer >= 0 or ((nativeWindow's orderedTabViews()'s isEqualToArray:my captureWrappers) as boolean) then
                if (my captureExpanded's objectAtIndex:i) as boolean then
                    outlineView's expandItem:nativeItem
                else
                    outlineView's collapseItem:nativeItem
                end if
            end if
        end repeat
        if my captureRootExpanded as boolean then
            outlineView's expandItem:rootItem
        else
            outlineView's collapseItem:rootItem
        end if
        repeat with i from 0 to (my captureRows's |count|() as integer) - 1
            set nativeItem to (my captureRows's objectAtIndex:i)'s objectForKey:"item"
            if ((outlineView's isItemExpanded:nativeItem) as boolean) is not ((my captureExpanded's objectAtIndex:i) as boolean) then error "Original collapsed/expanded state was not restored"
        end repeat
        if ((outlineView's isItemExpanded:rootItem) as boolean) is not (my captureRootExpanded as boolean) then error "Open Tabs section expansion was not restored"
        set clipView to outlineView's enclosingScrollView()'s contentView()
        clipView's scrollToPoint:(my captureScrollPoint's pointValue())
        outlineView's enclosingScrollView()'s reflectScrolledClipView:clipView
    end restoreCaptureUI

    on cancelCapture(payload)
        -- Idempotent cancellation also handles a reply lost after finish/watchdog.
        if my captureToken is missing value then return current application's NSDictionary's dictionaryWithObject:true forKey:"cancelled"
        if not (((payload's objectForKey:"token")'s isEqualToString:my captureToken) as boolean) then error "Identity capture token mismatch"
        my restoreCaptureUI()
        set my captureToken to missing value
        set my contextItems to missing value
        set my selectedIdentity to missing value
        return current application's NSDictionary's dictionaryWithObject:true forKey:"cancelled"
    end cancelCapture

    on finishCapture(payload)
        my checkCapture(payload)
        if my selectedIdentity is not missing value then error "An identity is not confirmed"
        set itemMap to item 5 of my contextItems
        set metaMap to item 6 of my contextItems
        if (itemMap's |count|() as integer) is not (metaMap's |count|() as integer) then error "Not all extension identities are confirmed"
        my assignNativeOnly()
        my restoreCaptureUI()
        set activeView to item 9 of my contextItems
        if not (((my pageHistory(item 10 of my contextItems, activeView's URLString()))'s isEqualToDictionary:my captureActiveHistory) as boolean) then error "Original active history changed during identification"
        set my captureToken to missing value
        return my snapshot()
    end finishCapture

    on assignNativeOnly()
        -- Suspended Orion tabs are absent from WebExtension tabs.query. Give
        -- their retained native objects session-local IDs, without activation,
        -- navigation or any guess about persisted/WebExtension identity.
        set {nativeWindow, outlineView, sourceObject, rootItem, itemMap, metaMap} to my contextItems
        set rows to my collectRows(sourceObject, outlineView, rootItem, 0)
        set ordinal to 0
        repeat with nativeRow in rows
            set nativeItem to contents of item 1 of nativeRow
            if my keyForItem(nativeItem, itemMap) is missing value then
                set ordinal to ordinal + 1
                set nativeID to current application's NSNumber's numberWithInteger:(-ordinal)
                repeat while (metaMap's objectForKey:(nativeID's stringValue())) is not missing value
                    set ordinal to ordinal + 1
                    set nativeID to current application's NSNumber's numberWithInteger:(-ordinal)
                end repeat
                set keyText to "native-" & ordinal
                set nativeURL to nativeItem's URLString()
                if nativeURL is missing value then error "Suspended tab has no URL"
                if (nativeURL's |length|() as integer) is 0 then error "Suspended tab URL is still loading"
                set tabMeta to current application's NSDictionary's dictionaryWithObjects:{nativeID, nativeURL, false, true} forKeys:{"id", "url", "active", "nativeOnly"}
                itemMap's setObject:nativeItem forKey:keyText
                metaMap's setObject:tabMeta forKey:keyText
            end if
        end repeat
    end assignNativeOnly

    on keyForItem(nativeItem, itemMap)
        repeat with keyText in (itemMap's allKeys() as list)
            if ((itemMap's objectForKey:keyText)'s isEqual:nativeItem) as boolean then return contents of keyText
        end repeat
        return missing value
    end keyForItem

    on snapshot()
        if my captureToken is not missing value then error "Duplicate identities are not confirmed yet"
        if my contextItems is missing value then error "Read the selected group first"
        set {nativeWindow, outlineView, sourceObject, rootItem, itemMap, metaMap, pins, scopeObject, activeView} to my contextItems
        if not ((current application's NSApplication's sharedApplication()'s |windows|()'s containsObject:nativeWindow) as boolean) then error "Selected window closed"
        if not ((sourceObject's isEqual:(outlineView's dataSource())) as boolean) then error "Native controller changed"
        if not ((nativeWindow's currentTabView()'s isEqual:activeView) as boolean) then error "Active tab changed; read the group again"
        set nativeRows to my collectRows(sourceObject, outlineView, rootItem, 0)
        if (count of nativeRows) is not (itemMap's |count|() as integer) then error "Native tab set changed"
        set tabsArray to current application's NSMutableArray's array()
        repeat with nativeRow in nativeRows
            set {nativeItem, parentItem, siblingIndex} to contents of nativeRow
            set keyText to my keyForItem(nativeItem, itemMap)
            if keyText is missing value then error "Native tab object changed"
            set tabMeta to metaMap's objectForKey:keyText
            if not ((nativeItem's URLString()'s isEqualToString:(tabMeta's objectForKey:"url")) as boolean) then error "Tab navigated; read the group again"
            set parentKey to current application's NSNull's |null|()
            if not ((parentItem's isEqual:rootItem) as boolean) then
                set parentKey to my keyForItem(parentItem, itemMap)
                if parentKey is missing value then error "Parent outside selected group"
            end if
            set rowObject to current application's NSDictionary's dictionaryWithObjects:{tabMeta's objectForKey:"id", keyText, nativeItem's displayName(), nativeItem's URLString(), parentKey, siblingIndex, false, tabMeta's objectForKey:"active", outlineView's isItemExpanded:nativeItem} forKeys:{"id", "key", "title", "url", "parentKey", "index", "pinned", "active", "expanded"}
            set originFlag to tabMeta's objectForKey:"nativeOnly"
            if originFlag is not missing value then
                set nativeRowObject to rowObject's mutableCopy()
                nativeRowObject's setObject:originFlag forKey:"nativeOnly"
                tabsArray's addObject:nativeRowObject
            else
                tabsArray's addObject:rowObject
            end if
        end repeat
        repeat with pinIndex from 0 to (pins's |count|() as integer) - 1
            set tabMeta to pins's objectAtIndex:pinIndex
            set keyText to "pinned-" & ((tabMeta's objectForKey:"id")'s stringValue() as text)
            if my directNativeMode then set keyText to "native-" & (-((tabMeta's objectForKey:"id") as integer))
            set pinTitle to tabMeta's objectForKey:"title"
            if pinTitle is missing value then set pinTitle to "Pinned tab"
            set rowObject to current application's NSDictionary's dictionaryWithObjects:{tabMeta's objectForKey:"id", keyText, pinTitle, tabMeta's objectForKey:"url", current application's NSNull's |null|(), tabMeta's objectForKey:"index", true, tabMeta's objectForKey:"active", false} forKeys:{"id", "key", "title", "url", "parentKey", "index", "pinned", "active", "expanded"}
            if my directNativeMode then
                set rowObject to rowObject's mutableCopy()
                rowObject's setObject:true forKey:"nativeOnly"
            end if
            tabsArray's addObject:rowObject
        end repeat
        if my directNativeMode then
            set currentPins to my nativePinnedWrappers(nativeWindow, nativeRows)
            if (count of currentPins) is not (my capturedPinnedObjects's |count|() as integer) then error "Pinned tab membership changed"
            repeat with i from 1 to count of currentPins
                if not (((item i of currentPins)'s isEqual:(my capturedPinnedObjects's objectAtIndex:(i - 1))) as boolean) then error "Pinned object or order changed"
                if not (((item i of currentPins)'s URLString()'s isEqual:((pins's objectAtIndex:(i - 1))'s objectForKey:"url")) as boolean) then error "Pinned tab navigated"
            end repeat
        end if
        set activeWebView to contents of item 10 of my contextItems
        if activeWebView is not missing value then
            if not ((activeWebView's |window|()'s isEqual:nativeWindow) as boolean) then error "Active page view changed"
        end if
        set historyObject to my pageHistory(activeWebView, activeView's URLString())
        set stateObject to current application's NSMutableDictionary's dictionaryWithObjects:{scopeObject, tabsArray, historyObject, outlineView's isItemExpanded:rootItem} forKeys:{"scope", "tabs", "activeHistory", "rootExpanded"}
        if my directNativeMode then
            stateObject's setObject:"native-session" forKey:"identityMode"
            stateObject's setObject:my selectionWrapperToken forKey:"selectionWrapperToken"
        end if
        if my identityHistories is not missing value then
            repeat with keyText in (my identityHistories's allKeys() as list)
                set webView to my identityViews's objectForKey:keyText
                set tabMeta to metaMap's objectForKey:keyText
                if not (((my pageHistory(webView, tabMeta's objectForKey:"url"))'s isEqualToDictionary:(my identityHistories's objectForKey:keyText)) as boolean) then error "Duplicate navigation history changed"
            end repeat
            if (my identityHistories's |count|() as integer) > 0 then stateObject's setObject:my identityHistories forKey:"identityHistories"
        end if
        stateObject's setObject:(my jsonText(stateObject)) forKey:"revision"
        return stateObject
    end snapshot

    on moveItem(nativeItem, parentItem, siblingIndex)
        set {ignoredWindow, outlineView, sourceObject} to my contextItems
        set zeroPoint to current application's NSMakePoint(0, 0)
        sourceObject's outlineView:outlineView draggingSession:(missing value) willBeginAtPoint:zeroPoint forItems:{nativeItem}
        try
            set accepted to sourceObject's outlineView:outlineView acceptDrop:(missing value) |item|:parentItem childIndex:siblingIndex
        on error errorText number errorNumber
            sourceObject's outlineView:outlineView draggingSession:(missing value) endedAtPoint:zeroPoint operation:0
            error errorText number errorNumber
        end try
        sourceObject's outlineView:outlineView draggingSession:(missing value) endedAtPoint:zeroPoint operation:16
        if not (accepted as boolean) then error "Native move rejected"
    end moveItem

    on appendItem(nativeItem, parentItem)
        set outlineView to item 2 of my contextItems
        set sourceObject to item 3 of my contextItems
        set childCount to (sourceObject's outlineView:outlineView numberOfChildrenOfItem:parentItem) as integer
        if childCount > 0 then
            set lastItem to sourceObject's outlineView:outlineView child:(childCount - 1) ofItem:parentItem
            if (lastItem's isEqual:nativeItem) as boolean then return
        end if
        my moveItem(nativeItem, parentItem, -1)
    end appendItem

    on writeJournal(phaseText, targetObject)
        set journalObject to current application's NSMutableDictionary's dictionaryWithObjects:{1, phaseText, my beforeSnapshot, my sessionKey} forKeys:{"version", "phase", "before", "sessionKey"}
        if targetObject is not missing value then journalObject's setObject:targetObject forKey:"target"
        if my persistentIdentity is not missing value then journalObject's setObject:my persistentIdentity forKey:"identity"
        set jsonData to current application's NSJSONSerialization's dataWithJSONObject:journalObject options:2 |error|:(missing value)
        if not ((jsonData's writeToFile:journalPath options:1 |error|:(missing value)) as boolean) then error "Could not save recovery journal; operation stopped"
    end writeJournal

    on validateNodes(nodes)
        set itemMap to item 5 of my contextItems
        if not ((nodes's isKindOfClass:(current application's NSArray)) as boolean) then error "Invalid plan nodes"
        if (nodes's |count|() as integer) is not (itemMap's |count|() as integer) then error "Plan omits native tabs"
        set nodeMap to current application's NSMutableDictionary's dictionary()
        set siblingSets to current application's NSMutableDictionary's dictionary()
        repeat with nodeIndex from 0 to (nodes's |count|() as integer) - 1
            set nodeObject to nodes's objectAtIndex:nodeIndex
            set keyText to nodeObject's objectForKey:"key"
            set parentKey to nodeObject's objectForKey:"parentKey"
            set siblingIndex to nodeObject's objectForKey:"index"
            if keyText is missing value or parentKey is missing value or siblingIndex is missing value then error "Incomplete node"
            if not ((keyText's isKindOfClass:(current application's NSString)) as boolean) then error "Invalid native key type"
            if not ((siblingIndex's isKindOfClass:(current application's NSNumber)) as boolean) then error "Invalid sibling index type"
            set expandedFlag to nodeObject's objectForKey:"expanded"
            if expandedFlag is missing value then error "Missing expanded state"
            if (current application's NSStringFromClass(expandedFlag's |class|()) as text) is not "__NSCFBoolean" then error "Invalid expanded state type"
            if (itemMap's objectForKey:keyText) is missing value or (nodeMap's objectForKey:keyText) is not missing value then error "Unknown or repeated native key"
            set tabMeta to (item 6 of my contextItems)'s objectForKey:keyText
            if not (((nodeObject's objectForKey:"id")'s isEqualToNumber:(tabMeta's objectForKey:"id")) as boolean) then error "ID/key mismatch"
            if (siblingIndex's integerValue() as integer) < 0 or (siblingIndex's integerValue() as integer) > 2000 then error "Invalid sibling index"
            if not ((siblingIndex's isEqualToNumber:(current application's NSNumber's numberWithInteger:(siblingIndex's integerValue()))) as boolean) then error "Non-integer sibling index"
            set siblingKey to "root"
            if not ((parentKey's isKindOfClass:(current application's NSNull)) as boolean) then
                if not ((parentKey's isKindOfClass:(current application's NSString)) as boolean) then error "Invalid parent key type"
                if (itemMap's objectForKey:parentKey) is missing value then error "Parent outside selected group"
                set siblingKey to parentKey
            end if
            set indexSet to siblingSets's objectForKey:siblingKey
            if indexSet is missing value then
                set indexSet to current application's NSMutableIndexSet's indexSet()
                siblingSets's setObject:indexSet forKey:siblingKey
            end if
            if (indexSet's containsIndex:(siblingIndex's integerValue())) as boolean then error "Duplicate sibling position"
            indexSet's addIndex:(siblingIndex's integerValue())
            nodeMap's setObject:nodeObject forKey:keyText
        end repeat
        repeat with indexSet in (siblingSets's allValues() as list)
            if (indexSet's firstIndex() as integer) is not 0 or (indexSet's lastIndex() as integer) is not ((indexSet's |count|() as integer) - 1) then error "Non-contiguous sibling order"
        end repeat
        repeat with nodeIndex from 0 to (nodes's |count|() as integer) - 1
            set nodeObject to nodes's objectAtIndex:nodeIndex
            set visited to current application's NSMutableSet's setWithObject:(nodeObject's objectForKey:"key")
            set parentKey to nodeObject's objectForKey:"parentKey"
            set depth to 1
            repeat while not ((parentKey's isKindOfClass:(current application's NSNull)) as boolean)
                if (visited's containsObject:parentKey) as boolean then error "Native plan cycle"
                visited's addObject:parentKey
                set depth to depth + 1
                if depth > 8 then error "Native depth limit"
                set parentKey to (nodeMap's objectForKey:parentKey)'s objectForKey:"parentKey"
            end repeat
        end repeat
        return nodeMap
    end validateNodes

    on placeChildren(nodes, parentKey, parentItem)
        set childrenArray to current application's NSMutableArray's array()
        repeat with nodeIndex from 0 to (nodes's |count|() as integer) - 1
            set nodeObject to nodes's objectAtIndex:nodeIndex
            if ((nodeObject's objectForKey:"parentKey")'s isEqual:parentKey) as boolean then childrenArray's addObject:nodeObject
        end repeat
        set sortDescriptor to current application's NSSortDescriptor's sortDescriptorWithKey:"index" ascending:true
        childrenArray's sortUsingDescriptors:{sortDescriptor}
        repeat with childIndex from 0 to (childrenArray's |count|() as integer) - 1
            set nodeObject to childrenArray's objectAtIndex:childIndex
            set keyText to nodeObject's objectForKey:"key"
            set nativeItem to (item 5 of my contextItems)'s objectForKey:keyText
            -- Appending in desired sibling order avoids before-removal index ambiguity.
            my appendItem(nativeItem, parentItem)
            my placeChildren(nodes, keyText, nativeItem)
        end repeat
    end placeChildren

    on applyLayout(nodes)
        my validateNodes(nodes)
        set {nativeWindow, outlineView, sourceObject, rootItem, itemMap} to my contextItems
        set rows to my collectRows(sourceObject, outlineView, rootItem, 0)
        -- Detach deepest descendants first, retaining each actual native object.
        repeat with rowIndex from (count of rows) to 1 by -1
            set nativeRow to item rowIndex of rows
            if not (((item 2 of nativeRow)'s isEqual:rootItem) as boolean) then my moveItem(item 1 of nativeRow, rootItem, -1)
        end repeat
        my placeChildren(nodes, current application's NSNull's |null|(), rootItem)
        repeat with nodeIndex from 0 to (nodes's |count|() as integer) - 1
            set nodeObject to nodes's objectAtIndex:nodeIndex
            set nativeItem to itemMap's objectForKey:(nodeObject's objectForKey:"key")
            if (nodeObject's objectForKey:"expanded") as boolean then
                outlineView's expandItem:nativeItem
            else
                outlineView's collapseItem:nativeItem
            end if
        end repeat
        if my beforeSnapshot is not missing value then
            if (my beforeSnapshot's objectForKey:"rootExpanded") as boolean then
                outlineView's expandItem:rootItem
            else
                outlineView's collapseItem:rootItem
            end if
        end if
        set activeView to item 9 of my contextItems
        if not ((nativeWindow's currentTabView()'s isEqual:activeView) as boolean) then
            if not ((nativeWindow's orderedTabViews()'s containsObject:activeView) as boolean) then error "Original active view no longer belongs to the window"
            nativeWindow's setCurrentTabView:activeView
        end if
        set liveSnapshot to my snapshot()
        if my beforeSnapshot is not missing value then
            if not (((liveSnapshot's objectForKey:"activeHistory")'s isEqualToDictionary:(my beforeSnapshot's objectForKey:"activeHistory")) as boolean) then error "Active navigation history changed"
        end if
        set liveMap to current application's NSMutableDictionary's dictionary()
        set liveTabs to liveSnapshot's objectForKey:"tabs"
        repeat with liveIndex from 0 to (liveTabs's |count|() as integer) - 1
            set liveNode to liveTabs's objectAtIndex:liveIndex
            if not ((liveNode's objectForKey:"pinned") as boolean) then liveMap's setObject:liveNode forKey:(liveNode's objectForKey:"key")
        end repeat
        repeat with nodeIndex from 0 to (nodes's |count|() as integer) - 1
            set nodeObject to nodes's objectAtIndex:nodeIndex
            set liveNode to liveMap's objectForKey:(nodeObject's objectForKey:"key")
            repeat with fieldName in {"parentKey", "index", "expanded"}
                if not (((liveNode's objectForKey:fieldName)'s isEqual:(nodeObject's objectForKey:fieldName)) as boolean) then error "Native layout verification failed"
            end repeat
        end repeat
        return liveSnapshot
    end applyLayout

    on movableNodes(snapshotObject)
        set nodes to current application's NSMutableArray's array()
        set snapshotTabs to snapshotObject's objectForKey:"tabs"
        repeat with snapshotIndex from 0 to (snapshotTabs's |count|() as integer) - 1
            set tabObject to snapshotTabs's objectAtIndex:snapshotIndex
            if not ((tabObject's objectForKey:"pinned") as boolean) then nodes's addObject:tabObject
        end repeat
        return nodes
    end movableNodes

    on refreshIdentity(payload)
        my snapshot()
        set my identityRequestedAt to current application's NSDate's |date|()
        set my persistentIdentity to missing value
        current application's NSNotificationCenter's defaultCenter()'s postNotificationName:"TabStateDidUpdated" object:(missing value)
        return current application's NSDictionary's dictionaryWithObject:true forKey:"requested"
    end refreshIdentity

    on beginExposure(savedCandidates)
        if my captureToken is not missing value then error "Identity capture already pending"
        if my beforeSnapshot is not missing value then error "Undo the current sort before exposing sleeping duplicates"
        my snapshot()
        set {nativeWindow, outlineView, sourceObject, rootItem, itemMap, metaMap, pins, scopeObject, activeView, activeWebView} to my contextItems
        set rows to my collectRows(sourceObject, outlineView, rootItem, 0)
        set my captureRows to current application's NSMutableArray's array()
        set my captureExpanded to current application's NSMutableArray's array()
        repeat with nativeRow in rows
            set {nativeItem, parentItem, siblingIndex} to contents of nativeRow
            my captureRows's addObject:(current application's NSDictionary's dictionaryWithObjects:{nativeItem, parentItem, current application's NSNumber's numberWithInteger:siblingIndex} forKeys:{"item", "parent", "index"})
            my captureExpanded's addObject:(current application's NSNumber's numberWithBool:(outlineView's isItemExpanded:nativeItem))
        end repeat
        set my captureWrappers to nativeWindow's orderedTabViews()'s |copy|()
        set my captureRootExpanded to outlineView's isItemExpanded:rootItem
        set clipBounds to outlineView's enclosingScrollView()'s contentView()'s |bounds|()
        set my captureScrollPoint to current application's NSValue's valueWithPoint:(item 1 of clipBounds)
        set my captureActiveHistory to my pageHistory(activeWebView, activeView's URLString())
        set my captureBindingIDs to current application's NSMutableArray's array()
        set my exposureCandidates to current application's NSMutableDictionary's dictionary()
        repeat with i from 0 to (savedCandidates's |count|() as integer) - 1
            set candidate to savedCandidates's objectAtIndex:i
            set candidateID to candidate's objectForKey:"tabId"
            if candidateID is missing value or (candidate's objectForKey:"localTabIdentifier") is missing value then error "Missing saved candidate identity"
            my captureBindingIDs's addObject:candidateID
            my exposureCandidates's setObject:candidate forKey:(candidateID's stringValue())
        end repeat
        set my selectedIdentity to missing value
        set my captureToken to current application's NSUUID's UUID()'s UUIDString()
        set my captureDeadline to current application's NSDate's dateWithTimeIntervalSinceNow:30
        set selectionIndexes to current application's NSMutableArray's array()
        repeat with i from 0 to (my captureWrappers's |count|() as integer) - 1
            set wrapper to my captureWrappers's objectAtIndex:i
            repeat with j from 0 to (savedCandidates's |count|() as integer) - 1
                if ((wrapper's URLString()'s isEqual:((savedCandidates's objectAtIndex:j)'s objectForKey:"url")) as boolean) then
                    selectionIndexes's addObject:(current application's NSNumber's numberWithInteger:i)
                    exit repeat
                end if
            end repeat
        end repeat
        if (selectionIndexes's |count|() as integer) is not (savedCandidates's |count|() as integer) then error "Native/saved duplicate candidate counts differ"
        return current application's NSDictionary's dictionaryWithObjects:{my captureToken, my captureBindingIDs, selectionIndexes} forKeys:{"exposureToken", "bindingIDs", "nativeSelections"}
    end beginExposure

    on selectExposure(payload)
        my checkCapture(payload)
        if my exposureCandidates is missing value or my selectedIdentity is not missing value then error "Exposure selection unavailable"
        set selectionIndex to payload's objectForKey:"id"
        set idx to selectionIndex as integer
        if idx < 0 or idx >= (my captureWrappers's |count|() as integer) then error "Native selection outside original wrappers"
        set wrapper to my captureWrappers's objectAtIndex:idx
        set candidates to my exposureCandidates's allValues()
        set allowed to false
        repeat with i from 0 to (candidates's |count|() as integer) - 1
            if ((wrapper's URLString()'s isEqual:((candidates's objectAtIndex:i)'s objectForKey:"url")) as boolean) then set allowed to true
        end repeat
        if not allowed then error "Native selection outside duplicate scope"
        set my selectedIdentity to selectionIndex
        set nativeWindow to item 1 of my contextItems
        nativeWindow's setCurrentTabView:wrapper
        if not ((nativeWindow's currentTabView()'s isEqual:wrapper) as boolean) then error "Native duplicate selection failed"
        return current application's NSDictionary's dictionaryWithObject:true forKey:"selected"
    end selectExposure

    on confirmExposure(payload)
        my checkCapture(payload)
        if my exposureCandidates is missing value then error "No sleeping duplicate exposure pending"
        set tabID to payload's objectForKey:"id"
        if my selectedIdentity is missing value then error "Select a candidate first"
        if not ((tabID's isEqualToNumber:my selectedIdentity) as boolean) then error "Candidate activation not confirmed"
        set candidate to my exposureCandidates's objectForKey:((payload's objectForKey:"activeId")'s stringValue())
        if candidate is missing value then error "Candidate outside saved scope"
        set {nativeWindow, outlineView, sourceObject, rootItem, itemMap} to my contextItems
        set wrapper to nativeWindow's currentTabView()
        if not ((wrapper's isEqual:(my captureWrappers's objectAtIndex:(my selectedIdentity as integer))) as boolean) then error "Activated wrapper differs from selected native object"
        if not ((wrapper's URLString()'s isEqual:(candidate's objectForKey:"url")) as boolean) then error "Activated candidate URL differs"
        set selectedRow to outlineView's selectedRow() as integer
        if selectedRow < 0 then error "Activated candidate has no native row"
        set nativeItem to outlineView's itemAtRow:selectedRow
        set keyText to my keyForItem(nativeItem, itemMap)
        if keyText is missing value then error "Activated candidate outside retained native scope"
        if not ((nativeItem's URLString()'s isEqual:(candidate's objectForKey:"url")) as boolean) then error "Native candidate URL differs"
        set tabUUID to candidate's objectForKey:"localTabIdentifier"
        if my nativeUUIDBindings is missing value then set my nativeUUIDBindings to current application's NSMutableDictionary's dictionary()
        set previousUUID to my nativeUUIDBindings's objectForKey:keyText
        if previousUUID is not missing value then
            if not ((previousUUID's isEqual:tabUUID) as boolean) then error "Two saved IDs selected one native object"
        end if
        set boundKeys to my nativeUUIDBindings's allKeys()
        repeat with i from 0 to (boundKeys's |count|() as integer) - 1
            set otherKey to boundKeys's objectAtIndex:i
            if not ((otherKey's isEqual:keyText) as boolean) then
                if ((my nativeUUIDBindings's objectForKey:otherKey)'s isEqual:tabUUID) as boolean then error "Saved UUID already bound to another native object"
            end if
        end repeat
        my nativeUUIDBindings's setObject:tabUUID forKey:keyText
        set my selectedIdentity to missing value
        return current application's NSDictionary's dictionaryWithObject:true forKey:"confirmed"
    end confirmExposure

    on finishExposure(payload)
        my checkCapture(payload)
        if my exposureCandidates is missing value or my selectedIdentity is not missing value then error "Sleeping duplicate exposure incomplete"
        set candidates to my exposureCandidates's allValues()
        if my nativeUUIDBindings is missing value then error "No candidate identities confirmed"
        set confirmedUUIDs to my nativeUUIDBindings's allValues()
        repeat with i from 0 to (candidates's |count|() as integer) - 1
            set candidate to candidates's objectAtIndex:i
            if not ((confirmedUUIDs's containsObject:(candidate's objectForKey:"localTabIdentifier")) as boolean) then error "Sleeping duplicate candidate not confirmed"
        end repeat
        my restoreCaptureUI()
        set activeView to item 9 of my contextItems
        if not (((my pageHistory(item 10 of my contextItems, activeView's URLString()))'s isEqualToDictionary:my captureActiveHistory) as boolean) then error "Original active history changed during exposure"
        set my captureToken to missing value
        set my exposureCandidates to missing value
        return my snapshot()
    end finishExposure

    on readPersistentIdentity(payload)
        if my identityRequestedAt is missing value then error "Request a fresh identity snapshot first"
        set liveSnapshot to my snapshot()
        set statePath to "@@ORION_STATE@@"
        set fileManager to current application's NSFileManager's defaultManager()
        set attributes to fileManager's attributesOfItemAtPath:statePath |error|:(missing value)
        if attributes is missing value then error "Saved browser state missing"
        set modifiedAt to attributes's objectForKey:(current application's NSFileModificationDate)
        if (modifiedAt's compare:my identityRequestedAt) as integer < 0 then error "Identity snapshot is not fresh yet"
        set stateData to current application's NSData's dataWithContentsOfFile:statePath
        set savedWindows to current application's NSPropertyListSerialization's propertyListWithData:stateData options:0 format:(missing value) |error|:(missing value)
        if savedWindows is missing value then error "Unreadable saved identity snapshot"
        set scopeID to (liveSnapshot's objectForKey:"scope")'s objectForKey:"windowId"
        set matches to current application's NSMutableArray's array()
        repeat with i from 0 to (savedWindows's |count|() as integer) - 1
            set savedWindow to savedWindows's objectAtIndex:i
            if ((scopeID's isEqual:(savedWindow's objectForKey:"windowID")) as boolean) then matches's addObject:savedWindow
        end repeat
        if (matches's |count|() as integer) is not 1 then error "Saved window ID is ambiguous"
        set savedWindow to matches's objectAtIndex:0
        set windowUUID to savedWindow's objectForKey:"localWindowID"
        if windowUUID is missing value then error "Persistent window UUID missing"
        set savedTabs to savedWindow's objectForKey:"tabStates"
        set liveTabs to liveSnapshot's objectForKey:"tabs"
        set liveByKey to current application's NSMutableDictionary's dictionary()
        set savedByID to current application's NSMutableDictionary's dictionary()
        repeat with i from 0 to (savedTabs's |count|() as integer) - 1
            set savedTab to savedTabs's objectAtIndex:i
            if (savedTab's objectForKey:"isPinned") as boolean then error "Unexpected pinned object in saved open tabs"
            set savedID to savedTab's objectForKey:"tabId"
            if savedID is missing value then error "Saved numeric identity missing"
            set savedKey to savedID's stringValue()
            if (savedByID's objectForKey:savedKey) is not missing value then error "Duplicate saved numeric identity"
            savedByID's setObject:savedTab forKey:savedKey
        end repeat
        set bindings to current application's NSMutableArray's array()
        set uuidByKey to current application's NSMutableDictionary's dictionary()
        set savedByKey to current application's NSMutableDictionary's dictionary()
        set seenUUIDs to current application's NSMutableSet's |set|()
        repeat with i from 0 to (liveTabs's |count|() as integer) - 1
            set liveTab to liveTabs's objectAtIndex:i
            if not ((liveTab's objectForKey:"pinned") as boolean) then
                set keyText to liveTab's objectForKey:"key"
                set savedTab to missing value
                if (liveTab's objectForKey:"nativeOnly") is missing value then
                    set savedTab to savedByID's objectForKey:((liveTab's objectForKey:"id")'s stringValue())
                else
                    -- Never assign persisted identities by duplicate URL or array position.
                    set urlMatches to current application's NSMutableArray's array()
                    repeat with j from 0 to (savedTabs's |count|() as integer) - 1
                        set candidate to savedTabs's objectAtIndex:j
                        if (((candidate's objectForKey:"url")'s isEqual:(liveTab's objectForKey:"url")) as boolean) then urlMatches's addObject:candidate
                    end repeat
                    if (urlMatches's |count|() as integer) < 1 then error "Native-only tab absent from saved state"
                    if (urlMatches's |count|() as integer) > 1 then
                        set verifiedUUID to missing value
                        if my nativeUUIDBindings is not missing value then set verifiedUUID to my nativeUUIDBindings's objectForKey:keyText
                        if verifiedUUID is missing value then return my beginExposure(urlMatches)
                        repeat with j from 0 to (urlMatches's |count|() as integer) - 1
                            set candidate to urlMatches's objectAtIndex:j
                            if ((candidate's objectForKey:"localTabIdentifier")'s isEqual:verifiedUUID) as boolean then
                                if savedTab is not missing value then error "Duplicate saved UUID"
                                set savedTab to candidate
                            end if
                        end repeat
                    else
                        set savedTab to urlMatches's objectAtIndex:0
                    end if
                end if
                if savedTab is missing value then error "Live ID absent from fresh saved state"
                if not (((savedTab's objectForKey:"url")'s isEqual:(liveTab's objectForKey:"url")) as boolean) then error "Saved URL differs from live ID"
                set tabUUID to savedTab's objectForKey:"localTabIdentifier"
                if tabUUID is missing value then error "Persistent tab UUID missing"
                if (seenUUIDs's containsObject:tabUUID) as boolean then error "Ambiguous persistent tab UUID"
                seenUUIDs's addObject:tabUUID
                uuidByKey's setObject:tabUUID forKey:keyText
                savedByKey's setObject:savedTab forKey:keyText
                liveByKey's setObject:liveTab forKey:keyText
                bindings's addObject:(current application's NSDictionary's dictionaryWithObjects:{keyText, tabUUID} forKeys:{"key", "uuid"})
            end if
        end repeat
        if (bindings's |count|() as integer) is not (savedTabs's |count|() as integer) then error "Saved/live tab membership differs"
        set keyList to liveByKey's allKeys()
        repeat with i from 0 to (keyList's |count|() as integer) - 1
            set keyText to keyList's objectAtIndex:i
            set liveTab to liveByKey's objectForKey:keyText
            set savedTab to savedByKey's objectForKey:keyText
            set parentKey to liveTab's objectForKey:"parentKey"
            set expectedParent to missing value
            if not ((parentKey's isKindOfClass:(current application's NSNull)) as boolean) then set expectedParent to uuidByKey's objectForKey:parentKey
            set savedParent to savedTab's objectForKey:"parentLocalTabIdentifier"
            if expectedParent is missing value then
                if savedParent is not missing value then error "Saved parent differs from live tree"
            else
                if savedParent is missing value then error "Saved parent missing"
                if not ((expectedParent's isEqual:savedParent) as boolean) then error "Saved parent UUID differs from live tree"
            end if
            if ((savedTab's objectForKey:"isActive") as boolean) is not ((liveTab's objectForKey:"active") as boolean) then error "Saved active identity differs from live tree"
        end repeat
        set my persistentIdentity to current application's NSDictionary's dictionaryWithObjects:{windowUUID, bindings, liveSnapshot's objectForKey:"revision"} forKeys:{"windowUUID", "tabs", "revision"}
        return my persistentIdentity
    end readPersistentIdentity

    on archiveCompletedJournal(journalObject, reasonText)
        set archivePath to journalPath & ".completed-" & (current application's NSUUID's UUID()'s UUIDString() as text)
        if not ((current application's NSFileManager's defaultManager()'s copyItemAtPath:journalPath toPath:archivePath |error|:(missing value)) as boolean) then error "Could not archive completed sort"
        set resolved to journalObject's mutableCopy()
        resolved's setObject:"accepted" forKey:"phase"
        resolved's setObject:reasonText forKey:"resolution"
        resolved's setObject:archivePath forKey:"archive"
        set dataObject to current application's NSJSONSerialization's dataWithJSONObject:resolved options:2 |error|:(missing value)
        if not ((dataObject's writeToFile:journalPath options:1 |error|:(missing value)) as boolean) then error "Could not finalize completed sort"
        current application's NSFileManager's defaultManager()'s setAttributes:(current application's NSDictionary's dictionaryWithObject:384 forKey:(current application's NSFilePosixPermissions)) ofItemAtPath:archivePath |error|:(missing value)
        return resolved
    end archiveCompletedJournal

    on recoveryJournal(payload)
        set dataObject to current application's NSData's dataWithContentsOfFile:journalPath
        if dataObject is missing value then error "No recovery journal"
        set journalObject to current application's NSJSONSerialization's JSONObjectWithData:dataObject options:0 |error|:(missing value)
        if journalObject is missing value then error "Unreadable recovery journal"
        set identityObject to journalObject's objectForKey:"identity"
        if identityObject is not missing value and my beforeSnapshot is missing value then
            if ((journalObject's objectForKey:"phase") as text) is "applied" and ((identityObject's objectForKey:"mode") as text) is "native-session" then
                set journalSession to (identityObject's objectForKey:"sessionKey") as text
                if my sessionKey is missing value or (my sessionKey as text) is not journalSession then set journalObject to my archiveCompletedJournal(journalObject, "Completed native sort preserved after session change")
            end if
        end if
        return journalObject
    end recoveryJournal

    on acceptCurrentLayout(payload)
        if my beforeSnapshot is not missing value then error "Use retained Undo before accepting a previous session"
        set journalObject to my recoveryJournal(payload)
        if ((journalObject's objectForKey:"phase") as text) is not "applied" then error "Only a completed applied journal can be accepted"
        if my persistentIdentity is missing value then error "Verify fresh persistent UUIDs before accepting current tree"
        set liveSnapshot to my snapshot()
        if not (((my persistentIdentity's objectForKey:"revision")'s isEqual:(liveSnapshot's objectForKey:"revision")) as boolean) then error "Tree changed after UUID verification"
        if not (((payload's objectForKey:"expectedRevision")'s isEqual:(liveSnapshot's objectForKey:"revision")) as boolean) then error "Acceptance preview changed"
        set oldIdentity to journalObject's objectForKey:"identity"
        if oldIdentity is missing value then error "Journal persistent identity missing"
        if not (((oldIdentity's objectForKey:"windowUUID")'s isEqual:(my persistentIdentity's objectForKey:"windowUUID")) as boolean) then error "Select the original journal window before accepting its current tree"
        set archivePath to journalPath & ".accepted-" & (current application's NSUUID's UUID()'s UUIDString() as text)
        if not ((current application's NSFileManager's defaultManager()'s copyItemAtPath:journalPath toPath:archivePath |error|:(missing value)) as boolean) then error "Could not archive previous journal"
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        set archiveData to current application's NSData's dataWithContentsOfFile:archivePath
        if not ((originalData's isEqualToData:archiveData) as boolean) then error "Journal archive verification failed"
        set resolvedJournal to journalObject's mutableCopy()
        resolvedJournal's setObject:"accepted" forKey:"phase"
        resolvedJournal's setObject:archivePath forKey:"archivePath"
        set dataObject to current application's NSJSONSerialization's dataWithJSONObject:resolvedJournal options:2 |error|:(missing value)
        if not ((dataObject's writeToFile:journalPath options:1 |error|:(missing value)) as boolean) then error "Could not resolve archived journal"
        return current application's NSDictionary's dictionaryWithObjects:{true, archivePath} forKeys:{"accepted", "archivePath"}
    end acceptCurrentLayout

    on recoverLayout(payload)
        set candidateJournal to my recoveryJournal(payload)
        set candidateIdentity to candidateJournal's objectForKey:"identity"
        if candidateIdentity is not missing value then
            if ((candidateIdentity's objectForKey:"mode") as text) is "native-session" then
                if not (((candidateIdentity's objectForKey:"sessionKey")'s isEqual:my sessionKey) as boolean) then error "Этот журнал относится к другой сессии Orion. Текущее дерево можно сохранить, восстановление по этим ID недоступно."
            end if
        end if
        if my beforeSnapshot is not missing value then error "Use retained Undo for this process"
        set journalObject to my recoveryJournal(payload)
        if ((journalObject's objectForKey:"phase") as text) is not in {"prepared", "applied", "undoing", "rollingBack"} then error "Journal is already resolved"
        set oldIdentity to journalObject's objectForKey:"identity"
        if oldIdentity is missing value or my persistentIdentity is missing value then error "Verified persistent identities missing"
        if not (((oldIdentity's objectForKey:"windowUUID")'s isEqual:(my persistentIdentity's objectForKey:"windowUUID")) as boolean) then error "Persistent window differs"
        set liveSnapshot to my snapshot()
        if not (((my persistentIdentity's objectForKey:"revision")'s isEqual:(liveSnapshot's objectForKey:"revision")) as boolean) then error "Live tree changed after persistent identity verification"
        set planObject to payload's objectForKey:"plan"
        if planObject is missing value then error "Recovery preview missing"
        if not (((planObject's objectForKey:"scope")'s isEqual:(liveSnapshot's objectForKey:"scope")) as boolean) then error "Recovery scope differs"
        if not (((planObject's objectForKey:"expectedRevision")'s isEqual:(liveSnapshot's objectForKey:"revision")) as boolean) then error "Recovery revision differs"
        set nodes to planObject's objectForKey:"nodes"
        my validateNodes(nodes)
        set oldUUIDByKey to current application's NSMutableDictionary's dictionary()
        set oldTabByUUID to current application's NSMutableDictionary's dictionary()
        set newUUIDByKey to current application's NSMutableDictionary's dictionary()
        set oldBindings to oldIdentity's objectForKey:"tabs"
        set newBindings to my persistentIdentity's objectForKey:"tabs"
        if (oldBindings's |count|() as integer) is not (newBindings's |count|() as integer) then error "Recovery membership differs"
        repeat with i from 0 to (oldBindings's |count|() as integer) - 1
            set bindingObject to oldBindings's objectAtIndex:i
            oldUUIDByKey's setObject:(bindingObject's objectForKey:"uuid") forKey:(bindingObject's objectForKey:"key")
        end repeat
        repeat with i from 0 to (newBindings's |count|() as integer) - 1
            set bindingObject to newBindings's objectAtIndex:i
            newUUIDByKey's setObject:(bindingObject's objectForKey:"uuid") forKey:(bindingObject's objectForKey:"key")
        end repeat
        set oldTabs to (journalObject's objectForKey:"before")'s objectForKey:"tabs"
        repeat with i from 0 to (oldTabs's |count|() as integer) - 1
            set oldTab to oldTabs's objectAtIndex:i
            if not ((oldTab's objectForKey:"pinned") as boolean) then
                set tabUUID to oldUUIDByKey's objectForKey:(oldTab's objectForKey:"key")
                if tabUUID is missing value then error "Journal tab UUID missing"
                oldTabByUUID's setObject:oldTab forKey:tabUUID
            end if
        end repeat
        repeat with i from 0 to (nodes's |count|() as integer) - 1
            set nodeObject to nodes's objectAtIndex:i
            set keyText to nodeObject's objectForKey:"key"
            set tabUUID to newUUIDByKey's objectForKey:keyText
            if tabUUID is missing value then error "Current UUID missing"
            set oldTab to oldTabByUUID's objectForKey:tabUUID
            if oldTab is missing value then error "UUID outside original tab set"
            set newMeta to (item 6 of my contextItems)'s objectForKey:keyText
            if not (((oldTab's objectForKey:"url")'s isEqual:(newMeta's objectForKey:"url")) as boolean) then error "Original tab URL changed"
            if ((oldTab's objectForKey:"active") as boolean) is not ((newMeta's objectForKey:"active") as boolean) then error "Original active tab changed"
            if not (((oldTab's objectForKey:"index")'s isEqual:(nodeObject's objectForKey:"index")) as boolean) then error "Recovery sibling index differs from journal"
            if not (((oldTab's objectForKey:"expanded")'s isEqual:(nodeObject's objectForKey:"expanded")) as boolean) then error "Recovery expansion differs from journal"
            set oldParent to oldTab's objectForKey:"parentKey"
            set newParent to nodeObject's objectForKey:"parentKey"
            if (oldParent's isKindOfClass:(current application's NSNull)) as boolean then
                if not ((newParent's isKindOfClass:(current application's NSNull)) as boolean) then error "Recovery parent differs"
            else
                if (newParent's isKindOfClass:(current application's NSNull)) as boolean then error "Recovery parent missing"
                if not (((oldUUIDByKey's objectForKey:oldParent)'s isEqual:(newUUIDByKey's objectForKey:newParent)) as boolean) then error "Recovery parent UUID differs"
            end if
        end repeat
        -- Preserve the original journal before the first native mutation.
        set archivePath to journalPath & ".recovery-" & (current application's NSUUID's UUID()'s UUIDString() as text)
        if not ((current application's NSFileManager's defaultManager()'s copyItemAtPath:journalPath toPath:archivePath |error|:(missing value)) as boolean) then error "Could not archive recovery journal"
        set my beforeSnapshot to liveSnapshot
        try
            set restored to my applyLayout(nodes)
            set outlineView to item 2 of my contextItems
            set rootItem to item 4 of my contextItems
            if ((journalObject's objectForKey:"before")'s objectForKey:"rootExpanded") as boolean then
                outlineView's expandItem:rootItem
            else
                outlineView's collapseItem:rootItem
            end if
            set restored to my snapshot()
            set resolvedJournal to journalObject's mutableCopy()
            resolvedJournal's setObject:"recovered" forKey:"phase"
            resolvedJournal's setObject:restored forKey:"recovered"
            set dataObject to current application's NSJSONSerialization's dataWithJSONObject:resolvedJournal options:2 |error|:(missing value)
            if not ((dataObject's writeToFile:journalPath options:1 |error|:(missing value)) as boolean) then error "Could not mark recovery complete"
            set my beforeSnapshot to missing value
            set my appliedSnapshot to missing value
            return restored
        on error errorText
            try
                set rolledBack to my applyLayout(my movableNodes(liveSnapshot))
                if not ((rolledBack's isEqualToDictionary:liveSnapshot) as boolean) then error "Recovery rollback mismatch"
                set my beforeSnapshot to missing value
                error errorText & "; recovery cancelled and original live tree restored"
            on error rollbackError
                error errorText & "; journal retained: " & rollbackError
            end try
        end try
    end recoverLayout

    on credentialOrigin(payload)
        set originText to payload's objectForKey:"origin"
        if originText is missing value or not ((originText's isKindOfClass:(current application's NSString)) as boolean) then error "Invalid Keychain origin"
        set components to current application's NSURLComponents's componentsWithString:originText
        if components is missing value or components's |host|() is missing value then error "Invalid Keychain origin"
        if components's |user|() is not missing value or components's |password|() is not missing value or components's |query|() is not missing value or components's fragment() is not missing value or (components's |path|() as text) is not "" then error "Invalid Keychain origin"
        set schemeText to components's |scheme|() as text
        set hostText to components's |host|() as text
        if schemeText is not "https" and not (schemeText is "http" and hostText is in {"localhost", "127.0.0.1", "::1", "[::1]"}) then error "Invalid Keychain origin"
        return originText
    end credentialOrigin

    on keychainQuote(valueText)
        set escapedText to valueText's stringByReplacingOccurrencesOfString:"\\" withString:"\\\\"
        set escapedText to escapedText's stringByReplacingOccurrencesOfString:"\"" withString:"\\\""
        return "\"" & (escapedText as text) & "\""
    end keychainQuote

    on loadCredential(originText)
        set taskObject to current application's NSTask's alloc()'s init()
        taskObject's setLaunchPath:"/usr/bin/security"
        taskObject's setArguments:{"find-generic-password", "-s", "local.orion-tab-sort.ai.v1", "-a", originText, "-w"}
        set outputPipe to current application's NSPipe's pipe()
        taskObject's setStandardOutput:outputPipe
        taskObject's setStandardError:(current application's NSFileHandle's fileHandleWithNullDevice())
        taskObject's |launch|()
        set outputData to outputPipe's fileHandleForReading()'s readDataToEndOfFile()
        taskObject's waitUntilExit()
        set exitCode to taskObject's terminationStatus() as integer
        if exitCode is 44 then return current application's NSDictionary's dictionaryWithObjects:{true, false} forKeys:{"ok", "found"}
        if exitCode is not 0 then error "macOS Keychain read failed (" & exitCode & ")"
        set keyText to current application's NSString's alloc()'s initWithData:outputData encoding:4
        if keyText is missing value then error "Invalid Keychain value"
        if (keyText's hasSuffix:(character id 10)) as boolean then set keyText to keyText's substringToIndex:((keyText's |length|() as integer) - 1)
        if (keyText's |length|() as integer) < 1 then error "Empty Keychain value"
        return current application's NSDictionary's dictionaryWithObjects:{true, true, keyText} forKeys:{"ok", "found", "key"}
    end loadCredential

    on credentialCommand(commandName, payload)
        set originText to my credentialOrigin(payload)
        if commandName is "loadKey" then return my loadCredential(originText)
        set keyText to payload's objectForKey:"key"
        if keyText is missing value or not ((keyText's isKindOfClass:(current application's NSString)) as boolean) then error "Invalid API key"
        if (keyText's |length|() as integer) < 1 or (keyText's |length|() as integer) > 8192 then error "Invalid API key length"
        set controlChars to current application's NSCharacterSet's controlCharacterSet()
        set keyParts to keyText's componentsSeparatedByCharactersInSet:controlChars
        if (keyParts's |count|() as integer) > 1 then error "Invalid API key characters"
        set inputText to "add-generic-password -U -s \"local.orion-tab-sort.ai.v1\" -a " & my keychainQuote(originText) & " -w " & my keychainQuote(keyText) & (character id 10)
        set taskObject to current application's NSTask's alloc()'s init()
        taskObject's setLaunchPath:"/usr/bin/security"
        taskObject's setArguments:{"-i", "-q"}
        set inputPipe to current application's NSPipe's pipe()
        taskObject's setStandardInput:inputPipe
        taskObject's setStandardOutput:(current application's NSFileHandle's fileHandleWithNullDevice())
        taskObject's setStandardError:(current application's NSFileHandle's fileHandleWithNullDevice())
        taskObject's |launch|()
        inputPipe's fileHandleForWriting()'s writeData:((current application's NSString's stringWithString:inputText)'s dataUsingEncoding:4)
        inputPipe's fileHandleForWriting()'s closeFile()
        taskObject's waitUntilExit()
        set verifiedValue to my loadCredential(originText)
        if not ((verifiedValue's objectForKey:"found") as boolean) then error "macOS Keychain save not confirmed"
        if not (((verifiedValue's objectForKey:"key")'s isEqualToString:keyText) as boolean) then error "macOS Keychain saved value differs"
        return current application's NSDictionary's dictionaryWithObjects:{true, true} forKeys:{"ok", "saved"}
    end credentialCommand

    on performCommand(commandName, payload)
        set commandName to commandName as text
        if commandName is "scopes" then return my nativeScopes(payload)
        if commandName is "captureNative" then return my captureNative(payload)
        if commandName is "nativeSessionIdentity" then return my nativeSessionIdentity(payload)
        if commandName is in {"loadKey", "saveKey"} then return my credentialCommand(commandName, payload)
        if commandName is "ping" then return current application's NSDictionary's dictionaryWithObjects:{"AppleScriptObjC native tree V3R48", my reconnectError} forKeys:{"host", "reconnectError"}
        if commandName is "capture" then return my capture(payload)
        if commandName is "captureRecovery" then
            set my recoveryCapture to true
            try
                set captured to my capture(payload)
                set my recoveryCapture to false
                return captured
            on error errorText
                set my recoveryCapture to false
                error errorText
            end try
        end if
        if commandName is "refreshIdentity" then return my refreshIdentity(payload)
        if commandName is "persistentIdentity" then return my readPersistentIdentity(payload)
        if commandName is "acceptCurrent" then return my acceptCurrentLayout(payload)
        if commandName is "recoveryJournal" then return my recoveryJournal(payload)
        if commandName is "recover" then return my recoverLayout(payload)
        if commandName is "selectIdentity" then return my selectIdentity(payload)
        if commandName is "confirmIdentity" then return my confirmIdentity(payload)
        if commandName is "finishCapture" then return my finishCapture(payload)
        if commandName is "selectExposure" then return my selectExposure(payload)
        if commandName is "confirmExposure" then return my confirmExposure(payload)
        if commandName is "finishExposure" then return my finishExposure(payload)
        if commandName is "cancelCapture" then return my cancelCapture(payload)
        if commandName is "keep" then
            if my beforeSnapshot is missing value or my appliedSnapshot is missing value then error "No verified sort to keep"
            set dataObject to current application's NSData's dataWithContentsOfFile:journalPath
            set journalObject to current application's NSJSONSerialization's JSONObjectWithData:dataObject options:0 |error|:(missing value)
            my archiveCompletedJournal(journalObject, "Current verified sort kept")
            set my beforeSnapshot to missing value
            set my appliedSnapshot to missing value
            return current application's NSDictionary's dictionaryWithObject:true forKey:"accepted"
        end if
        set liveSnapshot to my snapshot()
        if commandName is "snapshot" then return liveSnapshot
        if commandName is "undo" then
            if my beforeSnapshot is missing value or my appliedSnapshot is missing value then error "No verified operation to undo"
            if not ((liveSnapshot's isEqualToDictionary:(my appliedSnapshot)) as boolean) then error "Tree changed since sorting; Undo refused"
            my writeJournal("undoing", my beforeSnapshot)
            set restored to my applyLayout(my movableNodes(my beforeSnapshot))
            if not ((restored's isEqualToDictionary:(my beforeSnapshot)) as boolean) then error "Undo verification failed; journal retained"
            my writeJournal("undone", restored)
            set my beforeSnapshot to missing value
            set my appliedSnapshot to missing value
            return restored
        end if
        if commandName is not "apply" then error "Unsupported native command"
        if my beforeSnapshot is not missing value then error "Undo the previous sort first"
        if my persistentIdentity is missing value then error "Verify fresh persistent UUIDs before Apply"
        if not (((my persistentIdentity's objectForKey:"revision")'s isEqual:(liveSnapshot's objectForKey:"revision")) as boolean) then error "Tree changed after UUID verification"
        set planObject to payload's objectForKey:"plan"
        if planObject is missing value then error "Missing plan"
        if not (((planObject's objectForKey:"scope")'s isEqualToDictionary:(liveSnapshot's objectForKey:"scope")) as boolean) then error "Plan scope changed"
        if not (((planObject's objectForKey:"expectedRevision")'s isEqualToString:(liveSnapshot's objectForKey:"revision")) as boolean) then error "Tree changed since preview"
        set nodes to planObject's objectForKey:"nodes"
        my validateNodes(nodes)
        set existingJournalData to current application's NSData's dataWithContentsOfFile:journalPath
        if existingJournalData is not missing value then
            set existingJournal to current application's NSJSONSerialization's JSONObjectWithData:existingJournalData options:0 |error|:(missing value)
            if existingJournal is missing value then error "Unreadable journal"
            if ((existingJournal's objectForKey:"phase") as text) is in {"prepared", "applied", "undoing", "rollingBack"} then error "Recovery journal must be resolved before a new Apply"
        end if
        set my beforeSnapshot to liveSnapshot
        try
            my writeJournal("prepared", planObject)
        on error journalError
            set my beforeSnapshot to missing value
            error journalError
        end try
        try
            set my appliedSnapshot to my applyLayout(nodes)
            my writeJournal("applied", my appliedSnapshot)
            return my appliedSnapshot
        on error errorText
            try
                my writeJournal("rollingBack", my beforeSnapshot)
                set restored to my applyLayout(my movableNodes(my beforeSnapshot))
                if not ((restored's isEqualToDictionary:(my beforeSnapshot)) as boolean) then error "Rollback verification failed"
                my writeJournal("rolledBack", restored)
                set my beforeSnapshot to missing value
                set my appliedSnapshot to missing value
            on error rollbackError
                error errorText & "; rollback incomplete: " & rollbackError & "; recovery journal retained"
            end try
            error errorText & "; original tree restored"
        end try
    end performCommand

    on userContentController:contentController didReceiveScriptMessage:messageObject
        set senderView to messageObject's webView()
        if (senderView's |URL|()'s absoluteString() as text) is not controllerURL then return
        if not (messageObject's frameInfo()'s isMainFrame() as boolean) then return
        if (messageObject's frameInfo()'s request()'s |URL|()'s absoluteString() as text) is not controllerURL then return
        set requestBody to messageObject's body()
        if not ((requestBody's isKindOfClass:(current application's NSDictionary)) as boolean) then return
        set requestID to requestBody's objectForKey:"id"
        set commandValue to requestBody's objectForKey:"command"
        if requestID is missing value or commandValue is missing value then return
        if not ((requestID's isKindOfClass:(current application's NSString)) as boolean) then return
        if not ((commandValue's isKindOfClass:(current application's NSString)) as boolean) then return
        if (requestID's |length|() as integer) > 80 then return
        set replyObject to current application's NSMutableDictionary's dictionaryWithObject:requestID forKey:"id"
        try
            if (commandValue as text) is not in {"scopes", "captureNative", "nativeSessionIdentity", "ping", "loadKey", "saveKey", "capture", "captureRecovery", "refreshIdentity", "persistentIdentity", "acceptCurrent", "recoveryJournal", "recover", "selectIdentity", "confirmIdentity", "finishCapture", "selectExposure", "confirmExposure", "finishExposure", "cancelCapture", "snapshot", "apply", "undo", "keep"} then error "Unsupported command"
            set payload to requestBody's objectForKey:"payload"
            if payload is missing value then set payload to current application's NSDictionary's dictionary()
            set resultObject to my performCommand(commandValue as text, payload)
            replyObject's setObject:true forKey:"ok"
            replyObject's setObject:resultObject forKey:"result"
        on error errorText
            replyObject's setObject:false forKey:"ok"
            replyObject's setObject:errorText forKey:"error"
        end try
        replyObject's setObject:(my beforeSnapshot is not missing value and my appliedSnapshot is not missing value) forKey:"canUndo"
        replyObject's setObject:(my beforeSnapshot is not missing value and my appliedSnapshot is missing value) forKey:"needsRecovery"
        my armCaptureWatchdog:(missing value)
        senderView's evaluateJavaScript:("window.OrionSorter.receive(" & my jsonText(replyObject) & ");") completionHandler:(missing value)
    end userContentController:didReceiveScriptMessage:
    on supportedHost()
        set hostBundle to current application's NSBundle's mainBundle()
        set hostID to hostBundle's bundleIdentifier() as text
        set hostVersion to (hostBundle's objectForInfoDictionaryKey:"CFBundleShortVersionString") as text
        set hostBuild to (hostBundle's objectForInfoDictionaryKey:"CFBundleVersion") as text
        if hostID is not "com.kagi.kagimacOS" or hostVersion is not "1.1.3" or hostBuild is not "152" then error "Unsupported Orion build"
    end supportedHost

    on nativeContextForWindow(nativeWindow)
        set matches to {}
        repeat with outlineView in my findViews(nativeWindow's contentView(), current application's NSOutlineView)
            set sourceObject to outlineView's dataSource()
            if sourceObject is not missing value then
                if (current application's NSStringFromClass(sourceObject's |class|()) as text) is "Orion.VerticalTabsViewController" then
                    set rootItem to my openRoot(sourceObject, outlineView)
                    set end of matches to {contents of outlineView, sourceObject, rootItem}
                end if
            end if
        end repeat
        if (count of matches) is not 1 then error "Open the native vertical tabs sidebar in this window"
        return item 1 of matches
    end nativeContextForWindow

    on pinnedRows(sourceObject, outlineView)
        set rows to {}
        set rootCount to (sourceObject's outlineView:outlineView numberOfChildrenOfItem:(missing value)) as integer
        repeat with i from 0 to rootCount - 1
            set rootItem to sourceObject's outlineView:outlineView child:i ofItem:(missing value)
            if (rootItem's description() as text) contains "pinned" then set rows to rows & my collectRows(sourceObject, outlineView, rootItem, 0)
        end repeat
        return rows
    end pinnedRows

    on nativePinnedWrappers(nativeWindow, ordinaryRows)
        -- On the guarded Orion build the scripting list is pinned prefix +
        -- complete ordinary suffix. Prove that suffix by its URL multiset,
        -- retain the actual prefix objects, and never infer ordinary IDs.
        set wrappers to nativeWindow's orderedTabViews()
        set ordinaryCount to count of ordinaryRows
        set prefixCount to (wrappers's |count|() as integer) - ordinaryCount
        if prefixCount < 0 or prefixCount > 64 then error "Native wrapper membership differs from the full tab tree"
        set expectedURLs to current application's NSCountedSet's |set|()
        repeat with r in ordinaryRows
            expectedURLs's addObject:((item 1 of r)'s URLString())
        end repeat
        set actualURLs to current application's NSCountedSet's |set|()
        repeat with i from prefixCount to (wrappers's |count|() as integer) - 1
            actualURLs's addObject:((wrappers's objectAtIndex:i)'s URLString())
        end repeat
        if not ((actualURLs's isEqualToSet:expectedURLs) as boolean) then error "Native wrapper suffix differs from ordinary tabs"
        repeat with u in (expectedURLs's allObjects() as list)
            if (actualURLs's countForObject:u) is not (expectedURLs's countForObject:u) then error "Native wrapper duplicate membership differs"
        end repeat
        set pins to {}
        repeat with i from 0 to prefixCount - 1
            set end of pins to wrappers's objectAtIndex:i
        end repeat
        return pins
    end nativePinnedWrappers

    on nativeScopeSignature(nativeWindow, rows)
        if my nativeObjectUUIDs is missing value then set my nativeObjectUUIDs to current application's NSMapTable's weakToStrongObjectsMapTable()
        if my nativeScopeUUIDs is missing value then set my nativeScopeUUIDs to current application's NSMutableDictionary's dictionary()
        set ids to current application's NSMutableArray's array()
        repeat with r in rows
            set nativeItem to contents of item 1 of r
            set identityText to my nativeObjectUUIDs's objectForKey:nativeItem
            if identityText is missing value then
                set identityText to current application's NSUUID's UUID()'s UUIDString()
                my nativeObjectUUIDs's setObject:identityText forKey:nativeItem
            end if
            ids's addObject:identityText
        end repeat
        ids's sortUsingSelector:"compare:"
        set scopeKey to (nativeWindow's windowNumber() as text) & ":" & (ids's componentsJoinedByString:"," as text)
        set scopeUUID to my nativeScopeUUIDs's objectForKey:scopeKey
        if scopeUUID is missing value then
            set scopeUUID to current application's NSUUID's UUID()'s UUIDString()
            my nativeScopeUUIDs's setObject:scopeUUID forKey:scopeKey
        end if
        return scopeUUID
    end nativeScopeSignature

    on nativeScopes(payload)
        my supportedHost()
        set resultRows to current application's NSMutableArray's array()
        set windowsArray to current application's NSApplication's sharedApplication()'s orderedWindows()
        repeat with i from 0 to (windowsArray's |count|() as integer) - 1
            set nativeWindow to windowsArray's objectAtIndex:i
            if (nativeWindow's respondsToSelector:"currentTabView") as boolean then
                set wrapper to nativeWindow's currentTabView()
                if wrapper is not missing value then
                    if (wrapper's URLString() as text) is not my controllerURL then
                        if nativeWindow's isVisible() as boolean then
                            set scopeName to nativeWindow's title() as text
                            set tabCount to missing value
                            try
                                set {outlineView, sourceObject, rootItem} to my nativeContextForWindow(nativeWindow)
                                set scopeRows to my collectRows(sourceObject, outlineView, rootItem, 0)
                                set tabCount to count of scopeRows
                            end try
                            set scopeRow to current application's NSMutableDictionary's dictionaryWithObjects:{nativeWindow's windowNumber(), scopeName, nativeWindow's isMainWindow()} forKeys:{"id", "name", "focused"}
                            if tabCount is not missing value then
                                scopeRow's setObject:tabCount forKey:"tabCount"
                                scopeRow's setObject:(my nativeScopeSignature(nativeWindow, scopeRows)) forKey:"token"
                            end if
                            if tabCount is not missing value and tabCount > 0 then resultRows's addObject:scopeRow
                        end if
                    end if
                end if
            end if
        end repeat
        return resultRows
    end nativeScopes

    on captureNative(payload)
        my supportedHost()
        if my beforeSnapshot is not missing value then error "Undo the previous sort before selecting another scope"
        if my captureToken is not missing value then error "Complete or cancel the pending capture"
        set windowNumber to payload's objectForKey:"windowId"
        if windowNumber is missing value then error "Selected native window missing"
        set matches to current application's NSMutableArray's array()
        set windowsArray to current application's NSApplication's sharedApplication()'s orderedWindows()
        repeat with i from 0 to (windowsArray's |count|() as integer) - 1
            set candidate to windowsArray's objectAtIndex:i
            if (candidate's respondsToSelector:"currentTabView") as boolean then
                if ((current application's NSNumber's numberWithInteger:(candidate's windowNumber()))'s isEqual:windowNumber) as boolean then matches's addObject:candidate
            end if
        end repeat
        if (matches's |count|() as integer) is not 1 then error "Selected native window closed or ambiguous"
        set nativeWindow to matches's objectAtIndex:0
        set activeView to nativeWindow's currentTabView()
        if activeView is missing value or (activeView's URLString() as text) is my controllerURL then error "Select an ordinary browser window"
        set {outlineView, sourceObject, rootItem} to my nativeContextForWindow(nativeWindow)
        set rows to my collectRows(sourceObject, outlineView, rootItem, 0)
        if (count of rows) < 1 then error "No ordinary tabs in selected scope"
        if my sessionKey is missing value then set my sessionKey to current application's NSUUID's UUID()'s UUIDString()
        set my persistentIdentity to missing value
        set my nativeUUIDBindings to missing value
        set my exposureCandidates to missing value
        set my directNativeMode to true
        set my selectionWrapperToken to current application's NSUUID's UUID()'s UUIDString()
        set itemMap to current application's NSMutableDictionary's dictionary()
        set metaMap to current application's NSMutableDictionary's dictionary()
        set pins to current application's NSMutableArray's array()
        set my capturedPinnedObjects to current application's NSMutableArray's array()
        set pinWrappers to my nativePinnedWrappers(nativeWindow, rows)
        set activeURL to activeView's URLString()
        set activeMatches to 0
        repeat with rowRef in rows
            if ((item 1 of rowRef)'s URLString()'s isEqual:activeURL) as boolean then set activeMatches to activeMatches + 1
        end repeat
        repeat with wrapperRef in pinWrappers
            if ((contents of wrapperRef)'s URLString()'s isEqual:activeURL) as boolean then set activeMatches to activeMatches + 1
        end repeat
        set ordinal to 0
        repeat with rowRef in rows
            set nativeItem to contents of item 1 of rowRef
            set ordinal to ordinal + 1
            set nativeID to current application's NSNumber's numberWithInteger:(-ordinal)
            set keyText to "native-" & ordinal
            set u to nativeItem's URLString()
            if u is missing value or (u's |length|() as integer) is 0 then error "Native tab URL unavailable"
            set isActive to false
            if activeMatches is 1 then set isActive to (u's isEqual:activeURL) as boolean
            itemMap's setObject:nativeItem forKey:keyText
            metaMap's setObject:(current application's NSDictionary's dictionaryWithObjects:{nativeID, u, isActive, true} forKeys:{"id", "url", "active", "nativeOnly"}) forKey:keyText
        end repeat
        repeat with i from 1 to count of pinWrappers
            set nativeItem to contents of item i of pinWrappers
            set ordinal to ordinal + 1
            set u to nativeItem's URLString()
            set isActive to false
            if activeMatches is 1 then set isActive to (u's isEqual:activeURL) as boolean
            set tabMeta to current application's NSDictionary's dictionaryWithObjects:{current application's NSNumber's numberWithInteger:(-ordinal), u, nativeItem's title(), i - 1, isActive, true, true} forKeys:{"id", "url", "title", "index", "active", "pinned", "nativeOnly"}
            pins's addObject:tabMeta
            my capturedPinnedObjects's addObject:nativeItem
        end repeat
        set activeWebView to my pageView(nativeWindow, activeURL)
        set scopeObject to current application's NSDictionary's dictionaryWithObjects:{windowNumber, windowNumber, my nativeScopeSignature(nativeWindow, rows), nativeWindow's title()} forKeys:{"windowId", "nativeWindowNumber", "groupKey", "name"}
        set my contextItems to {nativeWindow, outlineView, sourceObject, rootItem, itemMap, metaMap, pins, scopeObject, activeView, activeWebView}
        set my identityViews to current application's NSMutableDictionary's dictionary()
        set my identityHistories to current application's NSMutableDictionary's dictionary()
        return my snapshot()
    end captureNative

    on nativeSessionIdentity(payload)
        if not my directNativeMode then error "Native session capture required"
        set liveSnapshot to my snapshot()
        if my nativeObjectUUIDs is missing value then set my nativeObjectUUIDs to current application's NSMapTable's weakToStrongObjectsMapTable()
        if my nativeScopeUUIDs is missing value then set my nativeScopeUUIDs to current application's NSMutableDictionary's dictionary()
        set bindings to current application's NSMutableArray's array()
        set ids to current application's NSMutableArray's array()
        set itemMap to item 5 of my contextItems
        repeat with keyRef in (itemMap's allKeys() as list)
            set keyText to contents of keyRef
            set nativeItem to itemMap's objectForKey:keyText
            set identityText to my nativeObjectUUIDs's objectForKey:nativeItem
            if identityText is missing value then
                set identityText to current application's NSUUID's UUID()'s UUIDString()
                my nativeObjectUUIDs's setObject:identityText forKey:nativeItem
            end if
            bindings's addObject:(current application's NSDictionary's dictionaryWithObjects:{keyText, identityText} forKeys:{"key", "uuid"})
            ids's addObject:identityText
        end repeat
        ids's sortUsingSelector:"compare:"
        set scopeKey to ((liveSnapshot's objectForKey:"scope")'s objectForKey:"nativeWindowNumber")'s stringValue() as text
        set scopeKey to scopeKey & ":" & (ids's componentsJoinedByString:"," as text)
        set scopeUUID to my nativeScopeUUIDs's objectForKey:scopeKey
        if scopeUUID is missing value then
            set scopeUUID to current application's NSUUID's UUID()'s UUIDString()
            my nativeScopeUUIDs's setObject:scopeUUID forKey:scopeKey
        end if
        set my persistentIdentity to current application's NSDictionary's dictionaryWithObjects:{scopeUUID, bindings, liveSnapshot's objectForKey:"revision", "native-session", my sessionKey} forKeys:{"windowUUID", "tabs", "revision", "mode", "sessionKey"}
        return my persistentIdentity
    end nativeSessionIdentity

end script
