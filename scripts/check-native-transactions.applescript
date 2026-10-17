property fixtureBefore : missing value
property fixtureApplied : missing value
property fixtureLive : missing value
property failedMoves : {}
property failedWrites : {}
property moveCalls : 0
property writeCalls : 0
property failureCount : 0
property failures : ""
property archiveFailure : false
property resolutionFailure : false
property assertionCount : 0
property snapshotFailure : false
property snapshotFailureText : "Injected snapshot verification failure"
property archiveFault : ""
property archiveWrites : 0
property archiveReads : 0
property permissionReads : 0
property captureCalls : 0
property fixtureContext : missing value
property resolutionAfterWriteFailure : false
property resolutionCorruption : false

on snapshot()
    if my snapshotFailure then error my snapshotFailureText
    return my fixtureLive
end snapshot

-- This boundary models partial native moves, not transaction decisions.
on applyLayout(nodes)
    my validateNodes(nodes)
    set my moveCalls to my moveCalls + 1
    set destination to my fixtureApplied
    if (nodes's isEqualToArray:(my movableNodes(my fixtureBefore))) as boolean then set destination to my fixtureBefore
    if my moveCalls is in my failedMoves then
        set my fixtureLive to current application's NSDictionary's dictionaryWithObjects:{"partial", my fixtureBefore's objectForKey:"scope", my fixtureBefore's objectForKey:"tabs"} forKeys:{"revision", "scope", "tabs"}
        error "Injected partial move failure"
    end if
    set my fixtureLive to destination
    return my fixtureLive
end applyLayout

on writeJournal(phaseText, targetObject)
    set my writeCalls to my writeCalls + 1
    if my writeCalls is in my failedWrites then error "Injected journal write failure"
    return my production_writeJournal(phaseText, targetObject)
end writeJournal

on protectedJournalArchive(expectedData, suffixText)
    if my archiveFailure then error "Injected archive I/O failure"
    return my production_protectedJournalArchive(expectedData, suffixText)
end protectedJournalArchive

on saveResolvedJournal(resolved)
    if my resolutionFailure then error "Injected resolution I/O failure"
    my production_saveResolvedJournal(resolved)
    if my resolutionAfterWriteFailure then error "Injected error after completed journal write"
    if my resolutionCorruption then
        set altered to resolved's mutableCopy()
        altered's setObject:"Injected different resolution" forKey:"resolution"
        my production_saveResolvedJournal(altered)
    end if
end saveResolvedJournal

on supportedHost()
    return true
end supportedHost

-- Only private scope acquisition is synthetic. captureNative's actual command
-- dispatch and transaction/capture guards must permit this fresh explicit read.
on captureNativeScope(payload)
    set my captureCalls to my captureCalls + 1
    set my contextItems to my fixtureContext
    set my fixtureLive to my fixtureBefore
    set my snapshotFailure to false
    return my snapshot()
end captureNativeScope

-- Fault only individual filesystem calls; production archive creation, encoding,
-- permission checks, byte verification and finalization decisions stay intact.
on createProtectedDirectory(pathText)
    if my archiveFault is "mkdir" then return false
    return my production_createProtectedDirectory(pathText)
end createProtectedDirectory

on writeProtectedFile(pathText, dataObject)
    set my archiveWrites to my archiveWrites + 1
    if my archiveFault is ("write" & my archiveWrites) then return false
    set outcome to my production_writeProtectedFile(pathText, dataObject)
    if my archiveWrites is 2 then
        if my archiveFault is "journalChanged" then
            set dataObject to (current application's NSString's stringWithString:"{}")'s dataUsingEncoding:4
            dataObject's writeToFile:journalPath options:1 |error|:(missing value)
        end if
        if my archiveFault is "transactionChanged" then set my partialSnapshot to current application's NSDictionary's dictionaryWithObject:"changed" forKey:"revision"
        if my archiveFault is "liveChanged" then set my fixtureLive to my fixtureApplied
    end if
    return outcome
end writeProtectedFile

on archiveFileData(pathText)
    set my archiveReads to my archiveReads + 1
    if my archiveFault is ("read" & my archiveReads) then return missing value
    if my archiveFault is ("bytes" & my archiveReads) then return current application's NSData's data()
    return my production_archiveFileData(pathText)
end archiveFileData

on archiveFilePermissions(pathText)
    set my permissionReads to my permissionReads + 1
    if my archiveFault is ("permissions" & my permissionReads) then return 511
    return my production_archiveFilePermissions(pathText)
end archiveFilePermissions

on restoreRootExpansion(snapshotObject)
    return true
end restoreRootExpansion

on resetFixture()
    current application's NSFileManager's defaultManager()'s removeItemAtPath:journalPath |error|:(missing value)
    set scopeObject to current application's NSDictionary's dictionaryWithObject:"synthetic" forKey:"groupKey"
    set tabs to current application's NSMutableArray's array()
    set itemMap to current application's NSMutableDictionary's dictionary()
    set metaMap to current application's NSMutableDictionary's dictionary()
    repeat with i from 1 to 2
        set k to "tab-" & i
        set nodeObject to current application's NSDictionary's dictionaryWithObjects:{i, k, current application's NSNull's |null|(), i - 1, false, false, false, "https://example.test/" & i} forKeys:{"id", "key", "parentKey", "index", "expanded", "pinned", "active", "url"}
        tabs's addObject:nodeObject
        itemMap's setObject:k forKey:k
        metaMap's setObject:nodeObject forKey:k
    end repeat
    set changedTabs to current application's NSMutableArray's array()
    repeat with i from 0 to 1
        set n to (tabs's objectAtIndex:i)'s mutableCopy()
        n's setObject:(1 - i) forKey:"index"
        changedTabs's addObject:n
    end repeat
    set my fixtureBefore to current application's NSDictionary's dictionaryWithObjects:{"before", scopeObject, tabs, false} forKeys:{"revision", "scope", "tabs", "rootExpanded"}
    set my fixtureApplied to current application's NSDictionary's dictionaryWithObjects:{"applied", scopeObject, changedTabs, false} forKeys:{"revision", "scope", "tabs", "rootExpanded"}
    set my fixtureLive to my fixtureBefore
    set my contextItems to {"window", "outline", "source", "root", itemMap, metaMap}
    set my fixtureContext to my contextItems
    set my identityHistories to missing value
    set my nativeUUIDBindings to missing value
    set my captureToken to missing value
    set my beforeSnapshot to missing value
    set my appliedSnapshot to missing value
    set my persistentIdentity to current application's NSDictionary's dictionaryWithObjects:{"before", "native-session", "fixture-process", "scope-uuid"} forKeys:{"revision", "mode", "sessionKey", "windowUUID"}
    set my sessionKey to "fixture-process"
    my clearTransaction()
    set my snapshotFailure to false
    set my snapshotFailureText to "Injected snapshot verification failure"
    set my archiveFailure to false
    set my resolutionFailure to false
    set my resolutionAfterWriteFailure to false
    set my resolutionCorruption to false
    set my archiveFault to ""
    set my archiveWrites to 0
    set my archiveReads to 0
    set my permissionReads to 0
    set my captureCalls to 0
    set my failedMoves to {}
    set my failedWrites to {}
    set my moveCalls to 0
    set my writeCalls to 0
end resetFixture

on applyFixture()
    set p to current application's NSDictionary's dictionaryWithObjects:{my fixtureBefore's objectForKey:"scope", "before", my fixtureApplied's objectForKey:"tabs"} forKeys:{"scope", "expectedRevision", "nodes"}
    return my performCommand("apply", current application's NSDictionary's dictionaryWithObject:p forKey:"plan")
end applyFixture

on expectFailure(commandText)
    set didFail to false
    try
        if commandText is "apply" then
            my applyFixture()
        else
            my performCommand(commandText, current application's NSDictionary's dictionary())
        end if
    on error
        set didFail to true
    end try
    if not didFail then error "Expected command failure: " & commandText
end expectFailure

on checkRestored(expectedObject, labelText)
    if not ((my fixtureLive's isEqualToDictionary:expectedObject) as boolean) then
        set my failureCount to my failureCount + 1
        set my failures to my failures & labelText & "; "
    end if
end checkRestored

on assertTrue(valueObject, labelText)
    if not valueObject then error "Assertion failed: " & labelText
    set my assertionCount to my assertionCount + 1
end assertTrue

on assertLayout(expectedObject)
    my assertTrue((my fixtureLive's isEqualToDictionary:expectedObject) as boolean, "verified destination")
end assertLayout

on assertStatus(phaseText, undoFlag, recoveryFlag, journalText)
    set statusObject to my performCommand("transactionStatus", current application's NSDictionary's dictionary())
    my assertTrue(((statusObject's objectForKey:"transactionPhase") as text) is phaseText, "transaction phase " & phaseText)
    my assertTrue(((statusObject's objectForKey:"canUndo") as boolean) is undoFlag, "canUndo")
    my assertTrue(((statusObject's objectForKey:"needsRecovery") as boolean) is recoveryFlag, "needsRecovery")
    my assertTrue(((statusObject's objectForKey:"journalPhase") as text) is journalText, "durable phase " & journalText)
end assertStatus

on resumeRetained(targetName)
    set payload to current application's NSDictionary's dictionaryWithObjects:{my fixtureLive's objectForKey:"revision", targetName} forKeys:{"expectedRevision", "target"}
    my performCommand("recoverRetained", payload)
end resumeRetained

on previousJournal(phaseText)
    my resetFixture()
    set identityObject to current application's NSDictionary's dictionaryWithObjects:{"native-session", "previous-process", "unrelated-old-scope"} forKeys:{"mode", "sessionKey", "windowUUID"}
    set journalObject to current application's NSDictionary's dictionaryWithObjects:{1, phaseText, identityObject, my fixtureBefore} forKeys:{"version", "phase", "identity", "before"}
    set dataObject to current application's NSJSONSerialization's dataWithJSONObject:journalObject options:2 |error|:(missing value)
    dataObject's writeToFile:journalPath options:1 |error|:(missing value)
    set inspection to my performCommand("inspectJournal", current application's NSDictionary's dictionary())
    return current application's NSMutableDictionary's dictionaryWithObjects:{true, inspection's objectForKey:"journalRevision", 1, identityObject, "before"} forKeys:{"confirmed", "expectedJournalRevision", "expectedJournalVersion", "expectedJournalIdentity", "expectedRevision"}
end previousJournal

on expectPayloadFailure(commandText, payload)
    set didFail to false
    try
        my performCommand(commandText, payload)
    on error
        set didFail to true
    end try
    my assertTrue(didFail, "reject unsafe " & commandText)
end expectPayloadFailure

on prepareVerifiedRecovery()
    my resetFixture()
    set my fixtureLive to my fixtureApplied
    set bindings to current application's NSMutableArray's array()
    repeat with i from 1 to 2
        bindings's addObject:(current application's NSDictionary's dictionaryWithObjects:{"tab-" & i, "uuid-" & i} forKeys:{"key", "uuid"})
    end repeat
    set my persistentIdentity to current application's NSDictionary's dictionaryWithObjects:{"applied", "native-session", "fixture-process", "scope-uuid", bindings} forKeys:{"revision", "mode", "sessionKey", "windowUUID", "tabs"}
    set journalObject to current application's NSDictionary's dictionaryWithObjects:{1, "prepared", my persistentIdentity, my fixtureBefore} forKeys:{"version", "phase", "identity", "before"}
    my production_saveResolvedJournal(journalObject)
    set planObject to current application's NSDictionary's dictionaryWithObjects:{my fixtureBefore's objectForKey:"scope", "applied", my fixtureBefore's objectForKey:"tabs"} forKeys:{"scope", "expectedRevision", "nodes"}
    return current application's NSDictionary's dictionaryWithObject:planObject forKey:"plan"
end prepareVerifiedRecovery

on abandonmentPayload()
    set inspection to my performCommand("inspectRetainedTransaction", current application's NSDictionary's dictionary())
    return current application's NSMutableDictionary's dictionaryWithObjects:{true, inspection's objectForKey:"inspectionToken", inspection's objectForKey:"transactionID", inspection's objectForKey:"journalRevision", inspection's objectForKey:"journalVersion", inspection's objectForKey:"journalIdentity", (inspection's objectForKey:"live")'s objectForKey:"available", (inspection's objectForKey:"live")'s objectForKey:"revision"} forKeys:{"confirmed", "inspectionToken", "expectedTransactionID", "expectedJournalRevision", "expectedJournalVersion", "expectedJournalIdentity", "expectedLiveAvailable", "expectedRevision"}
end abandonmentPayload

on assertAbandoned(resultObject, originalData, inspectedRecord, oldMoveCalls)
    my assertTrue((resultObject's objectForKey:"abandoned") as boolean, "explicit abandonment reply")
    my assertTrue((resultObject's objectForKey:"acknowledged") as boolean, "explicit acknowledgment reply")
    my assertTrue(not ((resultObject's objectForKey:"restorationVerified") as boolean), "no restoration claim")
    my assertTrue(not ((resultObject's objectForKey:"currentLayoutVerified") as boolean), "no current layout claim")
    my assertTrue(my moveCalls is oldMoveCalls, "archive-only resolution made zero native moves")
    set resolved to resultObject's objectForKey:"journal"
    my assertTrue(((resolved's objectForKey:"phase") as text) is "acknowledged", "resolved journal phase")
    my assertTrue(((resolved's objectForKey:"resolutionKind") as text) is "abandoned", "journal records abandonment")
    set archiveData to current application's NSData's dataWithContentsOfFile:(resolved's objectForKey:"archive")
    my assertTrue((originalData's isEqualToData:archiveData) as boolean, "byte-exact divergent journal preserved")
    set evidenceData to current application's NSData's dataWithContentsOfFile:(resolved's objectForKey:"evidenceArchive")
    set evidenceObject to current application's NSJSONSerialization's JSONObjectWithData:evidenceData options:0 |error|:(missing value)
    my assertTrue(((evidenceObject's objectForKey:"retainedInspection")'s isEqualToDictionary:inspectedRecord) as boolean, "every inspected before/applied/partial value preserved")
    repeat with keyName in {"archive", "evidenceArchive"}
        set pathText to resolved's objectForKey:(contents of keyName)
        my assertTrue((my production_archiveFilePermissions(pathText) as integer) is 384, "0600 evidence file")
        my assertTrue((my production_archiveFilePermissions(pathText's stringByDeletingLastPathComponent()) as integer) is 448, "0700 unique evidence directory")
    end repeat
    my assertStatus("idle", false, false, "acknowledged")
    my assertTrue(my beforeSnapshot is missing value and my appliedSnapshot is missing value and my partialSnapshot is missing value and my transactionID is missing value and my retainedInspection is missing value and my recoveryArchive is missing value, "resolved transaction evidence released")
    my assertTrue(my contextItems is missing value and my persistentIdentity is missing value and my identityViews is missing value and my identityHistories is missing value and my nativeUUIDBindings is missing value and my capturedPinnedObjects is missing value and my selectionWrapperToken is missing value and my exposureCandidates is missing value, "old captured context released")
    my assertTrue(my captureRows is missing value and my captureWrappers is missing value and my captureExpanded is missing value and my captureRootExpanded is missing value and my captureScrollPoint is missing value and my captureBindingIDs is missing value and my captureActiveHistory is missing value and my captureDeadline is missing value and my selectedIdentity is missing value and my identityRequestedAt is missing value, "old capture references released")
end assertAbandoned

on finishAbandonment(payload)
    set recordObject to my retainedInspection
    set oldMoveCalls to my moveCalls
    set originalData to current application's NSData's dataWithContentsOfFile:journalPath
    set resultObject to my performCommand("abandonRetainedTransaction", payload)
    my assertAbandoned(resultObject, originalData, recordObject, oldMoveCalls)
    return resultObject
end finishAbandonment

on assertRetainedAfterRefusal(payload, originalData)
    my expectPayloadFailure("abandonRetainedTransaction", payload)
    my assertTrue(my beforeSnapshot is not missing value and my appliedSnapshot is not missing value and my contextItems is not missing value and my persistentIdentity is not missing value, "refusal retains evidence and native context")
    set currentData to current application's NSData's dataWithContentsOfFile:journalPath
    my assertTrue((originalData's isEqualToData:currentData) as boolean, "refusal did not overwrite journal")
    my assertTrue(my moveCalls is 1, "refusal made zero moves")
end assertRetainedAfterRefusal

on run argv
    set journalPath to item 1 of argv
    my resetFixture()
    my applyFixture()
    set my failedMoves to {2}
    my expectFailure("undo")
    my checkRestored(my fixtureApplied, "Undo partial failure is not compensated")
    my resetFixture()
    set my failedMoves to {1}
    set my failedWrites to {2}
    my expectFailure("apply")
    my checkRestored(my fixtureBefore, "Apply rollback skipped after journal I/O error")
    if my failureCount is not 0 then error my failures

    -- Success, repetition and reuse, with real journal serialization.
    my resetFixture()
    my applyFixture()
    my assertLayout(my fixtureApplied)
    my assertStatus("applied", true, false, "applied")
    my expectFailure("apply")
    my performCommand("undo", current application's NSDictionary's dictionary())
    my assertLayout(my fixtureBefore)
    my assertStatus("idle", false, false, "undone")
    my expectFailure("undo")
    my expectFailure("keep")
    my applyFixture()
    my assertStatus("applied", true, false, "applied")
    my performCommand("keep", current application's NSDictionary's dictionary())
    my assertStatus("idle", false, false, "accepted")
    my expectFailure("keep")

    -- Apply write-ahead, finalization, rollback-start and rollback-final writes.
    my resetFixture()
    set my failedWrites to {1}
    my expectFailure("apply")
    my assertTrue(my moveCalls is 0, "write-ahead before moves")
    my assertStatus("idle", false, false, "none")
    my resetFixture()
    set my failedWrites to {2}
    my expectFailure("apply")
    my assertLayout(my fixtureBefore)
    my assertStatus("idle", false, false, "rolledBack")
    my resetFixture()
    set my failedMoves to {1}
    set my failedWrites to {2}
    my expectFailure("apply")
    my assertLayout(my fixtureBefore)
    my assertTrue(my moveCalls is 2, "journal failure did not skip compensation")
    my assertStatus("idle", false, false, "rolledBack")
    repeat with failedBoundary in {{3}, {2, 3}}
        my resetFixture()
        set my failedMoves to {1}
        set my failedWrites to contents of failedBoundary
        my expectFailure("apply")
        my assertLayout(my fixtureBefore)
        if contents of failedBoundary is {3} then
            my assertStatus("restoredJournalPending", false, true, "rollingBack")
        else
            my assertStatus("restoredJournalPending", false, true, "prepared")
        end if
        my expectFailure("keep")
        my expectFailure("undo")
        my expectFailure("apply")
        my resumeRetained("original")
        my assertStatus("idle", false, false, "rolledBack")
    end repeat

    -- Undo write-ahead, finalization, compensation-start and compensation-final writes.
    my resetFixture()
    my applyFixture()
    set my failedWrites to {3}
    my expectFailure("undo")
    my assertTrue(my moveCalls is 1, "Undo write-ahead before moves")
    my assertStatus("applied", true, false, "applied")
    my resetFixture()
    my applyFixture()
    set my failedWrites to {4}
    my expectFailure("undo")
    my assertLayout(my fixtureApplied)
    my assertStatus("applied", true, false, "applied")
    my resetFixture()
    my applyFixture()
    set my failedMoves to {2}
    set my failedWrites to {4}
    my expectFailure("undo")
    my assertLayout(my fixtureApplied)
    my assertStatus("applied", true, false, "applied")
    my resetFixture()
    my applyFixture()
    set my failedMoves to {2}
    set my failedWrites to {5}
    my expectFailure("undo")
    my assertLayout(my fixtureApplied)
    my assertStatus("appliedJournalPending", false, true, "rollingBack")
    my expectFailure("keep")
    my expectFailure("undo")
    my resumeRetained("applied")
    my assertStatus("applied", true, false, "applied")

    -- Failed compensation retains both original and partial evidence.
    repeat with originCommand in {"apply", "undo"}
        my resetFixture()
        if contents of originCommand is "apply" then
            set my failedMoves to {1, 2}
        else
            my applyFixture()
            set my failedMoves to {2, 3}
        end if
        my expectFailure(contents of originCommand)
        my assertStatus("recoveryRequired", false, true, "recoveryRequired")
        my assertTrue(my beforeSnapshot is not missing value, "original snapshot retained")
        my assertTrue(my partialSnapshot is not missing value, "partial evidence retained")
        set evidence to (my inspectJournal(current application's NSDictionary's dictionary()))'s objectForKey:"journal"
        my assertTrue((evidence's objectForKey:"partial") is not missing value, "partial evidence durable")
        my expectFailure("keep")
        my expectFailure("undo")
        my expectFailure("apply")
        my expectPayloadFailure("recoverRetained", current application's NSDictionary's dictionaryWithObjects:{"stale", "original"} forKeys:{"expectedRevision", "target"})
        my resumeRetained("original")
        my assertLayout(my fixtureBefore)
        my assertStatus("idle", false, false, "rolledBack")
    end repeat
    my resetFixture()
    set my failedMoves to {1, 2}
    set my failedWrites to {3}
    my expectFailure("apply")
    my assertStatus("recoveryRequired", false, true, "rollingBack")
    my resumeRetained("original")
    my assertStatus("idle", false, false, "rolledBack")

    -- Failed snapshot verification is evidence of uncertainty, never success.
    my resetFixture()
    my applyFixture()
    set my snapshotFailure to true
    set my failedMoves to {2}
    set outcome to my compensateLayout(my fixtureBefore, "rolledBack")
    my assertTrue(my transactionPhase is "recoveryRequired", "unverified compensation retained")
    my assertTrue((my partialSnapshot's objectForKey:"snapshotError") is not missing value, "failed snapshot evidence retained")
    my assertStatus("recoveryRequired", false, true, "recoveryRequired")
    set my snapshotFailure to false
    my resumeRetained("original")
    my assertStatus("idle", false, false, "rolledBack")

    -- Read-only inspection and explicit abandonment break the divergent applied trap.
    -- Selection, navigation, membership/window closure make the shipped snapshot
    -- boundary unavailable; reorganization can instead produce a different snapshot.
    repeat with divergence in {"reorganized", "Active tab changed; read the group again", "Tab navigated; read the group again", "Native tab set changed", "Selected window closed"}
        my resetFixture()
        my applyFixture()
        if contents of divergence is "reorganized" then
            set my fixtureLive to my fixtureBefore
        else
            set my snapshotFailure to true
            set my snapshotFailureText to contents of divergence
        end if
        my expectFailure("keep")
        my expectFailure("undo")
        my expectFailure("captureNative")
        my expectFailure("apply")
        my expectPayloadFailure("recoverRetained", current application's NSDictionary's dictionaryWithObjects:{"before", "original"} forKeys:{"expectedRevision", "target"})
        my expectFailure("acknowledgeCurrent")
        my assertStatus("applied", false, true, "applied")
        set my nativeUUIDBindings to current application's NSDictionary's dictionaryWithObject:"uuid-1" forKey:"tab-1"
        set my identityHistories to current application's NSDictionary's dictionaryWithObject:(current application's NSDictionary's dictionaryWithObject:"https://example.test/1" forKey:"current") forKey:"tab-1"
        set my identityViews to current application's NSDictionary's dictionaryWithObject:"synthetic-native-view" forKey:"tab-1"
        set my capturedPinnedObjects to current application's NSArray's arrayWithObject:"synthetic-pinned-object"
        set my selectionWrapperToken to "old-selection"
        set my exposureCandidates to current application's NSDictionary's dictionaryWithObject:"synthetic-candidate" forKey:"tab-1"
        set my captureRows to current application's NSArray's arrayWithObject:"synthetic-native-row"
        set my captureWrappers to current application's NSArray's arrayWithObject:"synthetic-wrapper"
        set my captureExpanded to current application's NSArray's arrayWithObject:true
        set my captureRootExpanded to true
        set my captureScrollPoint to "synthetic-scroll-reference"
        set my captureBindingIDs to current application's NSArray's arrayWithObject:1
        set my captureActiveHistory to my identityHistories
        set my captureDeadline to current application's NSDate's dateWithTimeIntervalSinceNow:0
        set my selectedIdentity to 1
        set my identityRequestedAt to current application's NSDate's dateWithTimeIntervalSinceNow:0
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        set payload to my abandonmentPayload()
        my assertTrue(my archiveWrites is 0 and my archiveReads is 0 and my captureCalls is 0 and my moveCalls is 1, "inspection did no filesystem writes or native changes")
        my assertTrue((originalData's isEqualToData:(current application's NSData's dataWithContentsOfFile:journalPath)) as boolean, "inspection did not modify journal")
        if contents of divergence is "reorganized" then
            my assertTrue((payload's objectForKey:"expectedLiveAvailable") as boolean, "available live revision inspected")
        else
            my assertTrue(not ((payload's objectForKey:"expectedLiveAvailable") as boolean), "unavailable live state explicit")
            my assertTrue(((payload's objectForKey:"expectedRevision")'s isEqual:(current application's NSNull's |null|())) as boolean, "unavailable revision is null")
        end if
        -- Preserve process-wide maps and connection/UI references across cleanup.
        set my nativeScopeUUIDs to current application's NSDictionary's dictionaryWithObject:"scope-id" forKey:"scope"
        set sharedScopes to my nativeScopeUUIDs
        set my nativeObjectUUIDs to current application's NSMapTable's weakToStrongObjectsMapTable()
        set sharedObjects to my nativeObjectUUIDs
        set my attachedControllers to current application's NSMutableArray's array()
        set sharedControllers to my attachedControllers
        set my sidebarView to "synthetic-controller-view"
        set resultObject to my finishAbandonment(payload)
        my assertTrue((my nativeScopeUUIDs's isEqual:sharedScopes) as boolean, "shared scope identity retained")
        my assertTrue((my nativeObjectUUIDs's isEqual:sharedObjects) as boolean, "shared object identity retained")
        my assertTrue((my attachedControllers's isEqual:sharedControllers) as boolean, "controller connections retained")
        my assertTrue(my sidebarView is "synthetic-controller-view" and my sessionKey is "fixture-process", "process/UI references retained")
        my expectPayloadFailure("abandonRetainedTransaction", payload)
        my expectFailure("inspectRetainedTransaction")
        my performCommand("captureNative", current application's NSDictionary's dictionary())
        my assertTrue(my captureCalls is 1, "fresh explicit capture reached private scope boundary")
    end repeat

    -- Every confirmation binding is mandatory and compared, including a real boolean.
    repeat with keyName in {"confirmed", "inspectionToken", "expectedTransactionID", "expectedJournalRevision", "expectedJournalVersion", "expectedJournalIdentity", "expectedLiveAvailable", "expectedRevision"}
        my resetFixture()
        my applyFixture()
        set payload to my abandonmentPayload()
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        set altered to payload's mutableCopy()
        altered's removeObjectForKey:(contents of keyName)
        my assertRetainedAfterRefusal(altered, originalData)
        set altered to payload's mutableCopy()
        altered's setObject:"wrong" forKey:(contents of keyName)
        my assertRetainedAfterRefusal(altered, originalData)
        my finishAbandonment(payload)
    end repeat
    repeat with confirmation in {false, "true", current application's NSNumber's numberWithInteger:1, current application's NSNull's |null|()}
        my resetFixture()
        my applyFixture()
        set payload to my abandonmentPayload()
        payload's setObject:(contents of confirmation) forKey:"confirmed"
        my assertRetainedAfterRefusal(payload, current application's NSData's dataWithContentsOfFile:journalPath)
    end repeat
    my resetFixture()
    my applyFixture()
    set payload to my abandonmentPayload()
    payload's setObject:(current application's NSNumber's numberWithInteger:1) forKey:"expectedLiveAvailable"
    my assertRetainedAfterRefusal(payload, current application's NSData's dataWithContentsOfFile:journalPath)

    -- A newer inspection invalidates the earlier token. Concurrent capture refuses
    -- both inspection and abandonment, retaining all state without a move.
    my resetFixture()
    my applyFixture()
    set oldPayload to my abandonmentPayload()
    set payload to my abandonmentPayload()
    set originalData to current application's NSData's dataWithContentsOfFile:journalPath
    my assertRetainedAfterRefusal(oldPayload, originalData)
    set my captureToken to "pending-capture"
    my expectFailure("inspectRetainedTransaction")
    my assertRetainedAfterRefusal(payload, originalData)
    set my captureToken to missing value
    my finishAbandonment(payload)

    -- Snapshot/revision/availability changes after inspection require reinspection.
    repeat with changedState in {"layout", "same-revision-layout", "unavailable", "available"}
        my resetFixture()
        my applyFixture()
        if contents of changedState is "available" then set my snapshotFailure to true
        set payload to my abandonmentPayload()
        if contents of changedState is "layout" then
            set my fixtureLive to my fixtureBefore
        else if contents of changedState is "same-revision-layout" then
            set my fixtureLive to my fixtureApplied's mutableCopy()
            my fixtureLive's setObject:"changed" forKey:"extra-observed-state"
        else if contents of changedState is "unavailable" then
            set my snapshotFailure to true
        else
            set my snapshotFailure to false
        end if
        my assertRetainedAfterRefusal(payload, current application's NSData's dataWithContentsOfFile:journalPath)
        my finishAbandonment(my abandonmentPayload())
    end repeat

    -- Exact bytes matter even when JSON is semantically unchanged. Changes to
    -- identity/version/transaction journal fields cannot reuse an inspected token.
    repeat with changedField in {"whitespace", "identity", "version", "transactionID"}
        my resetFixture()
        my applyFixture()
        set payload to my abandonmentPayload()
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        if contents of changedField is "whitespace" then
            set alteredData to originalData's mutableCopy()
            alteredData's appendData:((current application's NSString's stringWithString:" ")'s dataUsingEncoding:4)
            alteredData's writeToFile:journalPath options:1 |error|:(missing value)
        else
            set altered to ((my inspectJournal(current application's NSDictionary's dictionary()))'s objectForKey:"journal")'s mutableCopy()
            if contents of changedField is "identity" then
                altered's setObject:(current application's NSDictionary's dictionaryWithObject:"changed-session" forKey:"sessionKey") forKey:"identity"
            else if contents of changedField is "version" then
                altered's setObject:1 forKey:"version"
            else
                altered's setObject:"different-journal-transaction" forKey:"transactionID"
            end if
            my production_saveResolvedJournal(altered)
        end if
        my assertRetainedAfterRefusal(payload, current application's NSData's dataWithContentsOfFile:journalPath)
        my finishAbandonment(my abandonmentPayload())
    end repeat
    -- Bind retained evidence independently of journal changes, freezing mutable data.
    repeat with changedField in {"transactionID", "phase", "before", "applied", "partial", "identity"}
        my resetFixture()
        my applyFixture()
        set payload to my abandonmentPayload()
        if contents of changedField is "transactionID" then
            set my transactionID to "different-retained-transaction"
        else if contents of changedField is "phase" then
            set my transactionPhase to "recoveryRequired"
        else if contents of changedField is "before" then
            set my beforeSnapshot to my fixtureBefore's mutableCopy()
            my beforeSnapshot's setObject:"changed" forKey:"revision"
        else if contents of changedField is "applied" then
            set my appliedSnapshot to my fixtureApplied's mutableCopy()
            my appliedSnapshot's setObject:"changed" forKey:"revision"
        else if contents of changedField is "partial" then
            set my partialSnapshot to my fixtureBefore
        else
            set my persistentIdentity to my persistentIdentity's mutableCopy()
            my persistentIdentity's setObject:"changed" forKey:"sessionKey"
        end if
        my assertRetainedAfterRefusal(payload, current application's NSData's dataWithContentsOfFile:journalPath)
        my finishAbandonment(my abandonmentPayload())
    end repeat

    -- Fault each create/write/protection/read/byte-verification boundary, including
    -- verification after finalization. Every failure retains native references and
    -- snapshots; a fresh inspection can retry without any restoration moves.
    repeat with faultName in {"mkdir", "write1", "write2", "permissions1", "permissions2", "permissions3", "permissions4", "permissions5", "permissions6", "permissions7", "read1", "read2", "read3", "read4", "bytes1", "bytes2", "bytes3", "bytes4", "resolution", "after-write", "resolution-corrupt"}
        my resetFixture()
        my applyFixture()
        set my fixtureLive to my fixtureBefore
        set payload to my abandonmentPayload()
        set retainedBefore to my beforeSnapshot
        set retainedApplied to my appliedSnapshot
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        set my archiveFault to contents of faultName
        if contents of faultName is "resolution" then set my resolutionFailure to true
        if contents of faultName is "after-write" then set my resolutionAfterWriteFailure to true
        if contents of faultName is "resolution-corrupt" then set my resolutionCorruption to true
        my expectPayloadFailure("abandonRetainedTransaction", payload)
        my assertTrue((my beforeSnapshot's isEqualToDictionary:retainedBefore) as boolean, "archive failure retains original")
        my assertTrue((my appliedSnapshot's isEqualToDictionary:retainedApplied) as boolean, "archive failure retains verified applied evidence")
        my assertTrue(my contextItems is not missing value and my retainedInspection is not missing value and my transactionID is not missing value, "archive failure retains context/token/transaction")
        my assertTrue(my moveCalls is 1, "archive failure made zero moves")
        my expectFailure("captureNative")
        set my archiveFault to ""
        set my resolutionFailure to false
        set my resolutionAfterWriteFailure to false
        set my resolutionCorruption to false
        set currentData to current application's NSData's dataWithContentsOfFile:journalPath
        if (currentData's isEqualToData:originalData) as boolean then
            -- Same token can retry when no observed state changed.
            my finishAbandonment(payload)
        else
            -- A write may have completed before its verification/reply failed.
            -- Old token cannot overwrite it; new inspection archives that version.
            my expectPayloadFailure("abandonRetainedTransaction", payload)
            my finishAbandonment(my abandonmentPayload())
        end if
    end repeat

    -- Changes during archive I/O are caught by the second binding check.
    repeat with faultName in {"journalChanged", "transactionChanged", "liveChanged"}
        my resetFixture()
        my applyFixture()
        set my fixtureLive to my fixtureBefore
        set payload to my abandonmentPayload()
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        set my archiveFault to contents of faultName
        my expectPayloadFailure("abandonRetainedTransaction", payload)
        my assertTrue(my beforeSnapshot is not missing value and my contextItems is not missing value and my moveCalls is 1, "concurrent change retained evidence without moves")
        set my archiveFault to ""
        if contents of faultName is "journalChanged" then
            my expectFailure("inspectRetainedTransaction")
            -- Only this fixture repairs its injected file; production never guesses.
            originalData's writeToFile:journalPath options:1 |error|:(missing value)
        end if
        my finishAbandonment(my abandonmentPayload())
    end repeat

    -- Archive failed/pending transactions too, even when partial evidence could
    -- not be journaled or a fresh snapshot is unavailable.
    repeat with phaseName in {"recoveryRequired", "restoredJournalPending", "appliedJournalPending"}
        my resetFixture()
        if contents of phaseName is "recoveryRequired" then
            set my failedMoves to {1, 2}
            set my failedWrites to {3}
            my expectFailure("apply")
        else if contents of phaseName is "restoredJournalPending" then
            set my failedMoves to {1}
            set my failedWrites to {3}
            my expectFailure("apply")
        else
            my applyFixture()
            set my failedMoves to {2}
            set my failedWrites to {5}
            my expectFailure("undo")
        end if
        my assertTrue(my transactionPhase is contents of phaseName, "abandonment pending phase fixture")
        set my snapshotFailure to true
        my finishAbandonment(my abandonmentPayload())
    end repeat
    my resetFixture()
    my applyFixture()
    set my snapshotFailure to true
    set my failedMoves to {2}
    my compensateLayout(my fixtureBefore, "rolledBack")
    my assertTrue((my partialSnapshot's objectForKey:"snapshotError") is not missing value, "unavailable partial evidence fixture")
    my finishAbandonment(my abandonmentPayload())

    -- Existing recovery evidence is retained by path in the new archive and its
    -- original protected file is never deleted, changed or retired by abandonment.
    my resetFixture()
    my applyFixture()
    set priorData to current application's NSData's dataWithContentsOfFile:journalPath
    set priorArchive to my protectedJournalArchive(priorData, ".fixture-prior-recovery-")
    set my recoveryArchive to priorArchive
    set payload to my abandonmentPayload()
    set resultObject to my finishAbandonment(payload)
    set evidenceData to current application's NSData's dataWithContentsOfFile:((resultObject's objectForKey:"archives")'s objectForKey:"evidenceArchive")
    set evidenceObject to current application's NSJSONSerialization's JSONObjectWithData:evidenceData options:0 |error|:(missing value)
    set savedEvidence to (evidenceObject's objectForKey:"retainedInspection")'s objectForKey:"evidence"
    my assertTrue(((savedEvidence's objectForKey:"recoveryArchive")'s isEqual:priorArchive) as boolean, "earlier archive reference preserved")
    my assertTrue((priorData's isEqualToData:(current application's NSData's dataWithContentsOfFile:priorArchive)) as boolean, "earlier archive file unchanged")
    my assertTrue((my production_archiveFilePermissions(priorArchive) as integer) is 384, "earlier archive protection unchanged")

    -- Uninspectable disk evidence cannot be silently archived as a valid journal.
    repeat with invalidText in {"not JSON", "[]", "{}", "{\"version\":3,\"identity\":{}}", "{\"version\":2,\"identity\":[]}"}
        my resetFixture()
        my applyFixture()
        set textData to (current application's NSString's stringWithString:(contents of invalidText))'s dataUsingEncoding:4
        textData's writeToFile:journalPath options:1 |error|:(missing value)
        my expectFailure("inspectRetainedTransaction")
        my assertTrue(my beforeSnapshot is not missing value and my contextItems is not missing value and my archiveWrites is 0, "invalid inspection retains evidence without writes")
        my expectFailure("abandonRetainedTransaction")
    end repeat
    my resetFixture()
    my applyFixture()
    current application's NSFileManager's defaultManager()'s removeItemAtPath:journalPath |error|:(missing value)
    my expectFailure("inspectRetainedTransaction")
    my assertTrue(my beforeSnapshot is not missing value and my contextItems is not missing value and my archiveWrites is 0, "missing journal never discards retained state")

    -- Divergent live layout and journal mismatch cannot be kept or undone.
    my resetFixture()
    my applyFixture()
    set my fixtureLive to my fixtureBefore
    my expectFailure("keep")
    my expectFailure("undo")
    my assertTrue(my beforeSnapshot is not missing value, "divergence retained Undo evidence")
    my assertTrue(my moveCalls is 1, "divergence made no moves")
    my assertStatus("applied", false, true, "applied")
    set my fixtureLive to my fixtureApplied
    set journalObject to (my inspectJournal(current application's NSDictionary's dictionary()))'s objectForKey:"journal"
    set altered to journalObject's mutableCopy()
    altered's setObject:"wrong-transaction" forKey:"transactionID"
    my production_saveResolvedJournal(altered)
    my expectFailure("keep")
    my expectFailure("undo")
    my assertStatus("applied", false, true, "applied")

    -- Archive or resolution failure cannot clear retained verified state.
    repeat with failingStage in {"archive", "resolution"}
        my resetFixture()
        my applyFixture()
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        if contents of failingStage is "archive" then
            set my archiveFailure to true
        else
            set my resolutionFailure to true
        end if
        my expectFailure("keep")
        my assertStatus("applied", true, false, "applied")
        set my archiveFailure to false
        set my resolutionFailure to false
        my performCommand("keep", current application's NSDictionary's dictionary())
        set resolved to (my inspectJournal(current application's NSDictionary's dictionary()))'s objectForKey:"journal"
        set archivePath to resolved's objectForKey:"archive"
        set archiveData to current application's NSData's dataWithContentsOfFile:archivePath
        my assertTrue((originalData's isEqualToData:archiveData) as boolean, "byte-exact archive")
        set attributes to current application's NSFileManager's defaultManager()'s attributesOfItemAtPath:archivePath |error|:(missing value)
        my assertTrue(((attributes's objectForKey:(current application's NSFilePosixPermissions)) as integer) is 384, "protected 0600 archive")
    end repeat

    -- Actual shipped recoveryJournal retires only completed native-session sorts.
    -- Model a new process with no context/identity, keeping the applied live tree.
    my resetFixture()
    my applyFixture()
    set previousMoveCalls to my moveCalls
    my clearTransaction()
    set my contextItems to missing value
    set my persistentIdentity to missing value
    set my sessionKey to missing value
    set originalData to current application's NSData's dataWithContentsOfFile:journalPath
    my assertStatus("idle", false, true, "applied")
    set resolved to my performCommand("recoveryJournal", current application's NSDictionary's dictionary())
    my assertTrue(((resolved's objectForKey:"phase") as text) is "accepted", "completed prior native session retired")
    my assertStatus("idle", false, false, "accepted")
    my assertLayout(my fixtureApplied)
    my assertTrue(my moveCalls is previousMoveCalls, "startup retirement made no moves")
    my assertTrue((resolved's objectForKey:"recovered") is missing value, "retirement does not claim restoration")
    set archivePath to resolved's objectForKey:"archive"
    my assertTrue((originalData's isEqualToData:(current application's NSData's dataWithContentsOfFile:archivePath)) as boolean, "completed prior journal preserved byte exactly")
    my assertTrue((my production_archiveFilePermissions(archivePath) as integer) is 384, "completed prior archive protected")
    set repeated to my performCommand("recoveryJournal", current application's NSDictionary's dictionary())
    my assertTrue((resolved's isEqualToDictionary:repeated) as boolean, "repeat normalization keeps same resolution")

    repeat with phaseName in {"prepared", "undoing", "rollingBack", "recoveryRequired"}
        my previousJournal(contents of phaseName)
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        my performCommand("recoveryJournal", current application's NSDictionary's dictionary())
        my assertStatus("idle", false, true, contents of phaseName)
        my assertTrue((originalData's isEqualToData:(current application's NSData's dataWithContentsOfFile:journalPath)) as boolean, "unfinished journal not retired")
        my assertTrue(my moveCalls is 0, "unfinished normalization made no moves")
    end repeat

    my resetFixture()
    my applyFixture()
    set originalData to current application's NSData's dataWithContentsOfFile:journalPath
    my performCommand("recoveryJournal", current application's NSDictionary's dictionary())
    my assertStatus("applied", true, false, "applied")
    my assertTrue((originalData's isEqualToData:(current application's NSData's dataWithContentsOfFile:journalPath)) as boolean, "retained same-process journal not retired")

    repeat with failingStage in {"archive", "resolution"}
        my previousJournal("applied")
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        if contents of failingStage is "archive" then
            set my archiveFailure to true
        else
            set my resolutionFailure to true
        end if
        my expectFailure("recoveryJournal")
        my assertStatus("idle", false, true, "applied")
        my assertTrue((originalData's isEqualToData:(current application's NSData's dataWithContentsOfFile:journalPath)) as boolean, "failed retirement keeps journal")
        my assertTrue(my moveCalls is 0, "failed retirement made no moves")
        set my archiveFailure to false
        set my resolutionFailure to false
        my performCommand("recoveryJournal", current application's NSDictionary's dictionary())
        my assertStatus("idle", false, false, "accepted")
    end repeat

    -- Prior-session acknowledgment is explicit and never maps old IDs to live tabs.
    repeat with phaseName in {"prepared", "undoing", "rollingBack", "recoveryRequired"}
        set payload to my previousJournal(contents of phaseName)
        my assertStatus("idle", false, true, contents of phaseName)
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        set resolved to my performCommand("acknowledgeCurrent", payload)
        my assertTrue(((resolved's objectForKey:"phase") as text) is "acknowledged", "acknowledgment phase")
        my assertTrue((resolved's objectForKey:"recovered") is missing value, "not falsely restored")
        my assertTrue(my moveCalls is 0, "acknowledgment made no moves")
        set archiveData to current application's NSData's dataWithContentsOfFile:(resolved's objectForKey:"archive")
        my assertTrue((originalData's isEqualToData:archiveData) as boolean, "prior journal preserved")
        my assertStatus("idle", false, false, "acknowledged")
        my expectPayloadFailure("acknowledgeCurrent", payload)
    end repeat
    repeat with fieldName in {"confirmed", "expectedJournalRevision", "expectedJournalVersion", "expectedJournalIdentity", "expectedRevision"}
        set payload to my previousJournal("prepared")
        payload's removeObjectForKey:(contents of fieldName)
        my expectPayloadFailure("acknowledgeCurrent", payload)
        my assertStatus("idle", false, true, "prepared")
    end repeat
    repeat with fieldName in {"confirmed", "expectedJournalRevision", "expectedJournalVersion", "expectedJournalIdentity", "expectedRevision"}
        set payload to my previousJournal("undoing")
        payload's setObject:"wrong" forKey:(contents of fieldName)
        my expectPayloadFailure("acknowledgeCurrent", payload)
        my assertTrue(my moveCalls is 0, "stale acknowledgment made no moves")
    end repeat
    repeat with failingStage in {"archive", "resolution"}
        set payload to my previousJournal("rollingBack")
        if contents of failingStage is "archive" then
            set my archiveFailure to true
        else
            set my resolutionFailure to true
        end if
        my expectPayloadFailure("acknowledgeCurrent", payload)
        my assertStatus("idle", false, true, "rollingBack")
        set my archiveFailure to false
        set my resolutionFailure to false
        my performCommand("acknowledgeCurrent", payload)
        my assertStatus("idle", false, false, "acknowledged")
    end repeat
    set payload to my previousJournal("prepared")
    set my sessionKey to "previous-process"
    my expectPayloadFailure("acknowledgeCurrent", payload)
    set payload to my previousJournal("prepared")
    set my beforeSnapshot to my fixtureBefore
    my expectPayloadFailure("acknowledgeCurrent", payload)
    set payload to my previousJournal("prepared")
    my expectPayloadFailure("recover", current application's NSDictionary's dictionary())
    my assertTrue(my moveCalls is 0, "cross-session recovery forbidden")
    -- Execute the existing UUID-verified recovery path with the same transaction machinery.
    set payload to my prepareVerifiedRecovery()
    my performCommand("recover", payload)
    my assertLayout(my fixtureBefore)
    my assertStatus("idle", false, false, "recovered")
    repeat with boundaryIndex in {1, 2}
        set payload to my prepareVerifiedRecovery()
        set my failedWrites to {contents of boundaryIndex}
        my expectPayloadFailure("recover", payload)
        my assertLayout(my fixtureApplied)
        if contents of boundaryIndex is 1 then
            my assertTrue(my moveCalls is 0, "recovery write-ahead before moves")
            my assertStatus("idle", false, true, "prepared")
        else
            my assertStatus("idle", false, false, "rolledBack")
        end if
    end repeat
    set payload to my prepareVerifiedRecovery()
    set my failedMoves to {1, 2}
    my expectPayloadFailure("recover", payload)
    my assertStatus("recoveryRequired", false, true, "recoveryRequired")
    my assertTrue(my recoveryArchive is not missing value, "original recovery archive retained")
    my resumeRetained("original")
    my assertLayout(my fixtureApplied)
    my assertStatus("idle", false, false, "rolledBack")

    -- Invalid disk evidence must still produce safe reply flags.
    repeat with invalidText in {"not JSON", "[]", "{}", "{\"phase\":\"future-unknown\"}"}
        my resetFixture()
        set textData to (current application's NSString's stringWithString:(contents of invalidText))'s dataUsingEncoding:4
        textData's writeToFile:journalPath options:1 |error|:(missing value)
        set statusObject to my transactionStatus()
        my assertTrue(not ((statusObject's objectForKey:"canUndo") as boolean), "invalid journal cannot Undo")
        my assertTrue((statusObject's objectForKey:"needsRecovery") as boolean, "invalid journal blocks Apply")
        my expectFailure("apply")
        my assertTrue(my moveCalls is 0, "invalid journal made no moves")
    end repeat

    -- The installer executes these exact guards before reusing any host object.
    my validateLoadedRevision("OrionNativeTreeHostV3R49")
    set refused to false
    try
        my validateLoadedRevision("OrionNativeTreeHostV3R48")
    on error
        set refused to true
    end try
    my assertTrue(refused, "mixed loaded revision refused")
    set runtimeObject to current application's NSDictionary's dictionaryWithObjects:{"chrome-extension://@@EXTENSION_ID@@/sorter.html", "@@RUNTIME_ROOT@@/state/native-session-undo.json"} forKeys:{"controllerURL", "journalPath"}
    my validateRuntime(runtimeObject)
    set refused to false
    try
        my validateRuntime(current application's NSDictionary's dictionaryWithObjects:{"chrome-extension://different/sorter.html", "@@RUNTIME_ROOT@@/state/native-session-undo.json"} forKeys:{"controllerURL", "journalPath"})
    on error
        set refused to true
    end try
    my assertTrue(refused, "mixed runtime configuration refused")
    return "Shipped transaction handlers: " & my assertionCount & " assertions passed (success, partial moves, all journal boundaries, retained recovery, Keep divergence, protected abandonment/retry completed-session retirement and explicit prior-session acknowledgment). No Orion was loaded or changed."
end run
